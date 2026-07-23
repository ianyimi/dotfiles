-- Ghana-inspired cozy colorscheme (Light Mode) using Lush.nvim
-- Colors inspired by the Ghanaian flag: red, gold, green
-- Light version with warm tones for a cozy feel

local lush = require('lush')
local hsl = lush.hsl

-- Define the Ghana-inspired color palette for light mode
local ghana_red = hsl(355, 65, 45)      -- Deep red from flag
local ghana_gold = hsl(45, 70, 50)      -- Rich golden yellow from flag  
local ghana_green = hsl(140, 50, 35)    -- Deep forest green from flag

-- Cozy supporting colors for light mode
local warm_brown = hsl(25, 40, 30)      -- Rich chocolate brown
local light_brown = hsl(30, 35, 65)     -- Light warm brown
local cream = hsl(45, 30, 25)           -- Dark cream for text
local dark_green = hsl(145, 45, 25)     -- Very dark forest green
local olive = hsl(60, 25, 40)           -- Muted olive green
local burgundy = hsl(350, 55, 30)       -- Deep burgundy red
local copper = hsl(15, 55, 40)          -- Warm copper accent

-- Base background and foreground for light mode
local bg_dark = hsl(45, 25, 95)         -- Very light warm cream
local bg_medium = hsl(40, 20, 90)       -- Light warm grey
local bg_light = hsl(35, 15, 85)        -- Medium light grey
local fg_light = hsl(25, 15, 20)        -- Very dark warm text
local fg_medium = hsl(30, 12, 35)       -- Medium dark grey
local fg_dark = hsl(35, 8, 55)          -- Lighter grey for less important text

