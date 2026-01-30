return {
	"luckasRanarison/tailwind-tools.nvim",
	name = "tailwind-tools",
	event = "VeryLazy",
	build = ":UpdateRemotePlugins",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-telescope/telescope.nvim", -- optional
		"neovim/nvim-lspconfig",       -- optional
	},
	opts = {
		server = {
			override = false,
		},
		filetypes = {
			"astro",
			"html",
			"javascriptreact",
			"typescriptreact",
			"javascript",
			"typescript",
			"svelte",
			"vue",
		},
		extension = {
			patterns = {
				javascript = {
					{ "cva%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
				},
				typescript = {
					{ "cva%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
				},
				astro = {
					{ "cva%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
				},
			},
		},
	},
}
