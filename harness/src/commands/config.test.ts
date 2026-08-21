import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";

const manifest = (dir: string) => JSON.parse(readFileSync(join(dir, ".agent/manifest.json"), "utf8"));

describe("harness config", () => {
  test("list shows all keys with values; get returns one", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const list = await runCli({ argv: ["config"], cwd: dir });
    expect(list.code).toBe(0);
    expect(list.stdout).toContain("models.subagent_selection = dynamic  (dynamic | uniform)");
    expect(list.stdout).toContain("models.advisor = true");
    expect(list.stdout).toContain("workflow.commit_mode = message-only");
    const get = await runCli({ argv: ["config", "get", "models.tiers.cheap"], cwd: dir });
    expect(get.stdout).toContain("anthropic/claude-haiku-4-5");
    rmProject({ dir });
  });

  test("set validates literals and persists; bridge-affecting keys auto-sync", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    await runCli({ argv: ["sync"], cwd: dir });

    const bad = await runCli({ argv: ["config", "set", "models.subagent_selection", "sometimes"], cwd: dir });
    expect(bad.code).toBe(2);
    expect(bad.stderr).toContain("dynamic | uniform");

    const setSel = await runCli({ argv: ["config", "set", "models.subagent_selection", "uniform"], cwd: dir });
    expect(setSel.code).toBe(0);
    expect(manifest(dir).models.subagent_selection).toBe("uniform");
    expect(setSel.stdout).not.toContain("sync:"); // non-bridge key → no auto-sync

    const setTier = await runCli({ argv: ["config", "set", "models.tiers.cheap", "anthropic/claude-haiku-latest"], cwd: dir });
    expect(setTier.code).toBe(0);
    expect(setTier.stdout).toContain("sync:"); // bridge-affecting → auto-synced
    expect(readFileSync(join(dir, ".omp/config.yml"), "utf8")).toContain("anthropic/claude-haiku-latest");

    const setAdvisor = await runCli({ argv: ["config", "set", "models.advisor", "false"], cwd: dir });
    expect(setAdvisor.code).toBe(0);
    expect(readFileSync(join(dir, ".omp/config.yml"), "utf8")).toContain("enabled: false");

    const unknown = await runCli({ argv: ["config", "set", "models.nope", "x"], cwd: dir });
    expect(unknown.code).toBe(2);
    expect(unknown.stderr).toContain("unknown config key");
    rmProject({ dir });
  });
});
