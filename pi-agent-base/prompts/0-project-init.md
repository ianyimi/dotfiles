---
description: Bootstrap the Pi agent harness for any project. Language-agnostic. Detects stack from manifest files, scaffolds .pi/agent-docs/, generates customized core prompts (1-dev-spec, 2-sync-spec, 3-commit), and configures debug hierarchy. Re-runnable — merges improvements, asks before overwriting conflicts.
---

# Pi Project Setup

Bootstrap the Pi agent harness for this project. Run from the project root.

This prompt works for any language and any project type. It detects the stack, asks targeted questions, and produces a fully customized harness in `.pi/`.

> **Questions:** Use the `ask_user_question` tool for every question in this prompt. Never write question lists as plain text.

---

## Setup Protocol

**Write files immediately.** Do not accumulate answers and write everything at the end. After completing each phase, write the output file for that phase before moving to the next one. This ensures progress survives context compaction.

**Progress file.** Maintain `.pi/.setup-progress.md` throughout the run. Create it at the start of Phase 1. Update it after every phase completes. Delete it when `finish_setup` is called at the end.

Progress file format:
```markdown
# Setup Progress
Started: <ISO timestamp>
Project: <name once known>

## Phases
- [ ] Phase 1 — Project Identity
- [ ] Phase 2 — Tech Stack + Library Map
- [ ] Phase 3 — Dev Processes + Environment
- [ ] Phase 4 — Mission + Roadmap
- [ ] Phase 5 — Workflow Tier
- [ ] Phase 6 — Prompt Customization
- [ ] Phase 7 — Debug Hierarchy
- [ ] Phase 8 — Standards Initialization
- [ ] Phase 9 — Custom Prompt Suggestions
- [ ] Phase 10 — AGENTS.md Assembly

## Collected Data
<key findings from completed phases — language, stack, workflow tier, etc.>
```

**Resuming after compaction.** If `.pi/.setup-progress.md` already exists when this prompt starts:
1. Read it to find the last completed phase and all collected data
2. Announce: "Resuming setup from Phase <N>. Phases 1–<N-1> already complete."
3. Skip completed phases entirely — do not re-ask questions for them
4. Continue from the first unchecked phase

**Phase output map** — what to write and when:

| Phase | Write immediately after completing |
|-------|------------------------------------|
| 1 | Create `.pi/.setup-progress.md` |
| 2 | `.pi/agent-docs/product/tech-stack.md` |
| 3 | `.pi/agent-docs/product/dev-processes.md` |
| 4 | `.pi/agent-docs/product/mission.md`, `.pi/agent-docs/product/roadmap.md` |
| 5 | Append workflow tier section to `tech-stack.md` |
| 6a | `.pi/prompts/1-dev-spec.md` |
| 6b | `.pi/prompts/2-sync-spec.md` |
| 6c | `.pi/prompts/3-commit.md` |
| 6d | `.pi/prompts/document.md` (if applicable) |
| 6e | `.pi/prompts/debug.md`, `learn.md`, `research.md` (only if project-specific customization needed) |
| 6f | `.pi/prompts/implement-spec.md` (if applicable) |
| 7 | `.pi/agent-docs/standards/debug-hierarchy.md` |
| 8 | `.pi/agent-docs/standards/developer-preferences.md`, first ideaLog |
| 9 | Append suggestions to `.pi/.setup-progress.md` |
| 10 | `.pi/AGENTS.md`, then call `finish_setup` (deletes progress file) |

After each write, tick the corresponding checkbox in `.pi/.setup-progress.md` and append any key data collected to the Collected Data section.

---

## Phase 1 — Project Identity

Scan the project root for manifest files to determine language, ecosystem, and repo structure.

### Manifest detection table

