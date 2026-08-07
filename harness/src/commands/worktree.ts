import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { EXIT, HarnessError } from "../lib/errors.ts";
import { loadManifest, saveManifest } from "../lib/manifest.ts";
import type { Reporter } from "../lib/output.ts";

/** Injected process runner for tmux only (D08-4). Throws on non-zero exit. */
export type TmuxSpawn = (props: { args: string[] }) => void;

/**
 * Creates a git worktree + branch for a feature, sibling to the project root (D08-5), records
 * it in manifest.repo.worktrees, and opens a tmux window when inside tmux.
 *
 * @param props.root - Project root (the current worktree, e.g. …/maprios-app.git/dev).
 * @param props.feature - Feature name; becomes branch name and default directory name.
 * @param props.path - Optional explicit worktree path (overrides the sibling default).
 * @param props.env - Process env (reads TMUX only).
 * @param props.tmuxSpawn - Tmux runner; tests inject a recorder.
 * @param props.reporter - Output sink.
 * @returns EXIT.OK on success.
 * @throws {HarnessError} "not-worktree-repo" · "worktree-path-exists" · "branch-exists" ·
 *   "git-failed" · "usage" (bad feature name).
 */
export function worktreeAdd(props: {
  root: string;
  feature: string;
  path?: string;
  env: Record<string, string | undefined>;
  tmuxSpawn: TmuxSpawn;
  reporter: Reporter;
}): number {
  const { manifest } = loadManifest({ root: props.root });
  if (manifest.repo?.type !== "bare-git-worktrees") {
    throw new HarnessError(
      "not-worktree-repo",
      `repo.type is ${manifest.repo?.type ?? "unset"} — worktree needs "bare-git-worktrees"`,
      { hint: "set repo.type in .agent/manifest.json" },
    );
  }
  if (!/^[a-z0-9][a-z0-9._/-]*$/.test(props.feature) || props.feature.includes("..")) {
    throw new HarnessError("usage", `invalid feature name ${JSON.stringify(props.feature)}`);
  }
  const target = props.path !== undefined ? resolve(props.root, props.path) : join(dirname(props.root), props.feature);
  const branch = props.feature;

  if (existsSync(target)) {
    throw new HarnessError("worktree-path-exists", `${target} already exists`, {
      hint: `harness worktree ${props.feature} --path <other>`,
    });
  }
  const existing = execFileSync("git", ["branch", "--list", branch], {
    cwd: props.root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
  if (existing !== "") {
    throw new HarnessError("branch-exists", `branch ${branch} already exists`, {
      hint: `git worktree add ${target} ${branch}  # attach the existing branch manually`,
    });
  }
  try {
    execFileSync("git", ["worktree", "add", target, "-b", branch], {
      cwd: props.root,
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (e) {
    throw new HarnessError("git-failed", `git worktree add failed: ${(e as Error).message}`, { exitCode: EXIT.FAILURE });
  }

  manifest.repo.worktrees = {
    ...manifest.repo.worktrees,
    [props.feature]: { path: relative(props.root, target), branch },
  };
  saveManifest({ root: props.root, manifest });
  props.reporter.ok(`worktree ${target} on branch ${branch}`, "worktree");

  if (props.env["TMUX"] !== undefined && props.env["TMUX"] !== "") {
    try {
      props.tmuxSpawn({ args: ["new-window", "-n", props.feature, "-c", target] });
    } catch (e) {
      // The window is a nicety — the worktree already exists.
      props.reporter.warn(`tmux window failed: ${(e as Error).message}`, "worktree");
    }
  } else {
    props.reporter.info("not inside tmux — skipped window creation", "worktree");
  }
  return EXIT.OK;
}
