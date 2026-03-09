return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        -- eslint_d first (import sorting), then prettierd (formatting)
        -- stop_after_first = false means ALL formatters run sequentially
        javascript = { "eslint_d", "prettierd", stop_after_first = false },
        typescript = { "eslint_d", "prettierd", stop_after_first = false },
        javascriptreact = { "eslint_d", "prettierd", stop_after_first = false },
        typescriptreact = { "eslint_d", "prettierd", stop_after_first = false },
        svelte = { "eslint_d", "prettierd", stop_after_first = false },
        css = { "prettierd", stop_after_first = false },
        html = { "prettierd", stop_after_first = false },
        json = { "prettierd", stop_after_first = false },
        yaml = { "prettierd", stop_after_first = false },
        markdown = { "prettierd", stop_after_first = false },
        ["markdown.mdx"] = { "prettierd", stop_after_first = false },
        mdx = { "prettierd", stop_after_first = false },
        graphql = { "prettierd", stop_after_first = false },
        liquid = { "prettierd", stop_after_first = false },
        lua = { "stylua", stop_after_first = false },
        python = { "isort", "black", stop_after_first = false },
      },
      -- format_on_save causes cursor jumps on undo/redo - see commit 8dbbb4b
      -- Commenting out to test if this fixes the issue
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
