-- Ghana Cozy colorscheme (Simple Lua version)
-- A cozy dark theme inspired by the colors of the Ghanaian flag

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end

vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.g.colors_name = "ghana-cozy-simple"

-- Ghana-inspired color palette
local colors = {
  -- Ghana flag colors
  ghana_red = "#d14545",
  ghana_gold = "#e6b450", 
  ghana_green = "#4a7c59",
  
  -- Supporting colors
  warm_brown = "#5c4033",
  light_brown = "#8b6f47",
  cream = "#f0e6d2",
  dark_green = "#2d4a37",
  olive = "#6b6b47",
  burgundy = "#7a2d3a",
  copper = "#b85c36",
  
  -- Base colors
  bg_dark = "#2a2319",
  bg_medium = "#363028",
  bg_light = "#423b32",
  fg_light = "#f0e6d2",
  fg_medium = "#c4b49c",
  fg_dark = "#8b7d6b",
}

local groups = {
  -- Base
  Normal = { fg = colors.fg_light, bg = colors.bg_dark },
  NormalFloat = { fg = colors.fg_light, bg = colors.bg_medium },
  FloatBorder = { fg = colors.ghana_gold, bg = colors.bg_medium },
  
  -- Cursor and selection
  Cursor = { fg = colors.bg_dark, bg = colors.ghana_gold },
  CursorLine = { bg = colors.bg_medium },
  CursorColumn = { bg = colors.bg_medium },
  Visual = { bg = colors.dark_green },
  VisualNOS = { bg = colors.dark_green },
  
  -- Line numbers
  LineNr = { fg = colors.fg_dark },
  CursorLineNr = { fg = colors.ghana_gold, bold = true },
  SignColumn = { fg = colors.fg_dark, bg = colors.bg_dark },
  ColorColumn = { bg = colors.bg_medium },
  
  -- Search
  Search = { fg = colors.bg_dark, bg = colors.ghana_gold },
  IncSearch = { fg = colors.bg_dark, bg = colors.copper },
  MatchParen = { fg = colors.ghana_gold, bold = true },
  
  -- Status line
  StatusLine = { fg = colors.fg_light, bg = colors.bg_light },
  StatusLineNC = { fg = colors.fg_dark, bg = colors.bg_medium },
  TabLine = { fg = colors.fg_dark, bg = colors.bg_medium },
  TabLineFill = { bg = colors.bg_dark },
  TabLineSel = { fg = colors.fg_light, bg = colors.bg_light },
  
  -- Messages
  MsgArea = { fg = colors.fg_light, bg = colors.bg_dark },
  MsgSeparator = { fg = colors.ghana_gold, bg = colors.bg_medium },
  MoreMsg = { fg = colors.ghana_green },
  Question = { fg = colors.ghana_gold },
  WarningMsg = { fg = colors.copper },
  ErrorMsg = { fg = colors.ghana_red },
  
  -- Popup menu
  Pmenu = { fg = colors.fg_light, bg = colors.bg_medium },
  PmenuSel = { fg = colors.bg_dark, bg = colors.ghana_gold },
  PmenuSbar = { bg = colors.bg_light },
  PmenuThumb = { bg = colors.ghana_gold },
  
  -- Folds and diffs
  Folded = { fg = colors.fg_dark, bg = colors.bg_medium },
  FoldColumn = { fg = colors.fg_dark, bg = colors.bg_dark },
  DiffAdd = { fg = colors.ghana_green, bg = colors.dark_green },
  DiffChange = { fg = colors.ghana_gold, bg = colors.olive },
  DiffDelete = { fg = colors.ghana_red, bg = colors.burgundy },
  DiffText = { fg = colors.ghana_gold, bg = colors.olive, bold = true },
  
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
  Error = { fg = colors.ghana_red, bg = colors.burgundy },
  Todo = { fg = colors.bg_dark, bg = colors.ghana_gold, bold = true },
  
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
  TelescopeMatching = { fg = colors.ghana_gold, bold = true },
}

-- Apply all highlight groups
for group, settings in pairs(groups) do
  vim.api.nvim_set_hl(0, group, settings)
end