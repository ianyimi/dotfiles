# Pi Agent Configuration Workflow

## Source of Truth

**`pi-agent-base/` is the ONLY place to make changes.**

`~/.pi/agent/` is automatically synced from `pi-agent-base/` on every `chezmoi apply`.

---

## Making Changes

### 1. Edit Files in `pi-agent-base/`

```bash
# Edit settings
nvim pi-agent-base/settings.json

# Edit extensions
nvim pi-agent-base/extensions/my-extension.ts

# Add documentation
nvim pi-agent-base/extensions/README-MY-FEATURE.md
```

### 2. Sync to `~/.pi/agent/`

```bash
chezmoi apply
```

This runs `run_after_sync-pi-agent-base.sh.tmpl` which:
- Rsyncs `pi-agent-base/` → `~/.pi/agent/`
- Excludes runtime files: `auth.json`, `sessions/`, `bin/`, `.git/`
- Preserves git packages installed at runtime

### 3. Restart Pi to Apply Changes

```bash
pi
```

### 4. If Packages Changed, Reinstall

```bash
# If you changed settings.json packages array
pi update

# Or reinstall specific package
pi install git:https://github.com/ianyimi/pi-powerline-footer
```

---

## Complete Test Workflow

```bash
# 1. Make changes to pi-agent-base
nvim pi-agent-base/settings.json

# 2. Sync to ~/.pi/agent
chezmoi apply

# 3. Reinstall Pi packages if needed
pi update

# 4. Restart Pi
pi

# ✅ Changes are now active
```

---

## Testing Ansible Playbook Changes

When you update `dot_bootstrap/macos.yml`:

```bash
# 1. Edit the Ansible playbook
nvim dot_bootstrap/macos.yml

# 2. Test syntax
ansible-playbook dot_bootstrap/macos.yml --syntax-check

# 3. Sync to ~/.bootstrap/
chezmoi apply dot_bootstrap/macos.yml

# 4. Run the playbook
apConfig
```

---

## What NOT to Do

❌ **Don't edit `~/.pi/agent/` files directly** - changes will be overwritten on next `chezmoi apply`

❌ **Don't edit `~/.bootstrap/macos.yml` directly** - edit `dot_bootstrap/macos.yml` in chezmoi source

✅ **Always edit in chezmoi source** (`pi-agent-base/` or `dot_bootstrap/`)

---

## File Structure

```
~/.local/share/chezmoi/         # Chezmoi source (git repo)
├── pi-agent-base/              # ← EDIT HERE
│   ├── settings.json           # Package list, Pi config
│   ├── AGENTS.md               # Global agent context
│   ├── extensions/             # Custom extensions
│   ├── prompts/                # Custom prompts
│   ├── skills/                 # Custom skills
│   └── templates/              # Prompt templates
├── dot_bootstrap/
│   └── macos.yml               # ← EDIT HERE for Ansible
└── run_after_sync-pi-agent-base.sh.tmpl  # Auto-sync script

~/.pi/agent/                    # ← SYNCED FROM pi-agent-base/
├── settings.json               # (synced)
├── AGENTS.md                   # (synced)
├── extensions/                 # (synced)
├── git/                        # (runtime, excluded from sync)
│   └── github.com/ianyimi/pi-powerline-footer/  # Installed packages
├── sessions/                   # (runtime, excluded from sync)
└── auth.json                   # (runtime, excluded from sync)
```

---

## Sync Script Details

`run_after_sync-pi-agent-base.sh.tmpl`:
```bash
rsync -a --delete \
    --exclude='auth.json' \      # API keys (runtime)
    --exclude='sessions/' \      # Conversation history (runtime)
    --exclude='bin/' \           # Compiled binaries (runtime)
    --exclude='.DS_Store' \      # macOS junk
    --exclude='**/.git/' \       # Git packages (runtime)
    "$SOURCE/" "$TARGET/"
```

**Excluded files** are preserved in `~/.pi/agent/` and NOT synced from `pi-agent-base/`.

---

## Verifying Sync

```bash
# Check if files match
diff pi-agent-base/settings.json ~/.pi/agent/settings.json

# Should output nothing if synced
```

---

## Git Packages (Runtime Installed)

Packages installed via `pi install git:...` go to `~/.pi/agent/git/`.

These are **NOT** in `pi-agent-base/` because they're runtime installs.

To reinstall after fresh `chezmoi apply`:
```bash
# Settings.json has the package list
cat ~/.pi/agent/settings.json | grep packages

# Install all
pi update

# Or install specific
pi install git:https://github.com/ianyimi/pi-powerline-footer
```

---

## Summary

| Action | Edit Location | Sync Command | Test Command |
|--------|--------------|--------------|--------------|
| Pi config | `pi-agent-base/` | `chezmoi apply` | `pi` |
| Ansible playbook | `dot_bootstrap/macos.yml` | `chezmoi apply dot_bootstrap/macos.yml` | `apConfig` |
| Pi extensions | `pi-agent-base/extensions/` | `chezmoi apply` | `pi` |

**Golden rule:** Always edit in `pi-agent-base/`, then `chezmoi apply`, then test.

---

## Critical: Chezmoi Dotfiles Context

**When working in `/Users/zaye/.local/share/chezmoi/`:**

This is the SOURCE directory for chezmoi-managed dotfiles.

### File Editing Rules

✅ **ALWAYS edit files here:**
```
/Users/zaye/.local/share/chezmoi/pi-agent-base/
```

❌ **NEVER edit deployed files:**
```
~/.pi/agent/
```

### Deployment Flow

1. Edit: `/Users/zaye/.local/share/chezmoi/pi-agent-base/settings.json`
2. Run: `cma` (chezmoi apply)
3. Result: Changes deployed to `~/.pi/agent/settings.json`
4. Restart: `pi` to load new config

### Why This Matters

Chezmoi is a dotfiles manager that keeps `/Users/zaye/.local/share/chezmoi/` as the source of truth and deploys changes to system locations.

Editing deployed files breaks the sync - changes get overwritten by the next `cma`.

**Always edit source, then deploy with `cma`.**
