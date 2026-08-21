// omp tool_call hook: before the agent writes a file, tell a running nvim to load it so its
// persistent undo history survives the write. Registered once at user level via
// ~/.omp/agent/config.yml#extensions, so it covers every project — including the case where the
// agent edits project B while the only running nvim sits in project A (undofile names derive from
// the absolute path alone, so any instance protects any file).
//
// All real work lives in scripts/undo-guard-notify.ts; this hook only resolves paths.

import type { HookAPI } from "@oh-my-pi/pi-coding-agent";
import { extractShellPaths } from "./undo-guard-paths.ts";

const NOTIFIER_BUN = "/Users/zaye/.bun/bin/bun";
const NOTIFIER_SCRIPT = "/Users/zaye/.config/nvim/scripts/undo-guard-notify.ts";

// [PATH#TAG] section header, e.g. "[src/foo.ts#1A2B]" — TAG is 4 hex chars.
const SECTION_HEADER_RE = /^\[([^\]#]+)#[0-9A-Fa-f]{4}\]/;

/** True for internal-URI targets and archive/sqlite selectors that are not plain filesystem paths. */
function isInternalOrSelectorPath(path: string): boolean {
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(path)) return true; // xd://, local://, memory://, conflict://, etc.
  // archive.zip:inner/path or db.sqlite:table[:key] — a ':' after a file-like segment.
  if (/^[^:]+\.(zip|tar|tar\.gz|tgz|jar|war|ear|apk|db|db3|sqlite|sqlite3):/i.test(path)) return true;
  return false;
}

/** Extract every distinct `[PATH#TAG]` header path out of an edit-tool hashline document. */
function extractEditPaths(input: string): string[] {
  const paths = new Set<string>();
  for (const line of input.split("\n")) {
    const m = SECTION_HEADER_RE.exec(line);
    if (m?.[1]) paths.add(m[1]);
  }
  return [...paths];
}

/**
 * omp fails CLOSED when a tool_call handler throws (HookToolWrapper propagates emitToolCall
 * errors and blocks the call). Undo protection must never be able to block or slow an agent
 * edit, so every code path below is wrapped and swallows all errors, always returning undefined
 * (never `{ block: true }`).
 *
 * Deliberate coverage gap: `xd://ast_edit` bulk rewrites and shell commands that choose their own
 * file set (`prettier --write .`, `npm install`) are not enumerable before execution. Files under
 * the cwd are covered by the startup preload in lua/util/undo.lua instead.
 */
export default function (pi: HookAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    try {
      const isShell = event.toolName === "bash";
      if (event.toolName !== "write" && event.toolName !== "edit" && !isShell) return;

      let rawPaths: string[];
      if (isShell) {
        // Shell commands that name their targets (`sed -i f`, `tee f`, `> f`, `patch`, `mv`,
        // `cp`). Commands that choose their own file set are covered by the startup preload.
        const command = event.input.command;
        if (typeof command !== "string" || command.length === 0) return;
        rawPaths = extractShellPaths(command, ctx.cwd);
      } else if (event.toolName === "write") {
        const p = event.input.path;
        if (typeof p !== "string" || p.length === 0) return;
        rawPaths = [p];
      } else {
        const input = event.input.input;
        if (typeof input !== "string" || input.length === 0) return;
        rawPaths = extractEditPaths(input);
      }

      const absPaths = new Set<string>();
      for (const raw of rawPaths) {
        if (isInternalOrSelectorPath(raw)) continue;
        absPaths.add(raw.startsWith("/") ? raw : `${ctx.cwd}/${raw}`);
      }
      if (absPaths.size === 0) return;

      // One invocation for every path: the notifier accepts N paths and holds them over a
      // single socket, so this costs one Bun startup rather than one per path.
      await pi
        .exec(NOTIFIER_BUN, [NOTIFIER_SCRIPT, ...absPaths], { timeout: 1000 })
        .catch(() => undefined);
    } catch {
      // Never block or slow an agent edit — worst case is today's behavior (undo history lost).
    }
    return undefined;
  });
}
