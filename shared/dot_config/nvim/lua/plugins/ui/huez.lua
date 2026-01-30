return {
	"vague2k/huez.nvim",
	-- if you want registry related features, uncomment this
	import = "huez-manager.import",
	branch = "stable",
	event = "UIEnter",
	config = function()
		require("huez").setup({
			theme_config_module = "colorschemes",
			fallback = "ghana-cozy", -- Set Ghana Cozy as default dark theme
			exclude = {
				"cyberdream",
				"desert",
				"evening",
				"industry",
				"koehler",
				"morning",
				"murphy",
				"pablo",
				"peachpuff",
				"ron",
				"shine",
				"slate",
				"torte",
				"zellner",
				"blue",
				"darkblue",
				"delek",
				"quiet",
				"elflord",
				"habamax",
				"lunaperche",
				"zaibatsu",
				"wildcharm",
				"sorbet",
				"vim",
			},
		})
		local pickers = require("huez.pickers")

		vim.keymap.set("n", "<leader>to", pickers.themes, { desc = "[T]heme Switcher [O]pen" })
		vim.keymap.set("n", "<leader>tf", pickers.favorites, { desc = "[T]heme Favorites" })
		vim.keymap.set("n", "<leader>tl", pickers.live, { desc = "[T]hemes [L]ive" })
		vim.keymap.set("n", "<leader>te", pickers.ensured, { desc = "[T]hemes [E]nsured" })
	end,
}
