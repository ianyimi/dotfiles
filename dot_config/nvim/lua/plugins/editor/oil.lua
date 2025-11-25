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
			_bench("oil.setup begin")
			require("oil").setup({
				default_file_explorer = true,
				columns = {
					"icon",
					{
						"mtime",
						format = "%b %d %I:%M %p", -- 12-hour format with AM/PM (e.g., "Jan 15 03:45 PM")
					},
					"size",
				},
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
					border = "rounded",
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
					["fy"] = {
						desc = "Copy files/folders to clipboard (cross-instance)",
						callback = function()
							local oil = require("oil")
							local current_dir = oil.get_current_dir()
							if not current_dir then
								vim.notify("Not in an oil buffer", vim.log.levels.ERROR)
								return
							end

							local mode = vim.fn.mode()
							local files = {}

							if mode == "v" or mode == "V" then
								local start_line = vim.fn.line("v")
								local end_line = vim.fn.line(".")
								if start_line > end_line then
									start_line, end_line = end_line, start_line
								end
								for line = start_line, end_line do
									local entry = oil.get_entry_on_line(0, line)
									if entry and entry.name then
										-- Remove trailing slash from directories
										local name = entry.name:gsub("/$", "")
										table.insert(files, current_dir .. name)
									end
								end
								vim.cmd("normal! \\<Esc>")
							else
								local entry = oil.get_cursor_entry()
								if entry and entry.name then
									-- Remove trailing slash from directories
									local name = entry.name:gsub("/$", "")
									table.insert(files, current_dir .. name)
								end
							end

							if #files == 0 then
								vim.notify("No files/folders selected", vim.log.levels.WARN)
								return
							end

							local json = vim.fn.json_encode(files)
							vim.fn.setreg("+", json)
							vim.notify(string.format("Copied %d item(s) to clipboard", #files))
						end,
					},
					["fp"] = {
						desc = "Paste files/folders from clipboard (cross-instance)",
						callback = function()
							local oil = require("oil")
							local dest_dir = oil.get_current_dir()
							if not dest_dir then
								vim.notify("Not in an oil buffer", vim.log.levels.ERROR)
								return
							end

							local clipboard = vim.fn.getreg("+")
							local ok, files = pcall(vim.fn.json_decode, clipboard)

							if not ok or type(files) ~= "table" then
								vim.notify("No valid files/folders in clipboard", vim.log.levels.ERROR)
								return
							end

							for _, source_path in ipairs(files) do
								local filename = vim.fn.fnamemodify(source_path, ":t")
								local dest_path = dest_dir .. filename

								local cmd = string.format("cp -r %s %s",
									vim.fn.shellescape(source_path),
									vim.fn.shellescape(dest_path))

								local result = vim.fn.system(cmd)
								if vim.v.shell_error ~= 0 then
									vim.notify("Failed to copy: " .. filename .. "\n" .. result, vim.log.levels.ERROR)
								end
							end

							vim.notify(string.format("Pasted %d item(s)", #files))
							require("oil.actions").refresh.callback()
						end,
					},
				},
			})
			_bench("oil.setup end")
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "oil",
				callback = function(args)
					-- Disable global <leader>p in Oil buffers
					vim.keymap.set("x", "<leader>p", "<Nop>", { buffer = args.buf, desc = "Disabled in Oil" })
				end,
			})
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "oil",
				once = true,
				callback = function()
					_bench("FileType oil")
				end,
			})
			vim.api.nvim_create_autocmd("BufEnter", {
				pattern = "oil://*",
				once = true,
				callback = function()
					_bench("BufEnter oil")
					vim.schedule(function()
						pcall(vim.cmd, "redraw!")
					end)
					-- Kick off Harpoon/Barbar sync shortly after startup so pins render
					vim.defer_fn(function()
						pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "HarpoonListChanged" })
					end, 200)
				end,
			})
		end,
	},
}
