return {
	"nvim-treesitter/nvim-treesitter",
	version = false,
	event = { "BufReadPost", "BufWritePost", "BufNewFile", "VeryLazy" },
	dependencies = {
		"windwp/nvim-ts-autotag",
	},
	lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
	init = function(plugin)
		-- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
		-- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
		-- no longer trigger the **nvim-treesitter** module to be loaded in time.
		-- Luckily, the only things that those plugins need are the custom queries, which we make available
		-- during startup.
		require("lazy.core.loader").add_to_rtp(plugin)
		require("nvim-treesitter.query_predicates")
	end,
	cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
	opts = {
		auto_install = true,
		highlight = { enable = true },
		-- indent = { enable = true },
		ensure_installed = {
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
		},
	},
	config = function(_, opts)
		if type(opts.ensure_installed) == "table" then
			opts.ensure_installed = require("util").dedup(opts.ensure_installed)
		end
		require("nvim-treesitter.configs").setup(opts)
		require("nvim-ts-autotag").setup()

		-- nvim-treesitter master is archived (see :Git log on the plugin) and never
		-- migrated its custom query predicates to Nvim 0.10+'s new query-match shape
		-- where match[capture_id] can be a node LIST instead of a single TSNode.
		-- Two directives in nvim-treesitter/lua/nvim-treesitter/query_predicates.lua
		-- call vim.treesitter.get_node_text directly on whatever is in match[id]:
		--    set-lang-from-info-string!   (used by markdown/injections.scm)
		--    downcase!                    (used by HTML / various)
		-- When the capture resolves to a node-list, get_node_text tries node:range()
		-- on a Lua table and throws "attempt to call method 'range' (a nil value)",
		-- which then poisons every parse that touches the same query — including
		-- treesitter highlighter decoration providers, breaking highlighting in any
		-- buffer that gets rendered while the broken parse is cached.
		--
		-- We re-register both directives with the same logic but with node-list
		-- defensiveness: if the capture is a list, use the first node.
		local query = vim.treesitter.query
		local function first_node(match, id)
			local v = match[id]
			if type(v) == "table" and not v.range then
				return v[1] -- node-list → take first
			end
			return v
		end

		local markdown_alias_map = {
			ex = "elixir", pl = "perl", rs = "rust", sh = "bash",
			js = "javascript", ts = "typescript", py = "python",
			htm = "html", yml = "yaml", md = "markdown",
		}

		query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
			local node = first_node(match, pred[2])
			if not node then return end
			local alias = vim.treesitter.get_node_text(node, bufnr):lower()
			metadata["injection.language"] = markdown_alias_map[alias] or alias
		end, { force = true, all = true })

		query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
			local node = first_node(match, pred[2])
			if not node then return end
			local text = vim.treesitter.get_node_text(node, bufnr):lower()
			local cap = pred[2]
			metadata[cap] = metadata[cap] or {}
			metadata[cap].text = text
		end, { force = true, all = true })
	end,
}
