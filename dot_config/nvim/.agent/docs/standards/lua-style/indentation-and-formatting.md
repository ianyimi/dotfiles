---
applies_to: ["**/*.lua"]
---
# Indentation, quotes & formatting

The tree has NO `stylua.toml` and NO `.editorconfig` (verified by glob + grep). `dot_luarc.json`
sets only `diagnostics.globals: ["vim"]` — no style keys. Lua is formatted by stylua via
conform (formatting/conform.lua:28 `lua = { "stylua" }`) with format-on-save enabled
(conform.lua:34-37). With no config file, stylua uses DEFAULTS:
- 2-space indentation (spaces, not tabs)
- double quotes (AutoPreferDouble — singles rewritten unless the string contains `"`)
- trailing comma on the last element of multi-line tables
- 120-column line width

## Indentation reality: MIXED — match the file you're editing
Two code populations coexist:
- Vendored / LazyVim-derived files use 2 SPACES and are stylua-clean: `lua/util/init.lua`
  (LazyVim portions), `lua/util/lsp.lua`, `root.lua`, `format.lua`, `toggle.lua`,
  `formatting/conform.lua`.
- Hand-authored personal files use literal TAB bytes: `lua/config/options.lua`,
  `lua/config/autocmds.lua`, `editor/harpoon.lua`, `ui/barbar.lua`, `editor/oil.lua`, and
  the `M.safe_buf_delete` graft inside `lua/util/init.lua:26-51`.

`options.lua:118-122` sets `expandtab=true` + width 2, so the editor inserts SPACES; the tab
bytes are legacy and would flip to spaces if stylua ever touched those files.

## Rule for new code
- Editing an existing file → match that file's existing indent. Never mix within one file.
- New file → 2 spaces + double quotes + trailing commas (what format-on-save produces).

Don't hand-align tables or manage line-wraps — stylua owns that.
