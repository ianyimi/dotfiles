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

**Never stage:**
- `.env` files or secret files (unless they're .tmpl templates)
- Large binaries
- macOS system files (.DS_Store)
- Temporary files

### Step 3 — Find relevant ideaLog entries

Before drafting the message, scan for ideaLog entries that cover this work:

1. List files in `.pi/agent-docs/implementation-log/` for today's date (`YYYY/MM/YYYY-MM-DD.ideaLog.md`) and the previous 2 days
2. For each found file, skim it for entries mentioning: the same files being committed, the same feature/area, or decisions that explain the change
3. Collect the relative path(s) of any matching ideaLog files — they'll be added as `Refs:` in the commit body

If no ideaLog files exist or none are relevant, skip this step silently.

---

### Step 4 — Draft commit message

Analyze the diff and draft a conventional commit message:

```
<type>(<scope>): <short summary>

<body — only if the why is non-obvious>

Refs: <relative path to ideaLog file(s)>
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `style`, `ci`

Scope (dotfiles-specific):
- Tool or area changed: `zsh`, `tmux`, `nvim`, `ansible`, `chezmoi`, `aerospace`, `sketchybar`, `git`, `bitwarden`, `bootstrap`, `aliases`
- If multiple tools affected, use the primary one or `dotfiles` for cross-cutting changes

Rules:
- Summary line: imperative mood, under 72 chars, no period
- Body: explain WHY, not WHAT — the diff already shows what
- Skip body if the summary is self-explanatory
- Add `Refs:` line when relevant ideaLog(s) were found in Step 3 — use the path relative to the repo root (e.g. `.pi/agent-docs/implementation-log/2026/04/2026-04-21.ideaLog.md`)
- Never mention ticket numbers or "as per spec"

**Examples:**
```
feat(tmux): add project layout for cognitive-core
fix(zsh): correct Bitwarden session auto-load on shell startup
chore(ansible): update Homebrew package list
refactor(chezmoi): reorganize darwin-specific configs into subdirectory
docs(readme): add Linux support status
```

<!-- sync-spec:commit-conventions -->
_Standard conventional commits. Scope is the tool or area changed. sync-spec will add project-specific patterns here over time._
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
```bash
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

---

## Platform-specific commits

When changes affect only one platform:
```
feat(tmux/darwin): add macOS-specific keybinding for Mission Control
fix(zsh/linux): correct XDG config path for Linux
```

When both platforms are affected:
```
feat(tmux): add session layout (darwin + linux)
```

---

## What to avoid

- Never use `git add .` or `git add -A` without showing the developer what will be staged
- Never skip the confirmation step
- Never include actual secrets (only .tmpl templates that reference Bitwarden)
- Never amend a published commit
- Never commit chezmoi's managed files directly (commit source files in ~/.local/share/chezmoi instead)
