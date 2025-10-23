# Tech Stack

This document provides comprehensive technical details about the Neovim configuration to help AI agents write better, more contextually appropriate code.

## Core Technologies

### Neovim
- **Version:** Latest stable (0.10+)
- **Language:** Lua for all configuration
- **Platform:** macOS (Darwin 24.6.0)
- **Package Manager:** lazy.nvim

### Dotfile Management
- **Tool:** chezmoi
- **Workflow:** Changes made in `~/.local/share/chezmoi/dot_config/nvim` then applied via `chezmoi apply`
- **Source Directory:** `/Users/zaye/.local/share/chezmoi/dot_config/nvim`
- **Target Directory:** `~/.config/nvim` (after `chezmoi apply`)
- **Integration:** Automatic file type detection and syntax highlighting via chezmoi.nvim and chezmoi.vim plugins

## Project Structure

```
~/.local/share/chezmoi/dot_config/nvim/
├── init.lua                    # Entry point (bootstraps lazy.nvim)
├── lazy-lock.json              # Plugin version lockfile
├── AGENTS.md                   # Documentation for AI agents
├── agent-os/                   # Agent OS product documentation
│   └── product/
│       ├── mission.md
│       ├── roadmap.md
│       └── tech-stack.md
├── .claude/                    # Claude Code configuration
│   ├── agents/                 # Custom agent definitions
│   ├── commands/               # Custom commands
│   ├── skills/                 # Reusable skills
│   └── settings.local.json     # Local settings
├── lua/
│   ├── config/
│   │   ├── init.lua           # Main config initialization
│   │   ├── lazy.lua           # Lazy.nvim bootstrap & setup
│   │   ├── options.lua        # Vim options & settings
│   │   ├── keymaps.lua        # Global keybindings
│   │   └── autocmds.lua       # Autocommands
│   ├── plugins/
│   │   ├── lsp/               # LSP configurations
│   │   ├── editor/            # Editor enhancement plugins
│   │   ├── ui/                # UI/visual plugins
│   │   ├── ai/                # AI coding assistants
│   │   ├── coding/            # Code editing plugins
│   │   ├── formatting/        # Formatters
│   │   └── util/              # Utility plugins
│   ├── util/                  # Custom Lua utilities
│   │   ├── init.lua           # LazyVim utilities entrypoint
│   │   ├── lsp.lua            # LSP helpers
│   │   ├── format.lua         # Formatting utilities
│   │   ├── pick.lua           # Picker utilities
│   │   ├── terminal.lua       # Terminal helpers
│   │   └── ...                # Other utility modules
│   ├── colorschemes/          # Custom colorscheme definitions
│   ├── setup-ghana-cozy.lua   # Ghana Cozy theme setup
│   └── export-ghana-cozy.lua  # Theme export utilities
├── colors/                     # Vim colorscheme files
├── queries/                    # Custom treesitter queries
└── shipwright_build.lua        # Colorscheme build configuration
```

## Plugin Management

### lazy.nvim
- **Lazy Loading:** Plugins loaded via `event`, `cmd`, `ft`, or `keys` triggers
- **Performance:** Startup benchmarking built-in (see `:StartupBenchLog`)
- **Updates:** Auto-check enabled, notify disabled
- **Spec Import:** Plugins imported by category from `lua/plugins/*`

### Plugin Organization
Plugins are organized into functional categories:
- `plugins/lsp/` - Language server configurations, Mason, completion
- `plugins/editor/` - Text manipulation, navigation, file management
- `plugins/ui/` - Visual enhancements, statusline, notifications
- `plugins/ai/` - AI coding assistants (Avante, OpenCode)
- `plugins/coding/` - Code editing helpers (snippets, pairs, surround)
- `plugins/formatting/` - Code formatters (conform.nvim)
- `plugins/util/` - Miscellaneous utilities

## Language Server Protocol (LSP)

### LSP Stack
- **Server Manager:** Mason.nvim - automatic installation of LSP servers, formatters, linters
- **LSP Configuration:** nvim-lspconfig - server configurations and setup
- **LSP Bridge:** mason-lspconfig.nvim - automatic setup of Mason-installed servers
- **Progress UI:** fidget.nvim - LSP progress notifications with message mirroring to `:messages`

### Installed Language Servers
Based on `lazy-lock.json` and typical configuration:
- TypeScript/JavaScript: `tsserver` or `ts_ls`
- Go: `gopls`
- Lua: `lua_ls`
- Tailwind CSS: `tailwindcss` with tailwind-tools.nvim integration
- And others installed via Mason

