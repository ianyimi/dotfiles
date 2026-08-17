import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { parseFrontmatter } from "../lib/frontmatter.ts";

describe("spec new", () => {
  test("creates both files with exact D02-1 frontmatter", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["spec", "new", "collections-ui", "--date", "2026-02-03"], cwd: dir });
    expect(r.code).toBe(0);
    const specDir = join(dir, ".agent/docs/specs/2026-02-03-collections-ui");
    expect(existsSync(join(specDir, "spec.md"))).toBe(true);
    expect(existsSync(join(specDir, "spec-tasks.md"))).toBe(true);
    const { data } = parseFrontmatter({ text: readFileSync(join(specDir, "spec.md"), "utf8") });
    expect(data).toEqual({ status: "draft", spec_id: "2026-02-03-collections-ui", touches: [], prompt_version: 1 });
    rmProject({ dir });
  });

  test("re-run → spec-exists, exit 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    await runCli({ argv: ["spec", "new", "collections-ui", "--date", "2026-02-03"], cwd: dir });
    const r = await runCli({ argv: ["spec", "new", "collections-ui", "--date", "2026-02-03"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toMatch(/already exists/);
    rmProject({ dir });
  });

  test("bad slug → exit 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["spec", "new", "My Spec", "--date", "2026-02-03"], cwd: dir });
    expect(r.code).toBe(2);
    rmProject({ dir });
  });

  test("no --date uses the system wall clock (today)", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["spec", "new", "no-date-spec"], cwd: dir });
    expect(r.code).toBe(0);
    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    expect(existsSync(join(dir, `.agent/docs/specs/${today}-no-date-spec/spec.md`))).toBe(true);
    rmProject({ dir });
  });

  test("no --date ignores the HEAD commit date, uses the wall clock", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir, date: "2026-01-15T12:00:00Z" });
    const r = await runCli({ argv: ["spec", "new", "git-dated"], cwd: dir });
    expect(r.code).toBe(0);
    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    expect(existsSync(join(dir, `.agent/docs/specs/${today}-git-dated`))).toBe(true);
    expect(existsSync(join(dir, ".agent/docs/specs/2026-01-15-git-dated"))).toBe(false);
    rmProject({ dir });
  });

  test("modules.specs off → module-disabled", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const manifestPath = join(dir, ".agent/manifest.json");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    manifest.modules.specs = false;
    writeFileSync(manifestPath, JSON.stringify(manifest));
    const r = await runCli({ argv: ["spec", "new", "nope", "--date", "2026-02-03"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("module-disabled");
    rmProject({ dir });
  });
});

describe("spec list", () => {
  test("skips done specs unless --all; counts checkboxes", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    await runCli({ argv: ["spec", "new", "collections-ui", "--date", "2026-02-03"], cwd: dir });
    await runCli({ argv: ["spec", "new", "finished-one", "--date", "2026-02-04"], cwd: dir });
    const donePath = join(dir, ".agent/docs/specs/2026-02-04-finished-one/spec.md");
    writeFileSync(donePath, readFileSync(donePath, "utf8").replace("status: draft", "status: done"));

    const r = await runCli({ argv: ["spec", "list"], cwd: dir });
    expect(r.stdout).toBe("2026-02-03-collections-ui  draft  1 open / 1 total");

    const all = await runCli({ argv: ["spec", "list", "--all"], cwd: dir });
    expect(all.stdout.split("\n")).toHaveLength(2);
    rmProject({ dir });
  });

  test("empty → (no open specs)", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["spec", "list"], cwd: dir });
    expect(r.stdout).toBe("(no open specs)");
    expect(r.code).toBe(0);
    rmProject({ dir });
  });
});
