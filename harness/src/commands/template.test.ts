import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkHarnessHome, mkTmpProject, rmHarnessHome, rmProject, runCli } from "../../test/helpers.ts";
import { EMBEDDED_SKILLS_DIR } from "./template.ts";

let home = "";
beforeEach(() => {
  home = mkHarnessHome();
});
afterEach(() => {
  rmHarnessHome({ dir: home });
});

describe("harness template", () => {
  test("round-trip: save from initialized → init scaffold --template on empty project", async () => {
    const src = mkTmpProject({ fixture: "initialized" }); // + git, one dep pin, skill customizations
    const m = JSON.parse(readFileSync(join(src, ".agent/manifest.json"), "utf8"));
    m.dependencies = [{ package: "convex", version: "1.17.0", repo: "github.com/get-convex/convex-backend" }];
    writeFileSync(join(src, ".agent/manifest.json"), JSON.stringify(m, null, 2));
    writeFileSync(join(src, ".agent/docs/standards/naming-conventions.md"), "# Naming\nrules here\n");
    // custom skill (no embedded counterpart) → must be seeded
    mkdirSync(join(src, ".agent/skills/custom-x"), { recursive: true });
    writeFileSync(join(src, ".agent/skills/custom-x/SKILL.md"), "---\nname: custom-x\ndescription: d\n---\nbody\n");
    // pristine copy of an embedded default → must NOT be seeded
    cpSync(join(EMBEDDED_SKILLS_DIR, "init"), join(src, ".agent/skills/init"), { recursive: true });
    gitInit({ dir: src });

    const saved = await runCli({ argv: ["template", "save", "round-trip"], cwd: src });
    expect(saved.code).toBe(0);
    const tpl = JSON.parse(readFileSync(join(home, "templates/round-trip/template.json"), "utf8"));
    expect(tpl.saved_at_sha).toMatch(/^[0-9a-f]{40}$/);
    expect(tpl.source_project).toBe("initialized");
    expect(tpl.prefilled["3"]).toEqual({ domains: ["backend"] });
    expect(tpl.prefilled["6"]).toEqual({
      dependencies: [{ package: "convex", repo: "github.com/get-convex/convex-backend" }],
    }); // version STRIPPED
    expect(tpl.prefilled["7"]).toEqual({ workflow: m.workflow, modules: m.modules, platforms: m.platforms });
    expect(tpl.prefilled["2"]).toBeUndefined();
    expect(existsSync(join(home, "templates/round-trip/skills_seed/custom-x/SKILL.md"))).toBe(true);
    expect(existsSync(join(home, "templates/round-trip/skills_seed/init"))).toBe(false);
    expect(existsSync(join(home, "templates/round-trip/standards_seed/naming-conventions.md"))).toBe(true);

    const dst = mkTmpProject({ fixture: "empty-project" }); // fresh project: scaffold from template
    const scaf = await runCli({ argv: ["init", "scaffold", "--template", "round-trip"], cwd: dst });
    expect(scaf.code).toBe(0);
    const progress = readFileSync(join(dst, ".agent/.setup-progress.md"), "utf8");
    for (const n of ["3", "6", "7"]) expect(progress).toContain(`### Phase ${n}`);
    expect(JSON.parse(progress.match(/### Phase 6\n+```json\n([\s\S]*?)\n```/)![1]!)).toEqual(tpl.prefilled["6"]); // staged verbatim
    expect(progress).toMatch(/template: round-trip/); // phase-7 backfill source
    expect(readFileSync(join(dst, ".agent/skills/custom-x/SKILL.md"), "utf8")).toContain("custom-x");
    expect(existsSync(join(dst, ".agent/docs/standards/naming-conventions.md"))).toBe(true);

    const status = await runCli({ argv: ["init", "status"], cwd: dst });
    for (const line of ["Phase 3", "Phase 6", "Phase 7"]) {
      expect(status.stdout).toMatch(new RegExp(`${line}.*prefilled \\(confirm or edit\\)`));
    }
    expect(status.stdout).not.toMatch(/Phase 1.*prefilled/);
    rmProject({ dir: src });
    rmProject({ dir: dst });
  });

  test("save twice needs --force; --force drops stale seed files", async () => {
    const src = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(src, ".agent/docs/standards/naming-conventions.md"), "# Naming v1\n");
    expect((await runCli({ argv: ["template", "save", "twice"], cwd: src })).code).toBe(0);
    const again = await runCli({ argv: ["template", "save", "twice"], cwd: src });
    expect(again.code).toBe(2);
    expect(again.stderr).toContain("--force");

    // Remove the naming file → forced re-save must drop the stale seed.
    const { rmSync } = await import("node:fs");
    rmSync(join(src, ".agent/docs/standards/naming-conventions.md"));
    expect((await runCli({ argv: ["template", "save", "twice", "--force"], cwd: src })).code).toBe(0);
    expect(existsSync(join(home, "templates/twice/standards_seed/naming-conventions.md"))).toBe(false);
    rmProject({ dir: src });
  });

  test("save outside an initialized project → not-initialized with init hint", async () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    const { mkdirSync: mkdir } = await import("node:fs");
    mkdir(join(dir, ".git"), { recursive: true });
    const r = await runCli({ argv: ["template", "save", "nope"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("not initialized");
    rmProject({ dir });
  });

  test("list + inspect exact output; unknown names hint at list; delete removes", async () => {
    expect((await runCli({ argv: ["template", "list"], cwd: home })).stdout).toBe("no templates saved");

    const src = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir: src });
    await runCli({ argv: ["template", "save", "zz-one"], cwd: src });
    await runCli({ argv: ["template", "save", "aa-two"], cwd: src });
    const sha = JSON.parse(readFileSync(join(home, "templates/aa-two/template.json"), "utf8")).saved_at_sha.slice(0, 7);

    const list = await runCli({ argv: ["template", "list"], cwd: home });
    const lines = list.stdout.split("\n");
    expect(lines[0]).toContain("aa-two");
    expect(lines[0]).toContain(sha);
    expect(lines[1]).toContain("zz-one");

    const tpl = JSON.parse(readFileSync(join(home, "templates/aa-two/template.json"), "utf8"));
    const inspect = await runCli({ argv: ["template", "inspect", "aa-two"], cwd: home });
    expect(inspect.stdout).toBe(
      [
        "template: aa-two",
        `source:   initialized (saved ${tpl.saved_at} at ${sha} by harness ${tpl.harness_version})`,
        "prefilled phases: 3 (domains), 7 (workflow/modules/platforms)",
        "standards_seed: naming-conventions.md",
        "skills_seed: dev-spec, implement",
      ].join("\n"),
    );

    const badInspect = await runCli({ argv: ["template", "inspect", "ghost"], cwd: home });
    expect(badInspect.code).toBe(2);
    expect(badInspect.stderr).toContain("harness template list");

    expect((await runCli({ argv: ["template", "delete", "aa-two"], cwd: home })).code).toBe(0);
    expect(existsSync(join(home, "templates/aa-two"))).toBe(false);
    expect((await runCli({ argv: ["template", "delete", "aa-two"], cwd: home })).code).toBe(2);
    rmProject({ dir: src });
  });
});
