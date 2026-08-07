# 05 — Implementation Loop & Polish

> Phase spec 5 of 8. Prereqs: `00-master.md` (§2 conventions binding; D12: `harness implement` is a
> state machine, never spawns models), `01-foundation.md` (lib contracts), 02 (`spec new`, `context`),
> 03 (`log append`). Proposal sources: §13 (implementation agent), §14 (polish), §11 step 5
> (spec-tasks shape).

## Overview

Build the `harness implement <slug> status|next|verify|done` state machine, the `implement` skill
that drives it, `harness polish <slug>` (packet emitter, gated on importance), and the `polish`
skill. The CLI reads/writes task-group state in `spec-tasks.md` + a state json, prints working
packets, and records verify results. All analysis and code-writing is the skills' job.

## Design Decisions

- **D12 applied**: `verify` runs the group's shell command (`Bun.spawnSync`) — the ONLY subprocess
  the implement machinery ever spawns. `next` and `polish` are pure packaging.
- Bare `harness implement <slug>` = alias for `status` + hint "drive the loop with the implement
  skill" (the proposal's `harness implement "<slug>"` loop entry, reinterpreted per D12).
- `done` is gated on a recorded passing verify; escape hatch is `--force --reason`, always logged.
- Max-2-retries is *guidance* in the skill (`references/verification.md`); the CLI only counts
  attempts — it never blocks retrying.
- Polish gate is `workflow.importance === "high"` only (`post_implement_polish` merely tells the
  implement skill to *suggest* polish; it is not a CLI gate).

## Contracts Invented Here (⚠ FLAG — reconcile with 02/03 when those specs are authored/implemented)

### C-05a `spec-tasks.md` format (02's `harness spec new` must emit this)

