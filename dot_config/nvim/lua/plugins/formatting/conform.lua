return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        -- Use oxfmt (30x faster than Prettier) as primary, prettierd as fallback.
        -- `stop_after_first = true` means conform tries oxfmt first; if it errors
        -- (e.g., binary missing in a new env), it falls back to prettierd.
        -- ESLint LSP handles linting, oxfmt handles formatting.
        javascript = { "oxfmt", "prettierd", stop_after_first = true },
        typescript = { "oxfmt", "prettierd", stop_after_first = true },
        javascriptreact = { "oxfmt", "prettierd", stop_after_first = true },
        typescriptreact = { "oxfmt", "prettierd", stop_after_first = true },
        json = { "oxfmt", "prettierd", stop_after_first = true },
        -- Keep prettierd for file types not supported by oxfmt
        svelte = { "prettierd" },
        css = { "prettierd" },
        html = { "prettierd" },
        yaml = { "prettierd" },
        markdown = { "prettierd" },
        ["markdown.mdx"] = { "prettierd" },
        mdx = { "prettierd" },
        graphql = { "prettierd" },
        liquid = { "prettierd" },
        lua = { "stylua" },
        python = { "isort", "black" }, -- Keep both for Python
      },
      -- Disable format_on_save to prevent performance issues and cursor jumps
      -- Use manual formatting with <leader>mp instead
      format_on_save = {
        lsp_fallback = true,
        async = false,
        timeout_ms = 2000
      }
    })

    -- Configure oxfmt (super fast Rust-based formatter).
    --
    -- Call the binary directly from PATH. It's installed via Homebrew
    -- (`brew install oxc` or `brew install oxfmt`) at /opt/homebrew/bin/oxfmt.
    --
    -- Previously we used `command = "npx", args = { "oxfmt@latest", ... }`,
    -- but `npx oxfmt@latest` does a network round-trip to the npm registry on
    -- EVERY save to check for updates (~1.5-2s), which causes format-on-save
    -- to time out. Direct binary call is ~700ms total (vs 1.9s via npx).
    conform.formatters.oxfmt = {
      command = "oxfmt",
      args = { "--stdin-filepath", "$FILENAME" },
      stdin = true,
      -- conform's default condition checks if the binary is executable, so we
      -- don't override it. If oxfmt is missing for any reason, conform falls
      -- back to the next formatter in formatters_by_ft (prettierd).
    }
    
    -- Use built-in prettier (stdio). Prefer `prettierd` if available.
    conform.formatters.shfmt = {
      prepend_args = { "-i", "4" },
    }

    vim.keymap.set({ "n", "v" }, "<leader>mp", function()
      conform.format({
        lsp_fallback = true,
        async = false,
        timeout_ms = 3000, -- Increased for monorepos
      })
    end, { desc = "Format file or selection (in visual mode)" })
  end,
}
