# 08 — Integration, Worktree, Cascade, Migration Runbook

> Phase spec 8 of 8 — the capstone. Prereq: read `00-master.md` fully (§2 conventions and §7
> schemas are binding) and have specs 01–07 implemented and green. Wires `tasks.md` into the
> skill flow, ships `harness worktree` + the shared cascade-checks reference, adds the suite's
> end-to-end smoke test, and defines the migration runbook that retires the old harness trees.

## Overview

Four code deliverables: (1) a `tasksFile` lib + `harness tasks add|move` so skills stop
hand-editing `docs/tasks.md`; (2) `harness worktree <feature>` for `repo.type:
"bare-git-worktrees"` projects; (3) `shared-references/cascade-checks.md` (proposal §10's cascade
table as an actionable checklist) plus one-line pointers from the dev-spec and sync-spec skills;
(4) the e2e smoke test running the whole CLI surface cold on a fresh temp repo. Finally, §Runbook
is a human/agent-executed migration procedure — **not code** — for dotfiles, maprios, and vex.

## Design Decisions

- **D08-1 Section ids.** `harness tasks` addresses sections by stable kebab ids `in-progress`,
  `inbox`, `done`, mapped to headings `## In Progress`, `## Inbox`, `## Recently Done` (the exact
  headings 01's scaffold writes into `tasks.md`). The heading strings never appear in skill text
  again — only the CLI ids do.
- **D08-2 Tolerant tasks parser.** Unknown `## ` sections in `tasks.md` are preserved verbatim and
  never targeted. Missing canonical sections are recreated in canonical order on write. Items are
  `- ` lines; everything else in a section is preserved as-is.
- **D08-3 Move is idempotent.** Moving a task already in the target section is a no-op success
  (skills re-run steps; re-runs must not error).
- **D08-4 Git is real, tmux is injected.** `worktree` runs real `git worktree add` (tests use a
  local git fixture); the tmux window is created via an injected `tmuxSpawn` so tests never touch
  tmux, and only when `$TMUX` is set.
- **D08-5 Worktree path convention.** New worktrees are **siblings of the project root**
  (`<root>/../<feature>`) — matches the bare-repo layout `maprios-app.git/{dev,<feature>}`.
  `--path` overrides.
- **D08-6 `shared-references/` is not a skill.** It ships under `src/templates/skills/` and is
  copied by 01's scaffold like any skill dir, but has no `SKILL.md` — OMP, Claude Code, and the
  `skill-over-budget` check all ignore it. Skills load it by path:
  `.agent/skills/shared-references/cascade-checks.md`.
- **D08-7 The runbook is executed, not implemented.** It runs AFTER `bun test` + `tsc` are green
  across specs 01–08, with an explicit developer confirmation before every deletion; nothing in
  it is automated beyond existing `harness` commands.

## Out of Scope

`harness upgrade`, standalone binaries, new platform adapters (master §1), tmux layout management
beyond one `new-window`, migrating the checked-in Python venv (`pi-agent-base/skills/
excalidraw-diagram/references/.venv` — deleted, never moved).

## Implementation Order

> `[agent]` = boilerplate/pattern-following · `[dev]` = core logic, guided stub named per step

1. `[dev]` `tasksFile` lib — key fns: `parseTasksFile`, `serializeTasksFile`, `moveTask`
2. `[agent]` `harness tasks add|move` command
3. `[agent]` Skill template edits — tasks.md wiring (dev-spec, sync-spec, commit, implement)
4. `[agent]` `shared-references/cascade-checks.md` + skill pointers
5. `[dev]` `harness worktree <feature>` — key fn: `worktreeAdd`
6. `[agent]` End-to-end smoke test (`test/e2e.test.ts`)
7. Verification, then the Migration Runbook

---

## Step 1: `tasksFile` lib `[dev]`

- [ ] Create `src/lib/tasksFile.ts` + `src/lib/tasksFile.test.ts`; run tests

**File: `harness/src/lib/tasksFile.ts`**

```typescript
import { HarnessError } from "./errors.ts";

/** Stable CLI ids for the three canonical sections (D08-1). */
export const TASK_SECTIONS = ["in-progress", "inbox", "done"] as const;
export type TaskSectionId = (typeof TASK_SECTIONS)[number];

/** id → exact heading text written by 01's scaffold. */
export const SECTION_HEADINGS: Record<TaskSectionId, string> = {
  "in-progress": "## In Progress",
  inbox: "## Inbox",
  done: "## Recently Done",
};

export interface TasksSection {
  /** Canonical id, or null for an unknown user section (preserved, never targeted). */
  id: TaskSectionId | null;
  /** Exact heading line, e.g. "## In Progress". */
  heading: string;
  /** Task lines starting with "- ", verbatim (including the "- "). */
  items: string[];
  /** Non-item, non-blank lines inside the section, verbatim, in order (D08-2). */
  extra: string[];
}

export interface TasksDoc {
  /** Everything before the first "## " line, verbatim ("" if none). */
  preamble: string;
  sections: TasksSection[];
}

/**
 * Parses .agent/docs/tasks.md into sections (D08-2 tolerance rules).
 *
 * @param props.text - Full tasks.md content.
 * @returns Parsed doc; canonical sections recognized by exact heading match.
 * @throws Never — unknown content is preserved, not rejected.
 */
export function parseTasksFile(props: { text: string }): TasksDoc {
  // TODO: implement
  //
  // 1. Split into lines. Accumulate preamble until the first line starting "## ".
  // 2. Each "## " line starts a section: id = reverse lookup in SECTION_HEADINGS
  //    (exact string match on the trimmed-right line) else null; heading = the line verbatim.
  // 3. Within a section: lines starting "- " → items; blank lines dropped (serializer
  //    re-normalizes); anything else → extra.
  // 4. Return { preamble, sections } in source order.
  //
  // Edge cases:
  // - empty text → { preamble: "", sections: [] }
  // - duplicate canonical heading → first wins the id; later duplicates get id null (never
  //   silently merged — doctor territory, not ours)
  throw new Error("Not implemented");
}

/**
 * Serializes a TasksDoc back to markdown. Canonical sections are emitted in canonical order
 * (in-progress, inbox, done) with any missing one recreated empty; unknown sections follow in
 * their original order. Layout per section: heading, extra lines, items, one blank line.
 *
 * @param props.doc - Parsed/modified doc.
 * @returns Full file text ending in exactly one trailing newline.
 */
export function serializeTasksFile(props: { doc: TasksDoc }): string {
  // TODO: implement
  //
  // 1. Emit preamble (trimmed of trailing blank lines, then one blank line) when non-empty.
  // 2. Emit the three canonical sections in TASK_SECTIONS order, sourcing each from doc when
  //    present (first match) else as heading + no items.
  // 3. Emit remaining sections (id null / duplicates) verbatim in source order.
  // 4. Sections separated by exactly one blank line; file ends "\n".
  //
  // Edge case: round-trip stability — serialize(parse(serialize(x))) === serialize(x).
  throw new Error("Not implemented");
}

/**
 * Appends a task to a section.
 *
 * @param props.doc - Doc to mutate.
 * @param props.title - Task title (no leading "- ").
 * @param props.section - Target section id.
 * @returns Nothing (mutates doc; missing section is created per D08-2).
 */
export function addTask(props: { doc: TasksDoc; title: string; section: TaskSectionId }): void {
  // TODO: implement — find-or-create the canonical section, push `- ${props.title}`.
  throw new Error("Not implemented");
}

export type MoveResult = { line: string; from: TaskSectionId | null; noop: boolean };

/**
 * Moves the task whose line contains titleSubstr (case-insensitive) to the target section.
 *
 * @param props.doc - Doc to mutate.
 * @param props.titleSubstr - Substring matched against item lines across ALL sections.
 * @param props.to - Target section id.
 * @returns The moved line, its source section, and noop=true when it was already there (D08-3).
 * @throws {HarnessError} "task-not-found" (0 matches, hint "harness tasks add") ·
 *   "task-ambiguous" (2+ matches; message lists every matching line).
 */
export function moveTask(props: {
  doc: TasksDoc; titleSubstr: string; to: TaskSectionId;
}): MoveResult {
  // TODO: implement
  //
  // 1. Collect (section, index, line) for every item line whose lowercase contains
  //    props.titleSubstr.toLowerCase(). Search canonical AND unknown sections (a task may sit
  //    in a user-added section; it can still be moved OUT of it).
  // 2. 0 matches → task-not-found; 2+ → task-ambiguous listing the lines.
  // 3. Match already in target section → { line, from: to, noop: true } — no mutation.
  // 4. Splice out of source items, push onto target (find-or-create), return result.
  throw new Error("Not implemented");
}
```

**File: `harness/src/lib/tasksFile.test.ts`** — full code:

```typescript
import { describe, expect, test } from "bun:test";
import { addTask, moveTask, parseTasksFile, serializeTasksFile } from "./tasksFile.ts";

const SCAFFOLD = "## In Progress\n\n## Inbox\n\n## Recently Done\n";
const SAMPLE = `# Tasks

## In Progress
- Wire tasks into skills

## Inbox
- Fix doctor perf
- Write worktree docs

## Someday
- Rewrite everything

## Recently Done
- Ship spec 07
`;

describe("parse/serialize", () => {
  test("scaffold round-trips byte-exact", () => {
    expect(serializeTasksFile({ doc: parseTasksFile({ text: SCAFFOLD }) })).toBe(SCAFFOLD);
  });
  test("sample parses: ids, items, unknown section preserved", () => {
    const doc = parseTasksFile({ text: SAMPLE });
    expect(doc.preamble).toContain("# Tasks");
    expect(doc.sections.map((s) => s.id)).toEqual(["in-progress", "inbox", null, "done"]);
    expect(doc.sections[1]!.items).toEqual(["- Fix doctor perf", "- Write worktree docs"]);
  });
  test("unknown section survives serialize after canonical ones", () => {
    const out = serializeTasksFile({ doc: parseTasksFile({ text: SAMPLE }) });
    expect(out.indexOf("## Someday")).toBeGreaterThan(out.indexOf("## Recently Done"));
    expect(out).toContain("- Rewrite everything");
  });
  test("missing canonical section recreated empty", () => {
    const out = serializeTasksFile({ doc: parseTasksFile({ text: "## Inbox\n- x\n" }) });
    expect(out).toContain("## In Progress");
    expect(out).toContain("## Recently Done");
    expect(out.endsWith("\n")).toBe(true);
  });
});

describe("addTask / moveTask", () => {
  test("add appends to inbox", () => {
    const doc = parseTasksFile({ text: SCAFFOLD });
    addTask({ doc, title: "New idea", section: "inbox" });
    expect(serializeTasksFile({ doc })).toContain("## Inbox\n- New idea");
  });
  test("move by case-insensitive substring", () => {
    const doc = parseTasksFile({ text: SAMPLE });
    const r = moveTask({ doc, titleSubstr: "doctor PERF", to: "in-progress" });
    expect(r).toEqual({ line: "- Fix doctor perf", from: "inbox", noop: false });
    expect(doc.sections[0]!.items).toContain("- Fix doctor perf");
  });
  test("move out of an unknown section works", () => {
    const doc = parseTasksFile({ text: SAMPLE });
    expect(moveTask({ doc, titleSubstr: "rewrite", to: "inbox" }).from).toBe(null);
  });
  test("already in target → noop success", () => {
    const doc = parseTasksFile({ text: SAMPLE });
    expect(moveTask({ doc, titleSubstr: "Ship spec", to: "done" }).noop).toBe(true);
  });
  test("not found throws with add hint; ambiguous lists matches", () => {
    const doc = parseTasksFile({ text: SAMPLE });
    expect(() => moveTask({ doc, titleSubstr: "nope", to: "done" })).toThrow(/task-not-found|not found/i);
    expect(() => moveTask({ doc, titleSubstr: "e", to: "done" })).toThrow(/ambiguous/i);
  });
});
```

---

## Step 2: `harness tasks` command `[agent]`

- [ ] Create `src/commands/tasks.ts` + test; register `tasks` in `cli.ts`; extend the usage test

Grammar: `harness tasks add <title> [--to <section>]` (default `inbox`) and
`harness tasks move <title-substr> --to <section>` (required); `--to` ∉ `TASK_SECTIONS` → usage
error listing them. Thin: resolve root → `loadManifest` → `modules.tasks` false →
`HarnessError("module-disabled", …, { hint: "enable modules.tasks in .agent/manifest.json" })` →
read `P.tasks` (missing file → scaffold shape) → parse → `addTask`/`moveTask` →
`writeFileAtomic` → print one line: `added "<title>" to <section>` / `moved "<line>" <from> →
<to>` / `"<line>" already in <to>` (noop). Full JSDoc on the exported `run`.

Tests (full code — contracts): on `initialized` fixture `tasks add "Try worktrees"` → exit 0,
item under `## Inbox`; `tasks move "Try work" --to in-progress` → exit 0, item relocated; noop
re-run → exit 0 "already in"; `--to bogus` → exit 2; `move` with no match → exit 2, stderr
contains `harness tasks add`; modules.tasks patched false → exit 2 `module-disabled`.

---

## Step 3: Skill template edits — tasks wiring `[agent]`

Each edit is: file → find the exact old line (as authored by the earlier spec) → replace with the
new line(s). After all edits re-run 01's scaffold test (templates changed).

- [ ] **E1 dev-spec** — `src/templates/skills/dev-spec/SKILL.md`, step 9 (authored in 02):
  - old: `` `touches:` to the paths it will change; move the task to "In Progress" in `docs/tasks.md`. ``
  - new: `` `touches:` to the paths it will change; run `harness tasks move "<task title>" --to in-progress` (on task-not-found: `harness tasks add "<spec title>" --to in-progress`). ``
- [ ] **E2 sync-spec** — `src/templates/skills/sync-spec/SKILL.md`, step 3 (authored in 02):
  - old: `` spec-tasks.md; all boxes checked → set frontmatter `status: done` in both files. ``
  - new: `` spec-tasks.md; all boxes checked → set frontmatter `status: done` in both files, then run `harness tasks move "<spec title>" --to done` (skip when it reports task-not-found). ``
- [ ] **E3 commit** — `src/templates/skills/commit/SKILL.md`, step 5 bullet (authored in 03):
  - old: `` - `docs/tasks.md` — move finished tasks to "## Recently Done" (modules.tasks) ``
  - new: `` - `docs/tasks.md` — run `harness tasks move "<title>" --to done` per finished task (modules.tasks) ``
- [ ] **E4 implement** — `src/templates/skills/implement/SKILL.md`, step 3 (authored in 05):
  - old: `` "high", suggest running the polish skill. Then hand off to the commit skill. ``
  - new: `` "high", suggest running the polish skill. Run `harness tasks move "<spec slug>" --to done` (modules.tasks; noop-safe). Then hand off to the commit skill. ``
- [ ] Verify each edited SKILL.md is still ≤150 lines (doctor budget).

E2/E4 may both fire for one spec — safe by D08-3.

---

## Step 4: Cascade reference + pointers `[agent]`

- [ ] Create `src/templates/skills/shared-references/cascade-checks.md` (full content below)
- [ ] Confirm 01's `initScaffold` copy loop includes `shared-references/` (relax any SKILL.md
      filter); assert in the scaffold test that the file lands under `.agent/skills/`
