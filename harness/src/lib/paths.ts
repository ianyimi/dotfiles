import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { EXIT, HarnessError } from "./errors.ts";

/** Root-relative .agent path constants used by every command. */
export const AGENT_DIR = ".agent";
export const P = {
  manifest: join(AGENT_DIR, "manifest.json"),
  agentsMd: join(AGENT_DIR, "AGENTS.md"),
  contextRules: join(AGENT_DIR, "context-rules.yaml"),
  syncManifest: join(AGENT_DIR, ".sync-manifest.json"),
  setupProgress: join(AGENT_DIR, ".setup-progress.md"),
  docs: join(AGENT_DIR, "docs"),
  product: join(AGENT_DIR, "docs", "product"),
  standards: join(AGENT_DIR, "docs", "standards"),
  specs: join(AGENT_DIR, "docs", "specs"),
  decisions: join(AGENT_DIR, "docs", "decisions"),
  sessionLog: join(AGENT_DIR, "docs", "session-log"),
  tasks: join(AGENT_DIR, "docs", "tasks.md"),
  state: join(AGENT_DIR, "docs", "state.md"),
  skills: join(AGENT_DIR, "skills"),
  dependencies: join(AGENT_DIR, "dependencies"),
  depsRegistry: join(AGENT_DIR, "dependencies", "registry.md"),
  envManifest: join(AGENT_DIR, "env.manifest.md"),
} as const;

/**
 * Walks up from cwd to find the project root (master §2.10). The nearest `.agent/`
 * wins over `.git/` so a harness project nested inside an outer repo resolves to itself.
 *
 * @param props.cwd - Directory to start from.
 * @returns Absolute project root path.
 * @throws {HarnessError} code "no-project" when neither .agent/ nor .git/ is found up to /.
 */
export function resolveProjectRoot(props: { cwd: string }): string {
  let dir = props.cwd;
  let firstGit: string | null = null;
  for (;;) {
    if (existsSync(join(dir, AGENT_DIR))) return dir;
    // .git may be a file in worktrees — existsSync covers both.
    if (firstGit === null && existsSync(join(dir, ".git"))) firstGit = dir;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  if (firstGit !== null) return firstGit;
  throw new HarnessError("no-project", "Not inside a project (no .agent/ or .git/ found)", {
    hint: "cd into a project or run `git init`",
    exitCode: EXIT.USAGE,
  });
}
