# 03 — Session Log, Commit, Env, Ported Skills

> Phase spec 3 of 8. Prereqs: `00-master.md` (§2 conventions + §7 schemas binding, D7
> commit_mode) and `01-foundation.md` (all `src/lib/` contracts — `paths.P`, `parseArgs`,
> `Reporter`, frontmatter, `fsx`, `git`, `manifest`, `DoctorCheck`, `runCli`/fixtures/`gitInit`
> — are pinned there, NOT respecced here). Spec 02 shipped `harness struct`; skills reference it.
> Requirements: proposal §12 (commit + session log; entry structure authoritative), §15
> (`env-vars-undocumented`), §16 (debug skill).

## Overview

Deliver the session-cycle commands (`harness log append|session-end|backfill-sha|commit-msg`),
`harness env check`, the `env-vars-undocumented` doctor check, and five embedded skills:
`commit` (both D7 commit_modes), `debug`, plus thin router ports of `document`, `research`,
`learn`. After this spec a full fixture session runs: log → seeded entry → commit.md → backfill.

## Design Decisions (this spec)

- **Log files are append-only.** Commands only append bytes at EOF, with ONE exception: the
  targeted replacement of the literal `**Commit:** (pending)` by `backfill-sha`. Nothing ever
  rewrites prior entries; tests assert prefix-stability.
- **Dates via injection.** Every `log` sub accepts `--date <YYYY-MM-DD[THH:MM]>`. When absent:
  git HEAD commit timestamp, else system clock — resolved in exactly one function
  (`resolveLogDate`, the only clock touchpoint; §2.8 determinism). Tests always pass `--date`.
- **`env.manifest.md` is a markdown table** `| VAR | required | description |` (Step 6) —
  hand-editable, parseable without YAML. `env check` reports variable **names only**; values
  never reach the Reporter (tested).
- **Module gates**: `log *` requires `modules.session_log` (error `module-disabled`);
  `env check` requires `modules.env_manifest` (CLI: info + exit OK when off).
- New `HarnessError` codes: `no-log-entry`, `no-pending-commit`, `module-disabled`, `bad-date`.
- **Ported skills are routers, not the old pi prompts**: platform-neutral, no pi install paths,
  no `{{PLACEHOLDER}}` blocks; project specifics come from `.agent/docs/`. `research`/`learn`
  write to `.agent/docs/research/` (new dir, created on first use; research module gates it).

## Out of Scope

Sync/adapters (04), `implement`/`polish` (05), `deps` (06). No changes to any 01/02 contract
beyond the two additive `git.ts` helpers in Step 1 and the doctor-registry append in Step 7.

## Implementation Order

> `[agent]` = boilerplate/pattern-following · `[dev]` = core logic, guided stub named per step

1. `[agent]` `git.ts` additions — `headCommitIso`, `uncommittedFiles`
2. `[dev]` `log append` + CLI wiring — key fns: `resolveLogDate`, `logAppend`
3. `[dev]` `log session-end` — key fn: `logSessionEnd`
4. `[dev]` `log backfill-sha` — key fn: `logBackfillSha`
5. `[dev]` `log commit-msg` — key fns: `inferScope`, `buildCommitMessage`
6. `[dev]` `env check` — key fns: `parseEnvManifest`, `envCheck`
7. `[dev]` Doctor check `env-vars-undocumented`
8. `[agent]` `commit` skill + `references/session-log-format.md`
9. `[agent]` `debug` skill + `references/debug-hierarchy.md`
10. `[agent]` `document` / `research` / `learn` skills + templates test
11. `[dev]` End-to-end session-cycle test
12. Verification

---

## Step 1: `git.ts` additions `[agent]`

- [ ] Add two functions to `harness/src/lib/git.ts` (full code, same style as 01 Step 8:
      execSync, safe defaults, git absence never crashes) + cases in `git.test.ts`; run tests

```typescript
/**
 * ISO-8601 committer date of HEAD (`git log -1 --format=%cI`), e.g. "2026-08-02T14:23:11+02:00".
 * @param props.root - Project root. @returns ISO string, or "" when not a repo / no commits.
 */
export function headCommitIso(props: { root: string }): string { /* full code */ }

/**
 * Paths with uncommitted changes (staged + unstaged + untracked) via `git status --porcelain`.
 * Renames report the NEW path. @param props.root - Project root.
 * @returns Root-relative POSIX paths, sorted, deduped; [] when not a repo / on git error.
 */
export function uncommittedFiles(props: { root: string }): string[] { /* full code */ }
```

Tests (via `gitInit`): `headCommitIso` matches `/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/`;
`uncommittedFiles` after adding one file + modifying one tracked file returns exactly those two
sorted paths; both return safe defaults on non-repo `empty-project`.

---

## Step 2: `harness log append` `[dev]`

- [ ] Create `src/commands/log.ts` + `src/commands/log.test.ts`
- [ ] Wire `log` into the cli.ts command table (help: `log — session log: append, session-end,
      backfill-sha, commit-msg`); extend `cli.test.ts` usage test; run tests

