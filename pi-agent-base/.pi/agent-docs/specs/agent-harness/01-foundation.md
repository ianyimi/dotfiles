# 01 — Foundation: CLI Skeleton, Shared Lib, Init, Doctor, State

> Phase spec 1 of 8. Prereq: read `00-master.md` fully — its §2 conventions and §7 schemas are
> binding and not repeated here. Everything later specs import from `src/lib/` is pinned HERE.

## Overview

Build the `harness/` Bun package: CLI entry + router, the shared infrastructure library, the
`harness init` primitives + init skill, the doctor framework with 8 core checks, and `harness state`.
After this spec, `harness init` produces a valid `.agent/` on a fixture repo and `harness doctor`
catches seeded drift.

## Design Decisions

- Zero-dep core; `yaml` npm package only for full-document YAML (master §2.2). This spec adds it.
- Doctor checks are static-imported (no dynamic discovery) — determinism and `--compile` friendliness.
- Init primitives are dumb and deterministic; the init *skill* owns inference and interviewing (D5).
- `state.md` is derived entirely from files the CLI can read — never from model output.

## Out of Scope (this spec)

Sync/adapters (04 — only `platforms/types.ts` ships here), all commands listed for specs 02–08,
doctor checks belonging to later specs (registry is designed to grow).

## Target Directory Structure

As master §5, minus files owned by later specs. Every file below appears in a step.

## Implementation Order

> `[agent]` = boilerplate/pattern-following · `[dev]` = core logic, guided stub named per step
> (the implementing agent writes both; tags preserve review priority)

1. `[agent]` Package scaffold — after this, `bun test` runs (0 tests) and `bunx tsc --noEmit` is clean
2. `[agent]` Errors + exit codes
3. `[dev]` `resolveProjectRoot` + path constants — key fn: `resolveProjectRoot`
4. `[dev]` Arg parser — key fn: `parseArgs`
5. `[agent]` Reporter (`output.ts`)
6. `[dev]` Frontmatter parse/serialize — key fns: `parseFrontmatter`, `serializeFrontmatter`
7. `[dev]` `fsx` — key fns: `walk`, `ensureSymlink`, `writeFileAtomic`
8. `[agent]` `git.ts` wrappers
9. `[dev]` Manifest load/validate/save — key fn: `validateManifest`
10. `[agent]` `syncManifest.ts` + `platforms/types.ts`
11. `[dev]` CLI entry + router — key fn: `route`
12. `[dev]` Doctor framework — key fn: `runDoctor`
13. `[dev]` 8 core checks (one file + test each)
14. `[dev]` `harness state` — key fn: `buildState`
15. `[dev]` `harness init` primitives — key fns: `initScaffold`, `initWritePhase`, `initFinish`
16. `[agent]` Init skill (`SKILL.md` + references) + embedded `.agent` templates
17. Verification

---

## Step 1: Package scaffold `[agent]`

- [ ] Create `harness/package.json`, `harness/tsconfig.json`, `harness/bunfig.toml`
- [ ] Create `harness/test/helpers.ts` and `harness/test/fixtures/` (three fixtures)
- [ ] `cd harness && bun install && bun test && bunx tsc --noEmit` — all clean

**File: `harness/package.json`**

```json
{
  "name": "@zaye/harness",
  "version": "0.1.0",
  "description": "Platform-agnostic agent harness CLI — .agent/ source of truth, generated platform bridges",
  "type": "module",
  "bin": { "harness": "./src/cli.ts" },
  "engines": { "bun": ">=1.3.14" },
  "scripts": {
    "test": "bun test",
    "typecheck": "tsc --noEmit",
    "harness": "bun run src/cli.ts"
  },
  "dependencies": { "yaml": "^2.5.0" },
  "devDependencies": { "@types/bun": "^1.2.0", "typescript": "^5.6.0" }
}
```

**File: `harness/tsconfig.json`** — strict true, module/moduleResolution `"Preserve"`/`"bundler"`,
target `"ESNext"`, `types: ["@types/bun"]`, `noUncheckedIndexedAccess: true`, include `src`, `test`.

**File: `harness/test/helpers.ts`** — full code; used by every test file in the suite.

```typescript
import { mkdtempSync, cpSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const FIXTURES = join(dirname(fileURLToPath(import.meta.url)), "fixtures");

/**
 * Copies a named fixture tree into a fresh temp directory and returns its path.
 * Callers must pass the returned path as cwd to runCli. Cleaned by rmProject.
 *
 * @param props.fixture - Directory name under test/fixtures (e.g. "ts-monorepo").
 * @returns Absolute path of the temp project root.
 */
export function mkTmpProject(props: { fixture: string }): string {
  const dir = mkdtempSync(join(tmpdir(), "harness-test-"));
  cpSync(join(FIXTURES, props.fixture), dir, { recursive: true });
  return dir;
}

/** Removes a temp project created by mkTmpProject. @param props.dir - Path returned by mkTmpProject. @returns Nothing. */
export function rmProject(props: { dir: string }): void {
  rmSync(props.dir, { recursive: true, force: true });
}

/**
 * Runs the CLI in-process with argv and a working directory, capturing output.
 * In-process (not subprocess) so tests are fast and coverage attributes correctly.
 *
 * @param props.argv - Args after the binary name, e.g. ["doctor", "--json"].
 * @param props.cwd - Project directory to run in.
 * @returns Exit code plus captured stdout/stderr strings.
 */
export async function runCli(props: { argv: string[]; cwd: string }): Promise<{
  code: number; stdout: string; stderr: string;
}> {
  const { main } = await import("../src/cli.ts");
  const out: string[] = []; const err: string[] = [];
  const code = await main({
    argv: props.argv, cwd: props.cwd,
    stdout: (s) => out.push(s), stderr: (s) => err.push(s),
  });
  return { code, stdout: out.join("\n"), stderr: err.join("\n") };
}
```

