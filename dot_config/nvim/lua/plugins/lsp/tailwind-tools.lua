return {
	"luckasRanarison/tailwind-tools.nvim",
	name = "tailwind-tools",
	build = ":UpdateRemotePlugins",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-telescope/telescope.nvim", -- optional
		"neovim/nvim-lspconfig", -- optional
	},
	opts = {
		server = {
			override = false,
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
			},
		},
	},
}
