# Product Mission

## Pitch
This is a personal Neovim configuration managed by chezmoi that helps a single developer maintain a highly customized, efficient development environment by providing an organized, modular plugin architecture and seamless dotfile management workflow.

## Users

### Primary Customer
- **Solo Developer**: The owner of this configuration, using it exclusively for their personal development needs

### User Persona
**Software Developer** (Professional)
- **Role:** Full-stack developer working across multiple languages and projects
- **Context:** Uses tmux, terminal-based workflows, and needs rapid context switching between projects
- **Pain Points:**
  - Configuration changes need to be tested before applying system-wide
  - Need to maintain consistency across multiple machines
  - Want specialized tooling for specific workflows (AI integration, color schemes, project management)
  - Difficult to iterate on config without breaking working setup
- **Goals:**
  - Make incremental improvements to development workflow without disruption
  - Keep configuration portable and version-controlled
  - Efficiently switch between projects and contexts
  - Integrate modern AI coding tools seamlessly

## The Problem

### Configuration Management Without Breaking Production
Making changes to a live Neovim configuration risks breaking the developer's primary work environment. Testing configuration changes in isolation before applying them system-wide is critical but challenging with traditional dotfile approaches.

**Our Solution:** Use chezmoi's source directory workflow where agents make changes in `~/.local/share/chezmoi/dot_config/nvim`, allowing the user to review, test, and selectively apply changes with `chezmoi apply` only after verification.

### Maintaining Complex Custom Configuration Over Time
Personal Neovim configurations grow organically, becoming difficult to understand and maintain. Without clear documentation and structure, even the owner can forget why certain plugins were chosen or how features work together.

**Our Solution:** Comprehensive documentation in `AGENTS.md`, organized plugin structure by category (lsp/, editor/, ui/, ai/, etc.), and custom utility functions in the `util/` directory that provide reusable abstractions.

## Differentiators

### Chezmoi-First Workflow
Unlike standard Neovim distributions, this configuration is designed specifically for chezmoi's workflow. All changes happen in the source directory first, enabling safe iteration and testing before applying changes to the live config. This provides a natural staging environment for configuration experiments.

### Personal, Not Generic
Unlike LazyVim, LunarVim, or other distributions aimed at mass adoption, this configuration is purpose-built for one person's specific needs. It's not trying to please everyone - it's optimized for specific workflows, languages, and tools that this developer uses daily.

### Custom Theme Development
Includes custom Ghana Cozy color schemes (dark, light, and simple variants) with dedicated export and build tooling via Shipwright. The configuration treats theme development as a first-class feature, not an afterthought.

### AI-Native Integration
Modern AI coding tools (Avante, OpenCode) are integrated as core features rather than optional add-ons, reflecting the reality of modern development workflows.

## Key Features

### Core Features
- **Modular Plugin Architecture:** Plugins organized by function (LSP, editor, UI, AI, coding, formatting, utilities) for easy navigation and maintenance
- **Lazy Loading with lazy.nvim:** Fast startup times through intelligent lazy loading with performance benchmarking built-in
- **Comprehensive LSP Setup:** Mason for LSP server management, nvim-lspconfig with tailored server configurations, and integrated completion via nvim-cmp
- **Custom Utility Library:** Reusable Lua utilities in `util/` for common operations (LSP, formatting, pickers, terminals, etc.)

### Workflow Features
- **Chezmoi Integration:** Seamless dotfile management with automatic syntax highlighting and file detection for chezmoi templates
- **Git Worktree Support:** Per-worktree Shada files and dedicated git-worktree plugin for efficient branch/project switching
- **Tmux Integration:** Vim-tmux-navigator for seamless pane navigation, tmuxinator telescope integration for project session management
- **Project-Aware Persistence:** Automatic session and state management per git worktree/branch

### Customization Features
- **Ghana Cozy Themes:** Custom color schemes with dark, light, and simple variants, built with Shipwright for easy export and modification
- **Huez Theme Picker:** Quick theme switching with favorites and preview support
- **Auto Dark Mode:** System-wide dark/light mode detection and automatic theme switching
- **Performance Monitoring:** Built-in startup benchmarking with detailed logs for optimization

### Editor Enhancement Features
- **Telescope Integration:** Fuzzy finding for files, grep, LSP symbols, git worktrees, and tmuxinator sessions
- **Harpoon2 Navigation:** Lightning-fast file switching for frequently accessed files
- **Mini.files & Oil.nvim:** Modern file explorers with different interaction paradigms
- **Grug-far Search/Replace:** Advanced project-wide search and replace with live preview
- **Treesitter Parsing:** Advanced syntax highlighting and code understanding for multiple languages

### AI & Modern Tooling
- **Avante & OpenCode:** Integrated AI coding assistants for inline assistance and code generation
- **Render Markdown:** Beautiful markdown rendering in-buffer for documentation
- **Noice UI:** Modern command line, messages, and notification UI
- **Which-key Integration:** Discoverable keybindings with contextual help

### Development Features
- **LSP-Zero Configuration:** Simplified LSP setup with sensible defaults
- **Auto-pairs & Surround:** Intelligent bracket pairing and text object manipulation
- **Snippet Support:** LuaSnip with friendly-snippets for common code patterns
- **Format on Save:** Conform.nvim for automatic code formatting with multiple formatter support
- **TypeScript Error Translation:** Human-readable TypeScript error messages
- **Tailwind Tools:** Specialized support for Tailwind CSS development
