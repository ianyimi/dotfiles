# AGENTS.md - Neovim Configuration Codebase Guide

## About This Config
- Custom Neovim setup assembled from various online configs and tutorials
- Based on stripped-down LazyVim starter with default plugins removed
- Managed by chezmoi - changes here hot reload the actual config automatically
- Mix of curated plugins from YouTube tutorials and personal trial/error

## Build/Test Commands
- No traditional build system - uses Neovim's lazy loading via `lazy.nvim`
- Test configuration: Open Neovim and check for errors with `:checkhealth`
- Plugin management: `:Lazy` for plugin operations, `:Mason` for LSP servers
- Theme export: `:Shipwright` or `:lua require('export-ghana-cozy')`
- Changes auto-sync via chezmoi to live config

## Important Context for Agents
- **ALWAYS check git status/diff/log before starting work** - provides crucial context about recent changes, ongoing work, and untracked files that may be relevant
- Recent focus areas: custom Ghana Cozy colorschemes, opencode AI integration, LSP config modernization, bufferline migration from barbar

## Code Style Guidelines
- **Language**: Lua only
- **Indentation**: Tabs (not spaces), tab size = 2
- **Naming**: snake_case for variables/functions, PascalCase for modules
- **Imports**: Use `require()` at top of files, prefer local assignments
- **Plugin structure**: Return table with plugin spec, use lazy loading with `event`/`cmd`
- **Comments**: Use `--` for single line, `---@` for type annotations
- **Error handling**: Prefer `pcall()` for risky operations, check return values
- **Tables**: Trailing commas preferred for multi-line tables
- **Strings**: Use double quotes for user-visible text, single for internal strings
- **Global access**: Use `vim.*` API, define `LazyVim` util functions in `util/`
- **File organization**: Group by functionality (`plugins/`, `config/`, `util/`)

## Critical Configuration Rules
- **NEVER remove functionality** when fixing bugs or making changes unless explicitly requested by user or the removed code is clearly a previous failed implementation attempt of what is currently being fixed AND the new implementation has been confirmed working by the user
- **Preserve all features** when refactoring - existing behavior must remain intact
- When fixing issues, identify root cause and fix minimally without breaking other features
- If unsure whether to remove functionality, ask the user first