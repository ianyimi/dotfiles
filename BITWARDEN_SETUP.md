# Bitwarden Integration with Chezmoi

> **Note:** Bitwarden requires Tailscale connection to access your Vaultwarden server.
> See [INSTALLATION_REVIEW.md](./INSTALLATION_REVIEW.md) for the complete bootstrap sequence.

## Current Issues to Revisit

### Fixed: Duplicate "Synced agent-os-base" Message

**Issue:**
- When running `cma`, the message "✓ Synced agent-os-base → ~/agent-os" appeared twice
- This happened because the sync script was being executed twice:
  1. Once automatically during `chezmoi apply` (as a `run_after_*.sh.tmpl` script)
  2. Once manually via explicit `chezmoi execute-template ... | bash` in the alias

**Root Cause:**
The `cma` alias contained redundant manual execution of the sync script that was left over from debugging earlier issues.

**Fix:**
Simplified the `cma` alias from:
```bash
alias cma="bw-session-check && chezmoi apply; chezmoi execute-template < ~/.local/share/chezmoi/run_after_sync-agent-os-base.sh.tmpl | bash 2>/dev/null; source ~/.zshrc"
```

To:
```bash
alias cma="bw-session-check && chezmoi apply && source ~/.zshrc"
```

The manual execution was removed since `chezmoi apply` automatically runs all `run_after_*.sh.tmpl` scripts.

---

### Session Management Problem
**Status:** Temporarily working, needs long-term solution

**Issue:**
- `bw` CLI sessions expire too quickly (appears to be ~1 hour)
- Manual `~/.bw-session` management is unreliable
- Session works in interactive terminal but subprocesses (like chezmoi) can't always access it
- Getting password prompts when running `cma` if session expires

**Temporary Workaround:**
- `bw` CLI maintains its own auth when used interactively
- Works without explicit session management for now
- Unclear why it works in terminal but not always in chezmoi subprocesses

**Potential Long-term Solutions to Investigate:**
1. **Increase Vaultwarden server session timeout**
   - Location: Vaultwarden container on Unraid
   - Environment variable: `SESSION_TIMEOUT=43200` (12 hours) or `1440` (24 hours)
   - Requires container restart

2. **Use Bitwarden API Keys** (if available)
   - Check if your Vaultwarden version supports personal API keys
   - Location: Web vault → Settings → Security → Keys → API Key
   - Would use `bw login --apikey` instead of password

3. **Background session refresh daemon**
   - Create a background process that refreshes session before expiry
   - Less ideal than fixing server timeout

4. **Environment variable export issue**
   - Investigate if `BW_SESSION` needs to be exported differently
   - Current `.zshrc` sources `~/.bw-session` but may not export to all subprocesses

**Testing Needed:**
```bash
# Check current session status
bw status

# Verify BW_SESSION is exported
echo "BW_SESSION: ${BW_SESSION:0:20}..."
env | grep BW_SESSION

# Test chezmoi can access it
chezmoi execute-template '{{ (bitwarden "item" "Clawdbot API Token").login.password }}'
```

---

## Setup Plan: Adding Secrets to Bitwarden

### Phase 1: Shell Environment Variables

**Files to convert to templates:**
- `~/.zshrc` → Already exists, needs secrets added

**Bitwarden items to create:**

1. **OpenAI API Key**
   - Item name: `OpenAI API Key`
   - Type: Login
   - Username: (empty)
   - Password: `sk-...` (your OpenAI key)

2. **Anthropic API Key**
   - Item name: `Anthropic API Key`
   - Type: Login
   - Username: (empty)
   - Password: `sk-ant-...` (your Claude key)

**Changes needed in `dot_zshrc`:**
Add at the end of the file:
```bash
# API Keys from Bitwarden
export OPENAI_API_KEY="{{ (bitwarden "item" "OpenAI API Key").login.password }}"
export ANTHROPIC_API_KEY="{{ (bitwarden "item" "Anthropic API Key").login.password }}"
```

