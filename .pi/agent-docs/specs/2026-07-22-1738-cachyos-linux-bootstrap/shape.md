# CachyOS Linux Bootstrap — Shape

## 1. bootstrap.sh — Linux/Arch path

New/changed functions (keep existing macOS flow untouched):

```bash
# Detect distro family early
IS_ARCH=false
if [[ "$OS" == "Linux" ]] && [[ -f /etc/arch-release || -f /etc/cachyos-release ]] \
   || grep -qi 'arch\|cachyos' /etc/os-release 2>/dev/null; then
    IS_ARCH=true
fi
```

```bash
install_prerequisites_linux() {
    # 1. Ensure git + base-devel (needed for AUR builds later)
    sudo pacman -S --needed --noconfirm git base-devel curl
}
```

chezmoi install — the existing `pacman -S --noconfirm chezmoi` branch already works; move the pacman check ABOVE the snap check so CachyOS never tries snap.

```bash
setup_tailscale_linux() {
    # 1. Install via pacman if missing
    command -v tailscale &>/dev/null || sudo pacman -S --needed --noconfirm tailscale
    # 2. Enable + start the daemon (systemd)
    sudo systemctl enable --now tailscaled
    # 3. Already connected? tailscale status returns 0 when up
    if tailscale status &>/dev/null; then echo "already connected"; return 0; fi
    # 4. Authenticate — prints URL, waits for auth (mirror macOS flags)
    sudo tailscale up --accept-routes
}
```

```bash
setup_bitwarden() {
    # Make the brew call platform-aware:
    if ! command -v bw &>/dev/null; then
        if [[ "$OS" == "Darwin" ]]; then brew install bitwarden-cli
        elif $IS_ARCH; then sudo pacman -S --needed --noconfirm bitwarden-cli
        else npm install -g @bitwarden/cli; fi
    fi
    # ...rest unchanged (server config, login, ~/.bw-session)
}
```

Main flow for Linux becomes 5 steps (order matters — Tailscale BEFORE Bitwarden because the vault server is reachable only over tailnet):

```
[1/5] install_prerequisites_linux
[2/5] install_chezmoi
[3/5] setup_tailscale_linux
[4/5] init_chezmoi            # calls setup_bitwarden internally, then chezmoi init --apply
[5/5] run_os_setup            # replaces the "not yet implemented" stub → runs apConfig
```

`run_os_setup` Linux branch: identical to the Darwin branch (find `~/.local/bin/apConfig`, prompt, run) — delete the stub message.

## 2. run_once scripts

`run_once_install_ansible.sh` — add Arch:

```bash
install_on_arch() { sudo pacman -S --needed --noconfirm ansible; }
# in the Linux case:
if [ -f /etc/arch-release ] || grep -qi 'arch\|cachyos' /etc/os-release; then
    install_on_arch
elif ...
```

Also install paru here or in the playbook prerequisites play (see §3) — paru is preinstalled on CachyOS, so use `--needed` checks only.

`run_once_before_010_install_prerequisites.sh.tmpl` / `020_install_bitwarden.sh.tmpl`: already darwin-gated (`{{ if eq .chezmoi.os "darwin" }}`) — no change needed; verify they render empty on linux.

## 3. dot_bootstrap/cachyos.yml

Structure mirrors macos.yml plays. Key module: `community.general.pacman`; AUR via `paru` shell tasks (CachyOS ships paru; guard with `--needed`).

```yaml
---
- name: Prerequisites (git, paru, gh auth)
  hosts: localhost
  become: false
  connection: local
  tasks:
    - name: Ensure base packages
      become: true
      community.general.pacman:
        name: [git, base-devel, github-cli]
        state: present
    # gh auth block: identical to macos.yml (bw get password | gh auth login --with-token)

- name: Machine setup (shell)
  # zsh install + chsh — same as macos.yml but package via pacman

- name: Pacman Install (CLI)
  become: true
  tasks:
    - community.general.pacman:
        name: "{{ cli_packages }}"
        state: present

- name: AUR Install (paru)
  become: false
  tasks:
    - name: Install AUR packages
      ansible.builtin.shell: paru -S --needed --noconfirm {{ item }}
      loop: "{{ aur_packages }}"
```