**Fixtures** (small, checked in):

- `test/fixtures/empty-project/` — `package.json` (`{"name":"empty-project","version":"0.0.0"}`),
  `src/index.ts` (`export const hi = 1;`). No `.agent/`, no git.
- `test/fixtures/ts-monorepo/` — `package.json` with `scripts: { build, test, dev }` and
  workspaces, `pnpm-workspace.yaml` (`packages: ["packages/*"]`),
  `packages/core/package.json`, `packages/core/src/index.ts`, `.env.example`
  (`DATABASE_URL=\nAPI_KEY=\n`). No `.agent/`.
- `test/fixtures/initialized/` — a complete healthy `.agent/` matching master §6: valid
  `manifest.json` (project `initialized`, platforms.active `["omp","claude"]`, all budgets default,
  modules all true except design/roadmap, standards_domains `["backend"]`), `AGENTS.md` with a
  6-line `## Agent Directives` section, product docs with `verified_at: TESTSHA` frontmatter,
  `standards/anti-patterns.md` (10 lines), `standards/preferences.md` (12 lines),
  `standards/backend/api.md`, empty `docs/specs/`, `docs/tasks.md`, `dependencies/registry.md`
  (header only), one skill `.agent/skills/dev-spec/SKILL.md` (valid frontmatter, 20 lines).
  Tests that need git run `git init && git add -A && git commit -m init` in the temp copy
  (helper: `gitInit(props: { dir })` — add to helpers.ts, full code, trivial execSync wrapper).

---

## Step 2: Errors + exit codes `[agent]`

- [ ] Create `src/lib/errors.ts` + `src/lib/errors.test.ts`

**File: `harness/src/lib/errors.ts`** — full code.

```typescript
/** Exit codes per master §2.9. */
export const EXIT = { OK: 0, FINDINGS: 1, USAGE: 2, FAILURE: 3 } as const;

/**
 * A user-facing harness failure with a stable machine code and optional fix hint.
 * Thrown by lib/commands; caught once in cli.ts and rendered by the Reporter.
 */
export class HarnessError extends Error {
  /** Stable kebab-case code, e.g. "manifest-invalid", "not-initialized". */
  readonly code: string;
  /** Optional "run this" remediation, e.g. "harness init". */
  readonly hint?: string;
  /** Exit code to use; defaults to EXIT.USAGE for validation-shaped errors. */
  readonly exitCode: number;
  constructor(code: string, message: string, opts?: { hint?: string; exitCode?: number }) {
    super(message);
    this.code = code;
    this.hint = opts?.hint;
    this.exitCode = opts?.exitCode ?? EXIT.USAGE;
  }
}
```

Test: constructing carries fields; default exitCode is 2.

---

## Step 3: Project root + path constants `[dev]`

- [ ] Create `src/lib/paths.ts` + `src/lib/paths.test.ts`; run tests

**File: `harness/src/lib/paths.ts`**

```typescript
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { HarnessError, EXIT } from "./errors.ts";

/** Root-relative .agent path constants used by every command. */
export const AGENT_DIR = ".agent";
export const P = {
  manifest: join(AGENT_DIR, "manifest.json"),
  agentsMd: join(AGENT_DIR, "AGENTS.md"),
  contextRules: join(AGENT_DIR, "context-rules.yaml"),
  syncManifest: join(AGENT_DIR, ".sync-manifest.json"),
  setupProgress: join(AGENT_DIR, ".setup-progress.md"),
  docs: join(AGENT_DIR, "docs"),
  product: join(AGENT_DIR, "docs", "product"),
  standards: join(AGENT_DIR, "docs", "standards"),
  specs: join(AGENT_DIR, "docs", "specs"),
  decisions: join(AGENT_DIR, "docs", "decisions"),
  sessionLog: join(AGENT_DIR, "docs", "session-log"),
  tasks: join(AGENT_DIR, "docs", "tasks.md"),
  state: join(AGENT_DIR, "docs", "state.md"),
  skills: join(AGENT_DIR, "skills"),
  dependencies: join(AGENT_DIR, "dependencies"),
  depsRegistry: join(AGENT_DIR, "dependencies", "registry.md"),
  envManifest: join(AGENT_DIR, "env.manifest.md"),
} as const;

/**
 * Walks up from cwd to find the project root (master §2.10).
 *
 * @param props.cwd - Directory to start from.
 * @returns Absolute project root path.
 * @throws {HarnessError} code "no-project" when neither .agent/ nor .git/ is found up to /.
 */
export function resolveProjectRoot(props: { cwd: string }): string {
  // TODO: implement
  //
  // 1. Walk cwd → parent → … → filesystem root, collecting the FIRST dir containing `.agent/`
  //    and the FIRST containing `.git/` (file or dir — worktrees use a .git file).
  //    → nearest `.agent/` wins over `.git/` (a harness project inside a mono-repo must
  //      resolve to itself, not the outer repo)
  // 2. If .agent found → return that dir. Else if .git found → return that dir.
  // 3. Else throw HarnessError("no-project", "Not inside a project (no .agent/ or .git/ found)",
  //    { hint: "cd into a project or run `git init`", exitCode: EXIT.USAGE })
  //
  // Edge cases:
  // - cwd itself is the root → return it (loop includes cwd before parents)
  // - symlinked cwd: do NOT realpath; walk the literal path (chezmoi trees rely on this)
  throw new Error("Not implemented");
}
```