Grammar: `harness log <sub> [--slug <text>] [--date <d>] [--sha <sha>]` via `parseArgs`. Every
sub: `resolveProjectRoot` → `loadManifest` → `modules.session_log` false →
`HarnessError("module-disabled", "session_log module is disabled in manifest.json", { hint: "enable modules.session_log" })`.

**File: `harness/src/commands/log.ts`** — constants (full code) + guided stubs:

```typescript
/** Fixed entry skeleton ({date}/{time}/{slug} substituted); structure per proposal §12. */
export const ENTRY_TEMPLATE = `## {date} — {time} — {slug}

**Spec:** (none)
**Commit:** (pending)

### What was built

### Decisions made

### Problems hit

### Where I left off
`;

/** Marker appended by session-end; doubles as its idempotence guard. */
export const SESSION_END_MARKER =
  "_Session end — fill in: current state · next step · watch-outs._";

/** Questions session-end prints for the commit skill to ask the developer. */
export const SESSION_END_QUESTIONS = [
  "1. What was built this session?",
  "2. Any decisions that deviated from the spec — and why?",
  "3. Any problems hit, and how were they resolved?",
  "4. Where does the session leave off? (current state, next step, watch-outs)",
];

export interface LogDate { date: string; time: string }   // "YYYY-MM-DD", "HH:MM"

/**
 * Resolves the effective log date/time — THE only clock/git-time touchpoint in this file.
 * @param props.root - Project root. @param props.dateOpt - Raw --date value, if given.
 * @returns date + time. @throws {HarnessError} code "bad-date" on malformed --date.
 */
export function resolveLogDate(props: { root: string; dateOpt?: string }): LogDate {
  // TODO: implement
  // 1. dateOpt → must match /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?$/ else HarnessError("bad-date",
  //    `invalid --date "…" (want YYYY-MM-DD or YYYY-MM-DDTHH:MM)`). Missing time → "00:00".
  // 2. Else git.headCommitIso(root); non-empty → date = slice(0,10), time = slice(11,16).
  // 3. Else local system time, zero-padded.
  // Edge case: never do TZ math — the ISO string is sliced verbatim (committer-local time).
  throw new Error("Not implemented");
}

/** Root-relative log path. @param props.date - "YYYY-MM-DD". @returns e.g. ".agent/docs/session-log/2026/08/2026-08-02.log.md". */
export function logPathFor(props: { date: string }): string { /* full code: join(P.sessionLog, yyyy, mm, `${date}.log.md`) */ }

/**
 * Appends a new entry skeleton to today's log (creates file + dirs on first entry of the day).
 * @param props.root - Project root. @param props.slug - Entry slug; default "session".
 * @param props.dateOpt - Raw --date. @param props.stdout - Line sink.
 * @returns The root-relative log path (also printed).
 */
export function logAppend(props: { root: string; slug?: string; dateOpt?: string; stdout: (s: string) => void }): string {
  // TODO: implement
  // 1. d = resolveLogDate; rel = logPathFor(d.date); abs = join(root, rel).
  // 2. entry = ENTRY_TEMPLATE substituted; slug = props.slug ?? "session".
  // 3. Absent → writeFileAtomic(`# Session Log — ${d.date}\n\n` + entry).
  //    Exists → APPEND "\n" + entry (appendFileSync — the one non-atomic write; atomic rewrite
  //    would violate append-only for concurrent readers; documented).
  // 4. stdout(rel); return rel.
  // Edge cases: existing file not ending "\n" → append "\n\n" + entry (never glue to text);
  //   slug containing "\n" → HarnessError("usage", "slug must be a single line").
  throw new Error("Not implemented");
}

/**
 * Appends one bullet line under today's latest entry (consumed by 05's `implement done` —
 * always called as a function, never via the CLI). Creates the file and a "session" entry
 * first when today has none (via logAppend machinery).
 *
 * @param props.root - Project root.
 * @param props.line - Single-line text; written as `- <line>` at the end of today's entry.
 * @param props.dateOpt - Raw --date injection for tests (same grammar as resolveLogDate).
 * @returns Nothing.
 * @throws {HarnessError} code "usage" when props.line contains a newline.
 */
export function appendLogLine(props: { root: string; line: string; dateOpt?: string }): void {
  // TODO: implement
  // 1. resolveLogDate; ensure today's file+entry exist (reuse logAppend with slug "session",
  //    silent stdout) only when absent.
  // 2. appendFileSync `- ${props.line}\n` at end of file (append-only discipline; the latest
  //    entry is always the last block, so end-of-file IS the latest entry).
  throw new Error("Not implemented");
}
```

Test additions for `appendLogLine` (same log.test.ts): appending to an existing entry adds exactly
`- implement demo: T1 done\n` at EOF; on an empty day it first creates the skeleton then appends;
multiline input throws usage.

**Golden test** (full code in `log.test.ts` — the exact-string contract for the suite):

```typescript
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

