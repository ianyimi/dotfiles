---
name: 1-dev-spec
description: Write a scoped implementation spec for a feature or change. Produces plan.md, shape.md, standards.md, and references.md in .pi/agent-docs/specs/. Evolves per project via sync-spec.
invoke: "dev-spec"
---

# Dev Spec

<!-- SETUP:CHECK
  If this file still contains {{PROJECT_NAME}} (unreplaced), the project harness
  has not been initialized. Tell the user:

  "This project hasn't been set up yet. Run `/0-project-init` from the project
  root first — it will customize this prompt for your stack and workflow."

  Then stop. Do not proceed with spec writing until setup is complete.
-->

---

## Project Context

**Project:** {{PROJECT_NAME}}
**Stack:** {{TECH_STACK_SUMMARY}}
**Workflow tier:** {{WORKFLOW_TIER_RULE}}

<!-- sync-spec:dev-commands -->
**Dev commands:**
{{DEV_COMMANDS}}
<!-- /sync-spec:dev-commands -->

<!-- sync-spec:monorepo-packages -->
{{MONOREPO_PACKAGES}}
<!-- /sync-spec:monorepo-packages -->

---

## When to use

Run `dev-spec` when starting any non-trivial feature, change, or fix. The spec is the contract between you and the agent — it defines exactly what gets built before any code is written.

Skip dev-spec only for: typo fixes, config tweaks, single-line changes where the implementation is obvious.

---

> **Questions:** Use the `ask_user_question` tool for every question in this skill. Never write question lists as plain text.

## Spec interview

Use `ask_user_question` for every question in this section. Never write question blocks as plain text.

### Phase 1 — Scope

Ask:
> What are we building? Give a one-line description of the feature or change.

Ask:
> What files, modules, or packages will this touch? (Best guess — we'll refine.)

Ask:
> Are there any parts of the codebase this spec must NOT touch?

Ask:
> Is there an existing spec for this in `.pi/agent-docs/specs/`? If yes, are we continuing or starting fresh?

### Phase 2 — Shape

Ask:
> What are the inputs and outputs? (Data flowing in, data flowing out, side effects.)

Ask:
> Are there any new types, interfaces, or data structures needed?

Ask:
> What are the edge cases? (Empty states, errors, permission boundaries, concurrent access, missing data.)

### Phase 3 — Standards check

Read `.pi/agent-docs/standards/developer-preferences.md`. For each preference that applies to this spec, note it. Do not ask the developer to re-confirm standing rules — just apply them.

If a preference is ambiguous for this specific feature, ask one targeted question.

### Phase 4 — References

Identify files the developer will need to read before implementing:
- Existing files being modified
- Related types/interfaces
- Library docs for unfamiliar APIs used in this spec
- Recent ideaLog entries that affect this feature

---

## Build order rule

Specs must be ordered so each step produces something runnable or testable before the next step begins. Never spec leaf functions before their callers, never spec a UI component before its data contract exists.

**Build order:**
1. Types and interfaces first (no implementation, pure shape)
2. Entry point / top-level function stub (compiles, does nothing yet)
3. Data layer (DB queries, API calls, state mutations) — with tests
4. Business logic — with tests
5. UI / presentation layer last (if applicable)

After drafting the spec, self-check: can the developer implement step N and run the project without breaking anything before step N+1 is done? If not, reorder.

---

## Spec output format

Create `.pi/agent-docs/specs/YYYY-MM-DD-HHMM-<feature-slug>/` with four files:

### plan.md

```markdown
# <Feature Name> — Plan

## Summary
<one paragraph — what this builds and why>

## Build Order
- [ ] Step 1: <what + testable outcome>
- [ ] Step 2: <what + testable outcome>
- [ ] Step 3: <what + testable outcome>
...

## Out of scope
- <thing explicitly excluded>
```

### shape.md

Full boilerplate the developer should not have to write:
- Type definitions and interfaces (complete, not stubs)
- Function signatures with parameter types and return types
- Re-exports and barrel file additions
- Implementation guidance inside function bodies as numbered comments:

```typescript
// 1. Validate input — throw if userId is missing or malformed
// 2. Fetch user from DB — handle not-found as null, not error
// 3. Check permission — return 403 shape if role < required
// 4. Apply mutation
// 5. Return updated record
```

Language-specific rules:
- TypeScript: full types, no `any`, no `as` casts
- Rust: trait bounds, error types, lifetime annotations where needed
- Go: interface definitions, error wrapping pattern
- Python: type hints on all public functions, dataclasses for shapes
- Other: use whatever the language's idiomatic shape/contract mechanism is

### standards.md

```markdown
# Standards for This Spec

## Applied preferences
<list each rule from developer-preferences.md that applies here>

## Spec-specific conventions
<any one-off rules for this feature>

## Known gotchas
<edge cases or constraints the developer must not forget>
```

### references.md

```markdown
# References

## Files to read before implementing
- `<path>` — <why>

## Library docs
- `<library>` — <specific thing to check>

## Related specs
- `<path>` — <relationship>
```

---

## Workflow tier behavior

{{WORKFLOW_TIER_RULE}}

<!-- sync-spec:workflow-tier-detail -->
{{WORKFLOW_TIER_DETAIL}}
<!-- /sync-spec:workflow-tier-detail -->

---

## After presenting the spec

Ask:
> Does this spec look right? Anything to add, remove, or change before you start implementing?

On approval, say:
> Spec saved to `.pi/agent-docs/specs/YYYY-MM-DD-HHMM-<slug>/`. Run `sync-spec` when you're done implementing.

Do not begin implementation. The developer implements. The agent's job ends when the spec is approved.

---

## Developer preferences

<!-- sync-spec:developer-preferences -->
_No preferences recorded yet. Run `sync-spec` after your first implementation to start building this section._
<!-- /sync-spec:developer-preferences -->

---

## Continuous improvement

This file evolves. Every `sync-spec` run extracts patterns from how the developer actually implemented things versus what was specced, and updates the `<!-- sync-spec:* -->` sections above. Over time, specs require fewer corrections and generated shapes closer match what ships.

→ see `.pi/agent-docs/standards/developer-preferences.md` for the full audit trail
