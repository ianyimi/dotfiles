import { describe, expect, test } from "bun:test";
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, readlinkSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gitInit, runCli } from "./helpers.ts";
import { headCommitDate } from "../src/lib/git.ts";

const PHASES: Record<number, unknown> = {
  1: { project: "e2e-smoke", description: "E2E smoke project", language: "typescript", repo_type: "standard" },
  2: { purpose: "prove the cold-start cycle", team: "solo" },
  3: { domains: ["backend"] },
  4: { tech_stack_md: "# Tech Stack\n\nTypeScript on Bun. Minimal by design." },
  5: { dev_processes_md: "# Dev Processes\n\nRun the test script to verify changes.", env_vars: [] },
  6: { dependencies: [] },
  7: {
    platforms: { active: ["claude"] },
    workflow: {
      default_tier: "low-care",
      importance: "medium",
      developer_implements: false,
      post_implement_polish: false,
      commit_mode: "message-only",
    },
    modules: {
      specs: true, tasks: true, session_log: true, roadmap: false, design: false,
      decisions: false, research: true, env_manifest: true, naming_conventions: false,
    },
  },
  8: { naming_conventions_md: "" },
  9: { mission_md: "# Mission\n\nProve the harness cold-start cycle." },
};

describe("e2e: cold start to session cycle", () => {
  test("scaffold → phases → finish → sync → doctor → spec → implement → tasks → log → state", async () => {
    const dir = mkdtempSync(join(tmpdir(), "harness-e2e-"));
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "e2e-smoke", version: "0.0.0", scripts: { test: "true" } }));
    mkdirSync(join(dir, "src"));
    writeFileSync(join(dir, "src/index.ts"), "export const a = 1;\n");
    gitInit({ dir });
    const day = headCommitDate({ root: dir });

    // 1–3. init: scaffold, phases 1–9, finish.
    expect((await runCli({ argv: ["install"], cwd: dir })).code).toBe(0);
    for (const n of [1, 2, 3, 4, 5, 6, 7, 8, 9]) {
      const dataPath = join(dir, `.p${n}.json`);
      writeFileSync(dataPath, JSON.stringify(PHASES[n]));
      const r = await runCli({ argv: ["init", "write-phase", String(n), "--data", dataPath], cwd: dir });
      expect(r.code).toBe(0);
      rmSync(dataPath);
    }
    expect((await runCli({ argv: ["init", "finish"], cwd: dir })).code).toBe(0);
    expect(existsSync(join(dir, ".agent/.setup-progress.md"))).toBe(false);
    expect(readFileSync(join(dir, ".agent/AGENTS.md"), "utf8")).toContain("## Agent Directives");

    // 4. sync + index rebuild.
    expect((await runCli({ argv: ["sync"], cwd: dir })).code).toBe(0);
    expect(lstatSync(join(dir, ".claude/skills")).isSymbolicLink()).toBe(true);
    expect(readlinkSync(join(dir, ".claude/skills"))).toBe("../.agent/skills");
    expect(readFileSync(join(dir, ".claude/CLAUDE.md"), "utf8").startsWith("@.agent/AGENTS.md")).toBe(true);
    expect(readFileSync(join(dir, ".agent/.sync-manifest.json"), "utf8").length).toBeGreaterThan(2);
    expect((await runCli({ argv: ["index", "rebuild"], cwd: dir })).code).toBe(0);

    // 5. doctor exits 0.
    expect((await runCli({ argv: ["doctor"], cwd: dir })).code).toBe(0);

    // 6. spec new.
    expect((await runCli({ argv: ["spec", "new", "smoke-feature"], cwd: dir })).code).toBe(0);
    const specDirs = readdirSync(join(dir, ".agent/docs/specs")).filter((d) => d.endsWith("smoke-feature"));
    expect(specDirs).toHaveLength(1);
    const slug = specDirs[0] as string;
    expect(existsSync(join(dir, ".agent/docs/specs", slug, "spec.md"))).toBe(true);
    expect(existsSync(join(dir, ".agent/docs/specs", slug, "spec-tasks.md"))).toBe(true);

    // 7. implement status lists Step 1 open.
    const status = await runCli({ argv: ["implement", slug, "status"], cwd: dir });
    expect(status.code).toBe(0);
    expect(status.stdout).toContain("Step 1");
    expect(status.stdout).toContain("next");

    // 8. tasks add + move.
    expect((await runCli({ argv: ["tasks", "add", "Smoke task"], cwd: dir })).code).toBe(0);
    expect((await runCli({ argv: ["tasks", "move", "Smoke task", "--to", "done"], cwd: dir })).code).toBe(0);

    // 9. log append.
    expect((await runCli({ argv: ["log", "append", "--slug", "e2e smoke", "--date", `${day}T12:00`], cwd: dir })).code).toBe(0);
    const logPath = join(dir, ".agent/docs/session-log", day.slice(0, 4), day.slice(5, 7), `${day}.log.md`);
    expect(readFileSync(logPath, "utf8")).toContain(`## ${day} — 12:00 — e2e smoke`);

    // 10. uncommitted change → commit-msg.
    writeFileSync(join(dir, "src/index.ts"), "export const a = 2;\n");
    expect((await runCli({ argv: ["log", "commit-msg", "--date", day], cwd: dir })).code).toBe(0);
    expect(existsSync(logPath.replace(/\.log\.md$/, ".commit.md"))).toBe(true);

    // 11. state — golden (SHA-normalized). The cold-start claim: active spec, open tasks, and
    // last session all present in this one output.
    const state = await runCli({ argv: ["state"], cwd: dir });
    expect(state.code).toBe(0);
    const normalized = state.stdout.replace(/SHA: [0-9a-f]{40}/, "SHA: <sha>");
    expect(normalized).toBe(
      [
        "# Project State",
        "> GENERATED by `harness state` — do not edit. SHA: <sha>",
        "",
        "## Active specs",
        "",
        `- ${slug} — draft — 1 open / 1 total tasks`,
        "",
        "## Tasks",
        "",
        "## In Progress",
        "",
        "## Inbox",
        "",
        "## Recent sessions",
        "",
        `- ${day} — 12:00 — e2e smoke`,
        "",
        "## Doctor",
        "",
        "0 errors, 0 warnings at last run",
      ].join("\n"),
    );
    rmSync(dir, { recursive: true, force: true });
  });
});
