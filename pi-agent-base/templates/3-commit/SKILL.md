---
name: 3-commit
description: Stage and commit changes with a structured, conventional commit message. Reads git diff to summarize what changed. Developer confirms message before committing. Appends to implementation log.
invoke: "commit"
---

# Commit

Stage and commit the current changes with a well-formed commit message, then record it in the implementation log.

---

> **Questions:** Use the `ask_user_question` tool for every question in this skill. Never write question lists as plain text.

## Process

### Step 1 — Read current state

Run:
- `git status` — see what's staged, unstaged, untracked
- `git diff` — read unstaged changes
- `git diff --cached` — read staged changes

### Step 2 — Ask what to include

If there are untracked or unstaged files, ask:
> These files are not staged. Include any of them?
> <list files>

### Step 3 — Find relevant ideaLog entries

Before drafting the message, scan for ideaLog entries that cover this work:

1. List files in `.pi/agent-docs/implementation-log/` for today's date (`YYYY/MM/YYYY-MM-DD.ideaLog.md`) and the previous 2 days
2. For each found file, skim it for entries mentioning: the same files being committed, the same feature/area, or decisions that explain the change
3. Collect the relative path(s) of any matching ideaLog files — they'll be added as `Refs:` in the commit body

If no ideaLog files exist or none are relevant, skip silently.

---

### Step 4 — Draft commit message

Analyze the diff and draft a conventional commit message:

```
<type>(<scope>): <short summary>

<body — only if the why is non-obvious>

Refs: <relative path to ideaLog file(s)>
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `style`, `ci`

Scope: the app/package name (monorepos) or module name (single-package)

Rules:
- Summary line: imperative mood, under 72 chars, no period
- Body: explain WHY, not WHAT — the diff already shows what
- Skip body if the summary is self-explanatory
- Add `Refs:` line when relevant ideaLog(s) found in Step 3 — path relative to repo root
- Never mention ticket numbers or "as per spec"

<!-- sync-spec:commit-conventions -->
_No project-specific commit conventions yet. sync-spec will populate this as patterns are learned._
<!-- /sync-spec:commit-conventions -->

### Step 5 — Confirm with developer

Show the drafted message and ask:
> Commit message:
> ```
> <message>
> ```
> Confirm, edit, or cancel?

### Step 6 — Commit

On confirmation:
```
git add <approved files>
git commit -m "<message>"
```

Report the commit hash and summary on success.

### Step 7 — Append to implementation log

After a successful commit, append to `.pi/agent-docs/implementation-log/YYYY/MM/YYYY-MM-DD.commit.md`:

```markdown
## <HH:MM> — <commit hash short> — <summary line>

<body if present>

Files: <comma-separated list of changed files>
```

Create the file and directory if they don't exist. Never overwrite — always append.

If `.pi/agent-docs/` does not exist, skip this step silently.

---

## Monorepo scope convention

If `turbo.json` or `pnpm-workspace.yaml` is detected, or if the project's `tech-stack.md` identifies a monorepo, use the app/package name as scope:

```
feat(app): add user profile page
fix(api): handle null user in session middleware
chore(packages/ui): update button variants
```

For non-Node monorepos (Go workspaces, Rust workspaces, Python monorepos), use the module/crate/package name as scope.

---

## What to avoid

- Never use `git add .` or `git add -A` without showing the developer what will be staged
- Never skip the confirmation step
- Never include `.env` files, secrets, or large binaries
- Never amend a published commit
