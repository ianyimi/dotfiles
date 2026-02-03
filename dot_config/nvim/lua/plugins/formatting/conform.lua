return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        javascript = { "prettierd", "prettier" },
        typescript = { "prettierd", "prettier" },
        javascriptreact = { "prettierd", "prettier" },
        typescriptreact = { "prettierd", "prettier" },
        svelte = { "prettierd", "prettier" },
        css = { "prettierd", "prettier" },
        html = { "prettierd", "prettier" },
        json = { "prettierd", "prettier" },
        yaml = { "prettierd", "prettier" },
        markdown = { "prettierd", "prettier" },
        ["markdown.mdx"] = { "prettierd", "prettier" },
        mdx = { "prettierd", "prettier" },
        graphql = { "prettierd", "prettier" },
        liquid = { "prettierd", "prettier" },
        lua = { "stylua" },
        python = { "isort", "black" },
      },
      -- Disable conform's format_on_save - let LazyVim's format system handle it
      -- This prevents double-formatting and cursor jumping issues
      format_on_save = {
        lsp_fallback = true,
        async = false,
        timeout_ms = 1000
      }
    })

    -- Configure individual formatters
    -- Use built-in prettier (stdio). Prefer `prettierd` if available.
    conform.formatters.shfmt = {
      prepend_args = { "-i", "4" },
    }

    vim.keymap.set({ "n", "v" }, "<leader>mp", function()
      conform.format({
        lsp_fallback = true,
        async = false,
        timeout_ms = 1000,
      })
    end, { desc = "Format file or selection (in visual mode)" })
  end,
}
