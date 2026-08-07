import { describe, expect, test } from "bun:test";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import type { DoctorCheck } from "./doctor.ts";
import { runDoctor } from "./doctor.ts";
import { CHECKS } from "../checks/index.ts";
import { Reporter } from "../lib/output.ts";

function silentReporter(): Reporter {
  return new Reporter({ json: true, write: () => {} });
}

describe("doctor on healthy fixture", () => {
  test("exit 0 with ✅ lines for applicable checks", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toContain("✅ OK     preferences-over-budget");
    expect(r.stdout).toContain("✅ OK     anti-patterns-over-budget");
    expect(r.stdout).toContain("✅ OK     stale-commands");
    expect(r.stdout).not.toContain("🔴");
    rmProject({ dir });
  });

  test("--json emits machine-readable items", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["doctor", "--json"], cwd: dir });
    const items = JSON.parse(r.stdout) as Array<{ level: string; id?: string }>;
    expect(items.length).toBeGreaterThan(0);
    expect(items.every((i) => ["ok", "info", "warn", "error"].includes(i.level))).toBe(true);
    rmProject({ dir });
  });
});

describe("doctor seeded failures", () => {
  test("preferences over budget → error, exit 1", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const lines = Array.from({ length: 81 }, (_, i) => `- P-${String(i).padStart(3, "0")} (2026-01-01) filler`);
    writeFileSync(join(dir, ".agent/docs/standards/preferences.md"), `${lines.join("\n")}\n`);
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.code).toBe(1);
    expect(r.stdout).toContain("preferences.md is 81 lines (budget: 80)");
    expect(r.stdout).toContain("→ Run: harness pref compact");
    rmProject({ dir });
  });

  test("anti-patterns over budget → warn, exit stays 0", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const lines = Array.from({ length: 41 }, () => "- AP filler line");
    writeFileSync(join(dir, ".agent/docs/standards/anti-patterns.md"), `${lines.join("\n")}\n`);
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toContain("anti-patterns.md is 41 lines (budget: 40)");
    rmProject({ dir });
  });

  test("skill over 150 lines → warn naming the skill", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const pad = Array.from({ length: 151 }, (_, i) => `line ${i}`).join("\n");
    writeFileSync(join(dir, ".agent/skills/dev-spec/SKILL.md"), `${pad}\n`);
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain(".agent/skills/dev-spec/SKILL.md is 151 lines (budget: 150)");
    rmProject({ dir });
  });

  test("missing Agent Directives section → warn", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, ".agent/AGENTS.md"), "# ctx\n\nno directives here\n");
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain(`AGENTS.md has no "## Agent Directives" section`);
    rmProject({ dir });
  });

  test("stale command → warn naming the missing script", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const p = join(dir, ".agent/docs/product/dev-processes.md");
    writeFileSync(p, `${readFileSync(p, "utf8")}\n| \`bun run gone\` | Missing |\n`);
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain('package.json has no "gone" script');
    expect(r.stdout).not.toContain('no "build" script');
    rmProject({ dir });
  });

  test("stale package → warn; declared package silent", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const p = join(dir, ".agent/docs/product/tech-stack.md");
    writeFileSync(p, `${readFileSync(p, "utf8")}- \`ghost-pkg\` — not installed\n`);
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain("tech-stack.md lists `ghost-pkg`");
    expect(r.stdout).not.toContain("lists `yaml`");
    rmProject({ dir });
  });

  test("superseded ADR still in tech-stack → warn", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    mkdirSync(join(dir, ".agent/docs/decisions"), { recursive: true });
    writeFileSync(
      join(dir, ".agent/docs/decisions/ADR-001.md"),
      "---\nid: ADR-001\nstatus: Superseded\npackage: yaml\n---\n\n# ADR-001\n",
    );
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain("ADR-001.md is Superseded but tech-stack.md still lists `yaml`");
    rmProject({ dir });
  });
});

describe("doctor framework behavior", () => {
  test("doctor.checks filter runs exactly the listed checks", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const manifestPath = join(dir, ".agent/manifest.json");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    manifest.doctor.checks = ["preferences-over-budget"];
    writeFileSync(manifestPath, JSON.stringify(manifest));
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain("preferences-over-budget");
    expect(r.stdout).not.toContain("anti-patterns-over-budget");
    rmProject({ dir });
  });

  test("a crashing check reports an error line but the run completes", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const bomb: DoctorCheck = {
      id: "bomb",
      severity: "info",
      appliesWhen: () => true,
      run: () => {
        throw new Error("kaboom");
      },
    };
    const reporter = silentReporter();
    const code = runDoctor({ root: dir, checks: [bomb, ...CHECKS], reporter });
    expect(reporter.items.some((i) => i.message === "check bomb crashed: kaboom")).toBe(true);
    expect(code).toBe(1); // crash is reported as an error finding
    expect(reporter.items.some((i) => i.id === "preferences-over-budget")).toBe(true);
    rmProject({ dir });
  });
});