**Steps:**
1. Create the Bitwarden items (via web UI or CLI)
2. Rename `~/.local/share/chezmoi/dot_zshrc` to `~/.local/share/chezmoi/dot_zshrc.tmpl`
3. Add the export lines above
4. Run `cma` to apply

---

### Phase 2: Project .env Files

**General pattern for any project .env file:**

#### Example: Project at `~/Desktop/Projects/MyProject`

**Step 1: Add the .env file to chezmoi as a template**
```bash
# From the project directory
cd ~/Desktop/Projects/MyProject
chezmoi add --template .env
```

This creates: `~/.local/share/chezmoi/Desktop/Projects/MyProject/dot_env.tmpl`

**Step 2: Edit the template to use Bitwarden lookups**

Original `.env`:
```bash
DATABASE_URL=postgresql://user:password123@localhost:5432/mydb
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
STRIPE_SECRET_KEY=sk_test_abcdefghijklmnop
```

Converted template:
```bash
DATABASE_URL={{ (bitwarden "item" "MyProject Database").login.password }}
AWS_ACCESS_KEY_ID={{ (bitwarden "item" "AWS Credentials").login.username }}
AWS_SECRET_ACCESS_KEY={{ (bitwarden "item" "AWS Credentials").login.password }}
STRIPE_SECRET_KEY={{ (bitwarden "item" "Stripe API Keys").login.password }}
```

**Step 3: Create corresponding Bitwarden items**

1. **MyProject Database**
   - Type: Login
   - Username: (empty)
   - Password: `postgresql://user:password123@localhost:5432/mydb`

2. **AWS Credentials**
   - Type: Login
   - Username: `AKIAIOSFODNN7EXAMPLE`
   - Password: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

3. **Stripe API Keys**
   - Type: Login
   - Username: (empty)
   - Password: `sk_test_abcdefghijklmnop`

**Step 4: Apply and verify**
```bash
cma
cat ~/Desktop/Projects/MyProject/.env  # Verify secrets are populated
```

---

### Phase 3: Specific Projects to Add

**Projects identified from .zshrc aliases:**

1. **Cognitive Core** (`~/Desktop/Projects/Zoic/cognitive-core`)
   - Likely needs: Database URLs, API keys, service credentials

2. **Edapt** (`~/Desktop/Edapt/webapp-v2`)
   - Likely needs: Database URLs, API keys, third-party service credentials

3. **Portfolio** (`~/Desktop/Portfolio24`)
   - Likely needs: CMS API keys, deployment credentials

**Steps for each project:**
1. Navigate to project directory
2. Check if `.env` or `.env.local` exists
3. If yes:
   ```bash
   chezmoi add --template .env
   # Or for .env.local:
   chezmoi add --template .env.local
   ```
4. Edit the template file to replace hardcoded secrets with Bitwarden lookups
5. Create corresponding items in Bitwarden vault
6. Test with `cma`

---

### Common Bitwarden Item Patterns

#### Pattern 1: Simple API Key
```bash
# .env
API_KEY={{ (bitwarden "item" "Service Name API Key").login.password }}
```

#### Pattern 2: Username + Password
```bash
# .env
DB_USER={{ (bitwarden "item" "Database Credentials").login.username }}
DB_PASS={{ (bitwarden "item" "Database Credentials").login.password }}
```

#### Pattern 3: Multiple values in one item (using custom fields)
```bash
# .env
GITHUB_CLIENT_ID={{ (bitwardenFields "item" "OAuth Credentials").github_client_id.value }}
GITHUB_CLIENT_SECRET={{ (bitwardenFields "item" "OAuth Credentials").github_client_secret.value }}
GOOGLE_CLIENT_ID={{ (bitwardenFields "item" "OAuth Credentials").google_client_id.value }}
```

