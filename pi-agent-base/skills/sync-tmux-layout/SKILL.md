# Skill: sync-tmux-layout

Scan the current tmux session layout, treat it as the new default, and write the result to two places:
1. The project's `.pi/agent-docs/product/tmux-workspace.md`
2. The tmuxinator session file in the chezmoi source (`dot_config/tmuxinator/<session>.yml`)

Remind the developer to run `cma` after to deploy dotfile changes.

---

## Step 1 — Detect session and layout

```bash
# Get the current session name
SESSION=$(tmux display-message -p '#S')

# List all panes with window index, pane index, running command, and cwd
tmux list-panes -t "$SESSION" -a \
  -F "#{window_index}:#{pane_index} | #{window_name} | #{pane_current_command} | #{pane_current_path}"
```

Display the full table to the developer so they can confirm which pane is which before writing.

## Step 2 — Label each pane

For panes whose `pane_current_command` is ambiguous (e.g. `node`, `zsh`), ask the developer what process is actually running there and what its purpose is (e.g. "pnpm dev", "convex dev", "pi agent", "free shell").

Use `ask_user_question` if there are ambiguous panes. For clearly labelled panes (nvim, claude, etc.) infer automatically.

## Step 3 — Write `tmux-workspace.md`

Write to `.pi/agent-docs/product/tmux-workspace.md` in the project root. Use this template:

```markdown
# Tmux Workspace

Session: `<SESSION>`
Root: `<project root path>`

## Pane Map

### Window <N> — `<window_name>` (<purpose>)

| Pane | Target | Command | What to read here |
|------|--------|---------|-------------------|
| Left | `<SESSION>:<W>.<P>` | `<command>` | <description> |
...

## Reading Live Output

**In Pi — use the `tmux_pane` tool:**
```
tmux_pane({ pane: "<SESSION>:<W>.<P>" })   // <purpose>
```

**Via bash:**
```bash
tmux capture-pane -t <SESSION>:<W>.<P> -p -S -100
```

## Rules

- **Never start** [list always-running services] — they are permanently running in window <N>. Starting duplicates causes conflicts.
- **Never kill or restart** service panes without explicit developer instruction.
- Before browsing after a code change, confirm a rebuild completed in the relevant pane.

## Keeping This File Current

Run `/sync-tmux-layout` any time you reorganise panes.
```

Fill in all fields from the layout scan and developer labels.

## Step 4 — Find the chezmoi source

```bash
CHEZMOI_SOURCE=$(chezmoi source-path)
TMUXINATOR_FILE="$CHEZMOI_SOURCE/dot_config/tmuxinator/$SESSION.yml"
```

If `chezmoi source-path` fails, ask the developer for the chezmoi source path.

Check whether `$TMUXINATOR_FILE` already exists and show the developer the current contents before overwriting.

## Step 5 — Generate tmuxinator YAML

Reconstruct the tmuxinator YAML from the session layout. Use the pane startup commands (what the developer said each pane runs, or the shell command if it's a plain shell). For windows with multiple panes, use `layout: even-horizontal` (2 panes side-by-side) or `layout: main-vertical` (1 large pane left + stacked panes right) based on actual visual layout.

Template:

```yaml
name: <SESSION>
root: <absolute project root>/

windows:
  - <window_name>:
      layout: <layout>
      panes:
        - <startup command for pane 0>
        - <startup command for pane 1>
  - <window_name>:
      ...
```

For panes that should start blank (free shell, editor started manually), use an empty string `""` or omit the command.

Show the generated YAML to the developer for confirmation before writing.

## Step 6 — Write tmuxinator file to chezmoi source

Write the confirmed YAML to `$CHEZMOI_SOURCE/dot_config/tmuxinator/$SESSION.yml`.

If chezmoi is not tracking this file yet:
```bash
chezmoi add ~/.config/tmuxinator/$SESSION.yml
```

## Step 7 — Also update the project harness terse summary

In the project's `.pi/AGENTS.md`, find the `## Tmux Workspace` section and update the pane list to match the new layout. Keep it terse — just session name, the always-running panes with targets, and a link to `tmux-workspace.md`.

## Step 8 — Remind developer

Tell the developer:

> Updated:
> - `.pi/agent-docs/product/tmux-workspace.md` (project harness)
> - `<CHEZMOI_SOURCE>/dot_config/tmuxinator/<SESSION>.yml` (chezmoi source)
> - `.pi/AGENTS.md` tmux summary
>
> Run **`cma`** to apply the chezmoi changes to your live dotfiles.

---

## Notes

- This skill works for any project and any tmux session — it detects the session from the environment.
- It does NOT restart or modify any running processes.
- If the session has no `.pi/` harness, skip `tmux-workspace.md` and only update the tmuxinator file.
- The `cma` alias = `chezmoi apply && source ~/.zshrc`. It is defined in `~/.zshrc` and triggers the `run_after_sync-pi-agent-base.sh` script which syncs `pi-agent-base/` → `~/.pi/agent/`.
