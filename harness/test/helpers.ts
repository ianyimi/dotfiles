import { mkdtempSync, cpSync, rmSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const FIXTURES = join(dirname(fileURLToPath(import.meta.url)), "fixtures");

/**
 * Copies a named fixture tree into a fresh temp directory and returns its path.
 * Callers must pass the returned path as cwd to runCli. Cleaned by rmProject.
 *
 * @param props.fixture - Directory name under test/fixtures (e.g. "ts-monorepo").
 * @returns Absolute path of the temp project root.
 */
export function mkTmpProject(props: { fixture: string }): string {
  const dir = mkdtempSync(join(tmpdir(), "harness-test-"));
  cpSync(join(FIXTURES, props.fixture), dir, { recursive: true });
  return dir;
}

/** Removes a temp project created by mkTmpProject. @param props.dir - Path returned by mkTmpProject. @returns Nothing. */
export function rmProject(props: { dir: string }): void {
  rmSync(props.dir, { recursive: true, force: true });
}

/**
 * Initializes a git repo with one commit in a directory (identity pinned for determinism).
 *
 * @param props.dir - Directory to initialize.
 * @param props.date - Optional ISO date applied as author+committer date (pins %cs output).
 * @returns Nothing.
 */
export function gitInit(props: { dir: string; date?: string }): void {
  const env = {
    ...process.env,
    GIT_AUTHOR_NAME: "test",
    GIT_AUTHOR_EMAIL: "test@test",
    GIT_COMMITTER_NAME: "test",
    GIT_COMMITTER_EMAIL: "test@test",
    ...(props.date !== undefined ? { GIT_AUTHOR_DATE: props.date, GIT_COMMITTER_DATE: props.date } : {}),
  };
  const run = (args: string[]) => execFileSync("git", args, { cwd: props.dir, env, stdio: "pipe" });
  run(["init", "-q"]);
  run(["add", "-A"]);
  run(["commit", "-q", "-m", "init", "--allow-empty"]);
}

/**
 * Builds a local BARE git repo fixture with two commits and two tags:
 * v1.0.0 → lib.ts "export const v = 1;\n"; pkg@1.1.0 (default-branch tip) → "export const v = 2;\n".
 * Stand-in for a network remote — no test in this suite may hit the network.
 *
 * @returns dir - Absolute bare-repo path (usable as DependencyPin.repo); shaByTag - commit sha per tag.
 */
export function mkBareRepoWithTags(): { dir: string; shaByTag: Record<string, string> } {
  const work = mkdtempSync(join(tmpdir(), "harness-dep-work-"));
  const out = mkdtempSync(join(tmpdir(), "harness-dep-bare-"));
  const git = (args: string[]): string =>
    execFileSync("git", ["-C", work, "-c", "user.email=t@t", "-c", "user.name=t", ...args], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  git(["init", "-b", "main"]);
  writeFileSync(join(work, "lib.ts"), "export const v = 1;\n");
  git(["add", "-A"]);
  git(["commit", "-m", "one"]);
  git(["tag", "v1.0.0"]);
  writeFileSync(join(work, "lib.ts"), "export const v = 2;\n");
  git(["add", "-A"]);
  git(["commit", "-m", "two"]);
  git(["tag", "pkg@1.1.0"]);
  const shaByTag = {
    "v1.0.0": git(["rev-parse", "v1.0.0^{commit}"]).trim(),
    "pkg@1.1.0": git(["rev-parse", "pkg@1.1.0^{commit}"]).trim(),
  };
  const dir = join(out, "repo.git");
  execFileSync("git", ["clone", "--bare", "--quiet", work, dir], { stdio: "ignore" });
  rmSync(work, { recursive: true, force: true });
  return { dir, shaByTag };
}

/**
 * Runs the CLI in-process with argv and a working directory, capturing output.
 * In-process (not subprocess) so tests are fast and coverage attributes correctly.
 *
 * @param props.argv - Args after the binary name, e.g. ["doctor", "--json"].
 * @param props.cwd - Project directory to run in.
 * @returns Exit code plus captured stdout/stderr strings.
 */
export async function runCli(props: { argv: string[]; cwd: string }): Promise<{
  code: number;
  stdout: string;
  stderr: string;
}> {
  const { main } = await import("../src/cli.ts");
  const out: string[] = [];
  const err: string[] = [];
  const code = await main({
    argv: props.argv,
    cwd: props.cwd,
    stdout: (s) => out.push(s),
    stderr: (s) => err.push(s),
  });
  return { code, stdout: out.join("\n"), stderr: err.join("\n") };
}