### LSP Features
- **Diagnostics:** Inline diagnostics with customizable display
- **Code Actions:** Quick fixes and refactoring via LSP
- **Hover Documentation:** Type information and docs on hover
- **Go to Definition:** Navigate to symbol definitions
- **References:** Find all references to symbols
- **Rename:** Smart rename with preview
- **Format:** Format via LSP or external formatters

## Completion

### nvim-cmp
- **Sources:**
  - `cmp-nvim-lsp` - LSP completion
  - `cmp-buffer` - Buffer text completion
  - `cmp-path` - Filesystem path completion
  - `cmp-cmdline` - Command line completion
  - `cmp_luasnip` - Snippet completion
- **Snippets:** LuaSnip with friendly-snippets
- **UI:** lspkind.nvim for icons and formatting

## Syntax & Parsing

### Treesitter
- **Plugin:** nvim-treesitter
- **Features:**
  - Advanced syntax highlighting
  - Code folding
  - Incremental selection
  - Indentation
  - Context display (via nvim-treesitter-context)
- **Auto-tag:** nvim-ts-autotag for HTML/JSX tag closing
- **Comments:** ts-comments.nvim for language-aware commenting

## File Navigation & Search

### Telescope
- **Core:** telescope.nvim with fzf-native for performance
- **Pickers:**
  - File finder (respects gitignore)
  - Live grep
  - LSP symbols, references, definitions
  - Git worktrees (via git-worktree.nvim)
  - Tmuxinator sessions (via telescope-tmuxinator.nvim)
  - Colorscheme picker (via Huez)
- **UI:** telescope-ui-select for vim.ui.select replacement

### File Explorers
- **mini.files** - Modern, minimal file explorer
- **oil.nvim** - Edit filesystem like a buffer

### Quick Navigation
- **Harpoon2** - Mark and quickly jump between important files
- **vim-tmux-navigator** - Seamless tmux/vim pane navigation

## Git Integration

### Core Git Plugins
- **gitsigns.nvim** - Git signs in gutter, inline blame, hunk operations
- **diffview.nvim** - Advanced diff and merge tool
- **git-worktree.nvim** - Git worktree management with Telescope integration

### Git Features
- Per-worktree Shada files (configured in `options.lua`)
- Git branch/worktree detection for session management
- Inline git operations and conflict resolution

## Terminal & Session Management

### Terminal
- **Built-in Terminal:** Neovim's native terminal with custom utilities in `util/terminal.lua`
- **Lazygit:** Git TUI integration (config enabled via `vim.g.lazygit_config`)

### Tmux Integration
- **vim-tmux-navigator:** Consistent keybindings for pane navigation across vim and tmux
- **telescope-tmuxinator.nvim:** Quick access to tmuxinator sessions

### Session Management
- Git worktree-aware Shada files for per-project session state
- Automatic session/state isolation by branch/worktree

## UI & Visuals

### Statusline
- **lualine.nvim** - Fast, customizable statusline
- **Custom Components:** Extended via `util/lualine.lua`

### Notifications & Messages
- **noice.nvim** - Modern command line, messages, and popupmenu UI
- **nvim-notify** - Notification manager with Fidget integration
- **Message Mirroring:** All notifications and LSP progress messages copied to `:messages` for copyability

### Visual Enhancements
- **indent-blankline.nvim** - Indentation guides
- **satellite.nvim** - Scrollbar with git/diagnostic indicators
- **mini.icons** - File type icons (requires Nerd Font)
- **nvim-web-devicons** - Additional icon support

### Color Schemes
- **Primary:** Ghana Cozy (custom, with dark/light/simple variants)
- **Fallback:** TokyoNight
- **Theme Picker:** Huez.nvim for quick switching
- **Auto Dark Mode:** System-aware theme switching via auto-dark-mode.nvim
- **Other Themes:** Aquarium, Adwaita, Juliana, Distinct (available via Huez)

### Markdown Rendering
- **render-markdown.nvim** - Beautiful in-buffer markdown rendering
- **img-clip.nvim** - Image pasting support for markdown

## AI Integration

### AI Coding Assistants
- **avante.nvim** - AI coding assistant with inline suggestions
- **OpenCode** - Additional AI tooling (custom plugin in `plugins/ai/opencode.lua`)

### AI Workflow
- Integrated into daily coding workflow as first-class features
- Custom keybindings and configurations for efficient interaction
- Toggle support for enabling/disabling when not needed

## Code Editing & Manipulation

### Text Objects & Motions
- **mini.ai** - Extended text objects (currently disabled)
- **nvim-surround** - Manipulate surrounding characters (quotes, brackets, tags)

