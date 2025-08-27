-- Bufferline config with Harpoon 2 integration, equivalent to prior barbar.nvim setup
return {
	"akinsho/bufferline.nvim",
	event = "VeryLazy",
	enabled = false,
	dependencies = {
		"ThePrimeagen/harpoon",
	},
	keys = {
		{ "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
		{ "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non‑Pinned Buffers" },
		{ "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
		{ "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
		-- Buffer navigation keymaps moved from keymaps.lua
		{ "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous Buffer" },
		{ "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
		{ "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
		{ "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
		{ "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
		{ "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
		-- Buffer movement keymaps moved from keymaps.lua
		{ "<C-h>", "<cmd>BufferLineMovePrev<CR>", desc = "Move Buffer Left" },
		{ "<C-l>", "<cmd>BufferLineMoveNext<CR>", desc = "Move Buffer Right" },
	},
	opts = {
		options = {
			close_command = function(n) Snacks.bufdelete(n) end,
			right_mouse_command = function(n) Snacks.bufdelete(n) end,
			diagnostics = "nvim_lsp",
			always_show_bufferline = true,
			diagnostics_indicator = function(_, _, diag)
				local icons = LazyVim.config.icons.diagnostics
				local ret = (diag.error and icons.Error .. diag.error .. " " or "")
						.. (diag.warning and icons.Warn .. diag.warning or "")
				return vim.trim(ret)
			end,
			offsets = {
				{ filetype = "neo-tree",         text = "Neo-tree", highlight = "Directory", text_align = "left" },
				{ filetype = "snacks_layout_box" },
			},
			get_element_icon = function(opts)
				return LazyVim.config.icons.ft[opts.filetype]
			end,

			-- show Harpoon index in tab name
			name_formatter = function(buf)
				local ok, harpoon = pcall(require, "harpoon")
				local buf_name = vim.fn.fnamemodify(buf.path, ":t")
				local dir_name = vim.fn.fnamemodify(buf.path, ":h:t")

				if buf_name == "index" or buf_name == "client" or buf_name == "server" then
					buf_name = string.format("%s/%s", dir_name, buf_name)
				end

				if not ok then
					return buf_name
				end

				local list = harpoon:list().items or {}
				local buf_path = vim.fn.fnamemodify(buf.path, ":p")
				for i, item in ipairs(list) do
					if vim.fn.fnamemodify(item.value, ":p") == buf_path then
						return string.format("[%d] %s", i, buf_name)
					end
				end
				return buf_name
			end,

			-- sort Harpoon buffers first in Harpoon order, fall back to Bufferline default
			sort_by = function(buffer_a, buffer_b)
				local ok, harpoon = pcall(require, "harpoon")
				if not ok then
					return buffer_a.ordinal < buffer_b.ordinal
				end
				local list = harpoon:list().items or {}
				local path_a = vim.api.nvim_buf_get_name(buffer_a.id)
				local path_b = vim.api.nvim_buf_get_name(buffer_b.id)
				local idx_a, idx_b
				for i, item in ipairs(list) do
					if vim.fn.fnamemodify(item.value, ":p") == path_a then idx_a = i end
					if vim.fn.fnamemodify(item.value, ":p") == path_b then idx_b = i end
				end
				if idx_a and idx_b then return idx_a < idx_b end
				if idx_a then return true end
				if idx_b then return false end
				return buffer_a.ordinal < buffer_b.ordinal
			end,
		},
	},
	config = function(_, opts)
		require("bufferline").setup(opts)

		-- Helpers ---------------------------------------------------------------
		local function unpin_all()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				local ok, pinned = pcall(vim.api.nvim_buf_get_var, buf, "bufferline_pin")
				if ok and pinned then
					pcall(require("bufferline.commands").toggle_pin, buf)
				end
			end
		end

		local function buffer_matches(mark, buf)
			local buf_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
			if buf_path == "" or mark.value == "" then return false end
			-- escape magic chars, test both directions for partial match like barbar version
			local mark_pattern = mark.value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
			if string.match(buf_path, mark_pattern) then return true end
			local buf_pattern = buf_path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
			return string.match(mark.value, buf_pattern) ~= nil
		end

		local function get_buffer_by_mark(mark)
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if buffer_matches(mark, buf) then return buf end
			end
		end

		local function refresh_harpoon_pins()
			local ok, harpoon = pcall(require, "harpoon")
			if not ok then return end
			local list = harpoon:list()
			if not list then return end

			unpin_all()

			for i = 1, list:length() do
				local mark = list.items[i]
				if mark and mark.value ~= "" then
					local buf = get_buffer_by_mark(mark)
					if not buf then
						vim.cmd("badd " .. vim.fn.fnameescape(mark.value))
						buf = get_buffer_by_mark(mark)
					end
					if buf then
						-- pin if not already pinned
						local ok_pin, pinned = pcall(vim.api.nvim_buf_get_var, buf, "bufferline_pin")
						if not ok_pin or not pinned then
							pcall(require("bufferline.commands").toggle_pin, buf)
						end
					end
				end
			end
			-- force UI refresh
			pcall(require("bufferline.ui").refresh)
		end

		-- Run once and re‑run on key events similar to barbar autocommand
		refresh_harpoon_pins()
		vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufLeave", "User" }, {
			callback = refresh_harpoon_pins,
		})

		-- Fix bufferline session restore
		vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
			callback = function()
				vim.schedule(function()
					pcall(nvim_bufferline)
				end)
			end,
		})
	end,
}
