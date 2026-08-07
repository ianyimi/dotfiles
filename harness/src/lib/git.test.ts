import { describe, expect, test } from "bun:test";
import { writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject } from "../../test/helpers.ts";
import { changedFilesSince, commitsTouching, headCommitDate, headSha, isRepo, recentChangedFiles } from "./git.ts";

describe("git wrappers", () => {
  test("safe defaults outside a repo", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    expect(isRepo({ root: dir })).toBe(false);
    expect(headSha({ root: dir })).toBe("");
    expect(changedFilesSince({ root: dir, sha: "HEAD~1" })).toEqual([]);
    expect(commitsTouching({ root: dir, paths: ["src"], sinceDays: 7 })).toBe(0);
    expect(headCommitDate({ root: dir })).toBe("");
    expect(recentChangedFiles({ root: dir, commits: 10 })).toEqual([]);
    rmProject({ dir });
  });

  test("headCommitDate pins to the committer date", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    gitInit({ dir, date: "2026-01-15T12:00:00Z" });
    expect(headCommitDate({ root: dir })).toBe("2026-01-15");
    rmProject({ dir });
  });

  test("recentChangedFiles: sorted union across commits, tolerant of short history", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    gitInit({ dir });
    const env = { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@t", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@t" };
    writeFileSync(join(dir, "zed.ts"), "z");
    execFileSync("git", ["add", "-A"], { cwd: dir, env });
    execFileSync("git", ["commit", "-q", "-m", "second"], { cwd: dir, env });
    const files = recentChangedFiles({ root: dir, commits: 10 });
    expect(files).toEqual(["package.json", "src/index.ts", "zed.ts"]);
    rmProject({ dir });
  });

  test("real repo: sha, diff, log", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    gitInit({ dir });
    expect(isRepo({ root: dir })).toBe(true);
    const first = headSha({ root: dir });
    expect(first).toMatch(/^[0-9a-f]{40}$/);

    writeFileSync(join(dir, "new-file.ts"), "export const x = 1;\n");
    const env = { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@t", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@t" };
    execFileSync("git", ["add", "-A"], { cwd: dir, env });
    execFileSync("git", ["commit", "-q", "-m", "add file"], { cwd: dir, env });

    expect(changedFilesSince({ root: dir, sha: first })).toEqual(["new-file.ts"]);
    expect(commitsTouching({ root: dir, paths: ["new-file.ts"], sinceDays: 7 })).toBe(1);
    expect(commitsTouching({ root: dir, paths: ["nonexistent"], sinceDays: 7 })).toBe(0);
    rmProject({ dir });
  });
});
