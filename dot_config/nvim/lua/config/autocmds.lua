-- Add any additional autocmds here

local function augroup(name)
	return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

-- cd into directory given in cli params
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		for _, arg in ipairs(vim.v.argv) do
			-- Check if the argument is a directory
			local stat = vim.loop.fs_stat(arg)
			if stat and stat.type == "directory" then
				-- Change the current working directory to the first directory argument
				vim.cmd("cd " .. arg)
				-- removed noisy startup notify
				return
			end
		end
	end,
})

-- stop telescope from going into insert mode on close
vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
	callback = function(event)
		if vim.bo[event.buf].filetype == "TelescopePrompt" then
			vim.api.nvim_exec2("silent! stopinsert!", {})
		end
	end,
})

-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
	group = augroup("checktime"),
	callback = function()
		if vim.o.buftype ~= "nofile" then
			vim.cmd("checktime")
		end
	end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
	group = augroup("highlight_yank"),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
	group = augroup("resize_splits"),
	callback = function()
		local current_tab = vim.fn.tabpagenr()
		vim.cmd("tabdo wincmd =")
		vim.cmd("tabnext " .. current_tab)
	end,
})

-- go to last loc when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup("last_loc"),
	callback = function(event)
		local exclude = { "gitcommit" }
		local buf = event.buf
		if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
			return
		end
		vim.b[buf].lazyvim_last_loc = true
		local mark = vim.api.nvim_buf_get_mark(buf, '"')
		local lcount = vim.api.nvim_buf_line_count(buf)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- wrap and check for spell in text filetypes
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("wrap_spell"),
	pattern = { "text", "plaintex", "typst", "gitcommit", "markdown", "mdx", "markdown.mdx" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.spell = true
	end,
})

-- Fix conceallevel for json files
vim.api.nvim_create_autocmd({ "FileType" }, {
	group = augroup("json_conceal"),
	pattern = { "json", "jsonc", "json5" },
	callback = function()
		vim.opt_local.conceallevel = 0
	end,
})

vim.filetype.add({
	pattern = {
		[".*"] = {
			function(path, buf)
				return vim.bo[buf]
						and vim.bo[buf].filetype ~= "bigfile"
						and path
						and vim.fn.getfsize(path) > vim.g.bigfile_size
						and "bigfile"
						or nil
			end,
		},
	},
})

vim.api.nvim_create_autocmd({ "FileType" }, {
	group = augroup("bigfile"),
	pattern = "bigfile",
	callback = function(ev)
		vim.b.minianimate_disable = true
		vim.schedule(function()
			vim.bo[ev.buf].syntax = vim.filetype.match({ buf = ev.buf }) or ""
		end)
	end,
})

