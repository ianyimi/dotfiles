-- Ghana Cozy Light theme configuration for Huez
return {
  -- This function will be called when the theme is applied
  config = function()
    -- Ensure termguicolors is enabled
    vim.opt.termguicolors = true
    
    -- Set background to light for this theme
    vim.opt.background = "light"
    
    -- Any additional theme-specific configurations can go here
    -- For example, specific plugin configurations that work well with this theme
  end
}