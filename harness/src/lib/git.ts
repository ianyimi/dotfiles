import { execFileSync } from "node:child_process";
import { mkdirSync, rmSync } from "node:fs";
import { dirname } from "node:path";
import { EXIT, HarnessError } from "./errors.ts";

/** Runs git returning trimmed stdout, or null on any failure (git absent, not a repo, …). */
function tryGit(root: string, args: string[]): string | null {
  try {
    return execFileSync("git", args, { cwd: root, stdio: ["ignore", "pipe", "pipe"] })
      .toString()
      .trim();
  } catch {
    return null;
  }
}

/**
 * Whether root is inside a git work tree.
 *
 * @param props.root - Directory to test.
 * @returns True when `git rev-parse --is-inside-work-tree` succeeds.
 */
export function isRepo(props: { root: string }): boolean {
  return tryGit(props.root, ["rev-parse", "--is-inside-work-tree"]) === "true";
}

/**
 * Current HEAD sha.
 *
 * @param props.root - Repo directory.
 * @returns 40-hex sha, or "" when not a repo / no commits (callers treat "" as unknown).
 */
export function headSha(props: { root: string }): string {
  return tryGit(props.root, ["rev-parse", "HEAD"]) ?? "";
}

/**
 * Files changed between a sha and HEAD.
 *
 * @param props.root - Repo directory.
 * @param props.sha - Base sha.
 * @returns Changed paths (repo-relative), or [] on any git error (safe default).
 */
export function changedFilesSince(props: { root: string; sha: string }): string[] {
  const out = tryGit(props.root, ["diff", "--name-only", `${props.sha}..HEAD`]);
  if (out === null || out === "") return [];
  return out.split("\n");
}

/**
 * HEAD commit date in YYYY-MM-DD form.
 *
 * @param props.root - Repo directory.
 * @returns The `git log -1 --format=%cs` date, or "" on any error / no commits.
 */
export function headCommitDate(props: { root: string }): string {
  return tryGit(props.root, ["log", "-1", "--format=%cs"]) ?? "";
}

/**
 * Files touched by the most recent commits, deduped and sorted.
 *
 * @param props.root - Repo directory.
 * @param props.commits - How many commits to look back (fewer existing is fine).
 * @returns Sorted unique repo-relative paths, or [] on any git error.
 */
export function recentChangedFiles(props: { root: string; commits: number }): string[] {
  const out = tryGit(props.root, ["log", `-n`, String(props.commits), "--name-only", "--format="]);
  if (out === null || out === "") return [];
  return [...new Set(out.split("\n").filter((l) => l.trim() !== ""))].sort();
}

/**
 * ISO-8601 committer date of HEAD (`git log -1 --format=%cI`).
 *
 * @param props.root - Repo directory.
 * @returns e.g. "2026-08-02T14:23:11+02:00", or "" when not a repo / no commits.
 */
export function headCommitIso(props: { root: string }): string {
  return tryGit(props.root, ["log", "-1", "--format=%cI"]) ?? "";
}

/**
 * Paths with uncommitted changes (staged + unstaged + untracked) via `git status --porcelain`.
 * Renames report the NEW path.
 *
 * @param props.root - Repo directory.
 * @returns Root-relative POSIX paths, sorted, deduped; [] when not a repo / on git error.
 */
export function uncommittedFiles(props: { root: string }): string[] {
  // Raw output — tryGit's trim() would eat the first line's leading status space
  // (" M path" → "M path") and corrupt its path on slice(3).
  let out: string;
  try {
    out = execFileSync("git", ["status", "--porcelain"], {
      cwd: props.root,
      stdio: ["ignore", "pipe", "pipe"],
    }).toString();
  } catch {
    return [];
  }
  if (out === "") return [];
  const paths = out.split("\n").filter((l) => l.length > 3).map((line) => {
    let p = line.slice(3);
    const arrow = p.indexOf(" -> ");
    if (arrow !== -1) p = p.slice(arrow + 4);
    return p.replace(/^"|"$/g, "");
  });
  return [...new Set(paths)].sort();
}

/** Prefixes file:// on absolute local paths so git honors --depth (06 design decisions). */
function asGitUrl(repoUrl: string): string {
  return repoUrl.startsWith("/") ? `file://${repoUrl}` : repoUrl;
}

/**
 * Lists tag names on a remote via `git ls-remote --tags --refs`.
 *
 * @param props.repoUrl - Clone URL or absolute local path (bare repo ok).
 * @returns Tag names ("refs/tags/" stripped), lexically sorted; [] when the repo has no tags.
 * @throws {HarnessError} code "git-ls-remote-failed" when unreachable/private. Callers decide
 *   whether to warn (deliberate deviation from this file's safe-default wrappers — clone flows
 *   must distinguish unreachable repos from tagless ones).
 */
export function lsRemoteTags(props: { repoUrl: string }): string[] {
  try {
    const out = execFileSync("git", ["ls-remote", "--tags", "--refs", asGitUrl(props.repoUrl)], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
      maxBuffer: 64 * 1024 * 1024,
    });
    return out
      .split("\n")
      .filter(Boolean)
      .map((l) => (l.split("\t")[1] ?? "").replace("refs/tags/", ""))
      .filter(Boolean)
      .sort();
  } catch (e) {
    throw new HarnessError("git-ls-remote-failed", `git ls-remote failed for ${props.repoUrl}: ${(e as Error).message}`, {
      exitCode: EXIT.FAILURE,
    });
  }
}

/**
 * Shallow-clones (depth 1) a repo at a ref into dest, replacing any existing dest.
 *
 * @param props.repoUrl - Clone URL or absolute local path.
 * @param props.ref - Tag/branch for `--branch`; omit to clone the default branch.
 * @param props.dest - Absolute destination dir (removed first if present).
 * @returns The clone's HEAD commit sha (40 hex).
 * @throws {HarnessError} code "git-clone-failed" on any git failure; dest is removed on failure
 *   so a broken half-clone never survives.
 */
export function shallowCloneAtRef(props: { repoUrl: string; ref?: string; dest: string }): string {
  rmSync(props.dest, { recursive: true, force: true });
  mkdirSync(dirname(props.dest), { recursive: true });
  try {
    execFileSync(
      "git",
      ["clone", "--quiet", "--depth", "1", ...(props.ref !== undefined ? ["--branch", props.ref] : []), asGitUrl(props.repoUrl), props.dest],
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
    );
    return execFileSync("git", ["-C", props.dest, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  } catch (e) {
    rmSync(props.dest, { recursive: true, force: true });
    throw new HarnessError(
      "git-clone-failed",
      `git clone failed for ${props.repoUrl}${props.ref !== undefined ? ` @ ${props.ref}` : ""}: ${(e as Error).message}`,
      { exitCode: EXIT.FAILURE },
    );
  }
}

/**
 * Counts commits touching any of the given paths in the last N days.
 *
 * @param props.root - Repo directory.
 * @param props.paths - Pathspecs to filter by (empty = whole repo).
 * @param props.sinceDays - Lookback window in days.
 * @returns Commit count, or 0 on any git error (safe default).
 */
export function commitsTouching(props: { root: string; paths: string[]; sinceDays: number }): number {
  const out = tryGit(props.root, [
    "log",
    "--oneline",
    `--since=${props.sinceDays}.days`,
    "--",
    ...props.paths,
  ]);
  if (out === null || out === "") return 0;
  return out.split("\n").length;
}