| File | Stack |
|------|-------|
| `turbo.json` | Turborepo monorepo |
| `pnpm-workspace.yaml` | pnpm workspace (monorepo) |
| `package.json` | Node.js / TypeScript / JavaScript |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pyproject.toml` | Python (modern) |
| `setup.py` / `requirements.txt` | Python (legacy) |
| `Gemfile` | Ruby |
| `pom.xml` | Java (Maven) |
| `build.gradle` / `build.gradle.kts` | Java/Kotlin (Gradle) |
| `Package.swift` | Swift |
| `mix.exs` | Elixir |
| `composer.json` | PHP |
| `pubspec.yaml` | Dart / Flutter |
| `stack.yaml` / `*.cabal` | Haskell |
| `CMakeLists.txt` | C/C++ (CMake) |
| `Makefile` | C/C++ or generic build |
| `.sln` / `*.csproj` | .NET / C# |

### Monorepo detection

Check for monorepo signals in this order:
1. `turbo.json` present → Turborepo monorepo
2. `pnpm-workspace.yaml` present → pnpm workspace
3. `lerna.json` present → Lerna monorepo
4. `nx.json` present → Nx monorepo
5. `packages/` or `apps/` directory with multiple sub-manifests → generic monorepo

For Turborepo + pnpm (most common):
- Read `pnpm-workspace.yaml` to enumerate workspace packages
- Read `turbo.json` to enumerate pipeline tasks (dev, build, test, lint)
- Note each app/package in `apps/` and `packages/` directories

### Announce findings

After scanning, announce:
```
Detected: <language(s)>
Ecosystem: <runtime/framework>
Repo type: <single-package | monorepo (Turborepo+pnpm | pnpm workspace | Lerna | Nx | generic)>
Manifest: <primary manifest file>
```

If no manifest found, ask:
> What language and build system does this project use?

---

## Phase 2 — Tech Stack + Library Map

Read the primary manifest(s) to extract dependencies. Goal: build a library map the agent can reference when writing specs.

### For Node.js / TypeScript projects (package.json):
- Separate `dependencies` from `devDependencies`
- Identify: framework (React, Next.js, Vue, Express, Fastify, etc.), ORM/DB client, test runner, bundler, CSS solution

### For Turborepo + pnpm monorepos:
- Read root `package.json` for workspace-level tooling
- Read each `apps/*/package.json` and `packages/*/package.json`
- Build a per-package dependency map
- Identify shared packages that multiple apps depend on

### For Rust (Cargo.toml):
- List `[dependencies]` and `[dev-dependencies]`
- Identify: async runtime (tokio, async-std), web framework (axum, actix, warp), serialization (serde), DB client

### For Go (go.mod):
- List `require` directives
- Identify: web framework (gin, echo, fiber, chi), DB driver, test helpers

### For Python (pyproject.toml / requirements.txt):
- Identify: web framework (FastAPI, Django, Flask), ORM, test runner (pytest)

### For other languages:
- Extract library names from the relevant manifest section
- Group by purpose: web, data, testing, dev tooling

### Output

Generate `.pi/agent-docs/product/tech-stack.md`:

```markdown
# Tech Stack

## Language + Runtime
- Language: <language>
- Runtime/Version: <version if detectable>

## Repo Structure
- Type: <single | monorepo>
- Monorepo tool: <Turborepo | pnpm workspace | none>
<if monorepo>
### Packages
| Name | Path | Purpose |
|------|------|---------|
| app  | apps/app | ... |
| ... | ... | ... |
</if>

## Core Libraries
| Library | Purpose |
|---------|---------|
| <name> | <inferred purpose> |

## Dev Tooling
| Tool | Purpose |
|------|---------|
| <name> | <purpose> |
```

---

## Phase 3 — Dev Processes + Environment

Goal: understand how the developer runs, tests, and debugs the project. Agent will reference this when writing specs and during debugging.

### Auto-detect dev commands

#### Turborepo projects:
- Check `turbo.json` pipeline for: `dev`, `build`, `test`, `lint`, `typecheck`
- Common pattern: `pnpm dev` (runs turbo dev across all apps)
- Per-app: `pnpm --filter <app-name> dev`

#### Other Node.js projects:
- Read `scripts` in `package.json`

#### Rust:
- `cargo run`, `cargo test`, `cargo build --release`

#### Go:
- `go run .`, `go test ./...`, `go build`

#### Python:
- Look for `Makefile`, `justfile`, or `pyproject.toml [tool.taskipy]` / `[tool.scripts]`

#### Generic:
- Check `Makefile` targets: `make dev`, `make test`, `make build`
- Check `justfile` recipes

### Ask the developer

After auto-detecting, present findings and ask to confirm or correct:

> I detected these dev commands. Confirm or correct each one:
> - Dev server: `<detected command>`
> - Test runner: `<detected command or "none detected">`
> - Build: `<detected command>`
> - Lint/typecheck: `<detected command>`

If no test files or test runner were detected, explicitly ask:

> I didn't find a test runner or test files. Does this project have tests, or is testing out of scope?
> A) No tests — this project doesn't use automated testing
> B) Tests exist but weren't detected — tell me the command
> C) Tests are planned but not set up yet

Record the answer. If "no tests", add a `## Testing` section to `dev-processes.md` noting this explicitly so the agent never suggests running tests or adds test-related verify commands.

