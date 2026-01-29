# Linux Dotfiles Port - Implementation Plan

## Summary

Port the macOS dotfiles configuration to Linux (Ubuntu), creating a unified bootstrap experience where a single command works on both platforms. The goal is to maintain identical keybindings and workflows.

**Key Decisions:**
- Window Manager: Hyprland (replaces Aerospace)
- Status Bar: Waybar (replaces SketchyBar)
- Browser: Zen Browser (replaces Arc)
- macOS-only apps: Comment out in Linux playbook

---

## Task 1: Save Spec Documentation

Create `agent-os/specs/2026-01-29-linux-dotfiles-port/` with:
- `plan.md` - This implementation plan
- `shape.md` - Shaping notes and decisions
- `references.md` - Reference to existing macOS configs

---

## Task 2: Create Linux Ansible Playbook

**File:** `dot_bootstrap/linux.yml`

Copy `macos.yml` structure and adapt:

### 2.1 Replace Package Manager
- Change `community.general.homebrew` → `ansible.builtin.apt`
- Change `community.general.homebrew_cask` → `ansible.builtin.apt` (or snap/flatpak)
- Add Hyprland PPA: `ppa:hyprwm/hyprland`

### 2.2 Package Mappings

| macOS (brew) | Linux (apt) | Notes |
|--------------|-------------|-------|
| git | git | Same |
| neovim | neovim | Same |
| tmux | tmux | Same |
| fzf | fzf | Same |
| ripgrep | ripgrep | Same |
| bat | bat | Same |
| lazygit | lazygit | Via GitHub releases |
| lazydocker | lazydocker | Via GitHub releases |
| gh | gh | Via GitHub CLI PPA |
| starship | starship | Via curl installer |
| zsh | zsh | Same |
| zsh-autosuggestions | zsh-autosuggestions | Same |
| zsh-syntax-highlighting | zsh-syntax-highlighting | Same |
| kubectl | kubectl | Via apt repo |
| k9s | k9s | Via snap or GitHub |
| node | nodejs | Via NodeSource PPA |
| go | golang | Same |
| lua | lua5.4 | Same |
| luarocks | luarocks | Same |

### 2.3 GUI Apps

| macOS (cask) | Linux | Notes |
|--------------|-------|-------|
| spotify | spotify | Via snap |
| arc | zen-browser | Via flatpak |
| obsidian | obsidian | Via snap/flatpak |
| ghostty | ghostty | Build from source |
| discord | discord | Via snap |
| slack | slack | Via snap |
| syncthing | syncthing | Via apt |
| keymapp | keymapp | Via AppImage or tarball from ZSA |
| mouseless | mouseless | Via AppImage from mouseless.click |

### 2.4 Comment Out (No Linux Equivalent)
```yaml
# macOS-only: No Linux equivalent
# - responsively
# - lm-studio (check if available)
# - plex (use web version)
# - handbrake-cli (check availability)
```

### 2.5 Replace macOS-Specific Tasks
- Remove: `defaults write com.apple.dock autohide`
- Remove: `osascript` commands
- Remove: `killall Dock`
- Remove: `brew services` commands
- Add: systemd user services for Hyprland autostart

### 2.6 Font Installation
- Change path: `~/Library/Fonts` → `~/.local/share/fonts`
- Run `fc-cache -fv` after font installation

---

## Task 3: Create Hyprland Configuration

**Directory:** `dot_config/hypr/`

### 3.1 Main Config (`hyprland.conf`)
- Source modular config files
- Monitor settings
- General gaps, borders, layout
- Input settings

### 3.2 Keybinds (`keybinds.conf`)
Translate all Aerospace keybinds:
- `$mainMod = ALT`
- Focus: ALT + HJKL
- Move: ALT + SHIFT + HJKL
- Workspaces: ALT + 1-9, A-Y
- Move to workspace: ALT + SHIFT + 1-9, A-Y
- Fullscreen: ALT + F
- Resize: ALT + UP/DOWN
- Monitor focus: ALT + TAB
- Service mode: ALT + SHIFT + SEMICOLON (submap)

### 3.3 Window Rules (`windowrules.conf`)
- Workspace assignments for apps
- Floating rules for system dialogs

### 3.4 Autostart (`autostart.conf`)
- Start waybar
- Start dunst

---

## Task 4: Create Waybar Configuration

**Directory:** `dot_config/waybar/`

### 4.1 Config (`config.jsonc`)
Modules to include:
- Left: `hyprland/workspaces`, `hyprland/submap`, `hyprland/window`
- Right: `mpris`, `pulseaudio`, `cpu`, `memory`, `network`, `battery`, `clock`

### 4.2 Styling (`style.css`)
Match SketchyBar color scheme:
- Background: `rgba(44, 46, 52, 0.96)`
- Text: `#e2e2e3`
- Highlight: `#b39df3`
- Status colors: green/yellow/orange/red

---

## Task 5: Create Supporting Tool Configs

### 5.1 Rofi (`dot_config/rofi/config.rasi`)
- Application launcher
- Theme matching Waybar colors

### 5.2 Dunst (`dot_config/dunst/dunstrc`)
- Notification daemon
- Dark theme matching system

---

## Task 6: Update Chezmoi Ignore Rules

**File:** `.chezmoiignore`

Add OS-conditional ignores for Linux/macOS specific configs.

---

## Task 7: Update Bootstrap Script

**File:** `bootstrap.sh`

### 7.1 Add Linux Setup Function
- Install Ansible if not present
- Run Linux playbook

### 7.2 Update OS Switch
Replace placeholder in `run_os_setup()`

### 7.3 Add Linux Tailscale Setup

---

## Task 8: Create Linux Run-Once Scripts

- Prerequisites script for Linux
- Bitwarden script for Linux

---

## Task 9: Update Tech Stack Documentation

Add Linux section to `agent-os/product/tech-stack.md`

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `dot_bootstrap/linux.yml` | Create |
| `dot_config/hypr/hyprland.conf` | Create |
| `dot_config/hypr/keybinds.conf` | Create |
| `dot_config/hypr/windowrules.conf` | Create |
| `dot_config/hypr/autostart.conf` | Create |
| `dot_config/waybar/config.jsonc` | Create |
| `dot_config/waybar/style.css` | Create |
| `dot_config/rofi/config.rasi` | Create |
| `dot_config/dunst/dunstrc` | Create |
| `.chezmoiignore` | Modify |
| `bootstrap.sh` | Modify |
| `run_once_before_010_install_prerequisites_linux.sh.tmpl` | Create |
| `run_once_before_020_install_bitwarden_linux.sh.tmpl` | Create |
| `agent-os/product/tech-stack.md` | Modify |
| `agent-os/specs/2026-01-29-linux-dotfiles-port/` | Create (spec folder) |
