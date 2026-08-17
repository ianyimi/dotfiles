---
applies_to: ["**/*.lua"]
---
# Naming conventions

## File names — kebab-case (verified across full lua/**/*.lua listing)
Multi-word Lua files use hyphens, NEVER underscores: `lsp-debug.lua`, `memory-monitor.lua`,
`error-lens.lua`, `nvim-file-location.lua`, `render-markdown.lua`, `auto-dark-mode.lua`,
`setup-ghana-cozy.lua`. Single-word files are bare lowercase: `init.lua`, `root.lua`,
`options.lua`, `keymaps.lua`. ZERO snake_case filenames exist.

Plugin-spec files mirror the upstream repo short name (author stripped; `.nvim`/`.vim`
suffix usually dropped; internal dots become hyphens): `telescope.lua` (telescope.nvim),
`oil.lua`, `mini-pairs.lua` (mini.pairs), `ts-comments.lua`. Keep a `nvim-`/`vim-` prefix
when the bare name would be ambiguous: `nvim-lspconfig.lua`, `vim-glsl.lua`,
`nvim-treesitter-context.lua`.

## Module table — `local M = {}`
Every module returns a table literally named `M` (util/lsp.lua:2, util/root.lua:3,
util/format.lua:2, util/toggle.lua:2). Modules are NOT PascalCase-named — the old
"PascalCase modules" doc claim is wrong at the file/return level.

## Variables & functions — snake_case, two exceptions
- Functions and locals: snake_case — `M.safe_buf_delete` (util/init.lua:25), `M.on_attach`
  (util/lsp.lua:25), `get_git_branch` (config/options.lua), `should_open_oil`
  (config/autocmds.lua).
- Exception 1 — required "class-like" modules take PascalCase locals: `local LazyUtil =
  require("lazy.core.util")` (util/init.lua:1), `local Config`, `local Plugin`.
- Exception 2 — LuaLS type names: dotted lowercase `lazyvim.util.lsp` for module classes,
  PascalCase for structural types `LazyFormatter`, `LazyRoot` (format.lua:11, root.lua:9).
- Stray inconsistency, do not copy: `local tabSize` (options.lua:119) — prefer `tab_size`.

## Globals — `_G.<name>`
Cross-module globals are snake_case on `_G`: `_G.update_harpoon_from_buffer_order`,
`_G.refresh_oil_display` (barbar.lua:509-512), `_G.get_oil_winbar` (oil.lua:114). Private
caches/bench use a `__` prefix: `_G.__mru_files` (autocmds.lua:405), `_G.__boot_t0`
(config/lazy.lua:30). Always guard reads: `if _G.refresh_oil_display then ... end`
(autocmds.lua:279).
