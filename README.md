# Dotfiles with Bitwarden Secret Management

Complete system configuration using chezmoi + Bitwarden for secure secret management.

Supports **macOS** and **Linux (Ubuntu)** with a single bootstrap command.

## 🚀 Quick Start

On a **brand new machine** (macOS or Linux), run this single command:

```bash
URL="https://raw.githubusercontent.com/ianyimi/dotfiles/feat/linux-port/bootstrap.sh"; (command -v curl >/dev/null && curl -fsSL "$URL" -o /tmp/bootstrap.sh || wget -qO /tmp/bootstrap.sh "$URL") && bash /tmp/bootstrap.sh && rm /tmp/bootstrap.sh
```

**You'll be prompted for:**
1. **System password** - For package installation and Tailscale setup
2. **Tailscale authentication** - Browser opens to log in and approve device
3. **Bitwarden master password** - If not already logged in (session persists)

**Everything else is automatic!**

### macOS
The bootstrap script will:
- ✓ Install Homebrew, Xcode Command Line Tools, git
- ✓ Install and connect Tailscale (required for Bitwarden access)
- ✓ Install and configure Bitwarden CLI
- ✓ Apply all dotfiles with secrets populated from Bitwarden
- ✓ Set up Aerospace (window manager), SketchyBar, JankyBorders
- ✓ Set up agent-os for AI-powered development workflows

### Linux (Ubuntu)
The bootstrap script will:
- ✓ Install essential packages (git, curl, build-essential)
- ✓ Install and connect Tailscale (required for Bitwarden access)
- ✓ Install and configure Bitwarden CLI
- ✓ Apply all dotfiles with secrets populated from Bitwarden
- ✓ Set up Hyprland (window manager), Waybar, Rofi, Dunst
- ✓ Run Ansible playbook for full system configuration

---

## 📋 What Gets Installed

### Applications (macOS)
- Browsers: Arc
- Media: Spotify, Plex
- Development: Ghostty Terminal, Neovim, LM Studio
- Tools: Obsidian, Discord, Handbrake, Syncthing
- Window Management: Aerospace, JankyBorders, SketchyBar

### Applications (Linux)
- Browsers: Zen Browser (via Flatpak)
- Media: Spotify (via Snap)
- Development: Ghostty Terminal, Neovim
- Tools: Obsidian, Discord, Slack, Syncthing (via Snap)
- Window Management: Hyprland, Waybar, Rofi, Dunst

### CLI Tools (Both Platforms)
- Development: git, gh, node, pnpm, npm, go, lua
- DevOps: kubectl, k9s, Azure CLI
- Utilities: tmux, tmuxinator, lazygit, lazydocker, fzf, ripgrep, bat, neofetch
- Shell: zsh with autosuggestions & syntax highlighting, starship prompt

### Languages & Runtimes
- Node.js (via fnm on macOS, NodeSource on Linux)
- Go
- Lua (with luarocks & lunajson)
- C toolchain

---

## 🔐 Secret Management Architecture

### How It Works

1. **Templates in Git (Public)**
   - Your dotfiles repo contains `.tmpl` files
   - Variables like `{{ (bitwarden "item" "name").login.password }}`
   - Safe to commit to public repositories

2. **Secrets in Bitwarden (Private)**
   - Actual secret values stored in your self-hosted Bitwarden
   - Encrypted and secure

3. **Applied Files (Private)**
   - `chezmoi apply` fetches secrets and creates real files
   - Files created in your home directory with actual values
   - Not tracked in git

### Example Workflow

**Template in git:**
```bash
# File: ~/.local/share/chezmoi/private_dot_config/private_api_keys.env.tmpl
export GITHUB_TOKEN="{{ (bitwarden "item" "GitHub Personal Access Token").login.password }}"
```

**Applied file on your machine:**
```bash
# File: ~/.config/api_keys.env
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
```

---

## 📦 Managing Project .env Files

