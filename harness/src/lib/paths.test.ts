import { describe, expect, test } from "bun:test";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";
import { resolveProjectRoot } from "./paths.ts";

describe("resolveProjectRoot", () => {
  test("finds .agent at cwd", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    expect(resolveProjectRoot({ cwd: dir })).toBe(dir);
    rmProject({ dir });
  });
  test("finds .agent from nested dir", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const nested = join(dir, "src", "deep");
    mkdirSync(nested, { recursive: true });
    expect(resolveProjectRoot({ cwd: nested })).toBe(dir);
    rmProject({ dir });
  });
  test("nearest .agent wins over outer .git", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    mkdirSync(join(dir, ".git"), { recursive: true });
    const inner = join(dir, "apps", "site");
    mkdirSync(join(inner, ".agent"), { recursive: true });
    expect(resolveProjectRoot({ cwd: inner })).toBe(inner);
    rmProject({ dir });
  });
  test(".git fallback when no .agent", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    mkdirSync(join(dir, ".git"));
    expect(resolveProjectRoot({ cwd: join(dir, "src") })).toBe(dir);
    rmProject({ dir });
  });
  test(".git FILE (worktree) counts", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    writeFileSync(join(dir, ".git"), "gitdir: /elsewhere\n");
    expect(resolveProjectRoot({ cwd: dir })).toBe(dir);
    rmProject({ dir });
  });
  test("throws no-project otherwise", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    expect(() => resolveProjectRoot({ cwd: dir })).toThrow(/Not inside a project/);
    rmProject({ dir });
  });
});