**File: `harness/src/lib/paths.test.ts`** — full code; exact cases:

```typescript
import { describe, expect, test } from "bun:test";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";
import { resolveProjectRoot } from "./paths.ts";

describe("resolveProjectRoot", () => {
  test("finds .agent at cwd", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    expect(resolveProjectRoot({ cwd: dir })).toBe(dir);
    rmProject({ dir });
  });
  test("finds .agent from nested dir", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const nested = join(dir, "src", "deep");
    mkdirSync(nested, { recursive: true });
    expect(resolveProjectRoot({ cwd: nested })).toBe(dir);
    rmProject({ dir });
  });
  test("nearest .agent wins over outer .git", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    mkdirSync(join(dir, ".git"));                       // outer repo marker
    const inner = join(dir, "apps", "site");
    mkdirSync(join(inner, ".agent"), { recursive: true });
    expect(resolveProjectRoot({ cwd: inner })).toBe(inner);
    rmProject({ dir });
  });
  test(".git fallback when no .agent", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    mkdirSync(join(dir, ".git"));
    expect(resolveProjectRoot({ cwd: join(dir, "src") })).toBe(dir);
    rmProject({ dir });
  });
  test(".git FILE (worktree) counts", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    writeFileSync(join(dir, ".git"), "gitdir: /elsewhere\n");
    expect(resolveProjectRoot({ cwd: dir })).toBe(dir);
    rmProject({ dir });
  });
  test("throws no-project otherwise", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    expect(() => resolveProjectRoot({ cwd: dir })).toThrow(/Not inside a project/);
    rmProject({ dir });
  });
});
```

---

## Step 4: Arg parser `[dev]`

- [ ] Create `src/lib/args.ts` + `src/lib/args.test.ts`; run tests

**File: `harness/src/lib/args.ts`**

```typescript
import { HarnessError } from "./errors.ts";

/** Declares what a (sub)command accepts. */
export interface ArgSpec {
  /** Named positionals in order; a trailing "...rest" name collects remainder. */
  positionals?: string[];
  /** Boolean flags, e.g. ["json", "check"]. --json → true. */
  flags?: string[];
  /** Value options, e.g. ["for", "from", "data", "template"]. --for X or --for=X. */
  options?: string[];
}

export interface ParsedArgs {
  positionals: Record<string, string>;
  rest: string[];
  flags: Record<string, boolean>;
  options: Record<string, string>;
}

/**
 * Minimal deterministic arg parser (no deps).
 *
 * @param props.argv - Tokens after the command name.
 * @param props.spec - Accepted shape.
 * @returns Parsed groups; missing flags are false, missing options absent.
 * @throws {HarnessError} code "usage" on unknown flag/option, missing positional,
 *   or an option with no value.
 */
export function parseArgs(props: { argv: string[]; spec: ArgSpec }): ParsedArgs {
  // TODO: implement
  //
  // 1. Iterate tokens. "--" → everything after goes to rest verbatim, stop parsing.
  // 2. "--name=value" → options if name ∈ spec.options, else usage error.
  // 3. "--name" → if name ∈ spec.flags set true; else if ∈ spec.options consume NEXT token as
  //    value (usage error if absent or next token starts with "--"); else usage error.
  // 4. Bare token → next unfilled positional; if positionals exhausted and last one is
  //    "...rest", append to rest; else usage error "unexpected argument".
  // 5. After loop: every non-"...rest" positional must be filled → usage error naming it.
  //
  // Edge cases:
  // - single-dash tokens ("-x") are NOT supported → usage error (keeps grammar tiny)
  // - repeated option → last one wins (documented, tested)
  // - flag given a value via "=" → usage error
  throw new Error("Not implemented");
}
```

**File: `harness/src/lib/args.test.ts`** — full code, exact expectations:

```typescript
import { describe, expect, test } from "bun:test";
import { parseArgs } from "./args.ts";

const spec = { positionals: ["slug"], flags: ["json", "check"], options: ["for", "from"] };

describe("parseArgs", () => {
  test("positionals + flags + options", () => {
    expect(parseArgs({ argv: ["my-spec", "--json", "--for", "auth"], spec })).toEqual({
      positionals: { slug: "my-spec" }, rest: [],
      flags: { json: true, check: false },
      options: { for: "auth" },
    });
  });
  test("--key=value form", () => {
    expect(parseArgs({ argv: ["s", "--from=T3"], spec }).options.from).toBe("T3");
  });
  test("-- passthrough", () => {
    expect(parseArgs({ argv: ["s", "--", "--json", "x"], spec }).rest).toEqual(["--json", "x"]);
  });
  test("...rest collector", () => {
    const p = parseArgs({ argv: ["a", "b", "c"], spec: { positionals: ["first", "...rest"] } });
    expect(p.positionals.first).toBe("a");
    expect(p.rest).toEqual(["b", "c"]);
  });
  test("repeated option: last wins", () => {
    expect(parseArgs({ argv: ["s", "--for", "a", "--for", "b"], spec }).options.for).toBe("b");
  });
  for (const [name, argv] of [
    ["unknown flag", ["s", "--nope"]],
    ["missing positional", []],
    ["option without value", ["s", "--for"]],
    ["option eats a flag-looking token", ["s", "--for", "--json"]],
    ["unexpected extra positional", ["s", "extra"]],
    ["single dash", ["s", "-j"]],
    ["flag with =value", ["s", "--json=1"]],
  ] as const) {
    test(`usage error: ${name}`, () => {
      expect(() => parseArgs({ argv: [...argv], spec })).toThrow();
    });
  }
});
```