### Package selection (select subset — user-approved groups)

| Group | pacman (repos incl. cachyos repos) | AUR (paru) | Other installer |
|---|---|---|---|
| Core CLI | git, github-cli, neovim, tmux, tmuxinator, starship, fzf, ripgrep, bat, lazygit, zsh, zsh-autosuggestions, zsh-syntax-highlighting, nodejs, npm, fnm, luarocks, go, tree-sitter-cli, jq | lazydocker, gh-dash (via `gh extension install dlvhdr/gh-dash`), oxlint | pnpm (`curl get.pnpm.io`), claude (`claude.ai/install.sh`), lunajson (`luarocks install`) |
| npm globals | — | — | eslint, eslint_d, @fsouza/prettierd (community.general.npm global) |
| Pi agent | — | pi-coding-agent (verify AUR name; fallback: npm global `@earendil-works/pi-coding-agent`) | `pi install npm:pi-btw`, `npm:pi-docparser`, `npm:lsp-pi`, `npm:pi-smart-fetch`, `npm:@browser-annotations/pi`, `git:https://github.com/ianyimi/pi-image-preview` (same creates: guards as macos.yml) |
| GUI subset | discord, obsidian | spotify, ghostty (check repo first — ghostty is in [extra] now), helium-browser-bin (already installed — `--needed` check only; # VERIFY name) | — |
| Gaming | steam (requires multilib repo — enabled by default on CachyOS), gamescope | proton-ge-custom-bin (# VERIFY; alternatively Proton enabled inside Steam settings) | — |
| Fonts | ttf-hack-nerd, ttf-jetbrains-mono-nerd, ttf-cascadia-code-nerd | — | — |
| Hyprland ecosystem | hyprland, uwsm, hyprpicker, wl-clipboard, noctalia check (`--needed`, keep user install) | noctalia-shell (# VERIFY name on machine) | — |

Rules:
- Every task `ignore_errors: true` only for GUI/optional apps (mirror macos.yml).
- No sketchybar/aerospace/borders plays. **No syncthing on Linux** (user decision).
- No wofi/mako/hyprlock/hypridle/cliphist/grim/slurp — noctalia covers launcher, notifications, lock, clipboard, screenshots, wallpaper (confirmed from machine binds.lua: `noctalia msg screenshot-region`, `session lock`, `panel-toggle clipboard`, etc.).
- Optional cleanup task: remove `kitty` (`pacman -Rns --noconfirm kitty`, `ignore_errors: true`) — user is ghostty-only; alacritty stays installed.
- Tailscale/bitwarden-cli/chezmoi NOT in playbook (bootstrap owns them) — but add `--needed` idempotent check tasks for safety.

## 4. apConfig (dot_local/bin/executable_apConfig)

```bash
# 1. Bitwarden session preamble — unchanged
# 2. Select playbook by OS:
case "$(uname -s)" in
  Darwin*) PLAYBOOK=~/.bootstrap/macos.yml ;;
  Linux*)  PLAYBOOK=~/.bootstrap/cachyos.yml ;;
esac
ansible-playbook "$PLAYBOOK" --ask-become-pass
```

## 5. Hyprland config — dot_config/hypr/ (LUA — Hyprland ≥0.55)

**Base = the user's actual machine config** at https://github.com/ianyimi/base-cachyos-dotfiles (`.config/hypr/`), cloned during implementation. NOT the cachyos-hyprland-settings GitHub repo (both branches there are outdated hyprlang).

**Bind philosophy (user decision): COEXIST.** All existing CachyOS `SUPER` binds are KEPT verbatim (noctalia launcher/lock/clipboard/notifications/control-center, hardware keys, hyprpicker, scratchpad, mouse binds, monitor focus). The aerospace scheme is ADDED on `ALT`. Exception: `ALT + Tab` is rebound from `cycle_next` → previous workspace.

```
dot_config/hypr/
├── hyprland.lua               # unchanged: require("config.*")
├── xdph.conf                  # carried as-is
└── config/
    ├── animations.lua         # base as-is
    ├── autostart.lua          # base as-is (noctalia via hl.on("hyprland.start"))
    ├── colors.lua             # base as-is
    ├── decorations.lua        # base as-is; gaps → aerospace main-monitor values (inner 3, outer 3, top 10) if desired
    ├── environment.lua        # base as-is (uwsm env note; nvidia lines stay commented)
    ├── inputs.lua             # base as-is
    ├── misc.lua               # base as-is (swallow, vrr, dwindle preserve_split)
    ├── monitors.lua           # base as-is (single monitor, preferred/auto)
    ├── variables.lua          # EDITED — app swaps (below)
    ├── binds.lua              # EDITED — aerospace ALT section appended (below)
    ├── windowrules.lua        # EDITED — app→letter-workspace rules appended; ALL existing rules kept (gaming/steam, PiP, floats, opacity)
    └── workspaces.lua         # EDITED — keep name:gaming rule; numeric 1-3 persistent rules stay; letter workspaces auto-create
```

Also manage `dot_config/noctalia/config.toml` (statusbar config, carried from base repo).

### variables.lua edits

```lua
TERMINAL     = "ghostty"                     -- was kitty
FILE_MANAGER = "dolphin"                     -- keep
BROWSER      = "helium"                      -- was firefox; VERIFY launch cmd (net.imput.helium desktop id)
EDITOR       = "ghostty -e nvim"             -- was gnome-text-editor
CALCULATOR   = "gnome-calculator"            -- keep
```

### binds.lua — appended aerospace section (Lua API)

```lua
----------------------------------
---- AEROSPACE (ALT) SCHEME ------
----------------------------------
local aero = "ALT"

-- focus (aerospace: alt-hjkl)
hl.bind(aero .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(aero .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(aero .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(aero .. " + L", hl.dsp.focus({ direction = "r" }))

-- move window (aerospace: alt-shift-hjkl)
hl.bind(aero .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
-- ...J/K/L likewise

-- join-with approximation (aerospace: alt-ctrl-hjkl) — dwindle preselect
hl.bind(aero .. " + CONTROL + H", hl.dsp.layout("preselect l"))  -- # aerospace: join-with left (approximation)
-- ...J/K/L likewise

-- fullscreen / layout (aerospace: alt-f, alt-period, alt-comma)
hl.bind(aero .. " + F", hl.dsp.window.fullscreen())
hl.bind(aero .. " + period", hl.dsp.layout("togglesplit"))       -- # aerospace: layout tiles horizontal vertical
hl.bind(aero .. " + comma", hl.dsp.window.pseudo({ action = "toggle" })) -- # aerospace: accordion (approximation)

-- resize (aerospace: alt-up/down ±50)
hl.bind(aero .. " + Up",   hl.dsp.window.resize({ x = 0, y = 50, relative = true }))
hl.bind(aero .. " + Down", hl.dsp.window.resize({ x = 0, y = -50, relative = true }))

-- previous workspace (aerospace: alt-tab focused other monitor; single-monitor adaptation)
-- NOTE: remove base `hl.bind("ALT + Tab", hl.dsp.window.cycle_next())` line
hl.bind(aero .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

-- workspaces: 1-9 + letters (exact aerospace set: A B C D E G M N O P Q R S T U V W X Y)
local wsKeys = { "1","2","3","4","5","6","7","8","9" }
local wsLetters = { "A","B","C","D","E","G","M","N","O","P","Q","R","S","T","U","V","W","X","Y" }
for _, k in ipairs(wsKeys) do
    hl.bind(aero .. " + " .. k, hl.dsp.focus({ workspace = tonumber(k) }))
    hl.bind(aero .. " + SHIFT + " .. k, hl.dsp.window.move({ workspace = tonumber(k), follow = true }))
    hl.bind(aero .. " + CONTROL + SHIFT + " .. k, hl.dsp.window.move({ workspace = tonumber(k) }))
end
for _, k in ipairs(wsLetters) do
    hl.bind(aero .. " + " .. k, hl.dsp.focus({ workspace = "name:" .. k }))
    hl.bind(aero .. " + SHIFT + " .. k, hl.dsp.window.move({ workspace = "name:" .. k, follow = true }))
    hl.bind(aero .. " + CONTROL + SHIFT + " .. k, hl.dsp.window.move({ workspace = "name:" .. k }))
end

-- service submap (aerospace: alt-shift-semicolon)
hl.bind(aero .. " + SHIFT + semicolon", hl.dsp.submap("service"))
-- inside submap: escape = hyprctl reload + reset; F = float toggle + reset;
-- backspace = close-others script + reset; SHIFT+hjkl = preselect + reset
-- (exact hl.submap API per wiki Binds > Submaps — verify signature during implementation)
```

**Conflict resolution within existing SUPER binds:** none needed — SUPER and ALT namespaces are disjoint. The ONLY base-config change in the bind section is deleting the old `ALT + Tab` cycle_next line. Base `mainMod .. " + SHIFT + 1/2/3"` (move to monitor) and `mainMod .. " + TAB + ..."` binds remain untouched.

**Letter conflicts with base SUPER binds: none** (base uses SUPER+letters; aerospace uses ALT+letters). Reserved aerospace letters (no workspace): F H I J K L Z — replicate exactly.

### windowrules.lua — appended aerospace assignments

All existing rules kept (gaming/steam → name:gaming, PiP, floats, opacity, modals). Appended:

```lua
-- Aerospace app → workspace assignments (verify classes: hyprctl clients -j | jq '.[].class')
hl.window_rule({ match = { class = "^(net\\.imput\\.helium|helium)$" }, workspace = "name:B" })   -- Arc → Helium
hl.window_rule({ match = { class = "^(Spotify|spotify)$" }, workspace = "name:M" })
hl.window_rule({ match = { class = "^(obsidian)$" }, workspace = "name:O" })
hl.window_rule({ match = { class = "^(Slack)$" }, workspace = "name:S" })
hl.window_rule({ match = { class = "^(com\\.mitchellh\\.ghostty|ghostty)$" }, workspace = "name:T" })
hl.window_rule({ match = { class = "^(figma-linux)$" }, workspace = "name:D" })  -- if installed
-- macOS 'finder/system preferences float' ≡ base dolphin + settings float rules (already present)
```

### Helper script

`dot_config/hypr/scripts/executable_close-others.sh` — port of aerospace `close-all-windows-but-current` (service submap backspace):

```bash
# 1. Active window address + workspace id: hyprctl activewindow -j
# 2. hyprctl clients -j | jq: windows on same workspace, address != active
# 3. hyprctl dispatch closewindow address:0x... for each
```

## 6. Platform gating

`.chezmoiignore` additions (template):

```
{{ if ne .chezmoi.os "darwin" }}
.aerospace.toml
.config/sketchybar
.config/aerospace-monitor
.glzr
{{ end }}
{{ if ne .chezmoi.os "linux" }}
.config/hypr
.bootstrap/cachyos.yml
{{ end }}
{{ if ne .chezmoi.os "darwin" }}
.bootstrap/macos.yml
{{ end }}
```

(Note: `.chezmoiignore` IS already a template — append these blocks.)

## 7. dot_zshrc.tmpl portability

- Wrap darwin-only bits: `claude-zaye` alias (`/opt/homebrew/bin/claude`), `ocu` (brew), any `brew`-referencing aliases → `{{ if eq .chezmoi.os "darwin" }}`.
- Add linux block where needed: pacman/paru update alias (e.g. `alias up="paru -Syu"`), fnm init path.
- Keep bitwarden session block, starship, aliases shared.
- Verify: `chezmoi execute-template --init` not required; use `chezmoi cat ~/.zshrc` on the CachyOS box after apply.