### Auto-pairs & Completion
- **mini.pairs** - Automatic bracket/quote pairing
- **nvim-ts-autotag** - Auto-close and rename HTML/JSX tags

### Snippets
- **LuaSnip** - Snippet engine with jsregexp support
- **friendly-snippets** - Collection of common snippets for many languages

## Formatting & Linting

### Formatter
- **conform.nvim** - Async formatting with multiple formatter support
- **Integration:** Format on save, manual format commands, range formatting

### Error Translation
- **ts-error-translator.nvim** - Human-readable TypeScript error messages

## Utility Plugins

### Which-key
- **which-key.nvim** - Discoverable keybindings with popup help
- **Integration:** Used throughout config for documenting keybinding groups

### Search & Replace
- **grug-far.nvim** - Advanced project-wide search and replace with live preview

### Snacks.nvim
- Collection of small, useful utilities (recently added to config)

## Code Style

### Lua Configuration
- **Indentation:** Tabs (not spaces), tab size = 2
- **Naming Conventions:**
  - `snake_case` for variables and functions
  - `PascalCase` for modules/classes
- **Imports:** `require()` at top of file, prefer local assignments
- **Error Handling:** Use `pcall()` for risky operations
- **Comments:** `--` for single line, `---@` for type annotations (lua-language-server)
- **Strings:** Double quotes for user-facing text, single quotes for internal strings
- **Tables:** Trailing commas preferred for multi-line tables

### Plugin Specification Pattern
```lua
return {
  "author/plugin-name",
  event = "VeryLazy",  -- or cmd, ft, keys for lazy loading
  dependencies = { "other/plugin" },
  opts = {
    -- plugin options
  },
  config = function(_, opts)
    -- plugin setup
  end,
}
```

### Global Utilities
- **LazyVim Utilities:** Available via `LazyVim` global (defined in `lua/util/init.lua`)
- **Vim API:** Always use `vim.*` API, never deprecated `vim.fn` where modern alternatives exist

## Performance Optimization

### Startup Benchmarking
- **Built-in Logging:** Custom boot logger tracks load times
- **Access Logs:** `:StartupBenchLog` command opens detailed startup log
- **Cache Location:** `~/.local/share/nvim/cache/startup-bench.log`

### Lazy Loading Strategy
- Most plugins loaded on-demand via events, commands, or filetypes
- Critical path (options, keymaps) loaded before lazy.nvim setup
- Autocmds loaded after plugin initialization

### Performance Considerations
- Big file detection (1.5MB threshold) disables heavy features
- Per-worktree Shada files reduce memory overhead
- Treesitter queries cached per filetype

## Vim Options

### Key Settings (from `config/options.lua`)
- **Leader:** `<Space>`
- **Local Leader:** `\`
- **Line Numbers:** Relative + absolute
- **Tabs:** Tab characters with 2-space width
- **Clipboard:** System clipboard integration (with SSH detection)
- **Scrolloff:** `999` (keep cursor centered)
- **Undo:** Persistent undo with 10000 levels
- **Search:** Case-insensitive unless uppercase present
- **Cursor:** Cursorline and cursorcolumn enabled
- **Splits:** Open below and right by default

## Testing & Validation

### Health Checks
- **Command:** `:checkhealth`
- **Usage:** Verify LSP, treesitter, and plugin configurations

### Plugin Management
- **Lazy UI:** `:Lazy` for plugin operations (install, update, clean, profile)
- **Mason UI:** `:Mason` for LSP server management

### Theme Development
- **Export Command:** `:Shipwright` or `:lua require('export-ghana-cozy')`
- **Setup Command:** `:lua require('setup-ghana-cozy')`

## External Dependencies

### Required
- **Neovim:** 0.10+
- **Git:** For plugin management and version control
- **Nerd Font:** For icons (configured via `vim.g.have_nerd_font = true`)
- **chezmoi:** For dotfile management

### Optional but Recommended
- **ripgrep:** For fast grep in Telescope
- **fd:** For fast file finding in Telescope
- **lazygit:** For Git TUI
- **tmux:** For terminal multiplexing
- **tmuxinator:** For session management

### Build Dependencies
- **C Compiler:** For telescope-fzf-native.nvim (native FZF sorting)
- **Make:** For LuaSnip jsregexp installation

## Platform-Specific Notes

### macOS
- Running on Darwin 24.6.0
- System clipboard integration enabled
- Auto dark mode detection available
- No Windows-specific workarounds needed

### File Paths
- Always use absolute paths starting with `/Users/zaye/`
- No relative path usage in tooling or scripts
- Chezmoi source directory is primary working location
