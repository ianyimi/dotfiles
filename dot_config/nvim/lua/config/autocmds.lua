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

-- Detect files changed outside nvim (agents, CLI tools, git) and reload them.
-- Triggers on: window focus, terminal close/leave, cursor idle (updatetime=250ms).
--
-- Bare ":checktime" only reaches buffers currently displayed in a window, so an
-- agent rewriting 9 files you have open-but-hidden would leave all 9 stale and
-- their undo trees would die at exit (nvim keys persistent undo to a hash of the
-- file contents, so a stale undofile is silently discarded on next open). The
-- per-buffer ":checktime {buf}" form has no window requirement, so every loaded
-- buffer absorbs the external change as an undo state via 'undoreload' and gets
-- its undofile rewritten -- no visiting required.
--
-- Files nvim has never loaded are still invisible here; nothing can preserve
-- history for those, because the hash mismatch happens before nvim sees them.
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave", "CursorHold", "CursorHoldI" }, {
	group = augroup("checktime"),
	callback = function()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			-- Real files only: skip terminals, oil://, quickfix, and other scratch buffers.
			if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == ""
				and vim.api.nvim_buf_get_name(buf) ~= "" then
				pcall(vim.cmd, "checktime " .. buf)
			end
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

-- External file changes (agents, CLI formatters, git checkout) always win.
--
-- Without this handler nvim leaves a locally-modified buffer stale on conflict
-- and, because merely registering a FileChangedShell autocmd suppresses the
-- default action, shows no W12 warning either. Setting v:fcs_choice restores an
-- explicit policy: take the version on disk.
--
-- No undo history is lost. 'undoreload' (options.lua) files the pre-reload
-- buffer as an undo state, so unsaved work is one `u` away, and nvim rewrites
-- the undofile on reload so the tree survives into the next session.
--
-- Unmodified buffers never reach here -- 'autoread' reloads them and only
-- FileChangedShellPost fires. Detection requires the file to be open in a
-- loaded buffer; see the checktime autocmd above.
vim.api.nvim_create_autocmd("FileChangedShell", {
	group = augroup("reload_on_external_change"),
	callback = function()
		-- "deleted" cannot be reloaded; leave the buffer as the last copy of the file.
		if vim.v.fcs_reason ~= "deleted" then
			vim.v.fcs_choice = "reload"
		end
	end,
})

