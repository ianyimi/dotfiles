local initial_cwd = vim.fn.getcwd()
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
				-- Always use the directory where nvim was started as the key
				key = function()
					return initial_cwd
				end,
			},
		},
	keys = function()
		local harpoon = require("harpoon")
		-- basic telescope configuration
		local keys = {
				{
					"<leader>s",
					function()
						pcall(function()
							harpoon:list():add()
							vim.cmd(":do User")
						end)
					end,
					desc = "Harpoon File",
				},
				{
					"<leader>y",
					function()
						pcall(function()
							harpoon.ui:toggle_quick_menu(harpoon:list())
						end)
					end,
					desc = "Harpoon Quick Menu",
				},
		}

		for i = 1, 9 do
        table.insert(keys, (function(idx)
            return {
                "<leader>" .. idx,
                function()
                    pcall(function()
                        harpoon:list():select(idx)
                    end)
                end,
                desc = "Harpoon to File " .. idx,
            }
        end)(i))
		end
		return keys
	end,
}
