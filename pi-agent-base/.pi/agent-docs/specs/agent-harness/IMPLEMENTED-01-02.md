# Implementation Summary — Specs 01 + 02

> Implemented and verified 2026-08-06/07 on branch `feat/agent-harness`.
> Package: `/Users/zaye/.local/share/chezmoi/harness/` (`@zaye/harness` 0.1.0).
> Status: **specs 01 and 02 complete** — 166 tests green, `tsc --noEmit` clean, both manual
> verification smokes pass. Specs 03–08 not started.

## What works right now

```bash
bun run /Users/zaye/.local/share/chezmoi/harness/src/cli.ts <command>
# or from harness/: bun run harness -- <command>
```

| Command | Does |
|---|---|
| `harness init scaffold` | Idempotent `.agent/` skeleton + embedded skills (init, dev-spec, sync-spec). Falls back to cwd on brand-new dirs; never resurrects the progress file post-init. |
| `harness init write-phase <n> --data <path\|->` | Deterministic phase writers 1–9; phase 7 assembles + validates `manifest.json`; progress + collected data survive compaction in `.agent/.setup-progress.md`. |
| `harness init status` / `finish` | Resume checklist; finish validates 1–9, swaps in the post-init AGENTS.md, deletes progress. |
| `harness doctor [--json]` | 11 checks (8 from spec 01 + 3 from spec 02), memoized file access, crash-isolated per check, `doctor.checks` manifest filter. Exit 1 only on error-severity. |
| `harness state` | Regenerates `docs/state.md`: active specs w/ checkbox counts, tasks sections, recent sessions, silent doctor summary. |
| `harness spec new "<slug>" [--date]` / `spec list [--all] [--json]` | Spec dirs with the D02-1 frontmatter; dates from git or `--date`, never the wall clock. |
| `harness struct` / `struct --check` | Generates the annotated `directory-structure.md` (golden-pinned, byte-idempotent); `--check` = naming-rule validation, exit 1 on violations. |
| `harness index rebuild` | Regenerates `docs/standards/index.yml` — hand-emitted, yaml-parse-validated, description auto-extracted (no more "Needs description" rot). |
| `harness context --for "<task>" [--files a,b]` | Matches context-rules.yaml by path token / word token / file hints; degrades gracefully pre-sync. Exports `contextFilesFor` for spec 05. |
| `harness pref compact [--budget n]` / `pref remove <id>` | Supersedes → dedupe → oldest-drop pipeline; ids never renumbered; removal ledger reported. |

## New files (67 source/test/template files)

### `harness/` package scaffold
- `package.json`, `tsconfig.json`, `bunfig.toml` — Bun ≥1.3.14, strict TS, ESM, one runtime dep (`yaml`).

