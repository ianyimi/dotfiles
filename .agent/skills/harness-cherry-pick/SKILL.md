---
name: harness-cherry-pick
description: Cherry-pick techniques from an external agent harness/skills repo into THIS
  upstream harness. Triggers on "/harness-cherry-pick <repo url>", "review this harness repo",
  "pull ideas from <repo>", "cherry pick from <repo>". Adopts techniques, never paradigms —
  the existing workflow is the filter, not the thing being replaced. MAIN REPO ONLY: this
  skill is not shipped to projects.
harness_model_role: slow
---

# Harness Cherry-Pick

Review an external harness/skills repository and merge the genuinely valuable techniques
into this upstream harness, preserving the core workflow (dev-spec → implement → polish →
sync-spec → commit, CLI-backed state, knowledge graph) exactly as it is.

**The two layers — every adoption lands in BOTH:**
- `harness/src/templates/skills/` — the REAL upstream `harness fetch` ships to projects.
  A change that misses this layer never reaches any project.
- `.agent/skills/` — this repo's own local clone (dogfood copy).
Template copies may diverge from `.agent/` copies (either side can be ahead) — port edits
onto each side's actual content, never blind-copy one over the other.

## Preflight
1. Run `harness doctor`; fix 🔴 errors. Run `harness state`.
2. Read `.agent/docs/harness-guide.md` if not already loaded this session.

## Steps

1. **Scout both sides in parallel** (subagents; read-only):
   - External repo: per skill — core mechanism, phase gates, verbatim quotes of the
     strongest prompt patterns, what is genuinely novel vs generic.
   - Own harness: per skill — phases, gates, interview style, verification, where
     knowledge is written; flag weak spots the external repo might strengthen.
2. **Filter for fit.** For each candidate technique:
   - *Technique* (a rule, gate, checklist, phrasing, or protocol that slots into an
     existing skill) → candidate. *Paradigm* (its own state, tracker, file conventions,
     or workflow it wants the harness to orbit) → reject; running two systems is worse
     than either alone.
   - A second convention beside an existing one is PROHIBITED — if we already solve the
     problem, adopt only what measurably strengthens our solution, or skip.
   - A new skill is allowed ONLY if small, self-contained, and serving the existing
     workflow (litmus: it needs no new state files and no new developer habits).
3. **Present the plan, tiered.** Tier 1 (merge into existing skills — high value),
   Tier 2 (optional, adopt on demand), Rejected (say why — paradigm mismatch, overlap,
   different workflow). Per item: target file, what is taken, what is deliberately NOT
   taken. Wait for the developer to narrow the cut list — never start editing from the
   review turn.
4. **Spec it.** Run the dev-spec skill over the approved list. The spec carries the full
   drafted content of every edit (these are doc changes — the content IS the code), one
   task group per target skill, rejections recorded under Design Decisions.
   `Verify:` lines must each be a single executable shell command.
5. **Implement** via the implement skill. Then port every adopted change into
   `harness/src/templates/skills/` (adapting to template-side divergence), run the
   harness CLI test suite, and `harness index rebuild` + `harness sync` + `harness doctor`.
6. **Record.** Append to `.agent/docs/harness-changelog.md` (source repo, files, one line
   per adoption + the trigger). Remind the developer: projects take these with
   `/harness-pull`; skills also live behind `harness install --refresh-skill` (overwrite).

## Rules
- The external repo is read-only research — never vendor its files wholesale; every
  adopted line is rewritten in this harness's voice and conventions
  (`shared-references/writing-for-agents.md`).
- Verbatim quotes are allowed only when the phrasing itself is the technique.
- Rejections are deliverables: record them so the next cherry-pick doesn't re-litigate.
- Mind budgets: SKILL.md ≤ 150 lines (`manifest.json#doctor.budgets`).
