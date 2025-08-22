return {
	{
		"rktjmp/lush.nvim",
		lazy = false, -- Need to be loaded early for colorschemes to work
		priority = 1000,
		config = function()
			-- Ghana Cozy colorschemes are now managed by Huez
			-- Dark theme: :colorscheme ghana-cozy
			-- Light theme: :colorscheme ghana-cozy-light
		end,
	},
	{
		"rktjmp/shipwright.nvim",
		lazy = false, -- Load immediately so :Shipwright command is available
		priority = 999,
		-- Only needed for building/exporting themes
	},
}

