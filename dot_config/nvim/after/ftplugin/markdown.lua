-- Skip the treesitter highlighter on oversized markdown.
--
-- Nvim 0.12 ships `$VIMRUNTIME/ftplugin/markdown.lua`, whose first line calls
-- `vim.treesitter.start()` unconditionally. That runs before any FileType
-- autocmd we register, so gating inside our own treesitter config is not enough
-- -- verified by wrapping vim.treesitter.start and capturing the caller:
--
--   vim.treesitter.start called 1 time(s) for markdown:
--     .../0.12.4/share/nvim/runtime/ftplugin/markdown.lua:1
--     .../0.12.4/share/nvim/runtime/filetype.lua:28
--
-- `after/ftplugin/` is sourced after the runtime copy, making it the only
-- reliable override point.
--
-- Why: injected-region count scales with document length (a 3761-line spec
-- carries ~460 regions, mostly markdown_inline), and the highlighter re-resolves
-- injections roughly once per visible line, each pass walking every child tree.
-- A single full-screen redraw measured 1129ms -- ~12x one full re-resolution --
-- so anything forcing a redraw while such a buffer is visible paid it: opening
-- an Oil float, a Telescope keystroke, a window switch.
--
-- Stopping only the highlighter leaves the parser reachable via get_parser, so
-- render-markdown still renders (verified: all 97 extmarks restored with the
-- highlighter off). The cost is plain syntax colouring inside the raw buffer,
-- which the rendered view largely replaces.

local bufnr = vim.api.nvim_get_current_buf()
local max_lines = vim.g.markdown_ts_highlight_max_lines or 1500

if vim.api.nvim_buf_line_count(bufnr) <= max_lines then
  return
end

pcall(vim.treesitter.stop, bufnr)
-- Keep a parser available for render-markdown and treesitter-context.
pcall(vim.treesitter.get_parser, bufnr)
vim.b[bufnr].ts_highlight_skipped = true

-- Fall back to Vim's regex syntax, or the buffer ends up with NO highlighting at
-- all: Nvim's markdown ftplugin uses treesitter *instead of* loading a syntax
-- script, so stopping the highlighter leaves nothing behind.
--
-- Regex syntax is a good trade here. Its cost is bounded per visible line (and
-- further capped by 'synmaxcol'), rather than scaling with injected-region count
-- the way the treesitter highlighter does. Fenced code blocks still get
-- highlighted via vim.g.markdown_fenced_languages, set in config/options.lua.
vim.bo[bufnr].syntax = "markdown"