test("creates file with header + skeleton, prints path", async () => {
  const dir = mkTmpProject({ fixture: "initialized" });
  const r = await runCli({ argv: ["log", "append", "--slug", "filter panel wiring", "--date", "2026-08-02T14:23"], cwd: dir });
  expect(r.code).toBe(0);
  expect(r.stdout).toContain(REL);
  expect(readFileSync(join(dir, REL), "utf8")).toBe(GOLDEN_ENTRY);
  rmProject({ dir });
});
```

Further cases (same file, full code, exact contracts): second append same day (`--date
…T15:30`) → new file content `startsWith` the prior content (append-only pin) and contains
`## 2026-08-02 — 15:30 — b`; date-only `--date 2026-08-02` → heading
`## 2026-08-02 — 00:00 — session` (default slug); `--date "Aug 2"` → exit 2; manifest edited to
`modules.session_log=false` → exit 2, stderr contains `session_log`; with `gitInit` and no
`--date` → created path matches `/session-log\/\d{4}\/\d{2}\/\d{4}-\d{2}-\d{2}\.log\.md$/`.

---

## Step 3: `harness log session-end` `[dev]`

- [ ] Add `logSessionEnd` to `log.ts` + tests; run tests

```typescript
/**
 * Ensures today's entry exists (creates via logAppend, slug "session", when missing), then
 * appends the SESSION_END_MARKER prompt-block at EOF — landing inside the latest entry's
 * "### Where I left off" section (always the file's last section). Prints the questions the
 * invoking skill must ask, then the path to write answers into.
 * @param props.root - Project root. @param props.dateOpt - Raw --date.
 * @param props.stdout - Line sink. @returns The root-relative log path.
 */
export function logSessionEnd(props: { root: string; dateOpt?: string; stdout: (s: string) => void }): string {
  // TODO: implement
  // 1. Resolve date/path; file absent OR no /^## \d{4}-\d{2}-\d{2} — /m heading (hand-mangled)
  //    → logAppend({ slug: "session", … }) with a no-op stdout.
  // 2. Idempotence: latest entry (text after the LAST heading match) already contains
  //    SESSION_END_MARKER → skip; else append "\n" + SESSION_END_MARKER + "\n".
  // 3. stdout("Ask the developer:"); each SESSION_END_QUESTIONS line indented 2 spaces;
  //    stdout(`Write the answers into: ${rel}`); return rel.
  throw new Error("Not implemented");
}
```

Tests (full code, contracts): fresh project + `session-end --date 2026-08-02T18:00` → file ends
exactly with
`"### Where I left off\n\n_Session end — fill in: current state · next step · watch-outs._\n"`
and heading is `## 2026-08-02 — 18:00 — session`; stdout contains all four question lines and
`Write the answers into: .agent/docs/session-log/2026/08/2026-08-02.log.md`. After a prior
`append`: only the marker block is added (prefix-stability), and a second `session-end` leaves
the file byte-identical.

---

## Step 4: `harness log backfill-sha` `[dev]`

- [ ] Add `logBackfillSha` to `log.ts` + tests; run tests

```typescript
/**
 * Replaces the LAST "**Commit:** (pending)" in today's log with "**Commit:** <sha>" — the one
 * sanctioned in-place edit of a log file (D7 agent-commits mode).
 * @param props.root - Project root. @param props.sha - Commit SHA (7–40 hex chars).
 * @param props.dateOpt - Raw --date. @param props.stdout - Line sink. @returns Nothing.
 * @throws {HarnessError} "usage" bad sha · "no-log-entry" file missing (hint "harness log
 *   append") · "no-pending-commit" nothing to fill (hint "already backfilled? check the entry").
 */
export function logBackfillSha(props: { root: string; sha: string; dateOpt?: string; stdout: (s: string) => void }): void {
  // TODO: implement
  // 1. Validate /^[0-9a-f]{7,40}$/i. 2. Read today's file (absent → no-log-entry).
  // 3. i = text.lastIndexOf("**Commit:** (pending)"); i < 0 → no-pending-commit.
  // 4. Splice by slice (never regex-replace-all), writeFileAtomic, stdout(rel).
  // Edge cases: two pending entries → only the LAST (today's latest) is filled; sha written
  //   verbatim, never shortened.
  throw new Error("Not implemented");
}
```

Tests (full code, contracts): append at `…T09:00` and `…T15:30` → `backfill-sha --sha abc1234
--date 2026-08-02` → first entry still `(pending)`, second reads `**Commit:** abc1234`, all
other bytes identical; missing file → exit 2 `no-log-entry`; second run → exit 2
`no-pending-commit`; `--sha xyz` → exit 2.

---

## Step 5: `harness log commit-msg` `[dev]`

- [ ] Add `sectionBullets` (full code), `inferScope`, `buildCommitMessage`, `logCommitMsg` to
      `log.ts` + tests; run tests

Reads today's **latest** entry, derives a conventional message, writes
`.agent/docs/session-log/YYYY/MM/YYYY-MM-DD.commit.md`, prints the message then `Written: <rel>`.
`sectionBullets(props: { entryBody: string; heading: string }): string[]` — lines starting `- `
between `### <heading>` and the next `###`/`##`/EOF; [] when absent/empty.

