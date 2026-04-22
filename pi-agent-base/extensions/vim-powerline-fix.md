# Fix: Pi-Vim + Pi-Powerline-Footer Conflict

## Problem

Both `pi-vim` and `pi-powerline-footer` call `ctx.ui.setEditorComponent()` to register their custom editors:
- **pi-vim**: Registers `ModalEditor` (vim keybindings)
- **pi-powerline-footer**: Registers `BashModeEditor` (bash mode + ghost suggestions)

Only ONE editor can be active at a time. Whichever extension loads last wins.

## Solution

Use `pi config` to disable the conflicting resource while keeping others:

### Steps:

1. Run `pi config`
2. Navigate to `npm:pi-powerline-footer (user)`
3. Find the Extensions section
4. **Disable the editor component** but **keep widgets/footer enabled**

Unfortunately, pi-powerline-footer bundles everything in `index.ts`, so we can't selectively disable just the editor without disabling the whole extension.

## Better Solution: Package Load Order

Change the package load order in `~/.pi/agent/settings.json` so `pi-vim` loads LAST:

```json
{
  "packages": [
    "npm:pi-powerline-footer",
    "npm:pi-btw",
    "npm:pi-docparser",
    "npm:pi-image-preview",
    "npm:lsp-pi",
    "npm:pi-vim"  <-- Load vim LAST so its ModalEditor wins
  ]
}
```

This way:
1. Powerline sets up footer/header/widgets
2. Powerline tries to register BashModeEditor
3. **Vim loads last and replaces the editor with ModalEditor**
4. Powerline's UI elements remain active

### What You Keep:
✓ Vim modal editing (hjkl, dd, yy, etc.)
✓ Powerline status bar at top
✓ Vim mode indicator (INSERT/NORMAL) at bottom right

### What You Lose:
✗ Powerline's BashModeEditor features (bash mode, ghost suggestions, custom prompt)
✗ Bash mode transcript widget

## Long-term Fix

Submit a PR to `pi-powerline-footer` to:
1. Export `BashModeEditor` as a separate class
2. Make it extend `ModalEditor` from `pi-vim` when available
3. Fall back to `CustomEditor` when `pi-vim` is not installed

This would allow both to work together natively.
