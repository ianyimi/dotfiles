local keymap = vim.keymap

-- cut characters to void register
keymap.set("n", "s", '"_s')
keymap.set("n", "x", '"_x')
keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

--  save
keymap.set("n", "<leader>w", "<cmd>w<cr><Esc>", { desc = "[W]rite file" })
keymap.set("v", "<leader>w", "<cmd>w<cr><Esc>", { desc = "[W]rite file" })
keymap.set("v", "<leader><S-w>", "<cmd>w<CR><Esc><cmd>bd<CR>", { desc = "[W]rite file, close buffer" })

--  comment
keymap.set("n", "<leader>.", "<cmd>normal gcc<CR>", { noremap = true, desc = "[C]omment line" })
keymap.set("v", "<leader>.", "<cmd>normal gcc<CR>", { noremap = true, desc = "[C]omment lines" })

-- select/yank all
keymap.set("n", "<C-a>", "gg<S-v><S-g>", { desc = "Select [A]ll" })
keymap.set("n", "<C-y>", "gg<S-v><S-g>y", { desc = "[Y]ank All" })

-- toggle file explorer
keymap.set("n", "<leader>e", function()
	require("oil").toggle_float()
	vim.schedule(function()
		local buf = vim.api.nvim_get_current_buf()
		local ok, ft = pcall(vim.api.nvim_get_option_value, "filetype", { buf = buf })
		if ok and ft == "oil" then
			-- Opening via <leader>e should always be closable
			vim.b[buf].oil_allow_close = nil
		end
	end)
end, { desc = "[E]xplore Files" })

-- pane controls
keymap.set("n", "<leader>v", "<C-w>v", { desc = "Split window right" })
keymap.set("n", "<leader>b", "<C-w>s", { desc = "Split window below" })
-- keymap.set("n", "<leader>es", "<C-w>=", { desc = "Make [E]qual [S]plits" })
keymap.set("n", "<leader>x", "<cmd>close<CR>", { desc = "Close current split" })
keymap.set("n", "<leader>B", function()
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_delete(buf, { force = true })
end, { noremap = true, silent = true, desc = "Force Close Current Buffer" })
--  pane navigation
keymap.set("n", "<leader>h", "<C-w><C-h>", { desc = "Move focus to the left pane" })
keymap.set("n", "<leader>l", "<C-w><C-l>", { desc = "Move focus to the right pane" })
keymap.set("n", "<leader>j", "<C-w><C-j>", { desc = "Move focus to the lower pane" })
keymap.set("n", "<leader>k", "<C-w><C-k>", { desc = "Move focus to the upper pane" })

-- tab controls
keymap.set("n", "<a-t>", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<a-x>", "<cmd>tabclose<CR>", { desc = "Close current tab" })
-- tab navigation
keymap.set("n", "<a-h>", "<cmd>tabnext", { desc = "Split window right" })
keymap.set("n", "<a-l>", "<cmd>tabprev", { desc = "Split window below" })

-- buffer controls with oil auto-open
local function real_other_buffers_count(exclude)
	local count = 0
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(b) and b ~= exclude then
			local bt = vim.api.nvim_get_option_value("buftype", { buf = b })
			local ft = vim.api.nvim_get_option_value("filetype", { buf = b })
			local name = vim.api.nvim_buf_get_name(b)
			if bt == "" and ft ~= "oil" and name ~= "" then
				count = count + 1
			end
		end
	end
	return count
end
keymap.set("n", "<S-x>", function()
	local cur = vim.api.nvim_get_current_buf()
	-- if present in harpoon, remove it before deleting
	pcall(function()
		local ok_h, harpoon = pcall(require, "harpoon")
		if not ok_h then return end
		local list = harpoon:list()
		local current_file = vim.api.nvim_buf_get_name(cur)
		if current_file == "" then return end
		local norm = vim.fn.fnamemodify(current_file, ":p")
		local found_index
		for i, item in ipairs(list.items or {}) do
			if vim.fn.fnamemodify(item.value or "", ":p") == norm then
				found_index = i
				break
			end
		end
		if found_index then
			-- Always compact/shift the list when removing
			local new_items = {}
			for i, item in ipairs(list.items or {}) do
				if i ~= found_index and item and item.value and item.value ~= "" then
					table.insert(new_items, item)
				end
			end
			list.items = new_items
			list._length = #new_items
			pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "HarpoonListChanged" })
		end
	end)
	-- if there is exactly one other real file buffer, close this window after delete
	if real_other_buffers_count(cur) == 1 then
		local win = vim.api.nvim_get_current_win()
		require("util.ui").bufremove(cur, { force = false })
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(win) then
				pcall(vim.cmd, "close")
			end
		end)
		return
	end
	-- otherwise keep the split using util.ui.bufremove
	require("util.ui").bufremove(cur, { force = false })
end, { noremap = true, silent = true, desc = "Close Buffer (smart)" })

keymap.set("n", "<C-S-x>", function()
	local cur = vim.api.nvim_get_current_buf()
	if real_other_buffers_count(cur) == 1 then
		local win = vim.api.nvim_get_current_win()
		require("util.ui").bufremove(cur, { force = true })
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(win) then
				pcall(vim.cmd, "close")
			end
		end)
		return
	end
	-- otherwise keep the split using util.ui.bufremove
	require("util.ui").bufremove(cur, { force = true })