Then ask:

> Where do errors appear when things break? (e.g., terminal output, log files at a specific path, browser devtools console). List the main error surfaces for this project.

> Are there any background processes or services that must be running for the dev server to work? (e.g., database, Redis, separate API server). If yes, list the start command and process name for each.

### Phase 3b — Verification Loop

Configure how the agent verifies that changes are working. This gives the agent real feedback during bug fixing and implementation — not just reading logs but actually seeing/testing the running system.

Ask:

> How should the agent verify that changes are working correctly? Select all that apply.
>
> A) Web browser — navigate to UI, check pages visually (uses Playwright)
> B) API/HTTP — make requests, check response bodies and status codes
> C) CLI output — run the program, check stdout/exit code
> D) Terminal/server logs only — read dev server output for errors
> E) Manual only — I'll verify myself, agent doesn't need to check

**If web browser (A) selected:**

Ask:
> What URL does the dev server run on? (e.g. http://localhost:3000)

Note: Pi has a built-in `browse` tool (Arc + AppleScript + screencapture). No MCP needed. The agent navigates to any URL and returns a screenshot, reusing an existing tab at the same origin so Arc stays clean. Just keep a localhost tab pinned in Arc.

**If API/HTTP (B) selected:**

Ask:
> What is the API base URL? List 2–3 key endpoints to verify after changes (path + expected status).

**If CLI (C) selected:**

Ask:
> What command runs the program? What does successful output look like?

Generate `.pi/agent-docs/standards/verification.md`:

```markdown
# Verification Loop

How the agent checks that changes are working correctly.

## Method
<browser | api | cli | logs | manual>

<if browser>
## Browser
- Dev URL: <url>
- Tool: Playwright via MCP (pi-mcp-adapter + @playwright/mcp)
- After each change: navigate to the affected route, take screenshot, check console for errors
- Check tmux pane 1 for server-side errors simultaneously
</if>

<if api>
## API
- Base URL: <url>
- Key endpoints to verify:
  | Endpoint | Method | Expected |
  |----------|--------|---------|
  | <path> | GET | 200 |
</if>

<if cli>
## CLI
- Command: `<run command>`
- Success indicator: `<expected output or exit code 0>`
</if>

## Dev Server
- Check tmux pane 1 for errors after every change
- Known error patterns for this project: <fill in as discovered>
```

This file is read by `/debug` and `/implement-spec` so the agent always knows how to verify changes.

---

### Output

Generate `.pi/agent-docs/product/dev-processes.md`:

```markdown
# Dev Processes

## Dev Commands
| Command | What it does |
|---------|-------------|
| `<cmd>` | Start dev server |
| `<cmd>` | Run tests |
| `<cmd>` | Build for production |
| `<cmd>` | Lint + typecheck |

<if monorepo>
## Per-App Commands
| App | Dev | Test |
|-----|-----|------|
| <app> | `pnpm --filter <app> dev` | `pnpm --filter <app> test` |
</if>

## Testing
- Status: <active | none — out of scope | planned but not set up>
- Runner: `<command>` (or "N/A")

## Error Surfaces (Debug Hierarchy)
1. <primary — e.g., terminal output>
2. <secondary — e.g., log file at path>
3. <tertiary — e.g., browser console>

## Background Services
| Service | Start command | Port |
|---------|--------------|------|
| <name> | `<cmd>` | <port> |
```

---

## Phase 4 — Mission + Roadmap

Ask the developer about the project's purpose.

> In 1–3 sentences: what does this project do and who is it for?

> What is the current development focus? (What are you actively building right now?)

> Are there any known constraints, non-goals, or things the agent should never touch?

Generate `.pi/agent-docs/product/mission.md`:

```markdown
# Mission

<mission statement>

## Current Focus
<current development focus>

## Constraints + Non-Goals
- <constraint>
```

Generate `.pi/agent-docs/product/roadmap.md` as a stub:

```markdown
# Roadmap

_Updated by the developer. Agent reads this for context when writing specs._

## Now
-

## Next
-

## Later
-
```

---

## Phase 5 — Workflow Tier

Determine whether this is a high-care or low-care project.

Ask:

> How should the agent operate on this project?
>
> A) **High-care**: I implement all code manually. Agent writes specs, reviews, and points out issues only. Never writes core logic unilaterally.
> B) **Low-care**: Agent can implement fully. Used for scripts, tools, throwaway prototypes.

