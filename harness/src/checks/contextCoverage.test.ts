import { describe, expect, test } from "bun:test";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";

const findings = (stdout: string) =>
  JSON.parse(stdout).filter((i: { id?: string; level: string }) => i.id === "context-coverage" && i.level !== "ok");

describe("context-coverage", () => {
  test("synced fixture: src/ covered by naming scopes → clean; skipped pre-sync", async () => {
    const fresh = mkTmpProject({ fixture: "initialized" });
    const pre = JSON.parse((await runCli({ argv: ["doctor", "--json"], cwd: fresh })).stdout) as Array<{ id?: string }>;
    expect(pre.some((i) => i.id === "context-coverage")).toBe(false); // no context-rules.yaml yet
    rmProject({ dir: fresh });

    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    await runCli({ argv: ["sync"], cwd: dir });
    expect(findings((await runCli({ argv: ["doctor", "--json"], cwd: dir })).stdout)).toEqual([]);
    rmProject({ dir });
  });

  test("uncovered ≥5-file dir → exactly one info; sub-5-file dirs stay silent", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    await runCli({ argv: ["sync"], cwd: dir });
    mkdirSync(join(dir, "services"), { recursive: true });
    for (let i = 0; i < 5; i++) writeFileSync(join(dir, "services", `svc${i}.ts`), "export const s = 1;\n");
    mkdirSync(join(dir, "tiny"), { recursive: true });
    writeFileSync(join(dir, "tiny", "one.ts"), "export const t = 1;\n");
    const f = findings((await runCli({ argv: ["doctor", "--json"], cwd: dir })).stdout);
    expect(f).toHaveLength(1);
    expect(f[0].message).toBe("services/ (5 source files) matches no context rule");
    rmProject({ dir });
  });
});
