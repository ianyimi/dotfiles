return {
  "lewis6991/satellite.nvim",
  event = "VeryLazy",
  opts = {
    -- Draw only the focused window. With `false`, satellite renders for EVERY
    -- window, and `handlers.render` spawns an async coroutine per handler per
    -- window whose every step costs a `vim.schedule`. Profiled with `false`:
    -- 3455 scheduled callbacks from satellite/async.lua averaging 8.4ms, about
    -- 31s of main-loop callback time in a 62s session (~88% of all scheduled
    -- work). That is the residual half-second on oil/telescope actions.
    current_only = true,
    winblend = 50,
    zindex = 40,
    excluded_filetypes = { "oil" },
    width = 2,
    handlers = {
      cursor = {
        enable = true,
        -- Supports any number of symbols
        symbols = { "⎺", "⎻", "⎼", "⎽" },
        -- symbols = { '⎻', '⎼' }
        -- Highlights:
        -- - SatelliteCursor (default links to NonText
      },
      search = {
        enable = true,
        -- Highlights:
        -- - SatelliteSearch (default links to Search)
        -- - SatelliteSearchCurrent (default links to SearchCurrent)
      },
      diagnostic = {
        enable = true,
        signs = { "-", "=", "≡" },
        min_severity = vim.diagnostic.severity.HINT,
        -- Highlights:
        -- - SatelliteDiagnosticError (default links to DiagnosticError)
        -- - SatelliteDiagnosticWarn (default links to DiagnosticWarn)
        -- - SatelliteDiagnosticInfo (default links to DiagnosticInfo)
        -- - SatelliteDiagnosticHint (default links to DiagnosticHint)
      },
      gitsigns = {
        -- Disabled: recomputes hunk positions per window per redraw
        -- (handlers/gitsigns.lua:63 -> gitsigns/actions.lua:681 ->
        -- gitsigns/hunks.lua:115) and supplied 3 of the 4 hottest frames in an
        -- 87ms stall. The gutter signs already carry this information.
        enable = false,
        signs = { -- can only be a single character (multibyte is okay)
          add = "│",
          change = "│",
          delete = "-",
        },
        -- Highlights:
        -- SatelliteGitSignsAdd (default links to GitSignsAdd)
        -- SatelliteGitSignsChange (default links to GitSignsChange)
        -- SatelliteGitSignsDelete (default links to GitSignsDelete)
      },
      marks = {
        enable = true,
        show_builtins = false, -- shows the builtin marks like [ ] < >
        key = "m",
        -- Highlights:
        -- SatelliteMark (default links to Normal)
      },
      quickfix = {
        signs = { "-", "=", "≡" },
        -- Highlights:
        -- SatelliteQuickfix (default links to WarningMsg)
      },
    },
  },
  config = function(_, opts)
    local ok_sat, sat = pcall(require, "satellite")
    if ok_sat then pcall(sat.setup, opts) end

    -- Guard Satellite render to avoid rare out-of-bounds crashes
    local ok_view, view = pcall(require, "satellite.view")
    if ok_view and type(view.render) == "function" then
      local orig_render = view.render
      view.render = function(...)
        local ok, res = pcall(orig_render, ...)
        if ok then return res end
        -- Suppress sporadic errors; try again on next event
      end
    end

    -- Clamp util indices to valid line ranges defensively.
    --
    -- The previous version pre-clamped `row` with nvim_win_get_buf +
    -- nvim_buf_line_count on EVERY call. satellite invokes this inside per-hunk
    -- and per-line loops, so that added two API calls per iteration on a hot
    -- path. The pcall alone gives identical crash protection for free: an
    -- out-of-range row raises, we swallow it and report no virtual lines.
    local ok_util, util = pcall(require, "satellite.util")
    if ok_util and type(util.virtual_line_count) == "function" then
      local orig_vlc = util.virtual_line_count
      util.virtual_line_count = function(...)
        local ok1, res = pcall(orig_vlc, ...)
        return ok1 and res or 0
      end
    end
  end,
}

