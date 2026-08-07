# 06 — Dependency Source Clones

> Phase spec 6 of 8. Prereqs: `00-master.md` (§2 conventions binding, §7.1 `DependencyPin`),
> `01-foundation.md` (lib contracts — `git.ts` is EXTENDED here, never forked), proposal §9 + §15
> (`stale-dependencies`). Specs 01–05 are available; nothing from 07–08 exists yet.

## Overview

Implement `harness deps clone|sync|add|remove|list`: shallow-clone the git source of each pinned
dependency (`manifest.json#dependencies: DependencyPin[]`, master §7.1) at the tag best matching its
version into `.agent/dependencies/<dirname>`, track clones in the committed
`dependencies/registry.md`, and detect drift against the *project* manifest (package.json /
Cargo.toml / pyproject.toml) via the `stale-dependencies` doctor check. Skills (dev-spec 02,
implement 05) already tell agents to read `registry.md` during exploration — no skill content here.

## Design Decisions

- **Dirname mapping**: strip the leading `@`, replace every `/` with `__`. `convex` → `convex`,
  `@tanstack/form` → `tanstack__form`. One-way is fine — registry rows keep the real name.
- **Repo URL resolution**: `DependencyPin.repo` is host-relative (`github.com/org/repo`) → prefix
  `https://`, unless it contains `://` or starts with `/` (absolute local path — how tests reach
  fixture bare repos). Absolute paths get `file://` at clone time so `--depth` is honored (git
  silently ignores depth on plain local-path clones).
- **New git fns throw.** Unlike 01's safe-default wrappers, `lsRemoteTags`/`shallowCloneAtRef` throw
  `HarnessError` (`git-ls-remote-failed`, `git-clone-failed`) — callers must distinguish unreachable
  repos from tagless ones. The *command* catches per-package and warns; one bad dep never fails the
  batch (proposal §9). `execFileSync` not `execSync` — URLs/paths pass as argv, no shell-quoting
  bugs; still synchronous `node:child_process`, same testing model as 01 step 8.
- **Tests never touch the network.** All git tests use a local bare fixture repo built by
  `mkBareRepoWithTags` (tags `v1.0.0`, `pkg@1.1.0`).
- **`deps sync` updates both ledgers**: on drift it re-clones, rewrites the registry row AND the
  manifest pin (`DependencyPin.version` = "resolved pin at clone time", master §7.1).
- Registry rows sort by package name; serialization is deterministic (master §2.8).

## Out of Scope

`~/.harness/cache/` (master §5 reserves it for dep-clone metadata; shallow clones are cheap enough
to skip caching this phase), the project-`.gitignore` line `.agent/dependencies/*` (04 owns it),
skill authoring, registry *consumption* logic, lockfile-based version resolution.

## Implementation Order

> `[agent]` = boilerplate/pattern-following · `[dev]` = core logic, guided stub named per step

1. `[agent]` Test helper `mkBareRepoWithTags` — local bare repo fixture
2. `[agent]` `git.ts` extensions — `lsRemoteTags`, `shallowCloneAtRef` (+ tests)
3. `[agent]` Registry module `src/lib/depsRegistry.ts` (+ golden tests)
4. `[dev]` Deps helpers — key fns: `readProjectPin`, `resolveTag` (+ `depDirname`, `resolveRepoUrl`)
5. `[dev]` Command runners — key fns: `cloneOne`, `runDeps`; CLI wiring + full tests
6. `[dev]` Doctor check `stale-dependencies`
7. `[agent]` `.gitignore` contract test + fixture registry alignment
8. Verification

---

## Step 1: `mkBareRepoWithTags` test helper `[agent]`

- [ ] Append to `harness/test/helpers.ts` (full code); `bun test` still green

```typescript
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";

/**
 * Builds a local BARE git repo fixture with two commits and two tags:
 * v1.0.0 → lib.ts "export const v = 1;\n"; pkg@1.1.0 (default-branch tip) → "export const v = 2;\n".
 * Stand-in for a network remote — no test in this suite may hit the network.
 * @returns dir - Absolute bare-repo path (usable as DependencyPin.repo); shaByTag - commit sha per tag.
 */
export function mkBareRepoWithTags(): { dir: string; shaByTag: Record<string, string> } {
  const work = mkdtempSync(join(tmpdir(), "harness-dep-work-"));
  const out = mkdtempSync(join(tmpdir(), "harness-dep-bare-"));
  const git = (args: string[]): string =>
    execFileSync("git", ["-C", work, "-c", "user.email=t@t", "-c", "user.name=t", ...args],
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  git(["init", "-b", "main"]);
  writeFileSync(join(work, "lib.ts"), "export const v = 1;\n");
  git(["add", "-A"]); git(["commit", "-m", "one"]); git(["tag", "v1.0.0"]);
  writeFileSync(join(work, "lib.ts"), "export const v = 2;\n");
  git(["add", "-A"]); git(["commit", "-m", "two"]); git(["tag", "pkg@1.1.0"]);
  const shaByTag = {
    "v1.0.0": git(["rev-parse", "v1.0.0^{commit}"]).trim(),
    "pkg@1.1.0": git(["rev-parse", "pkg@1.1.0^{commit}"]).trim(),
  };
  const dir = join(out, "repo.git");
  execFileSync("git", ["clone", "--bare", "--quiet", work, dir], { stdio: "ignore" });
  rmSync(work, { recursive: true, force: true });
  return { dir, shaByTag };
}
```

