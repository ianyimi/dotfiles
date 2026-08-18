return {
	"romgrk/barbar.nvim",
	enabled = true,
	event = "VeryLazy",
	dependencies = { "ThePrimeagen/harpoon" },
	keys = {
		-- Buffer navigation keymaps (equivalent to bufferline keymaps)
		{ "<S-h>", "<Cmd>BufferPrevious<CR>", desc = "Previous Buffer" },
		{ "<S-l>", "<Cmd>BufferNext<CR>",     desc = "Next Buffer" },
		-- Buffer movement keymaps (equivalent to bufferline keymaps)
		{
			"<C-h>",
			function()
				vim.cmd("BufferMovePrevious")
				vim.schedule(function()
					if _G.update_harpoon_from_buffer_order then
						_G.update_harpoon_from_buffer_order()
					end
				end)
			end,
			desc = "Move Buffer Left"
		},
		{
			"<C-l>",
			function()
				vim.cmd("BufferMoveNext")
				vim.schedule(function()
					if _G.update_harpoon_from_buffer_order then
						_G.update_harpoon_from_buffer_order()
					end
				end)
			end,
			desc = "Move Buffer Right"
		},
		-- Additional barbar-specific keymaps for parity with bufferline
		{ "<leader>bp", "<Cmd>BufferPin<CR>",               desc = "Toggle Pin" },
		{ "<leader>X",  "<Cmd>BufferCloseBuffersRight<CR>", desc = "Delete Buffers to the Right" },
		{ "<leader>Z",  "<Cmd>BufferCloseBuffersLeft<CR>",  desc = "Delete Buffers to the Left" },
	},
	config = function()
		local barbar = require("barbar")
		local state = require("barbar.state")
		local render = require("barbar.ui.render")
		local harpoon = require("harpoon")

		-- Patch barbar's API to handle animation errors gracefully
		local api = require("barbar.api")
		local original_move_buffer_animated_tick = api.move_buffer_animated_tick
		api.move_buffer_animated_tick = function(...)
			-- Wrap the animation tick in pcall to suppress nil arithmetic errors
			local success, result = pcall(original_move_buffer_animated_tick, ...)
			if not success then
				-- Error occurred, but buffer still moved (just without animation)
				-- Silently ignore the animation error
				return
			end
			return result
		end

		barbar.setup({
			auto_hide = false, -- Never hide tabline, even with single buffer
			hide = {
				inactive = false,
			},
			highlight_visible = false, -- Show both current and visible buffers with different highlights
			icons = {
				pinned = { filename = true, buffer_index = true },
				diagnostics = { { enabled = true } },
			},
			maximum_length = 30, -- Allow longer names for unique paths
		})

		local function unpin_all()
			for _, buf in ipairs(state.buffers) do
				local data = state.get_buffer_data(buf)
				data.pinned = false
			end
		end

		local function get_buffer_by_mark(mark)
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				-- Skip invalid buffers
				if not vim.api.nvim_buf_is_valid(buf) then
					goto continue
				end

				local ok, buffer_path = pcall(vim.api.nvim_buf_get_name, buf)
				if not ok then
					goto continue
				end

				if buffer_path == "" or mark.value == "" then
					goto continue
				end

				local mark_pattern = mark.value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
				if string.match(buffer_path, mark_pattern) then
					return buf
				end

				local buffer_path_pattern = buffer_path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
				if string.match(mark.value, buffer_path_pattern) then
					return buf
				end

				::continue::
			end
		end

		-- Track if we're currently updating to prevent loops
		local updating_harpoon = false

		local function refresh_all_harpoon_tabs()
			if updating_harpoon then return end
			if _G._bench then _G._bench("harpoon refresh start") end

			local ok, list = pcall(function()
				return harpoon:list()
			end)
			if not ok or not list then
				if _G._bench then _G._bench("harpoon refresh skip: no list") end
				return
			end
			unpin_all()

			for i = 1, list:length() do
				local mark = list.items[i]
				if mark == nil or mark.value == "" then
					goto continue
				end

				local buf = get_buffer_by_mark(mark)
				if buf == nil then
					-- Use the path format from harpoon when creating buffer
					local buffer_path = mark.value
					-- If the harpoon path is relative and doesn't start with /, treat as relative
					if not buffer_path:match("^/") then
						-- Keep as relative path
						vim.cmd("badd " .. vim.fn.fnameescape(buffer_path))
					else
						-- Use absolute path
						vim.cmd("badd " .. vim.fn.fnameescape(buffer_path))
					end
					buf = get_buffer_by_mark(mark)
				end
				if buf ~= nil then
					state.toggle_pin(buf)
				end

				::continue::
			end
			render.update()
			if _G._bench then _G._bench("harpoon refresh end") end
		end

		-- Function to update harpoon list based on current buffer order
		local function update_harpoon_from_buffer_order()
			updating_harpoon = true

			local ok, harpoon_list = pcall(function()
				return harpoon:list()
			end)
			if not ok or not harpoon_list then
				updating_harpoon = false
				-- Fire event so others can refresh
				vim.api.nvim_exec_autocmds("User", { pattern = "HarpoonListChanged" })
				return
			end

			-- Get current pinned buffers in order
			local pinned_buffers = {}
			for _, buf in ipairs(state.buffers) do
				-- Skip invalid buffers
				if not vim.api.nvim_buf_is_valid(buf) then
					goto continue
				end

				local data = state.get_buffer_data(buf)
				if data and data.pinned then
					local ok, buf_path = pcall(vim.api.nvim_buf_get_name, buf)
					if ok and buf_path ~= "" then
						table.insert(pinned_buffers, buf_path)
					end
				end

				::continue::
			end

			-- Update harpoon list to match pinned buffer order
			local new_items = {}
			for _, buf_path in ipairs(pinned_buffers) do
				-- Find this buffer in the harpoon list
				for _, item in ipairs(harpoon_list.items) do
					if item and vim.fn.fnamemodify(item.value, ":p") == vim.fn.fnamemodify(buf_path, ":p") then
						table.insert(new_items, item)
						break
					end
				end
			end

			-- Update harpoon list
			harpoon_list.items = new_items
			harpoon_list._length = #new_items

			updating_harpoon = false
		end

		-- Function to create unique buffer names for duplicate filenames.
		--
		-- barbar calls this once per rendered tab, so the previous implementation -- which scanned
		-- every LOADED buffer and ran a vimscript fnamemodify() per iteration -- cost
		-- tabs x loaded_buffers of work on every render. That degraded as a session accumulated
		-- buffers (profiled: 96 of the samples in an 87ms oil stall landed on this function, with
		-- 5617 renders in one session), and it got worse once undo-guard started keeping files
		-- loaded. Now: one getbufinfo() per change, memoized, with the basename taken by pattern
		-- match instead of a vimscript call. Measured 0.809ms -> 0.074ms per render at 116 loaded
		-- buffers, 20 tabs.
		--
		-- Only LISTED buffers are considered, which is also more correct: barbar renders listed
		-- buffers, so an unlisted one can never collide for a tab label. The displayed name is
		-- unchanged for every case that can actually appear in the tabline.
		local _basename_paths = nil
		local _parts_by_path = {}

		local function invalidate_unique_names()
			_basename_paths = nil
			_parts_by_path = {}
		end

		local function listed_paths_by_basename()
			if _basename_paths then
				return _basename_paths
			end
			local map = {}
			for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
				local name = info.name
				if name ~= "" then
					local base = name:match("[^/]*$")
					local bucket = map[base]
					if bucket then
						bucket[#bucket + 1] = name
					else
						map[base] = { name }
					end
				end
			end
			_basename_paths = map
			return map
		end

		local function path_parts(path)
			local parts = _parts_by_path[path]
			if not parts then
				parts = vim.split(path, "/")
				_parts_by_path[path] = parts
			end
			return parts
		end

		local function get_unique_name(buf_path)
			if buf_path == "" then return "[No Name]" end

			local filename = buf_path:match("[^/]*$")
			local same_name_buffers = listed_paths_by_basename()[filename]

			-- Only one buffer with this filename (or it is not listed): just the filename.
			if not same_name_buffers or #same_name_buffers <= 1 then
				return filename
			end

			-- Find the minimal distinguishing path: same algorithm as before, but the split of
			-- each candidate is memoised for the lifetime of the buffer list.
			local parts = path_parts(buf_path)
			for count = 1, #parts do
				local partial_path = table.concat(vim.list_slice(parts, -count), "/")
				local is_unique = true

				for _, other_path in ipairs(same_name_buffers) do
					if other_path ~= buf_path then
						local other_parts = path_parts(other_path)
						if table.concat(vim.list_slice(other_parts, -count), "/") == partial_path then
							is_unique = false
							break
						end
					end
				end

				if is_unique then
					return partial_path
				end
			end

			return buf_path
		end

		-- Coalesced re-render. Every reactive refresh goes through this instead of calling
		-- render.update() directly: one oil directory change fires BufNew + BufEnter + BufWinEnter
		-- + WinEnter, and each of those used to trigger its own full render -- one of them the
		-- expensive render.update(true) that recomputes every tab's label. Profiled at 5617 renders
		-- (4.31ms each, 24s of CPU) before coalescing, still 2942 (6.56ms, 19.3s) after the first
		-- pass, which is the background work that stalls oil while navigating.
		--
		-- One reused timer handle (per docs/standards/lua-style/util-library.md). `update_names`
		-- sticks across a coalesced burst: if any event in the burst wanted names recomputed, the
		-- single render that follows recomputes them, so no label update is lost.
		--
		-- Window is deliberately short for interactive events (a render also repaints which tab is
		-- active, so a long delay would visibly lag buffer switching) and longer for diagnostics,
		-- which have no interactive component.
		local _render_timer = vim.uv.new_timer()
		local _render_names = false
		local function schedule_render(update_names, delay_ms)
			if update_names then
				_render_names = true
			end
			if not _render_timer then
				render.update(update_names)
				return
			end
			_render_timer:stop()
			_render_timer:start(
				delay_ms or 16,
				0,
				vim.schedule_wrap(function()
					local names = _render_names
					_render_names = false
					render.update(names)
				end)
			)
		end

		-- Refresh unique names when the buffer list changes. The memoised basename map must be
		-- dropped here too, or a new/renamed buffer would keep rendering under its old label.
		vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufWipeout", "BufFilePost", "BufEnter" }, {
			callback = function()
				invalidate_unique_names()
				schedule_render(true)
			end,
		})

		-- Replace barbar's own pure-render autocmds (events.lua:215 and :220) with coalesced
		-- equivalents. Both callbacks are nothing but a render.update call, so there is no state
		-- work to preserve -- unlike its BufDelete/BufWipeout handler, which also updates jump-mode
		-- letters and the recently-closed list and is therefore left alone.
		--
		-- This is the path that made changing directories in oil slow: oil creates a new oil://
		-- buffer per directory, so BufNew + BufEnter + BufWinEnter + WinEnter all fired, each
		-- rendering the whole tabline, one of them recomputing every tab's label.
		--
		-- VimResized is deliberately NOT in the clear list: nvim registers one autocmd entry per
		-- event, so barbar's own handler survives for it and a window resize still repaints
		-- immediately instead of 16ms later.
		pcall(vim.api.nvim_clear_autocmds, {
			group = "barbar_render",
			event = { "BufEnter", "BufNew", "BufWinEnter", "BufWinLeave", "BufWritePost", "TabEnter", "WinEnter", "WinLeave" },
		})
		local coalesced = vim.api.nvim_create_augroup("barbar_render_coalesced", { clear = true })
		vim.api.nvim_create_autocmd({ "BufEnter", "BufNew" }, {
			group = coalesced,
			callback = function()
				schedule_render(true)
			end,
		})
		vim.api.nvim_create_autocmd(
			{ "BufWinEnter", "BufWinLeave", "BufWritePost", "TabEnter", "WinEnter", "WinLeave" },
			{
				group = coalesced,
				callback = function()
					schedule_render()
				end,
			}
		)

		-- barbar re-renders on EVERY DiagnosticChanged (its own events.lua:242-246, unconditional).
		-- With eslint + tailwindcss + vtsls publishing across a monorepo that arrives in bursts:
		-- one profiled window held 21 DiagnosticChanged events, and the session totalled 2942
		-- render.update calls at 6.56ms each (19.3s of CPU, one render 132ms). None of it is
		-- visible as a tabline problem -- it is background work that blocks oil from painting
		-- while navigating directories.
		--
		-- Replace that handler with a coalesced one. Diagnostic counts still reach the tabline
		-- (icons.diagnostics stays enabled); they just land once per burst instead of 21 times.
		-- Deliberately mirrors upstream's vim.schedule_wrap: DiagnosticChanged is buffer-scoped,
		-- so rendering inside it would report the diagnostic's buffer as current and paint the
		-- wrong tab active.
		pcall(vim.api.nvim_clear_autocmds, { group = "barbar_render", event = "DiagnosticChanged" })
		vim.api.nvim_create_autocmd("DiagnosticChanged", {
			group = vim.api.nvim_create_augroup("barbar_diagnostics_coalesced", { clear = true }),
			callback = vim.schedule_wrap(function(event)
				-- Only listed buffers appear in the tabline, so diagnostics for anything else --
				-- including undo-guard's unlisted held buffers -- need no render at all. Upstream
				-- checks only nvim_buf_is_loaded, which is why held buffers could reach it.
				if not vim.api.nvim_buf_is_valid(event.buf) or vim.fn.buflisted(event.buf) ~= 1 then
					return
				end
				pcall(state.update_diagnostics, event.buf)
				-- 60ms: diagnostics arrive as a burst of separate scheduled callbacks, and nothing
				-- interactive waits on them, so collapse the whole burst into one render.
				schedule_render(false, 60)
			end),
		})

		-- Hook into barbar's state system to provide unique names and oil directory names
		local original_get_buffer_data = state.get_buffer_data
		state.get_buffer_data = function(buf)
			-- Always call the original function first to get the expected data structure
			local data = original_get_buffer_data(buf)

			-- If buffer is invalid, return the original data (might be nil or empty table)
			if not buf or not vim.api.nvim_buf_is_valid(buf) then
				return data
			end

			-- Only enhance with unique names if we have valid data and buffer
			if data and buf then
				-- Check if this is an oil buffer
				local ft_ok, filetype = pcall(vim.api.nvim_get_option_value, "filetype", { buf = buf })
				if ft_ok and filetype == "oil" then
					-- For oil buffers, try to get the current directory
					local oil_ok, oil = pcall(require, "oil")
					if oil_ok then
						local dir = oil.get_current_dir(buf)
						if dir then
							-- Store the directory name for display in barbar
							data.unique_name = "📁 " .. vim.fn.fnamemodify(dir, ":~")
						else
							data.unique_name = "📁 File Explorer"
						end
					else
						data.unique_name = "📁 File Explorer"
					end
				else
					-- Safely get buffer name with error handling for regular files
					local buf_ok, buf_path = pcall(vim.api.nvim_buf_get_name, buf)
					if buf_ok and buf_path and buf_path ~= "" then
						-- Store the unique name for display
						data.unique_name = get_unique_name(buf_path)
					end
				end
			end
			return data
		end

		-- Function to refresh barbar display for oil buffers
		local function refresh_oil_display()
			-- Force barbar to re-read buffer data (coalesced: oil navigation fires several events)
			schedule_render()
		end

		-- Function to clean up empty buffers
		local function cleanup_empty_buffers()
			vim.schedule(function()
				local buffers = vim.api.nvim_list_bufs()
				for _, buf in ipairs(buffers) do
					if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
						local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
						local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
						local buf_name = vim.api.nvim_buf_get_name(buf)
						local line_count = vim.api.nvim_buf_line_count(buf)
						local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""

						-- Delete empty, unnamed buffers (but not oil buffers or other special ones)
						if buftype == "" and filetype ~= "oil" and
								buf_name == "" and line_count == 1 and first_line == "" and
								vim.fn.bufwinnr(buf) == -1 then -- Not in a window
							pcall(LazyVim.safe_buf_delete, buf, { force = true })
						end
					end
				end
			end)
		end

		-- Function to handle file deletions
		local function handle_file_delete(deleted_path)
			if not deleted_path then
				return
			end

			-- Normalize the deleted path to absolute
			local deleted_path_abs = vim.fn.fnamemodify(deleted_path, ":p")
			local harpoon_list = harpoon:list()
			local deleted_buffer = nil
			local harpoon_index = nil

			-- Find the deleted file's buffer using normalized path comparison
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) then
					local ok, buf_path = pcall(vim.api.nvim_buf_get_name, buf)
					if ok and buf_path ~= "" then
						local buf_path_abs = vim.fn.fnamemodify(buf_path, ":p")
						if buf_path_abs == deleted_path_abs then
							deleted_buffer = buf
							break
						end
					end
				end
			end

			-- Find the deleted file in harpoon list using normalized paths
			for i, item in ipairs(harpoon_list.items) do
				if item and item.value ~= "" then
					local item_path_abs = vim.fn.fnamemodify(item.value, ":p")
					if item_path_abs == deleted_path_abs then
						harpoon_index = i
						break
					end
				end
			end

			-- Remove from harpoon list first
			if harpoon_index then
				table.remove(harpoon_list.items, harpoon_index)
				harpoon_list._length = #harpoon_list.items
			end

			-- Delete the buffer with force (works when not the active buffer)
			if deleted_buffer then
				pcall(LazyVim.safe_buf_delete, deleted_buffer, { force = true })
			end

			-- Fire list-changed event
			vim.api.nvim_exec_autocmds("User", { pattern = "HarpoonListChanged" })
		end

		-- Function to cleanup buffers for deleted files (not just from Oil)
		local function cleanup_deleted_file_buffers()
			vim.schedule(function()
				local buffers = vim.api.nvim_list_bufs()

				for _, buf in ipairs(buffers) do
					if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
						local buf_path = vim.api.nvim_buf_get_name(buf)

						-- Check if buffer has a file path and that file no longer exists
						if buf_path ~= "" and not vim.fn.filereadable(buf_path) then
							handle_file_delete(buf_path)
						end
					end
				end

				schedule_render()
			end)
		end

		-- Function to handle file renames
		local function handle_file_rename(old_path, new_path)
			if not old_path or not new_path or old_path == new_path then
				return
			end

			local harpoon_list = harpoon:list()
			local old_buffer = nil
			local harpoon_index = nil

			-- Find the old buffer and its position in harpoon
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) then
					local ok, buf_path = pcall(vim.api.nvim_buf_get_name, buf)
					if ok and buf_path == old_path then
						old_buffer = buf
						break
					end
				end
			end

			-- Find the old file in harpoon list
			for i, item in ipairs(harpoon_list.items) do
				if item and vim.fn.fnamemodify(item.value, ":p") == vim.fn.fnamemodify(old_path, ":p") then
					harpoon_index = i
					break
				end
			end

			-- Close the old buffer if it exists and is empty/invalid
			if old_buffer then
				-- Check if buffer has unsaved changes
				if not vim.api.nvim_buf_get_option(old_buffer, "modified") then
					pcall(LazyVim.safe_buf_delete, old_buffer, { force = true })
				end
			end

			-- Update harpoon list
			if harpoon_index then
				-- Always use relative paths to match the format of your other entries
				-- This ensures consistency with items like "tests/example.spec.ts"
				local new_harpoon_path = vim.fn.fnamemodify(new_path, ":.")

				-- Replace the old path with new path in harpoon
				harpoon_list.items[harpoon_index].value = new_harpoon_path
			end

			-- Don't call refresh_all_harpoon_tabs which might override our harpoon changes
			-- Instead, just refresh barbar directly and create the buffer with the same format as harpoon
			local new_buffer_path
			if harpoon_index then
				-- Use the path we just set in harpoon
				new_buffer_path = harpoon_list.items[harpoon_index].value
			else
				-- Fallback to relative path
				new_buffer_path = vim.fn.fnamemodify(new_path, ":.")
			end

			vim.cmd("badd " .. vim.fn.fnameescape(new_buffer_path))

			-- Get the new buffer and pin it directly
			if harpoon_index and harpoon_list.items[harpoon_index] then
				local new_buf = get_buffer_by_mark(harpoon_list.items[harpoon_index])
				if new_buf then
					state.toggle_pin(new_buf)
				end
			end

			-- Notify others that the Harpoon list changed
			vim.api.nvim_exec_autocmds("User", { pattern = "HarpoonListChanged" })
		end

		-- Update oil display when navigating directories
		vim.api.nvim_create_autocmd("User", {
			pattern = "OilEnter",
			callback = function()
				vim.schedule(function()
					refresh_oil_display()
				end)
			end,
		})

		-- Also refresh on buffer enter for oil buffers
		vim.api.nvim_create_autocmd("BufEnter", {
			callback = function()
				local ok, filetype = pcall(vim.api.nvim_get_option_value, "filetype", { buf = 0 })
				if ok and filetype == "oil" then
					vim.schedule(function()
						refresh_oil_display()
					end)
				else
					-- Clean up empty buffers when entering non-oil buffers
					cleanup_empty_buffers()
				end
			end,
		})

		-- Make functions globally accessible
		_G.update_harpoon_from_buffer_order = update_harpoon_from_buffer_order
		_G.handle_file_rename = handle_file_rename
		_G.refresh_oil_display = refresh_oil_display
		_G.cleanup_empty_buffers = cleanup_empty_buffers

		-- Debounced refresh on Harpoon list changes
		local _harpoon_refresh_timer
		local function debounced_harpoon_refresh()
			if _harpoon_refresh_timer then
				_harpoon_refresh_timer:stop()
				_harpoon_refresh_timer:close()
			end
			_harpoon_refresh_timer = vim.uv.new_timer()
			_harpoon_refresh_timer:start(100, 0, function()
				_harpoon_refresh_timer:stop()
				_harpoon_refresh_timer:close()
				_harpoon_refresh_timer = nil
				vim.schedule(function()
					pcall(refresh_all_harpoon_tabs)
					cleanup_empty_buffers()
					cleanup_deleted_file_buffers()
				end)
			end)
		end

		vim.api.nvim_create_autocmd("User", {
			pattern = "HarpoonListChanged",
			callback = function()
				if _G._bench then _G._bench("HarpoonListChanged received") end
				debounced_harpoon_refresh()
			end,
		})

		-- Additional autocmd to clean up deleted file buffers when focus returns to Neovim
		vim.api.nvim_create_autocmd({ "FocusGained", "CursorHold" }, {
			callback = function()
				cleanup_deleted_file_buffers()
			end,
		})

		-- Hook into Oil file operations
		vim.api.nvim_create_autocmd("User", {
			pattern = "OilActionsPost",
			callback = function(event)
				-- Check if operations succeeded
				if event.data.err then
					return -- Don't handle failed operations
				end

				-- Process all actions in the batch
				for _, action in ipairs(event.data.actions) do
					if action.type == "move" and action.entry_type == "file" then
						local old_path = action.src_url
						local new_path = action.dest_url

						-- Convert oil:// URLs to file paths
						if old_path:match("^oil://") then
							old_path = old_path:gsub("^oil://", "")
						end
						if new_path:match("^oil://") then
							new_path = new_path:gsub("^oil://", "")
						end

						handle_file_rename(old_path, new_path)
					elseif action.type == "delete" and action.entry_type == "file" then
						local deleted_path = action.url

						-- Convert oil:// URLs to file paths
						if deleted_path:match("^oil://") then
							deleted_path = deleted_path:gsub("^oil://", "")
						end

						handle_file_delete(deleted_path)
					end
				end
			end,
		})
	end,
}
