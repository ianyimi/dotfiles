#!/usr/bin/env bun
// Hook subprocess: given a target file path, finds the best live nvim instance
// (by advertise file under $TMPDIR/nvim-undo/), calls
// require("util.undo").hold(path) over msgpack-RPC on its unix socket, and exits.
//
// Fail-open contract: every exit path is `process.exit(0)`. Nothing is ever
// written to stdout, because Claude Code's PreToolUse hook treats hook stdout
// as a decision document — any stray byte there could alter tool execution.
//
// Msgpack is hand-rolled (no dependency) rather than shelling out to
// `nvim --server --remote-expr`: that spawns a whole second nvim process just
// to proxy one RPC call, ~30-40ms of process-start overhead versus the ~1-3ms
// a direct unix-socket round-trip costs here, and the entire script must stay
// well under the 150ms hard timeout with margin to spare.

import path from "node:path";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { extractShellPaths } from "./undo-guard-paths.ts";

const HARD_TIMEOUT_MS = 150;

async function main(): Promise<void> {
  const targetPaths = await resolveTargetPaths();
  if (targetPaths.length === 0) return;

  const instances = listLiveInstances(path.join(process.env.TMPDIR ?? "/tmp", "nvim-undo"));
  if (instances.length === 0) return;

  // Group by best instance so each socket sees exactly one connection regardless of how many
  // paths were passed (they usually all resolve to the same instance).
  const byInstance = new Map<string, string[]>();
  for (const targetPath of targetPaths) {
    const instance = pickInstance(instances, targetPath);
    if (!instance) continue;
    const list = byInstance.get(instance.socket) ?? [];
    list.push(targetPath);
    byInstance.set(instance.socket, list);
  }

  await Promise.all([...byInstance].map(([socket, paths]) => callHoldMany(socket, paths)));
}

// ---------------------------------------------------------------------------
// Target path resolution
// ---------------------------------------------------------------------------

async function resolveTargetPaths(): Promise<string[]> {
  const argvPaths = process.argv.slice(2);
  if (argvPaths.length > 0) return argvPaths.map((p) => path.resolve(p));

  const raw = await readStdin();
  if (!raw) return [];

  try {
    const doc = JSON.parse(raw);
    const filePath = doc?.tool_input?.file_path;
    if (typeof filePath === "string" && filePath.length > 0) {
      return [path.resolve(filePath)];
    }
    // Bash tool calls carry a command line instead of a path. Extraction lives here rather
    // than in the hook config so all path-sniffing stays in one place.
    if (doc?.tool_name === "Bash") {
      const command = doc?.tool_input?.command;
      const cwd = typeof doc?.cwd === "string" && doc.cwd.length > 0 ? doc.cwd : process.cwd();
      if (typeof command === "string" && command.length > 0) {
        return extractShellPaths(command, cwd);
      }
    }
    return [];
  } catch {
    return [];
  }
}

function readStdin(): Promise<string> {
  const { promise, resolve } = Promise.withResolvers<string>();
  if (process.stdin.isTTY) {
    resolve("");
    return promise;
  }

  const chunks: Buffer[] = [];
  process.stdin.on("data", (chunk) => chunks.push(chunk));
  process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
  process.stdin.on("error", () => resolve(""));
  // Guard against a stdin that never closes (e.g. an interactive shell).
  setTimeout(() => resolve(Buffer.concat(chunks).toString("utf8")), HARD_TIMEOUT_MS);
  return promise;
}

// ---------------------------------------------------------------------------
// Instance discovery
// ---------------------------------------------------------------------------

interface Instance {
  pid: number;
  cwd: string;
  socket: string;
}

function listLiveInstances(advertiseDir: string): Instance[] {
  let entries: string[];
  try {
    entries = readdirSync(advertiseDir);
  } catch {
    return [];
  }

  const instances: Instance[] = [];
  for (const name of entries) {
    const pid = Number.parseInt(name, 10);
    if (!Number.isInteger(pid) || pid <= 0) continue;

    try {
      process.kill(pid, 0); // signal 0 probes liveness without delivering anything
    } catch {
      continue; // pid is gone; a VimLeavePre that never ran left this file behind
    }

    let contents: string;
    try {
      contents = readFileSync(path.join(advertiseDir, name), "utf8");
    } catch {
      continue;
    }

    const lines = contents.split("\n");
    const cwd = lines[0]?.trim();
    const socket = lines[1]?.trim();
    if (!cwd || !socket) continue;
    // existsSync, not Bun.file(socket).exists(): the latter is a method (so `!fn` is always
    // false and never skips) and targets regular files, whereas this path is a unix socket.
    if (!existsSync(socket)) continue;

    instances.push({ pid, cwd, socket });
  }
  return instances;
}

