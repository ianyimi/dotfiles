import { describe, expect, test } from "bun:test";
import { appendFileSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { DEMO_SPEC_TASKS, seedDemoSpec } from "../../test/specFixture.ts";

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
    expect(r.stdout).toContain('Verify: bun -e "process.exit(0)"');
    rmProject({ dir });
  });
  test("dep note appears iff registry.md has entries", async () => {
    const { dir } = setup();
    appendFileSync(join(dir, ".agent", "dependencies", "registry.md"), "\n| convex | 1.17.0 | github.com/x/y | abc |\n");
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
    const y = String(now.getFullYear());
    const m = String(now.getMonth() + 1).padStart(2, "0");
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
    writeFileSync(tasksPath(specDir), DEMO_SPEC_TASKS.replace(`bun -e "console.log('t1 ok')"`, `bun -e "process.exit(1)"`));
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
      argv: ["implement", "demo-feature", "done", "T1", "--force", "--reason", "flaky sandbox"],
      cwd: dir,
    });
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
