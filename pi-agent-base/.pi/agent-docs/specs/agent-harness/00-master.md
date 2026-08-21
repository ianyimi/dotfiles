# Agent Harness — Master Spec (00)

> Spec suite for implementing the `harness` CLI and platform-agnostic agent harness described in
> `../agent-harness-proposal.md` (Draft v4). This master spec defines the architecture, shared
> schemas, and contracts. Phase specs `01`–`08` are implemented **in order**; each is independently
> verifiable. Read this file completely before starting any phase spec.
>
> Implementer: an AI agent (Fable 5). Follow the dev-spec conventions in §2 exactly.
> Status: ready-for-implementation · Authored: 2026-08-06

---

## Contents

- §1 Overview & scope
- §2 Implementation conventions (binding for all phase specs)
- §3 Corrections to the proposal (verified against installed OMP source)
- §4 Design decisions (locked with the developer)
- §5 Repo layout — the `harness/` package
- §6 The `.agent/` directory — source of truth layout
- §7 Core schemas (manifest, context rules, sync manifest, naming rules, index)
- §8 Shared infrastructure contracts (CLI router, output, fs, frontmatter, git)
- §9 Platform bridge contract (symlink-first sync, `PlatformAdapter`)
- §10 Skill authoring conventions
- §11 Spec suite index & build order
- §12 Global verification

---

## 1. Overview & Scope

We are building `@zaye/harness`: a Bun + TypeScript CLI (`harness`) plus a set of platform-agnostic
skills that together form a self-maintaining agent harness. The harness lives in each project as a
committed `.agent/` directory (single source of truth). Platform folders (`.omp/`, `.claude/`, and
later `.opencode/`, `.codex/`) are **generated bridges**: symlinks into `.agent/` wherever the
platform can consume shared content directly, plus minimal generated platform-specific glue.

**In scope for this suite (specs 01–08):**
- The `harness` CLI: `init` (primitives), `doctor`, `state`, `sync`, `platform add`, `index rebuild`,
  `struct [--check]`, `spec new|list`, `context --for`, `log append|session-end`, `pref compact|remove`,
  `env check`, `deps clone|sync|add|remove|list`, `implement`, `polish`, `template save|list|inspect|delete`,
  `worktree`
- Skills (in `.agent/skills/`, shipped as embedded defaults in the CLI): `init`, `dev-spec`,
  `sync-spec`, `commit`, `implement`, `polish`, `debug`, `document`, `research`, `learn`
- Platform bridges for **OMP** (oh-my-pi) and **Claude Code**, plus the adapter mechanism that makes
  future platforms a drop-in
- Full test coverage of every CLI command (bun test, fixture repos, golden files)

**Out of scope (deferred, do not build):**
- Standalone binary compilation, GitHub release workflow, install.sh (proposal Phase 10)
- All 7 built-in init templates — the `template save/…` **mechanism** IS in scope; template *content*
  will be authored later by the developer from inside real projects
- `.pi/` (base pi) shims, opencode/codex adapter **implementations** (the adapter interface must make
  them straightforward later)
- `harness upgrade` (template migration against base versions — needs real-world template churn first)
- OMP-native subagent *implementations* beyond the generated agent definitions (proposal Phase 9's
  deeper integration)

**Primary sources.** The proposal (`../agent-harness-proposal.md`) is the requirements document.
Where this spec suite contradicts it, **this suite wins** — every deviation is listed in §3/§4 with
its reason. Do not silently re-import proposal details that these specs dropped.

---

## 2. Implementation Conventions (binding)

These apply to all code written for any phase spec.

1. **Runtime**: Bun ≥ 1.3.14 (same floor as OMP, one install serves both). TypeScript, strict mode,
   ESM. No build step for development (`bun run`), `bun test` for tests.
2. **Zero runtime dependencies** for the CLI core. Arg parsing, YAML frontmatter, and file walking are
   implemented in `src/lib/` (specced with tests in 01). Exception: `yaml` (npm) is allowed for full
   YAML documents (context-rules.yaml, naming rules blocks, index.yml) — hand-rolling a YAML parser is
   not a good use of anyone's time. Frontmatter (the `---` block) uses the internal minimal parser
   because both pi and OMP frontmatter are flat key/value + arrays, and we must tolerate/preserve
   unknown keys byte-for-byte.
3. **Single object parameters.** All exported functions and class methods take a single typed `props`
   object (parameter name `props`, inline type unless shared by 3+ functions). Access via
   `props.field` when the body defines locals; destructure only when it doesn't. Zero/one-param
   helpers (`getAll()`, `has(key)`) are exempt, as are callbacks to `.map()`/`.filter()`.
4. **JSDoc on every export**: summary, `@param props.x - …` (description mandatory), `@returns`
   (mandatory), `@throws` where thrown, `@example` on public API functions.
5. **Tests colocated**: `src/commands/doctor.ts` → `src/commands/doctor.test.ts`. Every step in a
   phase spec that adds an implementation file adds its test file in the same step. No "tests phase".
