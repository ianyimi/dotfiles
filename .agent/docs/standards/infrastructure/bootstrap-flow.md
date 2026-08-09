---
applies_to: ["bootstrap.sh", "run_once_*", "dot_local/bin/executable_apConfig", "dot_config/hypr/**"]
---
# Bootstrap Ordering Contract

`bootstrap.sh` is the curl-able entry point (README.md:9-10), fetched raw from GitHub —
it runs OUTSIDE chezmoi's managed tree. Hard ordering (main(), bootstrap.sh:~530-600):

1. Prereqs — macOS: Xcode CLT → Homebrew; Arch: `pacman -S --needed git base-devel curl ansible`.
2. chezmoi install (pacman checked before snap on Linux).
3. **Tailscale before Bitwarden** — required to reach the self-hosted Vaultwarden.
4. **Bitwarden before `chezmoi init`** — `setup_bitwarden` runs inside `init_chezmoi` so
   `BW_SESSION` exists for templates; session persisted to `~/.bw-session` (chmod 600);
   template values exported as env vars (`BITWARDEN_EMAIL` …) because stdin isn't a TTY
   under `curl | bash`.
5. `chezmoi init --apply --branch "$BRANCH"` (`DOTFILES_BRANCH` override, bootstrap.sh:17).
6. `run_os_setup` → prompts to run `~/.local/bin/apConfig`.

Breaking this order breaks fresh-machine setup — treat it as an API contract.

- `apConfig` (dot_local/bin/executable_apConfig): re-validates `BW_SESSION` from
  `~/.bw-session`, self-heals ansible, selects playbook by `uname -s` (Darwin →
  `~/.bootstrap/macos.yml`, Linux → `~/.bootstrap/cachyos.yml`), runs
  `ansible-playbook --ask-become-pass`.
- `run_once_*` scripts are **idempotent safety nets, not owners** — bootstrap.sh owns the
  installs; run_once re-checks (run_once_before_020 header: "handled by bootstrap.sh").
  Every step must tolerate re-runs. Script style: see standards/shell/scripts.md.
- Hyprland config is modular Lua: `dot_config/hypr/hyprland.lua` is a pure require-list of
  `config/<topic>.lua` modules. New Hyprland settings go in the matching topic module.
