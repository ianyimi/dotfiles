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
			"jsonc",
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

		-- Per-buffer highlighting + indent. On main there is no global
		-- `highlight.enable` — you start treesitter explicitly per buffer.
		-- Catch-all FileType autocmd with pcall: tries to start the parser for
		-- whatever the buffer's filetype is, silently does nothing if no parser
		-- exists (e.g. for filetypes we never installed, or before background
		-- install finishes on first run).
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
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
				start_treesitter(bufnr)
				vim.b[bufnr].ts_started = true
			end
		end

		-- nvim-ts-autotag is a separate plugin with its own setup
		require("nvim-ts-autotag").setup()
	end,
}