6. **Guided stubs**: core logic in phase specs is given as function signatures + numbered pseudo-code
   comments inside the body ending in `throw new Error("Not implemented")`. Boilerplate (types,
   schemas, templates, test files) is full code. Tests are exact — they pin correct behavior.
7. **No speculative code.** If nothing in the current phase spec calls it, it doesn't exist yet.
   Later phases add what they need. (E.g. the `PlatformAdapter` type ships in 01 because doctor's
   `shims-stale` check needs it, but the OMP adapter itself is built in 04.)
8. **Determinism.** Commands never depend on wall-clock ordering, locale, or map iteration order.
   All generated files are stable under re-run (idempotent sync: same inputs → byte-identical
   outputs). Timestamps in generated files come from git SHAs or injected clock (`props.now`) so
   tests can pin them.
9. **Error style**: `HarnessError` (spec 01) with `code`, human `message`, optional `hint` (a
   command to run). CLI exit codes: `0` ok, `1` errors found (doctor), `2` usage/validation error,
   `3` unexpected failure.
10. **Paths**: every command resolves the project root by walking up from cwd to the first directory
   containing `.agent/` or `.git/` (`.agent/` wins). All internal paths are project-root-relative;
   only I/O boundaries make them absolute.

---

## 3. Corrections to the Proposal (verified 2026-08-06 against `@oh-my-pi/pi-coding-agent@17.2.10` source)

These are **facts** discovered by reading installed OMP source. Phase spec 04 depends on them.

| # | Proposal says | Reality (verified) |
|---|---|---|
| C1 | `.omp/agents.yaml` defines subagents | **No such file.** OMP subagents are `.omp/agents/<name>.md`, markdown + YAML frontmatter. `name` and `description` are required (file rejected otherwise). Other keys: `tools` (array or CSV), `spawns`, `model` (role alias like `"@smol"`/`"@slow"` or model pattern), `thinking-level` (kebab-case on write), `blocking`, `prewalk`, `autoloadSkills`, `read-summarize`, `output` (JTD-style schema). |
| C2 | "OMP native injection rules" (format unspecified) | Two mechanisms: **instructions** `.omp/instructions/<name>.instructions.md` with frontmatter `applyTo: "<glob>"` (pure content injection — this is what `context-rules.yaml` compiles to), and **rules** `.omp/rules/*.md` (TTSR: `condition` regex / `astCondition` / `scope: "tool:edit(*.ts), …"` / `interruptMode`) — used for anti-pattern enforcement. |
| C3 | Model tiers via agents.yaml | Model routing = **role aliases** (`@default @smol @slow @plan @task …`) configured under `modelRoles:` in `.omp/config.yml` (YAML — `config.yml`/`config.yaml`; `settings.json` also merged). `modelRoles` is the one group OMP itself writes at project level. |
| C4 | — | OMP **natively ingests** `.claude/` (priority 90), `.codex`, `.gemini`, `.cursor`, `.windsurf`, `.opencode`, `.cline`, and **`.agent`/`.agents`** (priority 70). `.omp` wins at priority 100. Without a guard, harness content would load twice. Sync must set `disabledProviders` in generated `.omp/config.yml` (04 verifies the exact key/values against the installed source before emitting). |
| C5 | — | An **empty `.omp/` is ignored** (`ifNonEmptyDir`). Generators must always write at least one file. |
| C6 | — | OMP skills: `.omp/skills/<dir>/SKILL.md`; `description` frontmatter **required** or the skill is silently dropped; name falls back to directory basename; unknown frontmatter keys tolerated (`[key: string]: unknown`). `disable-model-invocation` normalized from kebab-case. Relative paths inside a skill resolve against the skill dir → **`references/` works via symlink**. |
| C7 | — | OMP commands `.omp/commands/*.md` are raw content (no `argument-hint`/`allowed-tools` support). Prompts `.omp/prompts/**/*.md` read only `description` frontmatter; args via `$ARGUMENTS`, `$1`, `$@`, `{{args}}`. |
| C8 | — | OMP hooks: per-tool file hooks `.omp/hooks/{pre,post}/<tool|*>.ts` **and** event-hook TS modules (`export default function (pi: HookAPI)`) with events incl. `session_start`, `turn_end`, `tool_call`. Session-start doctor runs via an event hook module. |
| C9 | Commit skill runs `git commit` (§18.8) / never runs it (§12) | Resolved: `manifest.json#workflow.commit_mode: "message-only" | "agent-commits"`, default `"message-only"` (§4 D7). |
| C10 | pi frontmatter has `model_tier` | Base pi supports only `name`, `description`, `invoke`, `disable-model-invocation`. `model_tier` in `.agent/` skills is a **harness-namespaced** field (`harness_model_role`) that adapters translate (OMP: agents `model: "@role"`; Claude/pi: ignored). |

**Verification duty (04):** before emitting `.omp/` output, the implementer must re-verify C4's
`disabledProviders` key name and provider ids, and OMP's `thinking-level` value set, against the
installed package at
`$(npm root -g)/@oh-my-pi/pi-coding-agent/` (`src/config/settings-schema.ts`, `src/discovery/*`).
These were confirmed present but not exhaustively enumerated. Record findings in the 04 spec's
"Verified constants" table before implementing `omp.ts`.

