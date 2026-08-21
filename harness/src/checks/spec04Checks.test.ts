import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";

const GIT_ENV = {
  ...process.env,
  GIT_AUTHOR_NAME: "t",
  GIT_AUTHOR_EMAIL: "t@t",
  GIT_COMMITTER_NAME: "t",
  GIT_COMMITTER_EMAIL: "t@t",
};

function commitAll(dir: string, msg: string): void {
  execFileSync("git", ["add", "-A"], { cwd: dir, env: GIT_ENV });
  execFileSync("git", ["commit", "-q", "-m", msg], { cwd: dir, env: GIT_ENV });
}

async function syncedRepo(): Promise<string> {
  const dir = mkTmpProject({ fixture: "initialized" });
  gitInit({ dir });
  await runCli({ argv: ["sync"], cwd: dir });
  commitAll(dir, "sync bridges");
  await runCli({ argv: ["sync"], cwd: dir }); // refresh generated_at_sha to the new HEAD
  return dir;
}

describe("shims-stale check", () => {
  test("clean after sync; flags .agent changes and missing managed paths", async () => {
    const dir = await syncedRepo();
    const clean = await runCli({ argv: ["doctor"], cwd: dir });
    expect(clean.stdout).toContain("✅ OK     shims-stale");

    writeFileSync(join(dir, ".agent/docs/standards/backend/api.md"), "---\napplies_to: [\"convex/**\"]\n---\n\n# API\n\nChanged.\n");
    commitAll(dir, "change standards");
    const stale = await runCli({ argv: ["doctor"], cwd: dir });
    expect(stale.stdout).toContain(".agent/ changed since last sync");

    rmSync(join(dir, ".omp/AGENTS.md"));
    const missing = await runCli({ argv: ["doctor"], cwd: dir });
    expect(missing.stdout).toContain(".omp/AGENTS.md is missing on disk");
    rmProject({ dir });
  });
});

describe("context-rules-stale check", () => {
  test("silent pre-sync; clean post-sync; catches new domain and dead naming rule", async () => {
    const fresh = mkTmpProject({ fixture: "initialized" });
    const pre = await runCli({ argv: ["doctor", "--json"], cwd: fresh });
    const preItems = JSON.parse(pre.stdout) as Array<{ id?: string }>;
    expect(preItems.some((i) => i.id === "context-rules-stale")).toBe(false); // never synced → skipped
    rmProject({ dir: fresh });

    const dir = await syncedRepo();
    const clean = await runCli({ argv: ["doctor"], cwd: dir });
    expect(clean.stdout).toContain("✅ OK     context-rules-stale");

    mkdirSync(join(dir, ".agent/docs/standards/frontend"), { recursive: true });
    writeFileSync(join(dir, ".agent/docs/standards/frontend/state.md"), "---\napplies_to: [\"src/app/**\"]\n---\n\n# State\n\nRules.\n");
    const manifestPath = join(dir, ".agent/manifest.json");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    manifest.standards_domains.push("frontend");
    writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    const missing = await runCli({ argv: ["doctor"], cwd: dir });
    expect(missing.stdout).toContain("rule std-frontend missing from context-rules.yaml");

    rmSync(join(dir, ".agent/docs/standards/naming-conventions.md"));
    const stale = await runCli({ argv: ["doctor"], cwd: dir });
    expect(stale.stdout).toContain("rule naming is stale (source gone)");
    rmProject({ dir });
  });
});
