-- Ghana Cozy Light colorscheme (Simple Lua version)
-- A cozy light theme inspired by the colors of the Ghanaian flag

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end

vim.opt.termguicolors = true
vim.opt.background = "light"
vim.g.colors_name = "ghana-cozy-light-simple"

-- Ghana-inspired color palette for light mode
local colors = {
  -- Ghana flag colors (adjusted for light mode)
  ghana_red = "#c73e1d",
  ghana_gold = "#b8860b", 
  ghana_green = "#2d5a3d",
  
  -- Supporting colors
  warm_brown = "#5c4033",
  light_brown = "#d2b48c",
  cream = "#2d2416", -- Dark cream for text
  dark_green = "#1a3323",
  olive = "#556b3d",
  burgundy = "#8b1538",
  copper = "#b8860b",
  
  -- Base colors (inverted for light mode)
  bg_dark = "#f5f0e8",
  bg_medium = "#ede3d3",
  bg_light = "#e0d0b8",
  fg_light = "#2d2416",
  fg_medium = "#5c4a38",
  fg_dark = "#8b7d6b",
}

local groups = {
  -- Base
  Normal = { fg = colors.fg_light, bg = colors.bg_dark },
  NormalFloat = { fg = colors.fg_light, bg = colors.bg_medium },
  FloatBorder = { fg = colors.ghana_gold, bg = colors.bg_medium },
  
  -- Cursor and selection
  Cursor = { fg = colors.bg_dark, bg = colors.ghana_red },
  CursorLine = { bg = colors.bg_medium },
  CursorColumn = { bg = colors.bg_medium },
  Visual = { bg = "#b8d4c2" }, -- Light green selection
  VisualNOS = { bg = "#a8c4b2" },
  
  -- Line numbers
  LineNr = { fg = colors.fg_dark },
  CursorLineNr = { fg = colors.ghana_gold, bold = true },
  SignColumn = { fg = colors.fg_dark, bg = colors.bg_dark },
  ColorColumn = { bg = colors.bg_medium },
  
  -- Search
  Search = { fg = colors.bg_dark, bg = "#e6d073" }, -- Light gold
  IncSearch = { fg = colors.bg_dark, bg = "#deb887" }, -- Light copper
  MatchParen = { fg = colors.ghana_red, bold = true },
  
  -- Status line
  StatusLine = { fg = colors.fg_light, bg = colors.bg_light },
  StatusLineNC = { fg = colors.fg_medium, bg = colors.bg_medium },
  TabLine = { fg = colors.fg_medium, bg = colors.bg_medium },
  TabLineFill = { bg = colors.bg_light },
  TabLineSel = { fg = colors.fg_light, bg = colors.bg_dark },
  
  -- Messages
  MsgArea = { fg = colors.fg_light, bg = colors.bg_dark },
  MsgSeparator = { fg = colors.ghana_gold, bg = colors.bg_medium },
  MoreMsg = { fg = colors.ghana_green },
  Question = { fg = colors.ghana_gold },
  WarningMsg = { fg = colors.copper },
  ErrorMsg = { fg = colors.ghana_red },
  
  -- Popup menu
  Pmenu = { fg = colors.fg_light, bg = colors.bg_medium },
  PmenuSel = { fg = colors.bg_dark, bg = "#e6d073" }, -- Light gold selection
  PmenuSbar = { bg = colors.bg_light },
  PmenuThumb = { bg = colors.ghana_gold },
  
  -- Folds and diffs
  Folded = { fg = colors.fg_medium, bg = colors.bg_medium },
  FoldColumn = { fg = colors.fg_dark, bg = colors.bg_dark },
  DiffAdd = { fg = colors.ghana_green, bg = "#d4f0dc" }, -- Very light green
  DiffChange = { fg = colors.ghana_gold, bg = "#f0edc4" }, -- Very light gold
  DiffDelete = { fg = colors.ghana_red, bg = "#f0d4d4" }, -- Very light red
  DiffText = { fg = colors.ghana_gold, bg = "#e6d073", bold = true },
  
  -- Spell
  SpellBad = { fg = colors.ghana_red, undercurl = true, sp = colors.ghana_red },
  SpellCap = { fg = colors.copper, undercurl = true, sp = colors.copper },
  SpellRare = { fg = colors.ghana_gold, undercurl = true, sp = colors.ghana_gold },
  SpellLocal = { fg = colors.ghana_green, undercurl = true, sp = colors.ghana_green },
  
  -- Window separators
  VertSplit = { fg = colors.bg_light },
  WinSeparator = { fg = colors.bg_light },
  
  -- Syntax highlighting
  Comment = { fg = colors.fg_dark, italic = true },
  
  Constant = { fg = colors.ghana_red },
  String = { fg = colors.ghana_green },
  Character = { fg = colors.ghana_green },
  Number = { fg = colors.copper },
  Boolean = { fg = colors.ghana_red },
  Float = { fg = colors.copper },
  
  Identifier = { fg = colors.fg_light },
  Function = { fg = colors.ghana_gold },
  
  Statement = { fg = colors.ghana_red, bold = true },
  Conditional = { fg = colors.ghana_red },
  Repeat = { fg = colors.ghana_red },
  Label = { fg = colors.ghana_red },
  Operator = { fg = colors.copper },
  Keyword = { fg = colors.ghana_red },
  Exception = { fg = colors.ghana_red },
  
  PreProc = { fg = colors.copper },
  Include = { fg = colors.copper },
  Define = { fg = colors.copper },
  Macro = { fg = colors.copper },
  PreCondit = { fg = colors.copper },
  
  Type = { fg = colors.ghana_gold },
  StorageClass = { fg = colors.ghana_gold },
  Structure = { fg = colors.ghana_gold },
  Typedef = { fg = colors.ghana_gold },
  
  Special = { fg = colors.copper },
  SpecialChar = { fg = colors.copper },
  Tag = { fg = colors.ghana_gold },
  Delimiter = { fg = colors.fg_medium },
  SpecialComment = { fg = colors.warm_brown, italic = true },
  Debug = { fg = colors.ghana_red },
  
  Underlined = { fg = colors.ghana_green, underline = true },
  Ignore = { fg = colors.fg_dark },
  Error = { fg = colors.ghana_red, bg = "#f0d4d4" },
  Todo = { fg = colors.bg_dark, bg = "#e6d073", bold = true },
  
  -- LSP
  DiagnosticError = { fg = colors.ghana_red },
  DiagnosticWarn = { fg = colors.copper },
  DiagnosticInfo = { fg = colors.ghana_green },
  DiagnosticHint = { fg = colors.fg_medium },
  DiagnosticOk = { fg = colors.ghana_green },
  
  DiagnosticUnderlineError = { undercurl = true, sp = colors.ghana_red },
  DiagnosticUnderlineWarn = { undercurl = true, sp = colors.copper },
  DiagnosticUnderlineInfo = { undercurl = true, sp = colors.ghana_green },
  DiagnosticUnderlineHint = { undercurl = true, sp = colors.fg_medium },
  DiagnosticUnderlineOk = { undercurl = true, sp = colors.ghana_green },
  
  -- Git signs
  GitSignsAdd = { fg = colors.ghana_green },
  GitSignsChange = { fg = colors.ghana_gold },
  GitSignsDelete = { fg = colors.ghana_red },
  
  -- Telescope
  TelescopeNormal = { fg = colors.fg_light, bg = colors.bg_medium },
  TelescopeBorder = { fg = colors.ghana_gold, bg = colors.bg_medium },
  TelescopePromptNormal = { fg = colors.fg_light, bg = colors.bg_light },
  TelescopePromptBorder = { fg = colors.ghana_gold, bg = colors.bg_light },
  TelescopePromptTitle = { fg = colors.bg_dark, bg = colors.ghana_gold, bold = true },
  TelescopePreviewTitle = { fg = colors.bg_dark, bg = colors.ghana_green, bold = true },
  TelescopeResultsTitle = { fg = colors.bg_dark, bg = colors.copper, bold = true },
  TelescopeSelection = { fg = colors.fg_light, bg = colors.bg_light },
  TelescopeSelectionCaret = { fg = colors.ghana_gold },
  TelescopeMultiSelection = { fg = colors.ghana_green },
  TelescopeMatching = { fg = colors.ghana_red, bold = true },
}

-- Apply all highlight groups
for group, settings in pairs(groups) do
  vim.api.nvim_set_hl(0, group, settings)
end