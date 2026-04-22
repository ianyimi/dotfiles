# vim-powerline Combined Extension

Combines vim modal editing + powerline status bar in ONE extension with NO package dependencies or conflicts.

## What This Is

- **vim/** - Full source code from [pi-vim](https://github.com/lajarre/pi-vim) (`ModalEditor` class)
- **powerline/** - Full source code from [pi-powerline-footer](https://github.com/nicobailon/pi-powerline-footer)
- **Modification**: `powerline/bash-mode/editor.ts` now extends `ModalEditor` instead of `CustomEditor`

## Features

✅ Full vim modal editing (ESC, hjkl, visual mode, etc.)  
✅ Complete powerline status bar (model, git, tokens, time, etc.)  
✅ Clean vim mode indicator at bottom  
✅ Bash mode with ghost completion  
✅ NO package conflicts - everything is local source  

## How It Works

1. `vim/index.ts` exports `ModalEditor` class
2. `powerline/bash-mode/editor.ts` imports and extends `ModalEditor` (line 2 & 25)
3. `index.ts` exports the powerline extension (which now has vim built in)

## Installation

Already installed! This extension is in `pi-agent-base/extensions/vim-powerline/` and syncs to `~/.pi/agent/extensions/vim-powerline/` via chezmoi.

## Removing Conflicting Packages

If you have `npm:pi-vim` or `npm:pi-powerline-footer` in settings.json, remove them:

```bash
# Remove from pi-agent-base/settings.json
# They're not needed - we have the source code here
pi remove npm:pi-vim
pi remove npm:pi-powerline-footer
```

## Image Preview Conflict

⚠️ `npm:pi-image-preview` ALSO uses `setEditorComponent` and will conflict.

Options:
1. Remove it from settings
2. Integrate its image rendering into this extension
3. Use it only when needed via manual `pi install`

## Updating

To update vim or powerline features:

1. Pull latest from upstream repos:
   ```bash
   cd /tmp
   git clone https://github.com/lajarre/pi-vim.git
   git clone https://github.com/nicobailon/pi-powerline-footer.git
   ```

2. Copy updated files:
   ```bash
   cd ~/.local/share/chezmoi/pi-agent-base/extensions/vim-powerline
   cp -r /tmp/pi-vim/* vim/
   cp -r /tmp/pi-powerline-footer/* powerline/
   ```

3. Re-apply the ModalEditor modification:
   ```bash
   # Edit powerline/bash-mode/editor.ts
   # Add: import { ModalEditor } from "../../vim/index.ts";
   # Change: export class BashModeEditor extends ModalEditor {
   ```

4. Sync:
   ```bash
   cma
   ```

## Testing

```bash
# Start Pi
pi

# Test vim:
# - Press ESC → should enter NORMAL mode
# - Press hjkl → should navigate
# - Press i → should enter INSERT mode

# Test powerline:
# - Should see full status bar at top
# - Should see model, git branch, token count, etc.
```
