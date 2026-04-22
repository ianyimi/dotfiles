# Pi Extension Conflicts - Complete Guide

## Your Questions Answered

### Q: Do I need to fork one of the packages to make changes?

**A: Only if you want to fix it upstream.** You have three options:

**Option 1: Use load order** (current solution, no fork needed)
- ✅ Works now, no code changes
- ✅ Persisted in dotfiles (pi-agent-base)
- ❌ Only controls which editor wins, doesn't merge them
- ❌ Fragile if you add more editor-extending packages

**Option 2: Fork and PR** (best long-term)
- Fork `pi-powerline-footer`
- Make `BashModeEditor` extend `ModalEditor` when `pi-vim` is detected
- Submit PR to help the community
- ✅ Fixes it for everyone
- ✅ Both editors work together natively
- ⏱️ Requires maintaining a fork until PR is merged

**Option 3: Create bridge package** (most flexible)
- Create `pi-vim-powerline-bridge` npm package
- Publish it
- Have it compose both editors intelligently
- ✅ Handles multiple editor conflicts
- ✅ Can add more editors later (pi-emacs, pi-custom-editor, etc.)
- ⏱️ Requires npm package creation and maintenance

### Q: Should I make a PR so it doesn't conflict?

**A: Yes, that would be valuable!** Here's how:

1. **Fork `pi-powerline-footer`**: https://github.com/nicobailon/pi-powerline-footer

2. **Modify `bash-mode/editor.ts`**:
```typescript
import { CustomEditor } from "@mariozechner/pi-coding-agent";

// Try to import ModalEditor from pi-vim
let BaseEditorClass: typeof CustomEditor = CustomEditor;
try {
  const piVim = await import("pi-vim");
  if (piVim?.ModalEditor) {
    BaseEditorClass = piVim.ModalEditor;
    console.log("[pi-powerline-footer] Using ModalEditor from pi-vim as base");
  }
} catch {
  // pi-vim not installed, fall back to CustomEditor
}

export class BashModeEditor extends BaseEditorClass {
  // Now inherits vim keybindings if pi-vim is installed!
}
```

3. **Update `package.json`**:
```json
{
  "peerDependencies": {
    "pi-vim": "*"
  },
  "peerDependenciesMeta": {
    "pi-vim": {
      "optional": true
    }
  }
}
```

4. **Test both scenarios**:
   - With pi-vim installed → vim + powerline work together
   - Without pi-vim → powerline works standalone

5. **Submit PR** with description:
   > "Make BashModeEditor compatible with pi-vim by extending ModalEditor when available. This allows both packages to work together without conflicts."

### Q: Why wouldn't our new extension install last?

**A: Great catch! Local extensions DON'T control load order.**

Extensions load in this order:

1. **npm packages** (from `settings.json` `packages` array) → **loaded in array order**
2. **Local extensions** (from `~/.pi/agent/extensions/*.ts`) → **loaded after packages, arbitrary order**

**Current state**:
- ✅ `settings.json` has correct order: `[..., "npm:pi-vim"]` (vim last)
- ❌ Local extension `vim-powerline-bridge.ts` **can't** enforce this order

**To make a custom extension work**, you'd need to:
1. Create an npm package
2. Add it to `packages` array AFTER `pi-vim`
3. Publish to npm or use `pi install git:...`

### Q: How is it working now?

**Current solution breakdown:**

```mermaid
Pi Startup
  ↓
Load packages in order from settings.json
  ↓
1. npm:pi-powerline-footer loads
   → calls ctx.ui.setEditorComponent(BashModeEditor)
   → calls ctx.ui.setFooter(...)
   → calls ctx.ui.setHeader(...)
   → calls ctx.ui.setWidget(...)
  ↓
2. npm:pi-btw loads
3. npm:pi-docparser loads
4. npm:pi-image-preview loads
5. npm:lsp-pi loads
  ↓
6. npm:pi-vim loads (LAST)
   → calls ctx.ui.setEditorComponent(ModalEditor)
   → **REPLACES** BashModeEditor with ModalEditor
  ↓
Result:
  - Editor: ModalEditor (vim keybindings)
  - Footer: Powerline footer (still registered)
  - Header: Powerline header (still registered)
  - Widgets: Powerline widgets (still registered)
```

