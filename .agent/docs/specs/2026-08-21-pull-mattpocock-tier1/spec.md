---
status: draft
spec_id: 2026-08-21-pull-mattpocock-tier1
touches:
  - ".agent/skills/dev-spec/references/interview.md"
  - ".agent/skills/debug/SKILL.md"
  - ".agent/skills/polish/references/polish-checklist.md"
  - ".agent/skills/summary-prompt/SKILL.md"
  - ".agent/skills/shared-references/writing-for-agents.md"
  - ".agent/docs/harness-guide.md"
prompt_version: 1
---

# 2026-08-21-pull-mattpocock-tier1 — Spec

## Overview

Merge five techniques from mattpocock/skills into this upstream harness: frontier-batched
interviewing (dev-spec), a reproduction-loop gate with instrumentation hygiene (debug), a
design-smell baseline with a block/warn split (polish), a reference-never-duplicate rule
(summary-prompt), and a writing-for-agents authoring reference (shared-references +
harness-guide pointer). All edits strengthen existing skills in place — no new paradigms,
no new top-level skills. Projects take these via `/harness-pull`.

## Design Decisions

1. **Frontier protocol lives inside the existing three phases** — Intent/Shape/Constraints
   stays as the decomposition; batching applies within each phase. Keeps our structure,
   gains his round-trip economy.
2. **Fact/decision litmus with ask-on-doubt default** — misclassification cost is
   asymmetric: a wasted question costs seconds, a wrongly inferred decision costs a
   rebuilt spec.
3. **Facts are reported above the question batch** — every lookup that shaped a question
   is stated, so a wrong "fact" is correctable, and inference is auditable.
4. **Debug: a red-capable reproduction command gates hypothesis** — no theory without a
   falsifier; deterministic 2-second loop is the target, 100× runs for flaky bugs.
5. **Regression test gated on existing test infra** — many harness projects (dotfiles
   included) have no suite; the gate is "when a suite exists and the bug had no covering
   test", never "invent test infrastructure".
6. **Smell baseline is subordinate to project standards** — `docs/standards/` always
   overrides the baseline; the baseline only fills gaps standards don't cover.
7. **Block/warn split, not a third severity** — blocking = correctness/spec violations,
   warn = judgment calls; matches polish's existing ✅/⚠️ output shape.
8. **Two-axis parallel-subagent review REJECTED** — polish stays single-pass,
   suggest-only; splitting into parallel Standards/Spec subagents restructures the skill
   for marginal gain at this scale.
9. **writing-for-agents is a shared reference, not a skill** — it is authoring guidance
   consulted by init/harness-advisor/harness-pull, not a triggered workflow.
10. **Spec drafted in one pass despite 6 task groups** — content derives from decisions
    made in this conversation which subagents cannot see; every group is a small doc edit.
11. **Tier: agent implements** — all groups are `[agent]`; markdown-only, full content
    below, developer reviews the diff.

## Out of Scope

- wayfinder / triage / to-tickets (issue-tracker-centric planning — paradigm mismatch)
- CONTEXT.md domain glossary (competes with naming-conventions.md + preferences.md)
- improve-codebase-architecture HTML reports, prototype, wizard, wait-what, grill-me
- resolving-merge-conflicts skill and TDD reference in implement (Tier 2 — separate spec
  if wanted)
- phase-boundaries decision doc (Tier 2)
- Downstream project updates (each project pulls via `/harness-pull` on its own schedule)

## Implementation

### T1 — Frontier protocol in dev-spec interview

- [ ] `[agent]` Replace `.agent/skills/dev-spec/references/interview.md` with:

