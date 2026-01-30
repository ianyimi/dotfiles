return {
  "lewis6991/satellite.nvim",
  event = "VeryLazy",
  opts = {
    current_only = false,
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
        enable = true,
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

    -- Clamp util indices to valid line ranges defensively
    local ok_util, util = pcall(require, "satellite.util")
    if ok_util and type(util.virtual_line_count) == "function" then
      local orig_vlc = util.virtual_line_count
      util.virtual_line_count = function(winid, row, ...)
        local buf_ok, buf = pcall(vim.api.nvim_win_get_buf, winid)
        if buf_ok then
          local line_count = vim.api.nvim_buf_line_count(buf)
          if type(row) == "number" then
            if row < 1 then row = 1 end
            if row > line_count then row = line_count end
          end
        end
        local ok1, res = pcall(orig_vlc, winid, row, ...)
        if ok1 then return res end
        return 0
      end
    end
  end,
}

