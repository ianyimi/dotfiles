# Neovim Configuration - Claude Context

This is a personal Neovim configuration for a single developer, managed entirely by chezmoi. This document provides essential context so you don't need repeated explanations about the project setup.

## Critical: Chezmoi Workflow

**YOU ARE CURRENTLY IN THE CHEZMOI SOURCE DIRECTORY**, not the live Neovim config!

- **Source Directory (WHERE YOU ARE):** `/Users/zaye/.local/share/chezmoi/dot_config/nvim`
- **Target Directory (Live config):** `~/.config/nvim`
- **Workflow:**
  1. You make changes HERE in the source directory
  2. User manually runs `chezmoi apply` to test changes in live config
  3. Changes hot-reload automatically when applied
  4. User verifies everything works before committing

**NEVER** suggest making changes directly in `~/.config/nvim` - all changes must be made in the chezmoi source directory where you are now.

## Project Overview

### What This Is
A personal Neovim configuration based on a stripped-down LazyVim starter with custom plugins. It's assembled from various online configs, tutorials, and personal experimentation. This is NOT a distribution - it's optimized for one person's specific workflows.

### What Makes It Special
- **Managed by chezmoi:** Provides a safe staging environment for config changes
- **Custom Ghana Cozy themes:** Dark, light, and simple variants built with Shipwright
- **AI-native integration:** Avante and OpenCode as first-class features
- **Git worktree workflow:** Per-worktree session management and telescope integration
- **Performance-focused:** Lazy loading with built-in benchmarking

### Recent Focus Areas
Check `git status`, `git diff`, and `git log` at the start of any work to understand recent changes. Recent work includes:
- Ghana Cozy colorscheme development and export
- OpenCode AI integration
- LSP config modernization
- LSP keybind persistence (preventing loss on restart)
- Buffer management (using barbar.nvim with Harpoon integration)

## Project Structure

```
. (YOU ARE HERE: ~/.local/share/chezmoi/dot_config/nvim)
├── init.lua                    # Entry point (requires config.lazy)
├── AGENTS.md                   # Detailed codebase guide for agents
├── agent-os/product/           # Product documentation
│   ├── mission.md             # Product vision and purpose
│   ├── roadmap.md             # Development roadmap
│   └── tech-stack.md          # Comprehensive technical details
├── lua/
│   ├── config/                # Core configuration
│   │   ├── lazy.lua          # lazy.nvim bootstrap & plugin imports
│   │   ├── options.lua       # Vim options
│   │   ├── keymaps.lua       # Global keybindings
│   │   └── autocmds.lua      # Autocommands
│   ├── plugins/              # Plugin configurations
│   │   ├── lsp/             # Language servers, Mason, completion
│   │   ├── editor/          # Text editing, navigation, file mgmt
│   │   ├── ui/              # Statusline, themes, notifications
│   │   ├── ai/              # Avante, OpenCode
│   │   ├── coding/          # Snippets, pairs, text objects
│   │   ├── formatting/      # Conform.nvim
│   │   └── util/            # Misc utilities
│   ├── util/                 # Custom Lua utilities (LazyVim helpers)
│   └── colorschemes/        # Custom theme definitions
└── colors/                   # Vim colorscheme files
```

## Tech Stack Essentials

### Core
- **Language:** Lua only
- **Plugin Manager:** lazy.nvim with lazy loading
- **LSP:** Mason + nvim-lspconfig + mason-lspconfig
- **Completion:** nvim-cmp with multiple sources
- **Treesitter:** Syntax highlighting and code parsing
- **Telescope:** Fuzzy finding for everything

### Key Plugins by Category
- **LSP:** nvim-lspconfig, Mason, fidget.nvim, lspkind, tailwind-tools
- **Completion:** nvim-cmp, LuaSnip, friendly-snippets, cmp-nvim-lsp
- **Editor:** Telescope, Harpoon2, mini.files, oil.nvim, grug-far, which-key
- **Git:** gitsigns, diffview, git-worktree
- **UI:** lualine, noice, nvim-notify, indent-blankline, satellite, Huez
- **AI:** avante.nvim, OpenCode
- **Themes:** Ghana Cozy (custom), TokyoNight, and others

### Utilities
- Global `LazyVim` object provides utility functions (defined in `lua/util/init.lua`)
- Custom utilities in `lua/util/` for LSP, formatting, terminals, pickers, etc.

## Code Style Rules

