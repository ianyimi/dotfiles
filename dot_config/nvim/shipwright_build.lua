-- Shipwright build script to export Ghana Cozy themes to standard Lua format
-- Run with: :Shipwright

local lushwright = require("shipwright.transform.lush")

-- Export Ghana Cozy Dark theme
run(require("plugins.colorschemes.ghana-cozy"),
  lushwright.to_lua,
  {patchwrite, "colors/ghana-cozy.lua", "-- PATCH_OPEN", "-- PATCH_CLOSE"})

-- Export Ghana Cozy Light theme  
run(require("plugins.colorschemes.ghana-cozy-light"),
  lushwright.to_lua,
  {patchwrite, "colors/ghana-cozy-light.lua", "-- PATCH_OPEN", "-- PATCH_CLOSE"})