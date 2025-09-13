-- helper function to parse output
local pending_git = {}
local git_status = {}

local function start_git_status(dir)
	if pending_git[dir] or git_status[dir] then
		return
	end
	pending_git[dir] = { ignored = {}, tracked = {}, done = { ignored = false, tracked = false } }

	vim.system(
		{ "git", "ls-files", "--ignored", "--exclude-standard", "--others", "--directory" },
		{ cwd = dir, text = true },
		function(res)
			local ignored = {}
			if res.code == 0 and res.stdout then
				for line in vim.gsplit(res.stdout, "\n", { plain = true, trimempty = true }) do
					line = line:gsub("/$", "")
					ignored[line] = true
				end
			end
			local p = pending_git[dir]
			if not p then
				return
			end
			p.ignored = ignored
			p.done.ignored = true
			if p.done.tracked then
				git_status[dir] = { ignored = p.ignored, tracked = p.tracked }
				pending_git[dir] = nil
				vim.schedule(function()
					local ok, actions = pcall(require, "oil.actions")
					if ok and actions.refresh and actions.refresh.callback then
						pcall(actions.refresh.callback)
					end
				end)
			end
		end
	)

	vim.system(
		{ "git", "ls-tree", "HEAD", "--name-only" },
		{ cwd = dir, text = true },
		function(res)
			local tracked = {}
			if res.code == 0 and res.stdout then
				for line in vim.gsplit(res.stdout, "\n", { plain = true, trimempty = true }) do
					tracked[line] = true
				end
			end
			local p = pending_git[dir]
			if not p then
				return
			end
			p.tracked = tracked
			p.done.tracked = true
			if p.done.ignored then
				git_status[dir] = { ignored = p.ignored, tracked = p.tracked }
				pending_git[dir] = nil
				vim.schedule(function()
					local ok, actions = pcall(require, "oil.actions")
					if ok and actions.refresh and actions.refresh.callback then
						pcall(actions.refresh.callback)
					end
				end)
			end
		end
	)
end

-- -- Clear git status cache on refresh
-- local refresh = require("oil.actions").refresh
-- local orig_refresh = refresh.callback
-- refresh.callback = function(...)
--   git_status = new_git_status()
--   orig_refresh(...)
-- end

-- Declare a global function to retrieve the current directory
function _G.get_oil_winbar()
	local dir = require("oil").get_current_dir()
	if dir then
		return vim.fn.fnamemodify(dir, ":~")
	else
		-- If there is no current directory (e.g. over ssh), just show the buffer name
		return vim.api.nvim_buf_get_name(0)
	end
end

return {
	{
		"stevearc/oil.nvim",
		opts = {},
		enabled = true,
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("oil").setup({
				default_file_explorer = true,
				columns = { "icon", "mtime", "size" },
				delete_to_trash = true,
				skip_confirm_for_simple_edits = true,
				watch_for_changes = true,
				view_options = {
					show_hidden = true,
					natural_order = true,
					is_always_hidden = function(name, _)
						return name == ".." or name == ".git"
					end,
					is_hidden_file = function(name, bufnr)
						local dir = require("oil").get_current_dir(bufnr)
						local is_dotfile = vim.startswith(name, ".") and name ~= ".."
						-- if no local directory (e.g. for ssh connections), just hide dotfiles
						if not dir then
							return is_dotfile
						end
						-- dotfiles are considered hidden unless tracked
						if not git_status[dir] and not pending_git[dir] then
							start_git_status(dir)
						end
						local st = git_status[dir]
						if not st then
							return is_dotfile
						end
						if is_dotfile then
							return not st.tracked[name]
						else
							return st.ignored[name]
						end
					end,
				},
				float = {
					max_width = 120,
				},
				win_options = {
					wrap = true,
					winblend = 0,
					winbar = "%!v:lua.get_oil_winbar()",
				},
				keymaps = {
					["<C-c>"] = false,
					["gx"] = false,
					["q"] = "actions.close",
					["<Esc>"] = "actions.close",
					["."] = "actions.parent",
					[";"] = "actions.cd",
					["<C-v>"] = {
						"actions.select",
						opts = { vertical = true },
						desc = "Open the entry in a vertical split",
					},
					["<C-r>"] = "actions.refresh",
					["<C-s>"] = "actions.change_sort",
					["<C-h>"] = "actions.toggle_hidden",
					["<C-x>"] = "actions.toggle_trash",
					["<C-p>"] = "actions.preview",
					["<C-d>"] = {
						desc = "Toggle file detail view",
						callback = function()
							detail = not detail
							if detail then
								require("oil").set_columns({ "icon", "size", "mtime" })
							else
								require("oil").set_columns({ "icon" })
							end
						end,
					},
					["<C-y>"] = {
						desc = "[C]opy Directory path",
						callback = function()
							local current_dir = require("oil").get_current_dir()

							-- Function to escape special characters
							local function escape_special_chars(str)
								-- Escape Lua pattern special characters
								local special_chars =
								{ "(", ")", "[", "]", "%%", ".", "+", "-", "*", "?", "^", "$", "/" }
								for _, char in ipairs(special_chars) do
									str = str:gsub("%" .. char, "\\" .. char)
								end
								return str
							end

							-- Copy it to the system clipboard
							if current_dir then
								-- Format to replace home with ~
								local escaped_dir = escape_special_chars(vim.fn.fnamemodify(current_dir, ":~"))
								vim.fn.setreg("+", escaped_dir)
								vim.notify("Directory path copied: " .. escaped_dir)
							else
								vim.notify("No directory found", vim.log.levels.ERROR)
							end
						end,
					},
					gs = {
						desc = "[G]rep in Directory",
						callback = function()
							-- get the current directory
							local prefills = { paths = require("oil").get_current_dir() }

							local grug_far = require("grug-far")
							-- instance check
							if not grug_far.has_instance("explorer") then
								grug_far.open({
									instanceName = "explorer",
									prefills = prefills,
									staticTitle = "Find and Replace from Explorer",
								})
							else
								grug_far.open_instance("explorer")
								-- updating the prefills without clearing the search and other fields
								grug_far.update_instance_prefills("explorer", prefills, false)
							end
						end,
					},
				},
			})
		end,
	},
}