- [ ] Add the two pointer lines (edits E5/E6 below)

**File: `src/templates/skills/shared-references/cascade-checks.md`** (full content):

```markdown
# Cascade Checks

When a change to any harness-tracked file or name affects others, find EVERY downstream impact
first, then present ONE confirmation block before applying ANY of them. Never apply a subset
silently.

## Checklist — run the row(s) matching your change

- [ ] **Function/type renamed** → grep every `docs/specs/*/spec.md` + `spec-tasks.md` whose
      frontmatter `touches:` overlaps the changed path; list each file + line to update.
- [ ] **New package added to monorepo** → `docs/product/tech-stack.md` (Packages section),
      `docs/product/dev-processes.md` (commands), then `harness sync` (regenerates
      `context-rules.yaml`).
- [ ] **New env var added** → `.agent/env.manifest.md` entry; verify with `harness env check`.
- [ ] **Decision superseded** → `tech-stack.md` (drop/replace the package), every spec citing
      the old decision (grep the ADR id), the ADR's own `status:` frontmatter.
- [ ] **Standards domain renamed/deleted** → `manifest.json#standards_domains`, then
      `harness sync` (context-rules) + `harness index rebuild`; grep specs citing
      `docs/standards/<domain>/`.
- [ ] **Naming convention changed** → `docs/standards/naming-conventions.md` (rules block +
      examples), every OPEN spec's identifiers (`harness spec list`), then `harness struct`.
- [ ] **Dep version upgraded** → `dependencies/registry.md` pin, then prompt the developer to
      run `harness deps sync`.

## Confirmation block format (verbatim shape)

    This change has downstream impacts. Confirm this full set before I apply anything:

    1. <the primary change>
    2. <impact — file (line) — what changes>
    3. <impact …>

    Apply all N? (yes / review each / skip downstream)

"review each" → walk items one by one. "skip downstream" → apply only item 1 and append a task:
`harness tasks add "Cascade follow-up: <summary>" --to inbox`.
```

- [ ] **E5 dev-spec** — `src/templates/skills/dev-spec/SKILL.md`, step 3:
  - old: `3. **Edge cases** — present design questions, edge cases, scope check. Confirm in/out of scope.`
  - new: `3. **Edge cases** — present design questions, edge cases, scope check. Confirm in/out of scope. Renaming/removing anything that exists? Load `.agent/skills/shared-references/cascade-checks.md`.`
- [ ] **E6 sync-spec** — `src/templates/skills/sync-spec/SKILL.md`, step 6 trailing line:
  - old: `` convention in prose), then run `harness struct` so directory-structure.md re-annotates. ``
  - new: `` convention in prose), then run `harness struct` so directory-structure.md re-annotates. Multi-file impact? Load `.agent/skills/shared-references/cascade-checks.md` first. ``

---

## Step 5: `harness worktree <feature>` `[dev]`

- [ ] Create `src/commands/worktree.ts` + `src/commands/worktree.test.ts`; register `worktree`
      in the cli table (default `tmuxSpawn` = execSync-based); run tests

**File: `harness/src/commands/worktree.ts`**

```typescript
import type { Reporter } from "../lib/output.ts";

/** Injected process runner for tmux only (D08-4). Throws on non-zero exit. */
export type TmuxSpawn = (props: { args: string[] }) => void;

