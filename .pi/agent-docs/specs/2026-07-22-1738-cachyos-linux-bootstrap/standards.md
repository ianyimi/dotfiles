# Standards for This Spec

## Applied preferences

- `developer-preferences.md` is currently empty — no recorded preferences to apply.
- Repo conventions observed and applied:
  - Bootstrap order is sacred: **Tailscale connects BEFORE Bitwarden** (self-hosted vault only reachable over tailnet).
  - `BW_SESSION` persisted to `~/.bw-session` (chmod 600), sourced everywhere.
  - Idempotency everywhere: `command -v` guards in shell, `--needed` for pacman, `creates:` args / `ignore_errors` for optional GUI apps in ansible (mirrors macos.yml).
  - run_once scripts OS-gated with `{{ if eq .chezmoi.os "..." }}` so they render empty elsewhere.
  - Colors/echo style in bootstrap.sh preserved (GREEN ✓ / YELLOW → / RED ✗).

## Spec-specific conventions

- **Bind scheme = COEXIST**: all base CachyOS `SUPER` binds kept verbatim (noctalia/system); aerospace scheme added on `ALT`. Only base bind removed: `ALT + Tab` cycle_next (→ previous workspace). Letter workspace set is exactly A B C D E G M N O P Q R S T U V W X Y (h/j/k/l/f/i/z reserved, same as aerospace).
- Hyprland config is **Lua** (`hyprland.lua` + `require("config.*")` — Hyprland ≥0.55). Base = user's real machine config at github.com/ianyimi/base-cachyos-dotfiles, NOT cachyos-hyprland-settings (both branches there are outdated hyprlang). Do NOT write hyprlang .conf files.
- Default apps: TERMINAL=ghostty, BROWSER=helium, FILE_MANAGER=dolphin, EDITOR=`ghostty -e nvim`, CALCULATOR=gnome-calculator. Keep `uwsm app --` launch prefix.
- Configs NOT carried into chezmoi: kitty, fish, micro, alacritty (alacritty stays installed, untracked; kitty removed by playbook cleanup task).
- No syncthing on Linux. Steam + Proton (gamescope, proton-ge) IS installed; base gaming window rules preserved.
- Noctalia owns launcher/notifications/lock/clipboard/screenshots/wallpaper via `noctalia msg` — do not install wofi/mako/hyprlock/hypridle/cliphist/grim/slurp.
- Any keybind with no exact Hyprland equivalent (join-with, accordion layout, alt-tab monitor focus) gets a documented approximation with a `# aerospace: <original>` comment.
- Linux-only additions (terminal launch, killactive, launcher, mouse binds) grouped in a clearly commented "linux additions" section.
- The playbook is named `cachyos.yml` (user's choice) even though it would run on any Arch derivative.
- Package names guessed from Arch repos/AUR must be marked `# VERIFY on machine` where uncertain (pi-coding-agent, noctalia-shell, helium-browser, oxlint).

## Known gotchas

- **Cannot fully test locally** — this repo is edited on macOS. `chezmoi apply` here must NOT deploy linux files (verify `.chezmoiignore` gating with `cm diff` after edits → expect zero linux-file changes on this Mac).
- `bootstrap.sh` chezmoi installer: pacman branch must be checked before snap (CachyOS has no snap).
- `tailscale up` on Linux needs `tailscaled` running first (`systemctl enable --now tailscaled`); `sudo tailscale up` prints auth URL and blocks until authed.
- Bitwarden CLI on Arch: `bitwarden-cli` is in [extra]; npm fallback if removed.
- Ansible `community.general.pacman` needs `become: true`; paru must run as regular user (never root) — `become: false`.
- Hyprland Lua named workspaces: `hl.dsp.window.move({ workspace = "name:X", follow = true })` — forgetting `name:` creates numeric workspace confusion. `follow = true` ≡ aerospace move+follow; omit for silent move.
- Lua submap API (`hl.dsp.submap`, submap bind definitions) — verify exact signature against wiki Binds > Submaps during implementation; deprecated hyprlang syntax will not parse.
- Base workspaces.lua pins numeric ws 1-3 persistent + name:gaming default — keep; letter workspaces auto-create on first focus.
- ALT modifier conflicts: ALT+F4-style app shortcuts, terminal alt-keys; accepted trade-off per user decision.
- Window `class` values on Wayland differ from macOS bundle IDs — final windowrules require `hyprctl clients` verification on the machine.
- chezmoi run_once ordering: `run_once_before_*` execute before file application — ansible install script has no `before_` prefix so it runs after files exist (needed: `~/.bootstrap/cachyos.yml` present before apConfig runs, which is post-apply — safe).
- First `chezmoi apply` on the CachyOS box will conflict with existing `~/.config/hypr` (CachyOS skel files). Bootstrap should note: chezmoi will overwrite; that's intended (full-replace decision).

## Verification checklist (run on the CachyOS machine)

1. `curl -fsSL https://raw.githubusercontent.com/ianyimi/dotfiles/master/bootstrap.sh | bash` on fresh-ish system.
2. `tailscale status` → connected; `bw unlock --check --session "$BW_SESSION"` → ok.
3. `chezmoi doctor` clean; `ls ~/.config/hypr/config` shows managed files.
4. `apConfig` completes: `ansible-playbook ~/.bootstrap/cachyos.yml` all green.
5. `hyprctl reload` → no errors; test alt-hjkl, alt-<letter>, alt-shift-<letter>, service submap.
6. `hyprctl clients -j | jq '.[].class'` → correct windowrule classes; fix + `cma`.
7. On the Mac: `cm diff` shows no linux files deploying; `cma` still clean.
