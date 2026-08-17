-- Lazy entry point for the interactive performance probe (lua/util/perf-probe.lua).
--
-- Neovim sources `<rtp>/plugin/*.lua` exactly once during startup, which gives
-- us the three properties we want without involving lazy.nvim: the `Perf*`
-- commands always exist in every session, the 20KB probe module is never read
-- until one of them is invoked, and registration cannot happen twice.
--
-- Each command below is a forwarder. The first invocation requires the module
-- and calls its `setup()`, which *overwrites* these definitions with the real
-- handlers, then re-dispatches the original command with its arguments.
--
-- Why a plugin/ file rather than a lazy.nvim spec with `cmd = {...}`: that would
-- need `dir = vim.fn.stdpath('config')`, making lazy treat the entire config as
-- a plugin and adding a phantom entry to `:Lazy`, and it would duplicate this
-- command list anyway. Revisit only if the probe becomes its own repo.

if vim.g.loaded_perf_probe then
  return
end
vim.g.loaded_perf_probe = true

-- `nargs` per command must match lua/util/perf-probe.lua's real definitions, so
-- that arguments survive the hand-off untouched.
local COMMANDS = {
  PerfStart = "?",
  PerfStop = 0,
  PerfMark = "*",
  PerfSnap = "*",
  PerfReport = 0,
  PerfDup = 0,
  PerfLeak = 0,
  PerfLog = 0,
}

-- Flipped before re-dispatch. If the module fails to load or its setup() does
-- not replace these stubs, the second pass reports once instead of recursing
-- forever through the forwarder.
local attempted = false

---@param name string
---@param args string[]
local function load_and_dispatch(name, args)
  if attempted then
    vim.notify(
      ("perf-probe: %s did not install; see :messages"):format(name),
      vim.log.levels.ERROR
    )
    return
  end
  attempted = true

  local ok, probe = pcall(require, "util.perf-probe")
  if not ok then
    vim.notify("perf-probe: failed to load -> " .. tostring(probe), vim.log.levels.ERROR)
    return
  end

  local ok_setup, err = pcall(probe.setup)
  if not ok_setup then
    vim.notify("perf-probe: setup failed -> " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- setup() has replaced this forwarder, so this reaches the real handler.
  vim.cmd({ cmd = name, args = args })
end

for name, nargs in pairs(COMMANDS) do
  vim.api.nvim_create_user_command(name, function(a)
    load_and_dispatch(name, a.fargs)
  end, {
    nargs = nargs,
    desc = "perf-probe: " .. name .. " (module loads on first use)",
  })
end
