# Debug Hierarchy

When a bug is reported or found in the dotfiles, check in this order:

## Primary Debug Order

1. **Terminal error output** — Primary source for immediate failures
   - chezmoi template errors (syntax, undefined variables, Bitwarden lookups)
   - Bitwarden CLI errors (401 auth, network, missing items)
   - Script execution failures (bootstrap.sh, run_once_* scripts, Ansible playbooks)
   - Shell syntax errors (sourcing .zshrc, alias expansion)

2. **Git diff (uncommitted changes)** — What changed recently that might have caused this
   ```bash
   git diff
   git status
   ```
   Focus on:
   - Recently modified templates (.tmpl files)
   - Shell config changes (dot_zshrc, dot_bashrc)
   - Ansible playbook modifications
   - New files not yet tracked in chezmoi

3. **IdeaLog (recent decisions)** — Context from recent work
   Read `.pi/agent-docs/implementation-log/<recent dates>.ideaLog.md`
   Look for:
   - Recent dotfile changes
   - Decisions about tool configurations
   - Known issues or workarounds noted

4. **Bitwarden session status** — Is the secret management working?
   ```bash
   bw unlock --check
   echo $BW_SESSION
   source ~/.bw-session 2>/dev/null
   ```
   Common issues:
   - Session expired (need to run `bw unlock`)
   - Tailscale disconnected (can't reach self-hosted instance)
   - Wrong session loaded (multiple profiles)

5. **Platform-specific issues** — Darwin vs Linux differences
   Check:
   - Platform detection in templates: `{{ if eq .chezmoi.os "darwin" }}`
   - darwin/ vs linux/ directory contents
   - Homebrew paths: /opt/homebrew (ARM) vs /usr/local (Intel)
   - XDG paths on Linux vs ~/Library on macOS

6. **Application-specific logs** — When the error is in a tool's config
   - tmux: `tmux info` or check session startup
   - Neovim: `:checkhealth` after applying config
   - Aerospace: check macOS logs or aerospace debug output
   - SketchyBar: `sketchybar --reload` errors

## Known Fragile Areas

_None currently tracked. This section will be updated as recurring issues are discovered._

When patterns emerge, add them here with:
- Area (tool/script/template)
- Signs of trouble (symptoms to look for)
- Common fixes or workarounds

## Debug Commands Reference

**chezmoi diagnostics:**
```bash
cm diff                    # Preview what would change
cm doctor                  # Run chezmoi's built-in diagnostics
cm data                    # Show template data (useful for debugging conditionals)
chezmoi execute-template   # Test template syntax in isolation
```

**Bitwarden session:**
```bash
bw unlock --check          # Verify session is valid
bw sync                    # Sync vault (if changes not appearing)
bw list items --search <name>  # Check if secret exists
```

**Git investigation:**
```bash
git log --oneline -10      # Recent commits
git blame <file>           # When did this line change?
git show <commit>:<file>   # View file at specific commit
```

**Platform detection:**
```bash
chezmoi data | grep os     # What platform chezmoi detected
uname -s                   # OS kernel name
uname -m                   # Architecture
```
