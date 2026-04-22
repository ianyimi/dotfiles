---
description: Update the Pi agent harness config when project requirements change. Logs decisions to ideaLog. Run manually when processes, dependencies, or project structure changes.
---

# Sync Harness

Update the `.pi/` agent harness to reflect changes in the project.

Run this when:
- Dev processes changed (new commands, new services, ports moved)
- New dependencies added that the agent should know about
- Project structure changed (new apps/packages in monorepo)
- Debug hierarchy needs updating (new error surfaces found)
- Mission or focus changed significantly

---

## What this prompt does

1. Re-reads the current manifest files and project structure
2. Diffs against what `.pi/agent-docs/` currently documents
3. Presents the delta — what changed, what's stale
4. Asks the developer to confirm each update before writing
5. Appends a sync entry to today's ideaLog

---

> **Questions:** Use the `ask_user_question` tool for every question in this prompt. Never write question lists as plain text.

## Process

### Step 1 — Detect changes

Scan:
- Manifest files (package.json, Cargo.toml, go.mod, turbo.json, pnpm-workspace.yaml, etc.)
- `apps/` and `packages/` directories (monorepo packages added/removed)
- Current `.pi/agent-docs/product/` files

Report what has changed since the harness was last updated.

### Step 2 — Present delta

For each change, show:
```
Changed: <what>
Current doc says: <old value>
Now detected: <new value>
Update? [y/n/skip]
```

### Step 3 — Apply approved updates

Write updated sections to the relevant agent-docs files. Never overwrite without confirmation.

### Step 4 — IdeaLog entry

Append to today's ideaLog:

```markdown
## Harness Sync — <timestamp>

Changes applied:
- <change 1>
- <change 2>

Changes skipped:
- <change> — <reason given by developer>
```

---

## Trigger

Run manually only. Never run automatically or on a schedule.
