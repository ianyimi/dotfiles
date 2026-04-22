# Pi Agent: Complete Build & Workflow Guide

> Reference for combining **Pi** (badlogic/pi-mono) + your personal skills into a unified coding agent harness that works across any project and any language.

---

## Table of Contents

1. [What Pi Is](#1-what-pi-is)
2. [Pi Architecture — The Pieces](#2-pi-architecture--the-pieces)
3. [Installation & Quick Start](#3-installation--quick-start)
4. [Context Files (AGENTS.md / CLAUDE.md)](#4-context-files-agentsmd--claudemd)
5. [Skills — How They Work](#5-skills--how-they-work)
6. [Extensions — TypeScript Power Tools](#6-extensions--typescript-power-tools)
7. [Prompt Templates](#7-prompt-templates)
8. [Pi Packages — Bundling Everything](#8-pi-packages--bundling-everything)
9. [Sessions, Branching & Compaction](#9-sessions-branching--compaction)
10. [Programmatic SDK & RPC Mode](#10-programmatic-sdk--rpc-mode)
11. [Complete Skill Set — Flat Structure](#11-complete-skill-set--flat-structure)
12. [The Three Core Workflow Commands](#12-the-three-core-workflow-commands)
13. [The Continuous Improvement Loop](#13-the-continuous-improvement-loop)
14. [The `pi-project-setup` Command](#14-the-pi-project-setup-command)
15. [The `sync-harness` Command](#15-the-sync-harness-command)
16. [The `build-skill` Command](#16-the-build-skill-command)
17. [Debug Hierarchy](#17-debug-hierarchy)
18. [The `ask_user_question` Extension](#18-the-ask_user_question-extension)
19. [Workflow Improvements](#19-workflow-improvements)
20. [Community Resources](#20-community-resources)
21. [Doc Map — Where to Find Everything](#21-doc-map--where-to-find-everything)

---

## 1. What Pi Is

Pi (`@mariozechner/pi-coding-agent`) is a **minimal terminal coding harness** built to be extended. It is a direct Claude Code alternative that intentionally skips plan mode, sub-agents, MCP, and permission popups at the core level, letting you build exactly what you want via TypeScript extensions, skills, and prompt templates.

**Key philosophy differences from Claude Code:**

| Feature | Claude Code | Pi |
|---------|------------|-----|
| Skills | Via slash commands | Via SKILL.md files (Agent Skills standard) |
| Extensions | Hooks in settings.json | TypeScript modules with full TUI access |
| Sub-agents | Built-in | Build your own with extensions or tmux |
| Plan mode | Built-in | Build your own, or install a package |
| MCP | Yes | No (build via extension if needed) |
| Context files | CLAUDE.md | AGENTS.md (also reads CLAUDE.md) |
| Screenshot input | Ctrl+V paste | Ctrl+V paste + `@file` reference + RPC `images` field |
| Session tree | Linear | Branching tree (`/tree`) |
| `AskUserQuestion` | Built-in tool | Custom extension (see §18) |

**Core philosophy for this harness:** The developer is always the source of truth. The agent generates specs, writes boilerplate, points out flaws, and maintains project records. For important projects (user-facing, production code), the developer writes all core logic. The agent never unilaterally writes important code.

---

## 2. Pi Architecture — The Pieces

```
@mariozechner/pi-coding-agent    ← The CLI you run ("pi")
@mariozechner/pi-agent-core      ← Agent runtime, tool calling, state
@mariozechner/pi-ai              ← Unified LLM API (all providers)
@mariozechner/pi-tui             ← Terminal UI with differential rendering
@mariozechner/pi-web-ui          ← Web components for chat UIs
@mariozechner/pi-mom             ← Slack bot → delegates to coding agent
@mariozechner/pi-pods            ← CLI for managing vLLM GPU pods
```

### Config loading order (global → project)

Pi loads config in layers. Global loads first; project-local overrides or appends. **The setup command only ever writes to the project `.pi/` folder — it never touches the global config.**

```
~/.pi/agent/                     ← GLOBAL config (loaded first, every session)
├── settings.json                ← Global settings (model, thinking, etc.)
├── AGENTS.md                    ← Global context (prepended to all sessions)
├── SYSTEM.md                    ← Replaces default system prompt globally
├── keybindings.json             ← Custom key remapping
├── extensions/                  ← Global TypeScript extensions
│   ├── ask-user-question.ts     ← Recreates AskUserQuestion tool (see §18)
│   └── project-tools.ts         ← Tmux + session-start hooks
├── skills/                      ← Global skills (available in every project)
│   ├── pi-project-setup/
│   ├── sync-harness/
│   ├── implement-spec/
│   ├── debug/
│   ├── research/
│   ├── learn/
│   └── build-skill/
├── prompts/                     ← Global prompt templates
├── themes/                      ← Theme .json files
└── sessions/                    ← Auto-saved session JSONL files

project-root/
└── .pi/                         ← PROJECT-LOCAL config (loaded after global, overrides/appends)
    ├── settings.json            ← Project settings overrides
    ├── AGENTS.md                ← Project context (appended after global AGENTS.md)
    ├── skills/                  ← Project-local skills (override global by name)
    │   ├── 1-dev-spec/SKILL.md  ← Evolves as patterns are learned
    │   ├── 2-sync-spec/SKILL.md
    │   ├── 3-commit/SKILL.md
    │   ├── build-skill/SKILL.md ← Project-aware skill builder
    │   ├── review/SKILL.md      ← (optional)
    │   ├── document/SKILL.md    ← (optional)
    │   └── feature-checklist/SKILL.md ← (optional)
    └── agent-docs/              ← All agent documentation for this project
        ├── product/             ← Project planning docs
        │   ├── mission.md
        │   ├── roadmap.md       ← Updated by sync-spec
        │   └── tech-stack.md
        ├── specs/               ← dev-spec output
        ├── implementation-log/  ← sync-spec and commit output
        │   └── YYYY/MM/
        │       ├── YYYY-MM-DD.ideaLog.md
        │       └── YYYY-MM-DD.commit.md
        ├── research/            ← debug, research, learn output
        │   ├── bugs/
        │   ├── tools/
        │   └── docs/
        └── standards/
            └── developer-preferences.md  ← Evolves via sync-spec
```

**"agent-docs"** = the `.pi/agent-docs/` folder and its contents. Used interchangeably to mean both the folder and the agent harness settings for that project. When referring to agent-docs in conversation, the agent should understand this refers to `.pi/agent-docs/`.

Pi also reads `.agents/skills/` walking up the directory tree, so skills can live at any ancestor directory.

---

## 3. Installation & Quick Start

```bash
npm install -g @mariozechner/pi-coding-agent

# Auth with API key
export ANTHROPIC_API_KEY=sk-ant-...
pi

# Or use your existing Claude subscription
pi
/login   # then select provider

# Continue last session
pi -c

# One-shot non-interactive
pi -p "Summarize this codebase"
cat README.md | pi -p "What does this do?"

# Pass files directly
pi @prompt.md "Answer this"
pi -p @screenshot.png "What's in this image?"
```

**Available built-in tools (all on by default):** `read`, `bash`, `edit`, `write`, `grep`, `find`, `ls`

**Key interactive commands:**

| Command | Description |
|---------|-------------|
| `/model` or `Ctrl+L` | Switch model |
| `/tree` or `Escape×2` | Navigate session branches |
| `/compact` | Manually compact context |
| `/fork` | Create a new session branch |
| `/resume` or `pi -r` | Browse past sessions |
| `/reload` | Hot-reload extensions, skills, prompts |
| `/skill:name` | Force-invoke a skill |
| `Shift+Tab` | Cycle thinking level |
| `@filename` | Fuzzy-search project files in the editor |
| `!command` | Run bash command and send output to LLM |
| `!!command` | Run bash without sending to LLM |

---

## 4. Context Files (AGENTS.md / CLAUDE.md)

Pi loads context in this order (all concatenated):
1. `~/.pi/agent/AGENTS.md` — global instructions
2. Parent directories walking up from cwd (same as Claude Code's CLAUDE.md discovery)
3. Current directory `AGENTS.md` or `CLAUDE.md`

**Your existing CLAUDE.md files work as-is** — Pi reads both filenames.

**System prompt override:**
- Replace default: `.pi/SYSTEM.md` (project) or `~/.pi/agent/SYSTEM.md` (global)
- Append only: `APPEND_SYSTEM.md` in either location

**What `.pi/AGENTS.md` contains (generated by `pi-project-setup`):**

Files are colinked throughout — AGENTS.md contains summaries with `→ see` references so the agent can read the linked file for full detail rather than having everything duplicated inline. This keeps the context loaded per session tight.

```markdown
## Project: [name]
[mission — one sentence]
→ see .pi/agent-docs/product/mission.md for full project context

## Stack
[key libraries — brief list]
→ see .pi/agent-docs/product/tech-stack.md for full stack and version details

## Running Processes
- [process name]: [command] — tmux pane [N]
- [process name]: [command] — tmux pane [N]

## Key Commands
- Dev: [command]
- Build: [command]
- Test: [command]
- Typecheck: [command]

## Debug Hierarchy
1. Error output → 2. git diff HEAD → 3. git log → 4. ideaLog → 5. Google/SO → 6. GitHub issues
Library priority: [ranked list]
→ see §17 of pi-agent-guide for full hierarchy

## Workflow Mode
[high-care: developer implements / low-care: agent implements]
Core commands: /1-dev-spec → /2-sync-spec → /3-commit

## Harness Maintenance
- After every sync-spec: tests pass + docs current
- After every commit: check roadmap for completed items
→ see .pi/agent-docs/product/roadmap.md

## Agent-Docs
All agent documentation lives in .pi/agent-docs/:
- Specs:            .pi/agent-docs/specs/
- Implementation log: .pi/agent-docs/implementation-log/YYYY/MM/
- Research:         .pi/agent-docs/research/
- Dev preferences:  .pi/agent-docs/standards/developer-preferences.md
```

**Colinking pattern:** Whenever a file references another for more detail, it uses `→ see <path>` notation. The agent follows these links when it needs full context rather than getting everything dumped in the initial context load. This is the primary token-saving mechanism across all agent-docs files.

---

## 5. Skills — How They Work

Skills follow the [Agent Skills standard](https://agentskills.io/specification). Pi implements the same standard Claude Code uses, so your existing `SKILL.md` files work.

**Where Pi discovers skills:**

```
~/.pi/agent/skills/       ← Global
~/.agents/skills/         ← Global (alternative)
.pi/skills/               ← Project-local (overrides global for same name)
.agents/skills/           ← Project-local (walks up to git root)
```

**To reuse your existing Claude Code skills:**

```json
// ~/.pi/agent/settings.json
{
  "skills": [
    "~/.claude/skills",
    "~/.agents/skills"
  ]
}
```

**SKILL.md format:**

```markdown
---
name: my-skill
description: What it does and when to use it. Be specific — this is how the model decides to load it.
---

# My Skill

## Usage
...instructions...
```

**Invoke:** `/skill:1-dev-spec` or let the agent detect from context.

**Skill repositories to install:**
- `pi install git:github.com/badlogic/pi-skills` — web search (Brave), browser automation, Google APIs, transcription, YouTube
- `pi install git:github.com/anthropics/skills` — document processing (docx, pdf, pptx, xlsx), web development

---

## 6. Extensions — TypeScript Power Tools

Extensions are TypeScript `.ts` files that export a default function receiving the `ExtensionAPI`.

**Where they live:**
```
~/.pi/agent/extensions/     ← Global
.pi/extensions/             ← Project-local
```

**Basic shape:**

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerTool({ ... });
  pi.registerCommand("stats", { ... });
  pi.on("tool_call", async (event, ctx) => { ... });
  pi.setStatusLine(() => "dev server running");
}
```

**What extensions can do:**
- Custom tools the LLM calls (including replacing built-in tools)
- Custom slash commands
- Custom keyboard shortcuts
- Event hooks: `tool_call`, `tool_result`, `message`, `session_start`, compaction
- Permission gates (confirm before destructive operations)
- Git checkpointing
- Path protection
- Custom compaction/summarization logic
- User interaction: `ctx.ui.confirm()`, `ctx.ui.select()`, `ctx.ui.input()`, `ctx.ui.notify()`
- Full TUI custom components (`ctx.ui.custom()`)
- Sub-agent spawning via tmux or SDK
- Session persistence (`pi.appendEntry()`)

---

## 7. Prompt Templates

Reusable markdown prompts expanded via `/templatename` in the editor.

```markdown
<!-- ~/.pi/agent/prompts/review.md -->
Review this code for bugs, security issues, and performance problems.
Focus on: {{focus}}
```

Invoke: `/review` → pi expands and sends it. Supports `{{variables}}` filled in at invocation time.

**Where they live:** `~/.pi/agent/prompts/`, `.pi/prompts/`, or in a pi package.

---

## 8. Pi Packages — Bundling Everything

A pi package bundles your extensions, skills, prompts, and themes into a single installable unit.

**Install commands:**

```bash
pi install npm:@foo/pi-tools           # from npm
pi install git:github.com/user/repo    # from git (global)
pi install git:github.com/user/repo -l # project-local (.pi/settings.json)
pi install ./path/to/local-package     # local path
pi list                                # show installed
pi update                              # update all
pi config                              # enable/disable specific resources
```

**Your personal package structure:**

```
zaye-pi-setup/
├── package.json
├── extensions/
│   └── ask-user-question.ts     ← AskUserQuestion tool (see §18)
├── skills/
│   ├── pi-project-setup/SKILL.md
│   ├── sync-harness/SKILL.md
│   ├── implement-spec/SKILL.md
│   ├── debug/SKILL.md
│   ├── research/SKILL.md
│   ├── learn/SKILL.md
│   └── build-skill/SKILL.md
└── prompts/
    └── (any global prompt templates)
```

Note: `1-dev-spec`, `2-sync-spec`, `3-commit` are **project-local** — they live in `.pi/skills/` and evolve per project. They are scaffolded by `pi-project-setup` from base templates in this package.

---

## 9. Sessions, Branching & Compaction

Pi sessions are branching trees stored as JSONL files.

```bash
pi -c                    # continue most recent session
pi -r                    # browse and select from history
pi --no-session          # ephemeral (don't save)
pi --session <path>      # use specific session file
pi --fork <path>         # fork a session into a new file
```

**`/tree`** — Navigate the full session tree, jump to any prior point, continue from there. All history preserved — compaction doesn't delete it.

**`/fork`** — Create a new session file from the current branch point.

**Compaction:** Triggered automatically on context overflow, or manually via `/compact`. The JSONL file always has the full history — use `/tree` to revisit compacted messages.

---

## 10. Programmatic SDK & RPC Mode

### SDK (Node.js / TypeScript)

```typescript
import { AuthStorage, createAgentSession, ModelRegistry, SessionManager } from "@mariozechner/pi-coding-agent";

const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
  authStorage: AuthStorage.create(),
  modelRegistry: ModelRegistry.create(AuthStorage.create()),
});

await session.prompt("What files are in the current directory?");
```

### RPC Mode (any language)

```bash
pi --mode rpc
```

**Key RPC commands:**
- `{"type": "prompt", "message": "..."}` — send prompt
- `{"type": "prompt", "message": "...", "images": [...]}` — send with images
- `{"type": "steer", "message": "..."}` — queue steering mid-turn
- `{"type": "abort"}` — abort current operation

---

## 11. Complete Skill Set — Flat Structure

All skills live at the top level — no `agent-os/` subdirectory. All agent documentation lives in `.pi/agent-docs/`.

### Global skills (`~/.pi/agent/skills/`)

| Skill | Source | Purpose |
|-------|--------|---------|
| `pi-project-setup` | NEW | One-time bootstrap for any project (see §14) |
| `sync-harness` | NEW | Update harness when project requirements change (see §15) |
| `implement-spec` | from agent-os | Execute an approved spec plan |
| `debug` | from vex | Bug research with configurable hierarchy (see §17) |
| `research` | from vex | Tool comparison report |
| `learn` | from vex | Curated doc reading guide |
| `build-skill` | NEW | Scaffold new project-specific skills (see §16) |

### Project-local skills (`.pi/skills/` — scaffolded by setup, evolve per project)

| Skill | Source | Purpose |
|-------|--------|---------|
| `1-dev-spec` | from vex (advanced) | Developer-led implementation spec — evolves most |
| `2-sync-spec` | from vex | Post-implementation alignment + pattern extraction |
| `3-commit` | from vex/maprios | Conventional commit + ideaLog append |
| `build-skill` | NEW | Project-local skill builder (project-aware version) |
| `review` | from vex | Code review (optional, conventions vary per project) |
| `document` | from vex | JSDoc/docs (optional, language-specific) |
| `feature-checklist` | from vex | Completion check (optional, "done" definition varies) |

### Removed from old setup (reasons)

| Old command | Why removed |
|-------------|-------------|
| `copy-commit`, `copy-commit-body` | Redundant — `/commit` is the only commit workflow |
| `shape-spec`, `plan-product` | Folded into `pi-project-setup` |
| `init-standards`, `discover-standards`, `inject-standards`, `index-standards` | Handled by `pi-project-setup` and `sync-harness` |
| `detect-project-type`, `improve-skills` | Handled by setup and `build-skill` |
| `add-vexfield` / `new-field` | Project-specific skill for vex — stays in `.pi/skills/` for vex only |
| `guide` | Optional, project-specific — scaffold via `build-skill` if needed |

---

## 12. The Three Core Workflow Commands

These are the commands you run while building. They are numbered because they always run in this order. The numbers are set by `pi-project-setup` based on the project's workflow tier.

### Default workflow (high-care project — developer implements manually)

```
/1-dev-spec  →  [you implement]  →  /2-sync-spec  →  /3-commit
```

### Alternate workflow (low-care project — agent implements)

```
/1-dev-spec  →  /2-implement-spec  →  /3-sync-spec  →  /4-commit
```

The number assignment is determined at setup time and documented in `.pi/AGENTS.md`.

---

### 1-dev-spec — Developer-Led Implementation Spec

**Purpose:** Produce a spec document with full code for boilerplate (types, interfaces, utils, re-exports) and guided function stubs with edge cases and pseudo-code for logic the developer writes.

**Key behaviors:**
- Uses `ask_user_question` tool for all questions (scope, edge cases, review)
- Scopes tightly — no speculative code, no stubs for future specs
- Build order is testable at every step (entry point first, then leaf functions)
- Tests colocated with implementation in the same step
- Every exported symbol has complete JSDoc
- Implementation guidance lives inside function bodies as numbered comments
- After Phase 4, self-checks the build order before presenting to developer

**What makes the project-local version different from the global template:**
- Accumulated developer preference patterns (from sync-spec runs)
- Project-specific conventions (naming, file organization)
- Library-specific patterns (Convex mutation shapes, React hook patterns, etc.)
- Known "never do this" rules extracted from past deviations
- This file evolves — see §13

**Spec location:** `.pi/agent-docs/specs/YYYY-MM-DD-HHMM-feature-slug/` containing `plan.md`, `shape.md`, `standards.md`, `references.md`.

---

### 2-sync-spec — Post-Implementation Alignment

**Purpose:** After implementing a spec, compare actual code against the spec, update the spec to match, extract patterns, and update the project-local dev-spec so future specs start better.

**Key behaviors:**
- Uses `ask_user_question` for all diff presentations and confirmations
- Every deviation the developer made is treated as a preference, not a mistake
- Updates the project-local `1-dev-spec/SKILL.md` with extracted patterns
- Writes `.pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.ideaLog.md`
- Writes `.pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.commit.md`
- Updates `.pi/agent-docs/product/roadmap.md` for completed features
- Verifies tests pass and docs are current after every sync
- Marks all spec checkboxes complete

**Pattern extraction (feeds back into dev-spec):**
- **Preference Patterns** — consistent style choices → update dev-spec defaults
- **Implementation Improvements** — spec was underbaked → update stub quality
- **Architecture Decisions** — one-time choices → document in ideaLog only

---

### 3-commit — Commit Message Generator

**Purpose:** Generate a conventional commit message for all uncommitted changes and append it to today's implementation log.

**Key behaviors:**
- Reads `git diff HEAD` and `git log --oneline -5`
- Conventional commit format: `type(scope): description` (under 72 chars)
- Body explains WHY, not what files changed
- Appends to `.pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.commit.md`
- Outputs just the title on its own line so it's easy to copy

---

## 13. The Continuous Improvement Loop

The project-local `1-dev-spec` is a living document. Every time you run `2-sync-spec`, it gets smarter about how you build things. This is the primary compounding mechanism — each cycle reduces the gap between what the spec generates and what you'll actually ship.

```
dev-spec generates spec
        ↓
developer implements (moves things, renames, improves)
        ↓
sync-spec compares code vs spec
        ↓
sync-spec extracts deviations as patterns
        ↓
sync-spec updates 1-dev-spec/SKILL.md with new rules
        ↓
next dev-spec generates code closer to what you'll ship
        ↓
...repeat
```

**The `developer-preferences.md` file** (`.pi/agent-docs/standards/developer-preferences.md`) is the audit trail. Every pattern sync-spec encodes into dev-spec is also written here with the date it was learned and which sync-spec run surfaced it.

**What the model learns over time:**
- Naming conventions you consistently apply
- Which patterns you always deviate from in the spec
- Library-specific idioms that belong in every spec for this stack
- Testing patterns you always add that the spec misses
- Architecture decisions that inform all future specs

**Session continuity:** At the start of a session, if there's an active spec (unchecked boxes in `.pi/agent-docs/specs/`), resume from there. If no active spec, check `git status` — the most recent committed files tell you where you left off.

---

## 14. The `pi-project-setup` Command

Run once when starting any new project. Works for any language, any framework.

### Phase 1: Scan the project

Before asking a single question, read everything available:
- `package.json` / `Cargo.toml` / `go.mod` / `pyproject.toml` / `build.gradle`
- Existing `AGENTS.md` / `CLAUDE.md` / `.cursorrules`
- Existing `.pi/agent-docs/` directory (previous setup)
- `src/` structure to identify frameworks and patterns
- `README.md` for project description
- `.pi/agent-docs/product/` for existing mission/roadmap (if present)

Infer automatically:
- Project type (web app, CLI, library, service, monorepo)
- Framework and key libraries
- Build, test, and typecheck commands
- Whether code quality/UX matters (high-care vs low-care)
- Likely running processes based on the tech stack

### Phase 2: Plan-product interview

Ask only what cannot be determined from the codebase. Use `ask_user_question` for everything:

```
Topics to cover (ask only what's unclear):
- Mission: what is this project and who is it for?
- Current state: what's built vs what's planned?
- Tech stack: confirm what was inferred
- Running processes: what services run while you work?
  - Which tmux pane runs each?
  - Where do error logs appear?
- Workflow tier: high-care (manual implementation) or low-care?
- Key libraries for debugging (ranked by how often they cause issues)
- Roadmap direction: what are the next 3 things to build?
```

### Phase 3: Determine core workflow numbering

Based on the tier and project type, assign numbers to core commands:

**High-care (default):**
```
1-dev-spec → 2-sync-spec → 3-commit
```

**Low-care (agent implements):**
```
1-dev-spec → 2-implement-spec → 3-sync-spec → 4-commit
```

**Docs-heavy project:**
```
1-dev-spec → 2-sync-spec → 3-commit → document and guide promoted to numbered
```

Document the chosen order in `.pi/AGENTS.md`.

### Phase 4: Suggest project-specific skills

After scanning the codebase and completing the interview, the agent reviews the project patterns and suggests 3–5 custom skills that would streamline the developer's workflow. Examples:

- If the project has a custom component pattern used frequently → suggest a `new-component` skill
- If the project has a recurring migration or config pattern → suggest a skill for it
- If there's a docs site → suggest a `guide` skill scoped to the site's structure

Present suggestions with `ask_user_question`. Selected suggestions are added to the build queue for `build-skill` to create after setup.

### Phase 5: Write all project files

Create or update:
```
.pi/
├── AGENTS.md                    ← Project context (summaries + colinking → see notation)
├── skills/
│   ├── 1-dev-spec/SKILL.md      ← Base template customized for this stack
│   ├── 2-sync-spec/SKILL.md
│   ├── 3-commit/SKILL.md
│   └── build-skill/SKILL.md
└── agent-docs/
    ├── product/
    │   ├── mission.md            ← Project mission and goals
    │   ├── roadmap.md            ← Current roadmap (updated by sync-spec)
    │   └── tech-stack.md         ← Stack and key libraries with versions
    ├── specs/                    ← Where dev-spec saves specs
    ├── implementation-log/       ← Where sync-spec and commit save logs
    │   └── YYYY/MM/
    │       ├── YYYY-MM-DD.ideaLog.md
    │       └── YYYY-MM-DD.commit.md
    └── standards/
        └── developer-preferences.md  ← Accumulated patterns (starts empty)
```

### Phase 6: Write the first ideaLog entry

```markdown
# YYYY-MM-DD — Project Setup

**Command:** pi-project-setup
**Project:** [name]
**Type:** [inferred type]
**Tier:** [high-care / low-care]

## What was configured

- Running processes: [list]
- Key libraries: [ranked list]
- Core workflow: [numbered command sequence]
- Custom skills suggested: [list]

## Decisions made during setup

- [Any notable inference or answer that shaped the setup]
```

### Phase 7: Report to developer

```
Setup complete for: [project name]

Created:
- .pi/AGENTS.md
- .pi/skills/ (N skills)
- .pi/agent-docs/product/ (mission, roadmap, tech-stack)
- .pi/agent-docs/implementation-log/

Core workflow: /1-dev-spec → /2-sync-spec → /3-commit

Suggested skills to build next:
1. [skill name] — [what it does]
2. [skill name] — [what it does]

Run /build-skill to create any of these.
```

---

## 15. The `sync-harness` Command

Run manually when something about the project's setup changes: new libraries added, new services, change in direction, new team members, etc.

**Behavior:**
- Similar to `dev-spec` in how it asks questions (uses `ask_user_question`, only asks what's unclear)
- Scans the current codebase and compares against `.pi/AGENTS.md`
- Proposes updates to: AGENTS.md, process list, debug library hierarchy, roadmap, tech-stack.md
- For ambiguous changes, asks the developer for confirmation
- Logs every change to `.pi/agent-docs/implementation-log/` so the history of project direction is preserved

**Why the ideaLog entry matters here:** The history of how the harness evolved is queryable. You can ask "what was the project setup like when we were building the auth system?" and the agent searches the ideaLog for harness changes around that time.

**IdeaLog entry format for sync-harness:**
```markdown
# YYYY-MM-DD — Harness Update

**What changed:** [brief description]
**Why:** [the reason — new library, changed direction, new process]

## AGENTS.md changes
- [specific changes made]

## Developer-preferences.md changes
- [any new patterns encoded]
```

---

## 16. The `build-skill` Command

An interactive skill builder — you describe a workflow you repeat frequently, it interviews you about it and generates the `SKILL.md`.

**Process:**

### Phase 1: Understand the workflow

Use `ask_user_question` to gather:
- What triggers this workflow? (when do you run this?)
- What does the workflow produce? (output: a file, a change, a report)
- What does the agent need to know first? (what to read or check)
- What are the common failure modes or edge cases?
- Any project-specific conventions that apply?

### Phase 2: Scan for existing patterns

Before writing the skill, scan the codebase for examples of this workflow being done manually. Extract patterns.

### Phase 3: Write the SKILL.md

Output to `.pi/skills/<skill-name>/SKILL.md`. The skill uses `ask_user_question` for any interactive steps.

### Phase 4: Confirm and suggest numbering

If this skill is used often enough to be part of the core workflow, suggest adding it to the numbered sequence. Update `.pi/AGENTS.md` if accepted.

---

## 17. Debug Hierarchy

The debug skill is generic — the library list it checks is configured per project in `.pi/AGENTS.md` (set during `pi-project-setup`). The hierarchy never changes; only the library priority list changes per project.

**Universal debug hierarchy:**

```
1. Read the error output directly
   → What is the exact error message? What line? What call stack?
   → This is the first clue about which layer broke.

2. git diff HEAD — check uncommitted changes
   → ~80-90% of bugs are in the current working tree
   → The most recently touched file is the most likely culprit

3. git log --oneline -10 — if not uncommitted
   → When did this last work? What changed between then and now?
   → Narrow to the commit range, then read those diffs

4. .pi/agent-docs/implementation-log/ ideaLog
   → For harder issues: was there a decision or known gap documented?
   → Search for the affected file path, function name, or library name
   → If found: read the entry — it explains why the code looks that way

5. Google / Stack Overflow
   → Search the exact error string first
   → Priority: accepted answers with the same library version

6. GitHub issues for [project-specific libraries — from .pi/AGENTS.md]
   → Check the specific library's GitHub issues
   → Priority: closed issues with linked PRs (fix already merged)
   → Library order is set at project setup time

7. Official docs / changelog
   → Breaking changes in the library version being used?
   → Migration guide mention this behavior?
```

**Regression rule (always applies):** When a bug is found in test-covered code, the test must be updated to catch this regression before the fix is applied. The test failure is what catches the bug next time.

**Research output:** Bugs with non-trivial causes are saved to `.pi/agent-docs/research/bugs/<slug>.md` with root cause, solutions found, confidence levels, and search queries used. This prevents re-investigating the same dead ends.

---

## 18. The `ask_user_question` Extension

Recreates Claude Code's `AskUserQuestion` tool as a Pi custom tool. All skills that ask the user structured questions call this tool. The LLM calls it exactly as it calls the Claude Code version.

**File:** `~/.pi/agent/extensions/ask-user-question.ts`

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user_question",
    description: `Ask the user a structured question with options. Use this tool whenever you need to ask the user anything — decisions, preferences, scope confirmation, clarifications. Never ask questions via plain text output. Use this instead.`,
    parameters: {
      type: "object",
      properties: {
        question: {
          type: "string",
          description: "The complete question to ask the user"
        },
        options: {
          type: "array",
          items: {
            type: "object",
            properties: {
              label: { type: "string" },
              description: { type: "string" }
            },
            required: ["label", "description"]
          },
          description: "Options to present. If omitted, shows a free-text input."
        },
        multiSelect: {
          type: "boolean",
          description: "Allow selecting multiple options",
          default: false
        }
      },
      required: ["question"]
    },
    execute: async ({ question, options, multiSelect }, ctx) => {
      if (!options || options.length === 0) {
        const result = await ctx.ui.input(question);
        return result ?? "No input provided";
      }

      const labels = options.map((o: { label: string; description: string }) =>
        `${o.label} — ${o.description}`
      );

      if (multiSelect) {
        // Chain multiple selects for multi-select behavior
        const results: string[] = [];
        let selecting = true;
        while (selecting) {
          const remaining = ["Done selecting", ...labels.filter(l => !results.includes(l))];
          const pick = await ctx.ui.select(remaining, { prompt: question });
          if (!pick || pick === "Done selecting") selecting = false;
          else results.push(pick);
        }
        return results.join(", ") || "None selected";
      }

      const result = await ctx.ui.select(labels, { prompt: question });
      return result ?? "No selection made";
    }
  });
}
```

**Important:** All skills that currently say "use AskUserQuestion tool" should say "use the `ask_user_question` tool" in Pi. The behavior is identical — the LLM calls it as a tool, the extension handles the UI.

**Check `shittycodingagent.ai/packages` and the Pi Discord `#packages` channel** — a community package for this may already exist and offer a more polished implementation.

---

## 19. Workflow Improvements

### Screenshots without copy-paste

1. **`Ctrl+V` paste** — Pi supports pasting images from clipboard directly. Screenshot to clipboard with `Cmd+Ctrl+Shift+4`, paste with `Ctrl+V`.
2. **`@file` reference** — Type `@` in Pi editor to fuzzy-search files. Take a screenshot, save to `~/Desktop`, then `@screenshot.png`.
3. **`pi -p @screenshot.png "..."`** — Pass screenshot as file argument for non-interactive sessions.

### Tmux pane monitoring

Register the `tmux_pane` tool via extension so the LLM can read dev server output directly:

```typescript
pi.registerTool({
  name: "tmux_pane",
  description: "Read output from a tmux pane. Use to check dev server logs, test output, or build errors.",
  parameters: {
    type: "object",
    properties: {
      pane: { type: "string", description: "Pane target, e.g. '1', 'session:window.pane'" },
      lines: { type: "number", description: "Lines to capture (default: 50)" }
    },
    required: ["pane"]
  },
  execute: async ({ pane, lines = 50 }) => {
    const { execSync } = await import("child_process");
    try {
      return execSync(`tmux capture-pane -p -t ${pane} | tail -n ${lines}`).toString();
    } catch (e: any) {
      return `Error: ${e.message}`;
    }
  }
});
```

Pane layout is documented in `.pi/AGENTS.md` (set during `pi-project-setup`).

### Context injection at session start

Hook into `session_start` to automatically prime context with the active spec and last ideaLog entry:

```typescript
pi.on("session_start", async (event, ctx) => {
  const { execSync } = await import("child_process");
  try {
    // Find active spec (has unchecked boxes)
    const specs = execSync("grep -rl '\\- \\[ \\]' .pi/agent-docs/specs/ 2>/dev/null | head -3").toString().trim();
    if (specs) ctx.ui.notify(`Active specs: ${specs.split("\n").join(", ")}`);

    // Show last ideaLog entry date
    const lastLog = execSync("ls .pi/agent-docs/implementation-log/*/*ideaLog.md 2>/dev/null | sort | tail -1").toString().trim();
    if (lastLog) ctx.ui.notify(`Last log: ${lastLog}`);
  } catch { /* no agent-os yet */ }
});
```

---

## 20. Community Resources

| Resource | URL |
|----------|-----|
| Pi monorepo | https://github.com/badlogic/pi-mono |
| Coding agent README | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md |
| Extensions docs | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md |
| Skills docs | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md |
| SDK docs | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/sdk.md |
| RPC docs | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/rpc.md |
| Packages docs | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md |
| Extension examples | https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent/examples/extensions |
| Pi skills (badlogic) | https://github.com/badlogic/pi-skills (brave-search, browser, youtube, transcribe) |
| Anthropic skills | https://github.com/anthropics/skills (pdf, docx, xlsx, pptx, web dev) |
| Community packages | https://www.npmjs.com/search?q=keywords%3Api-package |
| Package gallery | https://shittycodingagent.ai/packages |
| Pi Discord | https://discord.com/invite/3cU7Bz4UPx |
| Agent Skills standard | https://agentskills.io/specification |

---

## 21. Doc Map — Where to Find Everything

### Your existing assets

| Asset | Current location |
|-------|-----------------|
| Vex commands (source) | `/Users/zaye/Documents/Projects/vex.git/dev/.claude/commands/` |
| Maprios commands (source) | `/Users/zaye/Documents/Projects/maprios-app.git/dev/.claude/commands/` |
| Chezmoi commands (source) | `/Users/zaye/.local/share/chezmoi/.claude/commands/` |
| Agent-OS skills (global) | `/Users/zaye/Documents/Projects/.claude/skills/` |
| Vex standards | `/Users/zaye/Documents/Projects/vex.git/dev/agent-os/standards/` |
| Vex product docs | `/Users/zaye/Documents/Projects/vex.git/dev/agent-os/product/` |
| This guide | `/Users/zaye/.local/share/chezmoi/pi-agent-guide.md` |

### Pi config locations (after setup)

| Asset | Target location |
|-------|----------------|
| Global settings | `~/.pi/agent/settings.json` |
| Global context | `~/.pi/agent/AGENTS.md` |
| Global skills | `~/.pi/agent/skills/` |
| AskUserQuestion extension | `~/.pi/agent/extensions/ask-user-question.ts` |
| Tmux + session-start extension | `~/.pi/agent/extensions/project-tools.ts` |
| Prompt templates | `~/.pi/agent/prompts/` |
| Project-local | `.pi/` in each repo |
| Numbered core skills | `.pi/skills/1-dev-spec/`, `.pi/skills/2-sync-spec/`, `.pi/skills/3-commit/` |
| Sessions | `~/.pi/agent/sessions/` |

### Per-project structure (after pi-project-setup)

```
project-root/
└── .pi/
    ├── AGENTS.md                        ← Summaries + colinking (→ see paths)
    ├── skills/
    │   ├── 1-dev-spec/SKILL.md          ← Evolves via sync-spec
    │   ├── 2-sync-spec/SKILL.md
    │   ├── 3-commit/SKILL.md
    │   └── build-skill/SKILL.md
    └── agent-docs/                      ← All agent docs ("agent-docs" in conversation)
        ├── product/
        │   ├── mission.md               ← Project mission
        │   ├── roadmap.md               ← Updated by sync-spec
        │   └── tech-stack.md            ← Stack, libs, versions
        ├── specs/
        │   └── YYYY-MM-DD-HHMM-feature/
        │       ├── plan.md              ← Links back to ideaLog and standards
        │       ├── shape.md
        │       ├── standards.md
        │       └── references.md
        ├── implementation-log/
        │   └── YYYY/MM/
        │       ├── YYYY-MM-DD.ideaLog.md  ← Decision history (links to spec)
        │       └── YYYY-MM-DD.commit.md   ← Commit message (links to ideaLog)
        ├── research/
        │   ├── bugs/                    ← Bug research from debug skill
        │   ├── tools/                   ← Tool comparison from research skill
        │   └── docs/                    ← Reading guides from learn skill
        └── standards/
            └── developer-preferences.md  ← Accumulated patterns (evolves)
```

### Quick reference: Claude Code → Pi mapping

| Claude Code | Pi |
|-------------|-----|
| `CLAUDE.md` | `AGENTS.md` (Pi reads both) |
| `.claude/commands/foo.md` | `.pi/skills/foo/SKILL.md` (project-local) or `~/.pi/agent/skills/foo/` (global) |
| `.claude/settings.local.json` hooks | `~/.pi/agent/extensions/*.ts` |
| `~/.claude/skills/` | `~/.pi/agent/skills/` |
| MCP servers | Build via extension (or skip) |
| Sub-agents | Build via extension or tmux |
| Plan mode | Build via extension or install package |
| `AskUserQuestion` tool | `ask_user_question` tool via extension (see §18) |
| `/command` | `/skill:name` or `/templatename` |

---

*Updated: 2026-04-21. Pi version: check `pi --version`.*