---

## 4. Design Decisions (locked with developer, 2026-08-06)

| # | Decision | Detail / why |
|---|---|---|
| D1 | **Spec suite** | Master + 8 phase specs. Implement in order; each phase leaves a working, tested CLI. |
| D2 | **Platforms now: OMP + Claude Code** | `.omp/` + `.claude/` bridges only. No `.pi/` shims. Adapter interface (§9) makes opencode/codex a future `harness platform add`. |
| D3 | **Defer** binaries + all built-in init templates | Template mechanism ships; contents authored later in-project. No `--compile`, no CI release, no install.sh. |
| D4 | **Standard dev-spec style, tests-first weight** | Guided stubs for logic; **full test files for every CLI command**. |
| D5 | **Agent-led init + CLI primitives** | The init interview is a *skill* (runs in OMP or Claude Code). The CLI provides deterministic primitives: `harness init scaffold`, `harness init write-phase <n> --data <json>`, `harness init status`, `harness init finish`. The skill infers + interviews; the CLI validates + writes + tracks progress in `.agent/.setup-progress.md`. |
| D6 | **Symlink-first bridges** | Everything readable cross-platform lives ONLY in `.agent/`. Platform dirs contain symlinks to it plus minimal generated glue. `.claude/skills → ../.agent/skills` (symlink), `.omp/skills → ../.agent/skills`, `.omp/AGENTS.md → ../.agent/AGENTS.md`, `.claude/CLAUDE.md` = thin *generated* file (routing directive + pointer, because Claude needs its own filename), OMP `agents/`, `instructions/`, `rules/`, `config.yml`, and Claude `settings.json` hooks + `CLAUDE.md` are *generated*. Editing `.agent/` updates every platform instantly; `harness sync` only regenerates the glue. |
| D7 | **`commit_mode` manifest setting** | `"message-only"` (default): skill writes `YYYY-MM-DD.commit.md`, developer commits via lazygit. `"agent-commits"`: skill stages + commits after confirmation, then backfills the SHA into the session log. Both specced + tested (03). |
| D8 | **Bun + zero-dep core** (§2.1–2.2) | Matches OMP's runtime requirement; keeps the future `--compile` path open. |
| D9 | **`.agent/` is committed; platform dirs are gitignored** | `harness sync` maintains the `.gitignore` entries. Exception: if a project intentionally commits `.claude/` for teammates, `manifest.json#platforms.commit_bridges: true` disables the gitignore management (default `false`). |
| D10 | **Never clobber user files** | Sync tracks everything it creates in `.agent/.sync-manifest.json` (path + content hash + `symlink`/`generated` kind). On regen: unchanged→rewrite freely; user-modified→leave in place, report conflict; user file at target that sync never created→never touch, report. Deletions of formerly-managed files clean up via the manifest. |
| D11 | **Spec dir format** | `spec.md` + `spec-tasks.md` per the proposal (replaces the old 4-file shape/standards/references/plan format). |
| D12 | **`harness implement` is a state machine, not an agent** | The CLI reads/writes task-group state in `spec-tasks.md`, prints the next task group + context bundle, and records verify results. The *implement skill* drives the loop by calling it. The CLI never spawns model processes. |

---

## 5. Repo Layout — the `harness/` package

Created at the chezmoi repo root (deployed like any other tool; it is NOT part of `pi-agent-base/`).

