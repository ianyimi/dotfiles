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
				vim.notify("updated directory")
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
	pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
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
