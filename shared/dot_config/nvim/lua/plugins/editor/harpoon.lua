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
	config = function(_, opts)
		local harpoon = require("harpoon")
		-- Try both styles to be compatible with harpoon2
		pcall(function()
			if type(harpoon.setup) == "function" then
				harpoon:setup(opts)
			else
				harpoon:setup(opts)
			end
		end)
		-- Wrap list methods to emit our sync event on changes
		local orig_list = harpoon.list
		local function compact_list(lst)
			if not lst or type(lst.items) ~= "table" then return end
			local new_items = {}
			for _, item in ipairs(lst.items) do
				if item and item.value and item.value ~= "" then
					table.insert(new_items, item)
				end
			end
			lst.items = new_items
			lst._length = #new_items
		end
		if type(orig_list) == "function" then
			harpoon.list = function(...)
				local lst = orig_list(...)
				if lst and not lst.__harpoon_event_wrapped then
					local function wrap(name)
						local fn = lst[name]
						if type(fn) == "function" then
							lst[name] = function(self, ...)
								local ret = fn(self, ...)
								-- Only compact for explicit removes to preserve Harpoon semantics
								if name == "remove" or name == "remove_at" then
									compact_list(self)
								end
								vim.schedule(function()
									pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "HarpoonListChanged" })
								end)
								return ret
							end
						end
					end
					for _, m in ipairs({ "add", "remove", "remove_at", "clear", "replace", "append", "prepend" }) do
						wrap(m)
					end
					lst.__harpoon_event_wrapped = true
				end
				return lst
			end
		end
	end,
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
						local list = harpoon:list()
						local function snapshot(lst)
							local vals = {}
							for i = 1, (lst:length() or #lst.items or 0) do
								local it = lst.items[i]
								vals[#vals + 1] = it and it.value or nil
							end
							return vals
						end
						local before = snapshot(list)
						harpoon.ui:toggle_quick_menu(list)
						vim.schedule(function()
							local menu_buf
							for _, buf in ipairs(vim.api.nvim_list_bufs()) do
								if vim.api.nvim_buf_is_loaded(buf) then
									local ok, ft = pcall(vim.api.nvim_get_option_value, "filetype", { buf = buf })
									local name = vim.api.nvim_buf_get_name(buf)
									if (ok and ft == "harpoon") or (name and name:match("Harpoon")) then
										menu_buf = buf
									end
								end
							end
							if menu_buf then
								vim.api.nvim_create_autocmd("BufWipeout", {
									buffer = menu_buf,
									once = true,
									callback = function()
										local after = snapshot(harpoon:list())
										local changed = false
										if #before ~= #after then
											changed = true
										else
											for i = 1, #before do
												if before[i] ~= after[i] then
													changed = true
													break
												end
											end
										end
										if changed then
											vim.api.nvim_exec_autocmds("User", { pattern = "HarpoonListChanged" })
										end
									end,
								})
							end
						end)
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
