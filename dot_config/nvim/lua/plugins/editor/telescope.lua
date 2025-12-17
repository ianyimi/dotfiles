return {
	"nvim-telescope/telescope.nvim",
	event = "VimEnter",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ -- If encountering errors, see telescope-fzf-native README for installation instructions
			"nvim-telescope/telescope-fzf-native.nvim",

			-- `build` is used to run some command when the plugin is installed/updated.
			-- This is only run then, not every time Neovim starts up.
			build = "make",

			-- `cond` is a condition used to determine whether this plugin should be
			-- installed and loaded.
			cond = function()
				return vim.fn.executable("make") == 1
			end,
		},
		{ "nvim-telescope/telescope-ui-select.nvim" },
		{ "danielpieper/telescope-tmuxinator.nvim" },
		{ "nvim-tree/nvim-web-devicons",            enabled = vim.g.have_nerd_font },
		{ "xvzc/chezmoi.nvim" },
		{
			"stevearc/dressing.nvim",
			lazy = true,
			enabled = function()
				return require("util").pick.want() == "telescope"
			end,
			init = function()
				-- ---@diagnostic disable-next-line: duplicate-set-field
				-- vim.ui.select = function(...)
				--   require("lazy").load({ plugins = { "dressing.nvim" } })
				--   return vim.ui.select(...)
				-- end
				-- ---@diagnostic disable-next-line: duplicate-set-field
				-- vim.ui.input = function(...)
				--   require("lazy").load({ plugins = { "dressing.nvim" } })
				--   return vim.ui.input(...)
				-- end
			end,
		},
	},
	opts = function()
		local actions = require("telescope.actions")
		-- local trouble = require("trouble.providers.telescope")

		-- local open_with_trouble = function(...)
		--   return trouble.open_with_trouble(...)
		-- end

		local find_files_no_ignore = function(prompt_bufnr)
			local action_state = require("telescope.actions.state")
			local line = action_state.get_current_line()
			actions.close(prompt_bufnr)
			require("telescope.builtin").find_files({ no_ignore = true, default_text = line })
		end

		local find_files_with_hidden = function(prompt_bufnr)
			local action_state = require("telescope.actions.state")
			local line = action_state.get_current_line()
			actions.close(prompt_bufnr)
			require("telescope.builtin").find_files({ hidden = true, default_text = line })
		end

		return {
			defaults = {
				cwd = vim.fn.getcwd(),
				prompt_prefix = " ",
				selection_caret = " ",
				get_selection_window = function()
					local wins = vim.api.nvim_list_wins()
					table.insert(wins, 1, vim.api.nvim_get_current_win())
					for _, win in ipairs(wins) do
						local buf = vim.api.nvim_win_get_buf(win)
						if vim.bo[buf].buftype == "" then
							return win
						end
					end
					return 0
				end,
				vimgrep_arguments = {
					"rg",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case",
					"--fixed-strings",
				},
				mappings = {
					i = {
						-- ["<a-t>"] = open_with_trouble,
						["<a-i>"] = find_files_no_ignore,
						["<a-h>"] = find_files_with_hidden,
						["<a-v>"] = actions.file_vsplit,
						["<a-b>"] = actions.file_split,
						["<C-Down>"] = actions.cycle_history_next,
						["<C-Up>"] = actions.cycle_history_prev,
						["<PageDown>"] = actions.preview_scrolling_down,
						["<PageUp>"] = actions.preview_scrolling_up,
						["<C-s>"] = function(prompt_bufnr)
							local state = require("telescope.actions.state")
							local entry = state.get_selected_entry()
							local path = entry and (entry.path or entry.filename or entry.value) or nil
							actions.select_default(prompt_bufnr)
							if path then
								vim.schedule(function()
									local ok_h, harpoon = pcall(require, "harpoon")
									if not ok_h then return end
									local list = harpoon:list()
									if list and type(list.add) == "function" then
										pcall(function() list:add() end)
										pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "HarpoonListChanged" })
									end
								end)
							end
						end,
					},
					n = {
						["q"] = actions.close,
						["<C-s>"] = function(prompt_bufnr)
							local state = require("telescope.actions.state")
							local entry = state.get_selected_entry()
							local path = entry and (entry.path or entry.filename or entry.value) or nil
							actions.select_default(prompt_bufnr)
							if path then
								vim.schedule(function()
									local ok_h, harpoon = pcall(require, "harpoon")
									if not ok_h then return end
									local list = harpoon:list()
									if list and type(list.add) == "function" then
										pcall(function() list:add() end)
										pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "HarpoonListChanged" })
									end
								end)
							end
						end,
					},
				},
			},
			pickers = {},
		}
	end,
	config = function(_, opts)
		require("telescope").setup(opts)

		-- Load Telescope extensions if they are installed
		pcall(require("telescope").load_extension, "fzf")
		pcall(require("telescope").load_extension, "ui-select")
		pcall(require("telescope").load_extension, "git-worktree")
		pcall(require("telescope").load_extension, "chezmoi")
		pcall(require("telescope").load_extension, "tmuxinator")

		-- Keymaps for Telescope functions
		local builtin = require("telescope.builtin")
		local extensions = require("telescope").extensions

		-- Shared utility to add enhanced telescope functionality
		local function enhance_telescope_opts(ofopts, picker_type)
			ofopts = ofopts or {}
			local current_dir = vim.fn.getcwd()

			-- Project-scoped behavior
			if picker_type == "oldfiles" then
				ofopts.cwd = current_dir
			elseif picker_type == "find_files" then
				-- Find files specific options can go here
			end

			-- Add enhanced previewer with custom filetype detection for all pickers
			ofopts.previewer = require('telescope.previewers').new_buffer_previewer({
				title = "File Preview",
				get_buffer_by_name = function(_, entry)
					return entry.value or entry.filename or entry[1]
				end,
				teardown = function(self)
					-- Kill any running job when preview is torn down
					if self.state and self.state.preview_job_id then
						pcall(vim.fn.jobstop, self.state.preview_job_id)
						self.state.preview_job_id = nil
					end
				end,
				define_preview = function(self, entry)
					local filename = entry.value or entry.filename or entry[1]
					local filepath = entry.path or filename

					if not filepath or filepath == "" then return end

					-- Kill any existing job before starting a new one
					if self.state.preview_job_id then
						pcall(vim.fn.jobstop, self.state.preview_job_id)
						self.state.preview_job_id = nil
					end

					-- Use same logic as find_files for all file types
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
					self.state.preview_job_id = vim.fn.jobstart({ 'cat', filepath }, {
						stdout_buffered = true,
						on_stdout = function(_, data)
							if data and #data > 0 then
								if data[#data] == "" then
									table.remove(data, #data)
								end
								local lines = {}
								for _, line in ipairs(data) do
									for split_line in line:gmatch("[^\n]*") do
										if split_line ~= "" or #lines == 0 then
											table.insert(lines, split_line)
										end
									end
								end
								vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

								-- Custom filetype detection for telescope previews
								local function detect_filetype(fname)
									-- Handle chezmoi dotfiles
									if fname == "dot_zshrc" then
										return "zsh"
									elseif fname == "dot_bashrc" then
										return "bash"
									elseif fname == "dot_profile" or fname == "dot_bash_profile" then
										return "bash"
									elseif fname:match("^dot_") then
										local suffix = fname:match("^dot_(.+)$")
										if suffix then
											if suffix:match("zsh") then
												return "zsh"
											elseif suffix:match("bash") then
												return "bash"
											elseif suffix:match("gitconfig") then
												return "gitconfig"
											elseif suffix:match("vimrc") or suffix:match("nvimrc") then
												return "vim"
											end
										end
										return "conf"
									end

									-- Handle other file patterns
									-- TypeScript / TSX
									if fname:match("%.tsx$") then
										return "tsx"
									elseif fname:match("%.ts$") then
										return "typescript"
									elseif fname:match("%.zsh$") or fname:match("zshrc") then
										return "zsh"
									elseif fname:match("%.sh$") or fname:match("%.bash$") or fname:match("bashrc") then
										return "bash"
									elseif fname:match("%.conf$") or fname:match("%.cfg$") or fname:match("%.config$") then
										return "conf"
									end

									-- Fallback to vim's detection
									return vim.filetype.match({ filename = fname }) or 'text'
								end

								local ft = detect_filetype(vim.fn.fnamemodify(filename, ':t'))
								vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', ft)

								-- Apply treesitter highlighting if available
								local lang = (vim.treesitter.language and vim.treesitter.language.get_lang(ft)) or ft
								local ok_has, has = pcall(function() return require('nvim-treesitter.parsers').has_parser(lang) end)
								if ok_has and has then
									pcall(vim.treesitter.start, self.state.bufnr, lang)
								else
									-- Fallback to regex highlighting
									require('telescope.previewers.utils').regex_highlighter(self.state.bufnr, ft)
								end
							end
						end,
					})
				end,
			})

			-- The global telescope mappings already handle:
			-- - Harpoon integration (<C-n>)
			-- - File splits (<a-v>, <a-b>)
			-- - History navigation (<C-Down>, <C-Up>)
			-- - Preview scrolling (<PageDown>, <PageUp>)
			-- So we don't need to duplicate them here

			return ofopts
		end

		local function project_oldfiles(ofopts)
			local enhanced_opts = enhance_telescope_opts(ofopts, "oldfiles")

			-- Force reload ShaDa to get latest oldfiles (fixes per-project ShaDa staleness)
			-- Use pcall to handle case where ShaDa file doesn't exist yet (new worktrees)
			pcall(vim.cmd, 'rshada!')

			-- Get currently open buffer to exclude from results
			local current_buf = vim.api.nvim_get_current_buf()
			local current_file = vim.api.nvim_buf_get_name(current_buf)
			local current_file_normalized = current_file ~= "" and vim.fn.fnamemodify(current_file, ":p") or nil

			-- Get MRU files from our custom tracking
			local mru_files = _G.__mru_files or {}
			local cwd = enhanced_opts.cwd or vim.fn.getcwd()
			local cwd_normalized = vim.fn.fnamemodify(cwd, ":p")

			-- Filter MRU files: only current project, exclude current buffer
			local project_mru = {}
			local seen = {}
			for _, filepath in ipairs(mru_files) do
				local normalized = vim.fn.fnamemodify(filepath, ":p")
				if normalized ~= current_file_normalized
						and normalized:find(cwd_normalized, 1, true) == 1
						and vim.fn.filereadable(normalized) == 1 then
					table.insert(project_mru, normalized)
					seen[normalized] = true
				end
			end

			-- Add v:oldfiles as fallback for historical files not in current session
			local oldfiles = vim.tbl_filter(function(file)
				local normalized = vim.fn.fnamemodify(file, ":p")
				return not seen[normalized]
						and normalized ~= current_file_normalized
						and normalized:find(cwd_normalized, 1, true) == 1
						and vim.fn.filereadable(normalized) == 1
			end, vim.v.oldfiles or {})

			-- Merge: MRU first (current session), then oldfiles (historical)
			for _, file in ipairs(oldfiles) do
				table.insert(project_mru, file)
			end

			-- Use telescope's standard picker with hybrid MRU + oldfiles list
			local conf = require("telescope.config").values
			local finders = require("telescope.finders")
			local make_entry = require("telescope.make_entry")
			local pickers = require("telescope.pickers")

			pickers.new(enhanced_opts, {
				prompt_title = "Recent Files (MRU)",
				finder = finders.new_table({
					results = project_mru,
					entry_maker = make_entry.gen_from_file(enhanced_opts),
				}),
				sorter = conf.file_sorter(enhanced_opts),
				previewer = enhanced_opts.previewer,
			}):find()
		end

		local function escape_special_chars(path)
			return path:gsub("%(", "\\("):gsub("%)", "\\)"):gsub("%[", "\\["):gsub("%]", "\\]")
		end

		local function find_files_with_escaped_paths(opts)
			opts = opts or {}
			opts.hidden = true
			opts.no_ignore = true
			opts.prompt_title = "Find Files"

			-- Track preview state per file
			local env_preview_states = {}

			-- Custom previewer that hides content for .env files
			opts.previewer = require('telescope.previewers').new_buffer_previewer({
				title = "File Preview",
				get_buffer_by_name = function(_, entry)
					return entry.value
				end,
				teardown = function(self)
					-- Kill any running job when preview is torn down
					if self.state and self.state.preview_job_id then
						pcall(vim.fn.jobstop, self.state.preview_job_id)
						self.state.preview_job_id = nil
					end
				end,
				define_preview = function(self, entry)
					local filename = entry.value
					local filepath = entry.path or entry.filename

					-- Kill any existing job before starting a new one
					if self.state.preview_job_id then
						pcall(vim.fn.jobstop, self.state.preview_job_id)
						self.state.preview_job_id = nil
					end

					-- Handle .env files
					if filename:match("%.env") then
						local show_content = env_preview_states[filepath] or false

						if show_content then
							-- Clear buffer first
							vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
							-- Show actual file contents
							self.state.preview_job_id = vim.fn.jobstart({ 'cat', filepath }, {
								stdout_buffered = true,
								on_stdout = function(_, data)
									if data and #data > 0 then
										-- Remove empty last line that cat often adds
										if data[#data] == "" then
											table.remove(data, #data)
										end
										-- Split any lines that contain newlines
										local lines = {}
										for _, line in ipairs(data) do
											for split_line in line:gmatch("[^\n]*") do
												if split_line ~= "" or #lines == 0 then
													table.insert(lines, split_line)
												end
											end
										end
										vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
										vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'bash')
									end
								end,
							})
						else
							-- Show security message
							vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
								"",
								"  🔒 .env file preview hidden for security",
								"",
								"  Press <Tab> to show/hide preview",
								"  Press <Enter> to open file",
								"",
							})
							vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'text')
						end
					else
						-- Use default preview for other files
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
						self.state.preview_job_id = vim.fn.jobstart({ 'cat', filepath }, {
							stdout_buffered = true,
							on_stdout = function(_, data)
								if data and #data > 0 then
									if data[#data] == "" then
										table.remove(data, #data)
									end
									-- Split any lines that contain newlines
									local lines = {}
									for _, line in ipairs(data) do
										for split_line in line:gmatch("[^\n]*") do
											if split_line ~= "" or #lines == 0 then
												table.insert(lines, split_line)
											end
										end
									end
									vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

									-- Custom filetype detection for telescope previews
									local function detect_filetype(fname)
										-- Handle chezmoi dotfiles
										if fname == "dot_zshrc" then
											return "zsh"
										elseif fname == "dot_bashrc" then
											return "bash"
										elseif fname == "dot_profile" or fname == "dot_bash_profile" then
											return "bash"
										elseif fname:match("^dot_") then
											local suffix = fname:match("^dot_(.+)$")
											if suffix then
												if suffix:match("zsh") then
													return "zsh"
												elseif suffix:match("bash") then
													return "bash"
												elseif suffix:match("gitconfig") then
													return "gitconfig"
												elseif suffix:match("vimrc") or suffix:match("nvimrc") then
													return "vim"
												end
											end
											return "conf"
										end

										-- Handle other file patterns
										-- TypeScript / TSX
										if fname:match("%.tsx$") then
											return "tsx"
										elseif fname:match("%.ts$") then
											return "typescript"
										elseif fname:match("%.zsh$") or fname:match("zshrc") then
											return "zsh"
										elseif fname:match("%.sh$") or fname:match("%.bash$") or fname:match("bashrc") then
											return "bash"
										elseif fname:match("%.conf$") or fname:match("%.cfg$") or fname:match("%.config$") then
											return "conf"
										end

										-- Fallback to vim's detection
										return vim.filetype.match({ filename = fname }) or 'text'
									end

									local ft = detect_filetype(filename)
									vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', ft)

									-- Apply treesitter highlighting if available
									local lang = (vim.treesitter.language and vim.treesitter.language.get_lang(ft)) or ft
									local ok_has, has = pcall(function() return require('nvim-treesitter.parsers').has_parser(lang) end)
									if ok_has and has then
										pcall(vim.treesitter.start, self.state.bufnr, lang)
									else
										-- Fallback to regex highlighting
										require('telescope.previewers.utils').regex_highlighter(self.state.bufnr, ft)
									end
								end
							end,
						})
					end
				end,
			})

			-- Add custom keymaps
			opts.attach_mappings = function(prompt_bufnr, map)
				-- Toggle .env file preview with Tab
				local toggle_env_preview = function()
					local entry = require('telescope.actions.state').get_selected_entry()
					if entry and entry.value:match("%.env") then
						local filepath = entry.path or entry.filename
						env_preview_states[filepath] = not (env_preview_states[filepath] or false)

						-- Force preview refresh by getting the picker and updating
						local picker = require('telescope.actions.state').get_current_picker(prompt_bufnr)
						picker.previewer.state.last_set_bufnr = nil -- Force refresh
						picker:refresh_previewer()
					else
						-- Default Tab behavior for non-.env files
						return false
					end
				end

				map("i", "<Tab>", toggle_env_preview)
				map("n", "<Tab>", toggle_env_preview)

				return true
			end

			-- Set find_command to show .env files and handle all finder tools
			if vim.fn.executable("rg") == 1 then
				opts.find_command = { "rg", "--files", "--color", "never", "--hidden", "--no-ignore", "-g", "!.git", "-g",
					"!node_modules" }
			elseif vim.fn.executable("fd") == 1 then
				opts.find_command = { "fd", "--type", "f", "--color", "never", "--hidden", "--no-ignore", "-E", ".git", "-E",
					"node_modules" }
			elseif vim.fn.executable("fdfind") == 1 then
				opts.find_command = { "fdfind", "--type", "f", "--color", "never", "--hidden", "--no-ignore", "-E", ".git", "-E",
					"node_modules" }
			elseif vim.fn.executable("find") == 1 and vim.fn.has("win32") == 0 then
				opts.find_command = { "find", ".", "-type", "f", "!", "-path", "*/.git/*", "!", "-path", "*/node_modules/*" }
			end

			-- Handle escaped paths for directories with special characters
			if opts.search_dirs then
				for i, dir in ipairs(opts.search_dirs) do
					opts.search_dirs[i] = escape_special_chars(dir)
				end
			end

			require("telescope.builtin").find_files(opts)
		end

		-- Enhanced find files with shared utility
		local function enhanced_find_files(opts)
			local enhanced_opts = enhance_telescope_opts(opts, "find_files")
			find_files_with_escaped_paths(enhanced_opts)
		end

		vim.keymap.set("n", "<leader>ff", function()
			enhanced_find_files()
		end, { desc = "[F]ind [F]iles" })


		vim.keymap.set("n", "<leader>ft", builtin.builtin, { desc = "[F]ind [S]elect Telescope" })
		vim.keymap.set("n", "<leader>fs", function()
			extensions.tmuxinator.projects(require('telescope.themes').get_dropdown({}))
		end, { desc = "[F]ind [S]ession" })
		vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "[F]ind [H]elp" })
		vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "[F]ind [K]eymaps" })
		vim.keymap.set("n", "gw", builtin.grep_string, { desc = "[G]rep current [W]ord" })
		vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "[F]ind by [G]rep" })
		vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "[F]ind [D]iagnostics" })
		vim.keymap.set("n", "<leader>fw", function()
			extensions.git_worktree.git_worktrees()
		end, { desc = "[F]ind [W]orkspace" })
		vim.keymap.set("n", "<leader>cw", function()
			extensions.git_worktree.create_git_worktree()
		end, { desc = "[C]reate [W]orkspace" })
		vim.keymap.set("n", "<leader>f.", project_oldfiles, { desc = '[F]ind Recent Files ("." for repeat)' })

		-- Search Chezmoi configuration files
		vim.keymap.set("n", "<leader>fc", extensions.chezmoi.find_files, { desc = "[F]ind [C]hezmoi" })
		-- Advanced example: Search within the current buffer
		vim.keymap.set("n", "<leader>fb", function()
			builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
				winblend = 10,
				previewer = false,
			}))
		end, { desc = "[F]uzzily search in current [B]uffer" })

		-- Live Grep in open files
		vim.keymap.set("n", "<leader>fo", function()
			builtin.live_grep({ grep_open_files = true, prompt_title = "Live Grep in Open Files" })
		end, { desc = "[F]ind in [O]pen Files" })
	end,
}
