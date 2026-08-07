import { describe, expect, test } from "bun:test";
import { mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";
import { harnessHome, resolveProjectRoot } from "./paths.ts";

describe("harnessHome", () => {
  test("HARNESS_HOME override wins; default is ~/.harness", () => {
    const prev = process.env["HARNESS_HOME"];
    try {
      process.env["HARNESS_HOME"] = "/tmp/custom-home";
      expect(harnessHome()).toBe("/tmp/custom-home");
      delete process.env["HARNESS_HOME"];
      expect(harnessHome()).toBe(join(homedir(), ".harness"));
    } finally {
      if (prev !== undefined) process.env["HARNESS_HOME"] = prev;
      else delete process.env["HARNESS_HOME"];
    }
  });
});

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
