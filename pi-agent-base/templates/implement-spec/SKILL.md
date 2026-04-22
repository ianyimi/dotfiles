---
name: implement-spec
description: Execute an approved spec plan step by step, verifying build and tests after each task. Language-agnostic. Workflow-tier aware — pauses at significant decisions on high-care projects.
invoke: "implement-spec"
---

# Implement Spec

<!-- SETUP:CHECK
  If this file still contains {{PROJECT_NAME}} (unreplaced), the project harness
  has not been initialized. Tell the user:

  "Run `/0-project-init` first — it will configure this prompt for your
  project's verification commands and workflow tier."

  Then stop.
-->

Execute an approved spec plan for **{{PROJECT_NAME}}**, implementing each task in sequence with mandatory verification before reporting completion.

**Workflow tier:** {{WORKFLOW_TIER_RULE}}

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
> No spec found. Run `/skill:dev-spec` first to create one.
> Stop here.

### Step 2 — Load the plan

Read `plan.md` from the spec folder. Parse the build-order task list and present a summary:

> Loaded: **<spec name>**
> Tasks:
> <numbered list of unchecked tasks from plan.md>
>
> Ready to begin? Or review the full plan first?

Also read:
- `shape.md` — types and function stubs to implement from
- `standards.md` — conventions that apply to this spec
- `references.md` — files and docs to read before implementing

### Step 3 — Execute tasks in build order

For each unchecked task in `plan.md`:

#### Announce
> Starting task <N>: <task title>

#### Implement
Follow `shape.md` for the exact signatures, stubs, and numbered implementation comments. Do not deviate from the shape unless blocked.

Apply conventions from `standards.md`. Reference docs from `references.md` when implementing unfamiliar APIs.

#### Verify after each task

<!-- sync-spec:verify-commands -->
{{VERIFY_COMMANDS}}
<!-- /sync-spec:verify-commands -->

Run the verify commands above after completing each task. If they fail:
- If you caused the failure — fix it before marking the task complete
- If it's pre-existing — note it, do not attempt to fix unrelated failures

#### Mark complete in plan.md

Tick the checkbox for the completed task in `plan.md` immediately after verification passes.

#### Report
> ✓ Task <N> complete: <title>
> Files: <created/modified list>
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

Do not attempt workarounds without approval on high-care projects.

### Step 5 — Handle deviations

**Minor** (different filename, extra import, small refactor): make the change, note it in the completion report. No approval needed.

**Significant** (different architecture, missing dependency, approach doesn't work): stop and ask before proceeding. Update `plan.md` if the approach changes.

**New tasks discovered**: ask whether to add them to this spec or note them for a future spec.

### Step 6 — Workflow tier behavior

<!-- sync-spec:workflow-tier-detail -->
{{WORKFLOW_TIER_DETAIL}}
<!-- /sync-spec:workflow-tier-detail -->

### Step 7 — Final summary

After all tasks complete and verification passes:

> ✓ Implementation complete
>
> Spec: <name>
> Tasks: <N>/<N> complete
> Verification: <commands run and result>
>
> Files created: <list>
> Files modified: <list>
>
> Next: run `/skill:sync-spec` to extract patterns and close the spec.

---

## What to avoid

- Never skip the verify step — always run `{{VERIFY_COMMANDS_SHORT}}` before marking complete
- Never implement tasks out of build order (shape.md defines the order for a reason)
- Never modify files outside the spec's stated scope without asking first
- Never leave failing tests caused by your changes
