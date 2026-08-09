# Session Log Format

## The file
`.agent/docs/session-log/YYYY/MM/YYYY-MM-DD.log.md` — an append-only diary. One file per day,
one `##` entry per work block. Created/extended only via `harness log append`. The single
permitted in-place edit is `harness log backfill-sha` filling `**Commit:** (pending)`.

## Entry structure (`harness log append` emits this skeleton)

    ## 2026-08-02 — 14:23 — filter panel wiring

    **Spec:** docs/specs/2026-07-12-collections-ui/spec.md (Step 4)
    **Commit:** (pending)

    ### What was built
    - `FilterPanel.tsx` — filter panel wired to TanStack Table

    ### Decisions made
    - Used nuqs instead of useState — URL-shareable filters matter here. Not in the spec;
      low-risk addition.

    ### Problems hit
    - nuqs `parseAsArrayOf` not exported in v2 — used `parseAsJson`. Library quirk, not our bug.

    ### Where I left off
    Empty state test failing: fix the test selector, not the component. Resume there.

## Field rules
- **Spec:** path (+ step) of the driving spec, or `(none)` for ad-hoc work.
- **Commit:** stays `(pending)` until the commit exists; `backfill-sha` fills it
  (automatic in agent-commits mode; message-only leaves it for the next session).
- Bullets state *why*, not just what. Problems record the resolution, not only the pain.
- "Where I left off" is for a cold-start reader: current state, next step, watch-outs.

## Commit message rules (`harness log commit-msg` output)
- Title `type(scope): description`, ≤ 72 chars. Types: feat, fix, docs, refactor, test.
  Scope = workspace package dir (omitted outside a workspace).
- Body: the "What was built" bullets, then `Why:` + the "Decisions made" bullets.
- Explain why, never list files — the diff already lists files.