function pickInstance(instances: Instance[], targetPath: string): Instance | null {
  let best: Instance | null = null;
  let bestLen = -1;

  for (const inst of instances) {
    const prefix = inst.cwd.endsWith(path.sep) ? inst.cwd : inst.cwd + path.sep;
    if (targetPath !== inst.cwd && !targetPath.startsWith(prefix)) continue;

    if (inst.cwd.length > bestLen || (inst.cwd.length === bestLen && inst.pid > (best?.pid ?? -1))) {
      best = inst;
      bestLen = inst.cwd.length;
    }
  }

  if (best) return best;

  // No cwd matched: fall back to any live instance, newest pid first.
  // Undofile names derive only from the absolute file path, so a foreign
  // project's nvim can still hold and protect this file correctly.
  return instances.reduce<Instance | null>(
    (acc, inst) => (acc === null || inst.pid > acc.pid ? inst : acc),
    null,
  );
}

// ---------------------------------------------------------------------------
// Minimal msgpack encoder (positive fixint, uintX, fixstr/strX, fixarray)
// ---------------------------------------------------------------------------

type MsgpackValue = number | string | null | MsgpackValue[];

function encodeMsgpack(value: MsgpackValue): Uint8Array {
  const out: number[] = [];
  writeValue(value, out);
  return new Uint8Array(out);
}

function writeValue(value: MsgpackValue, out: number[]): void {
  if (value === null) {
    out.push(0xc0);
    return;
  }
  if (typeof value === "number") {
    writeUint(value, out);
    return;
  }
  if (typeof value === "string") {
    writeStr(value, out);
    return;
  }
  if (Array.isArray(value)) {
    writeArray(value, out);
    return;
  }
  throw new Error(`unsupported msgpack value: ${String(value)}`);
}

