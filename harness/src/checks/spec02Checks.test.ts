import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { rmSync, writeFileSync } from "node:fs";
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

describe("naming-violations check", () => {
  test("flags recently committed violators; clean after their removal", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir }); // initial commit includes badFile.tsx + helperStuff.ts
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain("src/components/badFile.tsx violates react-components");
    expect(r.stdout).toContain("src/lib/helperStuff.ts violates lib-modules");
    expect(r.code).toBe(0); // warn only

    rmSync(join(dir, "src/components/badFile.tsx"));
    rmSync(join(dir, "src/lib/helperStuff.ts"));
    commitAll(dir, "remove offenders");
    const r2 = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r2.stdout).not.toContain("violates");
    rmProject({ dir });
  });

  test("unparseable rules block yields a single tolerant finding, no crash", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    writeFileSync(
      join(dir, ".agent/docs/standards/naming-conventions.md"),
      "# NC\n\n```yaml\nrules:\n  - id: broken\n    pattern: \"([\"\n    scope: [\"src/**\"]\n    description: d\n```\n",
    );
    commitAll(dir, "break rules");
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain("naming-conventions.md rules block unparseable");
    expect(r.stdout).not.toContain("crashed");
    rmProject({ dir });
  });
});

describe("structure-stale check", () => {
  test("struct at HEAD passes; a new commit flags; re-struct passes again", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    await runCli({ argv: ["struct"], cwd: dir });
    commitAll(dir, "record struct");
    const clean = await runCli({ argv: ["doctor"], cwd: dir });
    expect(clean.stdout).not.toContain("tree changed since");

    writeFileSync(join(dir, "src/lib/new-module.ts"), "export const n = 1;\n");
    commitAll(dir, "add module");
    const stale = await runCli({ argv: ["doctor"], cwd: dir });
    expect(stale.stdout).toContain("directory-structure.md generated at");
    expect(stale.stdout).toContain("tree changed since");

    await runCli({ argv: ["struct"], cwd: dir });
    commitAll(dir, "re-struct");
    const again = await runCli({ argv: ["doctor"], cwd: dir });
    expect(again.stdout).not.toContain("tree changed since");
    rmProject({ dir });
  });

  test("SHA unknown in a repo counts as stale", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir }); // fixture ds.md says SHA: unknown
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain("directory-structure.md generated at unknown");
    rmProject({ dir });
  });
});

describe("index-stale check", () => {
  test("clean fixture → silent; new standards file → one finding", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const clean = await runCli({ argv: ["doctor"], cwd: dir });
    expect(clean.stdout).not.toContain("index.yml");

    writeFileSync(join(dir, ".agent/docs/standards/backend/migrations.md"), "# Migrations\n\nHow we migrate.\n");
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    const lines = r.stdout.split("\n").filter((l) => l.includes("index.yml"));
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain("backend/migrations.md not in index.yml");
    rmProject({ dir });
  });

  test("deleted indexed file → lists-missing finding", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    rmSync(join(dir, ".agent/docs/standards/backend/api.md"));
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r.stdout).toContain("index.yml lists missing backend/api");
    rmProject({ dir });
  });
});