### Lua Conventions
- **Indentation:** Tabs (not spaces), tab size = 2
- **Naming:** snake_case for variables/functions, PascalCase for modules
- **Imports:** `require()` at top, use local assignments
- **Errors:** Use `pcall()` for risky operations
- **Comments:** `--` for single line, `---@` for type annotations
- **Tables:** Trailing commas on multi-line tables
- **Strings:** Double quotes for user text, single for internal

### Plugin Spec Pattern
```lua
return {
  "author/plugin",
  event = "VeryLazy",  -- Lazy load trigger
  dependencies = { "other/plugin" },
  opts = {
    -- options table
  },
  config = function(_, opts)
    require("plugin").setup(opts)
  end,
}
```

## Critical Rules for Agents

### NEVER Remove Functionality
**DO NOT** remove functionality when fixing bugs unless:
1. User explicitly requests removal, OR
2. The removed code is clearly a failed implementation attempt AND new implementation is confirmed working

When fixing issues, identify root cause and fix minimally. Preserve existing features when refactoring. If unsure whether to remove something, ask first.

### Always Check Git First
Before starting ANY work:
```bash
git status   # See untracked files and changes
git diff     # See what's modified
git log -5   # See recent commits and patterns
```

This provides crucial context about recent work and ongoing changes.

### Testing Changes
1. Make changes in this directory (chezmoi source)
2. User runs `chezmoi apply` to sync to live config
3. User tests in Neovim
4. Only commit when confirmed working

### File Organization
- Group plugins by function in `lua/plugins/*/`
- Put reusable utilities in `lua/util/`
- Follow existing patterns in the codebase
- Maintain lazy loading for performance

## Common Operations

### Testing & Validation
- **Health check:** `:checkhealth`
- **Plugin UI:** `:Lazy`
- **LSP servers:** `:Mason`
- **Startup perf:** `:StartupBenchLog`

### Theme Development
- **Export:** `:Shipwright` or `:lua require('export-ghana-cozy')`
- **Setup:** `:lua require('setup-ghana-cozy')`
- **Switch:** `:colorscheme ghana-cozy` (or -light, -simple variants)

### Git Integration
- Git worktrees managed via Telescope and git-worktree.nvim
- Per-worktree Shada files (configured in options.lua)
- Lazygit integration for TUI

## When Making Changes

### For Code Changes
1. Read existing code to understand patterns
2. Follow established conventions
3. Maintain lazy loading where appropriate
4. Test thoroughly before user applies changes
5. Document complex logic with comments

### For New Features
1. Check if similar functionality exists in `util/` or other plugins
2. Place in appropriate `plugins/` subdirectory
3. Use lazy loading with appropriate triggers
4. Add keybindings and which-key descriptions
5. Update documentation if significant

### For Bug Fixes
1. Understand the full context (check git history)
2. Identify root cause, not just symptoms
3. Fix minimally without breaking other features
4. Verify the fix doesn't remove functionality
5. Test edge cases

## Quick Reference

### File Paths
- Always use absolute paths starting with `/Users/zaye/`
- No relative paths in scripts or configurations
- You are in: `/Users/zaye/.local/share/chezmoi/dot_config/nvim`

### Key Files to Reference
- **`AGENTS.md`** - Detailed codebase guide and style rules
- **`agent-os/product/tech-stack.md`** - Complete technical details
- **`lua/config/lazy.lua`** - Plugin loading and imports
- **`lua/config/options.lua`** - All vim options
- **`lua/util/init.lua`** - LazyVim utilities

### Performance
- Startup time matters - maintain lazy loading
- Big file threshold: 1.5MB (LSP/treesitter disabled)
- Use `:StartupBenchLog` to check performance impact

### Platform
- macOS (Darwin 24.6.0)
- Nerd Font required for icons
- Clipboard integration with system clipboard

## Documentation References

For deeper dives into specific topics:
- **Product vision:** `agent-os/product/mission.md`
- **Future plans:** `agent-os/product/roadmap.md`
- **Full tech details:** `agent-os/product/tech-stack.md`
- **Codebase guide:** `AGENTS.md`

## Remember

This is a PERSONAL config for ONE user. It's not trying to be a distribution. Make changes that serve the owner's specific needs and workflows. Maintain the quality and organization that makes this config maintainable over time.

When in doubt:
1. Check existing code for patterns
2. Review git history for context
3. Ask the user before removing functionality
4. Test in the chezmoi workflow (source → apply → test)