```typescript
/**
 * Infers a commit scope from changed paths matched against workspace package globs.
 * @param props.root - Project root. @param props.changedPaths - Root-relative changed files.
 * @returns Package dir basename (e.g. "core") or null (emit unscoped "type: desc").
 */
export function inferScope(props: { root: string; changedPaths: string[] }): string | null {
  // TODO: implement
  // 1. Globs: pnpm-workspace.yaml `packages:` (yaml pkg) → else package.json `workspaces`
  //    (array or { packages }) → else null. (turbo.json signals a monorepo but lists no
  //    packages — never consulted for names.)
  // 2. Per glob ("packages/*", "apps/**"): prefix = text before first "*"; skip "!…" negations.
  //    Changed path starting with prefix → candidate = segment right after prefix (package DIR
  //    basename; no package.json reads — deterministic).
  // 3. Tally across paths; winner = highest count; tie → lexicographically smallest.
  //    No candidates (paths at repo root / outside globs) → null.
  throw new Error("Not implemented");
}

/**
 * Builds the commit message (title + why-body) from entry parts.
 * @param props.slug - Entry slug from the "## date — time — slug" heading.
 * @param props.built - "What was built" bullets, verbatim "- …" lines.
 * @param props.decisions - "Decisions made" bullets, verbatim.
 * @param props.scope - From inferScope, or null.
 * @returns Full commit.md content, trailing newline included.
 */
export function buildCommitMessage(props: { slug: string; built: string[]; decisions: string[]; scope: string | null }): string {
  // TODO: implement
  // 1. type — first regex hit wins, tested on slug then built text:
  //    /\b(fix|bug|broken|regression)\b/i → "fix"; /\bdocs?\b/i → "docs";
  //    /\b(refactor|rename|extract)\b/i → "refactor"; /\btest(s|ing)?\b/i → "test"; else "feat".
  // 2. title = `${type}(${scope}): ${slug.toLowerCase()}` (no scope → `${type}: …`); > 72 chars
  //    → drop trailing whole words until ≤ 72 (never mid-word, no ellipsis).
  // 3. Content = title + "\n" [+ "\n" + built.join("\n") + "\n"]
  //    [+ "\nWhy:\n" + decisions.join("\n") + "\n"] — body is the why-narrative from the log,
  //    never a file list (proposal §12 step 2).
  // Edge case: both sections empty → title only.
  throw new Error("Not implemented");
}
```

`logCommitMsg(props: { root; dateOpt?; stdout })` guided stub:

```
// 1. Read today's file; absent or no "## " heading → HarnessError("no-log-entry",
//    `no session log entry for <date>`, { hint: "harness log append" }).
// 2. Latest entry = from last /^## \d{4}-\d{2}-\d{2} — /m to EOF; slug = heading text after
//    the second " — "; built/decisions via sectionBullets.
// 3. changedPaths = UNION of: git.changedFilesSince({ sha }) where sha = the LAST filled
//    "**Commit:** <7-40 hex>" occurring BEFORE the latest entry (session baseline, if any),
//    and git.uncommittedFiles (message-only mode: work isn't committed yet). Dedupe, sort.
//    Not a repo → [].
// 4. msg = buildCommitMessage({ slug, built, decisions, scope: inferScope(…) }).
// 5. writeFileAtomic(<same dir>/<date>.commit.md, msg); stdout(msg); stdout(`Written: ${rel}`).
```

**Golden strings** (full code in `log.test.ts`):

```typescript
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
```

Golden test flow (full code): `initialized` fixture + `gitInit`; seed `pnpm-workspace.yaml`
(`packages:\n  - "packages/*"\n`) + `packages/core/src/index.ts`; commit; write `SEEDED_ENTRY`
to the log path (tests may write wholesale — only *commands* are bound by append-only); modify
`packages/core/src/index.ts` (uncommitted); `log commit-msg --date 2026-08-02` → exit 0,
commit.md `=== GOLDEN_COMMIT_MD`, stdout contains the title. Unit tests: `inferScope` (hit →
"core"; tie → lexicographic; no workspace → null), `buildCommitMessage` (slug "fix the flaky
selector test" → `fix: …`; 90-char slug → title ≤ 72, no mid-word cut; empty sections → title
only), `sectionBullets` (present / absent / empty).

---

## Step 6: `harness env check` `[dev]`

- [ ] Create `src/commands/env.ts` + `src/commands/env.test.ts`; wire `env` into cli.ts
      (+usage test line); run tests

**`env.manifest.md` format (authoritative — init phase 5 writes it, this parses it):**

```markdown
# Environment Variables

> Parsed by `harness env check`. required = yes|no. Never put secret VALUES in this file.

| VAR | required | description |
|-----|----------|-------------|
| DATABASE_URL | yes | Postgres connection string |
| ANALYTICS_ID | no | Plausible site id |
```

