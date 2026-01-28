# Clawdbot Files - What to Manage vs Ignore

## Why Ignore Session Files and Logs?

Your clawdbot directory contains both **configuration** (should sync) and **runtime data** (should not sync).

---

## Files MANAGED by Chezmoi (Sync Across Machines)

### ✅ Configuration Files

These are your settings that should be the same on all machines:

1. **`private_clawdbot.json.tmpl`** - Main configuration
   - Gateway settings (port, auth mode)
   - Channel configs (imessage, allowlist)
   - Model providers
   - Hooks and skills settings
   - **Uses Bitwarden template for API token**

2. **`agents/main/private_agent/models.json`** - Model configurations
   - Local LM Studio configs
   - Model names and endpoints

3. **`cron/jobs.json`** - Scheduled jobs
   - Cron job definitions
   - Automation schedules

---

## Files IGNORED (Not Synced)

### ❌ Runtime Data - `agents/main/sessions/`

**What's in there:**
```json
{
  "sessionId": "746acc79-ad1e-4f2b-a514-2b9112fc9640",
  "deliveryContext": {
    "to": "+19162123890"  // ← Your phone number
  },
  "lastHeartbeatSentAt": 1769503678875,
  "compactionCount": 0
}
```

**Why ignore:**
- ✗ **Personal information** - Contains your phone number
- ✗ **Ephemeral** - Changes with every conversation
- ✗ **Machine-specific** - Session IDs are per-instance
- ✗ **Not portable** - Sessions don't transfer between machines
- ✗ **Runtime state** - Active conversations, heartbeat times

### ❌ Log Files - `logs/`

**What's in there:**
```
[canvas] host mounted at http://127.0.0.1:18789/__clawdbot__/canvas/
[bridge] listening on tcp://0.0.0.0:18790 (node)
[heartbeat] started
[imessage] delivered reply to imessage:+19162123890
[gateway] agent model: anthropic/claude-opus-4-5
```

**Why ignore:**
- ✗ **Runtime output** - Generated during operation
- ✗ **Ever-growing** - Gets larger over time (already 140KB)
- ✗ **Personal info** - May contain message content and phone numbers
- ✗ **Debugging only** - Not configuration
- ✗ **Machine-specific** - Local gateway activity

### ❌ Backup Files - `*.bak`, `*.bak.*`

**What they are:**
- Old versions of config files
- Created automatically by clawdbot or editors
- Duplicates of existing configs

**Why ignore:**
- ✗ **Redundant** - Main config is already tracked
- ✗ **Clutter** - Creates noise in git history
- ✗ **Temporary** - Not intentional versions

---

## What Gets Synced on New Machine

When you run `chezmoi apply` on a fresh machine:

### ✅ Synced (From Git)
```
~/.clawdbot/
├── clawdbot.json           # ← Populated from template with Bitwarden token
├── agents/main/
│   └── agent/
│       └── models.json     # ← Your model configs
└── cron/
    └── jobs.json           # ← Your scheduled jobs
```

### ❌ Not Synced (Machine Creates New)
```
~/.clawdbot/
├── agents/main/
│   └── sessions/
│       └── sessions.json   # ← New sessions created when you use it
└── logs/
    ├── gateway.log         # ← New logs from this machine's usage
    └── gateway.err.log
```

---

## Added to .chezmoiignore

```
# Clawdbot runtime data and logs (not config)
private_dot_clawdbot/agents/main/sessions/
private_dot_clawdbot/logs/

# Backup files (all directories)
*.bak
*.bak.*
```

This ensures:
- Session files never get committed (keeps phone numbers private)
- Logs never bloat the repo
- Backup files don't clutter git history

---

## Benefits

### Privacy ✓
- Your phone number not in public git repo
- Conversation history not in git
- Personal runtime data stays local

### Performance ✓
- Git repo stays small (no 140KB+ log files)
- No merge conflicts on runtime files
- Clean, focused history

### Portability ✓
- Config syncs perfectly across machines
- Each machine gets fresh runtime state
- No "stale session" issues

### Maintainability ✓
- Clear separation: config vs runtime
- Easy to see what settings changed
- No noise from log/session updates

---

## Comparison: Before vs After

### Before (Managing Everything)
```bash
git status
# Modified: agents/main/sessions/sessions.json (every conversation)
# Modified: logs/gateway.log (every run)
# New file: clawdbot.json.bak.5 (every save)
# New file: clawdbot.json.bak.6
# ...
```

### After (Only Config)
```bash
git status
# Modified: clawdbot.json.tmpl (when you change settings)
# Clean!
```

---

## Testing Your Setup

After ignoring these files:

```bash
# Session files should NOT appear in git status
cd ~/.local/share/chezmoi
git status | grep sessions
# (should be empty)

# Logs should NOT appear in git status
git status | grep logs
# (should be empty)

# Only config should be tracked
git ls-files | grep clawdbot
# Should show:
# private_dot_clawdbot/private_clawdbot.json.tmpl
# private_dot_clawdbot/agents/main/private_agent/models.json
# private_dot_clawdbot/cron/jobs.json
```

---

## Summary

**KEEP (Manage with Chezmoi):**
- ✅ Main config template with Bitwarden integration
- ✅ Model configurations
- ✅ Cron job definitions

**IGNORE (Machine-specific):**
- ❌ Session files (personal info)
- ❌ Log files (runtime output)
- ❌ Backup files (duplicates)

This keeps your dotfiles repo **clean, private, and portable!**
