---
description: Write or update inline documentation for a target in the codebase. Language-agnostic — reads the implementation first, then writes accurate developer-facing docs that work as IDE hover text and API reference. Evolves per project via sync-spec and 0-project-init.
---

# Document

Write or update inline documentation for a target in this codebase. If no target was specified, ask for one and then proceed.

<!-- SETUP:CHECK
  If this file still contains {{PROJECT_NAME}} (unreplaced), the project harness
  has not been initialized. Tell the user:

  "Run `/0-project-init` first — it will configure this prompt for your language
  and documentation style."

  Then stop.
-->

> **Questions:** Use the `ask_user_question` tool for every question in this prompt. Never write question lists as plain text.

---

## Project Context

**Project:** {{PROJECT_NAME}}
**Language:** {{LANGUAGE}}
**Doc format:** {{DOC_FORMAT}}

<!-- sync-spec:check-commands -->
**Verify commands after editing:**
{{CHECK_COMMANDS}}
<!-- /sync-spec:check-commands -->

---

## Usage

```
/document [<target>] [in <file>]
```

**Examples:**
- `/document` — documents all uncommitted changes (staged + unstaged)
- `/document <TypeName or functionName>`
- `/document all exported functions in <file>`
- `/document <ThingA> and <ThingB>`

---

## Step 1 — Locate and read the target

**If no target specified**, run `git diff --name-only && git diff --cached --name-only` to get all uncommitted changed files. Include all relevant source files. Skip: config files, `.md` files, lock files.

**Test files must be included** — check every test file for stale descriptions, wrong type assertions, wrong expected values, and test cases that no longer match the implementation.

**If a target is specified**, find it:
- Start in the file the user specifies, or search `src/`, `packages/`, `lib/`, or the project root
- Read the full file the target lives in
- Follow any imports directly relevant to understanding the target's shape or behavior

---

## Step 2 — Gather context

Before writing a single word of documentation, understand:
- **What the thing is** — its purpose in the system, not just what its fields are
- **How it is used** — check for usages in the same package or nearby files
- **What defaults look like** — if there's a config function or derived type, read it
- **The parent type** — if documenting individual fields, always read the full type first

---

## Step 3 — Write the docs

### Doc format for this project

{{DOC_FORMAT_INSTRUCTIONS}}

<!-- sync-spec:type-conventions -->
{{TYPE_CONVENTIONS}}
<!-- /sync-spec:type-conventions -->

### Universal rules (all languages)

**For types, structs, interfaces, classes:**
1. One-sentence summary — what this represents and when a developer encounters it
2. Show defaults if applicable — what values are applied when not specified
3. One example of typical usage (skip only if entirely self-evident)
4. References to related types

**For functions and methods:**
1. Summary sentence — what it does and what it returns
2. Each parameter — what it is and valid values for union/enum types
3. Return value — what it contains and when it can be null/empty/error
4. One realistic example

**For individual fields:**
- One sentence max for simple fields
- Concrete about values — if the type is a union, explain what each value does
- Explain what *setting* this property does, not just its type

### Do not

- Restate the type signature in prose (`label is a string`)
- Use vague filler (`This function handles...`, `Used for...`)
- Document things obvious from the name alone
- Invent behavior that isn't visible in the implementation
- Add `@throws` / error annotations unless there is an actual throw/error in the implementation

---

## Step 4 — Apply the docs

Edit the file in place. Do not reformat surrounding code, rename anything, or change logic. Only add or replace the documentation comment blocks for the requested targets.

After editing, confirm comments render correctly — no broken syntax, no mismatched delimiters.

---

## Step 5 — Verify

Run the check commands from the Project Context section above.

**If a check fails:**
- If you caused it — fix it immediately, then re-run to confirm it passes
- If you did not cause it — do not attempt to fix it. Report it to the user at the end

**Report at the end:**
- Which files were documented
- Any pre-existing failures you did not cause, with the exact error

---

## Project-specific conventions

<!-- sync-spec:doc-conventions -->
{{DOC_CONVENTIONS}}
<!-- /sync-spec:doc-conventions -->