```typescript
export interface EnvVarDoc { name: string; required: boolean; description: string }

/**
 * Parses the env.manifest.md table. Tolerant: non-table lines, the header row, separator rows,
 * and rows whose first cell isn't ALL_CAPS_SNAKE are skipped silently.
 * @param props.text - File content. @returns Documented vars in table order.
 */
export function parseEnvManifest(props: { text: string }): EnvVarDoc[] {
  // TODO: implement
  // 1. Lines starting "|" → split on "|", trim cells, drop empty edge cells.
  // 2. Skip header (cell0 "VAR" case-insensitive) and separator rows (cells only -/:).
  // 3. Keep rows with cell0 matching /^[A-Z][A-Z0-9_]*$/; required = lowercased cell1 ∈
  //    {"yes","true"}; description = cell2 ?? "".
  // Edge cases: duplicate VAR → first wins; missing cells → required false, desc "".
  throw new Error("Not implemented");
}

/**
 * Checks documented vars against the live environment and .env/.env.local. NEVER reports
 * values — names only.
 * @param props.root - Project root. @param props.env - Injected environment (CLI passes
 *   process.env; tests pass literals). @param props.reporter - Sink.
 * @returns EXIT.OK, or EXIT.FINDINGS when a required var is missing.
 */
export function envCheck(props: { root: string; env: Record<string, string | undefined>; reporter: Reporter }): number {
  // TODO: implement
  // 1. loadManifest; modules.env_manifest false → reporter.info("env_manifest module
  //    disabled") → EXIT.OK.
  // 2. P.envManifest absent → reporter.error(".agent/env.manifest.md missing",
  //    "env-manifest-missing", "harness init write-phase 5") → EXIT.FINDINGS.
  // 3. dotenvNames = names with non-empty values from <root>/.env and .env.local: lines
  //    matching /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/, value non-empty after
  //    trimming one quote layer. Values discarded immediately after the emptiness test.
  // 4. Per parseEnvManifest var: set = env[name] non-empty OR name ∈ dotenvNames.
  //    required && !set → reporter.error(`missing required env var: ${name} — ${desc}`);
  //    !required && !set → reporter.info(`optional env var unset: ${name}`); set → reporter.ok.
  // 5. Return FINDINGS iff reporter.hasErrors().
  throw new Error("Not implemented");
}
```

Tests (full code, contracts — `initialized` fixture, seed the manifest block above verbatim):
required set via injected env → exit 0; required only in seeded `.env`
(`DATABASE_URL="postgres://sekrit@host/db"`) → exit 0 **and** joined output does NOT contain
`sekrit` (value-privacy pin); required missing → exit 1, output names `DATABASE_URL`; optional
missing → info, exit 0; manifest file deleted → exit 1 `env-manifest-missing`;
`modules.env_manifest=false` → exit 0 info. `parseEnvManifest` unit: golden table → exactly the
two `EnvVarDoc`s; malformed rows skipped.

---

## Step 7: Doctor check `env-vars-undocumented` `[dev]`

- [ ] Create `src/checks/envVarsUndocumented.ts` + `.test.ts`; append to the doctor.ts static
      registry; run tests

Contract (proposal §15): id `env-vars-undocumented` · severity `warn` · appliesWhen
`ctx.manifest.modules.env_manifest && ctx.read(".env.example") !== null` · run:

```
// 1. exampleNames = /^([A-Za-z_][A-Za-z0-9_]*)=/gm over .env.example.
// 2. documented = parseEnvManifest(ctx.read(P.envManifest) ?? "") names.
// 3. Finding per exampleName ∉ documented:
//    { message: `.env.example: ${name} not documented in env.manifest.md`,
//      hint: "add a row to .agent/env.manifest.md" }.
// Edge cases: env.manifest.md absent → every example var is a finding (file absence itself is
//   `harness env check`'s error, not this check's); commented "#FOO=" lines don't match.
```

Test (full code, contracts): `initialized` fixture; seed `.env.example` =
`DATABASE_URL=\nAPI_KEY=\n` + env.manifest.md documenting only `DATABASE_URL` → doctor reports
exactly one warn naming `API_KEY`; add an `API_KEY` row → passes; `modules.env_manifest=false`
→ skipped (no line for its id in `--json` output).

---

## Step 8: `commit` skill `[agent]`

