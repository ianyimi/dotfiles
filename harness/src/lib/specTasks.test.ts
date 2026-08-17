import { describe, expect, test } from "bun:test";
import { DEMO_SPEC_TASKS } from "../../test/specFixture.ts";
import { parseSpecTasks, tickGroup } from "./specTasks.ts";

describe("parseSpecTasks", () => {
  test("parses the Step-N heading convention (id captured verbatim)", () => {
    const text = `---\nspec_id: step-demo\n---\n\n## Step 1 — Scaffold\nWhy: because\nVerify: manual\n\n- [ ] 1. do a thing\n`;
    const st = parseSpecTasks({ text });
    expect(st.groups.map((g) => g.id)).toEqual(["Step 1"]);
    expect(st.groups[0]!.title).toBe("Scaffold");
  });

  test("parses the demo fixture exactly", () => {
    const st = parseSpecTasks({ text: DEMO_SPEC_TASKS });
    expect(st.frontmatter["spec_id"]).toBe("demo-feature");
    expect(st.frontmatter["touches"]).toEqual(["src/demo/**"]);
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
    const bad = `${DEMO_SPEC_TASKS}\n## T4 — Empty\nWhy: x\nVerify: manual\n`;
    expect(() => parseSpecTasks({ text: bad })).toThrow(/T4 has no steps/);
  });
  test("duplicate group id throws", () => {
    const bad = `${DEMO_SPEC_TASKS}\n## T1 — Again\nVerify: manual\n\n- [ ] 1. x\n`;
    expect(() => parseSpecTasks({ text: bad })).toThrow(/duplicate group id T1/);
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