If the project has a proper product mission (detected in Phase 4) and has substantial dependencies, suggest high-care as the default.

Record the tier in `.pi/agent-docs/product/tech-stack.md` under a `## Workflow Tier` section:

```markdown
## Workflow Tier
- Tier: <high-care | low-care>
- Rule: <"Developer implements. Agent writes specs and reviews." | "Agent can implement fully.">
```

---

## Phase 6 — Prompt Customization

Walk through each prompt and generate a project-local version in `.pi/prompts/`. Announce the current prompt at the start of each sub-phase. For each: read the template from `~/.pi/agent/templates/<name>/SKILL.md` or `~/.pi/agent/prompts/<name>.md`, inject project-specific tokens, ask any clarifying questions, then write `.pi/prompts/<name>.md`.

Tokens shared across all prompts:
- `{{PROJECT_NAME}}` — from Phase 4
- `{{LANGUAGE}}` — from Phase 1

---

### 6a — 1-dev-spec

Read `~/.pi/agent/templates/1-dev-spec/SKILL.md` and inject:

| Token | Value |
|-------|-------|
| `{{TECH_STACK_SUMMARY}}` | Language, framework, key libraries (Phase 2) |
| `{{WORKFLOW_TIER_RULE}}` | One-sentence rule from Phase 5 |
| `{{WORKFLOW_TIER_DETAIL}}` | Full behavior: what agent does vs what developer does |
| `{{DEV_COMMANDS}}` | Commands table from Phase 3 |
| `{{MONOREPO_PACKAGES}}` | Package table if monorepo, empty string if not |

Key customizations:
- Turborepo + pnpm: reference `pnpm --filter <app>` pattern in spec instructions
- High-care: include explicit "Developer implements — agent does not write core logic" rule
- Tech stack pre-populated so agent never guesses libraries

Write to `.pi/prompts/1-dev-spec.md`.

---

### 6b — 2-sync-spec

Read `~/.pi/agent/templates/2-sync-spec/SKILL.md` and inject:

| Token | Value |
|-------|-------|
| `{{PATTERN_CATEGORIES}}` | Language-appropriate pattern types (see table below) |
| `{{UPKEEP_TASKS}}` | Configured list of tasks to run after pattern extraction |

**Pattern categories by language:**

| Language | Pattern categories |
|----------|-----------------|
| TypeScript | Naming, file organization, type patterns, error handling, library usage, React/component patterns |
| Python | Naming (PEP 8 deviations), typing style, class structure, exception patterns, import organization |
| Rust | Error type conventions, trait impl patterns, lifetime rules, module structure |
| Go | Interface naming, error wrapping, package organization, goroutine patterns |
| Other | Naming, file organization, error handling, library usage |

**Configuring upkeep tasks:**

Ask:
> After implementing a feature, what should sync-spec run automatically? Select all that apply:
> - Update developer-preferences.md + prompts (always included)
> - Run typecheck / build verification
> - Run test suite
> - Update roadmap (mark completed features)
> - Update docs for changed files (runs `document` on uncommitted changes)
> - Close completed spec files
> - Custom task (describe it)

For each selected task, record as:
```
- task: <name>
  run: <shell command | "agent:document" | "agent:close-specs">
  condition: <always | only if tests exist | only if document prompt active>
```

Initialize `{{UPKEEP_TASKS}}` as the ordered list. If the developer selects nothing beyond the default, initialize with a stub placeholder.