function writeUint(n: number, out: number[]): void {
  if (n < 0 || !Number.isInteger(n)) throw new Error(`unsupported int: ${n}`);
  if (n <= 0x7f) {
    out.push(n);
  } else if (n <= 0xff) {
    out.push(0xcc, n);
  } else if (n <= 0xffff) {
    out.push(0xcd, (n >> 8) & 0xff, n & 0xff);
  } else {
    out.push(0xce, (n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff);
  }
}

function writeStr(s: string, out: number[]): void {
  const bytes = Buffer.from(s, "utf8");
  const len = bytes.length;
  if (len <= 0x1f) {
    out.push(0xa0 | len);
  } else if (len <= 0xff) {
    out.push(0xd9, len);
  } else if (len <= 0xffff) {
    out.push(0xda, (len >> 8) & 0xff, len & 0xff);
  } else {
    out.push(0xdb, (len >>> 24) & 0xff, (len >>> 16) & 0xff, (len >>> 8) & 0xff, len & 0xff);
  }
  for (const b of bytes) out.push(b);
}

function writeArray(arr: MsgpackValue[], out: number[]): void {
  const len = arr.length;
  if (len <= 0x0f) {
    out.push(0x90 | len);
  } else if (len <= 0xffff) {
    out.push(0xdc, (len >> 8) & 0xff, len & 0xff);
  } else {
    out.push(0xdd, (len >>> 24) & 0xff, (len >>> 16) & 0xff, (len >>> 8) & 0xff, len & 0xff);
  }
  for (const item of arr) writeValue(item, out);
}

// ---------------------------------------------------------------------------
// Minimal msgpack decoder — just enough to tell that a complete response frame
// `[1, msgid, error, result]` has arrived. A decode throw means "keep reading".
// ---------------------------------------------------------------------------

class Reader {
  constructor(
    public buf: Uint8Array,
    public pos = 0,
  ) {}

  byte(): number {
    if (this.pos >= this.buf.length) throw new Error("truncated msgpack frame");
    return this.buf[this.pos++] as number;
  }
}

function readValue(r: Reader): unknown {
  const b = r.byte();

  if (b <= 0x7f) return b; // positive fixint
  if (b >= 0xe0) return b - 0x100; // negative fixint
  if ((b & 0xf0) === 0x80) return readMap(r, b & 0x0f); // fixmap
  if ((b & 0xf0) === 0x90) return readArrayN(r, b & 0x0f); // fixarray
  if ((b & 0xe0) === 0xa0) return readStrN(r, b & 0x1f); // fixstr

  switch (b) {
    case 0xc0:
      return null;
    case 0xc2:
      return false;
    case 0xc3:
      return true;
    case 0xcc:
      return r.byte();
    case 0xcd:
      return (r.byte() << 8) | r.byte();
    case 0xce:
      return ((r.byte() << 24) | (r.byte() << 16) | (r.byte() << 8) | r.byte()) >>> 0;
    case 0xd0:
      return (r.byte() << 24) >> 24;
    case 0xd1: {
      const v = (r.byte() << 8) | r.byte();
      return (v << 16) >> 16;
    }
    case 0xd2:
      return (r.byte() << 24) | (r.byte() << 16) | (r.byte() << 8) | r.byte();
    case 0xd9:
      return readStrN(r, r.byte());
    case 0xda:
      return readStrN(r, (r.byte() << 8) | r.byte());
    case 0xdb:
      return readStrN(r, (r.byte() << 24) | (r.byte() << 16) | (r.byte() << 8) | r.byte());
    case 0xdc:
      return readArrayN(r, (r.byte() << 8) | r.byte());
    case 0xdd:
      return readArrayN(r, (r.byte() << 24) | (r.byte() << 16) | (r.byte() << 8) | r.byte());
    default:
      throw new Error(`unsupported msgpack tag: 0x${b.toString(16)}`);
  }
}

function readStrN(r: Reader, len: number): string {
  if (r.pos + len > r.buf.length) throw new Error("truncated msgpack string");
  const bytes = r.buf.slice(r.pos, r.pos + len);
  r.pos += len;
  return Buffer.from(bytes).toString("utf8");
}

function readArrayN(r: Reader, len: number): unknown[] {
  const items: unknown[] = [];
  for (let i = 0; i < len; i++) items.push(readValue(r));
  return items;
}

function readMap(r: Reader, len: number): Record<string, unknown> {
  const obj: Record<string, unknown> = {};
  for (let i = 0; i < len; i++) {
    const key = readValue(r);
    obj[String(key)] = readValue(r);
  }
  return obj;
}

// ---------------------------------------------------------------------------
// RPC call
// ---------------------------------------------------------------------------

async function callHoldMany(socketPath: string, targetPaths: string[]): Promise<void> {
  // One connection, one request, one reply — regardless of how many paths were named, so N
  // paths cost one Bun startup plus one round-trip instead of N of each.
  const request = encodeMsgpack([
    0, // request type
    0, // msgid
    "nvim_exec_lua",
    ['for _, p in ipairs(...) do require("util.undo").hold(p) end', [targetPaths]],
  ]);

  const { promise, resolve } = Promise.withResolvers<void>();
  let settled = false;
  const finish = () => {
    if (settled) return;
    settled = true;
    clearTimeout(timer);
    resolve();
  };
  const timer = setTimeout(finish, HARD_TIMEOUT_MS);

  const chunks: Uint8Array[] = [];

  Bun.connect({
    unix: socketPath,
    socket: {
      open(socket) {
        socket.write(request);
      },
      data(socket, chunk) {
        chunks.push(chunk);
        // The frame length isn't known in advance, so decode on each chunk and stop
        // once a complete response parses. A throw means the frame is still partial.
        try {
          readValue(new Reader(concatChunks(chunks)));
          socket.end();
          finish();
        } catch {
          // incomplete frame, wait for more data
        }
      },
      error: finish,
      close: finish,
    },
  }).catch(finish);

  await promise;
}

function concatChunks(chunks: Uint8Array[]): Uint8Array {
  const total = chunks.reduce((n, c) => n + c.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.length;
  }
  return out;
}

// ---------------------------------------------------------------------------

main()
  .catch(() => {})
  .finally(() => process.exit(0));
