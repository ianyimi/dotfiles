---
name: init
description: Initialize or update the agent harness for a project. Triggers on "harness init",
  "init the harness", "set up the agent harness", "initialize this project". Drives the
  10-phase interview; all file writes go through `harness init` CLI primitives.
---

# Harness Init

## Preflight

1. If `.agent/manifest.json` EXISTS: ask the developer — re-init (full rebuild) or update
   specific sections? For update mode, jump only to the phases they name.
2. Run `harness install` (idempotent — creates `.agent/` skeleton + this skill set).
3. Run `harness init status`. If phases are already complete, announce "Resuming setup from
   Phase N" and skip completed phases.

## Opening question — trusted context (before any inference)

Ask the developer FIRST: "Which documents or files do you KNOW are current and authoritative
(goals, roadmaps, architecture notes, critical context)? Anything I should distrust as stale?"
Read every trusted document before inferring anything — they are the accuracy baseline for the
whole setup, and existing agent docs are verified AGAINST them and against the code
(see references/inference.md — mined docs are drafts to verify, never facts to migrate).

## Using a Template

If the developer named a template ("use the <name> template", `--template <name>`):
1. `harness template list` — if the name is missing, show the list and stop.
2. Run `harness install --template <name>` instead of plain scaffold.
3. `harness init status`: phases marked `prefilled (confirm or edit)` carry staged data from
   the template. Skip codebase inference for those phases — present the staged block as the
   draft, confirm or edit, then `harness init write-phase <n> --data -` as usual.
4. Phase 6 staged deps have no versions: re-resolve each from THIS project's manifest files
   before submitting. All other phases proceed normally (see references/phases.md).

## The Loop (phases 1–9)

For each phase, in order:

1. Read the phase's section in `references/phases.md` (questions + data shape).
2. Infer everything you can from the codebase first — `references/inference.md` tells you
   what to detect per phase. Never ask about what you can infer; present it for confirmation.
3. Present the draft. Confirm or correct with the developer (use the structured question tool
   if available — `ask_user_question` / `AskUserQuestion` — otherwise a plain numbered list).
4. On confirmation, write immediately:
   `harness init write-phase <n> --data -` (JSON on stdin, shape per phases.md).
   Never accumulate phases — progress must survive context compaction.

Phase 8 (naming conventions) applies to high-care projects; for low-care projects confirm the
skip and submit `{ "naming_conventions_md": "" }`. See `references/naming-interview.md` for the
question set.

## Commit gate (after phase 9)

`/commit` is the final command before code goes upstream. Show the developer the default
checklist (`.agent/skills/commit/references/commit-checklist.md`, installed by scaffold),
pre-filled with THIS project's build/test commands from phase 5 and module-gated items from
phase 7. Ask: what else must be checked or updated on every commit? What should be removed?
Write the result back to that file.

## Discovery pass (after the commit gate, before finish)

Read `references/discovery.md`. Mine any EXISTING agent setup first (`.pi/agent-docs/**`,
`.claude/commands/`, `CLAUDE.md`/`AGENTS.md`) — **verify every claim against the code before
adopting; report drift**. Then sweep the ENTIRE codebase: fan out one subagent per standards
domain (default wherever the platform supports subagents; serial otherwise) and reconcile
their proposals. Present a summary of every file created or extended before moving on. The
harness stays living after init: add `harness tasks add "…" --to inbox` follow-ups for any
area you deferred — future sessions continue the investigation via sync-spec.

## Finish (phase 10)

1. `harness init finish` — validates phases 1–9, writes the real AGENTS.md + the harness guide
   + `docs/setup-report.md`, deletes progress.
2. Run `harness sync` (bridges + code map), then `harness index rebuild` + `harness struct`.
3. Append your discovery summary to `docs/setup-report.md` (its final section), then present
   the report path to the developer: it explains everything configured and how agents will use
   the harness — invite questions, corrections, and change requests.
