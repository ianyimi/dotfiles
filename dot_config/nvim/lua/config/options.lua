vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Notification filtering.
--
-- (1) Plugin-origin deprecation warnings that we can't fix in our own code.
-- Each entry corresponds to a known third-party plugin that hasn't migrated:
--   tbl_flatten         — various plugins, replaced by vim.iter():flatten():totable()
--   client.request      — tailwind-tools.nvim (lsp.lua lines 121, 212),
--                         snacks.nvim (rename.lua line 98); 0.12 wants client:request()
local deprecation_patterns = {
	"tbl_flatten",
	"client%.request",
	"client%.request_sync",
}

-- (2) Hover "no information" messages. Nvim 0.12+'s `vim.lsp.buf.hover()` and
-- Noice's hover replacement both emit one of these notifications when no LSP
-- client has hover content for the cursor position. With multiple LSPs
-- attached (tailwindcss + vtsls + eslint on a .tsx file), this fires multiple
-- times per hover attempt and also fires on every hover that hits whitespace,
-- comments, etc. We don't want any of these — if there's nothing to show on
-- hover, we want it to be silent (VSCode-style: no popup, no notification).
-- Overriding vim.lsp.buf.hover would let us dedupe at the source, but Noice
-- claims that function for itself and emits a warning if another plugin
-- overwrites it. Cleanest fix: drop these messages at the notification layer.
local hover_silence_patterns = {
	"^No information available$",
	"^Empty hover response$",
}

local function matches_any(msg, patterns)
	if type(msg) ~= "string" then return false end
	for _, pat in ipairs(patterns) do
		if msg:match(pat) then return true end
	end
	return false
end

local notify_orig = vim.notify
vim.notify = function(msg, level, opts)
	if matches_any(msg, deprecation_patterns) then return end
	if matches_any(msg, hover_silence_patterns) then return end
	return notify_orig(msg, level, opts)
end

-- Also suppress at the source so it doesn't even reach the notify path
if vim.deprecate then
	local deprecate_orig = vim.deprecate
	vim.deprecate = function(name, alt, version, ...)
		if type(name) == "string" then
			for _, pat in ipairs(deprecation_patterns) do
				if name:match(pat) then return end
			end
		end
		return deprecate_orig(name, alt, version, ...)
	end
end

-- Set filetype to `bigfile` for files larger than 1.5 MB
-- Only vim syntax will be enabled (with the correct filetype)
-- LSP, treesitter and other ft plugins will be disabled.
-- mini.animate will also be disabled.
vim.g.bigfile_size = 1024 * 1024 * 1.5 -- 1.5 MB
-- Fix markdown indentation settings
vim.g.markdown_recommended_style = 0

-- Enable syntax highlighting for fenced code blocks in markdown.
-- This is what makes ```css ... ``` highlight as CSS inside LSP hover popups
-- (and any other markdown buffer). Required for tailwindcss hover, JSDoc code
-- examples, etc. Used by both vim's markdown syntax and treesitter markdown_inline
-- injection queries.
vim.g.markdown_fenced_languages = {
	"css",
	"scss",
	"html",
	"javascript",
	"js=javascript",
	"typescript",
	"ts=typescript",
	"jsx=javascriptreact",
	"tsx=typescriptreact",
	"json",
	"lua",
	"bash",
	"sh=bash",
	"zsh=bash",
	"python",
	"go",
	"rust",
	"yaml",
	"toml",
	"sql",
}
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

vim.opt.expandtab = true
local tabSize = 2
vim.opt.tabstop = tabSize
vim.opt.shiftwidth = tabSize
vim.opt.softtabstop = tabSize

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

vim.opt.autoread = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 500 -- Faster key sequence timeout
vim.opt.ttimeoutlen = 10 -- Faster escape key

-- LSP performance optimizations
vim.opt.foldmethod = "manual" -- Avoid expensive fold calculations
vim.opt.synmaxcol = 200 -- Limit syntax highlighting to 200 columns

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
