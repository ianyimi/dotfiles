return {
  "echasnovski/mini.files",
	enabled = false,
  opts = {
    windows = {
      preview = true,
      width_focus = 30,
      width_preview = 30,
    },
    options = {
      -- Whether to use for editing directories
      -- Disabled by default in LazyVim because neo-tree is used for that
      use_as_default_explorer = true,
    },
		mappings = {
			close = '<Esc>',
			go_in = '<CR>',
			go_out = '.',
			synchronize = '<leader>w'
		},
  },
  keys = {
    {
      "<leader>e",
      function()
        require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
      end,
      desc = "Open mini.files (Directory of Current File)",
    },
    {
      "<leader>E",
      function()
        require("mini.files").open(vim.uv.cwd(), true)
      end,
      desc = "Open mini.files (cwd)",
    },
  },
  config = function(_, opts)
    require("mini.files").setup(opts)

    local show_dotfiles = true
    local filter_show = function(fs_entry)
      return true
    end
    local filter_hide = function(fs_entry)
      return not vim.startswith(fs_entry.name, ".")
    end

    local toggle_dotfiles = function()
      show_dotfiles = not show_dotfiles
      local new_filter = show_dotfiles and filter_show or filter_hide
      require("mini.files").refresh({ content = { filter = new_filter } })
    end

    local map_split = function(buf_id, lhs, direction, close_on_file)
      local rhs = function()
        local new_target_window
        local cur_target_window = require("mini.files").get_explorer_state().target_window
        if cur_target_window ~= nil then
          vim.api.nvim_win_call(cur_target_window, function()
            vim.cmd("belowright " .. direction .. " split")
            new_target_window = vim.api.nvim_get_current_win()
          end)

          require("mini.files").set_target_window(new_target_window)
          require("mini.files").go_in({ close_on_file = close_on_file })
        end
      end

      local desc = "Open in " .. direction .. " split"
      if close_on_file then
        desc = desc .. " and close"
      end
      vim.keymap.set("n", lhs, rhs, { buffer = buf_id, desc = desc })
    end

    local files_set_cwd = function()
      local cur_entry_path = MiniFiles.get_fs_entry().path
      local cur_directory = vim.fs.dirname(cur_entry_path)
      if cur_directory ~= nil then
        vim.fn.chdir(cur_directory)
      end
    end

		local current_folder = function(path)
			local trimmedPath = path:match("(.+)/[^/]*$")
			return trimmedPath
		end

		local reopen_mini_files = function(original_win_id, path)
			-- Switch back to the original window
			vim.api.nvim_set_current_win(original_win_id)
			-- Reopen mini.files in the original window with the given path
			MiniFiles.open(path, true)
			-- Move focus back to the new window (grug_far)
			--    local key = nvim_replace_termcodes("<leader>l", true, false, true)
			-- vim.api.nvim_feedkeys(key, "n", false)
		end

		local grep_in_folder = function()
			-- get the current directory
			-- local current_dir = vim.fs.dirname(MiniFiles.get_fs_entry().path)
			local current_dir = current_folder(MiniFiles.get_fs_entry().path)
			local prefills = { paths = current_dir }

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

			-- local win_id = vim.api.nvim_get_current_win()
			-- local path = vim.api.nvim_buf_get_name(0)
			-- reopen_mini_files(win_id, path)
		end

		local grep_in_selected_folder = function()
			-- get the current directory
			-- local current_dir = vim.fs.dirname(MiniFiles.get_fs_entry().path)
			local current_dir = MiniFiles.get_fs_entry().path
			local prefills = { paths = current_dir }

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
		end

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesBufferCreate",
      callback = function(args)
        local buf_id = args.data.buf_id

        vim.keymap.set(
          "n",
          opts.mappings and opts.mappings.toggle_hidden or "g.",
          toggle_dotfiles,
          { buffer = buf_id, desc = "Toggle hidden files" }
        )

        vim.keymap.set(
          "n",
          opts.mappings and opts.mappings.change_cwd or "gc",
          files_set_cwd,
          { buffer = buf_id, desc = "Set cwd" }
        )

				vim.keymap.set(
					"n",
					opts.mappings and opts.mappings.change_cwd or "gs",
					grep_in_folder,
					{ buffer = buf_id, desc = "[G]rep in folder" }
				)

				vim.keymap.set(
					"n",
					opts.mappings and opts.mappings.change_cwd or "gS",
					grep_in_selected_folder,
					{ buffer = buf_id, desc = "[G]rep in selected folder" }
				)

        map_split(buf_id, opts.mappings and opts.mappings.go_in_horizontal or "<C-b>", "horizontal", false)
        map_split(buf_id, opts.mappings and opts.mappings.go_in_vertical or "<C-v>", "vertical", false)
        map_split(buf_id, opts.mappings and opts.mappings.go_in_horizontal_plus or "<C-w>S", "horizontal", true)
        map_split(buf_id, opts.mappings and opts.mappings.go_in_vertical_plus or "<C-w>V", "vertical", true)
      end,
    })

		-- vim.api.nvim_create_autocmd("VimEnter", {
		-- 	callback = function()
		--       require("mini.files").open(nil, false)
		-- 	end,
		-- })

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesActionRename",
      callback = function(event)
        LazyVim.lsp.on_rename(event.data.from, event.data.to)
      end,
    })
  end,
}
