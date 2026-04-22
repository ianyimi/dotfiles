# Chezmoi Dotfiles Project

## Critical: File Editing Rules

**This is a chezmoi-managed dotfiles repository.**

### ONLY Edit Files In This Directory

```
/Users/zaye/.local/share/chezmoi/
```

**NEVER directly edit deployed files:**
- ❌ `~/.pi/agent/` (deployed by chezmoi)
- ❌ `~/.bootstrap/` (deployed by chezmoi)
- ❌ `~/.config/` (deployed by chezmoi)
- ❌ `~/.zshrc` (deployed by chezmoi)
- ❌ Any file in `~/` that is managed by chezmoi

### How It Works

1. **Edit** files in `/Users/zaye/.local/share/chezmoi/`
2. **Run** `cma` (chezmoi apply) to deploy changes
3. **Done** - chezmoi copies to the correct system locations

### File Mapping

| Chezmoi Source | Deployed To |
|----------------|-------------|
| `dot_zshrc` | `~/.zshrc` |
| `dot_bootstrap/macos.yml` | `~/.bootstrap/macos.yml` |
| `pi-agent-base/` | `~/.pi/agent/` |
| `dot_config/` | `~/.config/` |

**The `dot_` prefix becomes `.` when deployed.**

### Why This Matters

- Editing deployed files breaks chezmoi sync
- Changes in deployed locations get overwritten by `cma`
- Only changes in `/Users/zaye/.local/share/chezmoi/` persist in git

---

## Project Overview

**Type:** Dotfiles (shell/zsh, Bitwarden secrets, Ansible automation, Pi agent config)

**Stack:**
- Chezmoi for dotfiles management
- Ansible for macOS provisioning
- Bitwarden CLI for secrets
- Zsh + Starship
- Pi coding agent with custom extensions

## Pi Agent Configuration

**Source of truth:** `pi-agent-base/` (synced to `~/.pi/agent/` by chezmoi)

**Custom extensions:**
- `vim-powerline.ts` + `_vim-powerline/` - Combined vim modal editing + powerline status bar
- `auto-unescape-paths.ts` - Removes backslash-escapes from pasted file paths

**Settings:**
- Using forked `pi-image-preview` with spaces-in-filenames support
- Vim mode indicator in powerline (π INSERT / π NORMAL)
- Vim clipboard isolated (no system sync)

## Workflow Commands

```bash
# Apply dotfiles changes (from chezmoi source)
cma

# Apply Ansible provisioning
apConfig

# Edit chezmoi source files
nvim ~/.local/share/chezmoi/

# Check chezmoi diff before applying
chezmoi diff
```

## Services Required

- Tailscale (for network access)
- Bitwarden CLI session (for `cma` to work)

## Git Workflow

```bash
# Make changes in chezmoi source
cd ~/.local/share/chezmoi
nvim pi-agent-base/settings.json

# Test changes
cma

# Commit to dotfiles repo
git add .
git commit -m "feat: update pi settings"
git push
```

---

## Workflow Tier

**Low-care** - Agent can implement changes directly (except Bitwarden vault structure).

Agent should:
1. Edit files in `/Users/zaye/.local/share/chezmoi/`
2. Tell user to run `cma` to deploy
3. Never edit deployed files directly