```
~/.local/share/chezmoi/harness/
├── package.json                  # name @zaye/harness, bin: { harness: "./src/cli.ts" }, type: module
├── tsconfig.json                 # strict, ESM, bundler resolution, types: ["bun-types"]
├── bunfig.toml                   # test config
├── README.md
├── src/
│   ├── cli.ts                    # entry: parse argv → route → run, top-level error handler
│   ├── lib/                      # shared infrastructure (spec 01 unless noted)
│   │   ├── args.ts               # minimal arg parser (positional, --flag, --key value)
│   │   ├── errors.ts             # HarnessError + exit codes
│   │   ├── output.ts             # reporter: ok/info/warn/error lines, --json mode
│   │   ├── frontmatter.ts        # tolerant flat YAML frontmatter parse/serialize (preserves unknown keys)
│   │   ├── fsx.ts                # atomic write, ensureDir, walk, symlink helpers, hashing
│   │   ├── git.ts                # sha, changed files, repo root; clone helpers added by 06
│   │   ├── paths.ts              # project-root resolution, .agent/* path constants; harnessHome() added by 07
│   │   ├── manifest.ts           # load/validate/save manifest.json (schema §7.1)
│   │   ├── syncManifest.ts       # load/save .agent/.sync-manifest.json (§7.3)
│   │   ├── glob.ts               # (02) minimal glob matcher shared by struct/context/sync
│   │   ├── namingRules.ts        # (02) parseNamingRules/checkPath for the §7.4 rules block
│   │   ├── depsRegistry.ts       # (06) registry.md parse/serialize
│   │   ├── templateStore.ts      # (07) ~/.harness/templates store
│   │   └── tasksFile.ts          # (08) tasks.md section parser/updater
│   ├── commands/                 # one file per command group; each exports run(props)
│   │   ├── init.ts               # (01) scaffold / write-phase / status / finish
│   │   ├── doctor.ts             # (01) check framework + checks (registry grows through 02–06)
│   │   ├── state.ts              # (01)
│   │   ├── spec.ts               # (02) new / list
│   │   ├── context.ts            # (02) --for
│   │   ├── struct.ts             # (02) generate / --check
│   │   ├── index.ts              # (02) index rebuild
│   │   ├── pref.ts               # (02) compact / remove
│   │   ├── log.ts                # (03) append / session-end
│   │   ├── env.ts                # (03) check
│   │   ├── sync.ts               # (04) bridge generation
│   │   ├── platform.ts           # (04) platform add/list
│   │   ├── implement.ts          # (05) status / next / verify / done
│   │   ├── polish.ts             # (05)
│   │   ├── deps.ts               # (06) clone / sync / add / remove / list
│   │   ├── template.ts           # (07) save / list / inspect / delete
│   │   └── worktree.ts           # (08)
│   ├── platforms/                # (04) PlatformAdapter implementations
│   │   ├── types.ts              # (01) PlatformAdapter interface + BridgePlan types
│   │   ├── omp.ts                # (04)
│   │   └── claude.ts             # (04)
│   ├── checks/                   # (01+) doctor checks, one file each, self-registering
│   └── templates/                # embedded defaults, copied by init scaffold
│       ├── skills/<name>/SKILL.md (+ references/)   # authored across 01,02,03,05
│       ├── agent/                # AGENTS.md fallback, manifest skeleton, .gitignore stubs
│       └── standards/            # naming-conventions.md + directory-structure.md templates (02)
└── test/
    ├── fixtures/                 # fixture project trees (checked in, tiny)
    │   ├── empty-project/        # no .agent
    │   ├── ts-monorepo/          # package.json + pnpm-workspace + src tree
    │   └── initialized/         # full .agent/ in a healthy state
    └── helpers.ts                # mkTmpProject(fixture), runCli(args, cwd) → {code, stdout, stderr}
```

User-level directory (created lazily, override with `HARNESS_HOME`):

```
~/.harness/
├── templates/                    # saved init templates (07)
└── cache/                        # dep clone metadata (06)
```

---

## 6. The `.agent/` Directory — Source of Truth

Exactly the proposal §3.1 layout with these amendments:

```
.agent/
├── AGENTS.md                     # committed always; pre-init fallback text (proposal §6);
│                                 # post-init: directives block (≤20 lines) + pointer sections
├── manifest.json                 # §7.1
├── context-rules.yaml            # GENERATED by sync from standards folders (§7.2)
├── env.manifest.md               # required env vars (module-gated)
├── .setup-progress.md            # init only; deleted by `harness init finish`
├── .sync-manifest.json           # GENERATED (§7.3); committed (lets doctor detect drift anywhere)
├── docs/
│   ├── product/    mission.md, tech-stack.md, dev-processes.md, roadmap.md?
│   ├── standards/  anti-patterns.md, preferences.md, naming-conventions.md,
│   │               directory-structure.md (GENERATED), index.yml (GENERATED), <domain>/…
│   ├── design/?    specs/<slug>/{spec.md,spec-tasks.md}
│   ├── decisions/  ADR-NNN.md
│   ├── tasks.md    state.md (GENERATED)
│   └── session-log/YYYY/MM/{YYYY-MM-DD.log.md, YYYY-MM-DD.commit.md}
├── skills/<name>/{SKILL.md, references/…}
└── dependencies/   .gitignore ("*\n!.gitignore\n!registry.md"), registry.md, <package>/
```

Amendments vs proposal:
- **A1** `.sync-manifest.json` added (D10).
- **A2** `AGENTS.md` lives at `.agent/AGENTS.md` and is the platform-neutral context file. OMP gets a
  symlink (`.omp/AGENTS.md`); Claude gets a generated `CLAUDE.md` whose first line is
  `@.agent/AGENTS.md` (import) followed by Claude-specific routing notes.
- **A3** `tech-stack.md` / `dev-processes.md` carry `verified_at: <git-sha>` frontmatter (doctor uses it).
- **A4** Frontmatter for every skill: `name`, `description` (both required — OMP drops skills without
  a description), optional `disable-model-invocation`, optional `harness_model_role`
  (`default|smol|slow|plan|task|…`) which only adapters interpret (C10).

---

## 7. Core Schemas

Full TypeScript definitions ship in `src/lib/manifest.ts` (01). Reproduced here as the contract.

### 7.1 `manifest.json`

