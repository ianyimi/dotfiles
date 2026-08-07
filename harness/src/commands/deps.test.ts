import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { gitInit, mkBareRepoWithTags, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { depDirname, readProjectPin, resolveRepoUrl, resolveTag } from "./deps.ts";

const repo = mkBareRepoWithTags();

describe("depDirname / resolveRepoUrl", () => {
  test("mappings", () => {
    expect(depDirname({ pkg: "convex" })).toBe("convex");
    expect(depDirname({ pkg: "@tanstack/form" })).toBe("tanstack__form");
    expect(resolveRepoUrl({ repo: "github.com/colinhacks/zod" })).toBe("https://github.com/colinhacks/zod");
    expect(resolveRepoUrl({ repo: "git://x/y" })).toBe("git://x/y");
    expect(resolveRepoUrl({ repo: "/abs/bare.git" })).toBe("/abs/bare.git");
  });
});

describe("readProjectPin", () => {
  test("package.json ranges, Cargo.toml plain + table forms, pyproject specifiers", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    writeFileSync(
      join(dir, "package.json"),
      JSON.stringify({
        name: "x",
        dependencies: { pkg: "^1.1.0", linked: "workspace:*" },
        devDependencies: { "dev-pkg": "~2.0.1" },
      }),
    );
    writeFileSync(join(dir, "Cargo.toml"), `[dependencies]\ntokio = "1.47.1"\nserde = { version = "1.0.219", features = ["derive"] }\n`);
    writeFileSync(join(dir, "pyproject.toml"), `[project]\ndependencies = ["fastapi>=0.115.0", "pydantic==2.9.2"]\n`);
    expect(readProjectPin({ root: dir, pkg: "pkg" })).toBe("1.1.0");
    expect(readProjectPin({ root: dir, pkg: "dev-pkg" })).toBe("2.0.1");
    expect(readProjectPin({ root: dir, pkg: "linked" })).toBeNull(); // no version substring
    expect(readProjectPin({ root: dir, pkg: "absent" })).toBeNull();
    expect(readProjectPin({ root: dir, pkg: "tokio" })).toBe("1.47.1");
    expect(readProjectPin({ root: dir, pkg: "serde" })).toBe("1.0.219");
    expect(readProjectPin({ root: dir, pkg: "fastapi" })).toBe("0.115.0");
    expect(readProjectPin({ root: dir, pkg: "pydantic" })).toBe("2.9.2");
    rmProject({ dir });
  });
});

describe("resolveTag", () => {
  test("candidate order and fallback", () => {
    expect(resolveTag({ repoUrl: repo.dir, pkg: "pkg", version: "1.0.0" })).toBe("v1.0.0");
    expect(resolveTag({ repoUrl: repo.dir, pkg: "pkg", version: "1.1.0" })).toBe("pkg@1.1.0");
    expect(resolveTag({ repoUrl: repo.dir, pkg: "other", version: "1.1.0" })).toBe("pkg@1.1.0"); // unique @-suffix scan
    expect(resolveTag({ repoUrl: repo.dir, pkg: "pkg", version: "9.9.9" })).toBeNull();
  });
});

function setDeps(dir: string, deps: object[]): void {
  const p = join(dir, ".agent", "manifest.json");
  const m = JSON.parse(readFileSync(p, "utf8"));
  m.dependencies = deps;
  writeFileSync(p, `${JSON.stringify(m, null, 2)}\n`);
}
const readManifestDeps = (dir: string) => JSON.parse(readFileSync(join(dir, ".agent", "manifest.json"), "utf8")).dependencies;