### `src/lib/` — shared infrastructure (spec 01 + 02 additions)
- `errors.ts` — `HarnessError` (stable `code`, optional `hint`) + `EXIT` codes (0 ok / 1 findings / 2 usage / 3 failure).
- `paths.ts` — `.agent/*` path constants (`P`), `resolveProjectRoot` (nearest `.agent/` wins over `.git/`).
- `args.ts` — zero-dep arg parser: positionals, `...rest`, `--flag`, `--key value|=value`, `--` passthrough.
- `output.ts` — `Reporter`: ordered ok/info/warn/error items, exact human format (`🔴 ERROR  …` + `→ hint`), `--json` mode.
- `frontmatter.ts` — tolerant flat-YAML frontmatter parse/serialize; byte-exact round-trip for pi + OMP fixtures (quoted values, kebab keys, inline arrays, dash lists, folded descriptions).
- `fsx.ts` — `sha256`, `writeFileAtomic` (tmp+rename), `walk` (sorted, prunes .git/node_modules/dependency-clone bodies), `ensureSymlink` (created/ok/replaced/**conflict** — never clobbers real files, ready for spec 04).
- `git.ts` — safe-default wrappers: `isRepo`, `headSha`, `changedFilesSince`, `commitsTouching`, + spec 02's `headCommitDate`, `recentChangedFiles`.
- `manifest.ts` — full `HarnessManifest` schema (master §7.1), validation with defaults (budgets, `commit_mode`), unknown-key warn+preserve.
- `syncManifest.ts` — the D10 sync ledger (load default / stable sorted save) for spec 04.
- `glob.ts` — minimal `**`/`*`/`?` matcher, compiled+cached, no deps.
- `namingRules.ts` — `parseNamingRules` (yaml fence extraction + validation) and `checkPath` (scope globs → basename regex; multi-rule "any accepts" semantics).

### `src/platforms/types.ts`
`KNOWN_PLATFORM_IDS`, `PlatformAdapter`/`BridgePlan`/`ProjectContext`/`ContextRule` — the spec 04 contract, consumed today by manifest validation and `context`.

### `src/commands/`
`init.ts`, `doctor.ts` (framework: `CheckContext`, `DoctorCheck`, `runDoctor`), `state.ts`, `spec.ts`, `struct.ts` (`buildStruct` = the directory-structure generator), `index.ts` (`buildIndex` + `extractDescription`), `context.ts` (`matchContextRules` + `contextFilesFor`), `pref.ts` (`parsePrefEntries` + `compactPrefs`). `cli.ts` is the single command-registration point.

### `src/checks/` — 11 doctor checks
Spec 01: `preferences-over-budget` (error), `anti-patterns-over-budget`, `skill-over-budget`, `agents-md-directives-over-budget`, `stale-commands`, `stale-packages` (+ `verified_at` info), `open-specs-stale`, `decisions-inconsistent`. Spec 02: `naming-violations` (last-10-commits vs rules), `structure-stale` (SHA provenance line), `index-stale` (two-way index↔disk diff). Registry: `checks/index.ts` (static imports).

### `src/templates/` — embedded defaults copied by `init scaffold`
- `agent/` — AGENTS.md fallback + post-init (≤20-line directives block), setup-progress checklist.
- `skills/init/` — SKILL.md + `references/{phases.md,inference.md,naming-interview.md}` (the full 10-phase interview contract).
- `skills/dev-spec/` — SKILL.md router + `references/{interview.md,spec-format.md,code-rules.md,build-order.md}`.
- `skills/sync-spec/` — SKILL.md + `references/{pattern-extraction.md,compaction-rules.md}`.
- `standards/naming-conventions.template.md` — empty-rules skeleton for init phase 8.
- `templates.test.ts` enforces every SKILL.md ≤150 lines / reference ≤120 / valid frontmatter.

### `test/`
- `helpers.ts` — `mkTmpProject`, `rmProject`, `gitInit` (identity + optional pinned date), in-process `runCli`.
- `fixtures/{empty-project, ts-monorepo, initialized}` — `initialized` matches spec 02's normative tree, including the two **committed generated goldens** (`directory-structure.md`, `index.yml`) asserted in both directions (fixture == command output) and byte-idempotent.

## Verification results

- `bun test`: **166 pass, 0 fail** (318 assertions, 22 files). `bunx tsc --noEmit`: clean.
- Spec 01 smoke (scratch repo): scaffold → write-phase 1–9 → finish → doctor exit 0 (all 8 checks ✅) → state renders with real SHA → re-scaffold is a no-op.
- Spec 02 smoke (scratch repo): `spec new`/`list` → `struct` → `struct --check` reports exactly the 2 seeded violations (exit 1) → `index rebuild` → `pref compact` removes exactly P-002 (superseded) + P-003 (duplicate) → doctor exit 0 → `struct`/`index rebuild` re-runs byte-identical.
- The index golden matched the spec's predicted output **exactly**, including `lines: 55` for directory-structure.md.

## Deviations from the specs (each intentional, none user-facing)

1. **Frontmatter body kept verbatim** (01 said "leading newline stripped") — required for the byte-exact `raw + body === source` round-trip guarantee.
2. **Doctor findings may override level per item** — `stale-packages` emits warn findings + an info `verified_at` finding from one check; `CheckFinding` gained an optional `level`.
3. **`init` falls back to cwd** when neither `.agent/` nor `.git/` exists — `harness init` must work on brand-new directories.
4. **`init scaffold` skips `.setup-progress.md` when `manifest.json` exists** — post-finish re-scaffold must not resurrect the wizard.
5. **Phase 5 env_vars accept optional `required`** (default yes) so `env.manifest.md` matches spec 03's `| VAR | required | description |` parser; phase 7 also reads phase 3's domains (manifest needs `standards_domains`).
6. **`structure-stale` ignores `directory-structure.md` itself** in `changedFilesSince` — otherwise every struct→commit cycle self-flags stale forever (caught by the test).
7. **`buildStruct` renders subdirectories in byte-alphabetical order** — spec 02's golden tree had `standards/` before `specs/`, contradicting its own algorithm; the spec's golden was patched to match (`02-spec-naming.md` updated).
8. **`stale-packages` skips the `verified_at` comparison when HEAD is unknown** (non-repo) — avoids a permanent info finding on gitless projects.
9. **`verified_at` frontmatter omitted entirely when no git** (init phase 4/5 writers) rather than an empty value.

## What's next (not yet built)

Specs 03–08 in order: session log + commit (03), **platform bridges/sync — the step that makes OMP + Claude Code consume `.agent/`** (04), implement/polish (05), deps (06), template mechanism (07), integration + the migration runbook for maprios/vex/dotfiles (08). Until 04 lands, `harness sync` doesn't exist yet — the init skill already warns about this.

Nothing has been committed — the working tree on `feat/agent-harness` holds all changes for your review.
