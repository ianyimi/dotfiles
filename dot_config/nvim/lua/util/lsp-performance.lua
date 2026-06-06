---@class lazyvim.util.lsp_performance
local M = {}

-- Check if current buffer is "large" and might need performance optimizations
---@param bufnr? number Buffer number (defaults to current)
---@return boolean
function M.is_large_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local file_size = vim.fn.getfsize(vim.api.nvim_buf_get_name(bufnr))
  
  -- Consider large if > 5000 lines OR > 5MB (raised thresholds to avoid interruptions)
  return line_count > 5000 or file_size > 5 * 1024 * 1024
end

-- Disable expensive LSP features for truly large buffers
---@param bufnr? number Buffer number
function M.optimize_for_large_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not M.is_large_buffer(bufnr) then
    return
  end
  
  -- Disable document highlighting for large buffers
  vim.api.nvim_clear_autocmds({
    group = "lsp_document_highlight_" .. bufnr,
    buffer = bufnr,
  })
  
  -- Disable semantic tokens for performance
  vim.b[bufnr].semantic_tokens_enabled = false
end

-- Get active LSP clients with memory info
---@return table
function M.get_lsp_status()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local status = {}
  
  for _, client in ipairs(clients) do
    table.insert(status, {
      name = client.name,
      id = client.id,
      root_dir = client.config.root_dir,
      buffers = vim.tbl_count(client.attached_buffers or {}),
    })
  end
  
  return status
end

-- Show system memory pressure (macOS specific)
function M.check_memory_pressure()
  local handle = io.popen('vm_stat | head -8')
  if not handle then
    vim.notify("Could not check memory pressure", vim.log.levels.WARN)
    return
  end
  
  local result = handle:read("*a")
  handle:close()
  
  local compressed = result:match("Pages stored in compressor:%s*(%d+)")
  if compressed then
    local compressed_gb = math.floor(tonumber(compressed) * 16384 / 1024 / 1024 / 1024 * 10) / 10
    if compressed_gb > 10 then
      vim.notify(string.format(
        "⚠️  High memory pressure: %.1fGB compressed\n" ..
        "Consider closing: Spotify (24%% CPU), djay Pro (29%% CPU), or other apps", 
        compressed_gb
      ), vim.log.levels.WARN)
    else
      vim.notify(string.format("📊 Memory pressure: %.1fGB compressed (normal)", compressed_gb), vim.log.levels.INFO)
    end
  end
end

-- Restart slow/problematic LSP clients with buffer preservation
function M.restart_typescript_servers()
  local clients = vim.lsp.get_clients()
  local restarted = {}
  
  for _, client in ipairs(clients) do
    if client.name == "vtsls" or client.name == "eslint" then
      -- Store attached buffers before stopping
      local attached_buffers = vim.tbl_keys(client.attached_buffers or {})
      client.stop()
      table.insert(restarted, client.name .. " (" .. #attached_buffers .. " buffers)")
    end
  end
  
  if #restarted > 0 then
    vim.notify("🔄 Restarted: " .. table.concat(restarted, ", "), vim.log.levels.INFO)
    -- Gentle restart - let LSP auto-attach to current buffer
    vim.defer_fn(function()
      vim.cmd("edit") -- Trigger LSP re-attach
    end, 1000)
  else
    vim.notify("No TypeScript/ESLint servers found to restart", vim.log.levels.WARN)
  end
end

-- Toggle document highlighting
function M.toggle_document_highlighting()
  local bufnr = vim.api.nvim_get_current_buf()
  local augroup = "lsp_document_highlight_" .. bufnr
  local existing = vim.api.nvim_get_autocmds({ group = augroup })
  
  if #existing > 0 then
    vim.api.nvim_clear_autocmds({ group = augroup })
    vim.lsp.buf.clear_references()
    vim.notify("Document highlighting disabled", vim.log.levels.INFO)
  else
    -- Re-enable document highlighting
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    for _, client in ipairs(clients) do
      if client.supports_method("textDocument/documentHighlight") then
        local highlight_augroup = vim.api.nvim_create_augroup(augroup, { clear = true })
        vim.api.nvim_create_autocmd({ "CursorHold" }, {
          group = highlight_augroup,
          buffer = bufnr,
          callback = function()
            if not M.is_large_buffer(bufnr) then
              vim.lsp.buf.document_highlight()
            end
          end,
        })
        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
          group = highlight_augroup,
          buffer = bufnr,
          callback = vim.lsp.buf.clear_references,
        })
        break
      end
    end
    vim.notify("Document highlighting enabled", vim.log.levels.INFO)
  end
end

-- Setup automatic optimizations (gentle, non-intrusive)
function M.setup()
  -- Auto-optimize only truly large buffers (no interruptions for normal files)
  vim.api.nvim_create_autocmd({ "BufReadPost" }, {
    group = vim.api.nvim_create_augroup("lsp_performance_auto", { clear = true }),
    callback = function(args)
      vim.defer_fn(function()
        local line_count = vim.api.nvim_buf_line_count(args.buf)
        local file_size = vim.fn.getfsize(vim.api.nvim_buf_get_name(args.buf))
        
        -- Only notify about truly huge files (>5000 lines or >5MB)
        if line_count > 5000 or file_size > 5 * 1024 * 1024 then
          M.optimize_for_large_buffer(args.buf)
          vim.notify(string.format(
            "📊 Large file detected (%d lines, %.1fMB) - some LSP features disabled for performance", 
            line_count, file_size / 1024 / 1024
          ), vim.log.levels.INFO)
        end
      end, 100)
    end,
  })
  
  -- Set up keybindings for diagnostics and monitoring
  vim.keymap.set("n", "<leader>lr", M.restart_typescript_servers, { desc = "LSP: Restart TS servers" })
  vim.keymap.set("n", "<leader>lh", M.toggle_document_highlighting, { desc = "LSP: Toggle highlighting" })
  vim.keymap.set("n", "<leader>ls", function()
    local status = M.get_lsp_status()
    vim.notify(vim.inspect(status), vim.log.levels.INFO)
  end, { desc = "LSP: Show status" })
  vim.keymap.set("n", "<leader>lm", M.check_memory_pressure, { desc = "LSP: Check memory pressure" })
  
  -- Check memory pressure on startup (once, non-intrusive)
  vim.defer_fn(M.check_memory_pressure, 2000)
end

return M