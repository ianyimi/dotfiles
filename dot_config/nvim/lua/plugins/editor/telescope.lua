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

		-- Useful for getting pretty icons, but requires a Nerd Font.
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

		local function find_command()
			if vim.fn.executable("rg") == 1 then
				return { "rg", "--files", "--color", "never", "-g", "!.git" }
			elseif vim.fn.executable("fd") == 1 then
				return { "fd", "--type", "f", "--color", "never", "-E", ".git" }
			elseif vim.fn.executable("fdfind") == 1 then
				return { "fdfind", "--type", "f", "--color", "never", "-E", ".git" }
			elseif vim.fn.executable("find") == 1 and vim.fn.has("win32") == 0 then
				return { "find", ".", "-type", "f" }
			elseif vim.fn.executable("where") == 1 then
				return { "where", "/r", ".", "*" }
			end
		end

		return {
			defaults = {
				cwd = false,
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
					},
					n = {
						["q"] = actions.close,
					},
				},
			},
			pickers = {
				find_files = {
					find_command = find_command(),
					hidden = true,
				},
			},
			extensions = {
				tmuxinator = {
					select_action = 'kill',
					stop_action = 'kill',
				}
			}
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

		local function escape_special_chars(path)
			return path:gsub("%(", "\\("):gsub("%)", "\\)"):gsub("%[", "\\["):gsub("%]", "\\]")
		end

		local function project_oldfiles(ofopts)
			ofopts = ofopts or {}
			local current_dir = vim.fn.getcwd()

			ofopts.cwd_only = true
			ofopts.cwd = current_dir

			if ofopts.search_dirs then
				for i, dir in ipairs(ofopts.search_dirs) do
					ofopts.search_dirs[i] = escape_special_chars(dir)
				end
			end

			builtin.oldfiles(ofopts)
		end

		local function find_files_with_escaped_paths(opts)
			opts = opts or {}
			if opts.search_dirs then
				for i, dir in ipairs(opts.search_dirs) do
					opts.search_dirs[i] = escape_special_chars(dir)
				end
			end
			require("telescope.builtin").find_files(opts)
		end

		vim.keymap.set("n", "<leader>ff", function()
			find_files_with_escaped_paths()
		end, { desc = "[F]ind [F]iles" })
		vim.keymap.set("n", "<leader>fst", builtin.builtin, { desc = "[F]ind [S]elect Telescope" })
		vim.keymap.set("n", "<leader>fs",
			require('telescope').extensions.tmuxinator.projects(require('telescope.themes').get_dropdown({})),
			{ desc = "[F]ind [S]ession" })
		vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "[F]ind [H]elp" })
		vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "[F]ind [K]eymaps" })
		vim.keymap.set("n", "<leader>gw", builtin.grep_string, { desc = "[G]rep current [W]ord" })
		vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "[F]ind by [G]rep" })
		vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "[F]ind [D]iagnostics" })
		vim.keymap.set("n", "<leader>fw", function()
			extensions.git_worktree.git_worktrees()
		end, { desc = "[F]ind [W]orkspace" })
		vim.keymap.set("n", "<leader>cw", function()
			extensions.git_worktree.create_git_worktree()
		end, { desc = "[C]reate [W]orkspace" })
		vim.keymap.set("n", "<leader>f.", project_oldfiles, { desc = '[F]ind Recent Files ("." for repeat)' })
		-- vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "[ ] Find existing buffers" })

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
			builtin.live_grep({
				grep_open_files = true,
				prompt_title = "Live Grep in Open Files",
			})
		end, { desc = "[F]ind in [O]pen Files" })
	end,
}
