# CachyOS Linux Bootstrap + Hyprland Aerospace Port — Plan

## Summary

Port the single-script macOS install flow (`bootstrap.sh` → chezmoi → Tailscale → Bitwarden → ansible) to CachyOS (Arch-based, Hyprland/Wayland). One curl-able script installs everything in the right order on a fresh CachyOS machine: chezmoi via pacman, Tailscale (pacman + systemd + `tailscale up`), Bitwarden CLI, `chezmoi init --apply`, then an ansible playbook (`cachyos.yml`) installing a *select* subset of programs via pacman/paru. Additionally, ship a chezmoi-managed Hyprland **Lua** config (full replace of `~/.config/hypr`; base = the user's actual machine config pushed to https://github.com/ianyimi/base-cachyos-dotfiles) whose keybinds add the aerospace scheme on `ALT` (hjkl focus/move, letter+number workspaces, service submap, app→workspace rules) while keeping all existing CachyOS `SUPER` system/noctalia binds, for a **single-monitor** setup with **noctalia** as the status bar (launcher, lock, notifications, clipboard, screenshots, wallpaper). Steam + Proton support is included (gaming window rules already exist in the base config). All stale `linux/` content is replaced.

## Build Order

- [x] Step 1: **bootstrap.sh Linux path** — Arch/CachyOS branch: pacman prerequisites (git, base-devel), chezmoi via pacman, `setup_tailscale_linux` (pacman + `systemctl enable --now tailscaled` + `tailscale up`), Bitwarden CLI via pacman/npm fallback, then shared `init_chezmoi` + Linux `run_os_setup` invoking `apConfig`. Testable: `bash -n bootstrap.sh` + dry-read of flow; full test on CachyOS box.
- [x] Step 2: **run_once scripts made cross-platform** — `run_once_install_ansible.sh` gains Arch path (`pacman -S ansible`); prerequisites/bitwarden run_once scripts get linux guards so nothing darwin-only executes. Testable: `chezmoi execute-template` renders empty on linux-only/darwin-only mismatch.
- [x] Step 3: **`dot_bootstrap/cachyos.yml` ansible playbook** — select program set (CLI dev stack, Pi agent + extensions, GUI subset, fonts, Hyprland ecosystem incl. noctalia check). Uses `community.general.pacman` and paru for AUR. Testable: `ansible-playbook --syntax-check`.
- [x] Step 4: **`apConfig` OS detection** — runs `~/.bootstrap/cachyos.yml` on Arch-family Linux, `macos.yml` on Darwin. Same Bitwarden session preamble. Testable: `bash -n` + logic review.
- [x] Step 5: **Hyprland Lua config in chezmoi** — `dot_config/hypr/` (linux-only via `.chezmoiignore`): user's actual `hyprland.lua` + `config/*.lua` as base; `variables.lua` app swaps (ghostty/helium/nvim), `binds.lua` keeps SUPER system binds + adds full aerospace ALT scheme + service submap, `windowrules.lua` adds app→letter-workspace rules (keeps gaming/steam rules), `workspaces.lua` adjusted for named letter workspaces. Also manage `dot_config/noctalia/config.toml`. Testable: `luac -p` syntax check locally; live test via `hyprctl reload` on CachyOS.
- [x] Step 5b: **Config pruning** — do NOT carry kitty/fish/micro/alacritty configs into chezmoi (alacritty & others stay installed but untracked; kitty optionally removed by playbook). Testable: `chezmoi managed` list review.
- [x] Step 6: **zshrc/tooling portability audit** — guard darwin-only aliases/paths (`/opt/homebrew`, `brew`, aerospace, sketchybar) with `{{ if eq .chezmoi.os "darwin" }}`; add linux equivalents where needed. Testable: `chezmoi execute-template < dot_zshrc.tmpl` with os=linux override.
- [x] Step 7: **.chezmoiignore platform gating** — ensure darwin-only files (aerospace, sketchybar, aerospace-monitor) don't deploy on linux, and hypr doesn't deploy on darwin. Testable: `chezmoi managed` diff reasoning.
- [x] Step 8: **Docs + verification checklist** — README section for CachyOS install; on-machine checklist (see standards.md → Verification).

## Out of scope

- Multi-monitor logic (focus-monitor daemon, workspace-to-monitor pinning, alt-tab monitor cycling) — single monitor machine.
- Porting the Swift `aerospace-monitor` daemon — Hyprland tracks per-workspace focus natively.
- Sketchybar / waybar / wofi / mako / hyprlock / hypridle / cliphist — noctalia handles bar, launcher, notifications, lock, clipboard, screenshots, wallpaper (confirmed from machine's binds.lua).
- Noctalia deep configuration — config.toml is tracked as-is; theming iteration happens later on the machine.
- kitty / fish / micro / alacritty configs — explicitly dropped from chezmoi management (user decision).
- Syncthing on Linux — explicitly excluded (installed on macOS only).
- Installing the full macOS program list — only the selected subset (see shape.md package table).
- Bitwarden vault changes — reuse existing `ANTHROPIC_API_KEY` etc.; no new secrets.
- GUI apps with no Linux build (Arc, Mouseless, Keymapp, LM Studio, Plex desktop, Handbrake GUI).
