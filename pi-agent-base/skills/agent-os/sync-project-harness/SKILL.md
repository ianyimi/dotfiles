---
name: sync-project-harness
description: Port new paradigms from the global base harness (~/.pi/agent/) into the current project's .pi/ harness, adapting them to match the project's stack, workflow tier, and conventions. Run in any project to pull in improvements made to another project's harness.
---

# Sync Project Harness

Port new paradigms from the global base harness into this project. Run this
in any project after you've improved your harness patterns in another project
and want those improvements here too.

What this skill does:
1. Reads the base harness for new/changed standards files, prompt structure
   improvements, and skill additions
2. Diffs them against what this project currently has in `.pi/`
3. Asks targeted questions to understand how each paradigm should be adapted
   for this project's stack and workflow
4. Writes the adapted files into `.pi/` with your approval
5. Logs the sync to today's ideaLog

---

## Step 1 — Read base harness and current project state

Read both sides of the diff:

```
Base harness location:  ~/.pi/agent/
Project harness:        .pi/
```

Scan these locations in the base harness for anything the project doesn't
have yet, or has an older version of:

- `~/.pi/agent/skills/agent-os/*/template.md` — standards templates
- `~/.pi/agent/skills/agent-os/*/SKILL.md` — skill definitions
- `~/.pi/agent/prompts/*.md` — prompt files

For each item, check whether the project has a corresponding file:

| Base harness item | Maps to project file |
|---|---|
| `skills/agent-os/jsdoc-conventions/template.md` | `.pi/agent-docs/standards/jsdoc-conventions.md` |
| `skills/agent-os/spec-structure/template.md` | `.pi/agent-docs/standards/spec-structure.md` |
| `skills/agent-os/design/SKILL.md` | `.pi/design/` (folder + README) |
| `prompts/1-dev-spec.md` structure (slim + pointers pattern) | `.pi/prompts/1-dev-spec.md` |
| `prompts/sync-harness.md` | `.pi/prompts/sync-harness.md` |
| `prompts/debug.md` | `.pi/prompts/debug.md` |
| Any other `prompts/*.md` | `.pi/prompts/<name>.md` |
| `AGENTS.md` sections (executing skills, asking questions, workflow tier) | `.pi/AGENTS.md` |

Classify each item as one of:
- **NEW** — base has it, project doesn't
- **STALE** — project has an older version
- **CURRENT** — project has this, matches base pattern
- **PROJECT-SPECIFIC** — project has a customized version that shouldn't be overwritten blindly

Report the classification to the user as a table.

---

## Step 2 — Ask about each NEW or STALE item

For each **NEW** or **STALE** item, ask the user using `ask_user_question`:

Group related items into one question where possible. For example,
"Add jsdoc-conventions.md and spec-structure.md?" can be one question.

For each item the user wants to adopt, you'll need to adapt it. Move to
Step 3.

**Do not ask about CURRENT or PROJECT-SPECIFIC items.** Skip them silently
unless the user has explicitly said "sync everything."

---

## Step 3 — Adapt each adopted item to this project

For each item the user approved in Step 2, adapt it before writing.
"Adapting" means replacing base-harness-generic placeholders with
project-specific values.

### 3a. Discover project context

Read the project's existing harness to understand:

