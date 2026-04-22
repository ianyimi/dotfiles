---
description: Post-implementation spec alignment — compares actual code against the spec, updates spec to match renames/changes, marks tasks complete, writes implementation log and commit message, and feeds extracted developer patterns back into dev-spec.
---

# Sync Spec — Post-Implementation Spec Alignment

Run this after you have finished implementing a spec. It compares the actual code against the spec document, updates the spec to match any renames, restructures, or design changes made during implementation, marks all tasks as complete, and updates any dependent future specs to stay aligned with the current implementation.

If no spec name was provided, ask for one and then proceed.

## When to Use

Run `/sync-spec <spec-name-or-number>` after completing the build for a spec.

## Mandatory: Use ask_user_question Tool

**Always use the `ask_user_question` tool when asking the developer anything during this process.**

## Process

### Phase 1: Identify the Spec and Its Dependencies

1. Find the spec file in `.pi/agent-docs/specs/`
2. Read the spec's header for dependency links
3. Scan all other spec files for references to this spec
4. Build a list of **downstream specs** (specs that reference or depend on this one)

### Phase 2: Compare Code Against Spec

For each file mentioned in the spec:

1. **Check if the file exists** at the spec's stated path — if moved/renamed, note the new path

2. **Compare function signatures** — for each function stub in the spec:
   - Does the function still exist? Same name?
   - Has the signature changed (params, return type)?
   - **Check parameter style:** Does the function use a single `props` object parameter? If the spec has positional params but the code uses `props: { ... }`, flag this as a signature change.

3. **Compare types and interfaces** — for each type in the spec:
   - Does the type still exist? Same name?
   - Were fields added, removed, or renamed?
   - Were any interfaces removed entirely?

4. **Compare file structure** — does the actual directory structure match the spec's "Target Directory Structure"?
   - New files that weren't in the spec
   - Files from the spec that don't exist
   - Files that were moved to different directories
   - **Check for empty stubs:** Does the spec reference files that were never created because they'd only contain placeholder content?

5. **Check test colocation** — are test code blocks placed immediately after their implementation code blocks?

6. **Compare test assertions** — for each test file in the spec:
   - Do the test descriptions match?
   - Have expected values changed?
   - Were tests added or removed?
   - **Check call patterns in tests:** If a function was changed from positional params to `props` object, all test calls must be updated.

### Phase 2B: Extract Developer Patterns

**Before presenting the diff to the developer**, synthesize each deviation into a pattern category. Every deviation the developer made to the code is treated as intentional — it represents how they want things done.

For each deviation identified in Phase 2, classify it as one of:

**Preference Pattern** — a consistent stylistic or structural choice the developer applies regardless of context. These should be encoded in the dev-spec prompt so all future specs generate code this way by default.

**Implementation Improvement** — the spec generated a stub or placeholder; the developer fleshed it out with a real implementation. These define what "complete" means for a feature type.

**Architecture Decision** — a fundamental design choice driven by an external constraint. Document in the ideaLog but don't encode as a blanket preference.

For each Preference Pattern and Implementation Improvement, note:
- **What the spec generated** — what was in the spec code block
- **What the developer wrote** — what's actually in the code
- **The rule** — a one-sentence description of what dev-spec should do instead

### Phase 3: Present Diff Summary

Use `ask_user_question` to present findings — include both the diff AND the pattern summary:

```
Here's what changed during implementation of spec {name}:

**Renames:**
- `oldFunctionName()` → `newFunctionName()`

**Signature changes:**
- `function foo(a: string)` → `function foo(props: { a: string })`

**Structural changes:**
- Added file: `path/to/new-file.ts`
- Removed file: `path/to/old-file.ts`

**Downstream specs that reference changed names:**
- Spec X: references `oldFunctionName` on lines X, Y

---

**Patterns extracted (will update dev-spec after approval):**

Preference Patterns — will be encoded as default behavior in dev-spec:
- [Rule]: spec generated X, developer changed to Y → "always generate Y"

Implementation Improvements — spec was underbaked; will be added as defaults:
- [Feature]: spec had placeholder, developer added [real implementation]

Architecture Decisions — one-time; will be documented in ideaLog only:
- [Decision]: [constraint that drove it]

Should I update the spec, all downstream specs, and encode these patterns in dev-spec?
```

### Phase 4: Update the Completed Spec

After developer approval:

1. **Update all code blocks** to match the actual implementation
2. **Mark all task checkboxes as complete** (`- [ ]` → `- [x]`)
3. **Update design decisions** if the approach changed