/**
 * Creates a git worktree + branch for a feature, sibling to the project root (D08-5), records
 * it in manifest.repo.worktrees, and opens a tmux window when inside tmux.
 *
 * @param props.root - Project root (the current worktree, e.g. …/maprios-app.git/dev).
 * @param props.feature - Feature name; becomes branch name and default directory name.
 * @param props.path - Optional explicit worktree path (overrides the sibling default).
 * @param props.env - Process env (reads TMUX only).
 * @param props.tmuxSpawn - Tmux runner; tests inject a recorder.
 * @param props.reporter - Output sink.
 * @returns EXIT.OK on success.
 * @throws {HarnessError} "not-worktree-repo" · "worktree-path-exists" · "branch-exists" ·
 *   "git-failed" · "usage" (bad feature name).
 */
export function worktreeAdd(props: {
  root: string; feature: string; path?: string;
  env: Record<string, string | undefined>; tmuxSpawn: TmuxSpawn; reporter: Reporter;
}): number {
  // TODO: implement
  //
  // 1. loadManifest(root). manifest.repo?.type !== "bare-git-worktrees" →
  //    HarnessError("not-worktree-repo", `repo.type is ${type ?? "unset"} — worktree needs
  //    "bare-git-worktrees"`, { hint: "set repo.type in .agent/manifest.json" }).
  // 2. Validate feature: /^[a-z0-9][a-z0-9._\/-]*$/ (git branch charset subset) → else usage.
  // 3. target = props.path ? resolve(root, props.path) : join(dirname(root), props.feature);
  //    branch = props.feature.
  // 4. existsSync(target) → HarnessError("worktree-path-exists", naming the path,
  //    { hint: `harness worktree ${feature} --path <other>` }).
  // 5. `git branch --list <branch>` (execSync, cwd root) output non-empty →
  //    HarnessError("branch-exists", …, { hint: `git worktree add ${target} ${branch}` —
  //    attach the existing branch manually }).
  // 6. execSync `git worktree add <target> -b <branch>` (cwd root); failure → wrap stderr in
  //    HarnessError("git-failed", …, { exitCode: EXIT.FAILURE }).
  // 7. manifest.repo.worktrees = { ...existing, [feature]: { path: relative(root, target),
  //    branch } }; saveManifest. reporter.ok(`worktree ${target} on branch ${branch}`).
  // 8. props.env.TMUX set → props.tmuxSpawn({ args: ["new-window", "-n", feature, "-c",
  //    target] }); tmux failure → reporter.warn (window is a nicety, worktree already exists).
  //    TMUX unset → reporter.info("not inside tmux — skipped window creation").
  //
  // Edge cases:
  // - root not a git repo → step 6's git error surfaces as git-failed with the git stderr.
  // - feature containing ".." or leading "-" → rejected by the step-2 regex.
  throw new Error("Not implemented");
}
```

CLI wiring: `harness worktree <feature> [--path <p>]`; the table's runner builds the real
execSync-based `tmuxSpawn` and passes `process.env`.

**File: `harness/src/commands/worktree.test.ts`** — full code. Setup helper (in this file):
`mkWorktreeProject()` → `container = mkdtempSync(…)`; project at `join(container, "dev")` = copy
of `initialized` fixture; `gitInit({ dir: project })`; patch manifest `repo: { type:
"bare-git-worktrees" }`; returns `{ container, project }` (sibling worktrees land inside
`container`, never the OS tmpdir root). Recorder: `const calls: string[][] = []; const
tmuxSpawn = (p: { args: string[] }) => { calls.push(p.args); };`

```typescript
describe("harness worktree", () => {
  test("creates sibling worktree + branch, records in manifest, no tmux when TMUX unset", …);
  //   worktreeAdd({ root: project, feature: "my-feat", env: {}, tmuxSpawn, reporter })
  //   → existsSync(join(container, "my-feat")) true; `git branch --list my-feat` non-empty;
  //     reloaded manifest.repo.worktrees["my-feat"] = { path: "../my-feat", branch: "my-feat" };
  //     calls.length === 0; reporter items include the "not inside tmux" info line.
  test("TMUX set → tmuxSpawn called with new-window args", …);
  //   env: { TMUX: "/tmp/sock,1,0" } → calls[0] = ["new-window", "-n", "feat2", "-c", <path>]
  test("--path override wins", …);           // path resolves relative to root
  test("branch exists → branch-exists error, no new dir", …);   // pre-create branch via git
  test("path exists → worktree-path-exists", …);                // mkdir the sibling first
  test("repo.type standard → not-worktree-repo", …);            // unpatched fixture manifest
  test("bad feature name → usage", …);                          // "../evil"
});
```

Every commented expectation above is implemented literally (full code) — the comments pin the
exact assertions.

---

## Step 6: End-to-end smoke test `[agent]`

- [ ] Create `harness/test/e2e.test.ts` (describe tag `"e2e"`); run `bun test`

Full code. One `describe("e2e: cold start to session cycle", …)` running the entire surface
in-process via `runCli` against a fresh temp dir (NOT a fixture copy): `mkdtempSync` → `git init`
+ one seed commit (`package.json` with a `test` script, `src/index.ts`) → then, asserting exit 0
after every call unless noted:

1. `harness init scaffold`
2. `harness init write-phase <n> --data <tmpjson>` for n = 1…9, using the sample JSON payloads
   from 01's `init.test.ts` (project `e2e-smoke`, platforms `["claude"]`, modules: specs, tasks,
   session_log true; roadmap/design false; commit_mode `message-only`)
3. `harness init finish` → `.agent/.setup-progress.md` gone, `AGENTS.md` has `## Agent Directives`
4. `harness sync` → `.claude/skills` is a symlink resolving to `.agent/skills`;
   `.claude/CLAUDE.md` first line is `@.agent/AGENTS.md`; `.agent/.sync-manifest.json` non-empty
