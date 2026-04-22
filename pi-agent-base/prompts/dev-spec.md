---
description: Create a developer-led implementation spec — full code for boilerplate and types, guided stubs for core logic, colocated tests, and strict no-speculative-code discipline. The primary spec workflow.
---

# Dev Spec — Developer-Led Implementation Spec

Create a detailed specification document designed for a developer to follow manually — providing full code for boilerplate (types, interfaces, utils, re-exports) while leaving core logic as guided function stubs with edge cases, constraints, and implementation notes.

## Philosophy

This spec format bridges AI assistance and developer ownership:
- **AI handles the tedious parts**: type definitions, interfaces, test boilerplate, file structure, re-exports
- **Developer writes the important parts**: core logic, algorithms, integration code
- **Developer maintains full context**: understands where everything lives, why decisions were made
- **Spec is a living guide**: developer changes and renames freely during implementation

## CRITICAL: No Speculative Code

**Every line of code in a spec must serve an explicit purpose within that spec's scope.**

- Do NOT include types, interfaces, fields, or functions for "future" features
- Do NOT add placeholder fields on interfaces that no function in the spec reads or writes
- Do NOT stub out functions that won't be implemented or tested in this spec
- Do NOT add optional config properties that nothing in the spec uses
- If a type has 10 fields but only 4 are used by this spec's functions and tests, only include the 4

When in doubt, leave it out. A future spec can add it with full context.

## CRITICAL: No Empty Stub Files

**Never scaffold directories or files that contain only placeholder content or stubs for future specs.**

- Do NOT create folders with stub components for a future spec
- Do NOT create files that just say `// Implementation in next spec`
- Do NOT create re-export index files for modules that don't exist yet

Every file in the spec must either (a) contain working code used by this spec or (b) contain a guided function stub with `throw new Error("Not implemented")` that WILL be implemented in this spec.

## CRITICAL: Tests in Same Step as Implementation

**Never create a separate "Tests" phase or section.** Every test file appears in the same step as the implementation it tests.

- Step N implements `foo.ts` → Step N also includes `foo.test.ts`
- The step's checkbox list includes both: `- [ ] Create foo.ts` and `- [ ] Create foo.test.ts`

## CRITICAL: Single Object Parameters

**All functions AND class methods take a single typed `props` object instead of multiple positional parameters.**

```typescript
// ❌ WRONG — positional params
export function mergeFields(authTable: AuthTableDefinition, collection: Collection, slug: string): Result { ... }

// ✅ RIGHT — single props object
export function mergeFields(props: {
  authTable: AuthTableDefinition;
  collection: Collection;
  slug: string;
}): Result {
  // Access via props.authTable, props.collection, props.slug
}
```

**Rules:**
- The parameter name is always `props` (not `opts`, `args`, `options`, etc.)
- Prefer `props.fieldName` access when the function body also defines local variables
- Destructuring `const { ... } = props` is allowed only when the function body has no locally-defined variables
- Zero-param or single-param methods (`getAll()`, `has(key)`) don't need a props wrapper
- Callbacks passed to `.map()`, `.filter()` etc. use positional params

## Mandatory: Use AskUserQuestion Tool

**Always use the `ask_user_question` tool when asking the user anything.** Never ask questions via plain text output. Every question in Phase 1 (scope), Phase 3 (edge cases), and Phase 5 (review) MUST go through `ask_user_question`.

## Process

### Phase 1: Understand the Feature & Draw Scope Boundaries

Use `ask_user_question` to gather context:

```
What feature or system are we speccing out?

Describe:
- What it does
- What packages/areas of the codebase it touches
- Any key constraints or decisions already made
```

After the initial response, use `ask_user_question` again to explicitly define scope:

```
To keep the spec tight, I want to confirm what's IN and OUT of scope:

**I think this spec covers:**
- [Concrete deliverable 1]
- [Concrete deliverable 2]

**I think these are OUT of scope (future specs):**
- [Related thing that could creep in]

Is this right? Anything to add or move between the lists?
```

This boundary is binding. Every type, interface, function, and test must serve something in the "in scope" list.

### Phase 2: Explore the Codebase

Before writing anything, thoroughly explore the relevant parts of the codebase:
- Read existing types, interfaces, and patterns in the affected packages
- Understand how similar features are structured
- Identify existing conventions (naming, file organization, exports, test patterns)
- Note any existing code that will need to be modified vs created fresh

Summarize findings to the user briefly.

### Phase 3: Poke Holes & Surface Edge Cases

Use `ask_user_question` to present findings:

```
Before writing the spec, here are potential issues and edge cases I want to flag:

**Design questions:**
1. [Question about an ambiguous requirement]
2. [Question about how X interacts with Y]

**Edge cases to consider:**
- [Edge case 1 — why it matters]
- [Edge case 2 — why it matters]

**Scope check — things I will NOT include:**
- [Adjacent concern that came up during exploration but is out of scope]
- [Type field / function that only a future feature needs]

**Test coverage suggestions:**
- [Area 1] — because [this is the main integration point where bugs will surface]
- [Area 2] — because [reason]

Which of these should we address in the spec vs defer?
```

Iterate until the developer is satisfied with scope and edge case coverage.

### Phase 4: Write the Spec

Create the spec document at the path the user specifies (or suggest one based on existing spec numbering in `.pi/agent-docs/specs/`).

#### Build Order: Testable at Every Step

**This is the most important structural decision in the spec.** The implementation order must follow an outside-in approach:

