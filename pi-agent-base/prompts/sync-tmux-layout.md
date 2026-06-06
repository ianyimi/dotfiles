# Sync Tmux Layout

Re-scan the current tmux session layout, treat it as the new default, and write the result to:
1. `.pi/agent-docs/product/tmux-workspace.md` in the project
2. The tmuxinator session file in the chezmoi source
3. The `## Tmux Workspace` terse summary in `.pi/AGENTS.md`

Run this any time you reorganise tmux panes or start a new project session for the first time.

---

Execute the `sync-tmux-layout` skill immediately.

Read the skill file at:
`~/.pi/agent/skills/sync-tmux-layout/SKILL.md`

Follow every step in order. No confirmation needed before starting — the skill itself handles confirmation before writing files.
