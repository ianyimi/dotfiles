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
				-- Conservative patterns - only match obvious class utilities
				javascript = {
					{ "cn%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
					{ "cva%(([^)]*)%)" }, -- Basic CVA support
				},
				javascriptreact = {
					{ "cn%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
					{ "cva%(([^)]*)%)" },
				},
				typescript = {
					{ "cn%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
					{ "cva%(([^)]*)%)" },
				},
				typescriptreact = {
					{ "cn%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
					{ "cva%(([^)]*)%)" },
				},
				astro = {
					{ "cn%(([^)]*)%)" },
					{ "cx%(([^)]*)%)" },
					{ "clsx%(([^)]+)%)" },
					{ "cva%(([^)]*)%)" },
				},
			},
		},
	},
}
