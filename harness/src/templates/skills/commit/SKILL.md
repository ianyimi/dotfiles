---
name: commit
description: Generate a commit message from today's session log and update project documents at
  the end of a work session. Triggers on "commit", "/commit", "generate commit message", "wrap
  up this session". Honors manifest.json#workflow.commit_mode — "message-only" presents the
  message for lazygit; "agent-commits" stages and commits after confirmation.
harness_model_role: smol
---

# Commit

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.

## Steps

1. **Read the mode.** `workflow.commit_mode` in `.agent/manifest.json`: `"message-only"`
   (default) or `"agent-commits"`.
2. **Ensure today's log entry.** Run `harness log session-end`. It creates today's entry if
   missing and prints four questions. If the entry's sections are empty, ask the developer
   those questions (structured question tool if available — `ask_user_question` /
   `AskUserQuestion` — else a plain numbered list) and write the answers into the printed path.
   Append into today's entry only — never rewrite earlier entries. Load
   `references/session-log-format.md` for the entry format.
3. **High-care projects:** if `workflow.default_tier` is "high-care" and code changed since the
   last sync-spec run, suggest running the sync-spec skill first (it extracts patterns and
   updates standards). Continue if the developer declines.
4. **Generate the message.** Run `harness log commit-msg`. Review against the rules in
   `references/session-log-format.md`; if type/scope/title reads wrong, edit
   `.agent/docs/session-log/YYYY/MM/YYYY-MM-DD.commit.md` directly (title ≤ 72 chars, body says
   why — never a file list).
5. **Update project documents** (consult `manifest.json#modules`; proposal §12 step 3):
   - `docs/product/roadmap.md` — tick milestone tasks completed this session (modules.roadmap)
   - `docs/tasks.md` — move finished tasks to "## Recently Done" (modules.tasks)
   - `docs/decisions/` — if today's "Decisions made" holds an architectural decision not yet
     recorded, ask whether to write an ADR now (modules.decisions)
   - new files created this session → run `harness struct` (refreshes directory-structure.md)
   Collect every change for the step-8 summary. Nothing is silently changed.
6. **Regenerate state.** Run `harness state`.
7. **Commit — by mode.**
   - `message-only`: present the message ready to copy. The developer stages + commits via
     lazygit and pastes it. Do NOT run `git commit`.
   - `agent-commits`: show `git status --porcelain`; confirm the exact file list with the
     developer (structured question tool). On confirmation:
     `git add <files> && git commit -F .agent/docs/session-log/YYYY/MM/YYYY-MM-DD.commit.md`,
     then `harness log backfill-sha --sha "$(git rev-parse HEAD)"`.
8. **Summary.** "Updated: [files]. Needs your attention: [list]." Include the commit message
   (message-only) or the new commit SHA (agent-commits).
