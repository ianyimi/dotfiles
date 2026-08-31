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

# 2026-08-21-pull-mattpocock-tier1 — Tasks

## T1 — Frontier protocol in dev-spec interview
Why: Serial questioning hides assumptions and wastes round-trips; batched frontier
questions with recommended answers surface every inference for veto.
Verify: test $(grep -c "frontier" .agent/skills/dev-spec/references/interview.md) -ge 3 && grep -q "a decision — ask" .agent/skills/dev-spec/references/interview.md
- [x] Rewrite `.agent/skills/dev-spec/references/interview.md` — add Frontier protocol
      section; keep Intent/Shape/Constraints phases and Closing intact

## T2 — Reproduction-loop gate in debug
Why: A hypothesis without a red-capable reproduction command is unfalsifiable; tagged
instrumentation makes cleanup a single grep; regression tests stop reoccurrence.
Verify: grep -q "DEBUG-" .agent/skills/debug/SKILL.md && grep -q "reproduction loop" .agent/skills/debug/SKILL.md && test $(wc -l < .agent/skills/debug/SKILL.md) -le 150
- [x] Edit `.agent/skills/debug/SKILL.md` — insert reproduction-loop step before the
      hypothesis step; add instrumentation-hygiene step; extend verify step with
      regression-test gate

## T3 — Design-smell baseline + block/warn split in polish
Why: The checklist audits correctness but has no structural-quality floor; the Fowler
smell baseline catches design rot, and an explicit block/warn split makes the verdict
unambiguous.
Verify: grep -q "Design smells" .agent/skills/polish/references/polish-checklist.md && grep -q "BLOCKING" .agent/skills/polish/references/polish-checklist.md
- [x] Edit `.agent/skills/polish/references/polish-checklist.md` — add Design smells
      (baseline) section; tag every section blocking vs warn; update output format

## T4 — Reference-never-duplicate rule in summary-prompt
Why: Copied spec/diff content bloats handoffs and goes stale; paths and hashes stay true.
Verify: grep -q "never copy" .agent/skills/summary-prompt/SKILL.md
- [x] Edit `.agent/skills/summary-prompt/SKILL.md` — add the reference-not-copy rule to
      step 2

## T5 — writing-for-agents shared reference
Why: The harness has no authoring guidance for its own skills/pointers; init,
harness-advisor, and harness-pull all write skill prose and need shared rules.
Verify: test -f .agent/skills/shared-references/writing-for-agents.md && grep -q "writing-for-agents" .agent/docs/harness-guide.md
- [x] Create `.agent/skills/shared-references/writing-for-agents.md`
- [x] Add pointer in `.agent/docs/harness-guide.md` Editing rules

## T6 — Regenerate + sync
Why: `.agent/` sources changed; bridges and index are generated artifacts.
Verify: harness doctor
- [x] Run `harness index rebuild`, `harness struct`, `harness sync`, `harness doctor`