-- Define the light colorscheme
local theme = lush(function(injected_functions)
  local sym = injected_functions.sym
  return {
    -- Base colors
    Normal       { fg = fg_light, bg = bg_dark },
    NormalFloat  { fg = fg_light, bg = bg_medium },
    FloatBorder  { fg = ghana_gold, bg = bg_medium },
    
    -- Cursor and selection
    Cursor       { fg = bg_dark, bg = ghana_red },
    CursorLine   { bg = bg_medium },
    CursorColumn { bg = bg_medium },
    Visual       { bg = ghana_green.lighten(30) },
    VisualNOS    { bg = ghana_green.lighten(25) },
    
    -- Line numbers and columns
    LineNr       { fg = fg_dark },
    CursorLineNr { fg = ghana_gold.darken(10), gui = "bold" },
    SignColumn   { fg = fg_dark, bg = bg_dark },
    ColorColumn  { bg = bg_medium },
    
    -- Search and matching
    Search       { fg = bg_dark, bg = ghana_gold.lighten(20) },
    IncSearch    { fg = bg_dark, bg = copper.lighten(20) },
    MatchParen   { fg = ghana_red, gui = "bold" },
    
    -- Status and tab lines
    StatusLine   { fg = fg_light, bg = bg_light },
    StatusLineNC { fg = fg_medium, bg = bg_medium },
    TabLine      { fg = fg_medium, bg = bg_medium },
    TabLineFill  { bg = bg_light },
    TabLineSel   { fg = fg_light, bg = bg_dark },
    
    -- Messages and prompts
    MsgArea      { fg = fg_light, bg = bg_dark },
    MsgSeparator { fg = ghana_gold, bg = bg_medium },
    MoreMsg      { fg = ghana_green },
    Question     { fg = ghana_gold.darken(10) },
    WarningMsg   { fg = copper },
    ErrorMsg     { fg = ghana_red },
    
    -- Popup menus
    Pmenu        { fg = fg_light, bg = bg_medium },
    PmenuSel     { fg = bg_dark, bg = ghana_gold.lighten(15) },
    PmenuSbar    { bg = bg_light },
    PmenuThumb   { bg = ghana_gold },
    
    -- Folds and diffs
    Folded       { fg = fg_medium, bg = bg_medium },
    FoldColumn   { fg = fg_dark, bg = bg_dark },
    DiffAdd      { fg = ghana_green.darken(10), bg = ghana_green.lighten(40) },
    DiffChange   { fg = ghana_gold.darken(10), bg = ghana_gold.lighten(35) },
    DiffDelete   { fg = ghana_red.darken(5), bg = ghana_red.lighten(35) },
    DiffText     { fg = ghana_gold.darken(15), bg = ghana_gold.lighten(25), gui = "bold" },
    
    -- Spell checking
    SpellBad     { fg = ghana_red, gui = "undercurl", sp = ghana_red },
    SpellCap     { fg = copper, gui = "undercurl", sp = copper },
    SpellRare    { fg = ghana_gold.darken(10), gui = "undercurl", sp = ghana_gold },
    SpellLocal   { fg = ghana_green, gui = "undercurl", sp = ghana_green },
    
    -- Window separators
    VertSplit    { fg = bg_light },
    WinSeparator { fg = bg_light },
    
    -- Syntax highlighting
    Comment      { fg = fg_dark, gui = "italic" },
    
    Constant     { fg = ghana_red },
    String       { fg = ghana_green },
    Character    { fg = ghana_green },
    Number       { fg = copper },
    Boolean      { fg = ghana_red },
    Float        { fg = copper },
    
    Identifier   { fg = fg_light },
    Function     { fg = ghana_gold.darken(5) },
    
    Statement    { fg = ghana_red, gui = "bold" },
    Conditional  { fg = ghana_red },
    Repeat       { fg = ghana_red },
    Label        { fg = ghana_red },
    Operator     { fg = copper },
    Keyword      { fg = ghana_red },
    Exception    { fg = ghana_red },
    
    PreProc      { fg = copper },
    Include      { fg = copper },
    Define       { fg = copper },
    Macro        { fg = copper },
    PreCondit    { fg = copper },
    
    Type         { fg = ghana_gold.darken(5) },
    StorageClass { fg = ghana_gold.darken(5) },
    Structure    { fg = ghana_gold.darken(5) },
    Typedef      { fg = ghana_gold.darken(5) },
    
    Special      { fg = copper },
    SpecialChar  { fg = copper },
    Tag          { fg = ghana_gold.darken(5) },
    Delimiter    { fg = fg_medium },
    SpecialComment { fg = warm_brown, gui = "italic" },
    Debug        { fg = ghana_red },
    
    Underlined   { fg = ghana_green, gui = "underline" },
    Ignore       { fg = fg_dark },
    Error        { fg = ghana_red, bg = ghana_red.lighten(35) },
    Todo         { fg = bg_dark, bg = ghana_gold.lighten(15), gui = "bold" },
    
    -- LSP
    DiagnosticError { fg = ghana_red },
    DiagnosticWarn  { fg = copper },
    DiagnosticInfo  { fg = ghana_green },
    DiagnosticHint  { fg = fg_medium },
    DiagnosticOk    { fg = ghana_green },
    
    DiagnosticUnderlineError { gui = "undercurl", sp = ghana_red },
    DiagnosticUnderlineWarn  { gui = "undercurl", sp = copper },
    DiagnosticUnderlineInfo  { gui = "undercurl", sp = ghana_green },
    DiagnosticUnderlineHint  { gui = "undercurl", sp = fg_medium },
    DiagnosticUnderlineOk    { gui = "undercurl", sp = ghana_green },
    
    -- Tree-sitter
    sym"@variable"           { fg = fg_light },
    sym"@variable.builtin"   { fg = ghana_red },
    sym"@variable.parameter" { fg = fg_medium },
    sym"@variable.member"    { fg = fg_light },
    
    sym"@constant"           { Constant },
    sym"@constant.builtin"   { fg = ghana_red },
    sym"@constant.macro"     { PreProc },
    
    sym"@string"             { String },
    sym"@string.escape"      { fg = copper },
    sym"@string.special"     { Special },
    
    sym"@character"          { Character },
    sym"@character.special"  { SpecialChar },
    
    sym"@number"             { Number },
    sym"@number.float"       { Float },
    
    sym"@boolean"            { Boolean },
    
    sym"@function"           { Function },
    sym"@function.builtin"   { fg = ghana_gold.darken(10), gui = "bold" },
    sym"@function.call"      { Function },
    sym"@function.macro"     { PreProc },
    
    sym"@method"             { Function },
    sym"@method.call"        { Function },
    
    sym"@constructor"        { fg = ghana_gold.darken(5) },
    
    sym"@parameter"          { fg = fg_medium },
    
    sym"@keyword"            { Keyword },
    sym"@keyword.function"   { fg = ghana_red },
    sym"@keyword.operator"   { Operator },
    sym"@keyword.return"     { fg = ghana_red, gui = "bold" },
    sym"@keyword.conditional"{ Conditional },
    sym"@keyword.repeat"     { Repeat },
    sym"@keyword.import"     { Include },
    sym"@keyword.exception"  { Exception },
    
    sym"@operator"           { Operator },
    
    sym"@punctuation.delimiter" { Delimiter },
    sym"@punctuation.bracket"   { fg = fg_medium },
    sym"@punctuation.special"   { Special },
    
    sym"@comment"            { Comment },
    sym"@comment.documentation" { fg = warm_brown, gui = "italic" },
    sym"@comment.error"      { fg = ghana_red, gui = "bold" },
    sym"@comment.warning"    { fg = copper, gui = "bold" },
    sym"@comment.todo"       { Todo },
    sym"@comment.note"       { fg = ghana_green, gui = "bold" },
    
    sym"@type"               { Type },
    sym"@type.builtin"       { fg = ghana_gold.darken(10), gui = "bold" },
    sym"@type.definition"    { Typedef },
    
    sym"@attribute"          { PreProc },
    sym"@property"           { fg = fg_light },
    
    sym"@label"              { Label },
    
    sym"@namespace"          { fg = copper },
    
    sym"@tag"                { Tag },
    sym"@tag.attribute"      { fg = ghana_gold.darken(5) },
    sym"@tag.delimiter"      { Delimiter },
    
    -- Git signs
    GitSignsAdd              { fg = ghana_green },
    GitSignsChange           { fg = ghana_gold.darken(10) },
    GitSignsDelete           { fg = ghana_red },
    
    -- Telescope
    TelescopeNormal          { fg = fg_light, bg = bg_medium },
    TelescopeBorder          { fg = ghana_gold.darken(10), bg = bg_medium },
    TelescopePromptNormal    { fg = fg_light, bg = bg_light },
    TelescopePromptBorder    { fg = ghana_gold.darken(10), bg = bg_light },
    TelescopePromptTitle     { fg = bg_dark, bg = ghana_gold.darken(5), gui = "bold" },
    TelescopePreviewTitle    { fg = bg_dark, bg = ghana_green.darken(5), gui = "bold" },
    TelescopeResultsTitle    { fg = bg_dark, bg = copper.darken(5), gui = "bold" },
    TelescopeSelection       { fg = fg_light, bg = bg_light },
    TelescopeSelectionCaret  { fg = ghana_gold.darken(10) },
    TelescopeMultiSelection  { fg = ghana_green },
    TelescopeMatching        { fg = ghana_red, gui = "bold" },
    
    -- Which-key
    WhichKey                 { fg = ghana_gold.darken(10) },
    WhichKeyGroup            { fg = ghana_green },
    WhichKeyDesc             { fg = fg_light },
    WhichKeySeperator        { fg = fg_dark },
    WhichKeyFloat            { bg = bg_medium },
    WhichKeyBorder           { fg = ghana_gold.darken(10), bg = bg_medium },
    
    -- Lualine
    lualine_a_normal         { fg = bg_dark, bg = ghana_gold.darken(5), gui = "bold" },
    lualine_a_insert         { fg = bg_dark, bg = ghana_green, gui = "bold" },
    lualine_a_visual         { fg = bg_dark, bg = copper, gui = "bold" },
    lualine_a_replace        { fg = bg_dark, bg = ghana_red, gui = "bold" },
    lualine_a_command        { fg = bg_dark, bg = burgundy, gui = "bold" },
    
    -- Oil file manager
    OilDir                   { fg = ghana_gold.darken(10), gui = "bold" },
    OilDirIcon               { fg = ghana_gold.darken(10) },
    OilLink                  { fg = ghana_green, gui = "underline" },
    OilLinkTarget            { fg = fg_medium },
    OilCopy                  { fg = copper },
    OilMove                  { fg = ghana_green },
    OilChange                { fg = ghana_gold.darken(10) },
    OilCreate                { fg = ghana_green },
    OilDelete                { fg = ghana_red },
    OilPermissionNone        { fg = fg_dark },
    OilPermissionRead        { fg = fg_medium },
    OilPermissionWrite       { fg = copper },
    OilPermissionExecute     { fg = ghana_green },
  }
end)

return theme