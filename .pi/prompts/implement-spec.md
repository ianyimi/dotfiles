---
name: implement-spec
description: Execute an approved spec plan step by step, verifying changes after each task. Workflow-tier aware — low-care tier allows full implementation without pausing.
invoke: "implement-spec"
---

# Implement Spec

Execute an approved spec plan for **chezmoi dotfiles**, implementing each task in sequence with mandatory verification before reporting completion.

**Workflow tier:** Agent can implement fully. Make changes directly to dotfiles, scripts, and configurations.

> **Questions:** Use the `ask_user_question` tool for every question in this skill. Never write question lists as plain text.

---

## Process

### Step 1 — Identify the spec

Check `.pi/agent-docs/specs/` for available specs. Look for folders containing a `plan.md`.

If multiple specs exist, ask:
> Which spec should I implement?
> <list each as: `YYYY-MM-DD-HHMM-slug` — first line of plan.md summary>

If only one spec exists, confirm:
> Implement spec: `<slug>`? Or specify a different path.

If no spec exists:
> No spec found. Run `/dev-spec` first to create one.
> Stop here.

### Step 2 — Load the plan

Read `plan.md` from the spec folder. Parse the build-order task list and present a summary:

> Loaded: **<spec name>**
> Tasks:
> <numbered list of unchecked tasks from plan.md>
>
> Ready to begin? Or review the full plan first?

Also read:
- `shape.md` — file structures, template patterns, and numbered implementation comments
- `standards.md` — conventions that apply to this spec
- `references.md` — files and docs to read before implementing

### Step 3 — Execute tasks in build order

For each unchecked task in `plan.md`:

#### Announce
> Starting task <N>: <task title>

#### Implement
Follow `shape.md` for the exact file paths, template syntax, and numbered implementation comments. Do not deviate from the shape unless blocked.

Apply conventions from `standards.md`. Reference docs from `references.md` when implementing unfamiliar patterns (chezmoi templating, Bitwarden CLI, Ansible tasks).

#### Verify after each task

<!-- sync-spec:verify-commands -->
**Verification commands for dotfiles:**

1. **Preview changes**
   ```bash
   cm diff
   ```
   Confirms what files would be modified or created by the change.

2. **Apply changes** (conditional)
   ```bash
   cma
   ```
   Runs full apply workflow (Bitwarden session check, sync, apply, reload shell).
   
   **Skip if:**
   - Bitwarden session is not active (`bw unlock --check` fails)
   - Changes are safe to defer until manual `cma` run (e.g., documentation, comments)

3. **Verify specific functionality**
   - For shell aliases: source the file and run `type <alias>` to confirm
   - For tmux configs: `tmux source-file ~/.tmux.conf` if tmux is running
   - For scripts: run the script in dry-run mode if available, or verify syntax with `bash -n <script>`
<!-- /sync-spec:verify-commands -->

Run the verify commands above after completing each task. If they fail:
- If you caused the failure — fix it before marking the task complete
- If it's pre-existing or environment-specific — note it, do not attempt to fix unrelated failures

#### Mark complete in plan.md

Tick the checkbox for the completed task in `plan.md` immediately after verification passes.

#### Report
> ✓ Task <N> complete: <title>
> Files: <created/modified list>
> Verification: cm diff clean | cma applied successfully | skipped (no session)
> Moving to task <N+1>...

### Step 4 — Handle blockers

If a task cannot be completed as specified, stop and ask:
> Blocked on task <N>: <title>
>
> Issue: <what specifically is preventing progress>
>
> Options:
> A) <alternative approach>
> B) Skip this task, note it for follow-up
> C) Modify the plan (describe what to change)

**Common blockers in dotfiles:**
- Missing Bitwarden secret (can't test template until secret exists)
- Platform-specific tool not installed (e.g., Linux-only tool on macOS)
- chezmoi template syntax error (review template docs)

### Step 5 — Handle deviations

**Minor** (different filename, extra comment, small refactor): make the change, note it in the completion report. No approval needed.

**Significant** (different template structure, approach doesn't work, new dependency needed): report it and note the deviation. On low-care tier, implement the better approach and document why.

**New tasks discovered**: add them to `plan.md` as additional checkboxes at the appropriate position in build order.

### Step 6 — Workflow tier behavior

<!-- sync-spec:workflow-tier-detail -->
**Low-care tier behavior:**
- Agent implements all tasks independently
- No pause for review between tasks (unless blocked or significant deviation)
- Agent reports progress but continues automatically
- Exception: Never create or modify Bitwarden secrets without explicit approval
- Exception: Platform-specific changes on darwin/ or linux/ should confirm target platform if ambiguous
<!-- /sync-spec:workflow-tier-detail -->

### Step 7 — Final summary

After all tasks complete and verification passes:

> ✓ Implementation complete
>
> Spec: <name>
> Tasks: <N>/<N> complete
> Verification: cm diff clean, cma applied successfully
>
> Files created: <list>
> Files modified: <list>
> Platform: darwin | linux | both
>
> Next: run `/sync-spec` to extract patterns and close the spec.

---

## What to avoid

- Never skip the verify step — always run `cm diff` before marking complete
- Never implement tasks out of build order (dependencies matter)
- Never create or reference new Bitwarden secrets without approval (spec must document them first)
- Never modify files outside the spec's stated scope without asking first
- Never apply changes that break existing machines (backward compatibility rule)
- Never commit actual secrets (only commit .tmpl templates that reference Bitwarden)