Write to `.pi/prompts/2-sync-spec.md`.

---

### 6c — 3-commit

Read `~/.pi/agent/templates/3-commit/SKILL.md`. The commit prompt auto-detects monorepo markers at runtime. No token injection needed.

Ask:
> Are there any commit message conventions specific to this project? (e.g., required scope format, types you always use, body rules)

Initialize `<!-- sync-spec:commit-conventions -->` with the stated conventions, or with a stub if none.

Write to `.pi/prompts/3-commit.md`.

---

### 6d — document

Ask:
> Does this project need a `document` prompt? (Skip for scripts, CLIs, or projects with no public API surface.)

If yes, read `~/.pi/agent/prompts/document.md` and inject:

| Token | Value |
|-------|-------|
| `{{DOC_FORMAT}}` | Doc format for the language (JSDoc, docstrings, rustdoc, godoc, YARD, Javadoc, DocC, PHPDoc, XML doc) |
| `{{CHECK_COMMANDS}}` | Verify commands after editing |
| `{{DOC_FORMAT_INSTRUCTIONS}}` | Syntax reference block for the format |
| `{{TYPE_CONVENTIONS}}` | Detected or asked type documentation rules |
| `{{DOC_CONVENTIONS}}` | Initialize as stub — sync-spec populates over time |

**Check commands by stack:**

| Stack | Commands |
|-------|----------|
| TypeScript (pnpm) | `pnpm typecheck && pnpm test` |
| TypeScript (Turborepo) | `pnpm --filter <app> typecheck && pnpm --filter <app> test` |
| Rust | `cargo check && cargo test` |
| Go | `go vet ./... && go test ./...` |
| Python | `mypy . && pytest` |
| Ruby | `bundle exec rubocop && bundle exec rspec` |
| Other | ask the developer |

**Type conventions:** scan the codebase for patterns (Input vs resolved, React props, Pydantic models, Rust structs), then ask:
> Are there specific type patterns I should document differently?

Write to `.pi/prompts/document.md`.

---

### 6e — Conditional utility prompt overrides

The following prompts are served from base (`~/.pi/agent/prompts/`) by default. Only create a project-local override when the setup answers reveal something genuinely project-specific. Never copy unchanged.

#### debug

Base `debug` reads `debug-hierarchy.md` and `tech-stack.md` at runtime — debug behavior is configured through those files (Phase 7), not the prompt itself.

Create `.pi/prompts/debug.md` **only if** the project has a non-standard debug workflow that can't be expressed in `debug-hierarchy.md` alone — e.g., requires specific CLI tools, a custom log-parsing command, or a multi-service trace that needs step-by-step instructions baked in.

If creating: read `~/.pi/agent/prompts/debug.md`, add a `## Project-Specific Debug Steps` section with the custom workflow, write to `.pi/prompts/debug.md`.

#### learn + research

Create project-local versions **only if** the project has internal documentation sources the agent should always consult first — e.g., internal wiki, Confluence space, Notion docs, private package registry docs.

Ask:
> Does this project have internal documentation sources (wiki, Notion, internal API docs) that should be checked first during research or learning? If yes, name them and provide the URL or path.

If yes: read the base prompt, prepend a `## Project Sources` section listing those resources with instructions to consult them before external sources, write to `.pi/prompts/learn.md` and/or `.pi/prompts/research.md`.

If no: skip both — base handles it.

#### build-prompt

Base version writes to `.pi/prompts/<name>.md` which is already correct for any project. Only create a project-local override if the project uses a non-standard prompt directory or has a specific skill template format. This is rare — skip unless the developer requests it.

---

### 6f — implement-spec (optional)

Ask:
> Do you want an `implement-spec` prompt? This lets the agent execute approved specs step by step.
> It's optional — most high-care projects only use `dev-spec` + `sync-spec` and implement manually.
> A) Yes — set it up
> B) No — skip it

If yes, read `~/.pi/agent/templates/implement-spec/SKILL.md` and inject:

