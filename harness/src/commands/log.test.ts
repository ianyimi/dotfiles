import { describe, expect, test } from "bun:test";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { appendLogLine, buildCommitMessage, inferScope, sectionBullets } from "./log.ts";

export const GOLDEN_ENTRY = `# Session Log — 2026-08-02

## 2026-08-02 — 14:23 — filter panel wiring

**Spec:** (none)
**Commit:** (pending)

### What was built

### Decisions made

### Problems hit

### Where I left off
`;
const REL = ".agent/docs/session-log/2026/08/2026-08-02.log.md";

const SEEDED_ENTRY = `# Session Log — 2026-08-02

## 2026-08-02 — 14:23 — filter panel wiring

**Spec:** docs/specs/2026-07-12-collections-ui/spec.md (Step 4)
**Commit:** (pending)

### What was built
- \`FilterPanel.tsx\` — filter panel wired to TanStack Table
- \`useFilterState.ts\` — filter state in URL params

### Decisions made
- Used nuqs instead of useState — URL-shareable filters matter for admin use.

### Problems hit

### Where I left off
- Empty state test failing; fix the selector, not the component.
`;

export const GOLDEN_COMMIT_MD = `feat(core): filter panel wiring

- \`FilterPanel.tsx\` — filter panel wired to TanStack Table
- \`useFilterState.ts\` — filter state in URL params

Why:
- Used nuqs instead of useState — URL-shareable filters matter for admin use.
`;

describe("log append", () => {
  test("creates file with header + skeleton, prints path", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["log", "append", "--slug", "filter panel wiring", "--date", "2026-08-02T14:23"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toContain(REL);
    expect(readFileSync(join(dir, REL), "utf8")).toBe(GOLDEN_ENTRY);
    rmProject({ dir });
  });

  test("second append same day is append-only (prefix-stable)", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    await runCli({ argv: ["log", "append", "--slug", "a", "--date", "2026-08-02T14:23"], cwd: dir });
    const before = readFileSync(join(dir, REL), "utf8");
    await runCli({ argv: ["log", "append", "--slug", "b", "--date", "2026-08-02T15:30"], cwd: dir });
    const after = readFileSync(join(dir, REL), "utf8");
    expect(after.startsWith(before)).toBe(true);
    expect(after).toContain("## 2026-08-02 — 15:30 — b");
    rmProject({ dir });
  });

  test("date-only defaults time and slug", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    await runCli({ argv: ["log", "append", "--date", "2026-08-02"], cwd: dir });
    expect(readFileSync(join(dir, REL), "utf8")).toContain("## 2026-08-02 — 00:00 — session");
    rmProject({ dir });
  });

  test("malformed --date → exit 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["log", "append", "--date", "Aug 2"], cwd: dir });
    expect(r.code).toBe(2);
    rmProject({ dir });
  });

  test("module gate: session_log off → exit 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const manifestPath = join(dir, ".agent/manifest.json");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    manifest.modules.session_log = false;
    writeFileSync(manifestPath, JSON.stringify(manifest));
    const r = await runCli({ argv: ["log", "append", "--date", "2026-08-02"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("session_log");
    rmProject({ dir });
  });

  test("no --date in a repo uses the HEAD timestamp", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    const r = await runCli({ argv: ["log", "append"], cwd: dir });
    expect(r.stdout).toMatch(/session-log\/\d{4}\/\d{2}\/\d{4}-\d{2}-\d{2}\.log\.md$/);
    rmProject({ dir });
  });
});

describe("appendLogLine", () => {
  test("appends exactly one bullet at EOF of an existing entry", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    await runCli({ argv: ["log", "append", "--slug", "a", "--date", "2026-08-02T14:23"], cwd: dir });
    const before = readFileSync(join(dir, REL), "utf8");
    appendLogLine({ root: dir, line: "implement demo: T1 done", dateOpt: "2026-08-02" });
    expect(readFileSync(join(dir, REL), "utf8")).toBe(`${before}- implement demo: T1 done\n`);
    rmProject({ dir });
  });
  test("creates skeleton first on an empty day", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    appendLogLine({ root: dir, line: "hello", dateOpt: "2026-08-02" });
    const text = readFileSync(join(dir, REL), "utf8");
    expect(text).toContain("## 2026-08-02 — 00:00 — session");
    expect(text.endsWith("- hello\n")).toBe(true);
    rmProject({ dir });
  });
  test("multiline input throws usage", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    expect(() => appendLogLine({ root: dir, line: "a\nb", dateOpt: "2026-08-02" })).toThrow(/single line/);
    rmProject({ dir });
  });
});

describe("log session-end", () => {
  test("fresh project: creates entry, appends marker, prints questions", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["log", "session-end", "--date", "2026-08-02T18:00"], cwd: dir });
    expect(r.code).toBe(0);
    const text = readFileSync(join(dir, REL), "utf8");
    expect(text).toContain("## 2026-08-02 — 18:00 — session");
    expect(text.endsWith("### Where I left off\n\n_Session end — fill in: current state · next step · watch-outs._\n")).toBe(true);
    for (const q of ["1. What was built", "2. Any decisions", "3. Any problems", "4. Where does the session"]) {
      expect(r.stdout).toContain(q);
    }
    expect(r.stdout).toContain(`Write the answers into: ${REL}`);
    rmProject({ dir });
  });

  test("after append: only marker added; second run byte-identical", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    await runCli({ argv: ["log", "append", "--slug", "work", "--date", "2026-08-02T14:23"], cwd: dir });
    const before = readFileSync(join(dir, REL), "utf8");
    await runCli({ argv: ["log", "session-end", "--date", "2026-08-02"], cwd: dir });
    const after1 = readFileSync(join(dir, REL), "utf8");
    expect(after1.startsWith(before)).toBe(true);
    await runCli({ argv: ["log", "session-end", "--date", "2026-08-02"], cwd: dir });
    expect(readFileSync(join(dir, REL), "utf8")).toBe(after1);
    rmProject({ dir });
  });
});

