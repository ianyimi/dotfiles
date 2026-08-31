-- nvim-treesitter `main` branch — full rewrite with a different API than master.
--
-- Why we're on main:
--   master was archived 2026-04-03 (read-only). Its custom query predicates
--   (set-lang-from-info-string!, downcase!) were never updated for Nvim 0.10+'s
--   changed query-match shape, which crashes markdown injection on Nvim 0.12.
--   See https://github.com/nvim-treesitter/nvim-treesitter/issues/8618 (closed
--   "Not planned"). The fix is to migrate to main, where those broken
--   predicates were deleted (the custom predicates file is gone entirely and
--   Nvim core's @injection.language capture handles the markdown case correctly).
--
-- Setup docs:
--   :help nvim-treesitter
--   https://github.com/nvim-treesitter/nvim-treesitter
--
-- System requirements (installed via ~/.bootstrap/macos.yml):
--   - Nvim 0.12+
--   - tree-sitter-cli 0.26.1+ (brew install tree-sitter-cli — NOT npm)
--   - tar, curl, C compiler
--
-- Note: main branch does NOT support lazy-loading. Must be lazy = false.
-- After install, verify with :checkhealth nvim-treesitter and :TSLog.

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	dependencies = { "windwp/nvim-ts-autotag" },
	config = function()
		-- setup() is optional — only needed to override defaults like install_dir.
		require("nvim-treesitter").setup({})

		-- Parsers — installed asynchronously. No-op if already present.
		-- First run will install in the background; restart Nvim once they finish
		-- if you want a fully-highlighted experience immediately.
		-- See :help nvim-treesitter.install()
		require("nvim-treesitter").install({
			"astro",
			"bash",
			"c",
			"comment",
			"css",
			"diff",
			"dockerfile",
			"git_config",
			"git_rebase",
			"gitattributes",
			"gitcommit",
			"gitignore",
			"go",
			"gomod",
			"html",
			"ini",
			"javascript",
			"jsdoc",
			"json",
			"json5",
			-- jsonc removed: not a separate parser on nvim-treesitter `main`.
			-- JSONC files highlight via the `json` parser plus comment injection.
			-- (Warning was: "[nvim-treesitter] warning: skipping unsupported language: jsonc")
			"lua",
			"luadoc",
			"luap",
			"make",
			"markdown",
			"markdown_inline",
			"printf",
			"python",
			"query",
			"regex",
			"scss",
			"sql",
			"ssh_config",
			"toml",
			"tsx",
			"typescript",
			"vim",
			"vimdoc",
			"xml",
			"yaml",
		})

		-- Fence info-strings Nvim cannot resolve to a parser on its own. Core's
		-- injection query captures the info-string text and resolves it through
		-- vim.treesitter.language.get_lang, so an alias here is all that is
		-- needed -- cheaper than a query pattern, which would inject a SECOND
		-- region over the same fence that core already covered. (Measured: the
		-- hand-written fenced_code_block patterns this replaces doubled the
		-- bash/json/typescript/yaml region counts -- 288 -> 302 regions on a
		-- 2179-line spec -- for zero added coverage.)
		for lang, aliases in pairs({
			bash = { "shell", "zsh" },
			javascript = { "dataviewjs" },
			tsx = { "datacoretsx" },
			yaml = { "yml" },
		}) do
			vim.treesitter.language.register(lang, aliases)
		end

		-- Markdown is the ONLY language in the runtime whose highlights query uses
		-- `conceal_lines` -- Nvim 0.12 queries/markdown/highlights.scm:53,59, on
		-- the fenced-code delimiter and the info-string language label. That
		-- metadata sets `has_conceal_line`, which sets
		-- `TSHighlighter._conceal_line` (highlighter.lua:108-112), which makes
		-- Nvim invoke the `on_conceal_line` decoration callback ONCE PER SCREEN
		-- ROW. Each call runs `tree:parse({row, row})` plus a full
		-- `prepare_highlight_states` -- a walk of every injected child tree
		-- (highlighter.lua:521-533) -- and the per-row memo is dropped on every
		-- `on_bytes`, so the whole sweep is repaid after each keystroke. That is
		-- why markdown alone went slow, and why the cost tracked document length.
		--
		-- Measured on a 2179-line spec (288 injected regions, 255 of them
		-- markdown_inline) in a 38-row window:
		--   conceal_lines present  ->  35.4 ms of conceal callbacks per redraw
		--   conceal_lines stripped ->   0.01 ms
		-- Everything a redraw actually needs is already cheap: 0.1-0.5 ms for the
		-- warm ranged parse, 4.5 ms for one screen of highlight queries, ~40 ms
		-- for the one-time cold parse. So this one directive was the entire
		-- markdown redraw cost.
		--
		-- Nothing is lost. render-markdown conceals both of those lines itself
		-- (render/markdown/code.lua sets conceal_lines on the delimiter node), and
		-- LSP hover floats render identically either way -- verified by running
		-- the same open_floating_preview against the pre-change config.
		--
		-- Patch the query TEXT rather than shadowing the .scm file, so upstream
		-- query fixes keep flowing through on Nvim upgrades. Doing it globally
		-- rather than per buffer is deliberate: it needs no ordering guarantee
		-- against Nvim's own ftplugin/markdown.lua (or mdx.nvim's, which resolves
		-- to the same markdown query), and it uses only public API.
		local chunks = {}
		for _, file in ipairs(vim.treesitter.query.get_files("markdown", "highlights")) do
			table.insert(chunks, table.concat(vim.fn.readfile(file), "\n"))
		end
		local patched, stripped = table.concat(chunks, "\n"):gsub('%(#set!%s+conceal_lines%s+""%)%s*', "")
		if stripped > 0 then
			vim.treesitter.query.set("markdown", "highlights", patched)
		end

		local function start_treesitter(bufnr)
			local ok = pcall(vim.treesitter.start, bufnr)
			if ok then
				-- Indentation (provided by nvim-treesitter; experimental but stable)
				vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("zaye_treesitter_start", { clear = true }),
			callback = function(args) start_treesitter(args.buf) end,
		})

		-- Re-trigger on every BufEnter as a safety net: on first install, parsers
		-- arrive AFTER the file was already opened, so the FileType autocmd's
		-- pcall failed (parser didn't exist yet). When the buffer regains focus
		-- after the install finishes, this retries silently. Idempotent —
		-- vim.treesitter.start on an already-attached buffer is a no-op.
		vim.api.nvim_create_autocmd("BufEnter", {
			group = vim.api.nvim_create_augroup("zaye_treesitter_start_bufenter", { clear = true }),
			callback = function(args)
				if vim.bo[args.buf].buftype == "" and not vim.b[args.buf].ts_started then
					start_treesitter(args.buf)
					vim.b[args.buf].ts_started = true
				end
			end,
		})

		-- Start treesitter on any buffers that are already open when this config
		-- runs (happens on :Lazy sync of an existing session, or when the plugin
		-- config function runs after the file has already been loaded).
		--
		-- An already-attached highlighter is torn down first: vim.treesitter.start
		-- no-ops on an attached buffer, so a markdown highlighter built before the
		-- conceal_lines patch above would keep its `_conceal_line = true` -- the
		-- exact per-row sweep the patch exists to remove -- until the buffer was
		-- reopened.
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
				if vim.b[bufnr].ts_highlight then
					pcall(vim.treesitter.stop, bufnr)
				end
				start_treesitter(bufnr)
				vim.b[bufnr].ts_started = true
			end
		end

		-- nvim-ts-autotag is a separate plugin with its own setup
		require("nvim-ts-autotag").setup()
	end,
}
