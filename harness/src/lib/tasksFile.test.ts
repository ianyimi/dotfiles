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
  test("round-trip stability", () => {
    const once = serializeTasksFile({ doc: parseTasksFile({ text: SAMPLE }) });
    expect(serializeTasksFile({ doc: parseTasksFile({ text: once }) })).toBe(once);
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
    expect(() => moveTask({ doc, titleSubstr: "nope", to: "done" })).toThrow(/no task matches/i);
    expect(() => moveTask({ doc, titleSubstr: "e", to: "done" })).toThrow(/ambiguous/i);
  });
});
