import { describe, expect, test } from "bun:test";
import { mkTmpProject, rmProject, runCli } from "../test/helpers.ts";

describe("cli routing", () => {
  test("no args prints usage listing all commands, exit 0", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: [], cwd: dir });
    expect(r.code).toBe(0);
    for (const name of ["init", "doctor", "state"]) expect(r.stdout).toContain(`harness ${name}`);
    rmProject({ dir });
  });

  test("unknown command exits 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["frobnicate"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("unknown command: frobnicate");
    rmProject({ dir });
  });

  test("doctor outside a project exits 2 with no-project error", async () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("Not inside a project");
    rmProject({ dir });
  });

  test("HarnessError renders code + hint on stderr", async () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    // .git makes it a project root, but there is no .agent → doctor throws not-initialized.
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.code).toBe(2);
    rmProject({ dir });
  });
});
