# Secrets Audit - Files to Convert Before Making Repo Public

## Summary

Before making your dotfiles repo public, you need to:
1. Convert files with secrets to templates that pull from Bitwarden
2. Add files with personal information to `.chezmoiignore`
3. Rotate all exposed API keys

---

## Files That Need Template Conversion

### 1. `dot_config/opencode/opencode.json`
**Location:** `~/.config/opencode/opencode.json`

**Secrets found:**
- Line 30: Context7 API key: `ctx7sk-2e20a38c-b4f2-4c47-a283-17592cbbb0d9`
- Line 41: REF API key: `ref-db9443a57d1de0697a0b`

**Action required:**
1. Rename to `dot_config/opencode/opencode.json.tmpl`
2. Create Bitwarden items:
   - Item name: `Context7 API Key`
   - Item name: `REF API Key`
3. Replace secrets with templates:
```json
{
  "mcp": {
    "context7": {
      "command": [
        "npx",
        "-y",
        "@upstash/context7-mcp",
        "--api-key",
        "{{ (bitwarden "item" "Context7 API Key").login.password }}"
      ]
    },
    "ref": {
      "environment": {
        "REF_API_KEY": "{{ (bitwarden "item" "REF API Key").login.password }}"
      }
    }
  }
}
```

---

### 2. `private_dot_clawdbot/private_clawdbot.json.tmpl`
**Status:** ✓ Already templated (API token on line 109)

**Note:** This file is already correctly using Bitwarden:
```json
"token": "{{ (bitwarden "item" "Clawdbot API Token").login.password }}"
```

---

## Files to Exclude or Clean

### 3. `private_dot_clawdbot/agents/main/sessions/private_sessions.json`
**Personal information:**
- Phone number: `+19162123890` (appears on lines 177, 181)

**Action required:**
Add to `.chezmoiignore`:
```
# Clawdbot session files contain personal information
private_dot_clawdbot/agents/main/sessions/
private_dot_clawdbot/logs/
```

---

### 4. `private_dot_clawdbot/*.json.bak*`
**Backup files:** Multiple backup files with hardcoded phone numbers

**Action required:**
These backup files should not be committed. Add to `.chezmoiignore`:
```
# Backup files
*.bak
*.bak.*
```

---

### 5. `.chezmoi.toml.tmpl`
**Status:** ✓ Already safe

Contains only template prompts for:
- Bitwarden email (prompted on first run)
- Bitwarden server URL (prompted on first run)
- GitHub username (prompted on first run)

No hardcoded secrets.

---

## Files That Are Safe (No Secrets)

✓ `dot_bootstrap/macos.yml` - Only references Bitwarden for auth, no hardcoded secrets
✓ `private_dot_clawdbot/agents/main/private_agent/models.json` - Only local server configs
✓ `dot_config/gh-dash/config.yml` - Only GitHub repo paths and preferences
✓ `.claude/settings.local.json` - Only permissions config

---

## Required Actions Checklist

### Before Committing:

- [ ] **Rotate exposed API keys** (these are now public in git history)
  - [ ] Context7 API key: `ctx7sk-2e20a38c-b4f2-4c47-a283-17592cbbb0d9`
  - [ ] REF API key: `ref-db9443a57d1de0697a0b`
  - [ ] Clawdbot API token: `a3eb59aed85c36496e812379fb9aef72ad56c1f176809232`

- [ ] **Create Bitwarden items:**
  ```bash
  # Context7 API Key
  bw create item '{
    "type": 1,
    "name": "Context7 API Key",
    "login": {
      "password": "<new-key-here>"
    }
  }'
  
  # REF API Key
  bw create item '{
    "type": 1,
    "name": "REF API Key",
    "login": {
      "password": "<new-key-here>"
    }
  }'
  
  # Clawdbot API Token (if not already created)
  bw create item '{
    "type": 1,
    "name": "Clawdbot API Token",
    "login": {
      "password": "<new-token-here>"
    }
  }'
  ```

- [ ] **Convert files to templates:**
  ```bash
  cd ~/.local/share/chezmoi
  
  # Rename OpenCode config to template
  mv dot_config/opencode/opencode.json dot_config/opencode/opencode.json.tmpl
  
  # Edit and add Bitwarden templates
  chezmoi edit dot_config/opencode/opencode.json.tmpl
  ```

- [ ] **Update .chezmoiignore:**
  ```bash
  cat >> ~/.local/share/chezmoi/.chezmoiignore << 'EOF'
  
  # Clawdbot session files and logs (contain personal info)
  private_dot_clawdbot/agents/main/sessions/
  private_dot_clawdbot/logs/
  
  # Backup files
  *.bak
  *.bak.*
  EOF
  ```

- [ ] **Clean git history** (if keys were already committed):
  ```bash
  # This removes files from history but is destructive
  # Only do this if you haven't pushed yet, or create a new repo
  git filter-branch --force --index-filter \
    'git rm --cached --ignore-unmatch dot_config/opencode/opencode.json' \
    --prune-empty --tag-name-filter cat -- --all
  ```

- [ ] **Test that secrets work:**
  ```bash
  # Unlock Bitwarden
  bwsr
  
  # Test template rendering
  chezmoi execute-template < ~/.local/share/chezmoi/dot_config/opencode/opencode.json.tmpl
  
  # Apply and verify
  cma
  cat ~/.config/opencode/opencode.json | jq '.mcp.context7.command'
  ```

---

## Security Best Practices

1. **Never commit plaintext secrets** - Always use Bitwarden templates
2. **Rotate keys immediately** if they were exposed in git history
3. **Use `.chezmoiignore`** for files with personal information
4. **Test templates before committing** - Ensure they render correctly
5. **Review git history** before pushing - Use `git log -p` to check for secrets

---

## Verification Commands

After converting files, verify no secrets remain:

```bash
cd ~/.local/share/chezmoi

# Check for API key patterns
grep -r "sk-\|key-\|token-\|api.*=" . --include="*.json" --include="*.yml" --include="*.toml" | grep -v "bitwarden\|\.git"

# Check for phone numbers
grep -r "\+[0-9]\{10,\}" . | grep -v "\.git"

# Check for email addresses (excluding bitwarden config)
grep -r "@.*\." . --include="*.json" --include="*.yml" | grep -v "bitwarden\|bwEmail\|\.git"

# List all non-template JSON files that might have secrets
find . -name "*.json" ! -name "*.json.tmpl" ! -path "./.git/*" ! -path "./agent-os-base/*"
```

---

## What Happens on Fresh Install

After these changes, a fresh install will:

1. Run `bootstrap.sh` → installs chezmoi, Homebrew, Tailscale, Bitwarden
2. Prompt for Bitwarden master password → unlocks vault
3. Chezmoi processes `.tmpl` files → fetches secrets from Bitwarden
4. All config files populated with correct secrets automatically
5. No manual secret entry required!

**User only enters:**
- System password (for sudo)
- Tailscale authentication (browser)
- Bitwarden master password

**Everything else automatic!**
