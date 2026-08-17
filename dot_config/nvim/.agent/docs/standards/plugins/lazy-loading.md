---
applies_to: ["lua/plugins/**/*.lua"]
---
# Lazy-loading triggers

Pick exactly one trigger by how the plugin is reached. Getting this wrong makes a plugin
either load at startup (slow) or never load when needed.

- `event = "VeryLazy"` — background UI / editing tools not needed for the first frame
  (ui/barbar.lua:4, coding/mini-pairs.lua:3, editor/diffview.lua:3, ui/which-key.lua:3).
- `event = { "BufReadPre", "BufNewFile" }` — must attach before a file renders, e.g.
  format-on-save (formatting/conform.lua:3).
- `event = { "BufReadPost", "BufWritePost", "BufNewFile" }` — per-file editing features
  (editor/gitsigns.lua:3, editor/nvim-treesitter-context.lua:3). Comment `-- "LazyFile"`.
- `event = "VimEnter"` — first interactive UI (editor/telescope.lua:3).
- `cmd = "GrugFar"` — command-invoked only (editor/grug-far.lua:4).
- `keys = { ... }` — reached solely via a keymap; the keys table IS the trigger
  (editor/codesnap.lua:4, editor/undotree.lua:4).
- `ft = { "markdown", ... }` — filetype-scoped (ai/avante.lua:188 img-clip dep).
- `lazy = false` — MUST load at startup: colorschemes, tabline data sources, treesitter
  (util/snacks.lua:3, editor/harpoon.lua:5, editor/treesitter.lua:27).
- `lazy = true` — a dep loaded on demand by another plugin (coding/lua-snip.lua:3).

`priority = 1000` (or 999) pairs with `lazy = false` when the plugin must beat all others —
colorschemes and snacks (snacks.lua:2, colorschemes/lush.lua:5,15).

## enabled flag
`enabled` gates whether the spec is even considered:
- Boolean literal for on/off (barbar.lua:3 `= true`).
- Runtime expression for capability gates: `enabled = vim.fn.has("nvim-0.10.0") == 1`
  (ts-comments.lua:5), `enabled = vim.g.have_nerd_font` (telescope.lua:23),
  `enabled = function() return require("util").pick.want() == "telescope" end`
  (telescope.lua:27).

Put `enabled` and the trigger near the TOP of the spec, right after the repo string, so load
behavior is visible at a glance (barbar.lua:2-5).
