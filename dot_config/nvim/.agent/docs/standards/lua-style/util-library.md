---
applies_to: ["lua/util/**/*.lua"]
---
# `_G.LazyVim` util library conventions

The util library is a LazyVim-derived module tree at `lua/util/`, bootstrapped as the global
`_G.LazyVim = require("util")` (config/lazy.lua:27). Access any submodule as
`LazyVim.<name>` from anywhere.

## Adding a new util module
1. Create `lua/util/<name>.lua` (kebab-case if multi-word) that opens with a LuaLS class
   annotation and returns `M`:
   ```lua
   ---@class lazyvim.util.<name>
   local M = {}
   return M
   ```
   (pattern: lsp.lua:1-2, toggle.lua:1-2).
2. Register it on the aggregate class in `lua/util/init.lua:4-25` with a
   `---@field <name> lazyvim.util.<name>` line — documentation only; loading is automatic.
3. Lazy auto-loading: init.lua's `setmetatable(M, { __index = ... })` (init.lua:62-83) does
   `t[k] = require("util." .. k)` on first access and caches it. Deprecated aliases route
   through the `deprecated` table (init.lua:54-65).

## Lazy-require, NOT require-at-top
Only the module's own framework deps sit at top (`local LazyUtil = require("lazy.core.util")`,
init.lua:1). Everything else is required INSIDE functions to avoid load-order loops:
`require("gitsigns")` inside safe_buf_delete (init.lua:31), `require("which-key")` inside
toggle.wk (toggle.lua:47). The init comment says so: "load here to prevent loops"
(init.lua:73).

## Error handling shape
- Wrap risky ops in `pcall`: `pcall(function() require("gitsigns").detach(buf) end)`
  (init.lua:30), `pcall(vim.api.nvim_buf_delete, ...)` (init.lua:45), `pcall(toggle.get)`
  (toggle.lua:44).
- Notify through the library, never raw `vim.notify`: `LazyVim.info/warn/error(msg,
  { title = "LazyVim" })` (init.lua:295-300). Formatter failures use `LazyVim.try(fn,
  { msg = ... })` (format.lua:132).
- Guard buffers before acting: `nvim_buf_is_valid` / `buflisted` / `buftype` checks
  (lsp.lua:63-72).

## Deferral patterns
- `vim.schedule(fn)` to defer to a safe point (init.lua:171, harpoon.lua:52).
- `vim.defer_fn(fn, 100)` for a fixed settle delay (autocmds.lua oil_auto_open).
- Debounce with a reused `vim.uv.new_timer()` handle (init.lua:157, barbar.lua:515).
