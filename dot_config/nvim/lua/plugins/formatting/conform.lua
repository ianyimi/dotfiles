return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        -- Use oxfmt (30x faster than Prettier) as primary, prettierd as fallback
        -- ESLint LSP handles linting, oxfmt handles formatting
        javascript = { "oxfmt" },
        typescript = { "oxfmt" },
        javascriptreact = { "oxfmt" },
        typescriptreact = { "oxfmt" },
        json = { "oxfmt" }, -- oxfmt supports JSON
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
      -- format_on_save = {
      --   lsp_fallback = true,
      --   async = false,
      --   timeout_ms = 2000
      -- }
    })

    -- Configure individual formatters
    -- Configure oxfmt (super fast Rust-based formatter)
    conform.formatters.oxfmt = {
      command = "npx",
      args = { "oxfmt@latest", "--stdin-filepath", "$FILENAME" },
      stdin = true,
      -- Oxfmt is extremely fast, even via npx
      timeout_ms = 2000,
      -- Try to find local oxfmt first, fallback to npx
      condition = function()
        -- Always available via npx
        return true
      end,
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