-- Prevent Neovim from creating built-in LSP gr* mappings
vim.api.nvim_create_autocmd('User', {
	pattern = 'VeryLazy',
	callback = function()
		-- Remove all built-in LSP gr* keymaps to avoid conflicts
		local gr_maps = { 'gra', 'gri', 'grn', 'grr', 'grt', 'grx' } -- Added grx (codelens)
		for _, map in ipairs(gr_maps) do
			pcall(vim.cmd.vunmap, map)
			pcall(vim.cmd.unmap, map)
			pcall(vim.keymap.del, 'n', map, { silent = true })
		end
		-- Silently clean up conflicting keymaps (no notification needed)
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
				-- safe_buf_delete now handles gitsigns detachment automatically
				LazyVim.safe_buf_delete(empty_buf, { force = true })
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
		-- safe_buf_delete now handles gitsigns detachment automatically
		LazyVim.safe_buf_delete(empty_buf, { force = true })
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

-- Track MRU (Most Recently Used) files - completely custom, ignoring v:oldfiles
_G.__mru_files = _G.__mru_files or {}

-- Update MRU when entering a buffer
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
	group = augroup("track_mru_enter"),
	callback = function(ev)
		pcall(function()
			local bt = vim.api.nvim_get_option_value("buftype", { buf = ev.buf })
			if bt ~= "" then return end
			local ft = vim.api.nvim_get_option_value("filetype", { buf = ev.buf })
			if ft == "oil" or ft == "alpha" or ft == "lazy" then return end
			local name = vim.api.nvim_buf_get_name(ev.buf)
			if name and name ~= "" and vim.fn.filereadable(name) == 1 then
				local fullpath = vim.fn.fnamemodify(name, ":p")
				-- Remove if already exists (we'll re-add at front)
				for i, path in ipairs(_G.__mru_files) do
					if path == fullpath then
						table.remove(_G.__mru_files, i)
						break
					end
				end
				-- Insert at front
				table.insert(_G.__mru_files, 1, fullpath)
				-- Keep list manageable (max 200 files for good history)
				if #_G.__mru_files > 200 then
					table.remove(_G.__mru_files)
				end
			end
		end)
	end,
})

-- Track buffer close to ensure closed files go to front of MRU
vim.api.nvim_create_autocmd("BufDelete", {
	group = augroup("track_mru_close"),
	callback = function(ev)
		pcall(function()
			local bt = vim.api.nvim_get_option_value("buftype", { buf = ev.buf })
			if bt ~= "" then return end
			local name = vim.api.nvim_buf_get_name(ev.buf)
			if name and name ~= "" and vim.fn.filereadable(name) == 1 then
				local fullpath = vim.fn.fnamemodify(name, ":p")
				-- Remove from MRU if exists
				for i, path in ipairs(_G.__mru_files) do
					if path == fullpath then
						table.remove(_G.__mru_files, i)
						break
					end
				end
				-- Re-add at front (most recently closed = most recently used)
				table.insert(_G.__mru_files, 1, fullpath)
			end
		end)
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

-- Auto-restart LSP when type definition files change
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
	group = augroup("lsp_restart_on_types"),
	pattern = { "*.d.ts", "tsconfig.json", "jsconfig.json", "payload-types.ts" },
	callback = function(ev)
		local filepath = vim.api.nvim_buf_get_name(ev.buf)

		-- Don't restart LSP for config files (avoid breaking keybinds while editing config)
		if filepath:match("/.config/nvim/") or filepath:match("/%.local/share/chezmoi/") then
			return
		end

		vim.notify("Type definitions updated, restarting TypeScript LSP and ESLint...", vim.log.levels.INFO)

		-- Only restart TypeScript-related LSP clients and ESLint, not all clients
		-- This preserves keybinds for other language servers
		local ts_clients = { "ts_ls", "tsserver", "vtsls", "typescript-language-server", "eslint" }
		local restarted = false
		for _, client in ipairs(vim.lsp.get_clients()) do
			if vim.tbl_contains(ts_clients, client.name) then
				vim.cmd("LspRestart " .. client.id)
				restarted = true
			end
		end

		-- After restart, trigger LspAttach to ensure keymaps are restored
		-- The LspAttach autocmd in nvim-lspconfig.lua will handle the actual restoration
		if restarted then
			vim.defer_fn(function()
				-- Force a buffer update to trigger LspAttach
				vim.cmd("doautocmd User LspRestarted")
			end, 500)
		end
	end,
})

-- Payload type watcher setup
local payload_type_watchers = {}

-- Cleanup function to stop all timers
local function cleanup_payload_watchers()
	for path, timer in pairs(payload_type_watchers) do
		if timer then
			pcall(timer.stop, timer)
			pcall(timer.close, timer)
		end
		payload_type_watchers[path] = nil
	end
end

-- Fast check for specific file paths (no globbing)
local function find_payload_file(filename)
	local cwd = vim.fn.getcwd()
	local uv = vim.loop

	-- Common locations for Payload CMS files (checked in order of likelihood)
	local locations = {
		cwd .. "/" .. filename,      -- ./payload-types.ts
		cwd .. "/src/" .. filename,  -- ./src/payload-types.ts
		cwd .. "/app/" .. filename,  -- ./app/payload-types.ts (Next.js app dir)
		cwd .. "/server/" .. filename, -- ./server/payload-types.ts
	}

	for _, path in ipairs(locations) do
		local stat = uv.fs_stat(path)
		if stat and stat.type == "file" then
			return path
		end
	end

	return nil
end

local function setup_payload_type_watcher()
	-- First check if payload.config.ts exists in project (fast check)
	local payload_config = find_payload_file("payload.config.ts")
	if not payload_config then
		return -- No payload project detected
	end

	-- Find payload-types.ts in common locations
	local payload_types = find_payload_file("payload-types.ts")
	if not payload_types then
		return -- No types file to watch
	end

	-- Don't create duplicate watchers
	if payload_type_watchers[payload_types] then
		return
	end

	local uv = vim.loop

	-- Track last modification time and last restart time
	local last_mtime = vim.fn.getftime(payload_types)
	local last_restart = 0

	-- Use a timer to poll the file for changes
	local timer = uv.new_timer()
	if not timer then return end

	timer:start(0, 1000, vim.schedule_wrap(function() -- Check every 1 second
		local current_mtime = vim.fn.getftime(payload_types)
		local now = vim.loop.now()

		-- If file was modified and enough time has passed since last restart
		if current_mtime > last_mtime and (now - last_restart) > 2000 then
			last_mtime = current_mtime
			last_restart = now

			vim.notify("Payload types changed, restarting TypeScript LSP and ESLint...", vim.log.levels.INFO)

			-- Only restart TypeScript-related LSP clients and ESLint
			local ts_clients = { "ts_ls", "tsserver", "vtsls", "typescript-language-server", "eslint" }
			local restarted = false
			for _, client in ipairs(vim.lsp.get_clients()) do
				if vim.tbl_contains(ts_clients, client.name) then
					vim.cmd("LspRestart " .. client.id)
					restarted = true
				end
			end

			-- After restart, trigger LspAttach to ensure keymaps are restored
			if restarted then
				vim.defer_fn(function()
					vim.cmd("doautocmd User LspRestarted")
				end, 500)
			end
		end
	end))

	payload_type_watchers[payload_types] = timer
	vim.notify("Watching " .. vim.fn.fnamemodify(payload_types, ":~:.") .. " for changes", vim.log.levels.INFO)
end

-- Set up watcher on VimEnter
vim.api.nvim_create_autocmd("VimEnter", {
	group = augroup("setup_payload_watcher"),
	callback = function()
		-- Run on next tick without blocking (file finding is now instant)
		vim.schedule(function()
			setup_payload_type_watcher()
		end)
	end,
})

-- Also try to set up watcher when changing directories
vim.api.nvim_create_autocmd("DirChanged", {
	group = augroup("setup_payload_watcher_on_cd"),
	callback = function()
		vim.schedule(function()
			-- Clean up old watchers before setting up new ones
			cleanup_payload_watchers()
			setup_payload_type_watcher()
		end)
	end,
})

-- Clean up timers on Neovim exit
vim.api.nvim_create_autocmd("VimLeavePre", {
	group = augroup("cleanup_payload_watchers"),
	callback = function()
		cleanup_payload_watchers()
	end,
})

-- Enhanced filetype detection for shell and config files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufEnter" }, {
	group = augroup("enhanced_filetype_detection"),
	pattern = "*",
	callback = function(args)
		local filename = vim.fn.expand("%:t")
		local filepath = vim.fn.expand("%:p")



		-- Explicit chezmoi file detection
		if filename == "dot_zshrc" then
			vim.bo[args.buf].filetype = "zsh"
			return
		elseif filename == "dot_bashrc" then
			vim.bo[args.buf].filetype = "bash"
			return
		elseif filename == "dot_profile" or filename == "dot_bash_profile" then
			vim.bo[args.buf].filetype = "bash"
			return
		end

		-- General shell file patterns
		if filename:match("%.zsh$") or filename:match("zshrc") or filename:match("zprofile") then
			vim.bo[args.buf].filetype = "zsh"
		elseif filename:match("%.sh$") or filename:match("%.bash$") or filename:match("bashrc") or filename:match("bash_profile") or filename:match("profile") then
			vim.bo[args.buf].filetype = "bash"
		elseif filename:match("%.fish$") then
			vim.bo[args.buf].filetype = "fish"
		elseif filename:match("%.env") or filename:match("^%.env") then
			vim.bo[args.buf].filetype = "sh"
		elseif filename:match("%.ini$") or filename:match("%.conf$") or filename:match("%.config$") or filename:match("%.cfg$") then
			vim.bo[args.buf].filetype = "ini"
		elseif filename:match("^dot_") then
			-- General chezmoi dotfiles - detect by suffix
			local suffix = filename:match("^dot_(.+)$")
			if suffix then
				if suffix:match("zsh") then
					vim.bo[args.buf].filetype = "zsh"
				elseif suffix:match("bash") then
					vim.bo[args.buf].filetype = "bash"
				elseif suffix:match("gitconfig") then
					vim.bo[args.buf].filetype = "gitconfig"
				elseif suffix:match("vimrc") or suffix:match("nvimrc") then
					vim.bo[args.buf].filetype = "vim"
				else
					vim.bo[args.buf].filetype = "conf"
				end
			end
		end
	end,
})