- **Stack**: read `.pi/agent-docs/product/tech-stack.md` (if it exists) or
  scan manifest files (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`,
  etc.) to determine the language and major frameworks.
- **Workflow tier**: read `.pi/AGENTS.md` or `.pi/agent-docs/product/tech-stack.md`
  for the tier (high-care, standard, autonomous).
- **Test framework**: scan for `vitest.config.*`, `jest.config.*`,
  `pytest.ini`, `go test`, etc.
- **Linter**: scan for `eslint.config.*`, `.eslintrc`, `pylint`, `clippy`, etc.
- **Spec numbering**: check `.pi/agent-docs/specs/` for the highest existing
  spec number and naming convention.
- **Package manager**: `pnpm-workspace.yaml` → pnpm monorepo, `package.json`
  (no workspace) → npm/yarn, `Cargo.toml` → Cargo, etc.

If you can't determine something from files, ask the user. Bundle all
unknown-context questions into a **single `ask_user_question` call**.

### 3b. Adapt each standard file template

For `jsdoc-conventions.md`:

- Replace references to `eslint-plugin-jsdoc` with the actual linter the
  project uses. If the project uses Python/Pylint/ruff, replace JSDoc patterns
  with Python docstring patterns (Google/NumPy/Sphinx style). If Go, use
  godoc patterns. If Rust, use `///` doc comment patterns.
- Replace `@typescript-eslint/*` rule names with the equivalent for the
  project's linter.
- Replace code examples using the project's actual language syntax.
- Keep all failure-mode documentation structure — just translate the patterns.

For `spec-structure.md`:

- Replace "TypeScript rules in code samples" with the project's language.
- Replace test framework references (`vitest`, `convex-test`) with the
  project's actual test framework.
- Replace the build-order rule (the vexcms-specific 7-step order) with the
  project's actual build/deploy order from `dev-processes.md`.
- Keep all structural rules (colocation, ordering, decisions discipline,
  Code Effect Preview) — they're language-agnostic.

For `1-dev-spec.md` (the slim-prompt-with-pointers pattern):

- Keep the "slim checklist + pointers to standards files" structure.
- Replace the monorepo packages table with the project's actual packages
  (or remove if not a monorepo).
- Replace the dev commands table with the project's actual commands from
  `dev-processes.md`.
- Keep the Phase 1–4 interview structure.
- Keep the "Required sections quick checklist" pattern.
- Adapt the "Build order rule" section to the project's stack.
- Replace the developer preferences sync-spec block with whatever the project
  currently has in `.pi/agent-docs/standards/developer-preferences.md`.

### 3c. Confirm adapted content with user

For each adapted file, show the user a summary of what changed from the
template. Don't show the full file unless asked. Ask:

```
Ready to write <filename>?
- Adapted from: base harness template
- Key changes: <list of what was adapted>
```

Use `ask_user_question` to confirm before writing each file.

---

## Step 4 — Write approved files

Write each confirmed file to its target path in `.pi/`. Never overwrite
without confirmation from Step 3c.

If a file already exists:
- Show a one-line diff of the most important change
- Confirm with the user before overwriting

---

## Step 5 — Update standards index

If `.pi/agent-docs/standards/index.yml` exists, add entries for any new
standards files written in Step 4. Follow the format already in the index.

If it doesn't exist, note in the ideaLog that the user should run
`/index-standards` to generate it.

---

## Step 6 — IdeaLog entry

Append to today's ideaLog at `.pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.ideaLog.md`:

```markdown
## Harness Sync from Base — <timestamp>

New paradigms ported from `~/.pi/agent/`:

### Adopted
- <item>: <one-line description of what was adapted>
- <item>: ...

### Skipped
- <item>: <reason>

### Could not auto-adapt (manual action needed)
- <item>: <what the user needs to do manually>
```

---

## Guidelines

- **Always bundle questions.** Never call `ask_user_question` more than once
  per logical group. Batch all unknown-context questions into one call.
- **Adapt, don't copy.** A template that references "TypeScript" in a Python
  project is worse than no template. Always adapt to the project's actual
  stack.
- **Preserve project-specific content.** If `.pi/prompts/1-dev-spec.md`
  already has project-specific developer preferences, keep them. Only
  update the structural pattern (slim checklist + pointers), not the
  project-specific data inside it.
- **No silent writes.** Every write is preceded by a confirmation. The user
  is in control of what lands in their harness.
- **Fail gracefully.** If the base harness doesn't have a template for
  something the user wants, say so clearly and suggest they run
  `/sync-harness` in the project that has it first, then re-run
  `/sync-project-harness`.
