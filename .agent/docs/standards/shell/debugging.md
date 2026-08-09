---
applies_to: ["*.tmpl", "dot_*", "run_once_*", "run_after_*", "bootstrap.sh"]
---
# Debugging Dotfiles (check in this order)

1. **Terminal output** — chezmoi template errors (syntax, undefined vars, Bitwarden lookups),
   file conflicts, `run_*` script failures, shell syntax errors on `source ~/.zshrc`.
2. **Git diff** — `git diff` / `git status`: recently modified `.tmpl`, shell config,
   playbooks, untracked files.
3. **Session log** — `.agent/docs/session-log/` for recent decisions and known workarounds.
4. **Bitwarden session** — `bw unlock --check`; expired session → 401 during apply; Tailscale
   down → network errors reaching the self-hosted vault. Fix: `bwsr` / `bw unlock` /
   `tailscale up`.
5. **Platform split** — `{{ if eq .chezmoi.os "darwin" }}` conditionals, `.chezmoiignore`
   per-OS gating, Homebrew path `/opt/homebrew` (ARM), XDG vs `~/Library`.
   `chezmoi data | grep os` shows what chezmoi detected.
6. **App-specific** — `tmux info`; nvim `:checkhealth`; `sketchybar --reload`;
   `hyprctl clients -j | jq '.[].class'` for window-rule classes.

## Diagnostic commands

```bash
cm diff                    # preview what would change
cm doctor                  # chezmoi built-in diagnostics
cm data                    # template data (debug conditionals)
chezmoi execute-template   # test template syntax in isolation
bw list items --search X   # does the secret exist?
```
