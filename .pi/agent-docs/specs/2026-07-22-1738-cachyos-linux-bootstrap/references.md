# References

## Files to read before implementing

- `bootstrap.sh` — macOS flow to mirror; Linux stubs at `install_chezmoi` (pacman branch), `run_os_setup`, and the non-Darwin main path (3-step flow to expand to 5).
- `dot_bootstrap/macos.yml` — play structure, gh-auth-via-Bitwarden block, pi extension install pattern (`creates:` guards) to replicate in `cachyos.yml`.
- `dot_local/bin/executable_apConfig` — Bitwarden session preamble + playbook invocation; add OS switch.
- `run_once_install_ansible.sh` — add Arch branch.
- `run_once_before_010_install_prerequisites.sh.tmpl`, `run_once_before_020_install_bitwarden.sh.tmpl` — darwin-gated; confirm no change needed.
- `dot_aerospace.toml` — canonical keybind source for the Hyprland port (modes, workspace letters, on-window-detected rules, gaps).
- `dot_config/aerospace-monitor/executable_focus-workspace.sh` / `executable_focus-monitor.sh` — multi-monitor daemon behavior being intentionally dropped (single monitor).
- `.chezmoiignore` — existing ignore patterns; append OS-gating template blocks.
- `dot_zshrc.tmpl` — darwin-only aliases to guard.
- `linux/dot_local/bin/` — empty/outdated; delete or repurpose.

## Docs

- **User's actual machine config (THE base):** https://github.com/ianyimi/base-cachyos-dotfiles — `.config/hypr/hyprland.lua` + `config/*.lua`, `.config/noctalia/config.toml`. Clone during implementation (was at /tmp/base-cachyos-dotfiles).
- Hyprland wiki (Lua config, ≥0.55): https://wiki.hypr.land/Configuring/Basics/Binds/ — `hl.bind(keys, dispatcher, flags?)`, submaps, mouse binds
- Hyprland Lua dispatchers: https://wiki.hypr.land/Configuring/Basics/Dispatchers/ — `hl.dsp.focus`, `hl.dsp.window.move/close/fullscreen/resize/pseudo`, `hl.dsp.layout`, `hl.dsp.submap`
- Workspace rules: https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/ — `hl.workspace_rule(...)`
- Window rules: https://wiki.hypr.land/Configuring/Basics/Window-Rules/ — `hl.window_rule({ match = {...}, workspace = "name:X", ... })`
- Lua config structure / require(): https://wiki.hypr.land/Configuring/Start/ — LSP stubs at /usr/share/hypr/stubs
- ~~cachyos-hyprland-settings GitHub repo~~ — **DO NOT USE**: master = old hyprlang, rework = older still; neither matches the live ISO's Lua config.
- Noctalia shell IPC: `noctalia msg <cmd>` patterns visible in base binds.lua (launcher, lock, clipboard, screenshots, volume/brightness)
- Tailscale on Arch: `pacman -S tailscale && systemctl enable --now tailscaled && tailscale up` — https://tailscale.com/kb/1052/install-arch
- chezmoi templating / OS detection: https://www.chezmoi.io/user-guide/templating/ (`.chezmoi.os`, `.chezmoiignore` templates)
- Ansible pacman module: https://docs.ansible.com/ansible/latest/collections/community/general/pacman_module.html
- Bitwarden CLI: https://bitwarden.com/help/cli/
- Noctalia shell (status bar, user-installed): https://github.com/noctalia-dev/noctalia-shell — verify package name + launcher capability on machine.

## Key research findings

- User's live-ISO CachyOS install ships **Lua** Hyprland config: `hyprland.lua` requiring 12 `config/*.lua` modules; `mainMod = SUPER`; `uwsm app --` launch prefix; noctalia handles all desktop-shell roles via `noctalia msg`.
- Base already contains complete Steam/Proton gaming window rules (name:gaming workspace, steam_app/gamescope fullscreen, launcher floats) — keep for Steam + Wallpaper Engine plan.
- Base variables.lua: TERMINAL=kitty→ghostty, BROWSER=firefox→helium, FILE_MANAGER=dolphin (keep), EDITOR=gnome-text-editor→`ghostty -e nvim`; MONITOR1-3 vars empty (single monitor, preferred/auto).
- SUPER vs ALT namespaces are disjoint — aerospace ALT scheme coexists with all base binds; only `ALT + Tab` (cycle_next) must be removed/rebound.
- Helium browser config dir on machine: `.config/net.imput.helium` → window class likely `net.imput.helium` (verify).
- Aerospace letter workspaces in use: 1-9 + A B C D E G M N O P Q R S T U V W X Y.

## Related specs

- None — first spec in this repo.
