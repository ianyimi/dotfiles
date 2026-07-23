---@class lazyvim.util.memory_monitor
local M = {}

-- Get top memory consuming processes
function M.get_top_memory_processes()
  local handle = io.popen('ps aux | sort -nrk 4 | head -10')
  if not handle then
    vim.notify("Could not check memory usage", vim.log.levels.WARN)
    return
  end
  
  local result = handle:read("*a")
  handle:close()
  
  local lines = vim.split(result, '\n')
  local processes = {}
  
  for i = 2, #lines do -- Skip header
    local line = lines[i]
    if line and line ~= "" then
      local parts = vim.split(line, '%s+')
      if #parts >= 11 then
        local process = {
          user = parts[1],
          pid = parts[2],
          cpu = parts[3],
          mem = parts[4],
          vsz = parts[5],
          rss = parts[6],
          command = table.concat(parts, ' ', 11)
        }
        -- Shorten long command lines
        if #process.command > 60 then
          process.command = process.command:sub(1, 57) .. "..."
        end
        table.insert(processes, process)
      end
    end
  end
  
  return processes
end

-- Show memory usage in a formatted way
function M.show_memory_usage()
  local processes = M.get_top_memory_processes()
  if not processes or #processes == 0 then
    return
  end
  
  local output = {"🧠 Top Memory Consumers:", ""}
  
  local total_mem = 0
  for _, proc in ipairs(processes) do
    local mem_percent = tonumber(proc.mem) or 0
    total_mem = total_mem + mem_percent
    
    local line = string.format("%s%% %s %s", 
      proc.mem, 
      proc.command:match("([^/]+)$") or proc.command, -- Just app name
      proc.pid
    )
    table.insert(output, line)
  end
  
  table.insert(output, "")
  table.insert(output, string.format("Top 10 total: %.1f%% memory", total_mem))
  
  vim.notify(table.concat(output, '\n'), vim.log.levels.INFO)
end

-- Check if specific development tools are consuming too much memory
function M.check_dev_tool_memory()
  local handle = io.popen('ps aux | grep -E "(node|vtsls|eslint|tailwind|nvim)" | grep -v grep')
  if not handle then
    return
  end
  
  local result = handle:read("*a")
  handle:close()
  
  local lines = vim.split(result, '\n')
  local dev_tools = {}
  local total_dev_mem = 0
  
  for _, line in ipairs(lines) do
    if line and line ~= "" then
      local parts = vim.split(line, '%s+')
      if #parts >= 11 then
        local mem_percent = tonumber(parts[4]) or 0
        total_dev_mem = total_dev_mem + mem_percent
        
        local tool_name = "unknown"
        local command = table.concat(parts, ' ', 11)
        
        if command:match("vtsls") then
          tool_name = "TypeScript LSP"
        elseif command:match("eslint") then
          tool_name = "ESLint LSP"
        elseif command:match("tailwind") then
          tool_name = "Tailwind LSP"
        elseif command:match("nvim") then
          tool_name = "Neovim"
        elseif command:match("node.*tsserver") then
          tool_name = "TS Server"
        elseif command:match("node") then
          tool_name = "Node.js"
        end
        
        table.insert(dev_tools, {
          name = tool_name,
          mem = mem_percent,
          pid = parts[2],
        })
      end
    end
  end
  
  if #dev_tools > 0 then
    local output = {"⚙️  Development Tools Memory:", ""}
    
    -- Sort by memory usage
    table.sort(dev_tools, function(a, b) return a.mem > b.mem end)
    
    for _, tool in ipairs(dev_tools) do
      if tool.mem > 0.1 then -- Only show tools using more than 0.1% memory
        table.insert(output, string.format("%.1f%% %s (PID: %s)", tool.mem, tool.name, tool.pid))
      end
    end
    
    table.insert(output, "")
    table.insert(output, string.format("Total dev tools: %.1f%% memory", total_dev_mem))
    
    if total_dev_mem > 5 then
      table.insert(output, "")
      table.insert(output, "💡 Consider running '<leader>lr' to restart LSP servers")
    end
    
    vim.notify(table.concat(output, '\n'), vim.log.levels.INFO)
  else
    vim.notify("No development tools found using significant memory", vim.log.levels.INFO)
  end
end

-- Setup keybindings
function M.setup()
  vim.keymap.set("n", "<leader>mm", M.show_memory_usage, { desc = "Memory: Show top consumers" })
  vim.keymap.set("n", "<leader>md", M.check_dev_tool_memory, { desc = "Memory: Check dev tools" })
end

return M