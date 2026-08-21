---
verified_at: 58a24086c9e6d80c8ccdebd7294002557da5d894
---

# Dev Processes

## Golden Rule
Edit ONLY in `~/.local/share/chezmoi/` (this repo). NEVER edit deployed files (`~/.zshrc`, `~/.config/`, `~/.bootstrap/`, `~/.pi/agent/`) — `cma` overwrites them.

## Dev Commands
| Command | What it does |
|---------|-------------|
| `cm diff` | Preview what would change (run before applying) |
| `cma` | Deploy: bw-session-check + bw sync + `chezmoi apply` + reload shell. Requires Tailscale up + valid BW session |
| `cme <file>` | `chezmoi edit --watch` — live-apply a managed file |
| `cm add <file>` | Track a new file |
| `apConfig` | Run OS ansible playbook (`macos.yml` on darwin, `cachyos.yml` on linux) with `--ask-become-pass` |
| `./bootstrap.sh` | Full fresh-machine setup |
| `bwsr` | Check/refresh Bitwarden session |

## Harness Development (`harness/`)
| Command | What it does |
|---------|-------------|
| `bun test` | Hermetic test suite (300+ tests, no network) |
| `bunx tsc --noEmit` | Typecheck |
| `bun link` | Install global `harness` command from source tree |

## Verification
- Dotfile changes: `cm diff` before `cma`; after apply, exercise the changed tool (reload shell, `tmux`, `nvim`, etc.)
- Template changes referencing secrets: verify Bitwarden item exists (`bw get item "<name>"`) before apply
- Harness changes: `bun test` + typecheck in `harness/`

## Background Services (required for `cma`)
| Service | Check | Fix |
|---------|-------|-----|
| Tailscale | `tailscale status` | `tailscale up` |
| Bitwarden session | `bw unlock --check` | `bwsr` or `bw unlock`; `.zshrc` auto-loads `~/.bw-session` |

## Error Surfaces (debug order)
1. Terminal output — chezmoi template errors, file conflicts, `run_*` script failures
2. Bitwarden CLI — network (Tailscale down), auth (BW_SESSION expired → 401), missing vault items
3. App-specific — `tmux info`, nvim `:checkhealth`, `sketchybar --reload`, `hyprctl clients -j`
4. System — Console.app / LaunchAgents (macOS), `brew services list`, systemd units (CachyOS)
