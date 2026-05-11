# Chezmoi Dotfiles Project

## Critical: File Editing Rules

**This is a chezmoi-managed dotfiles repository.**

### ONLY Edit Files In This Directory

```
/Users/zaye/.local/share/chezmoi/
```

**NEVER directly edit deployed files:**
- ❌ `~/.pi/agent/` (deployed by chezmoi)
- ❌ `~/.bootstrap/` (deployed by chezmoi)
- ❌ `~/.config/` (deployed by chezmoi)
- ❌ `~/.zshrc` (deployed by chezmoi)
- ❌ Any file in `~/` that is managed by chezmoi

### How It Works

1. **Edit** files in `/Users/zaye/.local/share/chezmoi/`
2. **Run** `cma` (chezmoi apply) to deploy changes
3. **Done** - chezmoi copies to the correct system locations

### File Mapping

| Chezmoi Source | Deployed To |
|----------------|-------------|
| `dot_zshrc` | `~/.zshrc` |
| `dot_bootstrap/macos.yml` | `~/.bootstrap/macos.yml` |
| `pi-agent-base/` | `~/.pi/agent/` |
| `dot_config/` | `~/.config/` |

**The `dot_` prefix becomes `.` when deployed.**

### Why This Matters

- Editing deployed files breaks chezmoi sync
- Changes in deployed locations get overwritten by `cma`
- Only changes in `/Users/zaye/.local/share/chezmoi/` persist in git

---

## Project Overview

**Type:** Dotfiles (shell/zsh, Bitwarden secrets, Ansible automation, Pi agent config)

**Stack:**
- Chezmoi for dotfiles management
- Ansible for macOS provisioning
- Bitwarden CLI for secrets
- Zsh + Starship
- Pi coding agent with custom extensions

## Pi Agent Configuration

**Source of truth:** `pi-agent-base/` (synced to `~/.pi/agent/` by chezmoi)

**Custom extensions:**
- `vim-powerline.ts` + `_vim-powerline/` - Combined vim modal editing + powerline status bar
- `auto-unescape-paths.ts` - Removes backslash-escapes from pasted file paths

**Settings:**
- Using forked `pi-image-preview` with spaces-in-filenames support
- Vim mode indicator in powerline (π INSERT / π NORMAL)
- Vim clipboard isolated (no system sync)

## Key File: `dot_zshrc.tmpl`

**Path:** `/Users/zaye/.local/share/chezmoi/dot_zshrc.tmpl` (deploys to `~/.zshrc`)

This is the **source of truth for all shell aliases and functions** zaye uses. The user frequently refers to commands by their alias rather than the full command. Whenever an unfamiliar short command appears in a request (e.g. `cma`, `apConfig`, `nrd`, `lgCog`), **look it up in `dot_zshrc.tmpl` first** before asking what it means.

### Frequently-used aliases

| Alias | Expands to | Purpose |
|-------|------------|---------|
| `cma` | `bw-session-check && source ~/.bw-session && bw sync && chezmoi apply && source ~/.zshrc` | Deploy chezmoi changes (requires Bitwarden session) |
| `cm` | `chezmoi` | Chezmoi shorthand |
| `cme` | `chezmoi edit --watch` | Edit + live-apply a managed file |
| `apConfig` | `ansible-playbook ~/.bootstrap/macos.yml --ask-become-pass` | Run macOS provisioning playbook |
| `ap` | `ansible-playbook` | Ansible shorthand |
| `sz` | `source ~/.zshrc` | Reload shell config |
| `bwsr` | `bw-session-check` | Check/refresh Bitwarden session |
| `nv` | `nvim .` | Open current dir in Neovim |
| `lg` | `lazygit` | Lazygit TUI |
| `tm` / `tma` / `tms` | tmux / attach / kill-session | Tmux shortcuts |
| `mux` | `tmuxinator` | Tmuxinator |
| `nrd` / `nrb` / `nrs` / `nrt` | `npm run dev/build/start/test` | NPM script shortcuts |
| `claude-maprios` / `claude-zaye` | Claude CLI with isolated `CLAUDE_CONFIG_DIR` | Separate claude profiles |

### Navigation alias patterns

Zaye uses consistent prefixes — if you see an unfamiliar command matching one of these patterns, it almost certainly follows the pattern:

