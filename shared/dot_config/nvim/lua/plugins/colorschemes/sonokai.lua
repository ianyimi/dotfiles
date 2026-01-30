---@type Huez.ThemeConfig
local M = {
  styles = { "espresso" },
  set_theme = function(theme)
    ---@type sonokai.Config

    local config = function()
      vim.g.sonokai_transparent_background = "1"
      vim.g.sonokai_enable_style = "1"
      vim.g.sonokai_style = "espresso"
    end
    require("sonokai").setup(config)
    vim.cmd("colorscheme " .. theme)
    return true
  end,
}

