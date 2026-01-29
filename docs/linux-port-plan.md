# Linux Dotfiles Port - Implementation Plan

## Executive Summary

This document outlines the plan to port your macOS dotfiles to Linux, creating a unified bootstrap experience where a single command works on both platforms. The goal is to maintain identical keybindings and workflows across macOS and Linux.

**Feasibility: YES** - All components have Linux equivalents with direct keybind compatibility.

---

## Current macOS Stack

| Component | macOS Tool | Purpose |
|-----------|------------|---------|
| Window Manager | Aerospace | Tiling WM with hjkl navigation, workspaces 1-9 + A-Y |
| Status Bar | SketchyBar | Custom menu bar with workspace indicators |
| Window Borders | JankyBorders | Visual border around focused window |
| Terminal | Ghostty | GPU-accelerated terminal |
| Shell | zsh + Starship | Shell with custom prompt |
| Editor | Neovim | Text editor (fully portable) |
| Multiplexer | tmux | Terminal multiplexer (fully portable) |
| Secrets | Bitwarden CLI | Password management (fully portable) |

---

## Linux Tool Options

### 1. Window Manager (Aerospace Replacement)

Your keybinds use Alt (Option) as the primary modifier with hjkl navigation. All options below support this.

#### Option A: Hyprland (Recommended)
- **Pros:**
  - Most feature-rich Wayland compositor
  - Excellent animations and visual polish
  - Large community, extensive documentation
  - Native XWayland support for legacy apps
  - Direct keybind syntax similar to Aerospace
  - Per-monitor workspace support
  - Window rules for auto-assignment (like your `on-window-detected`)
- **Cons:**
  - Wayland-only (no X11)
  - Slightly higher resource usage than minimal WMs
  - Occasional breaking changes between versions

#### Option B: Niri
- **Pros:**
  - Unique "scrollable tiling" paradigm (windows never resize when adding new ones)
  - Written in Rust (fast, safe)
  - Simpler mental model - windows on infinite horizontal strip
  - Built-in screenshot tool
  - Mixed DPI/fractional scaling works well
- **Cons:**
  - XWayland via `xwayland-satellite` (less seamless than Hyprland)
  - Smaller community
  - Different tiling paradigm may require workflow adjustment
  - Fewer window layout options

#### Option C: Sway
- **Pros:**
  - Drop-in i3 replacement for Wayland
  - Most stable/mature Wayland compositor
  - i3-compatible config syntax (tons of examples online)
  - Extremely well-documented
- **Cons:**
  - Less flashy than Hyprland (minimal animations)
  - More conservative feature set

#### Option D: i3 (X11)
- **Pros:**
  - Battle-tested, extremely stable
  - Largest community of any tiling WM
  - Works on X11 (better compatibility with older apps)
- **Cons:**
  - X11-only (Wayland is the future)
  - No built-in compositor (need picom separately)

**Recommendation:** **Hyprland** - Best balance of features, community support, and direct keybind compatibility with Aerospace. Your Alt+hjkl navigation, workspace switching, and window rules all translate directly.

---

### 2. Status Bar (SketchyBar Replacement)