- [ ] Create `src/templates/skills/commit/SKILL.md` + `references/session-log-format.md`
      (01's `init scaffold` already copies embedded skills into `.agent/skills/` — no wiring)

**File: `src/templates/skills/commit/SKILL.md`** (full content, ≤150 lines):

```markdown
---
name: commit
description: Generate a commit message from today's session log and update project documents at
  the end of a work session. Triggers on "commit", "/commit", "generate commit message", "wrap
  up this session". Honors manifest.json#workflow.commit_mode — "message-only" presents the
  message for lazygit; "agent-commits" stages and commits after confirmation.
harness_model_role: smol
---

# Commit

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.

## Steps

1. **Read the mode.** `workflow.commit_mode` in `.agent/manifest.json`: `"message-only"`
   (default) or `"agent-commits"`.
2. **Ensure today's log entry.** Run `harness log session-end`. It creates today's entry if
   missing and prints four questions. If the entry's sections are empty, ask the developer
   those questions (structured question tool if available — `ask_user_question` /
   `AskUserQuestion` — else a plain numbered list) and write the answers into the printed path.
   Append into today's entry only — never rewrite earlier entries. Load
   `references/session-log-format.md` for the entry format.
3. **High-care projects:** if `workflow.default_tier` is "high-care" and code changed since the
   last sync-spec run, suggest running the sync-spec skill first (it extracts patterns and
   updates standards). Continue if the developer declines.
4. **Generate the message.** Run `harness log commit-msg`. Review against the rules in
   `references/session-log-format.md`; if type/scope/title reads wrong, edit
   `.agent/docs/session-log/YYYY/MM/YYYY-MM-DD.commit.md` directly (title ≤ 72 chars, body says
   why — never a file list).
5. **Update project documents** (consult `manifest.json#modules`; proposal §12 step 3):
   - `docs/product/roadmap.md` — tick milestone tasks completed this session (modules.roadmap)
   - `docs/tasks.md` — move finished tasks to "## Recently Done" (modules.tasks)
   - `docs/decisions/` — if today's "Decisions made" holds an architectural decision not yet
     recorded, ask whether to write an ADR now (modules.decisions)
   - new files created this session → run `harness struct` (refreshes directory-structure.md)
   Collect every change for the step-8 summary. Nothing is silently changed.
6. **Regenerate state.** Run `harness state`.
7. **Commit — by mode.**
   - `message-only`: present the message ready to copy. The developer stages + commits via
     lazygit and pastes it. Do NOT run `git commit`.
   - `agent-commits`: show `git status --porcelain`; confirm the exact file list with the
     developer (structured question tool). On confirmation:
     `git add <files> && git commit -F .agent/docs/session-log/YYYY/MM/YYYY-MM-DD.commit.md`,
     then `harness log backfill-sha --sha "$(git rev-parse HEAD)"`.
8. **Summary.** "Updated: [files]. Needs your attention: [list]." Include the commit message
   (message-only) or the new commit SHA (agent-commits).
```

**File: `src/templates/skills/commit/references/session-log-format.md`** (full content):

```markdown
# Session Log Format

## The file
`.agent/docs/session-log/YYYY/MM/YYYY-MM-DD.log.md` — an append-only diary. One file per day,
one `##` entry per work block. Created/extended only via `harness log append`. The single
permitted in-place edit is `harness log backfill-sha` filling `**Commit:** (pending)`.

## Entry structure (`harness log append` emits this skeleton)

    ## 2026-08-02 — 14:23 — filter panel wiring

    **Spec:** docs/specs/2026-07-12-collections-ui/spec.md (Step 4)
    **Commit:** (pending)

    ### What was built
    - `FilterPanel.tsx` — filter panel wired to TanStack Table

    ### Decisions made
    - Used nuqs instead of useState — URL-shareable filters matter here. Not in the spec;
      low-risk addition.

    ### Problems hit
    - nuqs `parseAsArrayOf` not exported in v2 — used `parseAsJson`. Library quirk, not our bug.

    ### Where I left off
    Empty state test failing: fix the test selector, not the component. Resume there.

## Field rules
- **Spec:** path (+ step) of the driving spec, or `(none)` for ad-hoc work.
- **Commit:** stays `(pending)` until the commit exists; `backfill-sha` fills it
  (automatic in agent-commits mode; message-only leaves it for the next session).
- Bullets state *why*, not just what. Problems record the resolution, not only the pain.
- "Where I left off" is for a cold-start reader: current state, next step, watch-outs.

## Commit message rules (`harness log commit-msg` output)
- Title `type(scope): description`, ≤ 72 chars. Types: feat, fix, docs, refactor, test.
  Scope = workspace package dir (omitted outside a workspace).
- Body: the "What was built" bullets, then `Why:` + the "Decisions made" bullets.
- Explain why, never list files — the diff already lists files.
```

---

## Step 9: `debug` skill `[agent]`

- [ ] Create `src/templates/skills/debug/SKILL.md` + `references/debug-hierarchy.md`

**File: `src/templates/skills/debug/SKILL.md`** (full content, ≤150 lines):

```markdown
---
name: debug
description: Investigate a bug with a git-history-first protocol before reading any source.
  Triggers on "debug", "/debug", "why is this broken", "this worked before", "find the
  regression". Checks recent commits, the session log, and the directory structure map before
  forming any hypothesis.
---

# Debug

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.

## Protocol — first steps, always

Most bugs are introduced by a recent commit. Run these BEFORE reading source:

    git log --oneline -20                        # what changed recently
    git diff HEAD~3..HEAD                        # what those commits actually changed
    git log --oneline origin/dev..HEAD           # changes since last known-good dev branch
    git log --oneline origin/master..HEAD        # changes since master
    git stash list                               # any stashed work that might interact

If the user says "it worked before X":

    git log --oneline <branch>..HEAD             # all commits since it worked
    git diff <branch>..HEAD -- <affected file>   # targeted diff on the specific file

## Steps

1. **Run the protocol above.** Note every commit plausibly related to the symptom.
2. **Check the session log.** Read the latest entries under `.agent/docs/session-log/` (newest
   first). The entry for the day the bug likely appeared often records the decision that caused
   it — read "Decisions made" and "Problems hit".
3. **Check the structure map.** For missing-import / wrong-path symptoms, read
   `.agent/docs/standards/directory-structure.md` — it shows where things actually live; run
   `harness struct --check` if it looks stale.
4. **Load `references/debug-hierarchy.md`** — this project's known fragile areas, most-likely
   first. Check any area intersecting the symptom before generic exploration.
5. **Form ONE hypothesis** naming the introducing commit or decision. Verify it (targeted diff,
   reproduction, or a focused test) before writing any fix.
6. **Propose the minimal fix.** Prefer adjusting the introducing change over patching symptoms
   downstream. State the root cause in one sentence.
7. **Verify** with the project's check commands (`.agent/docs/product/dev-processes.md`).
8. **Record it.** Append root cause + fix to today's log entry ("Problems hit"). If the bug
   revealed a lasting anti-pattern, suggest adding it to `docs/standards/anti-patterns.md`
   (mind its 40-line budget).
```

**File: `src/templates/skills/debug/references/debug-hierarchy.md`** (full content):

```markdown
# Debug Hierarchy — project fragile areas

> Ordered most-fragile-first. The debug skill checks intersecting areas before generic
> exploration. Maintained by the sync-spec skill: when a debugging session uncovers a recurring
> fragile area, append it here (keep ≤ 15 entries; prune superseded ones).

1. (populated per-project — example: "auth session refresh — races token rotation; check
   `session.ts` timestamps first")

## Global fallbacks (every project)
- Recent dependency bumps — `git log -10 -- package.json bun.lock pnpm-lock.yaml`
- Generated files edited by hand — anything `harness doctor` flags as drifted
- Environment — `harness env check` before chasing "works on my machine"
```

---

## Step 10: `document` / `research` / `learn` router skills `[agent]`

- [ ] Create the three skill dirs under `src/templates/skills/` (SKILL.md each, ≤60 lines, no
      references/); create `src/templates/templates.test.ts` (covers Steps 8–10); run tests

All three: standard Preflight (master §10.3) between frontmatter and Steps — elided below as
`<PREFLIGHT>` (write it out verbatim in the files). Platform-neutral by construction.

**`document/SKILL.md`** (full content — intent of the pi `document` prompt, distilled):

```markdown
---
name: document
description: Write or update inline documentation (JSDoc/docstrings/rustdoc — whatever the
  project uses) for a target in the codebase. Triggers on "document", "/document", "add docs
  for", "write JSDoc". Reads the implementation first; docs must match observed behavior.
harness_model_role: smol
---

# Document

<PREFLIGHT>

## Steps
1. **Resolve the target.** Given none, default to all uncommitted source changes
   (`git status --porcelain`), skipping config/lock/markdown files. Include changed TEST
   files — check for stale descriptions and assertions that no longer match the implementation.
2. **Load conventions.** `.agent/docs/product/tech-stack.md` (language, doc format),
   `harness context --for "documentation"`, and any doc-comment rules in `docs/standards/`.
3. **Read before writing.** Per target: the full file, nearby usages, the parent type, applied
   defaults. Never document behavior you haven't seen in the implementation.
4. **Write the docs.** Purpose summary (not a type restatement) · each param with valid values ·
   return + null/error cases · one realistic example where non-obvious. Never: filler
   ("Handles…"), restating signatures, invented error annotations.
5. **Edit in place** — only doc comments change; no reformatting, renaming, or logic edits.
6. **Verify** with the check commands in `.agent/docs/product/dev-processes.md`. Fix breakage
   you caused; report (don't fix) pre-existing failures.
7. **Report** documented files + any pre-existing failures.
```

**`research/SKILL.md`** (full content — findings doc, gated on `modules.research`):

```markdown
---
name: research
description: Investigate a technical question (library choice, API behavior, tooling
  comparison) and write a concise findings doc to .agent/docs/research/. Triggers on
  "research", "/research", "compare X and Y", "investigate whether".
---

# Research

<PREFLIGHT>
4. If `modules.research` is false in `.agent/manifest.json` → stop; tell the user to enable it
   (or answer inline without writing a doc, if they prefer).

## Steps
1. **Check prior work.** List `.agent/docs/research/` — if a doc on this topic exists,
   summarize it and ask whether to update or write anew.
2. **Walk sources nearest-first:** project code/docs → dependency source clones under
   `.agent/dependencies/<package>/` (if present) → installed types/docs in `node_modules` (or
   the language's equivalent) → official docs/repos on the web, last. Stop once answered; copy
   API shapes from source, never from memory.
3. **Write `.agent/docs/research/<slug>.md`** (create the dir if missing): **Question** ·
   **Answer** (concise, decision-ready) · **Sources** (full paths/URLs) · **Code references**
   (file:line or snippets ≤ 20 lines) · **Open questions**.
4. **Report the path.** Don't paste the whole doc into chat unless asked.
```

**`learn/SKILL.md`** (full content — deep-read a dependency, leave a reference note):

```markdown
---
name: learn
description: Deep-read a dependency or library to build a working understanding before changing
  code that uses it, and leave a reusable reference note. Triggers on "learn", "/learn",
  "how does <library> work", "read up on".
---

# Learn

<PREFLIGHT>

## Steps
1. **Scope the topic.** If vague ("learn the ORM"), ask once for the specific surface (API,
   config, lifecycle, extension point).
2. **Read source-of-truth first:** `.agent/dependencies/<package>/` clone if present (pinned to
   the project's version — prefer it) → the package's installed types + bundled docs/examples →
   `.agent/docs/research/` prior notes → official web docs, last.
3. **Build the understanding:** the mental model (what owns what, lifecycle), the 3–5 API
   shapes the project actually touches (copied verbatim from source), the smallest working
   example.
4. **Write `.agent/docs/research/learn-<slug>.md`** (create the dir if missing): **Mental
   model** · **Key API shapes** (verbatim signatures + source paths) · **Minimal example** ·
   **Gotchas** (version quirks seen in source, load order, footguns).
5. **Report the path** + the one-paragraph mental model inline.
```

**File: `src/templates/templates.test.ts`** (full code):

```typescript
import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { parseFrontmatter } from "../lib/frontmatter.ts";

const SKILLS = join(dirname(fileURLToPath(import.meta.url)), "skills");
const read = (rel: string) => readFileSync(join(SKILLS, rel), "utf8");

describe("03 skill templates", () => {
  for (const [name, budget] of [["commit", 150], ["debug", 150], ["document", 60],
      ["research", 60], ["learn", 60]] as const) {
    test(`${name}: frontmatter valid, within ${budget} non-empty lines`, () => {
      const text = read(`${name}/SKILL.md`);
      const fm = parseFrontmatter({ text });
      expect(fm.data.name).toBe(name);
      expect(String(fm.data.description).length).toBeGreaterThan(20);
      expect(text.split("\n").filter((l) => l.trim() !== "").length).toBeLessThanOrEqual(budget);
      expect(fm.body).toContain("## Preflight");
    });
  }
  test("references ship", () => {
    expect(read("commit/references/session-log-format.md")).toContain("**Commit:** (pending)");
    expect(read("debug/references/debug-hierarchy.md")).toContain("most-fragile-first");
  });
});
```

---

## Step 11: End-to-end session-cycle test `[dev]`

- [ ] Create `harness/test/e2e-session.test.ts` (full code); run tests

```typescript
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
      .replace("### What was built\n", "### What was built\n- `FilterPanel.tsx` — filter panel wired to TanStack Table\n- `useFilterState.ts` — filter state in URL params\n")
      .replace("### Decisions made\n", "### Decisions made\n- Used nuqs instead of useState — URL-shareable filters matter for admin use.\n");
    writeFileSync(join(dir, LOG), text);

    // 4. Uncommitted work → commit-msg → exact golden commit.md.
    writeFileSync(join(dir, "packages/core/src/index.ts"), "export const a = 2;\n");
    const m = await runCli({ argv: ["log", "commit-msg", "--date", "2026-08-02"], cwd: dir });
    expect(m.code).toBe(0);
    expect(readFileSync(join(dir, COMMIT_MD), "utf8")).toBe(GOLDEN_COMMIT_MD);
    expect(m.stdout).toContain("feat(core): filter panel wiring");

    // 5. Commit with the generated message (agent-commits mode), then backfill.
    execSync(`git add -A && git commit -q -F ${COMMIT_MD}`, { cwd: dir });
    const sha = execSync("git rev-parse HEAD", { cwd: dir }).toString().trim();
    const b = await runCli({ argv: ["log", "backfill-sha", "--sha", sha, "--date", "2026-08-02"], cwd: dir });
    expect(b.code).toBe(0);
    const finalText = readFileSync(join(dir, LOG), "utf8");
    expect(finalText).toContain(`**Commit:** ${sha}`);
    expect(finalText).not.toContain("(pending)");
    rmProject({ dir });
  });
});
```

---

## Step 12: Verification (mandatory)

- [ ] `cd harness && bun test` — all green including all 01/02 suites (no regressions from the
      git.ts additions or the doctor-registry append); no skipped tests
- [ ] `bunx tsc --noEmit` — clean
- [ ] Manual smoke in a scratch copy of `test/fixtures/initialized` (+`git init`, one commit):
      `harness log append --slug smoke` (no `--date` — HEAD-timestamp path), fill two bullets,
      `harness log commit-msg`, `harness log session-end`, `harness env check` (seed
      env.manifest.md + .env), `harness doctor` (env-vars-undocumented fires with a seeded
      `.env.example`). Confirm the log stays human-readable and append-only held throughout.
- [ ] Fix anything broken before declaring done.

## Success Criteria

- [ ] `harness log append/session-end/backfill-sha/commit-msg` and `harness env check` routed,
      module-gated, golden tests green (entry skeleton + commit.md byte-exact)
- [ ] Append-only holds: prefix-stability asserted; the only in-place edit ever made is the
      `**Commit:** (pending)` backfill
- [ ] `env check` never prints a value (privacy test green); missing required vars exit 1
- [ ] Doctor reports `env-vars-undocumented` on seeded `.env.example` drift; skips when the
      module is off
- [ ] All five skills ship as embedded templates, pass frontmatter/budget tests; the commit
      skill covers BOTH D7 commit_modes
- [ ] The e2e session cycle (Step 11) is green
