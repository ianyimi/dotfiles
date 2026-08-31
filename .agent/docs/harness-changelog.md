# Harness Changelog

Append-only audit of harness changes made from developer feedback. One line each:
date, file(s), change, trigger quote.

- 2026-08-21 — .agent/skills/commit/SKILL.md + references/session-log-format.md — commit
  skill now renames session-log entry titles to the commit title after message generation,
  and appends the title (comma-separated) to earlier relevant sessions; log format rule
  updated to permit title-only renames — "help me keep track of which sessions went with
  which commits so ... i can resume the agent session by name of the commit title".
- 2026-08-21 — .agent/skills/commit/SKILL.md — step-8 summary now prints a rename receipt
  (`old → new` per entry) ending with "Session names updated — safe to close this session"
  — "the agent must also acknowledge when the session names have been renamed so its safe
  for me to close the current session".
- 2026-08-21 — .agent/skills/resume-session/SKILL.md (new) + session-log-format.md —
  /resume-session <commit title>: compacts relevant similarly-named sessions into a resume
  brief and opens a new entry under the same name; simple v2/v3 suffix only on
  developer-requested rework — "a version bump will only happen if the feature is being
  significantly redone ... first version upgrade will be v2, then v3".
- 2026-08-21 — harness/src/templates/skills/* — ported today's session changes into the REAL
  upstream (templates): frontier interview.md, debug reproduction loop, polish smell baseline,
  summary-prompt reference-never-copy, writing-for-agents (new), commit rename step + receipt
  (adapted to ledger flow), session-log-format title rules, resume-session (new shipped
  skill). Root .agent edits alone never reach projects — maprios pull surfaced this.
- 2026-08-21 — .agent/skills/harness-cherry-pick/SKILL.md (new, main-repo only) — reusable
  process for reviewing external harness repos and merging techniques (never paradigms) into
  both layers — "turn this process we just did into a skill ... cherry pick features from
  other agent harnesses while maintaining the core pieces of my workflow".
- 2026-08-21 — .agent/AGENTS.md — new "Harness edits land in harness/src/templates/"
  directive + "Repo layout — where edits go" section (main harness = harness/ folder;
  .agent/ = this repo's local clone; nested dotfile harnesses off-limits) — "almost all
  edits i will want in the harness template files and generalized ... when i refer to the
  main harness i am referring to the harness folder".
