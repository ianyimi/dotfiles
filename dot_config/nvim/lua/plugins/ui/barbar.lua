return {
	"romgrk/barbar.nvim",
	enabled = true,
	event = "VeryLazy",
	dependencies = { "ThePrimeagen/harpoon" },
	keys = {
		-- Buffer navigation keymaps (equivalent to bufferline keymaps)
		{ "<S-h>",      "<Cmd>BufferPrevious<CR>",          desc = "Previous Buffer" },
		{ "<S-l>",      "<Cmd>BufferNext<CR>",              desc = "Next Buffer" },
		{ "[b",         "<Cmd>BufferPrevious<CR>",          desc = "Prev Buffer" },
		{ "]b",         "<Cmd>BufferNext<CR>",              desc = "Next Buffer" },
		{ "[B",         "<Cmd>BufferMovePrevious<CR>",      desc = "Move buffer prev" },
		{ "]B",         "<Cmd>BufferMoveNext<CR>",          desc = "Move buffer next" },
		-- Buffer movement keymaps (equivalent to bufferline keymaps)
		{ "<C-h>",      "<Cmd>BufferMovePrevious<CR>",      desc = "Move Buffer Left" },
		{ "<C-l>",      "<Cmd>BufferMoveNext<CR>",          desc = "Move Buffer Right" },
		-- Additional barbar-specific keymaps for parity with bufferline
		{ "<leader>bp", "<Cmd>BufferPin<CR>",               desc = "Toggle Pin" },
		{ "<leader>C",  "<Cmd>BufferCloseBuffersRight<CR>", desc = "Delete Buffers to the Right" },
		{ "<leader>X",  "<Cmd>BufferCloseBuffersLeft<CR>",  desc = "Delete Buffers to the Left" },
	},
	config = function()
		local barbar = require("barbar")
		local state = require("barbar.state")
		local render = require("barbar.ui.render")
		local harpoon = require("harpoon")

		barbar.setup({
			hide = {
				inactive = false,
			},
			icons = {
				pinned = { filename = true, buffer_index = true },
				diagnostics = { { enabled = true } },
			},
		})

		local function unpin_all()
			for _, buf in ipairs(state.buffers) do
				local data = state.get_buffer_data(buf)
				data.pinned = false
			end
		end

		local function get_buffer_by_mark(mark)
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				local buffer_path = vim.api.nvim_buf_get_name(buf)

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

		local function refresh_all_harpoon_tabs()
			local ok, list = pcall(function()
				return harpoon:list()
			end)
			if not ok or not list then
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
					vim.cmd("badd " .. mark.value)
					buf = get_buffer_by_mark(mark)
				end
				if buf ~= nil then
					state.toggle_pin(buf)
				end

				::continue::
			end
			render.update()
		end

		vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufLeave", "User" }, {
			callback = refresh_all_harpoon_tabs,
		})
	end,
}