| Token | Value |
|-------|-------|
| `{{PROJECT_NAME}}` | From Phase 4 |
| `{{WORKFLOW_TIER_RULE}}` | One-sentence rule from Phase 5 |
| `{{WORKFLOW_TIER_DETAIL}}` | Full tier behavior for this project |
| `{{VERIFY_COMMANDS}}` | Same commands as `document` prompt's check commands — build + test |
| `{{VERIFY_COMMANDS_SHORT}}` | Short inline version e.g. `pnpm build && pnpm test` |

**Workflow tier behavior to inject for `{{WORKFLOW_TIER_DETAIL}}`:**

- **High-care**: Agent implements code from `shape.md` stubs and numbered comments. Pauses before any decision not covered by the spec. Developer reviews each completed task before the agent continues.
- **Low-care**: Agent implements fully and independently. Reports progress but does not pause for review between tasks.

Write to `.pi/prompts/implement-spec.md`.

---


## Phase 7 — Debug Hierarchy Configuration

Configure the agent's bug-finding order for this specific project.

Ask:

> When debugging, what order should the agent check these sources? (Drag to reorder, or just number them.)
>
> Default order:
> 1. Terminal/process error output
> 2. Uncommitted changes (git diff)
> 3. ideaLog (recent decision log)
> 4. Error log files
> 5. Test output
> 6. Browser/client console (if applicable)

Then ask:

