import { describe, expect, test } from "bun:test";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { seedDemoSpec } from "../../test/specFixture.ts";

function setImportance(dir: string, value: string): void {
  const p = join(dir, ".agent", "manifest.json");
  const m = JSON.parse(readFileSync(p, "utf8"));
  m.workflow.importance = value;
  writeFileSync(p, `${JSON.stringify(m, null, 2)}\n`);
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
    expect(r.stderr).toContain("Polish is only enabled for high-importance projects. Set importance: high in manifest.json.");
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
  test("missing Edge cases section degrades gracefully", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const specDir = seedDemoSpec({ dir });
    const specPath = join(specDir, "spec.md");
    writeFileSync(specPath, readFileSync(specPath, "utf8").replace("## Edge cases", "## Something else"));
    setImportance(dir, "high");
    const r = await runCli({ argv: ["polish", "demo-feature"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toContain('(spec.md has no "## Edge cases" section — review the spec manually)');
    rmProject({ dir });
  });
});
