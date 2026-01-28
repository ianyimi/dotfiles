# How Bitwarden Authentication Works

## Overview

Your dotfiles use Bitwarden CLI for secure secret management. This document explains the authentication flow and how chezmoi accesses your secrets.

---

## Authentication Layers

### 1. Bitwarden Server Connection
**What:** Connect to your Vaultwarden server
**Where:** `unraid.tail68d30.ts.net/vault`
**How:** 
```bash
bw config server https://unraid.tail68d30.ts.net/vault
```

**Required:** Tailscale connection (your server is on your tailnet)

---

### 2. Bitwarden Login
**What:** Authenticate your identity with the server
**How:**
```bash
bw login zaye.dev@proton.me
# Prompts for master password
```

**Persists:** Login status is saved locally (you stay logged in)
**Check:** `bw login --check`

---

### 3. Vault Unlock (Session)
**What:** Decrypt your vault for access to secrets
**How:**
```bash
bw unlock
# Prompts for master password
# Returns: Session key (long encrypted string)
```

**Session key example:**
```
mQjjzyTrV50uhoUzjYM6YRKYU7xuqWVgV2KdsX0IJbzMYpHWbbMYM3ZuBPLODZIel3GsBlRwVhSlAfSaSocyyw==
```

**Important:** Session keys expire after a period of inactivity (typically 1 hour)

---

## How Chezmoi Accesses Secrets

### The Flow

```
1. Your shell (.zshrc) loads ~/.bw-session
   ↓
2. Exports BW_SESSION environment variable
   ↓
3. Chezmoi runs as subprocess, inherits BW_SESSION
   ↓
4. Template encounters: {{ (bitwarden "item" "Name").login.password }}
   ↓
5. Chezmoi calls: bw get item "Name" --session $BW_SESSION
   ↓
6. Bitwarden CLI returns decrypted secret
   ↓
7. Chezmoi renders template with secret value
```

### Key Points

**BW_SESSION must be exported:**
```bash
# In your .zshrc
if [ -f ~/.bw-session ]; then
    source ~/.bw-session
    export BW_SESSION  # ← CRITICAL: Must export for subprocesses
fi
```

**Without export:** Chezmoi can't access secrets (runs in subprocess)
**With export:** Chezmoi inherits the session key and can decrypt

---

## Session Management

### Session File Format
```bash
# ~/.bw-session
export BW_SESSION="<long-encrypted-string>"
```

### Session Lifecycle

1. **Initial unlock:**
   ```bash
   bw unlock --raw
   # Returns session key, save to ~/.bw-session
   ```

2. **Auto-load on shell start:**
   ```bash
   # .zshrc automatically sources ~/.bw-session
   source ~/.bw-session
   export BW_SESSION
   ```

3. **Validation:**
   ```bash
   bw unlock --check --session "$BW_SESSION"
   # Returns: "Vault is unlocked!" or "Vault is locked"
   ```

4. **Expiration:**
   - Session expires after inactivity
   - File remains but key no longer valid
   - Must run `bwsr` to refresh

### Refresh Session
```bash
# Your bwsr alias runs bw-session-check
bwsr

# Which does:
BW_SESSION=$(bw unlock --raw)
echo "export BW_SESSION=\"$BW_SESSION\"" > ~/.bw-session
export BW_SESSION
```

---

## Security Model

### What's Protected

1. **Master password** - Only you know this, never stored anywhere
2. **Vault data** - Encrypted at rest and in transit
3. **Session key** - Encrypted, but grants temporary access

### What's NOT Protected

- **Session file (~/.bw-session)** - Anyone with file access can use the session
  - Permissions: `chmod 600` (only you can read)
  - Location: Home directory (protected by macOS user permissions)
  - Expiration: Sessions expire automatically

### Security Trade-offs

**Why sessions instead of always prompting:**
- **Pro:** Don't enter master password for every chezmoi apply
- **Pro:** Automated workflows can access secrets
- **Con:** If someone gains access to your Mac while session is active, they can decrypt

**Mitigation:**
- Sessions expire automatically
- File permissions restrict access
- Tailscale adds network layer security (server not publicly accessible)
- macOS user account security

---

## Bootstrap Flow (Fresh Machine)

