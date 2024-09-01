-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
--
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true
-- Clear highlights on search when pressing <Esc> in normal mode

vim.keymap.set("n", "x", '"_x')
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Toggle Undo Tree
vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)

--  save
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "[W]rite file" })

--  pane navigation
vim.keymap.set("n", "<leader>h", "<C-w><C-h>", { desc = "Move focus to the left pane" })
vim.keymap.set("n", "<leader>l", "<C-w><C-l>", { desc = "Move focus to the right pane" })
vim.keymap.set("n", "<leader>j", "<C-w><C-j>", { desc = "Move focus to the lower pane" })
vim.keymap.set("n", "<leader>k", "<C-w><C-k>", { desc = "Move focus to the upper pane" })

-- pane controls
vim.keymap.set("n", "<leader>v", "<C-w>v", { desc = "Split window right" }) -- split window vertically
vim.keymap.set("n", "<leader>b", "<C-w>s", { desc = "Split window below" }) -- split window horizontally
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
vim.keymap.set("n", "<leader>x", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

-- tab
vim.keymap.set("n", "<C-t>", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
vim.keymap.set("n", "<C-w>", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
vim.keymap.set("n", "<S-l>", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
vim.keymap.set("n", "<S-h>", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
vim.keymap.set("n", "<C-S-t>", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  moves current buffer to new tab
