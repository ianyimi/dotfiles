import { execFileSync } from "node:child_process";

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
