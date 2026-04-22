# Dev Processes

## Dev Commands

| Command | What it does |
|---------|-------------|
| `cma` | **Apply dotfiles** — Check Bitwarden session, sync vault, apply all changes, reload shell |
| `cm diff` | Preview what would change before applying |
| `cm add <file>` | Track a new file in chezmoi |
| `cme <file>` | Edit a tracked file with live preview (`chezmoi edit --watch`) |
| `./bootstrap.sh` | Full setup from scratch — installs Homebrew, Tailscale, Bitwarden, applies dotfiles |
| `lgChezmoi` | Open lazygit in chezmoi source directory |

### Common Workflow
```bash
# Make changes to source files
cme ~/.zshrc           # Edit with live preview

# Or edit directly in chezmoi source
cdChezmoi              # Navigate to ~/.local/share/chezmoi
nvim dot_zshrc         # Edit source file

# Preview changes
cm diff

# Apply changes
cma                    # Applies + syncs Bitwarden + reloads shell
```

## Error Surfaces (Debug Hierarchy)

When things break, errors can appear in multiple places depending on what's failing:

1. **Terminal output** — Primary surface for:
   - chezmoi template errors (Bitwarden lookups, .tmpl syntax)
   - File conflicts (existing files blocking apply)
   - Script execution failures (run_* scripts)

2. **Bitwarden CLI errors** — When secret fetching fails:
   - Network errors (Tailscale down, self-hosted instance unreachable)
   - Auth errors (BW_SESSION expired, not logged in)
   - Missing items (secret referenced in .tmpl but not in vault)

3. **Application-specific logs** — After apply succeeds but app fails:
   - tmux: `tmux info` or session startup errors
   - Neovim: `:checkhealth` or plugin errors
   - Aerospace: check system logs or aerospace debug output
   - SketchyBar: `sketchybar --reload` errors

4. **System logs** — For service-level failures:
   - macOS Console.app for LaunchAgent/Daemon failures
   - `brew services list` for Homebrew services

## Background Services

These must be running for `cma` (chezmoi apply) to work:

| Service | Purpose | Start command | Check status |
|---------|---------|--------------|--------------|
| **Tailscale** | Required for self-hosted Bitwarden access | `tailscale up` | `tailscale status` |
| **Bitwarden CLI session** | Fetch secrets during template rendering | `bw unlock` (interactive) or `bwsr` alias | `bw unlock --check` |

### Bitwarden Session Management

The `.zshrc` automatically loads `~/.bw-session` if it exists and validates the session on shell startup. If expired, it clears the session.

Use `bwsr` to check/refresh the session manually.

### Common Service Failures

- **Tailscale disconnected**: `cma` will fail with network errors when fetching secrets
  - Fix: `tailscale up` and authenticate
- **BW_SESSION expired**: Template rendering fails with "401 Unauthorized"
  - Fix: `bw unlock` (enter master password) or run `cma` (it includes `bw-session-check`)