---

## Step 5: Reporter `[agent]`

- [ ] Create `src/lib/output.ts` + `src/lib/output.test.ts`; run tests

**File: `harness/src/lib/output.ts`** — full code.

```typescript
/** One reportable line. level ordering: error > warn > info > ok. */
export interface ReportItem {
  level: "ok" | "info" | "warn" | "error";
  message: string;
  id?: string;       // stable id (doctor check id etc.)
  hint?: string;     // "→ Run: harness sync"
}

/**
 * Collects report items and renders them either as human lines (with emoji + optional hint
 * line) or as a JSON array when json mode is on. Colors are emoji-only, so NO_COLOR needs
 * no special handling.
 */
export class Reporter {
  readonly items: ReportItem[] = [];
  #json: boolean;
  #write: (s: string) => void;

  constructor(props: { json: boolean; write: (s: string) => void }) {
    this.#json = props.json;
    this.#write = props.write;
  }

  /** Adds an item. @param props.item - The report line to record. @returns Nothing. */
  add(props: { item: ReportItem }): void { this.items.push(props.item); }

  ok(message: string, id?: string): void { this.add({ item: { level: "ok", message, id } }); }
  info(message: string, id?: string, hint?: string): void { this.add({ item: { level: "info", message, id, hint } }); }
  warn(message: string, id?: string, hint?: string): void { this.add({ item: { level: "warn", message, id, hint } }); }
  error(message: string, id?: string, hint?: string): void { this.add({ item: { level: "error", message, id, hint } }); }

  /** True if any item is level "error". @returns Whether errors were recorded. */
  hasErrors(): boolean { return this.items.some((i) => i.level === "error"); }

  /**
   * Renders all items. Human mode: `🔴 ERROR  msg` / `⚠️  WARN   msg` / `ℹ️  INFO   msg` /
   * `✅ OK     msg`, each followed by `          → hint` when present. JSON mode: one
   * JSON.stringify of the items array.
   * @returns Nothing (writes via the sink).
   */
  flush(): void {
    if (this.#json) { this.#write(JSON.stringify(this.items, null, 2)); return; }
    for (const i of this.items) {
      const tag = { ok: "✅ OK    ", info: "ℹ️  INFO  ", warn: "⚠️  WARN  ", error: "🔴 ERROR " }[i.level];
      this.#write(`${tag} ${i.message}`);
      if (i.hint) this.#write(`          → ${i.hint}`);
    }
  }
}
```

Test (full): items accumulate in order; `hasErrors`; human render matches the exact strings above
(assert full joined output for a 3-item reporter); JSON mode emits parseable array with `id`/`hint`
preserved.

---

## Step 6: Frontmatter `[dev]`

- [ ] Create `src/lib/frontmatter.ts` + `src/lib/frontmatter.test.ts`; run tests

**File: `harness/src/lib/frontmatter.ts`**

```typescript
export interface Frontmatter {
  /** Parsed keys. Values: string | boolean | number | string[]. Unknown keys preserved. */
  data: Record<string, unknown>;
  /** Document body after the closing ---, leading newline stripped. */
  body: string;
  /** The raw frontmatter block INCLUDING delimiters, byte-exact, for round-tripping. */
  raw: string;
}

/**
 * Tolerant flat-YAML frontmatter parser (master §8). Handles: `key: value`, quoted strings,
 * booleans, numbers, inline arrays `[a, b]`, dash lists, and multi-line folded strings with
 * 2-space continuation (pi descriptions use these). Unknown keys are preserved verbatim.
 *
 * @param props.text - Full file content.
 * @returns Parsed frontmatter; when the file has no leading `---` line, data={}, raw="",
 *   body=text.
 * @throws Never — malformed lines land in data as raw strings; tolerance is the contract.
 */
export function parseFrontmatter(props: { text: string }): Frontmatter {
  // TODO: implement
  //
  // 1. If text doesn't start with "---\n" (allow "---\r\n") → { data:{}, body:text, raw:"" }.
  // 2. Find the closing "\n---" line; absent → treat whole text as body (no throw).
  // 3. Parse lines inside: key rules above. Continuation lines (2+ leading spaces, previous
  //    line was a string value) append with a single space (folded).
  //    a. "true"/"false" → boolean; integer-looking → number; else string (strip one layer
  //       of matching quotes)
  //    b. "key:" followed by dash lines → string[]
  // 4. raw = the exact source slice including both --- lines and trailing newline.
  //
  // Edge cases:
  // - CRLF input: normalize for parsing but keep raw byte-exact
  // - empty frontmatter block ("---\n---\n") → data {}
  // - value containing ": " (e.g. descriptions with colons) → split on FIRST ": " only
  throw new Error("Not implemented");
}

/**
 * Serializes data + body back to a document. If props.raw is provided and props.data is
 * unchanged from its parse, emit raw verbatim (byte-exact round-trip guarantee).
 *
 * @param props.data - Frontmatter keys (insertion order preserved).
 * @param props.body - Document body.
 * @param props.raw - Optional original raw block for the unchanged fast path.
 * @returns Full document text.
 */
export function serializeFrontmatter(props: {
  data: Record<string, unknown>; body: string; raw?: string;
}): string {
  // TODO: implement
  //
  // 1. Unchanged fast path (raw provided + reparse(raw) deep-equals data) → raw + body.
  // 2. Else emit "---\n" + one line per key (arrays as inline [a, b]; strings quoted only
  //    when they contain ": ", "#", or leading/trailing space) + "---\n\n" + body.
  throw new Error("Not implemented");
}
```

