---
name: 3-commit
description: Stage and commit pi-agent-base changes with a conventional message. Note that pi-agent-base is a sub-tree of the chezmoi dotfiles repo — commits go to the parent repo.
invoke: "commit"
---

# Commit — pi-agent-base

## Important: this is a sub-tree commit

`pi-agent-base/` is part of the chezmoi dotfiles repo at `/Users/zaye/.local/share/chezmoi/` (remote: `github.com/ianyimi/dotfiles`). Commits made from inside `pi-agent-base/` go to the parent repo's git history.

The agent should `cd` to `/Users/zaye/.local/share/chezmoi/` before staging/committing, and scope the commit to changes inside `pi-agent-base/` (or include the matching `run_after_sync-pi-agent-base.sh.tmpl` change if relevant).

## Conventions for this repo

- **Format**: `type(scope): short description` — under 72 chars
- **Types**: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`
- **Scope**: use `pi-base` as the scope for changes inside `pi-agent-base/`. Examples:
  - `feat(pi-base): add browse extension tab-reuse`
  - `fix(pi-base): correct package load order for vim-powerline`
  - `docs(pi-base): document chezmoi sync exclusions`
  - `chore(pi-base): bump pi-smart-fetch package`
- **Body**: explain WHY, not what files changed. Mention if the change requires `pi update` (because `packages[]` changed) or just `cma`.
- **Multi-area commits**: if the same change touches both `pi-agent-base/` and the parent chezmoi config (e.g. updating the rsync script), use scope `pi-base` and call out the parent file in the body.

## Steps

1. `cd /Users/zaye/.local/share/chezmoi`
2. `git status` — review changes. If anything outside `pi-agent-base/` (or the rsync script) is staged unexpectedly, ask before proceeding.
3. `git diff --staged` — sanity check.
4. Draft a conventional message scoped to `pi-base`.
5. Show the message + diff summary to the user. Ask once for confirmation, edits, or amendments.
6. On confirmation: `git add` only the relevant paths, then `git commit`.
7. Do **not** push automatically.

<!-- sync-spec:commit-conventions -->
<!-- Add project-specific commit message rules here as they emerge. -->
