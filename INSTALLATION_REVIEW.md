# Fresh Machine Installation Guide

## Quick Start - Single Command

On a **brand new Mac** with nothing installed, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ianyimi/dotfiles/master/bootstrap.sh)
```

This single command will:
- ✓ Install chezmoi
- ✓ Clone and apply your dotfiles
- ✓ Install Homebrew and prerequisites
- ✓ Install and connect Tailscale
- ✓ Configure Bitwarden
- ✓ Set up all configs automatically

**You will be prompted for:**
1. System password (for Tailscale and Homebrew)
2. Tailscale authentication (browser opens)
3. Bitwarden master password (if not logged in)

That's it! Everything else is automatic.

---

## Overview

This guide covers the complete setup process for a fresh macOS machine using this dotfiles repository. The installation is designed to run in the correct order automatically.

## Bootstrap Sequence

When you run `chezmoi init` and `chezmoi apply` on a fresh machine, scripts run in this order:

### 1. Prerequisites (010)
**Script:** `run_once_before_010_install_prerequisites.sh.tmpl`

**What it does:**
- Installs Xcode Command Line Tools
- Installs Homebrew
- Installs git

**User interaction:**
- May prompt to install Xcode CLT
- Homebrew installation requires password confirmation

---

### 2. Tailscale Installation (015)
**Script:** `run_once_before_015_install_tailscale.sh.tmpl`

**What it does:**
- Installs Tailscale via Homebrew
- Starts Tailscale app
- Runs `sudo tailscale up --ssh --accept-routes`
- Waits for you to authenticate via browser

**User interaction:**
- **System password:** Required for `sudo tailscale up`
- **Browser authentication:** Opens browser for Tailscale login
- **Device approval:** Approve the device in Tailscale admin console

**Why this runs early:**
Your Bitwarden server is on your Tailscale network (`unraid.tail68d30.ts.net/vault`), so you must be connected to the tailnet before Bitwarden setup can proceed.

---

### 3. Bitwarden Installation (020)
**Script:** `run_once_before_020_install_bitwarden.sh.tmpl`

**What it does:**
- Installs Bitwarden CLI
- Configures server URL (your Vaultwarden instance)
- Ensures you're logged in (prompts if not)

**User interaction:**
- **Bitwarden master password:** Only if not logged in
- Note: This is a `run_once_before` script, so it only runs during initial setup, not on every `chezmoi apply`

**Why Tailscale must be connected first:**
The script configures `bw config server unraid.tail68d30.ts.net/vault` which requires an active Tailscale connection.

---

### 4. Agent-OS Sync (after apply)
**Script:** `run_after_sync-agent-os-base.sh.tmpl`

**What it does:**
- Syncs `agent-os-base/` from chezmoi → `~/agent-os/`
- Creates symlinks for scripts (e.g., `project-install.sh` → `executable_project-install.sh`)
- Makes scripts executable

**User interaction:** None - fully automatic

---

## Complete Fresh Install Flow

### Step 1: Install Chezmoi (if not already installed)
```bash
# Install chezmoi
brew install chezmoi

# Or using the installer script
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### Step 2: Initialize Dotfiles
```bash
# Clone your dotfiles repo
chezmoi init https://github.com/ianyimi/dotfiles.git

# Or if already cloned
chezmoi init --apply https://github.com/ianyimi/dotfiles.git
```

### Step 3: Run Installation
```bash
chezmoi apply
```

**You will be prompted for:**

1. **System password** (for Tailscale: `sudo tailscale up`)
2. **Browser opens** for Tailscale authentication
   - Log into Tailscale
   - Approve the new device
3. **Wait for Tailscale connection** (script waits automatically)
4. **Bitwarden master password** (if not already logged in)

### Step 4: Verify Installation
```bash
# Check Tailscale connection
tailscale status

# Check Bitwarden login
bw login --check

# Check agent-os installation
ls -la ~/agent-os/
aopi --help

# Test your aliases
cma
```

---

## Troubleshooting

### Tailscale Issues

**Problem:** Tailscale won't connect
```bash
# Check status
tailscale status

# Manual connection
sudo tailscale up --ssh --accept-routes

# If stuck, restart
sudo tailscale down
sudo tailscale up --ssh --accept-routes
```

**Problem:** Can't reach Bitwarden server
```bash
# Verify Tailscale is connected
tailscale status | grep unraid

# Test connection
ping unraid.tail68d30.ts.net

# Test HTTPS access
curl -I https://unraid.tail68d30.ts.net/vault
```

### Bitwarden Issues

**Problem:** "Not found" when accessing items
```bash
# Sync with server
bw sync

# Verify login
bw login --check

# Check server config
bw config server
# Should show: https://unraid.tail68d30.ts.net/vault
```

**Problem:** Session expires too quickly
- Run `bwsr` to refresh the session
- Consider increasing server timeout (see roadmap in agent-os/product/roadmap.md)

### Agent-OS Issues

**Problem:** `aopi` command not found
```bash
# Check if symlink exists
ls -la ~/agent-os/scripts/project-install.sh

# Manually trigger sync
chezmoi execute-template < ~/.local/share/chezmoi/run_after_sync-agent-os-base.sh.tmpl | bash

# Verify alias
alias aopi
```

---

## On Second Machine

When setting up a second machine that already has Tailscale installed and authenticated:

1. The Tailscale script will detect existing connection and skip
2. The Bitwarden script will proceed immediately
3. Everything should "just work"

```bash
# On second machine
chezmoi init --apply https://github.com/ianyimi/dotfiles.git

# Prompts:
# - Bitwarden master password (if needed)
# - That's it! (Tailscale already connected)
```

---

## Script Naming Convention

Chezmoi runs scripts in alphabetical order:

- `run_once_before_NNN_*.sh.tmpl` - Runs BEFORE files are copied, only once
- `run_after_NNN_*.sh.tmpl` - Runs AFTER files are copied, every time
- Lower numbers (010, 015, 020) run before higher numbers

**Current sequence:**
1. `010` - Prerequisites (Xcode, Homebrew, git)
2. `015` - Tailscale (network access)
3. `020` - Bitwarden check (secrets management)
4. (after) - Agent-OS sync

---

## Manual Installation Order (if needed)

If you need to run steps manually:

```bash
# 1. Prerequisites
brew install git

# 2. Tailscale
brew install --cask tailscale
sudo tailscale up --ssh --accept-routes

# 3. Bitwarden
brew install bitwarden-cli
bw config server https://unraid.tail68d30.ts.net/vault
bw login zaye.dev@proton.me

# 4. Initialize chezmoi
chezmoi init --apply https://github.com/ianyimi/dotfiles.git
```

---

## Security Notes

1. **Never commit secrets** - Use Bitwarden templates only
2. **Tailscale security** - Provides encrypted network access to homelab
3. **Bitwarden master password** - Only prompted once, session persists
4. **SSH keys** - Not managed by this dotfiles repo (yet)

---

## Next Steps After Installation

After the initial setup completes:

1. **Configure project .env files** - Use Bitwarden templates for project secrets (see README)
2. **Set up SSH keys** - Generate and add to GitHub/GitLab
3. **Install additional apps** - Run `apConfig` for full system configuration