**Key insight**: `setEditorComponent()` **replaces** the editor, but `setFooter()`, `setHeader()`, and `setWidget()` are separate APIs that persist.

### Q: Are these changes in pi-agent-base so they persist?

**A: NOW they are!** I just synced them:

**Files updated in `pi-agent-base/`:**
```
pi-agent-base/
├── settings.json                    # ✅ Package order + quietStartup
├── AGENTS.md                         # ✅ Extension conflict notes
└── extensions/
    ├── README-VIM-POWERLINE.md       # ✅ Full explanation
    ├── vim-powerline-fix.md          # ✅ Technical notes
    └── EXTENSION-CONFLICTS-EXPLAINED.md  # ✅ This file
```

**How chezmoi syncs it:**

1. You edit files in `pi-agent-base/`
2. Run `chezmoi apply`
3. `run_after_sync-pi-agent-base.sh.tmpl` executes
4. Runs `rsync -a --delete pi-agent-base/ ~/.pi/agent/`
5. Your `~/.pi/agent/` is now in sync

**On a new machine:**
```bash
# Clone dotfiles
chezmoi init --apply https://github.com/ianyimi/dotfiles

# run_after_sync-pi-agent-base.sh.tmpl runs automatically
# ✅ ~/.pi/agent/ is populated with your config
# ✅ settings.json has correct package order
# ✅ pi-vim loads last automatically
```

---

## Recommended Path Forward

### Immediate (Done ✅):
- [x] Package load order in `settings.json`
- [x] Ansible playbook installs in correct order
- [x] Changes synced to `pi-agent-base/`
- [x] Documentation created

### Short-term (If you want both features):
1. Fork `pi-powerline-footer`
2. Make `BashModeEditor` extend `ModalEditor`
3. Install from your fork: `pi install git:github.com/yourusername/pi-powerline-footer`
4. Submit upstream PR

### Long-term (If you want a general solution):
1. Create `pi-editor-bridge` npm package
2. Export a `createBridgeEditor()` function:
```typescript
export function createBridgeEditor(...editors: EditorClass[]) {
  // Compose multiple editor classes intelligently
  // Merge keybindings, render methods, etc.
  return CompositeEditor;
}
```
3. Use it in a custom extension:
```typescript
import { ModalEditor } from "pi-vim";
import { BashModeEditor } from "pi-powerline-footer";
import { createBridgeEditor } from "pi-editor-bridge";

export default function(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    const BridgedEditor = createBridgeEditor(ModalEditor, BashModeEditor);
    ctx.ui.setEditorComponent((tui, theme, kb) => 
      new BridgedEditor(tui, theme, kb)
    );
  });
}
```

---

## Current State Summary

✅ **Working now**: Vim keybindings + Powerline UI  
✅ **Persisted**: Changes in `pi-agent-base/`, synced via chezmoi  
✅ **Documented**: Full explanation for future reference  
❌ **Lost features**: Powerline's BashModeEditor (bash mode, ghost suggestions)  
⏭️ **Next step**: Fork + PR to make both work together natively

---

## Testing the Current Solution

```bash
# 1. Apply dotfiles (syncs pi-agent-base to ~/.pi/agent)
chezmoi apply

# 2. Verify settings
cat ~/.pi/agent/settings.json | grep -A 10 packages

# Expected output:
#   "packages": [
#     "npm:pi-powerline-footer",
#     ...
#     "npm:pi-vim"  ← LAST
#   ]

# 3. Start Pi
pi

# 4. Verify both work:
#    - Powerline status bar visible at top
#    - Press Esc → hjkl → vim keybindings work
#    - Bottom right shows "NORMAL" or "INSERT"
```
