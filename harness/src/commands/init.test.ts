import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { loadManifest } from "../lib/manifest.ts";

/** Writes phase data to a temp file and runs write-phase against it. */
async function writePhase(dir: string, phase: number, data: unknown) {
  const dataPath = join(dir, `.phase-${phase}.json`);
  writeFileSync(dataPath, JSON.stringify(data));
  return runCli({ argv: ["init", "write-phase", String(phase), "--data", dataPath], cwd: dir });
}

const SAMPLE = {
  1: { project: "sample-app", description: "A sample app", language: "typescript", repo_type: "standard" },
  2: { purpose: "Testing the harness", team: "solo" },
  3: { domains: ["backend", "testing"] },
  4: { tech_stack_md: "# Tech Stack\n\n- `yaml` — parsing" },
  5: {
    dev_processes_md: "# Dev Processes\n\n| `bun run build` | Build |",
    env_vars: [{ name: "DATABASE_URL", desc: "Postgres connection string", required: true }],
  },
  6: { dependencies: [{ package: "yaml", version: "2.9.0", repo: "github.com/eemeli/yaml" }] },
  7: {
    platforms: { active: ["omp", "claude"] },
    workflow: {
      default_tier: "low-care",
      importance: "medium",
      developer_implements: false,
      post_implement_polish: false,
      commit_mode: "message-only",
    },
    modules: {
      specs: true, tasks: true, session_log: true, roadmap: false, design: false,
      decisions: true, research: true, env_manifest: true, naming_conventions: false,
    },
  },
  8: { naming_conventions_md: "" },
  9: { mission_md: "# Mission\n\nShip the sample." },
} as const;

describe("init scaffold", () => {
  test("creates the full skeleton on empty-project and is idempotent", async () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    gitInit({ dir });
    const first = await runCli({ argv: ["init", "scaffold"], cwd: dir });
    expect(first.code).toBe(0);
    for (const p of [
      ".agent/AGENTS.md",
      ".agent/.setup-progress.md",
      ".agent/docs/tasks.md",
      ".agent/dependencies/.gitignore",
      ".agent/dependencies/registry.md",
      ".agent/skills/init/SKILL.md",
      ".agent/skills/init/references/phases.md",
    ]) {
      expect(existsSync(join(dir, p))).toBe(true);
    }
    expect(readFileSync(join(dir, ".agent/AGENTS.md"), "utf8")).toContain("Harness Not Initialized");

    const second = await runCli({ argv: ["init", "scaffold"], cwd: dir });
    expect(second.stdout).toBe("nothing to create — scaffold already complete");

    // Deleting one file and re-running restores only it.
    rmSync(join(dir, ".agent/docs/tasks.md"));
    const third = await runCli({ argv: ["init", "scaffold"], cwd: dir });
    expect(third.stdout).toBe("created: .agent/docs/tasks.md");
    rmProject({ dir });
  });
});

describe("init write-phase", () => {
  test("phase 4 writes tech-stack.md with verified_at frontmatter", async () => {
    const dir = mkTmpProject({ fixture: "ts-monorepo" });
    gitInit({ dir });
    await runCli({ argv: ["init", "scaffold"], cwd: dir });
    const r = await writePhase(dir, 4, SAMPLE[4]);
    expect(r.code).toBe(0);
    const text = readFileSync(join(dir, ".agent/docs/product/tech-stack.md"), "utf8");
    expect(text).toMatch(/^---\nverified_at: [0-9a-f]{40}\n---\n\n# Tech Stack/);
    rmProject({ dir });
  });

  test("phase 7 before phase 1 → init-incomplete", async () => {
    const dir = mkTmpProject({ fixture: "ts-monorepo" });
    await runCli({ argv: ["init", "scaffold"], cwd: dir });
    const r = await writePhase(dir, 7, SAMPLE[7]);
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("requires phase 1");
    rmProject({ dir });
  });

  test("invalid data shape → usage error naming the key", async () => {
    const dir = mkTmpProject({ fixture: "ts-monorepo" });
    await runCli({ argv: ["init", "scaffold"], cwd: dir });
    const r = await writePhase(dir, 1, { project: "x" });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("`description`");
    rmProject({ dir });
  });

  test("full 1→9 + finish yields a loadable manifest and post-init AGENTS.md", async () => {
    const dir = mkTmpProject({ fixture: "ts-monorepo" });
    gitInit({ dir });
    await runCli({ argv: ["init", "scaffold"], cwd: dir });
    for (const n of [1, 2, 3, 4, 5, 6, 7, 8, 9] as const) {
      const r = await writePhase(dir, n, SAMPLE[n]);
      expect(r.code).toBe(0);
    }
    const finish = await runCli({ argv: ["init", "finish"], cwd: dir });
    expect(finish.code).toBe(0);
    expect(finish.stdout).toContain("harness initialized for sample-app");

    const { manifest } = loadManifest({ root: dir });
    expect(manifest.project).toBe("sample-app");
    expect(manifest.standards_domains).toEqual(["backend", "testing"]);
    expect(manifest.dependencies).toEqual([{ package: "yaml", version: "2.9.0", repo: "github.com/eemeli/yaml" }]);
    expect(manifest.workflow.commit_mode).toBe("message-only");

    expect(existsSync(join(dir, ".agent/.setup-progress.md"))).toBe(false);
    const agents = readFileSync(join(dir, ".agent/AGENTS.md"), "utf8");
    expect(agents).toContain("# sample-app — Agent Context");
    expect(agents).toContain("## Agent Directives");

    // env manifest got the 03-compatible table shape.
    const env = readFileSync(join(dir, ".agent/env.manifest.md"), "utf8");
    expect(env).toContain("| VAR | required | description |");
    expect(env).toContain("| DATABASE_URL | yes | Postgres connection string |");

    // Standards domain folders exist with README stubs.
    expect(readFileSync(join(dir, ".agent/docs/standards/backend/README.md"), "utf8")).toBe("# backend standards\n");

    // Doctor and state now run clean end-to-end on the initialized project.
    const doctor = await runCli({ argv: ["doctor"], cwd: dir });
    expect(doctor.code).toBe(0);
    const state = await runCli({ argv: ["state"], cwd: dir });
    expect(state.code).toBe(0);
    expect(state.stdout).toContain("# Project State");
    rmProject({ dir });
  });

  test("finish before completing phases lists the missing ones", async () => {
    const dir = mkTmpProject({ fixture: "ts-monorepo" });
    await runCli({ argv: ["init", "scaffold"], cwd: dir });
    await writePhase(dir, 1, SAMPLE[1]);
    const r = await runCli({ argv: ["init", "finish"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("phases not completed: 2, 3, 4, 5, 6, 7, 8, 9");
    rmProject({ dir });
  });

  test("status marks phases with recorded data", async () => {
    const dir = mkTmpProject({ fixture: "ts-monorepo" });
    await runCli({ argv: ["init", "scaffold"], cwd: dir });
    await writePhase(dir, 1, SAMPLE[1]);
    const r = await runCli({ argv: ["init", "status"], cwd: dir });
    expect(r.stdout).toContain("- [x] Phase 1 — Project Identity");
    expect(r.stdout).toContain("- [ ] Phase 2 — Project Purpose + Team");
    rmProject({ dir });
  });
});
