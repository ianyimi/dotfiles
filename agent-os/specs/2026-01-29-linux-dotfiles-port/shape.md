# Linux Dotfiles Port - Shaping Notes

## Problem Statement

Current dotfiles are macOS-only. Need to support Linux (Ubuntu) with the same keybindings and workflow.

## Key Decisions

### Window Manager: Hyprland

**Why Hyprland over alternatives:**
- Modern Wayland compositor with excellent tiling support
- Active development and community
- Smooth animations and good performance
- Supports the keybinding model we want (similar to i3/sway)
- Native support for gaps, borders, and workspaces like Aerospace

**Alternatives considered:**
- i3 (X11 only, want Wayland)
- Sway (good but Hyprland has better features)
- dwm (too minimal, requires recompilation for changes)

### Status Bar: Waybar

**Why Waybar:**
- Native Hyprland support
- Highly customizable with CSS
- Supports all needed modules (workspaces, system stats, media)
- JSON configuration (easy to template)

### Browser: Zen Browser

**Why Zen over alternatives:**
- Firefox-based (privacy-focused)
- Modern UI similar to Arc
- Available via Flatpak for easy installation
- Good tab management features

### Application Launcher: Rofi

**Why Rofi:**
- Fast and lightweight
- Highly themeable
- Can integrate with other tools (clipboard managers, etc.)

### Notification Daemon: Dunst

**Why Dunst:**
- Lightweight and configurable
- Good theme support
- Integrates well with Wayland/Hyprland

## Package Installation Strategy

### Primary: apt
- Most CLI tools available directly
- Add PPAs for specific tools (gh, NodeSource, etc.)

### Secondary: snap
- GUI applications where apt packages are outdated
- Spotify, Discord, Slack, Obsidian

### Tertiary: flatpak
- Zen Browser (not in standard repos)

### Manual Installation
- lazygit, lazydocker (GitHub releases)
- starship (curl installer)
- Ghostty (build from source until packages available)

## Keybinding Parity

Goal: Same muscle memory between macOS and Linux

| Action | macOS (Aerospace) | Linux (Hyprland) |
|--------|-------------------|------------------|
| Focus window | ALT + HJKL | ALT + HJKL |
| Move window | ALT + SHIFT + HJKL | ALT + SHIFT + HJKL |
| Switch workspace | ALT + 1-9, A-Y | ALT + 1-9, A-Y |
| Move to workspace | ALT + SHIFT + 1-9, A-Y | ALT + SHIFT + 1-9, A-Y |
| Fullscreen | ALT + F | ALT + F |
| Resize | ALT + UP/DOWN | ALT + UP/DOWN |
| Focus monitor | ALT + TAB | ALT + TAB |
| Service mode | ALT + SHIFT + ; | ALT + SHIFT + ; |

## Workspace Assignments

Same app-to-workspace mapping:
- B: Browser (Zen)
- M: Music (Spotify)
- O: Obsidian
- S: Slack
- T: Terminal (Ghostty)

## Visual Consistency

Using same color scheme from SketchyBar:
- Background: #2c2e34 (with transparency)
- Text: #e2e2e3
- Accent: #b39df3 (magenta)
- Green: #9ed072
- Yellow: #e7c664
- Orange: #f39660
- Red: #fc5d7c

## Open Questions (Resolved)

1. **Ghostty on Linux?** - Build from source until packages available
2. **Keymapp on Linux?** - Use AppImage or tarball from ZSA
3. **Mouseless on Linux?** - Check for Linux version availability