--  e.g. ~/.local/share/chezmoi/*
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { os.getenv("HOME") .. "/.local/share/chezmoi/*" },
	callback = function(ev)
		local bufnr = ev.buf
		local edit_watch = function()
			require("chezmoi.commands.__edit").watch(bufnr)
		end
		vim.schedule(edit_watch)
	end,
})

-- Prevent Neovim from creating built-in LSP gr* mappings
vim.api.nvim_create_autocmd('User', {
	pattern = 'VeryLazy',
	callback = function()
		pcall(vim.cmd.vunmap, 'gra')
		pcall(vim.cmd.unmap, 'gra')
		pcall(vim.cmd.unmap, 'gri')
		pcall(vim.cmd.unmap, 'grn')
		pcall(vim.cmd.unmap, 'grr')
		pcall(vim.cmd.unmap, 'grt')
	end
})

-- Shared buffer validation logic
local function get_buffer_state()
	local buffers = vim.api.nvim_list_bufs()
	local valid_buffers = {}
	local oil_buffers = {}
	
	for _, buf in ipairs(buffers) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
			local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
			
			if buftype == "" then
				if filetype == "oil" then
					table.insert(oil_buffers, buf)
				else
					table.insert(valid_buffers, buf)
				end
			end
		end
	end
	
	return valid_buffers, oil_buffers
end

-- Function to check if we should open oil
local function should_open_oil()
	local valid_buffers, oil_buffers = get_buffer_state()
	
	-- If we have exactly one valid buffer left and it's empty/unnamed
	if #valid_buffers == 1 and #oil_buffers == 0 then
		local remaining_buf = valid_buffers[1]
		local buf_name = vim.api.nvim_buf_get_name(remaining_buf)
		local line_count = vim.api.nvim_buf_line_count(remaining_buf)
		local first_line = vim.api.nvim_buf_get_lines(remaining_buf, 0, 1, false)[1] or ""
		
		-- Check if buffer is empty (no name, only one line, and first line is empty)
		if buf_name == "" and line_count == 1 and first_line == "" then
			return remaining_buf
		end
	end
	return nil
end

-- Hook into buffer close events with immediate response
vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
	group = augroup("oil_auto_open"),
	callback = function()
		-- Add a small delay to let other autocmds complete
		vim.defer_fn(function()
			local empty_buf = should_open_oil()
			if empty_buf then
				pcall(vim.api.nvim_buf_delete, empty_buf, { force = true })
				pcall(require("oil").open)
				-- Mark this oil instance as non-closable (after closing all buffers)
				vim.schedule(function()
					local oil_buf = vim.api.nvim_get_current_buf()
					local ok, filetype = pcall(vim.api.nvim_get_option_value, "filetype", { buf = oil_buf })
					if ok and filetype == "oil" then
						vim.b[oil_buf].oil_allow_close = false
					end
					
					if _G.refresh_oil_display then
						pcall(_G.refresh_oil_display)
					end
				end)
			end
		end, 100)
	end,
})

-- Also create a command for manual triggering
vim.api.nvim_create_user_command("OpenOilIfEmpty", function()
	local empty_buf = should_open_oil()
	if empty_buf then
		vim.api.nvim_buf_delete(empty_buf, { force = true })
		require("oil").open()
		-- Mark this oil instance as non-closable (after closing all buffers)
		vim.schedule(function()
			local oil_buf = vim.api.nvim_get_current_buf()
			local ok, filetype = pcall(vim.api.nvim_get_option_value, "filetype", { buf = oil_buf })
			if ok and filetype == "oil" then
				vim.b[oil_buf].oil_allow_close = false
			end
			
			if _G.refresh_oil_display then
				_G.refresh_oil_display()
			end
		end)
	else
		vim.notify("Not in empty buffer state")
	end
end, { desc = "Open oil if in empty buffer state" })

-- Set oil closability on startup based on harpoon files
vim.api.nvim_create_autocmd("VimEnter", {
	group = augroup("oil_startup_closable"),
	callback = function()
		-- Check if oil opened as default file explorer (no files specified)
		if vim.fn.argc() == 0 then
			vim.schedule(function()
				local oil_buf = vim.api.nvim_get_current_buf()
				local ok, filetype = pcall(vim.api.nvim_get_option_value, "filetype", { buf = oil_buf })
				if ok and filetype == "oil" then
					-- Check if there are harpoon files available
					local has_harpoon_files = false
					local harpoon_ok, harpoon = pcall(require, "harpoon")
					if harpoon_ok then
						local list_ok, harpoon_list = pcall(function() return harpoon:list() end)
						if list_ok and harpoon_list and harpoon_list:length() > 0 then
							for i = 1, harpoon_list:length() do
								local item = harpoon_list.items[i]
								if item and item.value and item.value ~= "" then
									local file_path = item.value
									if not file_path:match("^/") then
										file_path = vim.fn.getcwd() .. "/" .. file_path
									end
									if vim.fn.filereadable(file_path) == 1 then
										has_harpoon_files = true
										break
									end
								end
							end
						end
					end
					
					-- Set closability based on harpoon files
					vim.b[oil_buf].oil_allow_close = has_harpoon_files
				end
			end)
		end
	end,
})

-- Prevent closing oil based on context
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("oil_prevent_close"),
	pattern = "oil",
	callback = function(ev)
		-- Override oil's close keymaps with a check
		local function safe_oil_close()
			local allow_close = vim.b[ev.buf].oil_allow_close
			
			if allow_close == false then
				-- Oil opened after closing all buffers - not closable
				vim.notify("Cannot close oil - no other files open", vim.log.levels.WARN)
			elseif allow_close == true then
				-- Oil opened on startup - check if there are harpoon files
				local has_harpoon_files = false
				local harpoon_ok, harpoon = pcall(require, "harpoon")
				if harpoon_ok then
					local list_ok, harpoon_list = pcall(function() return harpoon:list() end)
					if list_ok and harpoon_list and harpoon_list:length() > 0 then
						for i = 1, harpoon_list:length() do
							local item = harpoon_list.items[i]
							if item and item.value and item.value ~= "" then
								local file_path = item.value
								if not file_path:match("^/") then
									file_path = vim.fn.getcwd() .. "/" .. file_path
								end
								if vim.fn.filereadable(file_path) == 1 then
									has_harpoon_files = true
									break
								end
							end
						end
					end
				end
				
				if has_harpoon_files then
					require("oil.actions").close.callback()
				else
					vim.notify("Cannot close oil - no files to switch to", vim.log.levels.WARN)
				end
			else
				-- Oil opened via toggle_float - always allow closing
				require("oil.actions").close.callback()
			end
		end
		
		-- Override the close keymaps for this oil buffer
		vim.keymap.set("n", "q", safe_oil_close, { buffer = ev.buf, desc = "Close oil (protected)" })
		vim.keymap.set("n", "<Esc>", safe_oil_close, { buffer = ev.buf, desc = "Close oil (protected)" })
	end,
})





-- -- Autocommand to enable paste mode when exiting visual block mode
-- vim.api.nvim_create_autocmd("VisualLeave", {
--   group = augroup("PasteInVisualBlock"),
--   pattern = "*",
--   callback = function()
--     -- Enable 'paste' mode if exiting visual block mode
--     if vim.fn.mode() == "\22" then  -- "\22" is the code for visual block mode
--       vim.opt.paste = true
--     end
--   end,
-- })
--
-- -- Autocommand to disable paste mode when entering insert mode
-- vim.api.nvim_create_autocmd("InsertEnter", {
--   group = augroup("PasteInVisualBlock"),
--   pattern = "*",
--   callback = function()
--     -- Disable 'paste' mode when entering insert mode
--     vim.opt.paste = false
--   end,
-- })
