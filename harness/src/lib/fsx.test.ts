import { describe, expect, test } from "bun:test";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";
import { ensureSymlink, sha256, walk, writeFileAtomic } from "./fsx.ts";

describe("sha256", () => {
  test("known digest", () => {
    expect(sha256({ text: "harness\n" })).toBe(
      "c7eacb8ccadb7a650ad4eac69aca2d8bbb57d759d785ee07de32526d7a69c93f",
    );
  });
});

describe("writeFileAtomic", () => {
  test("creates parents and leaves no tmp files", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    const target = join(dir, "a", "b", "c.txt");
    writeFileAtomic({ path: target, content: "hello" });
    expect(readFileSync(target, "utf8")).toBe("hello");
    expect(readdirSync(join(dir, "a", "b")).filter((f) => f.includes(".tmp-"))).toEqual([]);
    rmProject({ dir });
  });
});

describe("walk", () => {
  test("exact sorted list for ts-monorepo", () => {
    const dir = mkTmpProject({ fixture: "ts-monorepo" });
    expect(walk({ root: dir })).toEqual([
      ".env.example",
      "package.json",
      "packages/core/package.json",
      "packages/core/src/index.ts",
      "pnpm-workspace.yaml",
    ]);
    rmProject({ dir });
  });
  test("prunes node_modules and extra prune names", () => {
    const dir = mkTmpProject({ fixture: "ts-monorepo" });
    mkdirSync(join(dir, "node_modules", "x"), { recursive: true });
    writeFileSync(join(dir, "node_modules", "x", "index.js"), "x");
    mkdirSync(join(dir, "dist"), { recursive: true });
    writeFileSync(join(dir, "dist", "out.js"), "x");
    const files = walk({ root: dir, prune: ["dist"] });
    expect(files.some((f) => f.startsWith("node_modules/"))).toBe(false);
    expect(files.some((f) => f.startsWith("dist/"))).toBe(false);
    rmProject({ dir });
  });
  test("keeps .agent/dependencies metadata but prunes clone bodies", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    mkdirSync(join(dir, ".agent", "dependencies", "some-clone", "src"), { recursive: true });
    writeFileSync(join(dir, ".agent", "dependencies", "some-clone", "src", "big.ts"), "x");
    const files = walk({ root: dir });
    expect(files).toContain(".agent/dependencies/registry.md");
    expect(files).toContain(".agent/dependencies/.gitignore");
    expect(files.some((f) => f.includes("some-clone"))).toBe(false);
    rmProject({ dir });
  });
});

describe("ensureSymlink", () => {
  test("full lifecycle: created → ok → replaced → conflict", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    const targetA = join(dir, "target-a");
    const targetB = join(dir, "target-b");
    mkdirSync(targetA);
    mkdirSync(targetB);
    const link = join(dir, "bridge", "skills");

    expect(ensureSymlink({ linkPath: link, targetPath: targetA })).toBe("created");
    expect(ensureSymlink({ linkPath: link, targetPath: targetA })).toBe("ok");
    expect(ensureSymlink({ linkPath: link, targetPath: targetB })).toBe("replaced");

    const realFile = join(dir, "bridge", "real.txt");
    writeFileSync(realFile, "user content");
    expect(ensureSymlink({ linkPath: realFile, targetPath: targetA })).toBe("conflict");
    expect(readFileSync(realFile, "utf8")).toBe("user content");
    expect(existsSync(link)).toBe(true);
    rmProject({ dir });
  });
});