```markdown
# Dev-Spec Interview — Question Phases

Run the phases in order. Within each phase, batch questions with the frontier protocol.
Close each phase by restating the answers; close the interview with a confirmed summary.

## Frontier protocol

The phase's open points form a tree of decisions; some depend on others. Each round:

1. **Split every open point: fact or decision.**
   - *Fact* — a tool call could settle it with certainty (does a helper already exist?
     what does `harness state` say? which plugin manager is configured?). Facts are YOUR
     job: look them up, or dispatch a subagent while the developer answers decisions.
     Never ask the developer for anything you could look up yourself.
   - *Decision* — two reasonable developers would answer differently (preference,
     tradeoff, intent). Decisions ALWAYS go to the developer, never inferred.
   - Unsure which side? It's a decision — ask. A wasted question costs seconds; a
     wrongly inferred decision costs a rebuilt spec.
2. **Ask the whole frontier at once** — every decision whose prerequisites are settled
   goes in one numbered batch (structured question tool if available, else a numbered
   list), each question carrying a recommended answer the developer can veto in a word.
   A question whose answer depends on another question still open in this round belongs
   to a later round, not this one.
3. **Report the facts that shaped the batch** as statements above it ("Found: chezmoi
   templates already gate on `.chezmoidata`, so Q2 assumes that mechanism") so a wrong
   fact can be corrected before it warps a decision.

A phase is done when its frontier is empty — nothing left silently assumed.

## Phase 1 — Intent

- What is being built, in one sentence?
- Who or what consumes it (user-facing UI, another package, a CLI, an agent)?
- What breaks or is missing today that this fixes?

## Phase 2 — Shape

- New module, or extension of existing code? Which paths?
- Inputs and outputs (function signatures, API routes, UI surface)?
- Any data/schema changes (tables, fields, migrations)?
- Candidate `touches` globs for the spec frontmatter.

## Phase 3 — Constraints + Scope

- Hard requirements: performance, compatibility, platform, security?
- What is explicitly OUT of scope (name the adjacent features that could creep in)?
- How does the developer verify done (commands, visible behavior)?
- Tier check: high-care (developer implements — spec is guided stubs) or low-care
  (agent implements — spec is full code)? Confirm against manifest workflow.default_tier.

## Closing

Restate: intent, shape, in-scope list, out-of-scope list, verification, tier.
Get an explicit confirmation before writing anything.
```

Verify: `grep -c "frontier" .agent/skills/dev-spec/references/interview.md` ≥ 3 and
`grep -q "It's a decision — ask" .agent/skills/dev-spec/references/interview.md`

### T2 — Reproduction-loop gate in debug

- [ ] `[agent]` In `.agent/skills/debug/SKILL.md`, replace steps 5–8 of `## Steps` with:

```markdown
5. **Build the reproduction loop.** Before forming any hypothesis: one command that goes
   red on this bug. Tighten it until it is fast, sharp, and deterministic — a 2-second
   deterministic loop is the target. Flaky bug? Raise the rate (run it 100× in a loop)
   until red is reliable. Then minimize: strip the reproduction to the smallest
   input/config that still fails.
6. **Form ONE hypothesis** naming the introducing commit or decision. Verify it against
   the reproduction loop (targeted diff, or a focused run) before writing any fix.
7. **Instrument if needed.** Temporary logging carries a `[DEBUG-<slug>]` tag so cleanup
   is a single grep. All instrumentation is removed before done.
8. **Propose the minimal fix.** Prefer adjusting the introducing change over patching
   symptoms downstream. State the root cause in one sentence.
9. **Verify.** The reproduction loop goes green, plus the project's check commands
   (`.agent/docs/product/dev-processes.md`). If the project has a test suite and the bug
   had no covering test, add a regression test that would have caught it.
10. **Record it.** Append root cause + fix to today's log entry ("Problems hit"). If the
    bug revealed a lasting anti-pattern, suggest adding it to
    `docs/standards/anti-patterns.md` (mind its 40-line budget).
```

(Steps 1–4 — git protocol, session log, structure map, debug-hierarchy — unchanged.)

Verify: `grep -q "DEBUG-" .agent/skills/debug/SKILL.md`,
`grep -q "reproduction loop" .agent/skills/debug/SKILL.md`, `harness doctor` shows no
skill-over-budget error

### T3 — Design-smell baseline + block/warn split in polish

- [ ] `[agent]` In `.agent/skills/polish/references/polish-checklist.md`:
  - Under the title, add a severity legend:

```markdown
Every finding is **BLOCKING** (correctness or spec violation — must be fixed or
explicitly waived by the developer) or **WARN** (judgment call — listed, never blocks).
Section headers below carry the default severity; individual findings may be downgraded
with a one-line reason.
```

  - Tag existing sections: `## Error handling completeness [BLOCKING]`,
    `## Codepath coverage [BLOCKING]`, `## Edge cases from the spec [BLOCKING]`,
    `## Suggested improvements (lightweight only) [WARN]`.
  - After "Edge cases from the spec", insert:

```markdown
## Design smells (baseline) [WARN]

A structural-quality floor from Fowler's catalog. Project standards
(`docs/standards/`) always override this baseline — check them first; the baseline only
fills gaps the standards don't cover. Flag, with file:line:

- Mysterious Name — name requires reading the body to understand
- Duplicated Code — same logic in ≥2 places (extract or point at the existing helper)
- Feature Envy — function mostly manipulates another module's data
- Data Clumps — same group of values passed around together (wants a type)
- Primitive Obsession — domain concept passed as bare string/number
- Repeated Switches — same discriminator switched on in ≥2 places
- Shotgun Surgery — one logical change forced edits across many files
- Divergent Change — one file edited for many unrelated reasons
- Speculative Generality — abstraction with a single implementation and no second in sight
- Message Chains — `a.b().c().d()` reaching through interfaces
- Middle Man — module that only delegates
- Refused Bequest — implements an interface but stubs half of it
```

  - In the output-format example, append a `## Design Smells` section and change the
    closing line to report `N blocking. N warnings. N suggestions.`

Verify: `grep -q "Design smells" .agent/skills/polish/references/polish-checklist.md`
and `grep -q "BLOCKING" .agent/skills/polish/references/polish-checklist.md`

### T4 — Reference-never-duplicate rule in summary-prompt

- [ ] `[agent]` In `.agent/skills/summary-prompt/SKILL.md`, extend step 2:

```markdown
2. **Address the receiving agent directly** — imperative voice ("Read X. Then do Y."),
   zero references to "the previous conversation"; every fact must stand alone or cite a
   file path. **Reference, never copy**: specs, ADRs, commits, diffs, and log entries are
   cited by path or hash — inline content only when the receiving agent cannot reach the
   file (and say so).
```

Verify: `grep -q "never copy" .agent/skills/summary-prompt/SKILL.md`

### T5 — writing-for-agents shared reference

- [ ] `[agent]` Create `.agent/skills/shared-references/writing-for-agents.md`:

```markdown
# Writing for Agents — Skill & Pointer Authoring Rules

Load this before writing or editing any SKILL.md, reference doc, AGENTS.md directive, or
context pointer in this harness. The goal: predictable agent behavior comes from document
structure, not from hoping the model reads carefully.

## Context pointers

- One pointer per distinct branch of behavior. Synonyms of the same branch are ONE
  branch, written once.
- The pointer's WORDING decides how often it triggers, not the file it points to.
  Front-load the leading word ("Renaming anything? Load cascade-checks.md" beats
  "cascade-checks.md contains guidance about renames").
- A weak pointer is a variance bug: sharpen the wording first; inline the content only
  if sharpening fails.

## Information hierarchy

Three tiers, cheapest first:
1. In-file step — every branch needs it; it lives in the skill body.
2. In-file reference — consulted on demand; a section further down.
3. Disclosed reference — separate file behind a pointer; only some branches reach it.
Inline what every branch needs; push behind a pointer what only some branches reach.
Progressive disclosure protects the hierarchy — it is not just token savings.

## Co-location

Keep a concept's definition, rules, and caveats under one heading, so reading any part
brings the neighbours. Scattered rules get half-read.

## Wording

- Prompt the positive: state the target behavior, not its negation ("ask the developer"
  beats "don't guess"). A negation is a weak modifier the activated concept overruns.
- A word too weak to beat the default is a no-op ("be thorough" → "relentless"). Fix the
  word, not the sentence count.
- Completion criteria must be checkable and exhaustive — the agent can tell from its own
  trace whether it is done ("frontier is empty", not "when sufficiently explored").

## Pruning

- Single source of truth: meaning lives in one place; everything else points at it.
- The environment (config files, generated maps, `harness state`) is a source of truth
  too — cache it in prose only when the lookup is expensive.
- Hunt no-ops sentence by sentence: any line that changes no behavior is context load
  with no return. Mind the doctor budgets (`manifest.json#doctor.budgets`).
```

- [ ] `[agent]` In `.agent/docs/harness-guide.md` `## Editing rules`, append:

```markdown
5. Writing or editing any skill, reference, or context pointer? Load
   `.agent/skills/shared-references/writing-for-agents.md` first.
```

Verify: file exists; `grep -q "writing-for-agents" .agent/docs/harness-guide.md`

### T6 — Regenerate + sync

- [ ] `[agent]` `harness index rebuild`
- [ ] `[agent]` `harness struct`
- [ ] `[agent]` `harness sync`
- [ ] `[agent]` `harness doctor`

Verify: `harness doctor` — 0 errors, no sync/index warnings

## Verification

Run every per-group Verify command above, then `harness doctor` (0 errors; all skill
files within the 150-line budget). No build/test suite applies — this repo's checks ARE
the harness CLI gates.