> Are there specific libraries or tools where bugs are commonly found? (e.g., ORM query errors, auth middleware, a specific package that's fragile). List them and what signs to look for.

Generate `.pi/agent-docs/standards/debug-hierarchy.md`:

```markdown
# Debug Hierarchy

When a bug is reported or found, check in this order:

1. <source 1> — <why / what to look for>
2. <source 2> — <why / what to look for>
3. <source 3> — <why / what to look for>
...

## Known Fragile Areas
| Area | Signs of trouble | Notes |
|------|-----------------|-------|
| <library/module> | <symptoms> | <notes> |
```

---

## Phase 8 — Standards Initialization

Create the developer preferences audit trail.

Generate `.pi/agent-docs/standards/developer-preferences.md`:

```markdown
# Developer Preferences

_Maintained by sync-spec. Each entry is a pattern extracted from developer deviations._

_Format: pattern → reason → date added_

<!-- sync-spec appends entries here as it learns -->
```

Create the first ideaLog entry.

Generate `.pi/agent-docs/implementation-log/<YYYY>/<MM>/<YYYY-MM-DD>.ideaLog.md`:

```markdown
# IdeaLog — <date>

## Harness Setup

- Initialized Pi agent harness via 0-project-init
- Stack: <detected stack>
- Repo type: <single | monorepo>
- Workflow tier: <high-care | low-care>
- Core prompts scaffolded: 1-dev-spec, 2-sync-spec, 3-commit (+ document/implement-spec if applicable)

## Decisions Made During Setup
<summarize any non-obvious choices made during setup, especially answers to Phase 4–7 questions>
```

---

## Phase 9 — Custom Prompt + Package Suggestions

After the harness is scaffolded, scan the codebase for patterns that suggest useful additions.

### Custom prompt signals

| Signal | Suggested prompt |
|--------|----------------|
| `migrations/` or ORM usage | `db-migrate` — run and verify migrations safely |
| `__tests__/` or test files exist | `run-tests` — run tests for a specific module |
| Multiple API route files | `add-endpoint` — scaffold a new route with type safety |
| `.env.example` or secrets management | `env-check` — verify required env vars are set |
| Docker / docker-compose | `docker-dev` — start/stop dev services |
| CI config (`.github/workflows/`) | `check-ci` — replicate CI checks locally before push |
| Turborepo monorepo | `add-package` — scaffold a new workspace package |
| OpenAPI / GraphQL schema | `sync-schema` — regenerate types from schema |

### Pi package signals

Pi packages can be installed globally (`pi install npm:<pkg>`) or project-only (`pi install -l npm:<pkg>`).

| Signal | Package / Tool | Scope | Reason |
|--------|---------------|-------|--------|
| Any project | `rtk` (brew) | global | Compresses git/ls/grep output 60-90% before it hits context — install with `brew install rtk && rtk init -g` |
| Any project | `pi-powerline-footer` | global | Powerline status bar in Pi terminal |
| Spec-driven workflow active | `@plannotator/pi-extension` | global | Visual plan annotation and review |
| Using GitHub for specs/issues | `@the-agency/pi-spec-kit` | global | GitHub Spec Kit integration for spec-driven dev |
| Security-sensitive or production code | `safe-coder` | project-local | Safety guardrails — prevent risky operations |

### Announce suggestions

After scanning, present both:

> **Custom prompts to build** (use `/build-prompt`):
> - `<prompt-name>` — <one-line reason>
>
> **Pi packages to install**:
> - `pi install npm:<package>` — <one-line reason> [global | project-only]

Do not install packages automatically. List the commands so the developer can run them.

---

## Phase 10 — First AGENTS.md Assembly

Generate `.pi/AGENTS.md` — the primary context file the agent reads at the start of every session.

```markdown
# <Project Name> — Agent Context

## Mission
→ see .pi/agent-docs/product/mission.md

## Tech Stack
→ see .pi/agent-docs/product/tech-stack.md

## Dev Commands
<inline the dev commands table from Phase 3 — keep short>

## Workflow Tier
<high-care or low-care rule — one sentence>

## Debug Hierarchy
→ see .pi/agent-docs/standards/debug-hierarchy.md

## Active Specs
→ see .pi/agent-docs/specs/

## IdeaLog (recent)
→ see .pi/agent-docs/implementation-log/

## Prompts Available
| Prompt | Invoke | Purpose |
|--------|--------|---------|
| 1-dev-spec | `/dev-spec` | Write implementation specs |
| 2-sync-spec | `/sync-spec` | Extract patterns → update dev-spec |
| 3-commit | `/commit` | Stage and commit with structured message |
| build-prompt | `/build-prompt` | Create a new project-specific prompt |
| debug | `/debug` | Systematic bug investigation |
```

---

## Specialized Init Templates

For project types you set up repeatedly (pnpm monorepo, create-z3-app, etc.), create a specialized variant at `~/.pi/agent/prompts/0-project-init-<type>.md`. Specialized templates:

- Skip Phase 1–2 detection (stack is already known for this template type)
- Pre-fill common answers (verify commands, scope format, workflow tier, etc.)
- Only ask for project-specific details: name, mission, dev URL, team conventions
- Run the same Phase 6–10 output steps as the base init

**Template structure:**

```markdown
---
description: Pi harness setup for <type> projects. Pre-configured for <stack>.
---

# Pi Setup — <Type> Project

This is a specialized init for <type> projects. Stack and tooling are pre-configured.
Only project-specific details are asked.

## Pre-configured settings
- Language: <language>
- Stack: <framework, libs>
- Verify commands: `<commands>`
- Workflow tier default: <high-care | low-care>
- Scope format: <monorepo app name | module name>

## Questions to ask
1. Project name and mission (Phase 4)
2. Dev server URL (Phase 3b, if web)
3. Workflow tier — confirm default or override (Phase 5)
4. Commit conventions specific to this project (Phase 6c)
5. implement-spec? (Phase 6f)

## Then run phases
6, 7, 8, 9, 10 from the base 0-project-init, using the pre-configured values above.
```

Invoke with `/0-project-init-pnpm-monorepo`, `/0-project-init-z3-app`, etc.

---

## Re-run Behavior

When run on a project that already has `.pi/` set up:

1. Announce which sections already exist
2. For each section, ask: **merge silently** (non-conflicting improvements) or **ask before overwriting** (if conflicts detected)
3. Never overwrite `developer-preferences.md` — append only
4. Never overwrite ideaLog entries — create a new entry for the re-run
5. Regenerate `AGENTS.md` to reflect any changes

---

## Final Output Summary

After all phases complete, call the `finish_setup` tool with:
- `summary`: one paragraph describing what was set up (stack detected, workflow tier, monorepo or single package)
- `prompts_created`: list of prompt names written to `.pi/prompts/`
- `next_steps`: suggested actions for the developer

Suggested next steps to include:
- Review `.pi/AGENTS.md` — this is what the agent reads every session
- Fill in `.pi/agent-docs/product/roadmap.md`
- Run `/build-prompt` to create any of the suggested custom prompts
- Run `/dev-spec` to write your first spec

The `finish_setup` tool will notify the user and automatically reload Pi so the
project-local `.pi/` config is active in the current session — no manual `/reload` needed.
