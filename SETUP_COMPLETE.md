# Setup Complete! 🎉

Your dotfiles repository is now fully configured for **one-command installation** on any fresh Mac.

## Single Command Installation

Share this with anyone (including future you) who wants to set up a new Mac:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ianyimi/dotfiles/master/bootstrap.sh)
```

That's it! No prerequisites needed.

---

## What This Sets Up Automatically

### 1. System Prerequisites
- Xcode Command Line Tools
- Homebrew package manager
- Git

### 2. Network Access
- Tailscale (installed and connected to your tailnet)
- Required for accessing your Vaultwarden server

### 3. Secret Management
- Bitwarden CLI
- Configured to connect to `unraid.tail68d30.ts.net/vault`
- Session management for seamless access

### 4. Dotfiles & Configs
- Shell configuration (zsh with starship prompt)
- Neovim, tmux, aerospace, sketchybar configs
- Agent-OS base installation at `~/agent-os`
- Clawdbot configuration
- All configs with secrets populated from Bitwarden

### 5. Development Tools
- See README.md for complete list of installed applications

---

## Repository Structure

```
~/.local/share/chezmoi/
├── bootstrap.sh                                    # Single-command bootstrap script
├── README.md                                       # Main documentation
├── INSTALLATION_REVIEW.md                          # Detailed installation guide
├── BITWARDEN_SETUP.md                             # Guide for adding more secrets
├── SETUP_COMPLETE.md                              # This file
│
├── run_once_before_010_install_prerequisites.sh.tmpl   # Installs Homebrew, git, Xcode CLT
├── run_once_before_015_install_tailscale.sh.tmpl      # Installs and connects Tailscale
├── run_once_before_020_install_bitwarden.sh.tmpl              # Configures Bitwarden CLI
├── run_after_sync-agent-os-base.sh.tmpl               # Syncs agent-os-base to ~/agent-os
│
├── dot_zshrc                                      # Shell configuration
├── dot_bootstrap/macos.yml                        # Ansible playbook (optional full setup)
├── agent-os-base/                                 # Agent-OS source (syncs to ~/agent-os)
├── private_dot_clawdbot/                         # Clawdbot configs
│   └── private_clawdbot.json.tmpl                # With Bitwarden template for API token
│
└── ... (all other dotfiles)
```

---

## Key Features

### ✓ Bitwarden Integration
- Secrets never committed to git
- Template files use `{{ (bitwarden "item" "Item Name").login.password }}` syntax
- See BITWARDEN_SETUP.md for adding more secrets

### ✓ Agent-OS Integration
- Base installation managed by chezmoi
- Located at `~/agent-os` after sync
- Symlinks created automatically for `aopi` command
- Can install agent-os as a project without conflicts

### ✓ Tailscale Dependency Handling
- Automatically installed and connected before Bitwarden setup
- Required for accessing self-hosted Vaultwarden server
- Gracefully skips if already connected

### ✓ Idempotent Scripts
- `run_once_before_*` scripts only run once
- Safe to run `chezmoi apply` multiple times
- Detects existing installations and skips redundant steps

---

## Testing on Fresh Machine

To test the full installation flow:

1. **VM or New Machine**: Best option for true testing
2. **Run Bootstrap**: 
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/ianyimi/dotfiles/master/bootstrap.sh)
   ```
3. **Follow Prompts**:
   - Enter system password when asked
   - Authenticate Tailscale in browser
   - Enter Bitwarden master password
4. **Verify**:
   ```bash
   # Check installations
   which brew tailscale bw chezmoi
   
   # Check Tailscale connection
   tailscale status
   
   # Check Bitwarden login
   bw login --check
   
   # Check agent-os
   ls -la ~/agent-os/
   aopi --help
   
   # Check secrets populated
   cat ~/.clawdbot/clawdbot.json | jq '.gateway.auth.token'
   ```

---

## Next Steps

### Adding More Secrets

See [BITWARDEN_SETUP.md](./BITWARDEN_SETUP.md) for:
- Adding API keys to zshrc (OpenAI, Anthropic)
- Managing project .env files
- Using custom fields for multiple values

### Extending Bootstrap

To add more to the initial setup:
1. Add files to chezmoi: `chezmoi add ~/.config/myapp/config`
2. Convert to template if secrets needed: `mv file.ext file.ext.tmpl`
3. Add to Ansible playbook (`dot_bootstrap/macos.yml`) for system-level changes
4. Create `run_once_before_*` scripts for one-time setup tasks

### Maintenance

```bash
# Update dotfiles on current machine
cd ~/.local/share/chezmoi
git pull
chezmoi apply

# Or use the alias
cma

# Add new files
chezmoi add ~/.config/newapp/config

# Edit existing managed files
chezmoi edit ~/.zshrc

# See what would change
chezmoi diff
```

---

## Troubleshooting

### Tailscale Issues
```bash
# Check status
tailscale status

# Manual connection
sudo tailscale up --ssh --accept-routes

# Restart
sudo tailscale down && sudo tailscale up --ssh --accept-routes
```

### Bitwarden Issues
```bash
# Check login
bw login --check

# Check server
bw config server  # Should show: unraid.tail68d30.ts.net/vault

# Sync vault
bw sync

# Refresh session
bwsr
```

### Agent-OS Issues
```bash
# Check symlinks
ls -la ~/agent-os/scripts/

# Manually trigger sync
chezmoi execute-template < ~/.local/share/chezmoi/run_after_sync-agent-os-base.sh.tmpl | bash
```

See [INSTALLATION_REVIEW.md](./INSTALLATION_REVIEW.md) for detailed troubleshooting.

---

## Security Notes

1. **Never commit secrets** to git
   - Always use Bitwarden templates
   - Check with: `git log --all -S "password" -p`

2. **Tailscale provides encrypted access** to your homelab
   - All traffic to Vaultwarden goes through Tailscale
   - No need to expose Vaultwarden publicly

3. **Bitwarden master password** is the key to everything
   - Store it securely (not in this repo!)
   - Session management handles day-to-day access

4. **Bootstrap script is safe to share**
   - No secrets embedded
   - Only installs and configures tools
   - Secrets fetched from Bitwarden after authentication

---

## Documentation

- **[README.md](./README.md)** - Overview and quick start
- **[INSTALLATION_REVIEW.md](./INSTALLATION_REVIEW.md)** - Detailed installation guide, sequence, troubleshooting
- **[BITWARDEN_SETUP.md](./BITWARDEN_SETUP.md)** - Complete guide to adding secrets, patterns, examples
- **[SETUP_COMPLETE.md](./SETUP_COMPLETE.md)** - This file - summary and reference

---

## Credits

- **chezmoi** - Dotfiles management with templating
- **Bitwarden** - Secret management
- **Tailscale** - Secure network access
- **agent-os** - AI-powered development workflows