### Adding a project's .env to your dotfiles

1. **Create the .env file:**
   ```bash
   cd ~/Desktop/Projects/my-project
   cat > .env << EOF
   DATABASE_URL=postgresql://localhost/mydb
   API_KEY=sk-actual-secret-here
   EOF
   ```

2. **Add to chezmoi:**
   ```bash
   chezmoi add ~/Desktop/Projects/my-project/.env
   ```

   This creates: `~/.local/share/chezmoi/Desktop/Projects/my-project/dot_env.tmpl`

3. **Edit the template:**
   ```bash
   chezmoi edit ~/Desktop/Projects/my-project/.env
   ```

4. **Replace secrets with Bitwarden variables:**
   ```env
   DATABASE_URL={{ (bitwarden "item" "My Project DB").login.password }}
   API_KEY={{ (bitwarden "item" "My Project API").login.password }}
   ```

5. **Apply changes:**
   ```bash
   chezmoi apply
   ```

6. **Commit (safe - only template):**
   ```bash
   cd ~/.local/share/chezmoi
   git add Desktop/Projects/my-project/dot_env.tmpl
   git commit -m "Add my-project .env template"
   git push
   ```

### On a new machine

```bash
# Run bootstrap (works on macOS and Linux)
URL="https://raw.githubusercontent.com/<your-username>/dotfiles/master/bootstrap.sh"; (command -v curl >/dev/null && curl -fsSL "$URL" -o /tmp/bootstrap.sh || wget -qO /tmp/bootstrap.sh "$URL") && bash /tmp/bootstrap.sh && rm /tmp/bootstrap.sh

# Projects clone with apCloneProjects
# Then apply configs
chezmoi apply

# All .env files automatically created in correct locations!
```

---

## 🛠 Commands Reference

### Bootstrap & Setup

| Command | Purpose |
|---------|---------|
| `bootstrap.sh` | Initial setup on fresh machine |
| `apConfig` | Full system configuration (ansible playbook) |
| `apConfig --skip-projects` | Setup without cloning projects |
| `apCloneProjects` | Interactive GitHub repo cloner |

### Chezmoi

| Command | Purpose |
|---------|---------|
| `chezmoi apply` | Apply all dotfiles + populate secrets |
| `chezmoi edit <file>` | Edit a tracked file's template |
| `chezmoi add <file>` | Start tracking a new file |
| `chezmoi diff` | See what would change |
| `chezmoi cd` | Go to chezmoi source directory |
| `chezmoi update` | Pull from git and apply changes |

### Bitwarden

| Command | Purpose |
|---------|---------|
| `bw login` | Login to Bitwarden |
| `bw unlock` | Unlock vault |
| `bw list items` | List all items in vault |
| `bw get item "name"` | Get specific item |

### Git Bare Repos & Worktrees

| Command | Purpose |
|---------|---------|
| `cd ~/Desktop/Projects/<repo>.git` | Enter bare repo |
| `git worktree add ../repo main` | Create worktree |
| `git worktree list` | List all worktrees |
| `git worktree remove ../repo` | Remove worktree |

---

## 📋 Required Bitwarden Items

Before running the bootstrap, create these in your Bitwarden vault:

### Essential Items

| Item Name | Type | Field | Value |
|-----------|------|-------|-------|
| `GitHub Personal Access Token` | Login | Password | `ghp_...` |
| `Anthropic API Key` | Login | Password | `sk-ant-...` |

### Optional Items (as needed)

| Item Name | Purpose |
|-----------|---------|
| `OpenAI API Key` | OpenAI API access |
| `<ProjectName> DB` | Database URLs for projects |
| `AWS Credentials` | AWS access keys |

### Storing Multiple Secrets in One Item

Use custom fields for related secrets:

**Item:** "Environment Variables"
- Custom Fields:
  - `api_key`: value1
  - `secret_key`: value2
  - `jwt_secret`: value3

