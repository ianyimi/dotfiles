import { describe, expect, test } from "bun:test";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gitInit, mkBareRepoWithTags, mkTmpProject, rmProject } from "../../test/helpers.ts";
import {
  changedFilesSince,
  commitsTouching,
  headCommitDate,
  headCommitIso,
  headSha,
  isRepo,
  lsRemoteTags,
  recentChangedFiles,
  shallowCloneAtRef,
  uncommittedFiles,
} from "./git.ts";

describe("git wrappers", () => {
  test("safe defaults outside a repo", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    expect(isRepo({ root: dir })).toBe(false);
    expect(headSha({ root: dir })).toBe("");
    expect(changedFilesSince({ root: dir, sha: "HEAD~1" })).toEqual([]);
    expect(commitsTouching({ root: dir, paths: ["src"], sinceDays: 7 })).toBe(0);
    expect(headCommitDate({ root: dir })).toBe("");
    expect(recentChangedFiles({ root: dir, commits: 10 })).toEqual([]);
    expect(headCommitIso({ root: dir })).toBe("");
    expect(uncommittedFiles({ root: dir })).toEqual([]);
    rmProject({ dir });
  });

  test("headCommitIso returns an ISO timestamp", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    gitInit({ dir });
    expect(headCommitIso({ root: dir })).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/);
    rmProject({ dir });
  });

  test("uncommittedFiles: new + modified tracked, sorted", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    gitInit({ dir });
    writeFileSync(join(dir, "src/index.ts"), "export const hi = 2;\n"); // modify tracked
    writeFileSync(join(dir, "brand-new.ts"), "export const n = 1;\n"); // untracked
    expect(uncommittedFiles({ root: dir })).toEqual(["brand-new.ts", "src/index.ts"]);
    rmProject({ dir });
  });
});

describe("deps git helpers (06)", () => {
  const repo = mkBareRepoWithTags();
  const mkDest = () => join(mkdtempSync(join(tmpdir(), "harness-clone-")), "pkg");
  test("lsRemoteTags lists both tags sorted; throws on unreachable repo", () => {
    expect(lsRemoteTags({ repoUrl: repo.dir })).toEqual(["pkg@1.1.0", "v1.0.0"]);
    expect(() => lsRemoteTags({ repoUrl: "/nope/missing.git" })).toThrow(/ls-remote failed/);
  });
  test("shallowCloneAtRef: tag → content + sha + depth 1; no ref → default branch tip", () => {
    const a = mkDest();
    expect(shallowCloneAtRef({ repoUrl: repo.dir, ref: "v1.0.0", dest: a })).toBe(repo.shaByTag["v1.0.0"]!);
    expect(readFileSync(join(a, "lib.ts"), "utf8")).toBe("export const v = 1;\n");
    expect(execFileSync("git", ["-C", a, "rev-list", "--count", "HEAD"], { encoding: "utf8" }).trim()).toBe("1");
    const b = mkDest();
    expect(shallowCloneAtRef({ repoUrl: repo.dir, dest: b })).toBe(repo.shaByTag["pkg@1.1.0"]!);
    expect(readFileSync(join(b, "lib.ts"), "utf8")).toBe("export const v = 2;\n");
  });
  test("bad ref throws git-clone-failed and leaves no dest", () => {
    const dest = mkDest();
    expect(() => shallowCloneAtRef({ repoUrl: repo.dir, ref: "v9.9.9", dest })).toThrow(/clone failed/);
    expect(existsSync(dest)).toBe(false);
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
