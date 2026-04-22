---
name: 2-sync-spec
description: Post-implementation upkeep runner. Extracts developer patterns and updates project skills, runs configured upkeep tasks, and keeps the harness in sync with how the project is actually built. Configured per project by 0-project-init.
invoke: "sync-spec"
---

# Sync Spec

<!-- SETUP:CHECK
  If this file still contains {{PROJECT_NAME}} (unreplaced), the project harness
  has not been initialized. Tell the user:

  "Run `/0-project-init` first — it will configure this prompt for your project's
  upkeep tasks and workflow."

  Then stop.
-->

Run at natural stopping points: end of session, after a PR, after implementing a complex feature.

**Project:** {{PROJECT_NAME}}
**Language:** {{LANGUAGE}}

---

> **Questions:** Use the `ask_user_question` tool for every question in this skill. Never write question lists as plain text.

---

## Part 1 — Pattern Extraction

### Step 1 — Read project context

Read before gathering deviations:
- `.pi/agent-docs/product/tech-stack.md` — language and stack, for language-aware pattern extraction
- `.pi/agent-docs/standards/developer-preferences.md` — existing rules, to avoid re-extracting known patterns

### Step 2 — Gather deviations

Ask:
> What changed during implementation compared to the spec? List any:
> - Files modified that weren't in the spec
> - Patterns used that differ from what was specced
> - Libraries or APIs chosen differently
> - Structural or naming decisions made on the fly

If there's no active spec, ask:
> What did you just build? Walk me through any non-obvious decisions you made.

### Step 3 — Identify extractable patterns

<!-- sync-spec:pattern-categories -->
{{PATTERN_CATEGORIES}}
<!-- /sync-spec:pattern-categories -->

Only extract patterns that are **repeatable** and **non-obvious from the code** — skip one-offs.

### Step 4 — Confirm with developer

For each extracted pattern, ask:
> I noticed you <pattern>. Should this become a standing rule for future specs?
> A) Yes — add to dev-spec
> B) Yes but narrow — only applies when <condition>
> C) No — one-off, skip it

### Step 5 — Update developer-preferences.md

Append confirmed patterns to `.pi/agent-docs/standards/developer-preferences.md`:

```
- <pattern description> → <reason if given> — <date>
```

### Step 6 — Update skills with extracted patterns

For each confirmed pattern, update the relevant skill's `<!-- sync-spec: -->` block:

| Pattern type | Update target |
|-------------|--------------|
| Implementation or naming convention | `1-dev-spec` → `<!-- sync-spec:developer-preferences -->` |
| Documentation style or type convention | `document` → `<!-- sync-spec:doc-conventions -->` or `<!-- sync-spec:type-conventions -->` |
| Commit message scope or type usage | `3-commit` → `<!-- sync-spec:commit-conventions -->` |

---

## Part 2 — Upkeep Tasks

After pattern extraction, run the configured upkeep tasks for this project in order:

<!-- sync-spec:upkeep-tasks -->
{{UPKEEP_TASKS}}
<!-- /sync-spec:upkeep-tasks -->

---

## Part 3 — IdeaLog Entry

Append to today's ideaLog at `.pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.ideaLog.md`:

```markdown
## Sync Spec — <timestamp>

Patterns extracted:
- <pattern> → added to <skill>

Patterns rejected:
- <pattern> — one-off / developer said skip

Upkeep tasks run:
- <task> — <result>
```

---

## What NOT to extract

- Patterns already in developer-preferences.md
- IDE or formatter preferences (those go in editor config)
- Debug steps or investigation notes (those go in ideaLog)
- Anything the developer said was a mistake
- Library internals that only apply to one specific call site
