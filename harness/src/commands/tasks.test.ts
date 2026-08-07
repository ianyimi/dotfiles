import { describe, expect, test } from "bun:test";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";

describe("harness tasks", () => {
  test("add → inbox; move → in-progress; noop re-run", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const add = await runCli({ argv: ["tasks", "add", "Try worktrees"], cwd: dir });
    expect(add.code).toBe(0);
    let text = readFileSync(join(dir, ".agent/docs/tasks.md"), "utf8");
    expect(text).toMatch(/## Inbox\n(- .*\n)*- Try worktrees/);

    const move = await runCli({ argv: ["tasks", "move", "Try work", "--to", "in-progress"], cwd: dir });
    expect(move.code).toBe(0);
    expect(move.stdout).toContain("moved");
    text = readFileSync(join(dir, ".agent/docs/tasks.md"), "utf8");
    expect(text).toMatch(/## In Progress\n(- .*\n)*- Try worktrees/);

    const noop = await runCli({ argv: ["tasks", "move", "Try work", "--to", "in-progress"], cwd: dir });
    expect(noop.code).toBe(0);
    expect(noop.stdout).toContain("already in");
    rmProject({ dir });
  });

  test("bad section, missing task, and module gate error cleanly", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    expect((await runCli({ argv: ["tasks", "add", "X", "--to", "bogus"], cwd: dir })).code).toBe(2);

    const missing = await runCli({ argv: ["tasks", "move", "does-not-exist", "--to", "done"], cwd: dir });
    expect(missing.code).toBe(2);
    expect(missing.stderr).toContain("harness tasks add");

    const manifestPath = join(dir, ".agent/manifest.json");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    manifest.modules.tasks = false;
    writeFileSync(manifestPath, JSON.stringify(manifest));
    const gated = await runCli({ argv: ["tasks", "add", "X"], cwd: dir });
    expect(gated.code).toBe(2);
    expect(gated.stderr).toContain("module-disabled");
    rmProject({ dir });
  });
});