```
┌─────────────────────────────────────┐
│ Run bootstrap.sh                    │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ Install Homebrew, Tailscale, Git    │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ Connect to Tailscale network        │
│ Prompt: System password + browser   │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ Install Bitwarden CLI               │
│ Configure server URL                │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ bw login zaye.dev@proton.me         │
│ Prompt: Master password             │
│ Result: Logged in ✓                 │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ bw unlock --raw                     │
│ (Uses saved login credentials)      │
│ Result: Session key                 │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ Save to ~/.bw-session               │
│ export BW_SESSION="<key>"           │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ chezmoi init --apply                │
│ (Inherits BW_SESSION from env)     │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ Process .tmpl files                 │
│ Call: bw get item "X" --session $X │
│ Decrypt secrets                     │
└──────────────┬──────────────────────┘
               │
               v
┌─────────────────────────────────────┐
│ Write config files with secrets     │
│ Result: All configs populated ✓     │
└─────────────────────────────────────┘
```

### Time to First Secret

**Total:** ~2-3 minutes
- Homebrew install: 30s
- Tailscale install + auth: 60s
- Bitwarden install: 10s
- Login + unlock: 20s
- Chezmoi apply: 30s

**User interaction required:**
1. System password (sudo) - 1 time
2. Tailscale browser auth - 1 time
3. Bitwarden master password - 1 time

**Then automatic forever!**

---

## Common Issues & Solutions

### Issue: "vault is locked"
**Cause:** Session expired
**Fix:**
```bash
bwsr  # Refresh session
```

### Issue: "Not found" when accessing item
**Cause:** Item name doesn't match exactly (case-sensitive)
**Fix:**
```bash
# List all items to find exact name
bw list items | jq -r '.[].name' | sort

# Test retrieval
bw get item "Exact Name Here"
```

### Issue: Chezmoi prompts for password every time
**Cause:** BW_SESSION not exported in .zshrc
**Fix:**
```bash
# Ensure .zshrc has:
if [ -f ~/.bw-session ]; then
    source ~/.bw-session
    if [ -n "$BW_SESSION" ]; then
        export BW_SESSION  # ← Must have this line
    fi
fi
```

### Issue: "unexpected end of JSON input"
**Cause:** Calling `bw` without valid session in subprocess
**Fix:**
```bash
# Verify session is exported
env | grep BW_SESSION

# If not exported, add export to .zshrc (see above)
```

---

## Advanced: Session Timeout Configuration

### Server-Side (Vaultwarden)

Can increase session timeout on your Vaultwarden server:

1. Edit docker-compose or container config
2. Add environment variable:
   ```yaml
   environment:
     - SESSION_TIMEOUT=1440  # 24 hours (in minutes)
   ```
3. Restart container

### Client-Side (No timeout control)

The Bitwarden CLI respects server settings. No client-side timeout configuration available.

---

## Comparison: Bitwarden vs Environment Variables

### Bitwarden Approach (This Setup)
**Pros:**
- ✓ Centralized secret storage
- ✓ Never committed to git
- ✓ Easy rotation (update in vault, run cma)
- ✓ Access from multiple machines
- ✓ Backup and sync via server

**Cons:**
- ✗ Requires Bitwarden server access
- ✗ Session management complexity
- ✗ Initial setup more involved

### Environment Variables Approach
**Pros:**
- ✓ Simple, no dependencies
- ✓ No server required

**Cons:**
- ✗ Secrets in plaintext files
- ✗ Hard to rotate (must update all machines)
- ✗ Risk of accidental commit to git
- ✗ No centralized management

---

## Summary

**Your setup is secure and automated:**

1. ✓ Secrets never in git (templates only)
2. ✓ One-time authentication on new machine
3. ✓ Sessions cached for convenience
4. ✓ Network security via Tailscale
5. ✓ File permissions protect session file
6. ✓ Master password is the only key you need to remember

**The magic:**
- `BW_SESSION` environment variable bridges the gap
- Chezmoi templates call `bw` CLI with session
- Secrets decrypted on-the-fly during template rendering
- Result files contain plaintext secrets (but never committed)

**When it works well:**
- Session stays valid for hours
- `cma` is instant (no password prompts)
- New machines setup in minutes
- Key rotation is trivial (update vault, apply)

**When you need to act:**
- Session expired → run `bwsr`
- New machine → enter password once during bootstrap
- Rotate keys → update in Bitwarden web UI