---

## Step 2: `git.ts` extensions `[agent]`

- [ ] Append both fns to `harness/src/lib/git.ts` (full code — same file, do NOT fork)
- [ ] Append the `describe` block below to `src/lib/git.test.ts`; run tests

```typescript
import { execFileSync } from "node:child_process";
import { mkdirSync, rmSync } from "node:fs";
import { dirname } from "node:path";
import { HarnessError, EXIT } from "./errors.ts";

/** Prefixes file:// on absolute local paths so git honors --depth (06 design decisions). */
function asGitUrl(repoUrl: string): string {
  return repoUrl.startsWith("/") ? `file://${repoUrl}` : repoUrl;
}

/**
 * Lists tag names on a remote via `git ls-remote --tags --refs`.
 * @param props.repoUrl - Clone URL or absolute local path (bare repo ok).
 * @returns Tag names ("refs/tags/" stripped), lexically sorted; [] when the repo has no tags.
 * @throws {HarnessError} code "git-ls-remote-failed" when unreachable/private. Callers decide whether to warn.
 */
export function lsRemoteTags(props: { repoUrl: string }): string[] {
  try {
    const out = execFileSync("git", ["ls-remote", "--tags", "--refs", asGitUrl(props.repoUrl)],
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    return out.split("\n").filter(Boolean)
      .map((l) => (l.split("\t")[1] ?? "").replace("refs/tags/", "")).filter(Boolean).sort();
  } catch (e) {
    throw new HarnessError("git-ls-remote-failed",
      `git ls-remote failed for ${props.repoUrl}: ${(e as Error).message}`, { exitCode: EXIT.FAILURE });
  }
}

/**
 * Shallow-clones (depth 1) a repo at a ref into dest, replacing any existing dest.
 * @param props.repoUrl - Clone URL or absolute local path.
 * @param props.ref - Tag/branch for `--branch`; omit to clone the default branch.
 * @param props.dest - Absolute destination dir (removed first if present).
 * @returns The clone's HEAD commit sha (40 hex).
 * @throws {HarnessError} code "git-clone-failed" on any git failure; dest is removed on failure
 *   so a broken half-clone never survives.
 */
export function shallowCloneAtRef(props: { repoUrl: string; ref?: string; dest: string }): string {
  rmSync(props.dest, { recursive: true, force: true });
  mkdirSync(dirname(props.dest), { recursive: true });
  try {
    execFileSync("git", ["clone", "--quiet", "--depth", "1",
      ...(props.ref ? ["--branch", props.ref] : []), asGitUrl(props.repoUrl), props.dest],
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    return execFileSync("git", ["-C", props.dest, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  } catch (e) {
    rmSync(props.dest, { recursive: true, force: true });
    throw new HarnessError("git-clone-failed",
      `git clone failed for ${props.repoUrl}${props.ref ? ` @ ${props.ref}` : ""}: ${(e as Error).message}`,
      { exitCode: EXIT.FAILURE });
  }
}
```

**Tests** (append to `src/lib/git.test.ts` — full code):

```typescript
describe("deps git helpers (06)", () => {
  const repo = mkBareRepoWithTags();
  const mkDest = () => join(mkdtempSync(join(tmpdir(), "harness-clone-")), "pkg");
  test("lsRemoteTags lists both tags sorted; throws on unreachable repo", () => {
    expect(lsRemoteTags({ repoUrl: repo.dir })).toEqual(["pkg@1.1.0", "v1.0.0"]);
    expect(() => lsRemoteTags({ repoUrl: "/nope/missing.git" })).toThrow(/ls-remote failed/);
  });
  test("shallowCloneAtRef: tag → content + sha + depth 1; no ref → default branch tip", () => {
    const a = mkDest();
    expect(shallowCloneAtRef({ repoUrl: repo.dir, ref: "v1.0.0", dest: a })).toBe(repo.shaByTag["v1.0.0"]!);
    expect(readFileSync(join(a, "lib.ts"), "utf8")).toBe("export const v = 1;\n");
    expect(execFileSync("git", ["-C", a, "rev-list", "--count", "HEAD"], { encoding: "utf8" }).trim()).toBe("1");
    const b = mkDest();
    expect(shallowCloneAtRef({ repoUrl: repo.dir, dest: b })).toBe(repo.shaByTag["pkg@1.1.0"]!);
    expect(readFileSync(join(b, "lib.ts"), "utf8")).toBe("export const v = 2;\n");
  });
  test("bad ref throws git-clone-failed and leaves no dest", () => {
    const dest = mkDest();
    expect(() => shallowCloneAtRef({ repoUrl: repo.dir, ref: "v9.9.9", dest })).toThrow(/clone failed/);
    expect(existsSync(dest)).toBe(false);
  });
});
```

---

## Step 3: Registry module `[agent]`

- [ ] Create `src/lib/depsRegistry.ts` + `src/lib/depsRegistry.test.ts` (full code); run tests

**File: `harness/src/lib/depsRegistry.ts`**

```typescript
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { writeFileAtomic } from "./fsx.ts";
import { P } from "./paths.ts";

/** One row of .agent/dependencies/registry.md. */
export interface RegistryRow {
  package: string;      // name as pinned in the project manifest
  version: string;      // version the clone targeted
  repo: string;         // DependencyPin.repo verbatim
  clonedAtSha: string;  // clone HEAD sha; "<sha> (no tag match)" when default branch was used
}

const HEADER = `# Dependency Source Clones

> GENERATED by \`harness deps\` — clone directories are gitignored; this registry is committed.
> Skills read this table before specs/implementation to consult real source at the pinned version.

| package | version | repo | cloned_at_sha |
| --- | --- | --- | --- |
`;

/**
 * Serializes rows to registry.md (sorted by package — deterministic).
 * @param props.rows - Rows in any order.
 * @returns Full file content, trailing newline included.
 */
export function serializeRegistry(props: { rows: RegistryRow[] }): string {
  const rows = [...props.rows].sort((a, b) => a.package.localeCompare(b.package));
  return HEADER + rows.map((r) => `| ${r.package} | ${r.version} | ${r.repo} | ${r.clonedAtSha} |\n`).join("");
}

/**
 * Parses registry.md tolerantly: only 4-cell `| a | b | c | d |` body rows count; header,
 * separator, prose, and malformed rows are skipped (never throws — hand-edits must not brick doctor).
 * @param props.text - File content.
 * @returns Rows in file order.
 */
export function parseRegistry(props: { text: string }): RegistryRow[] {
  const rows: RegistryRow[] = [];
  for (const line of props.text.split("\n")) {
    if (!line.startsWith("|")) continue;
    const cells = line.replace(/^\|/, "").replace(/\|\s*$/, "").split("|").map((c) => c.trim());
    if (cells.length !== 4 || cells[0] === "package" || cells[0] === "---") continue;
    rows.push({ package: cells[0]!, version: cells[1]!, repo: cells[2]!, clonedAtSha: cells[3]! });
  }
  return rows;
}

/** Loads the registry. @param props.root - Project root. @returns Rows; [] when file absent. */
export function loadRegistry(props: { root: string }): RegistryRow[] {
  try { return parseRegistry({ text: readFileSync(join(props.root, P.depsRegistry), "utf8") }); }
  catch { return []; }
}

/** Writes the registry atomically. @param props.root - Project root. @param props.rows - Rows to persist. @returns Nothing. */
export function saveRegistry(props: { root: string; rows: RegistryRow[] }): void {
  writeFileAtomic({ path: join(props.root, P.depsRegistry), content: serializeRegistry({ rows: props.rows }) });
}
```

**File: `harness/src/lib/depsRegistry.test.ts`** — full code; the golden string is exact:

```typescript
import { describe, expect, test } from "bun:test";
import { parseRegistry, serializeRegistry } from "./depsRegistry.ts";

const rows = [
  { package: "zod", version: "3.23.8", repo: "github.com/colinhacks/zod", clonedAtSha: "a".repeat(40) },
  { package: "convex", version: "1.17.4", repo: "github.com/get-convex/convex-backend", clonedAtSha: `${"b".repeat(40)} (no tag match)` },
];
const GOLDEN = `# Dependency Source Clones

> GENERATED by \`harness deps\` — clone directories are gitignored; this registry is committed.
> Skills read this table before specs/implementation to consult real source at the pinned version.

| package | version | repo | cloned_at_sha |
| --- | --- | --- | --- |
| convex | 1.17.4 | github.com/get-convex/convex-backend | ${"b".repeat(40)} (no tag match) |
| zod | 3.23.8 | github.com/colinhacks/zod | ${"a".repeat(40)} |
`;

describe("depsRegistry", () => {
  test("serialize sorts by package and matches golden", () => {
    expect(serializeRegistry({ rows })).toBe(GOLDEN);
  });
  test("parse(serialize(x)) round-trips; header-only → []", () => {
    expect(parseRegistry({ text: GOLDEN })).toEqual([rows[1]!, rows[0]!]);
    expect(parseRegistry({ text: serializeRegistry({ rows: [] }) })).toEqual([]);
  });
  test("malformed rows are skipped, not thrown", () => {
    expect(parseRegistry({ text: "| broken |\nprose\n| a | b | c | d |\n" }))
      .toEqual([{ package: "a", version: "b", repo: "c", clonedAtSha: "d" }]);
  });
});
```

---

## Step 4: Deps helpers `[dev]`

- [ ] Create `src/commands/deps.ts` (helpers below; runners land in Step 5) +
      `src/commands/deps.test.ts` with the helper tests; run tests

**File: `harness/src/commands/deps.ts`** (first half)

```typescript
import { HarnessError } from "../lib/errors.ts";
import { lsRemoteTags } from "../lib/git.ts";

/**
 * Maps a package name to its clone dirname: strip leading "@", "/" → "__" (fs-safe, collision-free).
 * @param props.pkg - Package name, e.g. "@tanstack/form".
 * @returns Dirname, e.g. "tanstack__form".
 * @example depDirname({ pkg: "convex" }) // "convex"
 */
export function depDirname(props: { pkg: string }): string {
  return props.pkg.replace(/^@/, "").replaceAll("/", "__");
}

/**
 * Resolves DependencyPin.repo to a cloneable URL.
 * @param props.repo - Host-relative ("github.com/org/repo"), full URL, or absolute local path.
 * @returns https://-prefixed URL, or the explicit/local form verbatim.
 */
export function resolveRepoUrl(props: { repo: string }): string {
  return props.repo.includes("://") || props.repo.startsWith("/") ? props.repo : `https://${props.repo}`;
}

/**
 * Reads the version currently pinned for a package in the PROJECT manifest (not .agent/).
 * Sources in order: package.json dependencies/devDependencies, Cargo.toml, pyproject.toml.
 * @param props.root - Project root. @param props.pkg - Name as it appears in that manifest.
 * @returns Version substring of the pin ("^1.1.0" → "1.1.0"), or null when not found or the
 *   value has no version substring ("workspace:*", "*", git URLs).
 */
export function readProjectPin(props: { root: string; pkg: string }): string | null {
  // TODO: implement
  // 1. package.json: JSON.parse; dependencies then devDependencies[pkg]; value → first
  //    /\d+\.\d+(?:\.\d+)?/ match → return; no match → keep looking in the next manifest
  //    (a "workspace:*" entry must not shadow a Cargo pin).
  // 2. Cargo.toml (only when pkg has no "/" — scoped npm names never appear here): line regex
  //    /^\s*<esc(pkg)>\s*=\s*(?:"([^"]+)"|\{[^}]*version\s*=\s*"([^"]+)")/m → version substring.
  // 3. pyproject.toml (same "/" guard): /"<esc(pkg)>\s*[=><~!^]{1,2}=?\s*([^",]+)"/ → substring.
  // 4. Nothing found → null.
  // Edge cases: unreadable/unparseable manifest → skip silently, never throw (doctor must survive
  // broken projects); ranges (">=1.1.0 <2", "~2.0.1") reduce to the FIRST substring.
  throw new Error("Not implemented");
}

/**
 * Resolves the tag to clone for pkg@version (candidate order per proposal §9).
 * @param props.repoUrl - Cloneable URL. @param props.pkg - Package name.
 * @param props.version - Version substring, e.g. "1.1.0".
 * @returns Matching tag name, or null when nothing matches (caller clones the default branch).
 * @throws {HarnessError} propagated "git-ls-remote-failed" — caller decides warn-vs-fail.
 */
export function resolveTag(props: { repoUrl: string; pkg: string; version: string }): string | null {
  // TODO: implement
  // 1. tags = lsRemoteTags({ repoUrl }) (throws → propagate untouched).
  // 2. candidates = [`v${version}`, version, `${pkg}@${version}`]; if pkg contains "/", also
  //    `${basename(pkg)}@${version}` ("@tanstack/form" → "form@1.1.0"). First one ∈ tags → return.
  // 3. Fallback: matches = tags.filter(t => t.endsWith(`@${version}`) || t.endsWith(`-${version}`));
  //    exactly ONE → return it; zero or 2+ → null (never guess between monorepo packages).
  // Edge cases: tagless repo → [] → null (NOT an error); "1.2"-style versions used verbatim.
  throw new Error("Not implemented");
}
```

**Helper tests** (start `src/commands/deps.test.ts` — full code; file grows in Steps 5/7):

```typescript
import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { gitInit, mkBareRepoWithTags, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { depDirname, readProjectPin, resolveRepoUrl, resolveTag } from "./deps.ts";

const repo = mkBareRepoWithTags();

describe("depDirname / resolveRepoUrl", () => {
  test("mappings", () => {
    expect(depDirname({ pkg: "convex" })).toBe("convex");
    expect(depDirname({ pkg: "@tanstack/form" })).toBe("tanstack__form");
    expect(resolveRepoUrl({ repo: "github.com/colinhacks/zod" })).toBe("https://github.com/colinhacks/zod");
    expect(resolveRepoUrl({ repo: "git://x/y" })).toBe("git://x/y");
    expect(resolveRepoUrl({ repo: "/abs/bare.git" })).toBe("/abs/bare.git");
  });
});

describe("readProjectPin", () => {
  test("package.json ranges, Cargo.toml plain + table forms, pyproject specifiers", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    writeFileSync(join(dir, "package.json"), JSON.stringify({
      name: "x", dependencies: { pkg: "^1.1.0", linked: "workspace:*" },
      devDependencies: { "dev-pkg": "~2.0.1" },
    }));
    writeFileSync(join(dir, "Cargo.toml"),
      `[dependencies]\ntokio = "1.47.1"\nserde = { version = "1.0.219", features = ["derive"] }\n`);
    writeFileSync(join(dir, "pyproject.toml"),
      `[project]\ndependencies = ["fastapi>=0.115.0", "pydantic==2.9.2"]\n`);
    expect(readProjectPin({ root: dir, pkg: "pkg" })).toBe("1.1.0");
    expect(readProjectPin({ root: dir, pkg: "dev-pkg" })).toBe("2.0.1");
    expect(readProjectPin({ root: dir, pkg: "linked" })).toBeNull();  // no version substring
    expect(readProjectPin({ root: dir, pkg: "absent" })).toBeNull();
    expect(readProjectPin({ root: dir, pkg: "tokio" })).toBe("1.47.1");
    expect(readProjectPin({ root: dir, pkg: "serde" })).toBe("1.0.219");
    expect(readProjectPin({ root: dir, pkg: "fastapi" })).toBe("0.115.0");
    expect(readProjectPin({ root: dir, pkg: "pydantic" })).toBe("2.9.2");
    rmProject({ dir });
  });
});

describe("resolveTag", () => {
  test("candidate order and fallback", () => {
    expect(resolveTag({ repoUrl: repo.dir, pkg: "pkg", version: "1.0.0" })).toBe("v1.0.0");
    expect(resolveTag({ repoUrl: repo.dir, pkg: "pkg", version: "1.1.0" })).toBe("pkg@1.1.0");
    expect(resolveTag({ repoUrl: repo.dir, pkg: "other", version: "1.1.0" })).toBe("pkg@1.1.0"); // unique @-suffix scan
    expect(resolveTag({ repoUrl: repo.dir, pkg: "pkg", version: "9.9.9" })).toBeNull();
  });
});
```

---

## Step 5: Command runners + CLI wiring `[dev]`

- [ ] Add `DEP_GITIGNORE`, `cloneOne`, `runDeps` to `src/commands/deps.ts`; register `deps` in the
      `cli.ts` command table (help: `deps clone|sync|add|remove|list — dependency source clones`)
- [ ] Extend `deps.test.ts` with the command tests; run tests

`export const DEP_GITIGNORE = "*\n!.gitignore\n!registry.md\n";` (same content 01's scaffold
writes). Add the needed imports to `deps.ts`: `DependencyPin` (lib/manifest), `RegistryRow` +
`loadRegistry`/`saveRegistry` (lib/depsRegistry), `Reporter` (lib/output), `shallowCloneAtRef`
(lib/git), `P`/`resolveProjectRoot` (lib/paths), `parseArgs`, node:fs.

```typescript
/**
 * Clones one pinned dependency at its best-matching tag. Never throws for repo problems — warns
 * via the reporter and returns null so a batch run always completes (proposal §9).
 * @param props.root - Project root. @param props.pin - DependencyPin (package, version, repo).
 * @param props.reporter - Sink for ok/warn lines.
 * @returns The new registry row, or null when the repo was unreachable.
 */
export function cloneOne(props: { root: string; pin: DependencyPin; reporter: Reporter }): RegistryRow | null {
  // TODO: implement
  // 1. url = resolveRepoUrl({ repo: pin.repo }); dest = join(root, P.dependencies, depDirname({ pkg })).
  // 2. Ensure <P.dependencies>/.gitignore exists with DEP_GITIGNORE (write only when missing —
  //    01's scaffold normally created it; clone self-heals).
  // 3. try { tag = resolveTag(…); sha = shallowCloneAtRef({ repoUrl: url, ref: tag ?? undefined, dest }) }
  //    catch HarnessError → reporter.warn(`${pkg}: ${e.message} — skipped`, "deps-clone") → null.
  //    (Covers private/unreachable repos for both ls-remote and clone.)
  // 4. tag ? reporter.ok(`${pkg} ${version} cloned at ${tag}`)
  //        : reporter.warn(`${pkg}: no tag matches ${version} — cloned default branch`, "deps-clone",
  //            `verify ${P.dependencies}/${depDirname({ pkg })} manually`)
  // 5. return { package: pkg, version: pin.version, repo: pin.repo,
  //             clonedAtSha: tag ? sha : `${sha} (no tag match)` }
  // Edge cases: existing dest → shallowCloneAtRef rm-rf's it (re-clone is idempotent); a tagless
  // repo is the step-4 warn path, not a git failure.
  throw new Error("Not implemented");
}

/**
 * `harness deps <clone|sync|add|remove|list>` dispatcher (wired into the cli.ts table).
 * @param props.args - Tokens after "deps". @param props.cwd - Working directory.
 * @param props.stdout - Line sink. @param props.stderr - Error sink.
 * @returns EXIT code: OK on success (warnings included), USAGE on bad invocation/unknown package.
 */
export async function runDeps(props: { args: string[]; cwd: string; stdout: (s: string) => void; stderr: (s: string) => void }): Promise<number> {
  // TODO: implement
  // 1. root = resolveProjectRoot; manifest = loadManifest; rows = loadRegistry. sub = args[0];
  //    missing/unknown → HarnessError("usage", "deps: clone|sync|add|remove|list"). parseArgs:
  //    clone/sync { positionals: ["...rest"] } (0/1 pkg); add { positionals: ["package"],
  //    options: ["repo", "version"] }; remove { positionals: ["package"] }; list { flags: ["json"] }.
  // 2. clone [<pkg>]: pins = manifest.dependencies (filtered when named; named-but-unpinned →
  //    HarnessError("dep-unknown", …, hint "harness deps add <pkg> --repo <url>")). Empty → info
  //    "(no dependencies pinned)". Each: cloneOne → row ? upsert into rows : keep old row. saveRegistry.
  // 3. sync [<pkg>]: targets = rows (named row absent → dep-unknown). Each row:
  //    pin = readProjectPin → null → info `${pkg}: no project pin — skipped`;
  //    pin === row.version → ok `${pkg} up to date (${pin})`; drift → cloneOne with
  //    { package, repo: row.repo, version: pin } → on success replace row AND set matching
  //    manifest.dependencies[].version = pin. Save registry + manifest only when changed.
  // 4. add <pkg> --repo <url> [--version <v>]: already pinned → HarnessError("dep-exists", …,
  //    hint "harness deps sync <pkg>"). version = --version ?? readProjectPin ?? throw
  //    HarnessError("dep-version-unknown", `${pkg}: not in the project manifest — pass --version`).
  //    cloneOne → null → record NOTHING (failed add must not leave a dead pin), OK with warn;
  //    row → push pin to manifest.dependencies + saveManifest, upsert + saveRegistry.
  // 5. remove <pkg>: in neither registry nor manifest.dependencies → dep-unknown. rmSync clone
  //    dir (force), drop registry row + manifest pin, save both, ok line.
  // 6. list: rows empty → stdout "(no dependencies registered)"; else serializeRegistry output
  //    from its "| package |" line onward (table only). One Reporter per run; flush before return.
  throw new Error("Not implemented");
}
```

**Command tests** (append to `deps.test.ts` — full code; `setDeps`/`readManifestDeps` are local utils):

```typescript
function setDeps(dir: string, deps: object[]): void {
  const p = join(dir, ".agent", "manifest.json");
  const m = JSON.parse(readFileSync(p, "utf8"));
  m.dependencies = deps;
  writeFileSync(p, JSON.stringify(m, null, 2) + "\n");
}
const readManifestDeps = (dir: string) =>
  JSON.parse(readFileSync(join(dir, ".agent", "manifest.json"), "utf8")).dependencies;

describe("harness deps", () => {
  test("clone: tag match, tree content, registry row", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setDeps(dir, [{ package: "pkg", version: "1.1.0", repo: repo.dir }]);
    expect((await runCli({ argv: ["deps", "clone"], cwd: dir })).code).toBe(0);
    expect(readFileSync(join(dir, ".agent/dependencies/pkg/lib.ts"), "utf8")).toBe("export const v = 2;\n");
    expect(readFileSync(join(dir, ".agent/dependencies/registry.md"), "utf8"))
      .toContain(`| pkg | 1.1.0 | ${repo.dir} | ${repo.shaByTag["pkg@1.1.0"]} |`);
    rmProject({ dir });
  });
  test("clone edge batch: unreachable repo warns + continues; no tag match → default branch + '(no tag match)'", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setDeps(dir, [
      { package: "gone", version: "1.0.0", repo: "/nope/missing.git" },
      { package: "pkg", version: "9.9.9", repo: repo.dir },
    ]);
    const r = await runCli({ argv: ["deps", "clone"], cwd: dir });
    expect(r.code).toBe(0); // never fails the whole run
    expect(r.stdout).toContain("gone:");
    expect(r.stdout).toContain("no tag match");
    const reg = readFileSync(join(dir, ".agent/dependencies/registry.md"), "utf8");
    expect(reg).not.toContain("| gone |");
    expect(reg).toContain(`| pkg | 9.9.9 | ${repo.dir} | ${repo.shaByTag["pkg@1.1.0"]} (no tag match) |`);
    expect(readFileSync(join(dir, ".agent/dependencies/pkg/lib.ts"), "utf8")).toBe("export const v = 2;\n");
    rmProject({ dir });
  });
  test("add: version defaults from package.json; errors without any version source", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "x", dependencies: { pkg: "^1.0.0" } }));
    expect((await runCli({ argv: ["deps", "add", "pkg", "--repo", repo.dir], cwd: dir })).code).toBe(0);
    expect(readManifestDeps(dir)).toEqual([{ package: "pkg", version: "1.0.0", repo: repo.dir }]);
    const bad = await runCli({ argv: ["deps", "add", "mystery", "--repo", repo.dir], cwd: dir });
    expect(bad.code).toBe(2);
    expect(bad.stderr).toContain("--version");
    rmProject({ dir });
  });
  test("sync: drift re-clones, updates registry + manifest; second run is a no-op", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setDeps(dir, [{ package: "pkg", version: "1.0.0", repo: repo.dir }]);
    await runCli({ argv: ["deps", "clone"], cwd: dir });
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "x", dependencies: { pkg: "^1.1.0" } }));
    expect((await runCli({ argv: ["deps", "sync"], cwd: dir })).code).toBe(0);
    expect(readFileSync(join(dir, ".agent/dependencies/pkg/lib.ts"), "utf8")).toBe("export const v = 2;\n");
    expect(readFileSync(join(dir, ".agent/dependencies/registry.md"), "utf8")).toContain("| pkg | 1.1.0 |");
    expect(readManifestDeps(dir)[0].version).toBe("1.1.0");
    expect((await runCli({ argv: ["deps", "sync"], cwd: dir })).stdout).toContain("up to date");
    rmProject({ dir });
  });
  test("remove deletes clone dir + registry row + manifest pin; list reflects it", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setDeps(dir, [{ package: "pkg", version: "1.0.0", repo: repo.dir }]);
    await runCli({ argv: ["deps", "clone"], cwd: dir });
    expect((await runCli({ argv: ["deps", "list"], cwd: dir })).stdout).toContain("| pkg | 1.0.0 |");
    expect((await runCli({ argv: ["deps", "remove", "pkg"], cwd: dir })).code).toBe(0);
    expect(existsSync(join(dir, ".agent/dependencies/pkg"))).toBe(false);
    expect(readManifestDeps(dir)).toEqual([]);
    expect((await runCli({ argv: ["deps", "list"], cwd: dir })).stdout).toContain("(no dependencies registered)");
    expect((await runCli({ argv: ["deps", "remove", "pkg"], cwd: dir })).code).toBe(2);
    rmProject({ dir });
  });
  test("no subcommand exits 2 listing subcommands; clone of unpinned name exits 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["deps"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("clone|sync|add|remove|list");
    expect((await runCli({ argv: ["deps", "clone", "nope"], cwd: dir })).code).toBe(2);
    rmProject({ dir });
  });
});
```

---

## Step 6: Doctor check `stale-dependencies` `[dev]`

- [ ] Create `src/checks/stale-dependencies.ts` + `src/checks/stale-dependencies.test.ts`;
      register in `doctor.ts`'s static list; run tests

Contract (01 step 13 style — implement `run` from it, ~15 lines):

- **id** `stale-dependencies` · **severity** `info` · **appliesWhen**: `loadRegistry` returns ≥1 row.
- Per registry row, in row order: clone dir `join(P.dependencies, depDirname({ pkg }))` missing →
  finding `registry: <pkg> registered but clone missing`, hint `harness deps clone <pkg>`. Else
  `pin = readProjectPin({ root, pkg })`; `pin !== null && pin !== row.version` → finding
  `registry: <pkg> cloned at <row.version>, project pins <pin>`, hint `harness deps sync <pkg>`
  (`pin === null` → no finding — reference-only clones not in the project manifest are legitimate).
- Imports `depDirname`/`readProjectPin` from `../commands/deps.ts`, `loadRegistry` from
  `../lib/depsRegistry.ts` — no duplicated logic.

**Test** (full code):

```typescript
import { describe, expect, test } from "bun:test";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { saveRegistry } from "../lib/depsRegistry.ts";

