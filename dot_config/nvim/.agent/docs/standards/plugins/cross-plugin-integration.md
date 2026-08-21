---
applies_to: ["lua/plugins/**/*.lua", "lua/config/lazy.lua"]
---
# Cross-plugin integration & migration

## Integration bus: User autocmd events (preferred)
Decoupled plugins talk via a named `User` autocmd, NOT direct requires. The canonical
channel is `HarpoonListChanged`: producers fire it with
`vim.api.nvim_exec_autocmds("User", { pattern = "HarpoonListChanged" })`
(editor/harpoon.lua:101, editor/telescope.lua:115, editor/oil.lua:351, ui/barbar.lua:388);
consumers subscribe with `nvim_create_autocmd("User", { pattern = ..., callback = ... })`
(barbar.lua:534, debounced at barbar.lua:515-538). Prefer this over cross-requiring.

## Integration bus: _G globals (use sparingly, always guard)
Shared functions hang off `_G` when an event won't fit: `_G.update_harpoon_from_buffer_order`,
`_G.handle_file_rename`, `_G.refresh_oil_display`, `_G.cleanup_empty_buffers`
(barbar.lua:509-512), `_G.get_oil_winbar` (oil.lua:114), `_G._bench` (config/lazy.lua).
Callers MUST guard existence before calling: `if _G.update_harpoon_from_buffer_order then
... end` (barbar.lua:16-18) — the owning plugin may be disabled. Vimscript-plugin config
goes through `vim.g[...]` in an `init` (util/chezmoi.lua:5-6, coding/nvim-surround.lua:6).

## Keymaps
Plugin keymaps live in the spec's `keys` table, not lua/config/keymaps.lua — full placement
rules in keymaps/placement-and-structure.md.

## Migration / disable pattern (disable first, delete later)
Migrated-off plugins are DISABLED IN PLACE, config retained: set `enabled = false` right
after the repo string and leave the whole spec (ui/bufferline.lua:5, ui/alpha.lua:8,
coding/mini-ai.lua:4, editor/mini-files.lua:3, ui/nvim-notify.lua:3, ai/avante.lua:6,
ai/opencode.lua:3). Fully-retired files are renamed OUT of the import glob rather than
deleted: `nvim-lspconfig.lua.bak`, `nvim-lspconfig.lua.disabled` (lsp/). lazy.lua imports
whole category dirs, so a non-`.lua` extension excludes the file while preserving it.
Never hard-delete a working spec during migration.