```typescript
/** Root manifest of a harness-initialized project. Committed at .agent/manifest.json. */
export interface HarnessManifest {
  schema_version: "1.0";
  project: string;                     // kebab-case project name
  description: string;                 // one line; injected into subagent prompts
  harness: {
    base_version: string;              // version of @zaye/harness that ran init
    template?: string;                 // init template name, if used (07)
  };
  platforms: {
    /** Bridge targets managed by `harness sync`. Order = generation order. */
    active: PlatformId[];              // e.g. ["omp", "claude"]
    /** Commit generated bridge dirs instead of gitignoring them (D9). Default false. */
    commit_bridges?: boolean;
  };
  workflow: {
    default_tier: "high-care" | "low-care";
    importance: "high" | "medium" | "low";
    developer_implements: boolean;
    post_implement_polish: boolean;    // polish gate (05)
    commit_mode: "message-only" | "agent-commits";   // D7
    agent_can_edit?: string[];         // globs
    agent_needs_approval?: string[];   // globs
  };
  modules: {
    specs: boolean; tasks: boolean; session_log: boolean;
    roadmap: boolean; design: boolean; decisions: boolean;
    research: boolean; env_manifest: boolean; naming_conventions: boolean;
  };
  standards_domains: string[];         // e.g. ["backend","frontend","testing"] — folders under docs/standards/
  dependencies: DependencyPin[];       // (06)
  doctor: {
    checks?: string[];                 // subset filter; absent = all registered checks
    budgets: {
      preferences_lines: number;       // default 80
      anti_patterns_lines: number;     // default 40
      skill_lines: number;             // default 150
      agents_md_directives_lines: number; // default 20
    };
    stale_spec_days: number;           // default 14
  };
  repo?: {
    type: "standard" | "bare-git-worktrees";
    worktrees?: Record<string, { path: string; branch: string; readonly?: boolean }>;
  };
}

export type PlatformId = "omp" | "claude";  // widened by future adapters

export interface DependencyPin {
  package: string;                     // name as it appears in the project manifest
  version: string;                     // resolved pin at clone time
  repo: string;                        // e.g. "github.com/get-convex/convex-backend"
}
```

Validation rules (implemented + tested in 01): unknown top-level keys → warn, keep; missing required
key → `HarnessError` code `manifest-invalid` with the JSON path; `platforms.active` entries must have
a registered adapter.

### 7.2 `context-rules.yaml` (generated)

Maps file globs → context files to inject. Compiled by sync from `standards_domains`,
`naming-conventions.md` scopes, and per-domain defaults; consumed by `harness context --for` (02) and
compiled by the OMP adapter into `.omp/instructions/*.instructions.md` (04). Claude Code has no
native equivalent; `harness context` is its path.

```yaml
# GENERATED by harness sync — do not edit. Source: standards folders + naming rule scopes.
version: 1
rules:
  - id: std-backend
    when: ["convex/**", "packages/*/src/server/**"]
    inject:
      - docs/standards/backend/api.md
      - docs/standards/backend/migrations.md
  - id: naming
    when: ["**/*.ts", "**/*.tsx"]
    inject: [docs/standards/naming-conventions.md]
```

### 7.3 `.agent/.sync-manifest.json` (generated)

```typescript
/** Ledger of every path a `harness sync` run owns. Enables safe regen + cleanup (D10). */
export interface SyncManifest {
  version: 1;
  generated_at_sha: string;            // git HEAD when last synced ("" if no repo)
  entries: SyncEntry[];
}
export interface SyncEntry {
  path: string;                        // project-root-relative, e.g. ".claude/CLAUDE.md"
  kind: "symlink" | "generated" | "gitignore-line";
  /** For symlink: the link target. For generated: sha256 of written content. */
  target_or_hash: string;
  platform: PlatformId | "core";
}
```

### 7.4 Naming rules block (inside `docs/standards/naming-conventions.md`)

Exactly the proposal §18.6 shape: a fenced ` ```yaml ` block with top-level `rules:`; each rule
`{ id, pattern (regex on basename), scope (glob[]), description, examples?, counter_examples? }`.
Parsed by `struct --check` and the `naming-violations` doctor check (02). The prose "Code Identifier
Conventions" section below the block is never machine-parsed.

### 7.5 `docs/standards/index.yml` (generated)

Proposal §1.1's fix. `harness index rebuild` (02) walks `docs/standards/**/*.md`, extracts the first
paragraph (or frontmatter `description`) as the description, and writes:

```yaml
# GENERATED by harness index rebuild
root:
  anti-patterns: { description: "…", lines: 38 }
backend:
  api: { description: "…", lines: 120 }
