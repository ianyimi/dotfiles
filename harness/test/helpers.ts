import { mkdtempSync, cpSync, rmSync } from "node:fs";
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
