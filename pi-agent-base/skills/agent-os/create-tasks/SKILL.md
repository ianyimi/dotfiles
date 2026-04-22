---
name: create-tasks
description: Break down a spec.md or requirements.md into an actionable tasks.md with strategic grouping and ordering. Used after spec creation and before implementation.
---

# Task List Creation Process

Break down a given spec and requirements into an actionable tasks list.

## Phase 1: Get the Spec

You will need ONE OR BOTH of these files:
- `agent-os/specs/[this-spec]/spec.md`
- `agent-os/specs/[this-spec]/planning/requirements.md`

If you don't have either file in context, ask:

```
I'll need a spec.md or requirements.md (or both) in order to build a tasks list.

Please direct me to where I can find those. If you haven't created them yet, you can run /dev-spec first.
```

## Phase 2: Create tasks.md

Once you have the spec and/or requirements, break them down into an actionable tasks list with strategic grouping and ordering.

**Task ordering principles:**
- Dependencies first — if Task B requires Task A's output, A comes before B
- Infrastructure before features — setup, scaffolding, config first
- Core logic before integration — implement the thing before wiring it up
- Tests alongside implementation — never batch tests at the end

**Task format:**

```markdown
# Tasks: [Spec Name]

## Phase 1: [Logical grouping name]

- [ ] **Task 1.1** — [Short action-oriented description]
  - [Sub-step if needed]
  - [Sub-step if needed]
  
- [ ] **Task 1.2** — [Short action-oriented description]

## Phase 2: [Next grouping]

- [ ] **Task 2.1** — [Description]
```

Save to `agent-os/specs/[this-spec]/tasks.md`.

## Phase 3: Inform User

```
Your tasks list is ready!

✅ Tasks list created: `agent-os/specs/[this-spec]/tasks.md`

NEXT STEP 👉 Run `/implement-spec` to start building.
```
