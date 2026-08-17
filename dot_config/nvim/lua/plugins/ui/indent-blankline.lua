return {
  "lukas-reineke/indent-blankline.nvim",
  event = { "BufReadPost", "BufWritePost", "BufNewFile" }, -- "LazyFile"
  opts = function()
    LazyVim.toggle.map("<leader>il", {
      name = "Indention Guides",
			desc = "[I]ndentation [L]ines",
      get = function()
        return require("ibl.config").get_config(0).enabled
      end,
      set = function(state)
        require("ibl").setup_buffer(0, { enabled = state })
      end,
    })

    return {
      indent = {
        char = "│",
        tab_char = "│",
      },
      scope = { show_start = false, show_end = false },
      exclude = {
        filetypes = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
          -- Prose has no indentation structure worth guiding, and large specs
          -- are expensive to decorate: a visible 5500-line markdown buffer
          -- carrying ~950 injected treesitter regions sits in the redraw path
          -- of every keystroke typed into a Telescope prompt. Profiling traced
          -- the "find_files is slower with the spec in a split" gradient here.
          "markdown",
          "markdown.mdx",
          "mdx",
        },
      },
    }
  end,
  config = function(_, opts)
    require("ibl").setup(opts)

    -- Release indent-blankline's per-buffer debounce timer.
    --
    -- ibl/init.lua:106-115 caches one uv timer per buffer number and never
    -- closes it -- the plugin contains no BufDelete or BufWipeout handler at
    -- all. Buffer numbers only increase, and its autocmds fire for every
    -- buffer regardless of `exclude` (the timer is created before any config
    -- lookup), including the throwaway buffers Telescope's previewer spawns.
    -- Measured at +24 live timers in 70s of ordinary editing, each pinning a
    -- closure; RSS grew 112MB -> 209MB over the same window.
    --
    -- The cache is a local, but M.debounced_refresh closes over it, so it is
    -- reachable via the upvalue helper (same technique as
    -- plugins/editor/nvim-treesitter-context.lua). Every step is guarded: if a
    -- future release restructures this, cleanup silently stops instead of
    -- erroring on every buffer close.
    local function release_timer(bufnr)
      local ok, ibl = pcall(require, "ibl")
      if not ok or type(ibl.debounced_refresh) ~= "function" then
        return
      end
      local cache = LazyVim.inject.get_upvalue(ibl.debounced_refresh, "debounced_refresh")
      if type(cache) ~= "table" or type(cache.timers) ~= "table" then
        return
      end
      local timer = cache.timers[bufnr]
      if not timer then
        return
      end
      cache.timers[bufnr] = nil
      if type(cache.queued_buffers) == "table" then
        cache.queued_buffers[bufnr] = nil
      end
      -- Safe to call methods here: ibl's table held this handle until the line
      -- above, so it is still alive rather than closed and collected.
      pcall(function()
        if not timer:is_closing() then
          timer:stop()
          timer:close()
        end
      end)
    end

    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
      group = vim.api.nvim_create_augroup("ibl_timer_release", { clear = true }),
      callback = function(ev)
        release_timer(ev.buf)
      end,
    })
  end,
}