#### Option A: Waybar (Recommended for Wayland)
- **Pros:**
  - Native Wayland support
  - JSON config + CSS styling (easier than SketchyBar's Lua)
  - Built-in modules: workspaces, tray, clock, battery, network, etc.
  - Native Hyprland/Sway integration
  - Active development
- **Cons:**
  - Less programmable than SketchyBar
  - Fewer animation options

#### Option B: Eww (ElKowar's Wacky Widgets)
- **Pros:**
  - Most powerful/customizable option
  - Works on both X11 and Wayland
  - GTK-based widgets (not just a bar)
  - Lisp-like config language (Yuck)
  - Can replicate any SketchyBar feature
- **Cons:**
  - Steeper learning curve
  - More complex configuration
  - Higher resource usage for complex configs

#### Option C: Polybar (X11 only)
- **Pros:**
  - Extremely customizable
  - Huge theme community
  - Simple DSL for configuration
- **Cons:**
  - X11 only (won't work with Hyprland/Sway/Niri)
  - Would need AGS or Waybar for Wayland

#### Option D: AGS (Aylur's GTK Shell)
- **Pros:**
  - TypeScript/JavaScript configuration
  - Full GTK widget system
  - Highly programmable
- **Cons:**
  - Newer, smaller community
  - Requires JS knowledge

**Recommendation:** **Waybar** for simplicity and native Hyprland integration, or **Eww** if you want feature parity with SketchyBar's programmability.

---

### 3. Window Borders

#### Option A: Hyprland Built-in (Recommended)
- Hyprland has native border support in config:
  ```
  general {
      border_size = 3
      col.active_border = rgba(ff0000ff)
      col.inactive_border = rgba(00000000)
  }
  ```
- No external tool needed

#### Option B: Picom (X11 only)
- Compositor with border, shadow, blur effects
- Only for X11 (i3)

**Recommendation:** Use Hyprland's built-in borders - direct equivalent to JankyBorders.

---

### 4. Application Launcher

You don't have one configured on macOS (likely using Spotlight), but Linux needs one:

#### Option A: Rofi (Recommended)
- Application launcher, window switcher, dmenu replacement
- Highly themeable
- Works on both X11 and Wayland (via rofi-wayland fork)

#### Option B: Wofi
- Native Wayland launcher
- Simpler than Rofi

#### Option C: Fuzzel
- Minimal Wayland launcher
- Very fast

**Recommendation:** **Rofi** (rofi-wayland) - Most flexible and well-documented.

---

### 5. Notification Daemon

#### Option A: Dunst (Recommended)
- Lightweight, highly configurable
- Works on X11 and Wayland

#### Option B: Mako
- Native Wayland
- Simple configuration

**Recommendation:** **Dunst** - works everywhere, well-documented.

---

## Keybind Translation Table

Your Aerospace keybinds translate directly to Hyprland:

| Action | Aerospace | Hyprland |
|--------|-----------|----------|
| Focus left | `alt-h` | `bind = ALT, H, movefocus, l` |
| Focus down | `alt-j` | `bind = ALT, J, movefocus, d` |
| Focus up | `alt-k` | `bind = ALT, K, movefocus, u` |
| Focus right | `alt-l` | `bind = ALT, L, movefocus, r` |
| Move left | `alt-shift-h` | `bind = ALT SHIFT, H, movewindow, l` |
| Move down | `alt-shift-j` | `bind = ALT SHIFT, J, movewindow, d` |
| Move up | `alt-shift-k` | `bind = ALT SHIFT, K, movewindow, u` |
| Move right | `alt-shift-l` | `bind = ALT SHIFT, L, movewindow, r` |
| Workspace 1 | `alt-1` | `bind = ALT, 1, workspace, 1` |
| Workspace B | `alt-b` | `bind = ALT, B, workspace, name:B` |
| Move to WS 1 | `alt-shift-1` | `bind = ALT SHIFT, 1, movetoworkspace, 1` |
| Fullscreen | `alt-f` | `bind = ALT, F, fullscreen, 0` |
| Resize +50 | `alt-up` | `bind = ALT, up, resizeactive, 0 -50` |
| Next monitor | `alt-tab` | `bind = ALT, Tab, focusmonitor, +1` |
| Float toggle | (service mode) | `bind = ALT, V, togglefloating` |

**Named workspaces (B, D, M, O, S, T, etc.)** work identically in Hyprland using `workspace, name:X` syntax.

---

## Window Rules Translation

Your `on-window-detected` rules translate to Hyprland's `windowrulev2`:

```
# Aerospace
[[on-window-detected]]
if.app-id = 'com.spotify.client'
run = "move-node-to-workspace M"

# Hyprland equivalent
windowrulev2 = workspace name:M, class:^(Spotify)$
```

| App | Aerospace app-id | Hyprland class |
|-----|------------------|----------------|
| Arc Browser | `company.thebrowser.browser` | N/A (use Firefox/Chrome) |
| Figma | `com.figma.Desktop` | `^(figma-linux)$` |
| Spotify | `com.spotify.client` | `^(Spotify)$` |
| Obsidian | `md.obsidian` | `^(obsidian)$` |
| Slack | `com.tinyspeck.slackmacgap` | `^(Slack)$` |
| Ghostty | `com.mitchellh.ghostty` | `^(ghostty)$` |

---

## Implementation Phases

### Phase 1: Bootstrap Infrastructure
1. Update `bootstrap.sh` to detect Linux distros (Ubuntu, Fedora, Arch)
2. Create `dot_bootstrap/linux.yml` Ansible playbook
3. Add Linux package installation logic
4. Create `.chezmoiignore` rules for OS-specific files

### Phase 2: Window Manager
1. Create `dot_config/hypr/hyprland.conf` with translated keybinds
2. Port all workspace bindings (1-9, A-Y)
3. Port window rules for app auto-assignment
4. Configure gaps, borders, and animations

### Phase 3: Status Bar
1. Create `dot_config/waybar/config.jsonc`
2. Create `dot_config/waybar/style.css`
3. Add workspace indicator module
4. Add system info modules (CPU, memory, network)
5. Integrate with Hyprland IPC for workspace events

### Phase 4: Supporting Tools
1. Configure Rofi for application launching
2. Configure Dunst for notifications
3. Set up screen locking (swaylock)
4. Configure screenshot tools (grim + slurp)

### Phase 5: Ansible Playbook (Linux)
Create `dot_bootstrap/linux.yml` with:

**Ubuntu/Debian packages (apt):**
- hyprland (from hyprland PPA or source)
- waybar
- rofi-wayland
- dunst
- grim, slurp (screenshots)
- wl-clipboard
- All CLI tools (git, neovim, tmux, fzf, ripgrep, etc.)

**Fonts:**
- fonts-hack
- JetBrains Mono Nerd Font

**From source/external:**
- Ghostty (no apt package yet)
- Starship prompt

### Phase 6: Testing & Refinement
1. Test on Ubuntu VM
2. Verify all keybinds work identically
3. Test multi-monitor support
4. Verify Bitwarden/Tailscale integration

---

## File Structure (Proposed)

```
~/.local/share/chezmoi/
├── bootstrap.sh                    # Updated for Linux
├── dot_bootstrap/
│   ├── macos.yml                   # Existing
│   └── linux.yml                   # NEW
├── dot_config/
│   ├── aerospace/                  # macOS only
│   ├── sketchybar/                 # macOS only
│   ├── hypr/                       # NEW - Linux only
│   │   ├── hyprland.conf
│   │   ├── keybinds.conf
│   │   └── windowrules.conf
│   ├── waybar/                     # NEW - Linux only
│   │   ├── config.jsonc
│   │   └── style.css
│   ├── rofi/                       # NEW - Linux only
│   │   └── config.rasi
│   ├── dunst/                      # NEW - Linux only
│   │   └── dunstrc
│   └── ...                         # Shared configs (nvim, starship, etc.)
├── .chezmoiignore                  # OS-conditional ignores
└── run_once_before_*               # OS-conditional scripts
```

---

## Chezmoi OS Conditionals

Use chezmoi templates for OS-specific handling:

```
# .chezmoiignore
{{ if eq .chezmoi.os "darwin" }}
dot_config/hypr
dot_config/waybar
dot_config/rofi
dot_config/dunst
{{ end }}

{{ if eq .chezmoi.os "linux" }}
dot_aerospace.toml
dot_config/aerospace
dot_config/sketchybar
{{ end }}
```

---

## Single Bootstrap Command

The same command works on both platforms:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/dotfiles/master/bootstrap.sh | bash
```

The script detects the OS and runs the appropriate setup.

---

## Recommended Linux Stack Summary

| Component | Tool | Notes |
|-----------|------|-------|
| Window Manager | **Hyprland** | Best Wayland WM, direct keybind compat |
| Status Bar | **Waybar** | Native Hyprland support, CSS styling |
| Borders | **Hyprland built-in** | No external tool needed |
| Launcher | **Rofi** | Most flexible, well-documented |
| Notifications | **Dunst** | Lightweight, works everywhere |
| Terminal | **Ghostty** | Same as macOS (cross-platform) |
| Screenshots | **grim + slurp** | Standard Wayland tools |
| Screen Lock | **swaylock** | Works with Hyprland |
| Clipboard | **wl-clipboard** | Wayland clipboard tools |

---

## Alternative Stack (If Choosing Niri)

If you prefer Niri's scrollable tiling paradigm:

| Component | Tool | Notes |
|-----------|------|-------|
| Window Manager | **Niri** | Unique workflow, Rust-based |
| Status Bar | **Waybar** | Works with Niri |
| XWayland | **xwayland-satellite** | Required for X11 apps |
| Rest | Same as above | |

Niri keybinds are similar but use different syntax. The scrollable paradigm is different from traditional tiling - windows don't resize when you add new ones.

---

## Decisions Made

1. **Window Manager:** Hyprland (confirmed)
2. **Status Bar:** Waybar (confirmed)
3. **Distro for testing:** Ubuntu VM

## Remaining Questions

1. **Arc Browser:** No Linux version - what browser to use? (Firefox, Chrome, Zen?)
2. **Additional tools:** Any Linux-specific tools you want added?

---

---

## Waybar Module Mapping (SketchyBar → Waybar)

Your SketchyBar displays these items. Here's how each maps to Waybar:

### Left Section

| SketchyBar | Waybar Module | Config |
|------------|---------------|--------|
| Apple menu | N/A (not needed on Linux) | Use Rofi for app launching |
| App menus | N/A | Linux apps have their own menus |
| Aerospace mode | `hyprland/submap` | Shows current keybind mode |
| Workspaces + app icons | `hyprland/workspaces` | Native, shows icons per workspace |
| Front app name | `hyprland/window` | Shows focused window title |

### Right Section

| SketchyBar | Waybar Module | Config |
|------------|---------------|--------|
| Spotify (art, song, artist) | `mpris` | Native MPRIS support for all media players |
| Date/Time | `clock` | Fully customizable format |
| Volume + slider | `pulseaudio` or `wireplumber` | Click to mute, scroll to adjust |
| CPU % + graph | `cpu` | Percentage, tooltip with details |
| RAM % | `memory` | Percentage, swap info in tooltip |
| Network (up/down speed) | `network` | Shows SSID, IP, speeds |
| Battery % + time | `battery` | Percentage, time remaining, charging state |

### Waybar Config Example

```jsonc
// ~/.config/waybar/config.jsonc
{
    "layer": "top",
    "position": "top",
    "height": 40,
    "modules-left": ["hyprland/workspaces", "hyprland/submap", "hyprland/window"],
    "modules-center": [],
    "modules-right": ["mpris", "pulseaudio", "cpu", "memory", "network", "battery", "clock"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "1",
            "2": "2",
            "B": "B",
            "M": "M",
            "T": "T",
            "urgent": "",
            "default": ""
        },
        "on-click": "activate"
    },

    "hyprland/submap": {
        "format": "{}",
        "tooltip": false
    },

    "hyprland/window": {
        "max-length": 50
    },

    "mpris": {
        "format": "{player_icon} {artist} - {title}",
        "format-paused": "{status_icon} {artist} - {title}",
        "player-icons": {
            "default": "▶",
            "spotify": ""
        },
        "status-icons": {
            "paused": "⏸"
        },
        "max-length": 40
    },

    "clock": {
        "format": "{:%a %d %b %I:%M %p}",
        "tooltip-format": "<tt>{calendar}</tt>"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰝟 muted",
        "format-icons": {
            "default": ["󰕿", "󰖀", "󰕾"]
        },
        "on-click": "pavucontrol",
        "on-scroll-up": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
        "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    },

    "cpu": {
        "format": " {usage}%",
        "tooltip": true,
        "interval": 2
    },

    "memory": {
        "format": " {percentage}%",
        "tooltip-format": "RAM: {used:0.1f}G / {total:0.1f}G\nSwap: {swapUsed:0.1f}G / {swapTotal:0.1f}G",
        "interval": 30
    },

    "network": {
        "format-wifi": " {essid}",
        "format-ethernet": "󰈀 {ipaddr}",
        "format-disconnected": "󰖪 disconnected",
        "tooltip-format": "SSID: {essid}\nIP: {ipaddr}\nUp: {bandwidthUpBits}\nDown: {bandwidthDownBits}",
        "on-click": "nm-connection-editor"
    },

    "battery": {
        "format": "{icon} {capacity}%",
        "format-charging": "󰂄 {capacity}%",
        "format-icons": ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"],
        "tooltip-format": "{timeTo}"
    }
}
```

### Waybar Styling (CSS)

```css
/* ~/.config/waybar/style.css */
* {
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
}

window#waybar {
    background: rgba(44, 46, 52, 0.96);
    color: #e2e2e3;
}

#workspaces button {
    padding: 0 8px;
    color: #7f8490;
    border-radius: 9px;
    margin: 4px 2px;
}

