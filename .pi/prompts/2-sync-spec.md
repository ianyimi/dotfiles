---
name: 2-sync-spec
description: Post-implementation upkeep runner. Extracts developer patterns and updates project skills, runs configured upkeep tasks, and keeps the harness in sync with how the project is actually built. Configured per project by 0-project-init.
invoke: "sync-spec"
---

# Sync Spec

Run at natural stopping points: end of session, after completing a dotfile change, after implementing a feature.

**Project:** chezmoi dotfiles
**Language:** Shell scripting (Bash/Zsh)

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
> - Shell syntax or scripting decisions made on the fly
> - chezmoi template patterns or Bitwarden integration patterns
> - Platform-specific handling (darwin vs linux)

If there's no active spec, ask:
> What did you just build or change in the dotfiles? Walk me through any non-obvious decisions you made.

### Step 3 — Identify extractable patterns

<!-- sync-spec:pattern-categories -->
**Shell scripting patterns:**
- Naming conventions (function names, variable naming, file naming)
- Error handling (set -e, error messages, exit codes)
- chezmoi template patterns (Bitwarden lookups, conditionals, file naming)
- Platform detection (OS checks, architecture checks)
- Script organization (where scripts go, how they're invoked)
- Ansible task structure (when to use run_once vs run_always, handler patterns)
- Alias conventions (naming, grouping in .zshrc)
- Tool configuration patterns (tmux, Neovim, Aerospace setup style)
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
| Implementation, naming, or scripting convention | `1-dev-spec` → `<!-- sync-spec:developer-preferences -->` |
| Commit message scope or type usage | `3-commit` → `<!-- sync-spec:commit-conventions -->` |
| chezmoi template patterns | `1-dev-spec` → `<!-- sync-spec:developer-preferences -->` (or create dedicated section if many) |

---

## Part 2 — Upkeep Tasks

After pattern extraction, run the configured upkeep tasks for this project in order:

<!-- sync-spec:upkeep-tasks -->
**Configured upkeep tasks:**

1. **Preview changes**
   - Run: `cm diff`
   - Purpose: Show what changed in managed files
   - Condition: Always

2. **Apply and verify** (conditional)
   - Run: `cma` (or `bw-session-check && cm apply` if already sourced)
   - Purpose: Apply dotfile changes to the system and verify no errors
   - Condition: Only if Bitwarden session is active (`bw unlock --check`)
   - If session expired: note it and skip (user can run `cma` manually after unlocking)

3. **Close completed specs**
   - Action: Move completed spec directories from `.pi/agent-docs/specs/` to `.pi/agent-docs/specs/archive/YYYY-MM/`
   - Condition: If the developer confirms implementation is complete

4. **Update ideaLog**
   - Action: Append sync-spec run summary to today's ideaLog
   - Always run (creates entry if missing)

**Note on roadmap:** This project doesn't maintain a formal roadmap. Changes are made as needed. Future Linux support is tracked on a separate branch.
<!-- /sync-spec:upkeep-tasks -->

---

## Part 3 — IdeaLog Entry

Append to today's ideaLog at `.pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.ideaLog.md`:

```markdown
## Sync Spec — <timestamp>

Changes applied:
- <summary of what was changed>

Patterns extracted:
- <pattern> → added to <skill>

Patterns rejected:
- <pattern> — one-off / developer said skip

Upkeep tasks run:
- cm diff — <result>
- cma (apply) — <result or skipped reason>
- Specs archived — <list>
```

---

## What NOT to extract

- Patterns already in developer-preferences.md
- IDE or formatter preferences (those go in editor config)
- Debug steps or investigation notes (those go in ideaLog, not preferences)
- Anything the developer said was a mistake
- Bitwarden vault structure or secret item names (those are data, not patterns)
- Tool installation steps (those go in Ansible playbook or bootstrap script, not preferences)
