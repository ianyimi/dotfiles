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
			"html",
			"json",
			"lua",
			"markdown",
			"markdown_inline",
			"query",
			"regex",
			"toml",
			"javascript",
			"tsx",
			"typescript",
			"vim",
			"vimdoc",
			"yaml"
		},
	},
	config = function(_, opts)
		if type(opts.ensure_installed) == "table" then
			opts.ensure_installed = require("util").dedup(opts.ensure_installed)
		end
		require("nvim-treesitter.configs").setup(opts)
		require("nvim-ts-autotag").setup()
	end,
}