**File: `harness/src/lib/frontmatter.test.ts`** — full code. Cases (exact literals in the test file):
pi skill frontmatter (`name`/`description`/`invoke: "dev-spec"` quoted), OMP agent frontmatter with
kebab keys (`thinking-level: medium`, `read-summarize: false` → boolean), inline array
(`applies_to: [".pi/**"]` → `[".pi/**"]`), dash list, folded multi-line description (2-space
continuation joins with space), no-frontmatter file, empty block, colon-in-value
(`description: Use BEFORE any change: always`  → value `"Use BEFORE any change: always"`),
round-trip: for every fixture string `serializeFrontmatter(parse(x)) === x`.

---

## Step 7: fsx `[dev]`

- [ ] Create `src/lib/fsx.ts` + `src/lib/fsx.test.ts`; run tests

**File: `harness/src/lib/fsx.ts`** — `sha256(props: { text })` (full code, `node:crypto`),
`writeFileAtomic(props: { path; content })` (full code: tmp file in same dir + rename, ensureDir
first), plus two guided stubs:

```typescript
/**
 * Recursively lists files under root, returning root-relative POSIX paths, sorted.
 * Prunes: .git, node_modules, .agent/dependencies (clone bodies), and any dir in props.prune.
 *
 * @param props.root - Absolute directory.
 * @param props.prune - Extra directory names to skip.
 * @returns Sorted relative file paths (files only, symlinks reported as files).
 */
export function walk(props: { root: string; prune?: string[] }): string[] {
  // TODO: implement — readdirSync(withFileTypes) recursion; sort() at the end for determinism.
  throw new Error("Not implemented");
}

export type SymlinkResult = "created" | "replaced" | "ok" | "conflict";

/**
 * Ensures linkPath is a symlink pointing at targetPath (stored relative to linkPath's dir).
 *
 * @param props.linkPath - Absolute path where the link should live.
 * @param props.targetPath - Absolute path the link must resolve to.
 * @returns "ok" (already correct), "created", "replaced" (was a symlink to elsewhere),
 *   or "conflict" (a REAL file/dir occupies linkPath — untouched; caller reports per D10).
 */
export function ensureSymlink(props: { linkPath: string; targetPath: string }): SymlinkResult {
  // TODO: implement
  //
  // 1. lstat linkPath. ENOENT → symlinkSync(relative(dirname(link), target), link) → "created".
  // 2. If symlink: readlink; resolve against dirname; equal to target → "ok";
  //    else unlink + recreate → "replaced".
  // 3. Real file or directory → return "conflict" WITHOUT touching it.
  //
  // Edge cases: parent dir of linkPath may not exist → mkdir -p first.
  throw new Error("Not implemented");
}
```

Tests (full): walk on `ts-monorepo` fixture returns the exact sorted list (assert whole array);
walk prunes a seeded `node_modules`; sha256 of `"harness\n"` equals the known hex
(compute once, pin literal); writeFileAtomic creates parents and leaves no tmp files;
ensureSymlink all four results (create → ok → point elsewhere → replaced → seed real file → conflict
and file content untouched).

---

## Step 8: git wrappers `[agent]`

- [ ] Create `src/lib/git.ts` + `src/lib/git.test.ts`; run tests

`execSync`-based, full code — each function: `isRepo(props: { root })`, `headSha(props: { root })`
(returns `""` when not a repo or no commits — callers treat empty as "unknown"),
`changedFilesSince(props: { root; sha })` (`git diff --name-only <sha>..HEAD`, [] on any git error),
`commitsTouching(props: { root; paths; sinceDays })` (`git log --oneline --since=<n>.days -- <paths>`
→ count). All wrap failures to safe defaults — git absence must never crash a command; JSDoc
documents each default. Tests use `gitInit` helper: headSha is 40 hex; changedFilesSince between two
commits returns the exact file list; non-repo returns safe defaults.

---

## Step 9: Manifest `[dev]`

- [ ] Create `src/lib/manifest.ts` + `src/lib/manifest.test.ts`; run tests

Full code: the `HarnessManifest` + related types **verbatim from master §7.1** (single source: this
file; master is prose), `DEFAULT_BUDGETS` const, `loadManifest(props: { root })` (read + JSON.parse +
`validateManifest`; ENOENT → `HarnessError("not-initialized", …, { hint: "harness init" })`),
`saveManifest(props: { root; manifest })` (writeFileAtomic, 2-space indent, trailing newline).

Guided stub `validateManifest(props: { value: unknown }): { manifest: HarnessManifest; warnings: string[] }`:

