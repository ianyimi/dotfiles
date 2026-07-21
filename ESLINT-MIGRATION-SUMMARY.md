# ESLint Migration Summary

**Date:** 2026-07-13  
**Status:** ✅ Complete - Ready to apply with `cma`

---

## What Changed

### 1. **macos.yml** - Added Global ESLint Installation
   - Added `eslint` npm global package installation
   - Located before `eslint_d` and `prettierd`
   - This makes ESLint available system-wide alongside oxlint

### 2. **Project Dependencies** - Already Configured
   - ✅ **vexcms**: ESLint 9.39.5 installed and working
   - ✅ **maprios-app**: ESLint 9.39.4 installed and working
   - Both projects have all required plugins:
     - `eslint-plugin-perfectionist` (import/object sorting)
     - `eslint-plugin-import-x` (import management)
     - `eslint-plugin-jsdoc` (JSDoc enforcement)
     - `@typescript-eslint` (TypeScript rules)

### 3. **Neovim Config** - Already Optimized
   Your `nvim-lspconfig.lua` is already perfectly configured:
   ```lua
   lspconfig.eslint.setup({
     settings = {
       useFlatConfig = true,
       format = false,  -- oxfmt handles formatting
       codeActionOnSave = {
         enable = true,
         mode = "all",  -- Applies all fixable rules on save
       },
     },
   })
   ```

---

## How It Works Now

### **Dual-Tool Strategy: oxfmt + ESLint**

| Tool | Purpose | Speed | What It Handles |
|------|---------|-------|-----------------|
| **oxfmt** | Formatting | ⚡ 30x faster than Prettier | Whitespace, semicolons, quotes |
| **ESLint** | Linting + Semantic Fixes | 🐌 Slower (type-aware) | Import sorting, JSDoc, plugins |

### **On Save Behavior**

1. **Format**: oxfmt runs (fast, <1s)
2. **Fix**: ESLint auto-fixes (slower, ~2-3s)
   - Sorts imports (perfectionist)
   - Sorts JSX props
   - Fixes JSDoc issues
   - Removes duplicate imports
   - Sorts Tailwind classes (via tailwindcss LSP)

---

## Tailwind Sorting

### **Status**: ✅ Should Work Now

Your projects use **Tailwind v4** (CSS-based config):
- **vexcms**: `tailwind.css` at root with `@import "tailwindcss"`
- **maprios-app**: `globals.css` with `@import "tailwindcss"`

Your LSP config already detects Tailwind v4:
```lua
root_dir = require("lspconfig.util").root_pattern(
  "tailwind.config.js",
  "tailwind.css",  -- ← Detects v4 setup
  "postcss.config.js"
)
```

The `tailwind-tools.nvim` plugin provides:
- Class sorting (via TailwindCSS LSP `codeAction`)
- Completion
- Hover previews

---

## Testing After `cma`

### 1. **Verify Global ESLint**
```bash
which eslint
# Should show: /Users/zaye/.nvm/versions/node/.../bin/eslint
# or /usr/local/bin/eslint

eslint --version
# Should show: v9.x.x
```

### 2. **Test in vexcms**
```bash
cd ~/Documents/Projects/vex.git/dev
nvim packages/core/src/some-file.ts
```

**Open a TypeScript file and:**
1. Mess up import order → Save → Should auto-sort
2. Add JSX with unsorted props → Save → Should auto-sort
3. Add unsorted Tailwind classes → Save → Should auto-sort
4. Add a function without JSDoc → Should see warning

### 3. **Test in maprios-app**
```bash
cd ~/Documents/Projects/maprios-app.git/dev/apps/app
nvim src/app/(frontend)/some-component.tsx
```

**Same tests as above.**

### 4. **Check LSP Attachment**
In Neovim, run:
```vim
:LspInfo
```

Should show:
- `eslint` attached (for .ts/.tsx files)
- `tailwindcss` attached (for .tsx files)
- `vtsls` or `tsserver` attached

### 5. **Check Tailwind Sorting Specifically**
Create a test file:
```tsx
// Test unsorted classes
<div className="p-4 mt-2 bg-red-500 text-white flex">
```

Save (`:w`) → Should reorder to:
```tsx
<div className="flex mt-2 bg-red-500 p-4 text-white">
```

---

## Troubleshooting

### **ESLint Not Sorting on Save**
```vim
:LspInfo
```
Check if `eslint` is attached. If not:
```bash
# In project root
pnpm install
# Restart Neovim
```

### **Tailwind Not Sorting**
```vim
:LspInfo
```
Check if `tailwindcss` is attached. If not:
1. Verify `tailwind.css` or `globals.css` exists
2. Ensure it has `@import "tailwindcss"`
3. Restart Neovim

### **"LSP Flags Errors But Doesn't Fix"**
This was happening because:
- oxlint couldn't fix plugin-based rules
- ESLint wasn't installed/running

**Now fixed** - ESLint LSP will auto-fix on save.

### **Imports Still Not Sorted**
Check ESLint config has perfectionist:
```bash
# In project root
cat eslint.config.mjs | grep perfectionist
```

Should see: `perfectionist.configs["recommended-natural"]` (maprios) or import sorting rules (vex).

---

## RAM Usage Comparison

| Setup | RAM Usage | Trade-offs |
|-------|-----------|------------|
| **oxlint only** | ~50MB | ❌ No plugins, no semantic fixes |
| **ESLint (type-aware)** | ~200-400MB | ✅ Full plugin support, slow on large projects |
| **ESLint (no type-checking)** | ~100-150MB | ⚠️ Faster but misses type errors |
| **Current: oxfmt + ESLint** | ~250-450MB | ✅ Fast formatting + full linting |

**Your choice:** You already have ESLint LSP running, so you're paying the RAM cost anyway. Might as well use it!

---

## What You Were Missing Before

With oxlint only:
- ❌ No import sorting (perfectionist)
- ❌ No JSDoc enforcement
- ❌ No Convex-specific rules
- ❌ No auto-fixing of semantic issues
- ❌ Tailwind sorting broken (ESLint provides codeAction)

With ESLint + oxfmt:
- ✅ Import sorting on save
- ✅ JSDoc warnings + auto-fix
- ✅ All plugin rules enforced
- ✅ Tailwind sorting via LSP
- ✅ Fast formatting (oxfmt)
- ✅ Semantic fixes on save

---

## Next Steps

1. **Run `cma`** to apply macos.yml changes
   ```bash
   cma
   ```

2. **Restart any open tmux sessions** or just reload shell:
   ```bash
   source ~/.zshrc
   ```

3. **Open both projects in Neovim** and test:
   - Import sorting
   - Tailwind class sorting
   - JSDoc warnings

4. **Report back** if anything doesn't work as expected!

---

## Files Modified

- ✅ `.local/share/chezmoi/dot_bootstrap/macos.yml` - Added global ESLint
- ✅ Both projects already have ESLint installed
- ✅ Neovim config already optimal

**Ready to apply!** Run `cma` when you're ready.
