# Tech Stack

## Language + Runtime
- Language: Shell scripting (Bash/Zsh)
- Runtime/Version: Zsh (macOS default), Bash

## Repo Structure
- Type: Single-package
- Purpose: Dotfiles management + development environment automation

## Dotfile Management
| Tool | Purpose |
|------|---------|
| chezmoi | Dotfile manager with templating |
| git | Version control |
| Bitwarden CLI (bw) | Secret injection via chezmoi integration |

## System Automation
| Tool | Purpose |
|------|---------|
| bootstrap.sh | One-command fresh machine setup |
| Ansible (playbooks in darwin/) | macOS configuration automation |
| Homebrew | Package management (macOS) |

## Shell Environment
| Tool | Purpose |
|------|---------|
| Zsh | Primary shell |
| Starship | Cross-shell prompt |
| zsh-autosuggestions | Command completion |
| zsh-syntax-highlighting | Syntax highlighting |

## Development Tools
| Tool | Purpose |
|------|---------|
| tmux | Terminal multiplexer |
| tmuxinator | tmux session manager (25+ project templates) |
| Neovim | Text editor |
| WezTerm | Terminal emulator |
| AeroSpace | macOS tiling window manager |
| SketchyBar | macOS status bar |

## CLI Tools
| Tool | Purpose |
|------|---------|
| fzf | Fuzzy finder |
| ripgrep (rg) | Fast grep alternative |
| bat | Cat alternative with syntax highlighting |
| lazygit | Git TUI |
| lazydocker | Docker TUI |
| gh | GitHub CLI |
| gh-dash | GitHub dashboard TUI |

## Development Runtimes
| Runtime | Manager | Purpose |
|---------|---------|---------|
| Node.js | fnm (Fast Node Manager) | JavaScript/TypeScript projects |
| Go | Homebrew | Go projects |
| Lua | Homebrew + luarocks | Neovim plugins, scripting |

## Project Management
| Tool | Purpose |
|------|---------|
| Git bare repos + worktrees | Multi-branch parallel development |
| apCloneProjects | Custom bulk project cloner |
| agent-os | AI development standards framework |

## Secret Management
| Tool | Purpose |
|------|---------|
| Bitwarden (self-hosted) | Centralized secret store |
| chezmoi + Bitwarden integration | Inject secrets into dotfiles on apply |

## Platform Support
- Primary: macOS (Darwin)
- Secondary: Linux (partial support in linux/ directory)

## Workflow Tier
- Tier: **Low-care**
- Rule: Agent can implement fully. Make changes directly to dotfiles, scripts, and configurations.
- Exception: Never modify Bitwarden vault structure or secret references without explicit approval. Changes to chezmoi templates that reference secrets require review.

## Pi Agent Configuration Workflow

**IMPORTANT:** This dotfiles repo contains TWO Pi configurations:

1. **Global Pi harness** (`pi-agent-base/`) → syncs to `~/.pi/agent/`
   - Source of truth for ALL machines
   - Edit files in `pi-agent-base/` ONLY
   - Run `cma` to sync to `~/.pi/agent/`
   - Global extensions, prompts, skills, settings

2. **Project-local Pi harness** (`.pi/`) → active when working in this dotfiles repo
   - Project-specific prompts (like `/brew-install`)
   - Specs for dotfiles changes
   - Does NOT sync to other projects

### Editing Rules

| What | Where to Edit | Why |
|------|---------------|-----|
| Global Pi settings | `pi-agent-base/settings.json` | Syncs to `~/.pi/agent/` on all machines |
| Global Pi extensions | `pi-agent-base/extensions/` | Available in ALL Pi sessions |
| Dotfiles project prompts | `.pi/prompts/` | Only active in this repo |
| Ansible playbook | `dot_bootstrap/macos.yml` | Source syncs to `~/.bootstrap/macos.yml` |

### Sync Workflow

```bash
# After editing pi-agent-base/
cma  # Runs chezmoi apply
     # → Executes run_after_sync-pi-agent-base.sh.tmpl
     # → Syncs pi-agent-base/ to ~/.pi/agent/
     # → Preserves runtime files (auth.json, sessions/, git/)

# Test changes
pi   # Restart Pi with updated config
```

**See:** `pi-agent-base/WORKFLOW.md` for full workflow documentation
