vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
-- Set filetype to `bigfile` for files larger than 1.5 MB
-- Only vim syntax will be enabled (with the correct filetype)
-- LSP, treesitter and other ft plugins will be disabled.
-- mini.animate will also be disabled.
vim.g.bigfile_size = 1024 * 1024 * 1.5 -- 1.5 MB
-- Fix markdown indentation settings
vim.g.markdown_recommended_style = 0
-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

vim.g.lazygit_config = true

vim.opt.spelllang = { "en" }

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.laststatus = 3
vim.opt.signcolumn = "yes"

vim.opt.cursorline = true
vim.opt.cursorcolumn = true

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.wrap = false

vim.opt.expandtab = false
local tabSize = 2
vim.opt.tabstop = tabSize
vim.opt.shiftwidth = tabSize

-- only set clipboard if not in ssh, to make sure the OSC 52
-- integration works automatically. Requires Neovim >= 0.10.0
vim.opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus" -- Sync with system clipboard
vim.opt.scrolloff = 999

vim.opt.virtualedit = "block"

-- vim.opt.inccommand = "split"

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.termguicolors = true

vim.opt.showmode = false

-- Suppress swap file ATTENTION messages for multi-session workflows
-- This prevents E325 errors when opening the same folder in multiple tmux sessions
vim.opt.shortmess:append("A")

vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.undoreload = 10000

-- Function to detect the operating system
local function is_windows()
	return package.config:sub(1, 1) == '\\'
end

-- Function to get the name of the current Git branch
local function get_git_branch()
	local stderr_redirect = is_windows() and '2>nul' or '2>/dev/null'
	local handle = io.popen('git rev-parse --abbrev-ref HEAD ' .. stderr_redirect)
	local result = handle:read("*a")
	handle:close()
	if result == '' then
		return nil
	else
		return result:gsub('%s+', '') -- Remove any whitespace
	end
end

-- Function to get the current Git worktree's top-level directory
local function get_git_worktree()
	local stderr_redirect = is_windows() and '2>nul' or '2>/dev/null'
	local handle = io.popen('git rev-parse --show-toplevel ' .. stderr_redirect)
	local result = handle:read("*a")
	handle:close()
	if result == '' then
		return nil
	else
		return result:gsub('%s+$', '') -- Remove trailing whitespace
	end
end

-- Get the Git worktree path or branch name
local git_worktree = get_git_worktree()
local git_branch = get_git_branch()

if git_worktree then
	-- Sanitize the worktree path to create a unique filename
	local worktree_name = git_worktree:gsub('[^%w%-_./]', '_'):gsub('[:\\]', '_')
	-- Replace forward slashes with underscores for compatibility
	worktree_name = worktree_name:gsub('/', '_')
	local shada_filename = 'main-' .. worktree_name .. '.shada'
	-- Set the shadafile option to use the worktree-specific Shada file
	vim.opt.shadafile = vim.fn.stdpath('data') .. '/shada/' .. shada_filename
elseif git_branch then
	-- Use the branch name if worktree path is not available
	local branch_name = git_branch:gsub('[^%w%-_./]', '_')
	branch_name = branch_name:gsub('/', '_')
	local shada_filename = 'main-' .. branch_name .. '.shada'
	vim.opt.shadafile = vim.fn.stdpath('data') .. '/shada/' .. shada_filename
else
	-- Fallback to the default shadafile
	vim.opt.shadafile = vim.fn.stdpath('data') .. '/shada/main.shada'
end