const row = (pkg: string, v: string) => ({ package: pkg, version: v, repo: `github.com/x/${pkg}`, clonedAtSha: "c".repeat(40) });
const findings = (stdout: string) => JSON.parse(stdout)
  .filter((i: { id?: string; level: string }) => i.id === "stale-dependencies" && i.level !== "ok");

describe("stale-dependencies", () => {
  test("drift → info + sync hint; missing clone dir → info + clone hint", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    saveRegistry({ root: dir, rows: [row("pkg", "1.0.0"), row("lost", "2.0.0")] });
    mkdirSync(join(dir, ".agent/dependencies/pkg"), { recursive: true }); // "lost" has no clone dir
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "x", dependencies: { pkg: "^1.1.0" } }));
    const f = findings((await runCli({ argv: ["doctor", "--json"], cwd: dir })).stdout);
    expect(f).toEqual([
      { level: "info", id: "stale-dependencies", message: "registry: lost registered but clone missing", hint: "harness deps clone lost" },
      { level: "info", id: "stale-dependencies", message: "registry: pkg cloned at 1.0.0, project pins 1.1.0", hint: "harness deps sync pkg" },
    ]);
    rmProject({ dir });
  });
  test("matching pin + present clone, and unpinned reference clones → no findings", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    saveRegistry({ root: dir, rows: [row("pkg", "1.1.0"), row("ref-only", "2.0.0")] });
    mkdirSync(join(dir, ".agent/dependencies/pkg"), { recursive: true });
    mkdirSync(join(dir, ".agent/dependencies/ref-only"), { recursive: true });
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "x", dependencies: { pkg: "1.1.0" } }));
    expect(findings((await runCli({ argv: ["doctor", "--json"], cwd: dir })).stdout)).toEqual([]);
    rmProject({ dir });
  });
});
```

---

## Step 7: `.gitignore` contract + fixture alignment `[agent]`

- [ ] Update `test/fixtures/initialized/.agent/dependencies/registry.md` to be byte-identical to
      `serializeRegistry({ rows: [] })` (01 seeded it as "header only"; pin the golden now)
- [ ] Append the test below to `deps.test.ts`; full suite green

```typescript
describe(".agent/dependencies/.gitignore contract", () => {
  test("clone (self-)writes the 01 contract; git ignores clone dirs but not registry.md", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    setDeps(dir, [{ package: "pkg", version: "1.0.0", repo: repo.dir }]);
    await runCli({ argv: ["deps", "clone"], cwd: dir });
    expect(readFileSync(join(dir, ".agent/dependencies/.gitignore"), "utf8"))
      .toBe("*\n!.gitignore\n!registry.md\n");
    // clone dir ignored (check-ignore exits 0)…
    execFileSync("git", ["-C", dir, "check-ignore", ".agent/dependencies/pkg"], { stdio: "ignore" });
    // …registry.md NOT ignored (check-ignore exits 1 → throws)
    expect(() => execFileSync("git", ["-C", dir, "check-ignore", ".agent/dependencies/registry.md"],
      { stdio: "ignore" })).toThrow();
    rmProject({ dir });
  });
});
```

Skills note (no action this phase): dev-spec (02) and implement (05) already instruct agents to
check `registry.md` before working against a cloned dep; `deps list` gives humans the same view.

## Verification (mandatory)

- [ ] `cd harness && bun test` — all green, including all pre-06 suites (git.ts changes are additive)
- [ ] `bunx tsc --noEmit` — clean
- [ ] Manual smoke in a scratch copy of `test/fixtures/initialized`: `harness deps add zod --repo
      github.com/colinhacks/zod --version 3.23.8` (network ok manually, never in tests) → tree under
      `.agent/dependencies/zod/`, `deps list` shows the row, `doctor` exits 0; bump the pin in
      package.json → doctor prints the info finding → `deps sync zod` clears it; `deps remove zod`
      leaves only `.gitignore` + `registry.md`
- [ ] `deps clone` twice → second registry byte-identical (idempotent)

## Success Criteria

- [ ] `deps clone` resolves `v<version>`, bare `<version>`, and `<pkg>@<version>` tags against the
      local fixture repo; tests assert cloned tree content and depth-1 history
- [ ] No-tag-match falls back to the default branch with `<sha> (no tag match)` recorded plus a
      warn; an unreachable repo warns and never fails the batch (exit 0)
- [ ] `registry.md` matches the golden serialization exactly; parse/serialize round-trips
- [ ] `add`/`remove`/`sync` keep `manifest.json#dependencies`, `registry.md`, and clone dirs
      mutually consistent in every test
- [ ] `stale-dependencies` reports drift and missing clones as info findings with exact hints, and
      stays silent for reference-only clones
- [ ] `.agent/dependencies/.gitignore` contract verified against real git (`check-ignore`)