#workspaces button.active {
    color: #b39df3;
    background: #363944;
    border: 2px solid #b39df3;
}

#window {
    font-weight: bold;
}

#mpris {
    color: #9ed072;
}

#clock {
    padding: 0 12px;
}

#cpu {
    color: #76cce0;
}

#memory {
    color: #e7c664;
}

#network {
    color: #76cce0;
}

#battery {
    color: #9ed072;
}

#battery.warning {
    color: #f39660;
}

#battery.critical {
    color: #fc5d7c;
}

#pulseaudio {
    color: #e2e2e3;
}

#pulseaudio.muted {
    color: #7f8490;
}
```

### Feature Comparison

| Feature | SketchyBar | Waybar |
|---------|------------|--------|
| Workspace icons per app | ✅ Custom Lua | ✅ Built-in `format-icons` |
| Click to switch workspace | ✅ AppleScript | ✅ Native Hyprland IPC |
| Media artwork | ✅ AppleScript + download | ⚠️ No album art (text only) |
| Volume popup/slider | ✅ Custom popup | ✅ pavucontrol on click |
| CPU graph | ✅ Custom C provider | ⚠️ No graph (% only) |
| Network popup | ✅ Custom Lua | ✅ Tooltip |
| Color-coded thresholds | ✅ Lua logic | ✅ CSS classes |

**Limitations vs SketchyBar:**
1. No album artwork display (text-only media info)
2. No CPU graph visualization (percentage only)
3. Tooltips instead of interactive popups

**If you need these features**, we could add:
- Custom scripts for album art (possible but complex)
- `custom/cpu` module with a script outputting a graph character
- Or use Eww for specific widgets that need advanced features

---

## Sources

- [Niri GitHub](https://github.com/YaLTeR/niri)
- [Hyprland Wiki](https://wiki.hypr.land/)
- [Waybar GitHub](https://github.com/Alexays/Waybar)
- [Polybar](https://polybar.github.io/)
- [The Linux Cast - Niri Review](https://thelinuxcast.org/posts/2025/i-tried-niri/)
- [Hyprland Keybinds](https://github.com/JaKooLit/Hyprland-Dots/wiki/Keybinds)
- [macOS-like shortcuts in Hyprland](https://satya164.page/posts/macos-like-shortcuts-in-hyprland)
- [HyprSpace - Hyprland for macOS](https://github.com/patroza/HyprSpace)