**Usage in templates:**
```env
API_KEY={{ (bitwardenFields "item" "Environment Variables").api_key.value }}
SECRET_KEY={{ (bitwardenFields "item" "Environment Variables").secret_key.value }}
```

---

## 🔧 Customization

### Before Running Bootstrap

1. **Edit `bootstrap.sh`:**
   ```bash
   GITHUB_USERNAME="your-github-username"  # Change this!
   ```

2. **Edit `.chezmoi.toml.tmpl`:**
   - Set your Bitwarden server URL
   - Set your GitHub username

### Adding Your Own Scripts

- `run_once_*.sh` - Runs once on first apply
- `run_onchange_*.sh` - Runs when script changes
- `run_*.sh` - Runs every apply

Scripts are executed in alphabetical order. Use numeric prefixes for ordering:
- `run_once_before_010_install_prerequisites.sh`
- `run_once_before_020_install_bitwarden.sh`

---

## 🚨 Troubleshooting

### Bitwarden session expired

```bash
# Re-unlock
export BW_SESSION=$(bw unlock --raw)
echo "export BW_SESSION=\"$BW_SESSION\"" > ~/.bw-session

# Re-apply configs
chezmoi apply
```

### GitHub authentication failed

```bash
bw get password "GitHub Personal Access Token" | gh auth login --with-token
gh auth status
```

### Can't find Bitwarden item

```bash
# List all items
bw list items | jq '.[] | {name: .name, id: .id}'

# Get specific item (use exact name)
bw get item "GitHub Personal Access Token"
```

### Ansible playbook fails

Check `~/.bootstrap/macos.yml` (macOS) or `~/.bootstrap/linux.yml` (Linux) for errors. Common issues:
- Missing sudo password
- Homebrew not in PATH (macOS)
- Package not available in repos (Linux)
- Network connectivity for downloads

### .env files not created after cloning projects

```bash
# Make sure BW_SESSION is set
echo $BW_SESSION

# Re-apply with verbose output
chezmoi apply -v
```

---

## 🔒 Security Best Practices

### ✅ Safe to Commit

- All `.tmpl` files with Bitwarden variables
- Scripts in `dot_local/bin/`
- Configuration files with template variables
- The bootstrap script

### ❌ Never Commit

- Actual `.env` files in projects
- Files in your home directory (only templates)
- `~/.bw-session` (session tokens)
- Any file containing actual secrets

### Additional Security

- Use `private_` prefix for sensitive files (auto-chmod 600)
- Add `.env` to project `.gitignore` files
- Rotate Bitwarden master password regularly
- Use unique API tokens per machine if possible

---

## 📚 Additional Documentation

- `INSTALLATION_REVIEW.md` - Bootstrap sequence, script naming conventions, manual installation steps

---

## 🤝 Contributing

Feel free to fork and customize for your needs. This setup is designed to be:
- **Portable** - Works on any machine with one command
- **Secure** - Secrets never touch git
- **Reproducible** - Same config everywhere
- **Maintainable** - Templates make updates easy

---

## 🙏 Credits

