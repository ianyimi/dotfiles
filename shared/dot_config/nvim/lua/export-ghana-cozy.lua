-- Alternative export script that doesn't require Shipwright
-- Run with: :lua require('export-ghana-cozy')

local function export_theme()
  -- Load lush if available
  local ok_lush, lush = pcall(require, 'lush')
  if not ok_lush then
    print("Error: Lush not available")
    return
  end
  
  -- Try to load and compile the themes
  local ok_dark, dark_theme = pcall(require, 'plugins.colorschemes.ghana-cozy')
  local ok_light, light_theme = pcall(require, 'plugins.colorschemes.ghana-cozy-light')
  
  if not ok_dark or not ok_light then
    print("Error: Could not load Ghana Cozy themes")
    return
  end
  
  -- Compile the themes to get color data
  local dark_compiled = lush.compile(dark_theme, { force_clean_slate = true })
  local light_compiled = lush.compile(light_theme, { force_clean_slate = true })
  
  -- Function to convert compiled theme to nvim_set_hl format
  local function compiled_to_nvim_hl(compiled)
    local result = {}
    for group_name, group_def in pairs(compiled) do
      local attrs = {}
      
      if group_def.fg then attrs.fg = group_def.fg.hex end
      if group_def.bg then attrs.bg = group_def.bg.hex end
      if group_def.sp then attrs.sp = group_def.sp.hex end
      
      -- Handle gui attributes
      if group_def.gui then
        local gui_attrs = {}
        if type(group_def.gui) == "table" then
          for _, attr in ipairs(group_def.gui) do
            gui_attrs[attr] = true
          end
        else
          gui_attrs[group_def.gui] = true
        end
        
        -- Convert to nvim_set_hl format
        if gui_attrs.bold then attrs.bold = true end
        if gui_attrs.italic then attrs.italic = true end
        if gui_attrs.underline then attrs.underline = true end
        if gui_attrs.undercurl then attrs.undercurl = true end
        if gui_attrs.reverse then attrs.reverse = true end
        if gui_attrs.standout then attrs.standout = true end
      end
      
      if next(attrs) then -- Only add if has attributes
        result[group_name] = attrs
      end
    end
    return result
  end
  
  -- Convert themes
  local dark_colors = compiled_to_nvim_hl(dark_compiled)
  local light_colors = compiled_to_nvim_hl(light_compiled)
  
  -- Generate Lua code for colors table
  local function generate_colors_table(colors)
    local lines = {}
    for group, attrs in pairs(colors) do
      local attr_parts = {}
      for key, value in pairs(attrs) do
        if type(value) == "string" then
          table.insert(attr_parts, string.format('%s = "%s"', key, value))
        elseif type(value) == "boolean" and value then
          table.insert(attr_parts, string.format('%s = true', key))
        end
      end
      if #attr_parts > 0 then
        table.insert(lines, string.format('  %s = { %s },', group, table.concat(attr_parts, ', ')))
      end
    end
    return table.concat(lines, '\n')
  end
  
  local dark_lua = generate_colors_table(dark_colors)
  local light_lua = generate_colors_table(light_colors)
  
  print("Exported themes successfully!")
  print("Dark theme has " .. vim.tbl_count(dark_colors) .. " highlight groups")
  print("Light theme has " .. vim.tbl_count(light_colors) .. " highlight groups")
  print("")
  print("Now updating colorscheme files...")
  
  -- Return the generated code for manual insertion if needed
  return {
    dark = dark_lua,
    light = light_lua,
    dark_colors = dark_colors,
    light_colors = light_colors
  }
end

local exported = export_theme()
if exported then
  -- Store in global variable for easy access
  _G.ghana_cozy_exported = exported
  print("Color data stored in _G.ghana_cozy_exported")
  print("You can access the color tables directly now:")
  print("- _G.ghana_cozy_exported.dark_colors")  
  print("- _G.ghana_cozy_exported.light_colors")
end