1. **Step 1 is always setup** — config files, package scaffolding, anything needed to make `build` and `test` commands work. After Step 1, `build` and `test` must both run without errors.
2. **Step 2 is the entry point / public API** — the main function or module that consumers will import, with hardcoded or minimal return values.
3. **Step 3 is a test shell** — set up the test file(s) so tests run from this point forward.
4. **Remaining steps progressively replace hardcoded values with real implementations** — each step implements one internal function, adds its tests, and wires it into the entry point.
5. **Last step is final integration** — expand tests, add re-exports, verify full build.
6. **Every spec ends with a mandatory Verification section** — build and tests must pass.

**The rule: after completing any step, the developer should be able to run `build` and `test` and see progress.**

#### Dependency Ordering

**If function A calls function B, then B's step MUST come before A's step.** Build from leaves to root:
- Utility/helper functions first
- Functions that call those utilities next
- Orchestration/entry-point functions last

#### Spec Document Structure

```markdown
# {Spec Number} — {Feature Name}

## Overview
[2-3 sentences: what this spec covers and why]

## Design Decisions
[Key decisions made during shaping, with brief rationale]

## Out of Scope
[What this spec explicitly does NOT cover]

## Target Directory Structure
[File tree showing what will exist after implementation, with annotations]

## Implementation Order

> **Key:**
> - `[agent]` — Boilerplate or pattern-following; agent generates this
> - `[dev]` — Important custom implementation; dev implements this

[Numbered list of steps with tags. Each `[dev]` step names the key function(s).]

---

## Step 1: [Setup]

- [ ] [Concrete action]
- [ ] Run build/install and verify it works

[File blocks with code...]

---

## Step 2: [Entry point with hardcoded return]

- [ ] [Create/modify file]
- [ ] [Verify import works]

[File blocks...]

---

## Step N: [Final integration]

- [ ] [Expand tests]
- [ ] [Run full build]

## Verification (mandatory)

- [ ] `build` — all affected packages build successfully
- [ ] `test` — all tests pass
- [ ] Fix any test assertions broken by your changes
- [ ] Fix any type errors introduced by your changes

## Success Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
```

#### What Gets Full Code vs Guided Stubs

**Full code (copy-paste ready):**
- TypeScript types and interfaces used by functions or tests in this spec
- Utility/helper functions (pure, simple logic)
- Re-export index files for modules created in this spec
- Package configuration files
- Test files (these ARE the spec — exact inputs and expected outputs)
- Error classes and constants

**Guided stubs (developer implements):**
- Core business logic functions
- Integration/orchestration functions
- Functions with complex conditional logic

For guided stubs, the implementation guidance goes **inside the function body as numbered pseudo-code comments**:

```typescript
export function myFunction(props: {
  input: string;
  collectionSlug: string;
}): Result {
  // TODO: implement
  //
  // 1. First step — what to do and why (access via props.input, props.collectionSlug)
  //    → what this returns or produces
  //    → conditions that cause errors (throw XError if ...)
  //
  // 2. Second step — next action
  //
  // 3. Return the result
  //
  // Edge cases:
  // - Edge case 1: what happens and how to handle it
  throw new Error("Not implemented");
}
```

**Guided stub requirements:**
- Start with `// TODO: implement`
- Use numbered steps for the algorithm
- Use `→` arrows to show what each step produces or throws
- Include `// Edge cases:` section when there are non-obvious cases
- End with `throw new Error("Not implemented")`

#### JSDoc Requirements

All exported functions, types, and interfaces MUST include complete JSDoc:

- **Functions:** summary, `@param props.fieldName` for each field, `@returns`, at least one `@example`
- **React components:** same as functions. `@returns` describes the JSX output. Every `@param props.fieldName` must have a description.
- **`@returns` is never optional.** Even if obvious, write one line.
- **`@param props.fieldName` descriptions are never optional.** `@param props.form` alone is a lint error; `@param props.form - The TanStack Form instance` is correct.
- **`@throws`** must be present on any function that explicitly throws.
- **Input types** (`*Input`): summary, full defaults block with inline `//` comments, `@example` blocks, `@see` references
- **Resolved types**: one-sentence summary, `@see` back to Input type. No examples needed.
- **Interface properties:** one-sentence description per property

### Phase 4.5: Review Build Order

After writing the spec but before presenting it, check:
1. Can the developer run `build` after Step 1?
2. Can the developer import the public API after Step 2?
3. Can the developer run `test` after Step 3?
4. For each subsequent step: does the step end with "run tests" and do all prior tests still pass?
5. Does any step require building multiple unrelated files before testing? (If yes, split it.)
6. Is every step in the Implementation Order tagged `[agent]` or `[dev]`?

### Phase 5: Review with Developer

After writing the spec, present a summary:

```
Spec created at: [path]

**What you can copy-paste directly:**
- [List of types/interfaces/utils/tests]

**What you'll implement yourself (guided):**
- [List of function stubs with brief descriptions]

**Suggested implementation order:**
1. [Phase 1 — what and why]
2. [Phase 2 — what and why]

Review the spec and let me know if anything needs adjustment.
```

## Key Principles

- **Nothing speculative.** Every line of code must be used by something else in this spec.
- **Tests are the real spec.** Every test file should have exact expected values.
- **JSDoc is required.** All exported code must have complete JSDoc.
- **Implementation order matters.** Dependencies come before dependents.
- **Testable at every step.** After completing any step, `build` and `test` must work.
- **Task checkboxes in every step.** Each step has `- [ ]` checkboxes for every file and verification action.
- **Scope is a feature.** A tight spec that covers its scope completely is better than a broad spec that covers everything partially.
- **Pseudo-code lives in the function body.** Never below the code block.
- **Tests live next to code.** Test files are colocated with the source files they test.