Built with:
- [chezmoi](https://www.chezmoi.io/) - Dotfile manager
- [Bitwarden](https://bitwarden.com/) - Secret management
- [Ansible](https://www.ansible.com/) - System configuration
- [Homebrew](https://brew.sh/) - Package management (macOS)
- [Hyprland](https://hyprland.org/) - Wayland compositor (Linux)
- [Waybar](https://github.com/Alexays/Waybar) - Status bar (Linux)

Original setup forked from [Logan Donley's dotfiles](https://github.com/logandonley/dotfiles).

---

## 🧪 Development

### Testing on a fresh VM

Use this command to bypass GitHub's CDN cache when testing changes:

**macOS:**
```bash
curl -H "Cache-Control: no-cache" -fsSL "https://raw.githubusercontent.com/ianyimi/dotfiles/feat/linux-port/bootstrap.sh?$(date +%s)" -o /tmp/bootstrap.sh && bash /tmp/bootstrap.sh && rm /tmp/bootstrap.sh
```

**Linux (Ubuntu):**
```bash
wget --no-cache -q "https://raw.githubusercontent.com/ianyimi/dotfiles/feat/linux-port/bootstrap.sh?$(date +%s)" -O /tmp/bootstrap.sh && bash /tmp/bootstrap.sh && rm /tmp/bootstrap.sh
```

**Universal (both platforms):**
```bash
URL="https://raw.githubusercontent.com/ianyimi/dotfiles/feat/linux-port/bootstrap.sh?$(date +%s)"; (command -v curl >/dev/null && curl -H "Cache-Control: no-cache" -fsSL "$URL" -o /tmp/bootstrap.sh || wget --no-cache -qO /tmp/bootstrap.sh "$URL") && bash /tmp/bootstrap.sh && rm /tmp/bootstrap.sh
```

### Reset script

Interactive reset script with menu or flags.

**Interactive menu (recommended):**
```bash
curl -fsSL "https://raw.githubusercontent.com/ianyimi/dotfiles/master/reset.sh?$(date +%s)" -o /tmp/reset.sh && bash /tmp/reset.sh && rm /tmp/reset.sh
```

**Available flags:**

| Flag | Description |
|------|-------------|
| `--dotfiles` | Remove chezmoi source, config, and applied dotfiles (resets shell to bash) |
| `--apps` | Remove all brew-installed apps and CLI tools (Ghostty, Discord, Spotify, etc.) |
| `--wm` | Remove window manager (Aerospace, SketchyBar, JankyBorders) |
| `--tailscale` | Remove Tailscale app and config |
| `--bitwarden` | Remove Bitwarden CLI and session |
| `--homebrew` | Remove Homebrew and all packages |
| `--xcode` | Remove Xcode Command Line Tools |
| `--all` | Remove everything (full reset) |

**Examples with flags:**

`--dotfiles` - Quick reset, removes only dotfiles and chezmoi config. Resets shell to bash.
```bash
curl -fsSL "https://raw.githubusercontent.com/ianyimi/dotfiles/master/reset.sh?$(date +%s)" -o /tmp/reset.sh && bash /tmp/reset.sh --dotfiles && rm /tmp/reset.sh
```

`--apps` - Remove all installed applications (Ghostty, Discord, Spotify, Arc, etc.) and CLI tools.
```bash
curl -fsSL "https://raw.githubusercontent.com/ianyimi/dotfiles/master/reset.sh?$(date +%s)" -o /tmp/reset.sh && bash /tmp/reset.sh --apps && rm /tmp/reset.sh
```

`--wm` - Remove window manager tools (Aerospace, SketchyBar, JankyBorders). Restores default macOS menu bar and dock.
```bash
curl -fsSL "https://raw.githubusercontent.com/ianyimi/dotfiles/master/reset.sh?$(date +%s)" -o /tmp/reset.sh && bash /tmp/reset.sh --wm && rm /tmp/reset.sh
```

`--all` - Full factory reset. Removes everything including apps, Homebrew, and Xcode CLT.
```bash
curl -fsSL "https://raw.githubusercontent.com/ianyimi/dotfiles/master/reset.sh?$(date +%s)" -o /tmp/reset.sh && bash /tmp/reset.sh --all && rm /tmp/reset.sh
```

Multiple flags - Reset everything except Tailscale, Bitwarden, Homebrew, and Xcode CLT (useful for re-testing bootstrap).
```bash
curl -fsSL "https://raw.githubusercontent.com/ianyimi/dotfiles/master/reset.sh?$(date +%s)" -o /tmp/reset.sh && bash /tmp/reset.sh --dotfiles --apps --wm && rm /tmp/reset.sh
```

---

**Happy Configuring! 🎉**