**To use custom fields, create the Bitwarden item with custom fields:**
```bash
bw get template item | jq '.fields = [
  {"name": "github_client_id", "value": "xxx", "type": 0},
  {"name": "github_client_secret", "value": "yyy", "type": 1},
  {"name": "google_client_id", "value": "zzz", "type": 0}
]' | bw create item
```

---

### Checklist

**Current Status:**
- [x] Bitwarden CLI installed and configured
- [x] Bitwarden server configured (unraid.tail68d30.ts.net/vault)
- [x] Test successful: Clawdbot API Token
- [ ] Session management issue resolved

**Shell Environment:**
- [ ] Create OpenAI API Key in Bitwarden
- [ ] Create Anthropic API Key in Bitwarden
- [ ] Convert `dot_zshrc` to `dot_zshrc.tmpl`
- [ ] Add API key exports to template
- [ ] Test with `cma`

**Project .env Files:**
- [ ] Cognitive Core project
  - [ ] Add .env as template
  - [ ] Create Bitwarden items
  - [ ] Test
- [ ] Edapt project
  - [ ] Add .env as template
  - [ ] Create Bitwarden items
  - [ ] Test
- [ ] Portfolio project
  - [ ] Add .env as template
  - [ ] Create Bitwarden items
  - [ ] Test
- [ ] (Add other projects as needed)

**Verification:**
- [ ] All `cma` runs complete without password prompts
- [ ] All secrets properly populated in target files
- [ ] No plaintext secrets in chezmoi source files
- [ ] Git history cleaned of any accidentally committed secrets

---

## Important Notes

### Security Best Practices

1. **Never commit plaintext secrets to git**
   - Always use `.tmpl` files with Bitwarden lookups
   - Check git history: `git log --all --full-history -- path/to/file`

2. **Use .chezmoiignore for sensitive files you don't want managed**
   ```
   # Don't manage session files
   .bw-session

   # Don't manage local-only configs
   .env.local
   ```

3. **Verify templates before applying**
   ```bash
   chezmoi execute-template < ~/.local/share/chezmoi/path/to/file.tmpl
   ```

4. **Keep backup of Bitwarden vault**
   - Export vault periodically
   - Store export in secure location (not in git)

### Troubleshooting

**Issue: "Not found" error**
- Check exact item name: `bw list items | jq -r '.[] | .name' | sort`
- Names are case-sensitive and must match exactly
- Sync vault: `bw sync`

**Issue: "Unexpected end of JSON input"**
- Session expired, run: `bwsr`
- Check vault status: `bw status`

**Issue: Template syntax errors**
- Validate with: `chezmoi execute-template < file.tmpl`
- Check for unescaped quotes in JSON files
- Remember: Template syntax is processed BEFORE the file content

**Issue: Password prompt every time**
- Check for files with Bitwarden lookups: `grep -r "bitwarden" ~/.local/share/chezmoi --include="*.tmpl"`
- Remove unused template files
- Add unwanted templates to `.chezmoiignore`

---

## Quick Reference

### Common Commands

```bash
# Refresh Bitwarden session
bwsr

# Sync vault with server
bw sync

# List all items
bw list items | jq -r '.[] | .name'

# Get specific item
bw get item "Item Name"

# Search for items
bw list items | jq -r '.[] | select(.name | contains("search term")) | .name'

# Test template rendering
chezmoi execute-template '{{ (bitwarden "item" "Item Name").login.password }}'

# Add file as template
chezmoi add --template path/to/file

# Apply changes
cma

# View what would change without applying
chezmoi diff
```

### File Naming Convention

- Regular file: `file.txt` → `dot_file.txt` (if in home) or `file.txt` (if in subdirs)
- Template file: `file.txt` → `dot_file.txt.tmpl` or `file.txt.tmpl`
- Private file (chmod 600): `private_` prefix → `private_dot_file.txt.tmpl`
- Executable: `executable_` prefix → `executable_script.sh.tmpl`
