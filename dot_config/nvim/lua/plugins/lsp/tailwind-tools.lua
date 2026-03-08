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
					{ "cn%(([^)]*)%)" },
					{ "cva%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
				},
				javascriptreact = {
					{ "cn%(([^)]*)%)" },
					{ "cva%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
				},
				typescript = {
					{ "cn%(([^)]*)%)" },
					{ "cva%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
				},
				typescriptreact = {
					{ "cn%(([^)]*)%)" },
					{ "cva%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
				},
				astro = {
					{ "cn%(([^)]*)%)" },
					{ "cva%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
				},
			},
		},
	},
}