- `cd<Name>` → `cd` into that project/directory (e.g. `cdCog`, `cdChezmoi`, `cdNvim`, `cdEdapt`, `cdPortfolio`, `cdVault`, `cdScripts`, `cdDaily`)
- `nv<Name>` → open that directory in Neovim (e.g. `nvCog`, `nvNvim`, `nvEdapt`, `nvZsh`, `nvAero`)
- `lg<Name>` → open lazygit for that project (e.g. `lgCog`, `lgNvim`, `lgEdapt`, `lgChezmoi`)
- `aeromon<Action>` → aerospace-monitor daemon control (`Start`, `Stop`, `Restart`, `Status`, `Logs`)

### Rule

When the user says "run cma" or "test with apConfig", that's a literal instruction to use that alias — do not translate it to the expanded command in your response. If the user invents a new alias-like shorthand you haven't seen, grep `dot_zshrc.tmpl` before guessing.

## Workflow Commands

```bash
# Apply dotfiles changes (from chezmoi source)
cma

# Apply Ansible provisioning
apConfig

# Edit chezmoi source files
nvim ~/.local/share/chezmoi/

# Check chezmoi diff before applying
chezmoi diff
```

## Services Required

- Tailscale (for network access)
- Bitwarden CLI session (for `cma` to work)

## Git Workflow

```bash
# Make changes in chezmoi source
cd ~/.local/share/chezmoi
nvim pi-agent-base/settings.json

# Test changes
cma

# Commit to dotfiles repo
git add .
git commit -m "feat: update pi settings"
git push
```

---

## Keyboard Hardware & Keybind Constraints

**Hardware:** ZSA Voyager — 52-key split ergonomic keyboard (26 keys per half).
Layout URL: https://configure.zsa.io/voyager/layouts/MWOyJ/latest/0

This keyboard layout is the **primary constraint** on all keybinding decisions across every tool (tmux, Neovim, Aerospace, Pi, shell). When suggesting new shortcuts, always reason against this layout first. Do not suggest combos that conflict with existing bindings or that require physically awkward chording.

### Physical Layout (Layer 0 — Main)

```
LEFT HALF                                 RIGHT HALF
────────────────────────────────────────────────────────────────
Number row:  ESC   1     2     3     4    5  │  6    7    8    9    0    -
QWERTY row:  F5    Q     W     E     R    T  │  Y    U    I    O    /    \
Home row:    Alt+Z A     S     D     F    G  │  H    J    K    L    P    '(⇧)
Bottom row:  Cmd   Z(⌥)  X     C     V    B  │  N    M    ,    .    ;(⎇)  =(⌃)
                                              │
Thumbs:      [Tab/MO1]  [Space/⌃]            │  [BS/⇧]  [Enter/MO2]
```

Key:
- `(⌥)` = tap sends letter, **hold sends Alt/Option**
- `(⇧)` = tap sends character, **hold sends Shift**
- `(⎇)` = hold sends Right Alt
- `(⌃)` = hold sends Ctrl
- `MO1` = hold activates Layer 1 (Sym+Num)
- `MO2` = hold activates Layer 2 (Brd+Sys)

### Modifier Keys — All Are Hold-Tap

There are **no standalone dedicated modifier keys** in the traditional sense.
Every modifier is a dual-function key:

| Modifier | Physical Key | How to Use |
|----------|-------------|------------|
| Left Ctrl | Space (right thumb outer-hold) | Hold Space |
| Right Ctrl | = (bottom row rightmost) | Hold = |
| Left Alt | Z (bottom row 2nd) | Hold Z |
| Right Alt | ; (bottom row 5th) | Hold ; |
| Left Shift | Backspace (left thumb inner) | Hold Backspace |
| Right Shift | ' (home row rightmost) | Hold ' |
| Cmd/GUI | Dedicated key (bottom row leftmost) | Tap or hold |
| Layer 1 | Tab (left thumb inner) | Hold Tab |
| Layer 2 | Enter (right thumb outer) | Hold Enter |

### Key Notation Cross-Reference

The Option key on macOS is the same physical key as Alt. It appears under different names depending on context:

