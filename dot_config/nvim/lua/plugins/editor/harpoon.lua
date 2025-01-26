return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	lazy = false,
	opts = {
		menu = {
			width = vim.api.nvim_win_get_width(0) - 4,
		},
		settings = {
			save_on_toggle = true,
			tabline = true,
		},
	},
	keys = function()
		local harpoon = require("harpoon")
		-- basic telescope configuration
		local keys = {
			{
				"<leader>s",
				function()
					harpoon:list():add()
					vim.cmd(":do User")
				end,
				desc = "Harpoon File",
			},
			{
				"<leader>y",
				function()
					harpoon.ui:toggle_quick_menu(harpoon:list())
				end,
				desc = "Harpoon Quick Menu",
			},
		}

		for i = 1, 9 do
			table.insert(keys, {
				"<leader>" .. i,
				function()
					harpoon:list():select(i)
				end,
				desc = "Harpoon to File " .. i,
			})
		end
		return keys
	end,
}