```

`root` is reserved for files directly in `standards/`. A file whose description cannot be derived
gets `description: "(first paragraph missing — add one)"` — never the old "Needs description" rot.

---

## 8. Shared Infrastructure Contracts (built + tested in 01)

Signatures only — 01 carries the guided stubs and full tests.

- `parseArgs(props: { argv: string[]; spec: ArgSpec }) → ParsedArgs` — positionals, `--flag`,
  `--key value`, `--key=value`, `--` passthrough; unknown flag → usage error (exit 2).
- `Reporter` — `ok/info/warn/error(msg, hint?)`, `summary()`, honors `--json` (machine output:
  `{ level, id?, message, hint? }[]`) and `NO_COLOR`.
- `parseFrontmatter(props: { text: string }) → { data: Record<string, unknown>; body: string; raw: string }`
  and `serializeFrontmatter` — tolerant, preserves unknown keys and key order; flat scalars, arrays
  (inline + dash lists), quoted strings. Round-trip test: `serialize(parse(x)) === x` for all fixtures.
- `fsx`: `writeFileAtomic`, `ensureSymlink(props: { linkPath; targetPath })` (relative target,
  replaces wrong-target links, refuses to replace a real file — returns conflict), `walk`
  (glob-filtered, `.git`/`node_modules`/`dependencies` pruned), `sha256`.
- `git`: `headSha`, `isRepo`, `changedFilesSince(props: { sha })`, `commitsTouching(props: { paths; sinceDays })`.
- `resolveProjectRoot(props: { cwd })` per §2.10.
- Doctor check registration: each file in `src/checks/` default-exports
  `{ id, severity, appliesWhen(ctx), run(ctx) → CheckResult[] }`; the registry is a static import
  list in `doctor.ts` (no dynamic discovery — determinism).

---

## 9. Platform Bridge Contract

### 9.1 `PlatformAdapter` (types in 01, implementations in 04)

```typescript
/** Everything `harness sync` needs to (re)generate one platform's bridge. */
export interface PlatformAdapter {
  id: PlatformId;
  /** Directory the bridge lives in, project-root-relative ("." + id by convention). */
  dir: string;                          // ".omp" | ".claude"
  /**
   * Compute the full desired bridge state from the .agent/ source. Pure — no I/O side effects.
   * @param props.ctx - Loaded project context (manifest, standards inventory, skills inventory,
   *   context rules, root paths).
   * @returns The complete plan: every symlink and generated file this platform wants.
   */
  plan(props: { ctx: ProjectContext }): BridgePlan;
}

export interface BridgePlan {
  symlinks: Array<{ linkPath: string; targetPath: string }>;  // both root-relative
  files: Array<{ path: string; content: string }>;            // generated glue
  gitignoreLines: string[];                                   // e.g. ".omp/" unless commit_bridges
}
```

`harness sync` (04) is adapter-agnostic: load context → for each active platform `plan()` → diff the
plan against `.sync-manifest.json` + disk → apply (respecting D10 conflict rules) → write the new
sync manifest → report. `harness platform add <id>` = append to `manifest.json#platforms.active` +
run sync for that platform. Adding opencode later = write `src/platforms/opencode.ts` implementing
`plan()`, register it, done.

### 9.2 What each bridge contains (authoritative table)

| Bridge path | Kind | Content |
|---|---|---|
| `.omp/skills` | symlink | → `../.agent/skills` |
| `.omp/AGENTS.md` | symlink | → `../.agent/AGENTS.md` |
| `.omp/agents/<skill>.md` | generated | One OMP subagent per routed skill (dev-spec, implement, debug, polish…): frontmatter per C1, `model` from `harness_model_role`, body = preflight + "load skill `<name>` and follow it". |
| `.omp/instructions/<rule-id>.instructions.md` | generated | One per context-rule (7.2): `applyTo` glob + inlined pointer list ("Read: docs/standards/…"). |
| `.omp/rules/anti-patterns.md` | generated | TTSR rule compiled from `anti-patterns.md` entries that declare a `pattern:` (04 defines the opt-in syntax). Absent if none. |
| `.omp/config.yml` | generated | `disabledProviders` guard (C4) + `modelRoles` skeleton (commented) — merged carefully if user-modified (D10). |
| `.omp/hooks/session-doctor.ts` | generated | Event hook: on `session_start`, run `harness doctor --json`, surface errors via `ctx.ui.notify`. |
| `.claude/skills` | symlink | → `../.agent/skills` |
| `.claude/CLAUDE.md` | generated | `@.agent/AGENTS.md` import line + routing directive (proposal §17) + "run `harness context --for` before specs" note. |
| `.claude/settings.json` | generated/merged | `hooks.SessionStart` → `harness doctor` (managed keys only; D10 merge rules — never touch keys sync didn't write). |
| `.claude/commands/<name>.md` | generated (09) | One slash-command shim per described skill ("invoke the skill, follow it exactly", `$ARGUMENTS`). `init` ships as `harness-init.md` — Claude Code's builtin `/init` collides. |
| `.omp/prompts/<name>.md` | generated (09) | Same shims for OMP (`/init` keeps its name there). Natural-language skill triggering is unaffected — shims are an additional invocation path. |
| `.gitignore` (project) | managed lines | `.omp/`, `.claude/`, `.agent/dependencies/*` (unless `commit_bridges`). |

Both platforms tolerate unknown frontmatter keys in SKILL.md (verified: OMP `[key: string]: unknown`;
Claude Code ignores unrecognized fields), which is what makes the shared-skill symlink sound.

---

## 10. Skill Authoring Conventions

Every skill shipped in `src/templates/skills/`:

1. `SKILL.md` ≤ 150 lines (doctor-enforced budget). It is a **router**: preflight, numbered steps,
   references loaded per-step. Content lives in `references/*.md`.
2. Frontmatter: `name`, `description` (trigger phrases included — this is the only text platforms see
   before loading), optional `harness_model_role`, optional `disable-model-invocation`.
3. Preflight block (verbatim, first section of every skill body):
   ```
   ## Preflight
   1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
   2. Run `harness doctor`. Fix 🔴 errors before proceeding.
   3. Run `harness state` and read the output.
   ```
4. Platform-conditional UI: "Use the structured question tool if available (`ask_user_question` /
   `AskUserQuestion`); otherwise a plain numbered list."
