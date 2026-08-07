import { describe, expect, test } from "bun:test";
import { execSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "./helpers.ts";
import { GOLDEN_COMMIT_MD } from "../src/commands/log.test.ts";

const LOG = ".agent/docs/session-log/2026/08/2026-08-02.log.md";
const COMMIT_MD = ".agent/docs/session-log/2026/08/2026-08-02.commit.md";

describe("e2e: log → commit-msg → commit → backfill-sha", () => {
  test("full agent-commits session cycle", async () => {
    // 1. Fixture: initialized + a workspace package, committed.
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, "pnpm-workspace.yaml"), 'packages:\n  - "packages/*"\n');
    mkdirSync(join(dir, "packages/core/src"), { recursive: true });
    writeFileSync(join(dir, "packages/core/package.json"), '{"name":"@x/core","version":"0.0.0"}');
    writeFileSync(join(dir, "packages/core/src/index.ts"), "export const a = 1;\n");
    gitInit({ dir });

    // 2. log append → skeleton exists.
    const a = await runCli({ argv: ["log", "append", "--slug", "filter panel wiring", "--date", "2026-08-02T14:23"], cwd: dir });
    expect(a.code).toBe(0);

    // 3. Seed entry content (as the commit skill would after interviewing the developer).
    let text = readFileSync(join(dir, LOG), "utf8");
    text = text
      .replace(
        "### What was built\n",
        "### What was built\n- `FilterPanel.tsx` — filter panel wired to TanStack Table\n- `useFilterState.ts` — filter state in URL params\n",
      )
      .replace(
        "### Decisions made\n",
        "### Decisions made\n- Used nuqs instead of useState — URL-shareable filters matter for admin use.\n",
      );
    writeFileSync(join(dir, LOG), text);

    // 4. Uncommitted work → commit-msg → exact golden commit.md.
    writeFileSync(join(dir, "packages/core/src/index.ts"), "export const a = 2;\n");
    const m = await runCli({ argv: ["log", "commit-msg", "--date", "2026-08-02"], cwd: dir });
    expect(m.code).toBe(0);
    expect(readFileSync(join(dir, COMMIT_MD), "utf8")).toBe(GOLDEN_COMMIT_MD);
    expect(m.stdout).toContain("feat(core): filter panel wiring");

    // 5. Commit with the generated message (agent-commits mode), then backfill.
    const env = { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@t", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@t" };
    execSync(`git add -A && git commit -q -F ${COMMIT_MD}`, { cwd: dir, env });
    const sha = execSync("git rev-parse HEAD", { cwd: dir }).toString().trim();
    const b = await runCli({ argv: ["log", "backfill-sha", "--sha", sha, "--date", "2026-08-02"], cwd: dir });
    expect(b.code).toBe(0);
    const finalText = readFileSync(join(dir, LOG), "utf8");
    expect(finalText).toContain(`**Commit:** ${sha}`);
    expect(finalText).not.toContain("(pending)");
    rmProject({ dir });
  });
});