5. `harness doctor` → **exit 0**
6. `harness spec new "smoke-feature"` → exactly one dir under `.agent/docs/specs/` matching
   `/smoke-feature$/` containing `spec.md` + `spec-tasks.md`
7. `harness implement <that-slug> status` → exit 0, stdout lists `T1` as not done
8. `harness tasks add "Smoke task" --to inbox` then `harness tasks move "Smoke task" --to done`
9. `harness log append --slug "e2e smoke"` → today's log file exists with a `## ` entry
10. touch `src/index.ts` (uncommitted change) → `harness log commit-msg` → exit 0, a
    `*.commit.md` exists beside the log
11. `harness state` → exit 0; `.agent/docs/state.md` **golden**: assert the exact full string
    after normalizing the SHA line (`replace(/SHA: [0-9a-f]{40}/, "SHA: <sha>")`) — sections in
    order: `# Project State`, `## Active specs` listing the smoke spec, `## Tasks` showing
    `## In Progress` (empty) + `## Inbox` (empty) with "Smoke task" under neither (it moved to
    done, which state.md does not render), `## Recent sessions` with the e2e entry headline,
    `## Doctor` with `0 errors`.

Cold-start assertion (the capstone claim): after step 11, a fresh agent reading ONLY
`harness state` output + `.agent/AGENTS.md` has the active spec, open tasks, and last session —
encoded by asserting all three appear in step 11's stdout. Keep the golden literal in the test
file; a diff there on format changes is a signal, not noise. Clean up with `rmSync`.