5. Every skill that writes files calls CLI primitives for mechanical work (file creation, index
   rebuild, struct) instead of writing by hand, per proposal principle 10.

Skill inventory and which phase spec authors each: `init` (01), `dev-spec`, `sync-spec` (02),
`commit`, `debug` (03), `implement`, `polish` (05), `document`, `research`, `learn` (03 — thin ports
of the existing pi prompts, trimmed to router format).

---

## 11. Spec Suite Index & Build Order

| Spec | Title | Delivers | Testable outcome |
|---|---|---|---|
| `01-foundation.md` | CLI foundation, init, doctor, state | Package scaffold, `src/lib/*`, `cli.ts`, `harness init` primitives + init skill, doctor framework + 8 core checks, `harness state` | `harness init` on a fixture repo produces a valid `.agent/`; doctor catches seeded drift; all lib tests green |
| `02-spec-naming.md` | Spec, naming, structure, context | `spec new/list`, `struct [--check]`, `index rebuild`, `context --for`, `pref compact/remove`, naming/directory templates, dev-spec + sync-spec skills, doctor checks `naming-violations`, `structure-stale`, `index-stale`, `preferences-over-budget` | Golden-file struct output; regex violations caught; `context --for` returns the right files |
| `03-commit-log.md` | Session log, commit, env, ported skills | `log append/session-end`, `env check`, commit skill (both `commit_mode`s), debug/document/research/learn skills, doctor `env-vars-undocumented` | Full session cycle on fixture: log → commit.md → SHA backfill (agent-commits mode) |
| `04-platform-bridges.md` | Sync + adapters | `PlatformAdapter` impls (omp, claude), `harness sync`, `harness platform add`, context-rules compilation, sync-manifest conflict handling, doctor `shims-stale`, `context-rules-stale` | Byte-stable golden bridges for both platforms; symlinks resolve; re-sync idempotent; user-edit conflict surfaced not clobbered |
| `05-implement-polish.md` | Implementation loop + polish | `implement status/next/verify/done` state machine, implement skill, `polish` + skill, manifest gates | Fixture spec driven task-group by task-group; polish refuses on `importance != high` |
| `06-deps.md` | Dependency source clones | `deps clone/sync/add/remove/list`, registry.md, doctor `stale-dependencies` | Clone pinned tag into `.agent/dependencies/`, registry accurate, drift detected |
| `07-templates.md` | Init templates mechanism | `template save/list/inspect/delete`, `init --template` wiring | Save from `initialized` fixture → re-init a fresh fixture from it, structural questions skipped |
| `08-integration.md` | Wiring + worktree + migration runbook | tasks.md wiring into skills, `worktree`, cascade-check reference, end-to-end smoke test, migration runbook (maprios / vex / this repo, incl. deleting old harness trees + pi-agent-base shrink) | Cold-start-from-state.md e2e; runbook executed on this dotfiles repo |
| `09-commands-guide-discovery.md` | Slash commands, harness guide, init discovery | Command shims in both adapters (`/dev-spec` etc., `/harness-init`), generated `docs/harness-guide.md` (per-project harness organization + knowledge routing), init skill discovery pass (full-codebase practice mining with `applies_to` globs), `context-coverage` doctor check | Shims visible as slash commands; guide written once by finish; discovery closes with index/struct/sync/doctor; coverage check catches a seeded uncovered dir |

Dependencies are strictly linear for 01–08 (each spec may use anything earlier, nothing later).
Spec 09 amends 01/04 surfaces and depends only on them — it may run before or alongside 05–08.

---

## 12. Global Verification

Every phase spec ends with its own verification section, plus these suite-wide gates:

- [ ] `bun test` green in `harness/` after every phase spec (no skipped tests committed)
- [ ] `bunx tsc --noEmit` clean after every phase spec
- [ ] After 04: `harness init` + `harness sync` on a scratch copy of THIS dotfiles repo produces
      working `.omp/` + `.claude/` bridges (manual smoke: open Claude Code, confirm skills visible
      through the symlink; open OMP if bun installed, confirm no double-loaded context)
- [ ] After 08: the migration runbook has been executed on at least one real project (this repo)
      and the old harness trees it replaces are deleted per runbook
- [ ] `harness doctor` exits 0 on the freshly migrated repo

---

