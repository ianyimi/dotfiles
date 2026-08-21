import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { gitInit } from "../../test/helpers.ts";
import { Reporter } from "../lib/output.ts";
import { worktreeAdd, type TmuxSpawn } from "./worktree.ts";

const FIXTURES = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "test", "fixtures");

/** Container dir + project at <container>/dev — sibling worktrees land inside the container. */
function mkWorktreeProject(): { container: string; project: string } {
  const container = mkdtempSync(join(tmpdir(), "harness-wt-"));
  const project = join(container, "dev");
  cpSync(join(FIXTURES, "initialized"), project, { recursive: true });
  gitInit({ dir: project });
  const manifestPath = join(project, ".agent/manifest.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  manifest.repo = { type: "bare-git-worktrees" };
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  return { container, project };
}

function mkRecorder(): { calls: string[][]; tmuxSpawn: TmuxSpawn; reporter: Reporter; lines: string[] } {
  const calls: string[][] = [];
  const lines: string[] = [];
  return {
    calls,
    lines,
    tmuxSpawn: (p) => {
      calls.push(p.args);
    },
    reporter: new Reporter({ json: false, write: (s) => lines.push(s) }),
  };
}

describe("harness worktree", () => {
  test("creates sibling worktree + branch, records in manifest, no tmux when TMUX unset", () => {
    const { container, project } = mkWorktreeProject();
    const r = mkRecorder();
    expect(worktreeAdd({ root: project, feature: "my-feat", env: {}, tmuxSpawn: r.tmuxSpawn, reporter: r.reporter })).toBe(0);
    expect(existsSync(join(container, "my-feat"))).toBe(true);
    const branches = execFileSync("git", ["branch", "--list", "my-feat"], { cwd: project, encoding: "utf8" }).trim();
    expect(branches).not.toBe("");
    const manifest = JSON.parse(readFileSync(join(project, ".agent/manifest.json"), "utf8"));
    expect(manifest.repo.worktrees["my-feat"]).toEqual({ path: "../my-feat", branch: "my-feat" });
    expect(r.calls).toHaveLength(0);
    r.reporter.flush();
    expect(r.lines.join("\n")).toContain("not inside tmux");
  });

  test("TMUX set → tmuxSpawn called with new-window args", () => {
    const { container, project } = mkWorktreeProject();
    const r = mkRecorder();
    worktreeAdd({ root: project, feature: "feat2", env: { TMUX: "/tmp/sock,1,0" }, tmuxSpawn: r.tmuxSpawn, reporter: r.reporter });
    expect(r.calls[0]).toEqual(["new-window", "-n", "feat2", "-c", join(container, "feat2")]);
  });

  test("--path override wins (resolves relative to root)", () => {
    const { project } = mkWorktreeProject();
    const r = mkRecorder();
    worktreeAdd({ root: project, feature: "feat3", path: "../elsewhere", env: {}, tmuxSpawn: r.tmuxSpawn, reporter: r.reporter });
    expect(existsSync(join(dirname(project), "elsewhere"))).toBe(true);
  });

  test("branch exists → branch-exists error, no new dir", () => {
    const { container, project } = mkWorktreeProject();
    const r = mkRecorder();
    execFileSync("git", ["branch", "taken"], { cwd: project });
    expect(() => worktreeAdd({ root: project, feature: "taken", env: {}, tmuxSpawn: r.tmuxSpawn, reporter: r.reporter })).toThrow(
      /branch taken already exists/,
    );
    expect(existsSync(join(container, "taken"))).toBe(false);
  });

  test("path exists → worktree-path-exists", () => {
    const { container, project } = mkWorktreeProject();
    const r = mkRecorder();
    mkdirSync(join(container, "occupied"));
    expect(() => worktreeAdd({ root: project, feature: "occupied", env: {}, tmuxSpawn: r.tmuxSpawn, reporter: r.reporter })).toThrow(
      /already exists/,
    );
  });

  test("repo.type standard → not-worktree-repo", () => {
    const container = mkdtempSync(join(tmpdir(), "harness-wt-"));
    const project = join(container, "dev");
    cpSync(join(FIXTURES, "initialized"), project, { recursive: true });
    gitInit({ dir: project }); // fixture manifest has no repo key
    const r = mkRecorder();
    expect(() => worktreeAdd({ root: project, feature: "x", env: {}, tmuxSpawn: r.tmuxSpawn, reporter: r.reporter })).toThrow(
      /worktree needs "bare-git-worktrees"/,
    );
  });

  test("bad feature name → usage", () => {
    const { project } = mkWorktreeProject();
    const r = mkRecorder();
    expect(() => worktreeAdd({ root: project, feature: "../evil", env: {}, tmuxSpawn: r.tmuxSpawn, reporter: r.reporter })).toThrow(
      /invalid feature name/,
    );
  });
});
