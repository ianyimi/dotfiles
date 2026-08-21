import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { sha256 } from "../lib/fsx.ts";

function ompOnlyFixture(): string {
  const dir = mkTmpProject({ fixture: "initialized" });
  const manifestPath = join(dir, ".agent/manifest.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  manifest.platforms.active = ["omp"];
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  gitInit({ dir });
  return dir;
}

describe("platform add / list", () => {
  test("add claude: manifest updated, bridge created, list flips", async () => {
    const dir = ompOnlyFixture();
    const before = await runCli({ argv: ["platform", "list"], cwd: dir });
    expect(before.stdout).toContain("omp    active");
    expect(before.stdout).toContain("claude available");

    const r = await runCli({ argv: ["platform", "add", "claude"], cwd: dir });
    expect(r.code).toBe(0);
    const manifest = JSON.parse(readFileSync(join(dir, ".agent/manifest.json"), "utf8"));
    expect(manifest.platforms.active).toEqual(["omp", "claude"]);
    expect(existsSync(join(dir, ".claude/CLAUDE.md"))).toBe(true);

    const after = await runCli({ argv: ["platform", "list"], cwd: dir });
    expect(after.stdout).toContain("claude active");
    rmProject({ dir });
  });

  test("unknown id → exit 2 naming it", async () => {
    const dir = ompOnlyFixture();
    const r = await runCli({ argv: ["platform", "add", "nope"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain('"nope"');
    rmProject({ dir });
  });

  test("duplicate add: already-active info, still idempotent on disk", async () => {
    const dir = ompOnlyFixture();
    await runCli({ argv: ["platform", "add", "claude"], cwd: dir });
    const hash1 = sha256({ text: readFileSync(join(dir, ".claude/CLAUDE.md"), "utf8") });
    const r = await runCli({ argv: ["platform", "add", "claude"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toContain("claude already active");
    expect(sha256({ text: readFileSync(join(dir, ".claude/CLAUDE.md"), "utf8") })).toBe(hash1);
    rmProject({ dir });
  });
});