describe("harness deps", () => {
  test("clone: tag match, tree content, registry row", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setDeps(dir, [{ package: "pkg", version: "1.1.0", repo: repo.dir }]);
    expect((await runCli({ argv: ["deps", "clone"], cwd: dir })).code).toBe(0);
    expect(readFileSync(join(dir, ".agent/dependencies/pkg/lib.ts"), "utf8")).toBe("export const v = 2;\n");
    expect(readFileSync(join(dir, ".agent/dependencies/registry.md"), "utf8")).toContain(
      `| pkg | 1.1.0 | ${repo.dir} | ${repo.shaByTag["pkg@1.1.0"]} |`,
    );
    rmProject({ dir });
  });
  test("clone edge batch: unreachable repo warns + continues; no tag match → default branch + '(no tag match)'", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setDeps(dir, [
      { package: "gone", version: "1.0.0", repo: "/nope/missing.git" },
      { package: "pkg", version: "9.9.9", repo: repo.dir },
    ]);
    const r = await runCli({ argv: ["deps", "clone"], cwd: dir });
    expect(r.code).toBe(0); // never fails the whole run
    expect(r.stdout).toContain("gone:");
    expect(r.stdout).toContain("no tag match");
    const reg = readFileSync(join(dir, ".agent/dependencies/registry.md"), "utf8");
    expect(reg).not.toContain("| gone |");
    expect(reg).toContain(`| pkg | 9.9.9 | ${repo.dir} | ${repo.shaByTag["pkg@1.1.0"]} (no tag match) |`);
    expect(readFileSync(join(dir, ".agent/dependencies/pkg/lib.ts"), "utf8")).toBe("export const v = 2;\n");
    rmProject({ dir });
  });
  test("add: version defaults from package.json; errors without any version source", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "x", dependencies: { pkg: "^1.0.0" } }));
    expect((await runCli({ argv: ["deps", "add", "pkg", "--repo", repo.dir], cwd: dir })).code).toBe(0);
    expect(readManifestDeps(dir)).toEqual([{ package: "pkg", version: "1.0.0", repo: repo.dir }]);
    const bad = await runCli({ argv: ["deps", "add", "mystery", "--repo", repo.dir], cwd: dir });
    expect(bad.code).toBe(2);
    expect(bad.stderr).toContain("--version");
    rmProject({ dir });
  });
  test("sync: drift re-clones, updates registry + manifest; second run is a no-op", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setDeps(dir, [{ package: "pkg", version: "1.0.0", repo: repo.dir }]);
    await runCli({ argv: ["deps", "clone"], cwd: dir });
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "x", dependencies: { pkg: "^1.1.0" } }));
    expect((await runCli({ argv: ["deps", "sync"], cwd: dir })).code).toBe(0);
    expect(readFileSync(join(dir, ".agent/dependencies/pkg/lib.ts"), "utf8")).toBe("export const v = 2;\n");
    expect(readFileSync(join(dir, ".agent/dependencies/registry.md"), "utf8")).toContain("| pkg | 1.1.0 |");
    expect(readManifestDeps(dir)[0].version).toBe("1.1.0");
    expect((await runCli({ argv: ["deps", "sync"], cwd: dir })).stdout).toContain("up to date");
    rmProject({ dir });
  });
  test("remove deletes clone dir + registry row + manifest pin; list reflects it", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    setDeps(dir, [{ package: "pkg", version: "1.0.0", repo: repo.dir }]);
    await runCli({ argv: ["deps", "clone"], cwd: dir });
    expect((await runCli({ argv: ["deps", "list"], cwd: dir })).stdout).toContain("| pkg | 1.0.0 |");
    expect((await runCli({ argv: ["deps", "remove", "pkg"], cwd: dir })).code).toBe(0);
    expect(existsSync(join(dir, ".agent/dependencies/pkg"))).toBe(false);
    expect(readManifestDeps(dir)).toEqual([]);
    expect((await runCli({ argv: ["deps", "list"], cwd: dir })).stdout).toContain("(no dependencies registered)");
    expect((await runCli({ argv: ["deps", "remove", "pkg"], cwd: dir })).code).toBe(2);
    rmProject({ dir });
  });
  test("no subcommand exits 2 listing subcommands; clone of unpinned name exits 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["deps"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("clone|sync|add|remove|list");
    expect((await runCli({ argv: ["deps", "clone", "nope"], cwd: dir })).code).toBe(2);
    rmProject({ dir });
  });
});

describe(".agent/dependencies/.gitignore contract", () => {
  test("clone (self-)writes the 01 contract; git ignores clone dirs but not registry.md", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    setDeps(dir, [{ package: "pkg", version: "1.0.0", repo: repo.dir }]);
    await runCli({ argv: ["deps", "clone"], cwd: dir });
    expect(readFileSync(join(dir, ".agent/dependencies/.gitignore"), "utf8")).toBe("*\n!.gitignore\n!registry.md\n");
    // clone dir ignored (check-ignore exits 0)…
    execFileSync("git", ["-C", dir, "check-ignore", ".agent/dependencies/pkg"], { stdio: "ignore" });
    // …registry.md NOT ignored (check-ignore exits 1 → throws)
    expect(() => execFileSync("git", ["-C", dir, "check-ignore", ".agent/dependencies/registry.md"], { stdio: "ignore" })).toThrow();
    rmProject({ dir });
  });
});
