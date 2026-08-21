---
verified_at: 59382a5199bd055626537d995cb92dc1e4eda588
---

# Tech Stack

## Core
- Neovim 0.11+ (vim.deprecate shim in `config/lazy.lua` targets the 0.11 lspconfig transition)
- Lua (LuaJIT) — entire config; tabs, snake_case
- lazy.nvim — plugin manager; specs under `lua/plugins/<category>/`, one plugin per file
- LazyVim-derived util library — `lua/util/` exposed as `_G.LazyVim` (stripped-down starter, not the LazyVim distro)
- chezmoi-managed — chezmoi.nvim + chezmoi.vim hot-reload the live config on save

## LSP & Completion
- nvim-lspconfig + mason + mason-lspconfig — servers: astro, bashls, clangd, dockerls, eslint, glsl_analyzer, gopls, html, jsonls, lua_ls, mdx_analyzer, tailwindcss, taplo, vtsls
- nvim-cmp + LuaSnip + friendly-snippets + lspkind
- fidget (LSP progress), ts-error-translator, tailwind-tools
- Custom LSP tooling in `lua/util/`: lsp.lua, lsp-debug.lua, lsp-performance.lua, error-lens.lua

## Formatting
- conform.nvim — oxfmt→prettierd fallback chain (JS/TS/JSON), prettierd (css/html/yaml/md), stylua (lua), isort+black (python); format_on_save with LSP fallback

## Editor
- telescope (+ fzf-native, ui-select, tmuxinator) — picker
- harpoon2 — buffer pinning; **deeply linked with barbar** (buffer-order sync via `_G.update_harpoon_from_buffer_order`) — the most important custom cross-plugin interaction in this config
- oil.nvim — file editing; treesitter + context + autotag + ts-comments
- grug-far (search/replace), undotree, which-key, snacks (dashboard, words)

## Git
- gitsigns, diffview, git-worktree; lazygit via `lua/util/lazygit.lua`

## UI
- barbar (active bufferline; harpoon-synced), lualine, noice (notifications, cmdline), satellite (scrollbar), indent-blankline, colorizer, auto-dark-mode
- huez — theme manager; **tokyonight is the daily-driver colorscheme**, selected via huez

## Colorschemes
- Ghana Cozy (custom, dark + light) — authored in lush.nvim, exported via shipwright (`shipwright_build.lua`, `lua/export-ghana-cozy.lua`) to plain files in `colors/`; not currently the active theme
- catppuccin, sonokai as alternates

## Terminal integration
- vim-tmux-navigator, telescope-tmuxinator, custom terminal util

## Migrated off (kept in tree, `enabled = false`)
- avante.nvim, opencode.nvim (AI), bufferline.nvim (replaced by barbar), alpha (replaced by snacks dashboard), mini.files (replaced by oil), mini.ai, bullets.vim, vim-mdx-js, nvim-notify (replaced by noice)