describe("log backfill-sha", () => {
  test("fills only the LAST pending entry, all other bytes identical", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    await runCli({ argv: ["log", "append", "--slug", "am", "--date", "2026-08-02T09:00"], cwd: dir });
    await runCli({ argv: ["log", "append", "--slug", "pm", "--date", "2026-08-02T15:30"], cwd: dir });
    const before = readFileSync(join(dir, REL), "utf8");
    const r = await runCli({ argv: ["log", "backfill-sha", "--sha", "abc1234", "--date", "2026-08-02"], cwd: dir });
    expect(r.code).toBe(0);
    const after = readFileSync(join(dir, REL), "utf8");
    const needle = "**Commit:** (pending)";
    const i = before.lastIndexOf(needle);
    expect(after).toBe(`${before.slice(0, i)}**Commit:** abc1234${before.slice(i + needle.length)}`);
    expect(after.indexOf("(pending)")).toBeGreaterThan(-1); // first entry untouched
    rmProject({ dir });
  });

  test("errors: missing file, nothing pending, bad sha", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    let r = await runCli({ argv: ["log", "backfill-sha", "--sha", "abc1234", "--date", "2026-08-02"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("no-log-entry");

    await runCli({ argv: ["log", "append", "--slug", "a", "--date", "2026-08-02"], cwd: dir });
    await runCli({ argv: ["log", "backfill-sha", "--sha", "abc1234", "--date", "2026-08-02"], cwd: dir });
    r = await runCli({ argv: ["log", "backfill-sha", "--sha", "abc1234", "--date", "2026-08-02"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("no-pending-commit");

    r = await runCli({ argv: ["log", "backfill-sha", "--sha", "xyz", "--date", "2026-08-02"], cwd: dir });
    expect(r.code).toBe(2);
    rmProject({ dir });
  });
});

describe("log commit-msg", () => {
  test("golden: seeded entry + workspace → exact commit.md", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, "pnpm-workspace.yaml"), 'packages:\n  - "packages/*"\n');
    mkdirSync(join(dir, "packages/core/src"), { recursive: true });
    writeFileSync(join(dir, "packages/core/package.json"), '{"name":"@x/core","version":"0.0.0"}');
    writeFileSync(join(dir, "packages/core/src/index.ts"), "export const a = 1;\n");
    gitInit({ dir });
    mkdirSync(join(dir, ".agent/docs/session-log/2026/08"), { recursive: true });
    writeFileSync(join(dir, REL), SEEDED_ENTRY);
    writeFileSync(join(dir, "packages/core/src/index.ts"), "export const a = 2;\n"); // uncommitted

    const r = await runCli({ argv: ["log", "commit-msg", "--date", "2026-08-02"], cwd: dir });
    expect(r.code).toBe(0);
    expect(readFileSync(join(dir, ".agent/docs/session-log/2026/08/2026-08-02.commit.md"), "utf8")).toBe(GOLDEN_COMMIT_MD);
    expect(r.stdout).toContain("feat(core): filter panel wiring");
    rmProject({ dir });
  });

  test("no entry → no-log-entry", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["log", "commit-msg", "--date", "2026-08-02"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("no-log-entry");
    rmProject({ dir });
  });
});

describe("unit: inferScope / buildCommitMessage / sectionBullets", () => {
  test("inferScope: hit, tie → lexicographic, no workspace → null", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, "pnpm-workspace.yaml"), 'packages:\n  - "packages/*"\n');
    expect(inferScope({ root: dir, changedPaths: ["packages/core/src/a.ts", "packages/core/b.ts", "packages/ui/c.ts"] })).toBe("core");
    expect(inferScope({ root: dir, changedPaths: ["packages/ui/a.ts", "packages/core/b.ts"] })).toBe("core"); // tie → lexicographic
    expect(inferScope({ root: dir, changedPaths: ["README.md"] })).toBe(null);
    rmProject({ dir });
    const plain = mkTmpProject({ fixture: "empty-project" });
    expect(inferScope({ root: plain, changedPaths: ["src/index.ts"] })).toBe(null);
    rmProject({ dir: plain });
  });

  test("buildCommitMessage: fix type, 72-char cap without mid-word cut, title-only", () => {
    expect(buildCommitMessage({ slug: "fix the flaky selector test", built: [], decisions: [], scope: null })).toBe(
      "fix: fix the flaky selector test\n",
    );
    const long = buildCommitMessage({
      slug: "a very long slug that keeps going and going and going and going and going onward",
      built: [],
      decisions: [],
      scope: "core",
    });
    const title = long.split("\n")[0] as string;
    expect(title.length).toBeLessThanOrEqual(72);
    expect(title.endsWith(" ")).toBe(false);
    expect(buildCommitMessage({ slug: "tiny", built: [], decisions: [], scope: null })).toBe("feat: tiny\n");
  });

  test("sectionBullets: present / absent / empty", () => {
    const body = "## 2026-08-02 — 09:00 — x\n\n### What was built\n- a\n- b\n\n### Decisions made\n\n### Problems hit\n";
    expect(sectionBullets({ entryBody: body, heading: "What was built" })).toEqual(["- a", "- b"]);
    expect(sectionBullets({ entryBody: body, heading: "Decisions made" })).toEqual([]);
    expect(sectionBullets({ entryBody: body, heading: "Nope" })).toEqual([]);
  });
});
