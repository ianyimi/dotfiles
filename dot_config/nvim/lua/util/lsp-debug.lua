---@class lazyvim.util.lsp_debug
local M = {}

-- Show all active LSP clients and their capabilities
function M.show_active_clients()
  local clients = vim.lsp.get_clients()
  print("=== ALL ACTIVE LSP CLIENTS ===")
  for _, client in ipairs(clients) do
    print(string.format("Client: %s (ID: %d)", client.name, client.id))
    print("  Attached buffers: " .. vim.inspect(vim.tbl_keys(client.attached_buffers or {})))
    print("  Supports hover: " .. tostring(client.supports_method("textDocument/hover")))
    print("  Root dir: " .. (client.config.root_dir or "unknown"))
    print("  ---")
  end
  print("==============================")
end

-- Show LSP handlers currently registered
function M.show_lsp_handlers()
  print("=== LSP HANDLERS ===")
  for method, handler in pairs(vim.lsp.handlers) do
    if method:match("hover") or method:match("textDocument") then
      print(string.format("%s: %s", method, type(handler)))
    end
  end
  print("====================")
end

-- Check for duplicate hover responses
function M.test_hover_responses()
  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  
  print("=== HOVER RESPONSE TEST ===")
  print("Position: " .. params.position.line .. ":" .. params.position.character)
  
  local response_count = 0
  for _, client in ipairs(clients) do
    if client.supports_method("textDocument/hover") then
      print("Requesting hover from: " .. client.name)
      -- Nvim 0.12+: colon notation, client.request is deprecated
      client:request("textDocument/hover", params, function(err, result)
        response_count = response_count + 1
        print(string.format("Response %d from %s:", response_count, client.name))
        if err then
          print("  ERROR: " .. vim.inspect(err))
        elseif result and result.contents then
          print("  SUCCESS: Has content")
        else
          print("  NO CONTENT: " .. vim.inspect(result))
        end
      end, bufnr)
    end
  end
  print("===========================")
end

-- Inspect the popup buffer that smart_hover just opened. Run this while a hover
-- popup is visible (focus it with <C-w>w first, or just call it from the original
-- buffer and it'll find the focus_id-tagged popup).
--
-- Prints:
--   1. The popup buffer's filetype + raw content (verify ```css fences exist)
--   2. Whether treesitter is started + which parser
--   3. The TS tree's root node sexpr (verify markdown parser sees fenced_code_block)
--   4. Active highlighter info
-- Tells us EXACTLY which step in the highlight pipeline is missing.
function M.diagnose_hover_popup()
  -- Find a floating window with markdown filetype (the hover popup)
  local target_buf, target_win
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" then -- it's a floating window
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "markdown" then
        target_buf, target_win = buf, win
        break
      end
    end
  end

  if not target_buf then
    vim.notify(
      "No markdown floating popup found. Trigger 'gh' on a tailwind class first, then run this.",
      vim.log.levels.WARN
    )
    return
  end

  print("=== HOVER POPUP DIAGNOSTIC ===")
  print("Buffer: " .. target_buf .. "  Window: " .. target_win)
  print("filetype: " .. vim.bo[target_buf].filetype)
  print("syntax:   " .. vim.bo[target_buf].syntax)
  print("conceallevel:  " .. tostring(vim.wo[target_win].conceallevel))
  print("concealcursor: '" .. tostring(vim.wo[target_win].concealcursor) .. "'")
  -- Is noice rendering this instead of our open_floating_preview?
  print("noice_lsp_loaded: " .. tostring(package.loaded["noice.lsp"] ~= nil))
  local fp_loc = debug.getinfo(vim.lsp.util.open_floating_preview).short_src
  print("open_floating_preview source: " .. tostring(fp_loc))

  print("\n--- Raw buffer content ---")
  local lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
  for i, l in ipairs(lines) do
    print(string.format("%2d: %s", i, l))
  end

  print("\n--- Treesitter highlighter active? ---")
  local hl_active = vim.treesitter.highlighter.active[target_buf] ~= nil
  print("highlighter.active: " .. tostring(hl_active))

  print("\n--- Treesitter parser tree ---")
  local ok, parser = pcall(vim.treesitter.get_parser, target_buf, "markdown")
  if not ok or not parser then
    print("!! No markdown parser attached: " .. tostring(parser))
  else
    parser:parse(true) -- force full parse
    local trees = parser:trees()
    print("Number of trees: " .. #trees)
    if trees[1] then
      local root = trees[1]:root()
      print("Root sexpr (first 500 chars):")
      print(string.sub(tostring(root:sexpr()), 1, 500))
    end

    -- Walk children, find fenced_code_block nodes
    print("\n--- fenced_code_block nodes found ---")
    local query = vim.treesitter.query.parse(
      "markdown",
      "((fenced_code_block (info_string (language) @lang) (code_fence_content) @content))"
    )
    local count = 0
    for _, tree in ipairs(trees) do
      for id, node in query:iter_captures(tree:root(), target_buf, 0, -1) do
        local name = query.captures[id]
        local text = vim.treesitter.get_node_text(node, target_buf)
        print(string.format("  @%s: %s", name, string.sub(text, 1, 80)))
        if name == "lang" then count = count + 1 end
      end
    end
    print("Total fenced blocks with language: " .. count)

    print("\n--- Injection languages active ---")
    parser:for_each_tree(function(_, lang_tree)
      print("  Parser: " .. lang_tree:lang())
    end)
  end

  print("==============================")
end

-- Set up debug keybindings
function M.setup()
  vim.keymap.set("n", "<leader>ldc", M.show_active_clients, { desc = "LSP Debug: Show clients" })
  vim.keymap.set("n", "<leader>ldh", M.show_lsp_handlers, { desc = "LSP Debug: Show handlers" })
  vim.keymap.set("n", "<leader>ldt", M.test_hover_responses, { desc = "LSP Debug: Test hover" })
  vim.keymap.set("n", "<leader>ldp", M.diagnose_hover_popup, { desc = "LSP Debug: Diagnose hover popup" })
end

return M