end, { noremap = true, silent = true, desc = "Close Buffer (Force, smart)" })

keymap.set("v", "<S-j>", ":m '>+1<CR>gv=gv", { desc = "Downshift selected code" })
keymap.set("v", "<S-k>", ":m '<-2<CR>gv=gv", { desc = "Upshift selected code" })

keymap.set("v", ">", ">gv", { desc = "Indent Selected Code" })
keymap.set("v", "<", "<gv", { desc = "Un-Indent Selected Code" })
keymap.set("x", ">", ">gv", { desc = "Indent Selected Code" })
keymap.set("x", "<", "<gv", { desc = "Un-Indent Selected Code" })

-- lazygit
keymap.set("n", "<leader>gg", function()
	LazyVim.lazygit({ cwd = LazyVim.root.git() })
end, { desc = "Lazygit (Root Dir)" })
keymap.set("n", "<leader>gG", function()
	LazyVim.lazygit()
end, { desc = "Lazygit (cwd)" })

-- make ZZ conditional: if a lazygit float exists, close it and quit all; else fallback to default ZZ
keymap.set("n", "ZZ", function()
	-- Always close everything in one shot, regardless of LazyGit state
	-- Close any LazyGit terminals first
	pcall(function() require("util.terminal").close_all() end)

	-- Save all buffers
	pcall(vim.cmd, "silent! wall")

	-- Force quit all - handles splits, tabs, everything
	local ok = pcall(vim.cmd, "qa")
	if not ok then
		pcall(vim.cmd, "qa!")
	end
end, { desc = "Force quit all (saves first)" })
keymap.set("n", "WW", "<leader>wZZ", { desc = "Split window below" })

-- delete to void register & paste
keymap.set("x", "<leader>p", '"_dP', { desc = "[P]aste & Delete to void" })

keymap.set("n", "<leader>d", '"_d', { desc = "[D]elete to void" })
keymap.set("v", "<leader>d", '"_d', { desc = "[D]elete to void" })
keymap.set("n", "<leader>D", '"_D', { desc = "[D]elete to void" })
-- keymap.set("n", "<leader>y", '"+y', { desc = "[Y]ank to system clipboard" })
-- keymap.set("v", "<leader>y", '"+y', { desc = "[Y]ank to system clipboard" })
-- keymap.set("n", "<leader>p", '"+p', { desc = "[P]aste from system clipboard" })
-- keymap.set("v", "<leader>p", '"+p', { desc = "[P]aste from system clipboard" })

-- void shift-q
keymap.set("n", "<S-q>", "<nop>")

keymap.set("n", "<a-C-h>", ":h <Space>", { desc = "[H]elp" })

-- LSP restart with keymap restoration
keymap.set("n", "<leader>rr", function()
	vim.notify("Restarting all LSP servers (including ESLint)...", vim.log.levels.INFO)

	-- Restart all active LSP clients including ESLint
	local clients = vim.lsp.get_clients()
	local restarted_count = 0
	for _, client in ipairs(clients) do
		vim.cmd("LspRestart " .. client.id)
		restarted_count = restarted_count + 1
	end

	-- After restart, ensure keymaps are restored for all buffers
	-- The LspAttach autocmd will handle the actual restoration
	vim.defer_fn(function()
		-- Get all buffers with LSP clients
		local buffers_with_lsp = {}
		for _, client in ipairs(vim.lsp.get_clients()) do
			for _, buf in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
				buffers_with_lsp[buf] = true
			end
		end

		-- Trigger LspAttach for each buffer to ensure keymaps are restored
		local restored_count = 0
		for buf, _ in pairs(buffers_with_lsp) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_exec_autocmds("LspAttach", { buffer = buf })
				restored_count = restored_count + 1
			end
		end

		if restored_count > 0 then
			vim.notify(
				string.format("LSP restarted (%d server(s), %d buffer(s))", restarted_count, restored_count),
				vim.log.levels.INFO
			)
		else
			vim.notify(string.format("LSP restarted (%d server(s))", restarted_count), vim.log.levels.INFO)
		end
	end, 500)
end, { desc = "[R]estart LSP (with keymap restore)" })

-- Lua keybind to copy the file path of the current buffer to the clipboard with home directory replaced by ~
vim.keymap.set("n", "<leader>cp", function()
	-- Get the current file's absolute path
	local filepath = vim.fn.expand("%:p")

	-- Get the user's home directory
	local home = vim.env.HOME or vim.fn.expand("~")

	-- Function to escape special characters
	local function escape_special_chars(str)
		-- Escape Lua pattern special characters
		local special_chars = { "(", ")", "[", "]", "%%", ".", "+", "-", "*", "?", "^", "$", "/" }
		for _, char in ipairs(special_chars) do
			str = str:gsub("%" .. char, "\\" .. char)
		end
		return str
	end

	-- Escape special characters in the path
	local escaped_display_path = escape_special_chars(home)

	-- Copy the escaped path to clipboard
	vim.fn.setreg("+", escaped_display_path)

	-- Optionally, show a message to confirm
	vim.notify("File path copied: " .. escaped_display_path)
end, { desc = "Copy current file path to clipboard" })