---

## Verification (mandatory)

- [ ] `cd harness && bun test` — all green including `e2e.test.ts`; no skipped tests
- [ ] `bunx tsc --noEmit` — clean
- [ ] Re-run 01's scaffold test after Steps 3–4 (templates changed) — green
- [ ] Master §12 gates: e2e passes; then execute the Runbook below on this dotfiles repo;
      `harness doctor` exits 0 on the migrated repo; old trees deleted per runbook

## Success Criteria

- [ ] Skills never hand-edit tasks.md — every template references `harness tasks` only
- [ ] `harness worktree` produces a working sibling worktree on a bare-worktrees fixture and
      clear errors for the three failure shapes; tests never invoke tmux
- [ ] `cascade-checks.md` lands in `.agent/skills/shared-references/` on scaffold; both pointers present
- [ ] E2E smoke passes from a bare temp dir; state.md golden pinned
- [ ] Runbook executed on ≥1 real project (this repo) with all confirmation gates honored

---

## Migration Runbook (executed AFTER all specs pass — not code)

> Executor: the implementing agent, live with the developer. **Every deletion sits behind an
> explicit developer confirmation** — present the exact `rm`/`git rm` list and wait for "yes".
> Order: 1. dotfiles (this repo) → 2. maprios → 3. vex; do not start a project until the
> previous one's VERIFY passed.