4. **Write two files to `.pi/agent-docs/implementation-log/YYYY/MM/`** for today's date:

   **`YYYY-MM-DD.ideaLog.md`** — the detailed record for debugging and understanding why code looks the way it does:
   ```markdown
   # YYYY-MM-DD — Spec [Name]: <Step Title>

   **Spec:** `.pi/agent-docs/specs/[spec-folder]/plan.md`
   **Commit:** *(leave blank — filled in after `git commit`)*

   ## What was built

   - `path/to/file.ts` — what it does and why it exists

   ## Deviations from spec

   - [deviation and reason]

   If none: "No deviations — implemented as specced."

   ## Decisions made

   - Chose X over Y because [reason]

   ## Known issues / follow-ups

   - [anything to watch for, or deferred bugs]
   ```

   **`YYYY-MM-DD.commit.md`** — a ready-to-copy git commit message.
   Line 1 is the title. Line 2 is blank. Lines 3+ are the body.

   **Title rules:** Conventional commit format `type(scope): description`, under 72 chars.

   **Body rules:**
   - Verbose — explain what was built and why
   - Group related changes into paragraphs
   - Include deviations from spec and the reason
   - End with spec and log references

   If a `.ideaLog.md` already exists for today (multiple sync runs in one day), append a new `---` separated section. Create a new `.commit.md` with a numeric suffix: `YYYY-MM-DD.2.commit.md`.

5. **Remove any "TODO" comments** from code blocks that are now implemented

### Phase 4B: Encode Patterns into Dev-Spec

After the spec update is complete, apply the patterns extracted in Phase 2B.

**For each Preference Pattern:**
1. Find the relevant section in `.pi/prompts/dev-spec.md` (project-local) or `~/.pi/agent/prompts/dev-spec.md` (global fallback)
2. Update the example code, stub template, or guidance text to use the pattern the developer prefers

**For each Implementation Improvement:**
1. Find the dev-spec section that describes the stub type being improved
2. Update the stub code to the complete implementation the developer actually wrote

**Write a patterns summary to `.pi/agent-docs/standards/developer-preferences.md`:**

```markdown
# Developer Preferences

> Patterns extracted from sync-spec runs. Each entry represents a deviation from
> AI-generated spec code that the developer consistently prefers.

## [Category]
- **[Rule]**: [Explanation]. *(Encoded: sync-spec {name}, {date})*
```

After writing patterns, confirm in your response which sections of dev-spec were updated.

### Phase 5: Update Downstream Specs

For each downstream spec:
1. **Search and replace** all references to renamed functions, types, file paths
2. **Update code blocks** that import or reference changed APIs
3. **Flag any downstream spec where a code block's logic may need rethinking** — present to the developer via `ask_user_question` rather than silently changing logic

### Phase 6: Verify Consistency

1. Grep across all specs for any remaining references to old names
2. Verify no spec references a function, type, or file that no longer exists

### Phase 7: Run Verification

After all spec and log updates are complete, run the project's build and test commands (from `.pi/agent-docs/product/dev-processes.md` if available).

Present a final summary:

```
Sync complete for spec {name}.

**Spec updated:** {count} checkboxes marked complete
**Log written:** .pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.ideaLog.md
**Commit message ready:** .pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.commit.md

**Verification:**
- Build: passed / FAILED
- Tests: passed / FAILED

Run /commit to generate a commit message from current changes.
```

## Key Principles

- **Every deviation is a preference.** All changes the developer made to code that differ from the spec are improvements — treat them as authoritative statements about how the developer wants things done.
- **Patterns flow upward.** Preferences extracted from a sync-spec run must be written back into the dev-spec prompt so future specs don't regenerate the same code the developer will have to change.
- **The spec is the state.** Checkbox state (`- [x]` vs `- [ ]`) is how the agent knows where you are.
- **The ideaLog is append-only.** Never edit or remove past entries.
- **Code is the source of truth.** After implementation, the code wins. The spec gets updated to match the code, never the other way around.
- **Don't silently change logic in downstream specs.** If a downstream spec's code block needs more than a name swap, flag it for the developer.
- **Single object parameters.** All functions AND class methods must use `props: { ... }`. If any function uses positional params but the code uses a `props` object, update the spec's function signature, pseudo-code, AND all test call sites.
- **No empty stub files.** If the spec references files that were never created because they'd only contain placeholder content, remove those files from the spec.