```
// TODO: implement
// 1. Assert object. For each required key (schema_version, project, description, harness,
//    platforms, workflow, modules, standards_domains, dependencies, doctor) → missing →
//    HarnessError("manifest-invalid", `manifest.json: missing ${path}`)
// 2. schema_version !== "1.0" → manifest-invalid (message includes found value)
// 3. platforms.active: array of strings; each must be "omp" | "claude" (import KNOWN_PLATFORM_IDS
//    from ../platforms/types.ts) → unknown id → manifest-invalid naming the id
// 4. workflow.commit_mode: default "message-only" when absent; must be one of the two literals
// 5. doctor.budgets: fill each missing budget from DEFAULT_BUDGETS; stale_spec_days default 14
// 6. Unknown top-level keys → warnings ("unknown key `x` — kept") , preserved on save
// Edge cases: dependencies entries missing repo → manifest-invalid (deps clone needs it)
```

Tests (full): fixture `initialized` manifest loads clean; each required-key deletion throws with the
key path in the message; defaults filled (delete budgets → defaults appear, commit_mode defaults);
unknown key warns and survives a load→save round-trip; unknown platform id throws.

---

## Step 10: syncManifest + platform types `[agent]`

- [ ] Create `src/lib/syncManifest.ts` (+test) and `src/platforms/types.ts`

`syncManifest.ts` — full code: types verbatim from master §7.3, `loadSyncManifest` (absent file →
`{ version: 1, generated_at_sha: "", entries: [] }`), `saveSyncManifest` (atomic, stable key order,
entries sorted by path). Test: round-trip + default.

`platforms/types.ts` — full code: `KNOWN_PLATFORM_IDS = ["omp", "claude"] as const`, `PlatformId`,
`PlatformAdapter`, `BridgePlan`, `ProjectContext` (fields: `root`, `manifest`, `skills:
{ name, dir, frontmatter }[]`, `standardsFiles: string[]`, `contextRules: ContextRule[] | null`) —
exactly what 04 consumes; nothing more (no-speculation rule: doctor's `shims-stale` check in 04 and
sync both read these).

---

## Step 11: CLI entry + router `[dev]`

- [ ] Create `src/cli.ts` + `src/cli.test.ts`; run tests

**File: `harness/src/cli.ts`**

```typescript
/** Sink-parameterized main so tests run in-process (test/helpers.ts contract). */
export interface MainProps {
  argv: string[];
  cwd: string;
  stdout: (s: string) => void;
  stderr: (s: string) => void;
}

/**
 * CLI entry. Routes `harness <command> [subcommand] [...args]` to command modules.
 *
 * @param props.argv - Tokens after the binary name.
 * @param props.cwd - Working directory.
 * @param props.stdout - Line sink for normal output.
 * @param props.stderr - Line sink for errors/usage.
 * @returns Process exit code (EXIT.*).
 */
export async function main(props: MainProps): Promise<number> {
  // TODO: implement
  //
  // 1. Command table: Record<string, { run(props: CommandProps): Promise<number>; help: string }>
  //    — this spec registers: init, doctor, state, help. Later specs append rows; the table is
  //    the ONLY registration point.
  // 2. argv empty | "help" | "--help" → print usage (command list + one-line help each) → EXIT.OK
  // 3. Unknown command → stderr usage → EXIT.USAGE
  // 4. Dispatch inside try/catch: HarnessError → stderr `error(<code>): <message>` + hint line
  //    → its exitCode; anything else → stderr `unexpected: <message>` + stack → EXIT.FAILURE
  //
  // CommandProps = { args: string[] (after command word), cwd, stdout, stderr }
  throw new Error("Not implemented");
}

if (import.meta.main) {
  const code = await main({
    argv: process.argv.slice(2), cwd: process.cwd(),
    stdout: console.log, stderr: console.error,
  });
  process.exit(code);
}
```

Tests (full, via runCli): no args → usage, exit 0, lists `init doctor state`; unknown command →
exit 2; `harness doctor` outside a project → exit 2 with "Not inside a project".

---

## Step 12: Doctor framework `[dev]`

- [ ] Create `src/commands/doctor.ts` + `src/commands/doctor.test.ts`; run tests (framework only —
      a stub check registry of [] is fine until Step 13 lands; the test file grows in Step 13)

**File: `harness/src/commands/doctor.ts`**

```typescript
import type { HarnessManifest } from "../lib/manifest.ts";
import type { ReportItem } from "../lib/output.ts";

/** Context handed to every check. Built once per doctor run. */
export interface CheckContext {
  root: string;
  manifest: HarnessManifest;
  headSha: string;                       // "" when unknown
  /** Lazy cached readers so 14 checks don't re-read the same files. */
  read: (relPath: string) => string | null;        // null when absent
  listFiles: (relDir: string) => string[];         // [] when absent, root-relative, sorted
}

export interface DoctorCheck {
  id: string;                            // e.g. "preferences-over-budget"
  severity: "error" | "warn" | "info";
  /** Skip silently when false (e.g. module disabled). @param props.ctx - run context. @returns Whether to run. */
  appliesWhen(props: { ctx: CheckContext }): boolean;
  /** @param props.ctx - run context. @returns Findings; [] = pass (reported as one ✅ line). */
  run(props: { ctx: CheckContext }): Omit<ReportItem, "level">[];
}

/**
 * Runs all registered checks honoring manifest.doctor.checks filtering.
 *
 * @param props.root - Project root.
 * @param props.checks - Registry (static import list; tests inject fixtures' subsets).
 * @param props.reporter - Sink for results.
 * @returns EXIT.FINDINGS if any error-severity finding, else EXIT.OK.
 */
export function runDoctor(props: { root: string; checks: DoctorCheck[]; reporter: Reporter }): number {
  // TODO: implement
  //
  // 1. loadManifest (not-initialized propagates — cli renders hint "harness init").
  // 2. Build CheckContext: memoized read/listFiles over fsx; headSha via git.
  // 3. filter = manifest.doctor.checks (absent → all). Unknown id in filter → warn line.
  // 4. For each check (registry order): !appliesWhen → skip silently.
  //    run() → [] → reporter.ok(`${id}`) ; findings → reporter[severity] each with id + hint.
  //    A check that THROWS → reporter.error(`check ${id} crashed: <msg>`) — one bad check
  //    never kills the run.
  // 5. Return FINDINGS iff hasErrors, else OK.
  throw new Error("Not implemented");
}
```