-- Advertise this nvim instance so external tools can reach it.
-- Writes $TMPDIR/nvim-undo/<pid> — line 1 cwd, line 2 v:servername — removed on VimLeavePre.
-- Every nvim already listens on msgpack-RPC (v:servername is always populated), so nothing is
-- started here; the file only makes an existing socket discoverable. Agent tool-call hooks read
-- it to find this instance and call LazyVim.undo.hold() before writing a file.
--
-- The group id is created ONCE and reused: augroup() passes clear = true, so calling it a
-- second time for the same name deletes the autocmd registered by the first call. Registering
-- both of these through separate augroup() calls silently left only VimLeavePre behind.
local undo_guard_group = augroup("undo_guard_advertise")

vim.api.nvim_create_autocmd("VimEnter", {
	group = undo_guard_group,
	callback = function()
		LazyVim.undo.advertise()
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	group = undo_guard_group,
	callback = function()
		LazyVim.undo.unadvertise()
	end,
})

-- Windowed startup preload: arms LazyVim.undo's 7-day candidate sweep so undo history for
-- git checkout, `prettier --write .`, npm install, codegen, and xd://ast_edit rewrites keeps
-- accumulating the same way tool-call-hook holds do -- none of those pass through a hooked
-- tool, and a manual `git checkout` in a tmux pane has no agent involved at all. Deferred 2s
-- past VimEnter so it never touches startup time; skipped for $HOME and "/" so a bare `nvim`
-- outside a real project doesn't walk the whole undo store for nothing.
vim.api.nvim_create_autocmd("VimEnter", {
	group = augroup("undo_guard_preload"),
	callback = function()
		local cwd = vim.uv.cwd()
		if not cwd or cwd == vim.env.HOME or cwd == "/" then
			return
		end
		vim.defer_fn(function()
			LazyVim.undo.arm()
		end, 2000)
	end,
})

-- UndoGuardHold: preemptively load a file to protect its undo history from external edits.
-- Delegates to lua/util/undo.lua. The previous inline implementation called vim.fn.bufload
-- OUTSIDE its pcall, so a throw left eventignore="all" set for the rest of the session,
-- silently disabling every autocmd (LSP attach, checktime, format-on-save). The module
-- restores eventignore and swapfile unconditionally instead.
vim.api.nvim_create_user_command("UndoGuardHold", function(opts)
	local ok, status = pcall(LazyVim.undo.hold, opts.args)
	if ok and status and vim.in_fast_event() == false then
		LazyVim.info("UndoGuardHold: " .. status, { title = "LazyVim" })
	end
end, {
	nargs = 1,
	complete = "file",
})
