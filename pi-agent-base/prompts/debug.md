---
description: Systematic bug investigation following the project's configured debug hierarchy. Reads workflow tier from tech-stack.md to know whether to describe or implement the fix.
---

# Debug

Investigate a bug systematically using the project's debug hierarchy.

---

> **Questions:** Use the `ask_user_question` tool for every question in this prompt. Never write question lists as plain text.

## Process

### Step 1 — Read project context

Before asking anything, read:
- `.pi/agent-docs/standards/debug-hierarchy.md` — the exact source order and known fragile areas for this project
- `.pi/agent-docs/product/tech-stack.md` — workflow tier (high-care or low-care), which determines the fix path
- `.pi/agent-docs/product/dev-processes.md` — error log file paths and background service ports

If these files don't exist, fall back to the default hierarchy below and assume high-care.

### Step 2 — Default hierarchy (if debug-hierarchy.md not configured)

1. Terminal/process error output
2. Uncommitted changes (`git diff`)
3. ideaLog (recent decisions that might explain the behavior)
4. Error log files
5. Test output
6. Browser/client console (if applicable)

### Step 3 — Describe the bug

Ask:
> What's the symptom? What did you expect to happen, and what happened instead?

> When did it start? After a specific change, or has it always been broken?

### Step 4 — Check sources in hierarchy order

For each source in the project's configured hierarchy:

**Terminal/process output**: First try to read log file paths from `dev-processes.md` directly. Only ask the developer to paste if no log path is configured or the file is empty.

**Uncommitted changes**: Run `git diff` and `git diff --cached`. Look for changes that could cause the symptom.

**ideaLog**: Read the most recent entries in `.pi/agent-docs/implementation-log/`. Look for decisions that might have introduced this behavior intentionally or accidentally.

**Error log files**: Read paths documented in `dev-processes.md`. Do not ask the developer to paste if the path is readable.

**Known fragile areas**: Check `debug-hierarchy.md` for known problem spots related to the symptom description.

### Step 5 — Form hypothesis

After checking each source, form one specific hypothesis:

> Based on <source>, the bug is likely caused by <specific thing>. Evidence: <what you found>.

Do not offer multiple theories. Pick the most likely one and state the evidence.

### Step 6 — Propose investigation step

Suggest one targeted action to confirm the hypothesis before proposing a fix:

> To confirm: <specific thing to check, change, or run>

Wait for the developer to confirm or redirect.

### Step 7 — Fix path

Once the cause is confirmed, apply the workflow tier from `tech-stack.md`:

- **High-care**: describe the fix precisely, let the developer implement it
- **Low-care**: propose the exact code change

If `tech-stack.md` doesn't exist or doesn't specify a tier, default to high-care.

### Step 8 — IdeaLog entry (for complex bugs)

If the bug took more than one iteration to find, append to today's ideaLog:

```markdown
## Bug: <symptom summary> — <timestamp>

Root cause: <what it was>
Found via: <which source in the hierarchy led to it>
Fix: <what was done>
Note: <anything non-obvious to avoid next time>
```

---

## Rules

- Always read log files directly before asking the developer to paste
- Never guess without checking sources first
- Never suggest "try restarting the dev server" as a first step
- One hypothesis at a time — don't scatter attention
- If the bug is in a known fragile area (debug-hierarchy.md), name it explicitly