### Per-project procedure (template)

1. **Snapshot** — clean `git status`; note branch; dotfiles only: `chezmoi diff` quiet.
2. **Mine** — map the old harness content to init phases (tables below); feed the mined content
   to the init skill as draft answers so the interview confirms rather than re-derives.
3. **Init** — run the init skill (→ `harness init scaffold` / `write-phase 1..9` / `finish`).
4. **Sync** — `harness sync`.
5. **VERIFY (gate)** — all must pass before ANY deletion:
   - `harness doctor` exits 0
   - Open Claude Code in the project: harness skills visible through `.claude/skills` symlink
   - If OMP installed: open it, confirm context loads once (no double-load — C4 guard)
6. **Delete (gate per group)** — for each deletion group below: list every path, get explicit
   confirmation, delete, commit with a message naming the group.
7. **Close** — `harness doctor` again (still 0); `harness state`; session-log entry via the
   commit skill.

### Project 1 — dotfiles (`/Users/zaye/.local/share/chezmoi`)

Chezmoi note: `.agent/` here is plain repo content — chezmoi ignores dot-prefixed source paths,
so **no `dot_` prefix**, no `.chezmoiignore` entry needed.

**Mining map (step 2):**

| Old file | Feeds |
|---|---|
| `.pi/agent-docs/product/tech-stack.md` | init phase 4 |
| `.pi/agent-docs/product/dev-processes.md` | init phase 5 (+ env vars → `env.manifest.md`) |
| `.pi/agent-docs/product/mission.md`, `roadmap.md` | init phase 9 |
| `.pi/agent-docs/standards/developer-preferences.md` | split → `preferences.md` + `anti-patterns.md` (02 grammar: `- P-NNN …` / `- AP-NNN …`) |
| `.pi/agent-docs/standards/debug-hierarchy.md` | debug skill reference (`.agent/skills/debug/references/`) |
| `.claude/commands/*.md` (13 files) | confirm harness skills cover each (table below) |
| `pi-agent-base/prompts/*` | already superseded by 02/03/05 skill ports — mine only for content the skills missed |

