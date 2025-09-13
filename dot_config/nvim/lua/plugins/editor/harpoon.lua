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
						local current_file = vim.api.nvim_buf_get_name(0)
						local list = harpoon:list()
						local found_index = nil

						-- Check if current file is already in harpoon list
						for i, item in ipairs(list.items) do
							if vim.fn.fnamemodify(item.value, ":p") == vim.fn.fnamemodify(current_file, ":p") then
								found_index = i
								break
							end
						end

						if found_index then
							-- Remove from harpoon list by rebuilding without the item
							local new_items = {}
							for i, item in ipairs(list.items) do
								if i ~= found_index then
									table.insert(new_items, item)
								end
							end
							list.items = new_items
							list._length = #new_items
							vim.api.nvim_exec_autocmds("User", { pattern = "HarpoonListChanged" })
						else
							-- Add to harpoon list
							list:add()
							vim.api.nvim_exec_autocmds("User", { pattern = "HarpoonListChanged" })
						end
					end)
				end,
				desc = "Toggle Harpoon File",
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
