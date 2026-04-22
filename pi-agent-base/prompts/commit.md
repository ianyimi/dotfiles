---
description: Generate a conventional commit message from all uncommitted changes, then append it to today's implementation log under a timestamped heading. Prints the title so you can copy it.
---

# Commit — Generate Commit Message from Uncommitted Changes

Generate a conventional commit message for all uncommitted changes (staged and unstaged), then append it to today's implementation log under a timestamped heading.

## Usage

```
/commit
```

No arguments. Always operates on the current working tree diff.

---

## Process

### Step 1 — Gather the diff

Run these two commands in parallel:

```bash
git diff HEAD
git log --oneline -5
```

Use the diff to understand what changed. Use the log to match the project's commit style.

### Step 2 — Read changed source files (if needed)

If the diff alone doesn't give enough context to write a specific commit body, read the relevant source files to understand the intent. Do not read files just to pad the message — only read if the diff is ambiguous.

### Step 3 — Write the commit message

**Title rules:**
- Conventional commit format: `type(scope): description`
- Under 72 characters — hard limit
- `type`: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`
- `scope`: the primary area changed (e.g., `core`, `api`, `cli`, `docs`). If the change spans many areas equally, use a broader label.
- Description: specific and complete. "refactor date time config to object" not "update date field". Cover everything material in the title.

**Body rules:**
- Explain **why** the change was made, not just what files changed
- Group related changes into short paragraphs (not one long bullet list)
- Mention any deviations from the spec and the reason
- End with spec and log references if this change is part of an active spec:
  ```
  Spec: .pi/agent-docs/specs/YYYY-MM-DD-feature-name/plan.md
  Log: .pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.ideaLog.md
  ```
- If the change is not part of a spec, omit those lines entirely

### Step 4 — Append to today's implementation log

Determine today's date. The log file lives at:

```
.pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.commit.md
```

**If the file does not exist**, create it. Write the heading on the first line, then the commit message.

**If the file already exists**, append the new entry after the existing content, separated by `---`.

**Heading format:**

```markdown
## Commit — YYYY-MM-DD HH:MM
```

Use `date '+%H:%M'` via a Bash tool call to get the current time. Never guess the time.

The full appended block looks like:

```markdown
---

## Commit — 2026-04-13 14:32

feat(scope): title here

Body paragraph explaining the why.

Second paragraph if needed.
```

### Step 5 — Output the title

After writing the log, print the commit title on its own line so the developer can copy it:

```
feat(scope): title here
```

That's it. No other output needed — the developer will read the full body from the log file.

---

## Key principles

- **Specific beats generic.** The title should tell a future developer exactly what changed without reading the diff.
- **Body explains intent.** If you can't explain why the change was made in one paragraph, read more of the code before writing.
- **Don't pad.** A two-sentence body that's accurate is better than five sentences with filler.
- **One message per `/commit` run.** One call = one message for all current uncommitted changes.