CLI wiring: `harness doctor [--json]`.

---

## Step 13: Eight core checks `[dev]`

- [ ] One file per check in `src/checks/` + one test each; register all in `doctor.ts` static list
- [ ] Run full test suite

Shared budget helper `src/checks/budget.ts` (full code): `countLines(text)` = non-empty lines.

Each check below: id / severity / appliesWhen / findings contract / exact test seed. Implement each
`run` from its contract (they are 5–20 lines each; contracts ARE the pseudo-code).

1. **`preferences-over-budget`** · error · module always · `docs/standards/preferences.md` lines >
   `budgets.preferences_lines` → one finding `preferences.md is <n> lines (budget: <b>)`, hint
   `harness pref compact`. Test: seed 81 one-word lines → error; 80 → ok.
2. **`anti-patterns-over-budget`** · warn · always · same shape, budget `anti_patterns_lines`, hint
   `manual review — never auto-compact`. Test mirrors 1.
3. **`skill-over-budget`** · warn · always · every `.agent/skills/*/SKILL.md` over
   `budgets.skill_lines` → finding per skill naming it. Test: fixture skill padded to 151 → warn.
4. **`agents-md-directives-over-budget`** · warn · always · lines between `## Agent Directives` and
   the next `## ` in `.agent/AGENTS.md` > budget → finding. Missing section → finding
   `AGENTS.md has no "## Agent Directives" section`. Tests: both.
5. **`stale-commands`** · warn · appliesWhen `dev-processes.md` exists AND project has package.json ·
   backticked tokens matching `^(pnpm|npm|bun|yarn) run \S+` in dev-processes.md whose script name
   is absent from package.json `scripts` → finding per command. Test: dev-processes references
   `pnpm run build` + `pnpm run gone`; fixture scripts have only `build` → exactly one finding
   naming `gone`.
6. **`stale-packages`** · warn · appliesWhen tech-stack.md + package.json exist · backticked
   `@scope/name` or bare `name` tokens in tech-stack.md that look like deps (present in a
   `**Packages**` table/section — contract: only scan lines starting with `| ` or `- `) and appear
   in neither dependencies nor devDependencies → finding per package. Additionally: frontmatter
   `verified_at` ≠ current headSha → one info `tech-stack.md last verified at <sha>` (hint: review +
   update verified_at). Tests: seeded missing package caught; verified_at mismatch info; match → ok.
7. **`open-specs-stale`** · info · modules.specs · for each `docs/specs/*/spec-tasks.md` containing
   `- [ ]`: `commitsTouching(paths from frontmatter touches[], sinceDays: stale_spec_days)` == 0 →
   info finding per spec. No git → skip (appliesWhen includes isRepo). Test: git fixture, spec with
   open boxes + no commits → info; after a commit touching the path with `--since` satisfied → ok
   (use sinceDays 0 trick: seed old commit via GIT_COMMITTER_DATE).
8. **`decisions-inconsistent`** · warn · modules.decisions · ADR files with frontmatter
   `status: Superseded` whose `title`-referenced package (frontmatter key `package:` — 02's ADR
   template includes it) still appears in tech-stack.md → finding per ADR. Test: seeded superseded
   ADR for `nextauth` + tech-stack listing `nextauth` → warn.

Doctor test (`doctor.test.ts`, full): on clean `initialized` fixture → exit 0, output contains
`✅ OK     preferences-over-budget` style lines for all applicable checks; `--json` emits
machine-readable items; `doctor.checks: ["preferences-over-budget"]` filter runs exactly one check;
a registered check that throws yields an error line but the run completes.

---

## Step 14: `harness state` `[dev]`

- [ ] Create `src/commands/state.ts` + test; wire into cli table; run tests

Contract — regenerate `.agent/docs/state.md`:

```markdown
# Project State
> GENERATED by `harness state` — do not edit. SHA: <headSha|unknown>

## Active specs        ← docs/specs/*/spec.md frontmatter status != done; "(none)"
- <slug> — <status> — <n> open / <m> total tasks   ← checkbox counts from spec-tasks.md

## Tasks               ← verbatim "## In Progress" + "## Inbox" sections of docs/tasks.md (if module)
## Recent sessions     ← last 3 session-log entry headlines (## lines), newest first
## Doctor              ← one line: "<e> errors, <w> warnings at last run" — runs the check registry
                         in-process (reuse runDoctor with a silent reporter)
```

`buildState(props: { root; checks }): string` guided stub (numbered comments per the contract above;
sections for disabled modules omitted entirely). Command writes atomically + prints the content to
stdout (skills read stdout). Tests (full): golden state.md for `initialized` fixture (exact string);
module-off omission; spec with 2/5 boxes checked renders `3 open / 5 total`.

---

## Step 15: `harness init` primitives `[dev]`

- [ ] Create `src/commands/init.ts` + `src/commands/init.test.ts`; wire; run tests