| Context | Name used | Example |
|---------|-----------|--------|
| ZSA / QMK firmware | `leftAlt` / `KC_LEFT_ALT` | `leftAlt+KC_Z` |
| macOS / AeroSpace config | `opt` | `alt-z` (AeroSpace uses `alt` not `opt`) |
| Terminal keybinding docs | `alt` | `alt-z` |
| Tmux | `M-` (Meta) | `M-z` |
| Pi keybindings.json | `alt` | `alt+z` |

So: **opt-z = alt-z = M-z = leftAlt+KC_Z** — all the same key.

### Dedicated Alt+Z Key

Physical position `[12]` (home row leftmost / inner column) is **hardcoded at the firmware level** to send `Alt+Z` (M-z) as a single keypress — not a hold-tap. This key exists purely to make tmux ergonomic:

- **Single tap** = tmux `prefix2` (`M-z`) — triggers tmux command mode without chording
- **Used as a prefix**: `Alt+Z then h/j/k/l` = tmux/vim pane navigation (vim-tmux-navigator mapping)
- `alt-z` is **explicitly left unused in AeroSpace** to protect this

### Tmux Prefix Keys

| Prefix | Keys | Ergonomics |
|--------|------|------------|
| `Ctrl+B` (default) | Hold Space + tap B | Two-finger chord |
| `M-z` (prefix2) | Single tap `[12]` | One key — preferred |

### Aerospace Modifier Saturation

AeroSpace uses **Alt as its primary modifier**. This means:

- `Alt + (almost every letter)` = **workspace switch** (A–Z minus z, i, f)
- `Alt + h/j/k/l` = focus window direction
- `Alt + Shift + h/j/k/l` = move window
- `Alt + Ctrl + h/j/k/l` = join containers
- `Alt + Tab` = cycle monitors
- `Alt + f` = fullscreen

**Consequence:** `Alt+letter` is almost entirely consumed by AeroSpace. When suggesting new keybindings for any tool that runs inside a terminal, **do not use bare `Alt+letter`** — it will likely be intercepted by the window manager before reaching the terminal.

Exceptions that are deliberately free:
- `Alt+Z` — tmux prefix2 (firmware key, passed through as terminal input)
- `Alt+I` — commented out in aerospace config, currently unbound

### Vim-Tmux Navigator

Pane navigation is intentionally prefixed with `Alt+Z` to avoid the AeroSpace collision:
```
Alt+Z then H  = pane left
Alt+Z then L  = pane right
Alt+Z then K  = pane up
Alt+Z then J  = pane down
```

### Layer 2 Arrow Cluster (hold Enter)

Layer 2 maps arrow keys to the IJKL cluster (vim-adjacent positions):
- `Enter(hold) + I` = Up
- `Enter(hold) + J` = Left
- `Enter(hold) + K` = Down
- `Enter(hold) + L` = Right
- `Enter(hold) + Y` = Page Up
- `Enter(hold) + H` = Page Down
- `Enter(hold) + U` = Home
- `Enter(hold) + O` = End

### Why Keybind Space Is Exhausted

Chording constraints on this board:
- `Ctrl+key`: requires holding the **right thumb** (Space) while pressing an alpha key — workable for single combos, not chains
- `Alt+key`: almost entirely consumed by AeroSpace at the OS level
- `Shift+key`: requires holding Backspace (left thumb) or `'` (right pinky) — fine for text, tiring for hotkeys
- `Ctrl+Alt+key`: requires hold Space + hold Z + key — three-finger awkward
- `Ctrl+Shift+key`: requires two hold-taps simultaneously — uncomfortable
- Layer combos: Layer keys are on thumb keys already used for Ctrl and Shift

The inner-column keys (`F5` at QWERTY row, `Alt+Z` at home row, `Cmd` at bottom row) exist precisely because normal modifier slots are full. Any new global shortcut suggestions should prioritize:
1. Layer 1 or Layer 2 combos (hold Tab or hold Enter + key)
2. Tmux prefix (`M-z`) + key sequences (not simultaneous chords)
3. Vim modal bindings (no modifier needed in normal mode)
4. `Cmd+key` combinations (GUI key is dedicated, less saturated than Alt/Ctrl)

---

## Workflow Tier

**Low-care** - Agent can implement changes directly (except Bitwarden vault structure).

Agent should:
1. Edit files in `/Users/zaye/.local/share/chezmoi/`
2. Tell user to run `cma` to deploy
3. Never edit deployed files directly