## 13. Cross-Spec Reconciliation Ledger

Contracts invented by one phase spec and consumed by another. This table is authoritative when a
phase spec's prose is ambiguous; each row names the owning spec (implement it there).

| Contract | Owner | Consumers | Detail |
|---|---|---|---|
| `spec-tasks.md` format | 02 (`spec new` emits) | 05 (`parseSpecTasks`), 01 (`state` counts boxes) | `## Tn — <title>` headings, `Why:`/`Verify:` first-prefixed lines, `- [ ]` steps; `Verify:` mandatory (value `manual` allowed). 05's contract C-05a restates it — identical by construction. |
| `contextFilesFor(props: { root; task; files? })` | 02 `src/commands/context.ts` | 05 (`implement next`) | Wrapper over `matchContextRules`; [] when rules file absent. |
| `appendLogLine(props: { root; line; dateOpt? })` | 03 `src/commands/log.ts` | 05 (`implement done`) | Single bullet appended to today's entry; creates skeleton when absent. |
| Session-log heading shape | 03 (`ENTRY_TEMPLATE`) | 01 (`state` Recent sessions), 02 (sync-spec skill) | `## YYYY-MM-DD — HH:MM — <slug>`; file header `# Session Log — YYYY-MM-DD`. |
| `env.manifest.md` table | 03 (`parseEnvManifest`) | 01 (init `write-phase 5` MUST emit this shape) | `| VAR | required | description |` markdown table. |
| Preference entry grammar | 02 (D02-3) | 02 sync-spec skill, 01 fixture seeds | `- P-NNN (YYYY-MM-DD) <text> [supersedes P-MMM]`; anti-patterns: `- AP-NNN (YYYY-MM-DD, seen Nx) <text>` with optional indented `pattern: <regex>` line (04 compiles those to TTSR rules). |
| `parseNamingRules`/`checkPath` | 02 `src/lib/namingRules.ts` | 04 (context-rules `when` from rule scopes) | Single parser; 04 must not fork it. |
| `applies_to` frontmatter on standards files | 04 (reads) | 02 (standards templates carry it), init phase 3 stubs | Inline string array of globs; source of domain context-rule `when` globs. |
| `ProjectContext.antiPatternRegexes` | 04 (type delta to 01's `platforms/types.ts`) | 04 omp adapter | Add the field when implementing 04; 01 ships without it. |
| Progress-file `template: <name>` frontmatter | 07 (writes at scaffold) | 01 (`initWritePhase` phase 7 sets `manifest.harness.template` from it) | Small documented delta to 01's phase-7 writer; implement when building 07. |
| git clone helpers throw | 06 (`lsRemoteTags`, `shallowCloneAtRef`) | 06 only | Documented deviation from 01's safe-default git wrappers: clone failures are actionable, so they throw `HarnessError` (`git-ls-remote-failed`, `git-clone-failed`). |
| `.agent/docs/research/` | 03 (research/learn skills create on first use) | 02 `struct` (tolerate), 04 sync (ignore) | Additive to §6 layout; module-gated by `modules.research`. |
| Command shims + `/harness-init` rename | 09 (adapters emit `.claude/commands/`, `.omp/prompts/`) | 04 sync tests (file counts/goldens updated by 09 Step 1) | One shim per described skill; only the init shim is renamed, only on Claude. |
| `docs/harness-guide.md` | 09 (`init finish` writes once, never overwrites) | init skill, sync-spec skill, all harness-editing agents | The per-project "how this harness is organized + where knowledge goes" doc. Additive to §6 layout. |
| `commit/references/commit-checklist.md` | 09 (default template; init's commit-gate step rewrites per project) | commit skill (runs every item, blocks on failures, waivers logged) | The sanctioned per-project customization point for the commit gate — reference file, not a manifest field. |
| tasks.md sections | 08 (`tasksFile.ts`: ids `in-progress|inbox|done`, `SECTION_HEADINGS`) | 01 (scaffold writes the matching `## In Progress / ## Inbox / ## Recently Done` skeleton), 02/03/05 skill edits | Headings are the contract; 08's parser is tolerant of extra content between sections. |
| `shared-references/cascade-checks.md` | 08 (authors it) | 01 (scaffold copies `.agent/skills/shared-references/` — small documented delta, implement when building 08), 02 dev-spec/sync-spec pointers | Non-skill shared reference location. |
| Error-code registry additions | 02/03/05/06/07/08 | all | `module-disabled`, `spec-exists`, `spec-tasks-invalid`, `no-log-entry`, `no-pending-commit`, `bad-date`, `polish-disabled`, `dep-unknown`, `dep-exists`, `dep-version-unknown`, `git-ls-remote-failed`, `git-clone-failed`, `template-not-found`, `template-invalid`, `template-exists`, `template-name-invalid`, `init-incomplete`, `not-initialized`, `no-project`, `usage`, `manifest-invalid`, `task-not-found`, `task-ambiguous`, `not-worktree-repo`, `worktree-path-exists`, `branch-exists`, `git-failed`. Codes are stable API — tests assert them. |
