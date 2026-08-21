---
applies_to: ["lua/plugins/**/*.lua"]
---
# Plugin spec file shape

Every file under `lua/plugins/<category>/` MUST `return` a lazy.nvim spec: either a single
spec table `return { "author/repo", ... }` (lua/plugins/formatting/conform.lua:1) or a LIST
of specs when plugins form one feature unit (lua/plugins/util/chezmoi.lua:1-9 pairs
chezmoi.vim + chezmoi.nvim). The plugin is the FIRST positional string. One plugin per file
is the default; file name = repo short name (see lua-style/naming.md).

## opts vs config (choose by need, don't mix arbitrarily)
- `opts = { ... }` declarative table — lazy calls `setup` for you. Use for pure config
  (coding/mini-pairs.lua:4, util/snacks.lua:5, editor/ts-comments.lua:3 `opts = {}`).
- `opts = function() ... return {...} end` — when opts need runtime `require`/computation
  (editor/telescope.lua:41, coding/mini-ai.lua:5).
- `config = function() require("x").setup({...}) end` — imperative, for heavy custom logic
  (ui/barbar.lua:43, formatting/conform.lua:4, editor/oil.lua:130).
- `config = function(_, opts) require("x").setup(opts) end` — bridge opts to custom setup
  (ui/bufferline.lua:90; mini-pairs.lua:16 delegates to `LazyVim.mini.pairs(opts)`).
- `init = function() ... end` — runs BEFORE load, only for `vim.g.*` flags a plugin reads
  at startup (util/chezmoi.lua:4-7, coding/nvim-surround.lua:4).

Never wrap a plain opts table in a `config` that just calls setup — use `opts`.

## Dependencies
`dependencies = { "author/repo" }` string list (barbar.lua:5), or nested spec tables when a
dep needs its own `build`/`cond`/`enabled` (telescope.lua:5-40, lsp/nvim-lspconfig.lua:2-17).

## Requires
Inside `config`, bind modules with `local x = require("x")` at the top of the FUNCTION
(barbar.lua:40-43, conform.lua:5), never at file top — specs must load without the plugin
installed.

## Category placement
A new spec goes in the dir matching its primary user-facing role: `ui/` (tabline, statusline,
notifications, colorscheme loaders), `editor/` (navigation, buffers, git, editing tools),
`coding/` (text micro-tools, snippets), `lsp/` (servers + cmp stack), `formatting/` (conform),
`util/` (infra: tmux, chezmoi, snacks), `ai/`. `colorschemes/` is NOT auto-imported
(managed by huez) — lazy.lua imports only lsp, editor, formatting, coding, ui, util, ai.
