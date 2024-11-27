local keymap = vim.keymap

-- cut characters to void register
keymap.set("n", "x", '"_x')
keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

--  save
keymap.set("n", "<leader>w", "<cmd>w<cr><Esc>", { desc = "[W]rite file" })
keymap.set("v", "<leader>w", "<cmd>w<cr><Esc>", { desc = "[W]rite file" })
keymap.set("v", "<leader><S-w>", "<cmd>w<CR><Esc><cmd>bd<CR>", { desc = "[W]rite file, close buffer" })

--  comment
keymap.set("n", "<leader>.", "<cmd>normal gcc<CR>", { noremap = true, desc = "[C]omment line" })
keymap.set("v", "<leader>.", "<cmd>normal gcc<CR>", { noremap = true, desc = "[C]omment lines" })

-- select all
keymap.set("n", "<C-a>", "gg<S-v><S-g>", { desc = "Select [A]ll" })
keymap.set("n", "<C-y>", "gg<S-v><S-g>y", { desc = "[Y]ank All" })

--  upshift line below
keymap.set("n", "<S-j>", "mz<S-j>`z", { desc = "Upshift line below" })

-- pane controls
keymap.set("n", "<leader>v", "<C-w>v", { desc = "Split window right" })
keymap.set("n", "<leader>b", "<C-w>s", { desc = "Split window below" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>x", "<cmd>close<CR>", { desc = "Close current split" })
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

-- buffer controls
keymap.set("n", "<S-x>", ":bd<CR>", { noremap = true, silent = true, desc = "Close Buffer" })
keymap.set("n", "<C-S-x>", ":bd!<CR>", { noremap = true, silent = true, desc = "Close Buffer (Force)" })
-- buffer navigation
keymap.set("n", "<S-l>", "<cmd>BufferNext<CR>", { noremap = true, silent = true, desc = "Next Buffer" })
keymap.set("n", "<S-h>", "<cmd>BufferPrev<CR>", { noremap = true, silent = true, desc = "Previous Buffer" })

keymap.set("v", "<S-j>", ":m '>+1<CR>gv=gv", { desc = "Downshift selected code" })
keymap.set("v", "<S-k>", ":m '<-2<CR>gv=gv", { desc = "Upshift selected code" })

keymap.set("v", ">", ">gv", { desc = "Indent Selected Code" })
keymap.set("v", "<", "<gv", { desc = "Un-Indent Selected Code" })
keymap.set("x", ">", ">g", { desc = "Indent Selected Code" })
keymap.set("x", "<", "<g", { desc = "Un-Indent Selected Code" })

-- lazygit
keymap.set("n", "<leader>gg", function()
	LazyVim.lazygit({ cwd = LazyVim.root.git() })
end, { desc = "Lazygit (Root Dir)" })
keymap.set("n", "<leader>gG", function()
	LazyVim.lazygit()
end, { desc = "Lazygit (cwd)" })

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
