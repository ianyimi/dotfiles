return { -- You can easily change to a different colorscheme.
  -- Change the name of the colorscheme plugin below, and then
  -- change the command in the config to whatever the name of that colorscheme is.
  --
  -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
  "sainnhe/sonokai",
  name = "sonokai",
  priority = 1000, -- Make sure to load this before all the other start plugins.
  config = function()
    -- Load the colorscheme here.
    -- Like many other themes, this one has different styles, and you could load
    -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
    vim.g.sonokai_transparent_background = "1"
    vim.g.sonokai_enable_style = "1"
    vim.g.sonokai_style = "andromeda"
    vim.cmd.colorscheme("sonokai")

    -- You can configure highlights by doing something like:
    -- vim.cmd.hi("Comment gui=none")
  end,
}