**`.claude/commands` coverage** — covered by shipped skills (delete): `commit.md`, `dev-spec.md`,
`sync-spec.md`, `debug.md`, `document.md`, `research.md`, `learn.md`. **Keep-candidates** (present
to developer; keep any confirmed, as `.agent/skills/` entries or leave in `.claude/commands/`):
`add-vexfield.md` (vex-specific — offer to move into the vex repo during Project 3),
`copy-commit.md`, `copy-commit-body.md` (clipboard helpers — no harness equivalent),
`feature-checklist.md`, `guide.md`, `review.md`. `agent-os/` subdir: superseded stub tree — delete.

**Deletion groups (each its own gate):**

- **G1 root `.pi/`** — delete `.pi/prompts/`, `.pi/agent-docs/product/`, `standards/`,
  `implementation-log/`, `.pi/AGENTS.md`. **KEEP specs history**: `git mv .pi/agent-docs/specs/*`
  → `.agent/docs/specs/archive/` first. Then remove the emptied `.pi/`.
- **G2 `agent-os/`** — abandoned standards stub; delete whole tree.
- **G3 `.claude/commands/`** — delete covered files + `agent-os/` subdir per the table; keep
  confirmed keep-candidates only.
- **G4 shrink `pi-agent-base/`** — KEEP only pi-specific files: `settings.json`,
  `keybindings.json`, `models.json.tmpl`, `extensions/`, `themes/`, `WORKFLOW.md`. Delete:
  `AGENTS.md`, `docs/`, `prompts/`, `templates/`, `skills/` — **including the 130MB checked-in
  venv `pi-agent-base/skills/excalidraw-diagram/references/.venv` (delete, never migrate)** —
  and `pi-agent-base/.pi/` (first `git mv pi-agent-base/.pi/agent-docs/specs/*` — this spec
  suite + the proposal — into `.agent/docs/specs/archive/`).
