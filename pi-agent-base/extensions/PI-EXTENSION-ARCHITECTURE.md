# Pi Extension Architecture - Understanding Conflicts

## TL;DR: Why Extensions Conflict

**Pi allows only ONE editor component at a time.** Multiple extensions calling `ctx.ui.setEditorComponent()` will conflict - the last one wins.

This is a fundamental architectural limitation, not a bug.

---

## What Can Coexist

✅ **Widgets** - Multiple extensions can use `ctx.ui.setWidget()`  
✅ **Header** - One `ctx.ui.setHeader()`  
✅ **Footer** - One `ctx.ui.setFooter()`  
✅ **Tools** - Unlimited `pi.registerTool()`  
✅ **Commands** - Unlimited `pi.registerCommand()`  
✅ **Event listeners** - Unlimited `pi.on()`  

## What Conflicts

❌ **Editor** - Only ONE `ctx.ui.setEditorComponent()`  
❌ **Autocomplete** - Only one provider per editor  

---

## Extension Conflict Matrix

| Extension | Uses | Conflicts With |
|-----------|------|----------------|
| `pi-vim` | `setEditorComponent()` | pi-powerline-footer, pi-image-preview |
| `pi-powerline-footer` | `setEditorComponent()` | pi-vim, pi-image-preview |
| `pi-image-preview` | `setWidget()` + polling | NONE ✅ |
| `lsp-pi` | Tools + commands | NONE ✅ |
| `pi-btw` | Vault integration | NONE ✅ |

---

## Solution: Manual Integration

When packages conflict, you must:

1. **Copy source code** to local extensions
2. **Modify one to extend the other** (class inheritance)
3. **Remove npm packages** from settings

This is what we did with `vim-powerline`:

### Our Solution

```
extensions/
├── vim-powerline.ts              # Top-level loader (Pi auto-loads this)
└── vim-powerline/
    ├── index.ts                  # Exports powerline extension
    ├── vim/                      # Full pi-vim source
    │   └── index.ts              # Exports ModalEditor
    └── powerline/                # Full pi-powerline-footer source
        ├── index.ts              # Powerline extension logic
        └── bash-mode/
            └── editor.ts         # MODIFIED: extends ModalEditor
```

**Key modification** in `powerline/bash-mode/editor.ts`:
```typescript
import { ModalEditor } from "../../vim/index.ts";  // ← Added
export class BashModeEditor extends ModalEditor {  // ← Changed from CustomEditor
```

Now powerline's editor **inherits** vim's modal editing!

---

## What We Get

✅ **Full vim modal editing** (ESC, hjkl, visual mode, operators)  
✅ **Complete powerline status bar** (model, git, tokens, time, etc.)  
✅ **Clean vim mode indicator** at bottom left  
✅ **Bash mode** with ghost completions  
✅ **Image preview** (separate package, uses widgets - no conflict!)  
✅ **NO package conflicts** (vim + powerline are local source)  

---

## Pi's Design Philosophy

Pi intentionally keeps the editor API simple:
- ONE editor instance
- ONE autocomplete provider
- ONE header, ONE footer
- Unlimited widgets, tools, commands

**Why?** Simplicity and predictability. Composition would require complex coordination protocols.

**Tradeoff:** Manual integration when packages conflict.

---

## Future Integration Tips

When combining editor-modifying packages:

1. **Check what they modify** (`setEditorComponent`? Just widgets?)
2. **If both use editor** → manual integration required
3. **Copy both sources** to extensions folder
4. **Make one extend the other** (class inheritance)
5. **Test thoroughly** - method conflicts can happen

---

## Q: Does Pi make combining packages easy?

**A: Only if they don't modify the editor.**

- Widgets, tools, commands → Easy to combine ✅
- Multiple editor packages → Manual integration required ⚠️

This is intentional - Pi prioritizes simplicity over automatic composition.