Subcommands (D5): the SKILL interviews; these primitives do all writes.

**`harness init scaffold`** — idempotent. Creates `.agent/` skeleton: all dirs of master §6,
`manifest.json` **not** written (write-phase 7 owns it), `AGENTS.md` with the proposal §6 fallback
text (embedded template), `.setup-progress.md` with the 10-phase checklist (all unchecked),
`dependencies/.gitignore`, empty `tasks.md` (`## In Progress\n\n## Inbox\n\n## Recently Done\n`),
copies every embedded default skill from `src/templates/skills/` into `.agent/skills/` (skip
existing). Re-run: only fills gaps, never overwrites. Prints created paths.

**`harness init write-phase <n> --data <path.json|->`** — deterministic phase writers. `-` = stdin.
Validates `n` ∈ 1..10 and data shape per phase (table below), writes the phase's files atomically,
ticks the phase checkbox in `.setup-progress.md`, records the data under `## Collected Data` (JSON
block per phase) so a compacted session can resume.

| n | data (validated keys) | writes |
|---|---|---|
| 1 | `{ project, description, language, repo_type }` | progress file only |
| 2 | `{ purpose, team }` | progress file only |
| 3 | `{ domains: string[] }` | `docs/standards/<domain>/` dirs + a `README.md` stub per domain (1 line) |
| 4 | `{ tech_stack_md: string }` | `docs/product/tech-stack.md` (adds `verified_at: <headSha>` frontmatter) |
| 5 | `{ dev_processes_md: string, env_vars: {name, desc}[] }` | dev-processes.md (+verified_at), `env.manifest.md` |
| 6 | `{ dependencies: DependencyPin[] }` | progress file (manifest assembly reads it in phase 7); appends to `dependencies/registry.md` |
| 7 | `{ workflow: …, modules: …, platforms: … }` | **assembles + writes `manifest.json`** from phases 1+6+7 data (validateManifest before write) |
| 8 | `{ naming_conventions_md: string }` | `docs/standards/naming-conventions.md` |
| 9 | `{ mission_md, roadmap_md? }` | mission.md, roadmap.md if modules.roadmap |
| 10 | `{}` | nothing (finish handles it) |

Phases may arrive out of order EXCEPT 7 requires 1 and 6 recorded; 10 via `finish` only.

**`harness init status`** — prints the progress checklist + which phases have recorded data (skills
resume from this).

**`harness init finish`** — asserts manifest.json exists + phases 1–9 ticked (else
`HarnessError("init-incomplete")` listing missing), replaces `AGENTS.md` fallback with the
post-init template (directives block ≤20 lines from proposal §17 + pointer sections), deletes
`.setup-progress.md`, prints next steps (`harness sync`, `harness doctor`).

Guided stubs for `initScaffold`, `initWritePhase`, `initFinish` with numbered comments per the
contracts above. Tests (full): scaffold on `empty-project` → assert exact dir/file set (walk);
re-scaffold after deleting one file restores only it; write-phase 4 writes tech-stack with
verified_at; phase 7 before 1 → init-incomplete error; full 1→9 + finish on `ts-monorepo` →
`loadManifest` succeeds, progress file gone, AGENTS.md has directives; write-phase with bad JSON →
usage error naming the offending key.

## Step 16: Init skill + embedded templates `[agent]`

- [ ] Create `src/templates/skills/init/SKILL.md` + `references/{phases.md,inference.md}`
- [ ] Create `src/templates/agent/{AGENTS.fallback.md, AGENTS.post-init.md, setup-progress.md}`
- [ ] Re-run scaffold test (templates now resolve)

`SKILL.md` (≤150 lines, full content in this step): frontmatter
(`name: init`, `description: Initialize or update the agent harness for a project. Triggers on "harness init", "init the harness", "set up the agent harness"…`),
preflight (inverted: if manifest EXISTS ask re-init vs update per proposal Phase 0), then the loop:
for each phase 1–10 → read `references/phases.md` section → infer from codebase per
`references/inference.md` → present draft → structured question → on confirm run
`harness init write-phase <n> --data -` → next. Ends: `harness init finish`, then `harness sync`
(no-op warning until 04 ships — acceptable), `harness index rebuild` (02 — skill mentions it
conditionally: "if available"). `references/phases.md`: per-phase question sets distilled from
proposal §7 (this spec ships phases 1–7,9,10 fully; phase 8's naming interview content is authored
in 02 and referenced here by path). `references/inference.md`: what to detect from manifest files
(package.json/Cargo.toml/go.mod/pyproject/Makefile), scripts→dev commands, deps→domain proposals,
"never propose a domain the project doesn't need".

## Verification (mandatory)

- [ ] `cd harness && bun install && bun test` — all green
- [ ] `bunx tsc --noEmit` — clean
- [ ] Manual smoke: in a scratch copy of `test/fixtures/ts-monorepo`, run scaffold → write-phase
      1..9 (sample JSON from the test file) → finish → doctor → state. Doctor exits 0; state.md
      renders; re-running scaffold changes nothing (idempotent).
- [ ] Fix anything broken; no skipped tests.

## Success Criteria

- [ ] `harness` usage lists init/doctor/state/help; unknown commands exit 2
- [ ] Init primitives produce a `.agent/` that `loadManifest` + doctor accept
- [ ] All 8 checks catch their seeded fixtures and pass on the healthy fixture
- [ ] Frontmatter round-trips pi + OMP fixture strings byte-exact
