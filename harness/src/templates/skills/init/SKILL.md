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
2. Run `harness init scaffold` (idempotent — creates `.agent/` skeleton + this skill set).
3. Run `harness init status`. If phases are already complete, announce "Resuming setup from
   Phase N" and skip completed phases.

## Using a Template

If the developer named a template ("use the <name> template", `--template <name>`):
1. `harness template list` — if the name is missing, show the list and stop.
2. Run `harness init scaffold --template <name>` instead of plain scaffold.
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
skip and submit `{ "naming_conventions_md": "" }`. See `references/naming-interview.md`
(available once spec 02 skills are installed) for the question set.

## Finish (phase 10)

1. `harness init finish` — validates phases 1–9, writes the real AGENTS.md, deletes progress.
2. Run `harness sync` if available (generates platform bridges), then `harness index rebuild`
   if available.
3. Report: what was created, what the developer can delete from any old harness, next steps.