- **G5 `run_after_sync-pi-agent-base.sh.tmpl`** — add `--exclude='.pi/'` to the rsync exclude
  list (belt-and-braces against a stale `pi-agent-base/.pi/` reappearing in `~/.pi/agent`), and
  after the shrink run `chezmoi apply` and confirm `~/.pi/agent` contains only the kept files
  (rsync `--delete` prunes the rest).

### Project 2 — maprios (`~/Documents/Projects/maprios-app.git/dev`)

Bare-repo worktree layout → init phase 1 answers `repo_type: bare-git-worktrees`; manifest gets
`repo: { type: "bare-git-worktrees", worktrees: { dev: { path: ".", branch: "dev" } } }`.
Smoke-test `harness worktree` here with a throwaway feature; `git worktree remove` it after.

**Mining map:** old harness is `~/Documents/Projects/maprios-app.git/dev/.claude/commands/`:
`commit.md`, `dev-spec.md` → covered (delete). `design.md`, `timesheet.md` → project-specific
keep-candidates (port into `.agent/skills/` or keep as commands — developer decides). `agent-os/`
subdir → delete. No `.pi/` tree; phases 4/5/9 come from the interview + codebase.

**Deletion group (gate):** covered `.claude/commands` files + `agent-os/` after VERIFY.

### Project 3 — vex

Path: ask the developer (not recorded in this repo). Same template: mine any `.claude/commands/`
/ `.pi/` trees found; the `add-vexfield` command from dotfiles G3 is offered here as
`.agent/skills/add-vexfield/` (port to router format, ≤150 lines, content into `references/`).
Vex is high-care (proposal): `default_tier: high-care`, `importance: high`,
`post_implement_polish: true`. Run the phase-8 naming interview seriously — vex is the project
the naming rules were designed for. Deletion gates identical: VERIFY first, list, confirm, delete.

### Runbook completion checklist

- [ ] All three projects: doctor 0, skills visible in Claude Code, OMP single-load verified
- [ ] Dotfiles: G1–G5 executed, specs history preserved in `.agent/docs/specs/archive/`;
      `~/.pi/agent` post-`chezmoi apply` contains only pi-specific files
- [ ] Every deletion commit names its group; nothing deleted without a recorded "yes"
