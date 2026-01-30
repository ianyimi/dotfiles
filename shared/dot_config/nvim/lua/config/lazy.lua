-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out,                            "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)
_G.LazyVim = require("util")

-- simple boot logger
if not _G.__boot_t0 then
  _G.__boot_t0 = (vim.uv and vim.uv.hrtime and vim.uv.hrtime()) or (vim.loop and vim.loop.hrtime() and vim.loop.hrtime()) or 0
end
_G._bench = function(msg)
  local now = (vim.uv and vim.uv.hrtime and vim.uv.hrtime()) or (vim.loop and vim.loop.hrtime and vim.loop.hrtime()) or 0
  local ms = (now - _G.__boot_t0) / 1e6
  local line = string.format("[boot +%.1fms] %s", ms, msg)
  -- echo to messages (if available)
  pcall(vim.cmd, "silent! echomsg " .. vim.fn.string(line))
  -- also write to a file so it's always inspectable
  local path = vim.fn.stdpath("cache") .. "/startup-bench.log"
  if not _G.__boot_log_inited then
    local f = io.open(path, "w"); if f then f:write(""); f:close() end
    _G.__boot_log_inited = true
  end
  local f = io.open(path, "a"); if f then f:write(line .. "\n"); f:close() end
end
_bench("lazy.lua start")

vim.api.nvim_create_user_command("StartupBenchLog", function()
  local path = vim.fn.stdpath("cache") .. "/startup-bench.log"
  vim.cmd("e " .. path)
end, { desc = "Open startup bench log" })

require("config.options")
_bench("options loaded")
require("config.keymaps")
_bench("keymaps loaded")

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- import your plugins
		{ import = "plugins.lsp" },
		{ import = "plugins.editor" },
		{ import = "plugins.formatting" },
		{ import = "plugins.coding" },
		{ import = "plugins.ui" },
		{ import = "plugins.util" },
		{ import = "plugins.ai" },
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "tokyonight" } },
	-- automatically check for plugin updates
	checker = { enabled = true, notify = false },
})
_bench("lazy.setup done")

require("config.autocmds")
_bench("config.autocmds loaded")

-- mark VeryLazy
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    _bench("VeryLazy fired")
  end,
})

-- mark VimEnter
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    _bench("VimEnter fired")
  end,
})

-- mark UIEnter
vim.api.nvim_create_autocmd("UIEnter", {
  once = true,
  callback = function()
    _bench("UIEnter fired")
  end,
})