Frontmatter (flat, parseable by 01's `parseFrontmatter`): `spec_id`, `status`
(`planned|in-progress|done`), `touches` (inline array of globs), `prompt_version`. Body:

```markdown
# Tasks — <slug>

## T1 — <title>
Why: <one line>
Verify: <shell command, or exactly `manual`>

- [ ] 1. <step>
- [ ] 2. <step>
```

Parse rules: group heading `^## (T\d+) — (.+)$` (em dash, as `spec new`'s template writes it);
`Why:` / `Verify:` are the first such-prefixed lines after the heading; steps are `- [ ]` / `- [x]`
lines. A group without a `Verify:` line is a parse error (proposal §13: "Verification Is
Mandatory"). A group is **done** iff all its checkboxes are checked. `spec.md` shares the same
frontmatter and contains one `## Tn — <title>` section per group (extraction target for `next`).

### C-05b `.agent/docs/specs/<slug>/.implement-state.json`

```typescript
/** Resume + audit state for one spec's implementation loop. Committed with the spec dir. */
export interface ImplementState {
  version: 1;
  slug: string;
  updated: string;                       // ISO-8601; from props.now (injected clock, master §2.8)
  groups: Record<string, GroupState>;    // key = group id ("T1")
}
export interface GroupState {
  attempts: number;                      // total `verify` invocations for this group
  last_result: "pass" | "fail" | null;   // manual --confirmed records "pass"
  last_exit_code: number | null;         // null for manual confirmation / never-run
  last_output_tail: string[];            // last ≤40 lines of combined stdout+stderr
  forced?: { reason: string; at: string };  // set by `done --force`
}
```

### C-05c Forward imports (must exist by build time; verify names before implementing)

- From 02 `src/commands/context.ts`: `contextFilesFor(props: { root: string; task: string; files?: string[] }):
  string[]` — root-relative paths matching the task; `[]` when `context-rules.yaml` is absent or
  nothing matches. (Declared in 02 as the wrapper over `matchContextRules`.)
- From 03 `src/commands/log.ts`: `appendLogLine(props: { root: string; line: string; dateOpt?: string }):
  void` — appends one bullet under today's session-log entry, creating file/entry as needed.
  `done` calls the **function**, never the CLI. (Declared in 03's log.ts step.)

## Out of Scope (this spec)

Subagent dispatch / OMP-native parallel implement (deferred — proposal Phase 9), everything from
06–08, **no new doctor checks**.

## Implementation Order

> `[agent]` = boilerplate/pattern-following · `[dev]` = core logic, guided stub

1. `[agent]` Test fixture helper — demo-feature spec dir
2. `[dev]` spec-tasks parser + checkbox ticking — key fns: `parseSpecTasks`, `tickGroup`
3. `[agent]` Implement-state load/save
4. `[dev]` `harness implement` command — key fns: `implementStatus`, `implementNext`,
   `implementVerify`, `implementDone`
5. `[dev]` `harness polish` command — key fn: `buildPolishPacket`
6. `[agent]` `implement` skill (SKILL.md + references/verification.md)
7. `[agent]` `polish` skill (SKILL.md + references/polish-checklist.md)
8. Verification

---

## Step 1: Fixture helper `[agent]`

- [ ] Create `harness/test/specFixture.ts` (full code below) — writes the demo spec dir into a tmp
      project; used by implement + polish tests. Checked-in fixtures stay untouched.

```typescript
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const FM = `---
spec_id: demo-feature
status: in-progress
touches: ["src/demo/**"]
prompt_version: 1
---
`;

export const DEMO_SPEC_TASKS = `${FM}
# Tasks — demo-feature

## T1 — Scaffold demo module
Why: every later group imports from these files.
Verify: bun -e "console.log('t1 ok')"

- [ ] 1. Create \`src/demo/types.ts\` with the \`DemoItem\` interface
- [ ] 2. Create \`src/demo/store.ts\` + \`src/demo/store.test.ts\`

## T2 — Wire list rendering
Why: visible output early — the developer can see items render.
Verify: bun -e "process.exit(0)"

- [ ] 1. Create \`src/demo/render.ts\` + test
- [ ] 2. Wire \`render\` into \`src/demo/index.ts\`

## T3 — Manual smoke
Why: rendering quality needs human eyes.
Verify: manual

- [ ] 1. Open the demo page and confirm items render with empty + error states
`;

export const DEMO_SPEC = `${FM}
# Demo Feature

## Overview
A tiny demo feature used by implement/polish tests.

## Edge cases
- Empty item list renders the "No items" state
- Store rejects duplicate ids with a clear error

## T1 — Scaffold demo module
Create \`types.ts\` (interface \`DemoItem { id: string; label: string }\`) and \`store.ts\`
(\`createDemoStore(props: { items: DemoItem[] })\`).

## T2 — Wire list rendering
\`render(props: { store: DemoStore }): string\` returns one line per item.

## T3 — Manual smoke
Open the demo page; confirm empty and error states.
`;

/**
 * Seeds the demo-feature spec dir into a project created by mkTmpProject.
 * @param props.dir - Project root (tmp copy of the `initialized` fixture).
 * @returns Absolute path of the spec dir.
 */
export function seedDemoSpec(props: { dir: string }): string {
  const specDir = join(props.dir, ".agent", "docs", "specs", "demo-feature");
  mkdirSync(specDir, { recursive: true });
  writeFileSync(join(specDir, "spec.md"), DEMO_SPEC);
  writeFileSync(join(specDir, "spec-tasks.md"), DEMO_SPEC_TASKS);
  return specDir;
}
```

---

## Step 2: spec-tasks parser `[dev]`

- [ ] Create `src/lib/specTasks.ts` + `src/lib/specTasks.test.ts`; run tests
- [ ] ⚠ If 02 shipped its own spec-tasks parser, reuse/extend it here instead of duplicating —
      one parser owns the format.

**File: `harness/src/lib/specTasks.ts`**

```typescript
import { HarnessError } from "./errors.ts";
import { parseFrontmatter } from "./frontmatter.ts";

export interface TaskStep { text: string; checked: boolean; line: number }
export interface TaskGroup {
  id: string;                 // "T1"
  title: string;
  why: string;                // "" when the Why: line is absent (tolerated)
  verify: string;             // shell command, or exactly "manual"
  steps: TaskStep[];
  startLine: number;          // 0-based line index of the "## Tn — " heading
  endLine: number;            // exclusive — next group heading or EOF
}
export interface SpecTasks { frontmatter: Record<string, unknown>; groups: TaskGroup[] }

/**
 * Parses a spec-tasks.md document into ordered task groups (contract C-05a).
 *
 * @param props.text - Full spec-tasks.md content.
 * @returns Frontmatter + groups in document order.
 * @throws {HarnessError} code "spec-tasks-invalid" when a group has no Verify: line,
 *   has zero steps, or a duplicate group id appears.
 */
export function parseSpecTasks(props: { text: string }): SpecTasks {
  // TODO: implement
  //
  // 1. parseFrontmatter; split FULL text into lines (line indexes refer to the full document,
  //    so tickGroup can splice byte-faithfully).
  // 2. Scan for /^## (T\d+) — (.+)$/ headings → group boundaries (startLine, endLine).
  // 3. Within each range: first /^Why: (.*)/ → why; first /^Verify: (.*)/ → verify (trimmed);
  //    every /^- \[( |x)\] (.*)/ → step { checked: m[1]==="x", text: m[2], line }.
  // 4. Validate per group: verify missing → HarnessError("spec-tasks-invalid",
  //    `${id} has no Verify: line`); steps.length === 0 → same code, `${id} has no steps`;
  //    duplicate id → same code.
  //
  // Edge cases:
  // - "## T10 — x" after "## T2 — x": document order is kept as-is; no numeric sorting.
  // - CRLF: strip \r when matching, but report line indexes of the original lines array.
  // - Non-group "## " headings (e.g. "# Tasks — slug" or "## Notes") are ignored, and a
  //   "## Notes" section between groups ends the previous group's range.
  throw new Error("Not implemented");
}

/**
 * Returns the document with every step checkbox of one group ticked ("- [ ]" → "- [x]").
 * All other bytes are preserved exactly.
 *
 * @param props.text - Full spec-tasks.md content.
 * @param props.groupId - Group to tick, e.g. "T1".
 * @returns Updated document text.
 * @throws {HarnessError} code "group-not-found" when the id has no group.
 */
export function tickGroup(props: { text: string; groupId: string }): string {
  // TODO: implement
  // 1. parseSpecTasks; find group or throw group-not-found (message lists valid ids).
  // 2. Split into lines; for each step line index of the group, replace the FIRST "- [ ]"
  //    occurrence on that line with "- [x]". Already-checked lines untouched.
  // 3. Rejoin with "\n" (input is normalized LF; assert no "\r\n" — see parse edge case).
  throw new Error("Not implemented");
}
```

**File: `harness/src/lib/specTasks.test.ts`** — full code; uses `DEMO_SPEC_TASKS`:

```typescript
import { describe, expect, test } from "bun:test";
import { DEMO_SPEC_TASKS } from "../../test/specFixture.ts";
import { parseSpecTasks, tickGroup } from "./specTasks.ts";

describe("parseSpecTasks", () => {
  test("parses the demo fixture exactly", () => {
    const st = parseSpecTasks({ text: DEMO_SPEC_TASKS });
    expect(st.frontmatter.spec_id).toBe("demo-feature");
    expect(st.frontmatter.touches).toEqual(["src/demo/**"]);
    expect(st.groups.map((g) => g.id)).toEqual(["T1", "T2", "T3"]);
    const t1 = st.groups[0]!;
    expect(t1.title).toBe("Scaffold demo module");
    expect(t1.why).toBe("every later group imports from these files.");
    expect(t1.verify).toBe(`bun -e "console.log('t1 ok')"`);
    expect(t1.steps.map((s) => s.checked)).toEqual([false, false]);
    expect(st.groups[1]!.verify).toBe(`bun -e "process.exit(0)"`);
    expect(st.groups[2]!.verify).toBe("manual");
    expect(st.groups[2]!.steps).toHaveLength(1);
  });
  test("missing Verify: line throws spec-tasks-invalid", () => {
    const bad = DEMO_SPEC_TASKS.replace(`Verify: bun -e "console.log('t1 ok')"\n`, "");
    expect(() => parseSpecTasks({ text: bad })).toThrow(/T1 has no Verify/);
  });
  test("group with zero steps throws", () => {
    const bad = DEMO_SPEC_TASKS + "\n## T4 — Empty\nWhy: x\nVerify: manual\n";
    expect(() => parseSpecTasks({ text: bad })).toThrow(/T4 has no steps/);
  });
});

describe("tickGroup", () => {
  test("ticks only the target group, byte-preserving the rest", () => {
    const out = tickGroup({ text: DEMO_SPEC_TASKS, groupId: "T1" });
    const st = parseSpecTasks({ text: out });
    expect(st.groups[0]!.steps.every((s) => s.checked)).toBe(true);
    expect(st.groups[1]!.steps.every((s) => !s.checked)).toBe(true);
    // everything except the two ticked hyphen-lines is unchanged
    expect(out.replaceAll("- [x]", "- [ ]")).toBe(DEMO_SPEC_TASKS);
  });
  test("unknown group throws group-not-found", () => {
    expect(() => tickGroup({ text: DEMO_SPEC_TASKS, groupId: "T9" })).toThrow(/T9/);
  });
});
```

---

## Step 3: Implement-state load/save `[agent]`

- [ ] Create `src/lib/implementState.ts` + `src/lib/implementState.test.ts` — full code, pattern
      identical to 01's `syncManifest.ts`.

Types verbatim from C-05b. `loadImplementState(props: { specDir: string; slug: string }):
ImplementState` — absent/unparseable file → `{ version: 1, slug, updated: "", groups: {} }`
(unparseable additionally warns via caller; keep the function pure — return a `reset: boolean`
flag? No: tolerate silently, the file is derived state). `saveImplementState(props: { specDir:
string; state: ImplementState })` — `writeFileAtomic`, 2-space indent, `groups` keys sorted,
trailing newline. File name constant `IMPLEMENT_STATE_FILE = ".implement-state.json"`.

Test (full): default on absent; round-trip; sorted keys stable (`T10` sorts after `T2`? No —
lexicographic `T1,T10,T2` is fine, determinism is the requirement, assert the literal order).

---

## Step 4: `harness implement` `[dev]`

- [ ] Create `src/commands/implement.ts` + `src/commands/implement.test.ts`; register `implement`
      in `cli.ts` command table; run tests

Arg shape: `{ positionals: ["slug", "...rest"], flags: ["json", "force", "confirmed"], options:
["from", "reason"] }`. `rest[0]` = subcommand (`status` default — the bare-alias rule), `rest[1]` =
group id for `verify`/`done`. Unknown subcommand → usage error listing the four.

**File: `harness/src/commands/implement.ts`** — shared loader (full code): `loadSpec(props: { root:
string; slug: string })` reads `.agent/docs/specs/<slug>/spec-tasks.md` (dir missing →
`HarnessError("spec-not-found", …, { hint: "harness spec list" })`; file missing →
`"spec-tasks-missing"`), returns `{ specDir, tasksPath, text, tasks, state }`. Then four guided
stubs:

```typescript
export const VERIFY_TIMEOUT_MS = 300_000;

/** Group display state for the status table. */
export type GroupDisplayState = "done" | "failed" | "next" | "pending";

/**
 * Prints the task-group table. Columns: ID, Title, Steps (checked/total), Verify, State —
 * two-space separated, each padded to max(header, longest cell); no trailing pad on State.
 * @param props.root - Project root. @param props.slug - Spec slug. @param props.stdout - Sink.
 * @returns EXIT.OK always (status never fails on content).
 */
export function implementStatus(props: { root: string; slug: string; stdout: (s: string) => void }): number {
  // TODO: implement
  // 1. loadSpec. Per group: done = every step checked; else "failed" if
  //    state.groups[id]?.last_result === "fail"; FIRST group neither done nor failed →
  //    "next"; remaining → "pending".
  // 2. Header `Spec: <slug> — <n> task groups, <c>/<t> steps done`, blank, table with
  //    computed column widths (deterministic — golden-tested).
  // Edge cases: 0 groups → header + "(no task groups)"; all done → no "next" row.
  throw new Error("Not implemented");
}

/**
 * Prints the working packet for the next unchecked group (or --from's group). This stdout IS
 * the implement skill's context bundle (D12 — packaging only).
 * @param props.root - Project root. @param props.slug - Spec slug.
 * @param props.from - Optional group id override. @param props.stdout - Sink.
 * @returns EXIT.OK; also EXIT.OK with "(all groups done)" when nothing is open.
 */
export function implementNext(props: { root: string; slug: string; from?: string; stdout: (s: string) => void }): number {
  // TODO: implement
  // 1. loadSpec. Target = props.from (group-not-found if unknown) else first not-done group;
  //    none → print "(all groups done — run the commit skill)" → EXIT.OK.
  // 2. Emit, in order (exact shape pinned by the golden test):
  //    `# <slug> — <id>: <title>` / blank / `Why: <why>` / `Verify: <verify>` / blank /
  //    `## Steps` + the group's checkbox lines verbatim / blank /
  //    `## Spec section (from spec.md)` + spec.md lines from its `## <id> — ` heading up to
  //    the next `## ` (missing spec.md or heading → line
  //    `(no matching spec section — read spec.md in full)`) / blank /
  //    `## Context files (harness context --for "<title>")` + contextFilesFor (C-05c) results
  //    one per line, or `(none — no context rules matched)` / blank /
  //    [only when dependencies/registry.md has a non-empty, non-heading line:
  //     `## Dependency sources` + one fixed line pointing at registry.md / blank] /
  //    `## Conventions` + `Read .agent/docs/standards/naming-conventions.md before writing any code.`
  // Edge cases: --from targeting a done group is allowed (re-work); manual groups get the
  //   same packet (the skill reads Verify: manual and pauses).
  throw new Error("Not implemented");
}

/**
 * Runs the group's Verify command and records the result in .implement-state.json.
 * @param props.root - Project root. @param props.slug - Spec slug. @param props.groupId - "Tn".
 * @param props.confirmed - Required for `Verify: manual` groups.
 * @param props.now - Injected ISO timestamp (tests); default new Date().toISOString().
 * @param props.stdout - Sink.
 * @returns EXIT.OK on pass/confirmed manual; EXIT.FINDINGS on fail or unconfirmed manual.
 */
export function implementVerify(props: {
  root: string; slug: string; groupId: string; confirmed?: boolean; now?: string;
  stdout: (s: string) => void;
}): number {
  // TODO: implement
  // 1. loadSpec; group or group-not-found.
  // 2. verify === "manual": !confirmed → print `manual verification required for <id> —
  //    confirm with the developer, then re-run with --confirmed` → EXIT.FINDINGS (state
  //    untouched). confirmed → record { attempts+1, last_result: "pass", last_exit_code:
  //    null, last_output_tail: [] }, save, print `<id> verify: manual — confirmed` → EXIT.OK.
  // 3. Else Bun.spawnSync({ cmd: ["sh", "-c", verify], cwd: root, stdout: "pipe",
  //    stderr: "pipe", timeout: VERIFY_TIMEOUT_MS }). Timeout/spawn failure counts as fail
  //    (record exitCode ?? -1; tail gets a "verify timed out after 300s" line appended).
  // 4. tail = last 40 lines of stdout+stderr (stdout first); record attempts+1 / pass|fail /
  //    exitCode / tail; state.updated = now; save.
  // 5. Print the tail, then `<id> verify: pass` → EXIT.OK, or `<id> verify: FAIL (exit <n>)
  //    — done is blocked until verify passes` → EXIT.FINDINGS.
  throw new Error("Not implemented");
}

/**
 * Marks a group complete: requires a recorded passing verify (or --force with a reason),
 * ticks the group's checkboxes, appends a session-log line via 03's appendLogLine.
 * @param props.root - Project root. @param props.slug - Spec slug. @param props.groupId - "Tn".
 * @param props.force - Bypass the verify gate. @param props.reason - Required with force.
 * @param props.now - Injected ISO timestamp. @param props.stdout - Sink.
 * @returns EXIT.OK.
 * @throws {HarnessError} "verify-not-passed" (hint: `harness implement <slug> verify <id>`)
 *   when last_result !== "pass" and !force; "force-reason-required" when force && !reason.
 */
export function implementDone(props: {
  root: string; slug: string; groupId: string; force?: boolean; reason?: string; now?: string;
  stdout: (s: string) => void;
}): number {
  // TODO: implement
  // 1. loadSpec; group or group-not-found. gs = state.groups[id].
  // 2. Gate: gs?.last_result === "pass" → ok. Else: !force → verify-not-passed (message
  //    names the last result: "fail (exit 1)" | "never run"); force && !reason →
  //    force-reason-required; force && reason → gs.forced = { reason, at: now }.
  // 3. writeFileAtomic(tasksPath, tickGroup(...)).
  // 4. state.updated = now; save. Log line via appendLogLine (C-05c):
  //    `implement <slug>: <id> done — <title> (verify pass, <attempts> attempt(s))`;
  //    forced → `… (FORCED: <reason>)` replaces the verify clause.
  // 5. Print `<id> done — <checked>/<total> steps ticked` (+ next open group id if any).
  // Edge cases: group already all-checked → print "already done", no tick, no log, EXIT.OK.
  throw new Error("Not implemented");
}
```

**File: `harness/src/commands/implement.test.ts`** — full code. Golden strings are exact:

```typescript
import { describe, expect, test } from "bun:test";
import { readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { seedDemoSpec, DEMO_SPEC_TASKS } from "../../test/specFixture.ts";

function setup(): { dir: string; specDir: string } {
  const dir = mkTmpProject({ fixture: "initialized" });
  return { dir, specDir: seedDemoSpec({ dir }) };
}
const tasksPath = (specDir: string) => join(specDir, "spec-tasks.md");
const statePath = (specDir: string) => join(specDir, ".implement-state.json");
const readState = (specDir: string) => JSON.parse(readFileSync(statePath(specDir), "utf8"));

const STATUS_GOLDEN = `Spec: demo-feature — 3 task groups, 0/5 steps done

ID  Title                 Steps  Verify                         State
T1  Scaffold demo module  0/2    bun -e "console.log('t1 ok')"  next
T2  Wire list rendering   0/2    bun -e "process.exit(0)"       pending
T3  Manual smoke          0/1    manual                         pending`;

describe("implement status", () => {
  test("golden table; bare subcommand defaults to status", async () => {
    const { dir } = setup();
    const r = await runCli({ argv: ["implement", "demo-feature", "status"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toBe(STATUS_GOLDEN);
    const bare = await runCli({ argv: ["implement", "demo-feature"], cwd: dir });
    expect(bare.stdout).toContain(STATUS_GOLDEN);
    rmProject({ dir });
  });
  test("unknown slug → spec-not-found, exit 2", async () => {
    const { dir } = setup();
    const r = await runCli({ argv: ["implement", "nope", "status"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("spec-not-found");
    rmProject({ dir });
  });
});

const NEXT_T1_GOLDEN = `# demo-feature — T1: Scaffold demo module

Why: every later group imports from these files.
Verify: bun -e "console.log('t1 ok')"

## Steps
- [ ] 1. Create \`src/demo/types.ts\` with the \`DemoItem\` interface
- [ ] 2. Create \`src/demo/store.ts\` + \`src/demo/store.test.ts\`

## Spec section (from spec.md)
## T1 — Scaffold demo module
Create \`types.ts\` (interface \`DemoItem { id: string; label: string }\`) and \`store.ts\`
(\`createDemoStore(props: { items: DemoItem[] })\`).

## Context files (harness context --for "Scaffold demo module")
(none — no context rules matched)

## Conventions
Read .agent/docs/standards/naming-conventions.md before writing any code.`;

describe("implement next", () => {
  test("golden packet for first open group", async () => {
    const { dir } = setup();
    const r = await runCli({ argv: ["implement", "demo-feature", "next"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toBe(NEXT_T1_GOLDEN);
    rmProject({ dir });
  });
  test("--from targets a specific group", async () => {
    const { dir } = setup();
    const r = await runCli({ argv: ["implement", "demo-feature", "next", "--from", "T2"], cwd: dir });
    expect(r.stdout).toContain("# demo-feature — T2: Wire list rendering");
    expect(r.stdout).toContain("Verify: bun -e \"process.exit(0)\"");
    rmProject({ dir });
  });
  test("dep note appears iff registry.md has entries", async () => {
    const { dir, specDir } = setup();
    appendFileSync(join(dir, ".agent", "dependencies", "registry.md"), "\n| convex | 1.17.0 |\n");
    const r = await runCli({ argv: ["implement", "demo-feature", "next"], cwd: dir });
    expect(r.stdout).toContain("## Dependency sources");
    expect(r.stdout).toContain(".agent/dependencies/registry.md");
    rmProject({ dir });
  });
});

describe("implement verify + done — full loop", () => {
  test("next → verify pass → done ticks boxes, updates state, logs; resume from T2", async () => {
    const { dir, specDir } = setup();
    const v = await runCli({ argv: ["implement", "demo-feature", "verify", "T1"], cwd: dir });
    expect(v.code).toBe(0);
    expect(v.stdout).toContain("t1 ok");
    expect(v.stdout).toContain("T1 verify: pass");
    let st = readState(specDir);
    expect(st.groups.T1).toMatchObject({ attempts: 1, last_result: "pass", last_exit_code: 0 });
    const d = await runCli({ argv: ["implement", "demo-feature", "done", "T1"], cwd: dir });
    expect(d.code).toBe(0);
    const tasks = readFileSync(tasksPath(specDir), "utf8");
    expect(tasks).toContain("- [x] 1. Create `src/demo/types.ts`");
    expect(tasks).toContain("- [x] 2. Create `src/demo/store.ts`");
    expect(tasks).toContain("- [ ] 1. Create `src/demo/render.ts`"); // T2 untouched
    st = readState(specDir);
    expect(typeof st.updated).toBe("string");
    // session log got a line (path: .agent/docs/session-log/YYYY/MM/YYYY-MM-DD.log.md)
    const now = new Date();
    const y = String(now.getFullYear()); const m = String(now.getMonth() + 1).padStart(2, "0");
    const day = `${y}-${m}-${String(now.getDate()).padStart(2, "0")}`;
    const log = readFileSync(join(dir, ".agent", "docs", "session-log", y, m, `${day}.log.md`), "utf8");
    expect(log).toContain("implement demo-feature: T1 done");
    // resume: status shows T1 done, T2 next; next emits T2
    const s = await runCli({ argv: ["implement", "demo-feature", "status"], cwd: dir });
    expect(s.stdout).toContain("T1  Scaffold demo module  2/2");
    expect(s.stdout).toMatch(/T2 {2}Wire list rendering.*next/);
    const n = await runCli({ argv: ["implement", "demo-feature", "next"], cwd: dir });
    expect(n.stdout).toContain("# demo-feature — T2: Wire list rendering");
    rmProject({ dir });
  });

  test("failed verify blocks done; --force needs and logs a reason", async () => {
    const { dir, specDir } = setup();
    writeFileSync(tasksPath(specDir),
      DEMO_SPEC_TASKS.replace(`bun -e "console.log('t1 ok')"`, `bun -e "process.exit(1)"`));
    const v = await runCli({ argv: ["implement", "demo-feature", "verify", "T1"], cwd: dir });
    expect(v.code).toBe(1);
    expect(v.stdout).toContain("T1 verify: FAIL (exit 1)");
    expect(readState(specDir).groups.T1).toMatchObject({ last_result: "fail", last_exit_code: 1 });
    const d1 = await runCli({ argv: ["implement", "demo-feature", "done", "T1"], cwd: dir });
    expect(d1.code).toBe(2);
    expect(d1.stderr).toContain("verify-not-passed");
    const d2 = await runCli({ argv: ["implement", "demo-feature", "done", "T1", "--force"], cwd: dir });
    expect(d2.code).toBe(2);
    expect(d2.stderr).toContain("force-reason-required");
    const d3 = await runCli({
      argv: ["implement", "demo-feature", "done", "T1", "--force", "--reason", "flaky sandbox"], cwd: dir });
    expect(d3.code).toBe(0);
    expect(readState(specDir).groups.T1.forced.reason).toBe("flaky sandbox");
    expect(readFileSync(tasksPath(specDir), "utf8")).toContain("- [x] 1. Create `src/demo/types.ts`");
    rmProject({ dir });
  });

  test("done without any verify is blocked", async () => {
    const { dir } = setup();
    const d = await runCli({ argv: ["implement", "demo-feature", "done", "T2"], cwd: dir });
    expect(d.code).toBe(2);
    expect(d.stderr).toContain("never run");
    rmProject({ dir });
  });

  test("manual group: verify needs --confirmed", async () => {
    const { dir, specDir } = setup();
    const v1 = await runCli({ argv: ["implement", "demo-feature", "verify", "T3"], cwd: dir });
    expect(v1.code).toBe(1);
    expect(v1.stdout).toContain("manual verification required for T3");
    const v2 = await runCli({ argv: ["implement", "demo-feature", "verify", "T3", "--confirmed"], cwd: dir });
    expect(v2.code).toBe(0);
    expect(readState(specDir).groups.T3).toMatchObject({ last_result: "pass", last_exit_code: null });
    const d = await runCli({ argv: ["implement", "demo-feature", "done", "T3"], cwd: dir });
    expect(d.code).toBe(0);
    rmProject({ dir });
  });
});
```

---

## Step 5: `harness polish` `[dev]`

- [ ] Create `src/commands/polish.ts` + `src/commands/polish.test.ts`; register `polish` in
      `cli.ts`; run tests

**File: `harness/src/commands/polish.ts`** — arg shape `{ positionals: ["slug"], flags: ["json"] }`.

```typescript
/**
 * Emits the polish working packet: spec edge cases, touches[] file globs, checklist path.
 * The ANALYSIS is the polish skill's job — this command is packaging only (D12).
 *
 * @param props.root - Project root. @param props.slug - Spec slug. @param props.stdout - Sink.
 * @returns EXIT.OK.
 * @throws {HarnessError} "polish-disabled" when manifest.workflow.importance !== "high",
 *   message exactly: `Polish is only enabled for high-importance projects. Set importance:
 *   high in manifest.json.` (proposal §14); "spec-not-found" when the spec dir or spec.md
 *   is missing.
 */
export function buildPolishPacket(props: { root: string; slug: string; stdout: (s: string) => void }): number {
  // TODO: implement
  // 1. loadManifest; gate on importance (before touching the spec — gate error wins).
  // 2. Read spec.md (+ frontmatter). Extract "## Edge cases" section lines (heading exclusive,
  //    up to next "## "); absent → the single line
  //    "(spec.md has no \"## Edge cases\" section — review the spec manually)".
  // 3. Emit exactly:
  //    `Polish packet for spec: <slug>` / blank /
  //    `## Edge cases (from spec.md)` + section lines / blank /
  //    `## Files to review (frontmatter touches[])` + one `- <glob>` per entry
  //      (empty/missing touches → `- (touches[] empty — review files changed for this spec)`) / blank /
  //    `## Checklist` / `.agent/skills/polish/references/polish-checklist.md` / blank /
  //    `Run the polish skill against this packet. The CLI does no code analysis (D12).`
  throw new Error("Not implemented");
}
```

**File: `harness/src/commands/polish.test.ts`** — full code:

```typescript
import { describe, expect, test } from "bun:test";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { seedDemoSpec } from "../../test/specFixture.ts";

function setImportance(dir: string, value: string): void {
  const p = join(dir, ".agent", "manifest.json");
  const m = JSON.parse(readFileSync(p, "utf8"));
  m.workflow.importance = value;
  writeFileSync(p, JSON.stringify(m, null, 2) + "\n");
}

const PACKET_GOLDEN = `Polish packet for spec: demo-feature

## Edge cases (from spec.md)
- Empty item list renders the "No items" state
- Store rejects duplicate ids with a clear error

## Files to review (frontmatter touches[])
- src/demo/**

## Checklist
.agent/skills/polish/references/polish-checklist.md

Run the polish skill against this packet. The CLI does no code analysis (D12).`;

describe("polish", () => {
  test("importance medium → polish-disabled with the proposal's exact message", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    seedDemoSpec({ dir });
    setImportance(dir, "medium");
    const r = await runCli({ argv: ["polish", "demo-feature"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("polish-disabled");
    expect(r.stderr).toContain(
      "Polish is only enabled for high-importance projects. Set importance: high in manifest.json.");
    rmProject({ dir });
  });
  test("importance high → golden packet", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    seedDemoSpec({ dir });
    setImportance(dir, "high");
    const r = await runCli({ argv: ["polish", "demo-feature"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toBe(PACKET_GOLDEN);
    rmProject({ dir });
  });
  test("importance high but spec missing → spec-not-found", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setImportance(dir, "high");
    const r = await runCli({ argv: ["polish", "ghost"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("spec-not-found");
    rmProject({ dir });
  });
});
```

---

## Step 6: `implement` skill `[agent]`

- [ ] Create `src/templates/skills/implement/SKILL.md` (≤150 lines) +
      `references/verification.md`; re-run 01's scaffold test (templates now include it)

**File: `src/templates/skills/implement/SKILL.md`** — full content:

```markdown
---
name: implement
description: Run the implementation loop for a spec — implement each task group per the spec,
  verify, record progress. Triggers on "implement the spec", "harness implement",
  "run the implementation loop", "/implement". For low-care projects or specs the developer
  delegated; drives the `harness implement` state machine.
harness_model_role: default
---

# Implement

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.

## Steps
1. Determine the spec slug (ask if ambiguous — use the structured question tool if available
   (`ask_user_question` / `AskUserQuestion`); otherwise a plain numbered list).
   Run `harness implement <slug> status`.
2. For each group that is not `done`, in order:
   a. Run `harness implement <slug> next` — its stdout is your complete working packet.
      Read every file it points to: the spec section, each context file, naming-conventions.md,
      and `dependencies/registry.md` sources when the packet lists them.
   b. Explore the current codebase state, especially files written by prior groups.
   c. Implement every step in order, following the spec exactly. All names must follow
      naming-conventions.md. Never deviate from the spec without asking.
   d. Steps tagged `[dev]` are the developer's: never write them — stop, say exactly what to
      implement, and wait for confirmation before continuing.
   e. Run `harness implement <slug> verify <Tn>`. On failure load
      `references/verification.md` and follow the retry protocol.
   f. On pass: `harness implement <slug> done <Tn>`, then continue to the next group.
3. All groups done: if `manifest.json#workflow.post_implement_polish` is true and importance is
   "high", suggest running the polish skill. Then hand off to the commit skill.

## Platform note
Claude Code / pi: task groups run serially. Between groups, re-run `status` and read the fresh
`next` packet instead of relying on memory of earlier groups — the packet is the state.
OMP: the same serial loop applies; native per-group subagent dispatch is deferred.

## Rules
- Never proceed past a failed verify without developer approval — the CLI refuses `done`
  after a fail; `--force` requires the developer's explicit go-ahead and a `--reason`.
- `Verify: manual` groups: pause, tell the developer what to check, and only after they
  confirm run `verify <Tn> --confirmed`.
- Write a session-note if you deviated at all (the `done` log line records only completion).
```

**File: `src/templates/skills/implement/references/verification.md`** — full content:

```markdown
# Verification Protocol

## On `verify <Tn>` failure
1. Read the failure tail the CLI printed (also stored in
   `.agent/docs/specs/<slug>/.implement-state.json` → `groups.<Tn>.last_output_tail`).
2. Form a single hypothesis before editing anything. Fix, then re-run `verify <Tn>`.
3. **Maximum 2 fix attempts.** After the second failed retry, stop and report to the
   developer: the verify command, exit code, last output tail, what you tried, and your
   current hypothesis. Wait for direction. Do not touch other task groups meanwhile.

## What never happens
- `done <Tn>` after a failed verify. The CLI blocks it; do not reach for `--force` yourself.
  `--force --reason "…"` is typed only when the developer explicitly says to skip, and the
  reason is their words, recorded in the state file and session log.
- Weakening a Verify command (or a test it runs) to make it pass. That is deviation from the
  spec — ask first.

## Timeouts
Verify commands are killed after 300s and recorded as failures. If the command is genuinely
long-running, tell the developer; they may split the group or mark it `Verify: manual`.

## `Verify: manual`
Present the group's steps and what "verified" means for them. After the developer confirms,
run `verify <Tn> --confirmed` — never before.
```

---

## Step 7: `polish` skill `[agent]`

- [ ] Create `src/templates/skills/polish/SKILL.md` + `references/polish-checklist.md`

**File: `src/templates/skills/polish/SKILL.md`** — full content (proposal §14's skill, adapted to
master §10: preflight block verbatim; `model_tier: frontier` → `harness_model_role: slow` per C10;
the importance gate moves behind the CLI call, which enforces it):

```markdown
---
name: polish
description: Deep code review for high-importance projects after spec implementation.
  Triggers on "run polish", "polish the code", "/polish", or after harness implement completes
  on high-importance projects. Only runs when manifest.json#workflow.importance is "high".
  Checks error handling, codepath coverage, and spec edge cases. May suggest small UX
  improvements but never applies them without approval.
harness_model_role: slow
---

# Polish

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.

## Steps
1. Run `harness polish <slug>`. If it exits with `polish-disabled`, relay its message and stop.
   Its stdout is your working packet: spec edge cases, `touches[]` globs, checklist path.
2. Load `references/polish-checklist.md`.
3. Read the completed spec (spec.md + spec-tasks.md) — note every listed edge case.
4. Read all files matching the packet's `touches[]` globs.
5. Run the error-handling check against the checklist.
6. Run the codepath-coverage check.
7. Check every spec edge case is implemented; search the touched files for remaining
   `throw new Error("Not implemented")` stubs.
8. Generate lightweight suggestions only (small, low-risk, no new spec required). This is a
   review: never apply changes — suggestions are presented, nothing is edited.
9. Present findings in the exact output format at the end of the checklist.
   Ask: add warnings to tasks.md inbox?
```

**File: `src/templates/skills/polish/references/polish-checklist.md`** — full content (the
checklist from proposal §14, verbatim in substance):

```markdown
# Polish Checklist

A semantic audit: is the code actually correct and complete? Not a style review.

## Error handling completeness
- Every async operation has a catch/error boundary
- Network errors are handled gracefully (not silently swallowed)
- Invalid input produces a clear user-facing error, not a crash
- Loading and empty states are explicitly handled (not just the happy path)

## Codepath coverage
- What happens when a list is empty?
- What happens when a required resource is missing or deleted?
- What happens when the user has no permissions?
- What happens when two users act on the same resource simultaneously?

## Edge cases from the spec
- Were all edge cases listed in the spec's "## Edge cases" section actually implemented?
- Are there any `throw new Error("Not implemented")` stubs still in the code?

## Suggested improvements (lightweight only)
Small, low-risk improvements that improve UX without architectural changes — suggestions
only, presented as a list, never applied without developer approval. Examples:
- A missing loading indicator on a slow operation
- A keyboard shortcut that would be natural given the UI
- An error message that could be more informative
- A missing confirmation dialog before a destructive action

Never suggest new features, architectural changes, or anything requiring a new spec.
Those go to `tasks.md` inbox if they're worth pursuing.

## Output format (exactly this shape)

    Polish complete for spec: collections-ui

    ## Error Handling
    ✅ FilterPanel — empty state handled
    ✅ Upload failures — toast notification shown
    ⚠️  BulkDeleteButton — no confirmation dialog before deletion of >1 item
        → Suggest: add AlertDialog (shadcn installed) before batch delete

    ## Codepath Coverage
    ✅ Empty collection — renders "No items" state
    ✅ Missing collection — 404 redirect handled in loader
    ⚠️  Concurrent edit — no conflict detection on save
        → Spec did not cover this. Add to tasks.md inbox?

    ## Spec Edge Cases
    ✅ All 3 edge cases from spec implemented

    ## Suggestions (your call, no action taken)
    - [ ] Add keyboard shortcut Cmd+K to open filter panel (natural given Command palette)
    - [ ] "No items match your filters" empty state is more specific than "No items"

    2 warnings. 2 suggestions. No blocking issues.
    Add warnings to tasks.md inbox? (yes / no)
```

---

## Verification (mandatory)

- [ ] `cd harness && bun test` — all green (including all earlier phases' suites)
- [ ] `bunx tsc --noEmit` — clean
- [ ] Manual smoke: in a tmp copy of the `initialized` fixture with the demo spec seeded, walk the
      full loop by hand: `status` → `next` → `verify T1` → `done T1` → `status` shows T2 next →
      `verify T3` blocks without `--confirmed` → `polish demo-feature` errors on medium, prints
      the packet on high.
- [ ] No skipped tests; no new doctor checks were added (out of scope).

## Success Criteria

- [ ] `implement status` golden table and `next` packet match byte-exact on the demo fixture
- [ ] Full loop works: verify pass → done ticks exactly that group's boxes, state json records
      attempts/result/tail, session log gains the line, resume picks up at T2
- [ ] Failed verify (exit 1) blocks `done`; `--force` demands `--reason` and records it
- [ ] `Verify: manual` requires `--confirmed`; confirmed manual passes gate `done`
- [ ] `polish` refuses with the proposal's exact message on `importance !== "high"`, emits the
      golden packet on high, and performs zero code analysis (D12)
- [ ] Both SKILL.md files ≤150 lines with valid frontmatter (name + description)
```
