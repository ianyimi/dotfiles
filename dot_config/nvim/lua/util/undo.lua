---@class lazyvim.util.undo
local M = {}

-- bufnr -> absolute path, for buffers this module CREATED and has not seen visited yet. Only
-- these may be unlisted, evicted or deleted. Drained by M.release and by the BufEnter hook.
---@type table<integer, string>
local held = {}

-- bufnr -> true for every buffer this module loaded with eventignore="all" — both the ones it
-- created and pre-existing ones it merely adopted. Such a buffer never saw BufReadPost or
-- FileType, so it has no filetype and therefore no syntax, treesitter or LSP. Because the
-- buffer is already loaded, opening it will NOT re-read it and those events never come on their
-- own, so the BufEnter hook below has to fire them once. Tracked separately from `held`:
-- adopted buffers need the attach but must never be unlisted or deleted.
---@type table<integer, true>
local needs_attach = {}

-- path -> true for files whose undofile turned out missing or stale. Purely an optimisation, but
-- a load-bearing one: without it every repeat hold of a historyless file created and destroyed a
-- buffer, and the destroy leaked BufWipeout/BufUnload into barbar and friends.
---@type table<string, true>
local no_history = {}

-- Absolute path of the advertise file this instance last wrote, or nil if none/removed.
---@type string?
local advertise_path

-- Only undofiles touched in roughly the last week are worth preloading -- older history
-- reflects work nobody is actively reaching for, and skipping it keeps the preload
-- proportional to recent activity instead of the whole repo's undo store. One constant, so
-- widening or narrowing the window is a one-line change.
local WINDOW_DAYS = 7

-- Backstop, not a routine path: measured preload sizes (37 on maprios-app within the window)
-- sit far below this, so eviction inside M.arm should not normally fire.
local HOLD_CAP = 200

local group = vim.api.nvim_create_augroup("lazyvim_undo_guard", { clear = true })

--- Deletes advertise files whose pid is no longer running, so `$TMPDIR/nvim-undo` doesn't
--- grow forever across crashed/killed instances and the notifier never dials a dead socket.
---@param dir string
local function prune_dead(dir)
  for name in vim.fs.dir(dir) do
    local pid = tonumber(name)
    if pid then
      -- vim.uv.kill returns 0 (truthy in Lua) for a live pid and nil for a dead one.
      local alive = vim.uv.kill(pid, 0)
      if not alive then
        pcall(vim.uv.fs_unlink, dir .. "/" .. name)
      end
    end
  end
end

--- Preemptively loads `path` so a running nvim absorbs a later external rewrite of the file as
--- an undo state (via 'undoreload') instead of silently discarding the persistent undofile on
--- next open. Called by agent tool-call hooks before an agent writes a file it hasn't opened
--- itself, and by the startup preload. Idempotent and cheap once a buffer is loaded.
---
--- Ownership rule: only a buffer this function CREATED may be unlisted, tracked or deleted. A
--- buffer that already existed belongs to the user or to a plugin — a harpoon pin or a session
--- restore lists its files before loading them, and unlisting one drops it from the tabline
--- while deleting one closes it outright. Loading such a buffer is the whole protection and is
--- safe; touching 'buflisted' or removing it is not ours to do.
---@param path string absolute file path
---@return "held"|"loaded"|"adopted"|"no-history"|"missing"
function M.hold(path)
  path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.filereadable(path) ~= 1 then
    return "missing"
  end

  if vim.fn.bufloaded(path) ~= 0 then
    return "loaded"
  end

  -- Already known to have no usable undofile this session. Without this, an agent editing the
  -- same historyless file repeatedly re-created and re-deleted a buffer on every single edit.
  -- A file can only gain undo history by being written from inside nvim, which requires it to be
  -- loaded — and a loaded buffer returns "loaded" above — so this cache cannot go stale.
  if no_history[path] then
    return "no-history"
  end

  -- Checked BEFORE bufadd, which would create the buffer and make every later check say "mine".
  local pre_existing = vim.fn.bufexists(path) == 1

  -- eventignore="all" and swapfile=false must both be restored on every exit path, including a
  -- throw: leaving eventignore="all" set silently kills every autocmd for the rest of the session
  -- (LSP attach, treesitter, gitsigns, checktime...), which is worse than losing one file's undo
  -- history. Save/restore therefore wraps the pcall, never sits inside it.
  --
  -- The whole create/inspect/maybe-delete sequence runs inside that window, not just the load.
  -- Suppressing the create events while letting the delete escape fired BufWipeout + BufUnload
  -- into barbar's state on every historyless file, which showed up as a render/animation storm
  -- (measured: 5617 barbar render.update calls, 24s of CPU, tabs visibly rearranging).
  local saved_eventignore = vim.o.eventignore
  local saved_swapfile = vim.o.swapfile
  vim.o.eventignore = "all"
  vim.o.swapfile = false

  local ok, result = pcall(function()
    local b = vim.fn.bufadd(path)
    vim.fn.bufload(b)
    if pre_existing then
      return { buf = b, status = "adopted" }
    end

    vim.api.nvim_set_option_value("buflisted", false, { buf = b })

    -- No usable undo history: holding this buffer costs memory for nothing.
    if vim.fn.undotree(b).seq_last == 0 then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
      return { buf = b, status = "no-history" }
    end

    return { buf = b, status = "held" }
  end)

  vim.o.eventignore = saved_eventignore
  vim.o.swapfile = saved_swapfile

  if not ok or type(result) ~= "table" then
    return "missing"
  end

  if result.status == "no-history" then
    no_history[path] = true
    return "no-history"
  end

  -- Both held and adopted buffers were loaded with eventignore="all", so neither saw
  -- BufReadPost/FileType and neither has a filetype until the BufEnter hook fires them.
  needs_attach[result.buf] = true
  if result.status == "held" then
    held[result.buf] = path
  end
  return result.status
end

--- Deletes still-held, never-visited buffers. With no argument, deletes all of them. With `n`,
--- deletes only the `n` worst: buffers with no usable history are evicted first (defensive --
--- M.hold already filters these out at load time, so this branch should rarely have any to
--- find), then the oldest held buffers, using bufnr order as a free proxy for hold order
--- (Neovim never reuses a buffer number within a session, so the lowest bufnr among held
--- buffers was always held first -- no separate insertion-order list is needed).
---@param n integer? if given, evict at most this many buffers instead of all of them
---@return integer count of buffers deleted
function M.release(n)
  local victims = {}
  for buf in pairs(held) do
    victims[#victims + 1] = buf
  end

  if n ~= nil and n < #victims then
    table.sort(victims, function(a, b)
      local a_stale = vim.fn.undotree(a).seq_last == 0
      local b_stale = vim.fn.undotree(b).seq_last == 0
      if a_stale ~= b_stale then
        return a_stale
      end
      return a < b
    end)
    for i = #victims, n + 1, -1 do
      victims[i] = nil
    end
  end

  local count = 0
  for _, buf in ipairs(victims) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    held[buf] = nil
    needs_attach[buf] = nil
    count = count + 1
  end
  return count
end

--- Enumerates files under `root` that already have a persistent undofile whose mtime falls
--- within the last WINDOW_DAYS days, newest undofile mtime first. Backs the startup preload
--- (M.arm, below).
---
--- 'undodir' mangles a file's absolute path into its undofile's name by turning every path
--- separator into "%" (its value carries a trailing "//" by default -- normalized here rather
--- than assumed away). A literal "%" already present in a path component is indistinguishable
--- from an encoded "/" by that scheme alone, so every decoded candidate is round-tripped back
--- through vim.fn.undofile() and kept only when that reproduces the exact entry it came from.
---@param root string absolute directory to restrict candidates to
---@return {path: string, mtime: integer}[] sorted newest undofile mtime first
function M.candidates(root)
  -- Undofile names encode the *resolved* absolute path, so the root must be resolved too or
  -- nothing matches for a project reached through a symlink (on macOS /tmp -> /private/tmp,
  -- and $TMPDIR lives under /var -> /private/var). Without this the preload silently finds
  -- zero candidates instead of failing loudly.
  root = vim.uv.fs_realpath(root) or root
  root = vim.fn.fnamemodify(root, ":p"):gsub("/+$", "") .. "/"

  local undodir = vim.split(vim.o.undodir, ",", { plain = true })[1] or ""
  undodir = undodir:gsub("/+$", "")
  if undodir == "" then
    return {}
  end

  local cutoff = os.time() - WINDOW_DAYS * 24 * 60 * 60
  local entries = {}

  pcall(function()
    for name, kind in vim.fs.dir(undodir) do
      if kind == "file" then
        local decoded = (name:gsub("%%", "/"))
        if decoded:sub(1, #root) == root and vim.fn.filereadable(decoded) == 1 then
          local st = vim.uv.fs_stat(undodir .. "/" .. name)
          local mtime = st and st.mtime.sec or 0
          if mtime >= cutoff then
            if vim.fs.basename(vim.fn.undofile(decoded)) == name then
              entries[#entries + 1] = { path = decoded, mtime = mtime }
            end
          end
        end
      end
    end
  end)

  table.sort(entries, function(a, b)
    return a.mtime > b.mtime
  end)
  return entries
end

--- Windowed startup preload: holds every file under the cwd with a recent undofile (see
--- M.candidates), not just files an edit hook happens to touch. This is what covers a
--- `git checkout`, `prettier --write .`, `npm install`, codegen, an xd://ast_edit rewrite, or
--- the developer's own manual git operations -- none of those pass through a tool-call hook,
--- so nothing else would ever hold them.
---
--- The queue drains behind a repeating 16ms timer doing at most 0.8ms of hold() work per tick
--- (wrapped in vim.schedule_wrap since the callback touches buffers/options, which is unsafe
--- in a fast event). Measured total work is small (~29ms on maprios-app, about two ticks), but
--- the chunk stays in place rather than running as one synchronous loop: a cold FS cache or a
--- much larger project could turn that into a real stall, and a single unchunked call risks
--- crossing the 300ms red-flag threshold in .agent/docs/perf-baseline.md. Already-loaded files
--- and files over vim.g.bigfile_size are skipped.
---@return nil
function M.arm()
  local queue = M.candidates(vim.uv.cwd() or ".")
  if #queue == 0 then
    return
  end

  local timer = vim.uv.new_timer()
  if not timer then
    return
  end

  local i = 0
  local held_count, skipped_count = 0, 0
  local max_tick_ms = 0
  -- vim.schedule_wrap means every libuv tick QUEUES a callback on the main loop. When the loop
  -- is busy (opening a file, LSP/treesitter work) several can queue before any runs, so the
  -- finish path must be idempotent: the first one to drain the queue closes the timer, and the
  -- rest must return instead of closing it again ("handle is already closing") and re-notifying.
  local finished = false

  timer:start(
    16,
    16,
    vim.schedule_wrap(function()
      if finished then
        return
      end
      local tick_start = vim.uv.hrtime()

      while i < #queue do
        i = i + 1
        local path = queue[i].path

        if vim.fn.bufloaded(path) == 0 then
          local size = vim.fn.getfsize(path)
          if size >= 0 and size <= vim.g.bigfile_size then
            local ok, status = pcall(M.hold, path)
            if ok and status == "held" then
              held_count = held_count + 1
              -- Backstop eviction: keep the held set at or under HOLD_CAP. Measured queues
              -- (37 on maprios-app) sit far below this, so `over` should never be positive in
              -- practice -- it exists for the project this hasn't been measured on yet.
              local over = vim.tbl_count(held) - HOLD_CAP
              if over > 0 then
                M.release(over)
              end
            end
          else
            skipped_count = skipped_count + 1
          end
        end

        if (vim.uv.hrtime() - tick_start) / 1e6 >= 0.8 then
          break
        end
      end

      max_tick_ms = math.max(max_tick_ms, (vim.uv.hrtime() - tick_start) / 1e6)

      if i >= #queue then
        finished = true
        timer:stop()
        if not timer:is_closing() then
          timer:close()
        end
        LazyVim.info(
          string.format(
            "undo-guard preload: %d/%d held (%d skipped, max tick %.2fms)",
            held_count,
            #queue,
            skipped_count,
            max_tick_ms
          ),
          { title = "LazyVim" }
        )
      end
    end)
  )
end

-- First-visit re-attach. Any buffer this module loaded was loaded with eventignore="all", so it
-- skipped BufReadPost and FileType and has no filetype — meaning no syntax, no treesitter, no
-- LSP. Neovim will not deliver those events later on its own, because the buffer is already
-- loaded and opening it does not re-read it. So the first time the user actually enters one,
-- fire BufReadPost and set the filetype, which lets every FileType-driven attach run normally.
--
-- This applies to adopted (pre-existing, e.g. harpoon-pinned) buffers as well as ones this
-- module created; only the latter also need relisting, since only those were unlisted here.
-- Buffers this module never loaded are untouched.
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(args)
    local buf = args.buf
    if not needs_attach[buf] then
      return
    end
    needs_attach[buf] = nil

    if held[buf] then
      held[buf] = nil
      vim.api.nvim_set_option_value("buflisted", true, { buf = buf })
    end

    vim.api.nvim_exec_autocmds("BufReadPost", { buffer = buf })

    if vim.api.nvim_get_option_value("filetype", { buf = buf }) == "" then
      local ft = vim.filetype.match({ buf = buf, filename = vim.api.nvim_buf_get_name(buf) })
      if ft then
        vim.api.nvim_set_option_value("filetype", ft, { buf = buf })
      end
    end
  end,
})

--- Writes `$TMPDIR/nvim-undo/<pid>` so the notifier script can discover this instance: line 1
--- is this instance's cwd, line 2 is `v:servername`. Every nvim already listens on msgpack-RPC
--- by default, so no `serverstart()` call is needed here. This function only knows how to write
--- the file; the VimEnter autocmd that calls it lives in autocmds.lua.
---@return string? path absolute path of the advertise file, or nil on any failure
function M.advertise()
  local ok, result = pcall(function()
    local tmp = (vim.env.TMPDIR or "/tmp"):gsub("/$", "")
    local dir = tmp .. "/nvim-undo"
    vim.fn.mkdir(dir, "p")
    prune_dead(dir)

    local servername = vim.v.servername
    if servername == nil or servername == "" then
      return nil
    end

    local path = dir .. "/" .. tostring(vim.fn.getpid())
    vim.fn.writefile({ vim.uv.cwd() or "", servername }, path)
    return path
  end)

  if ok and result then
    advertise_path = result
    return result
  end
  return nil
end

--- Removes this instance's advertise file, if one was written. Called from a VimLeavePre
--- autocmd so a dead instance never lingers as a discoverable target.
---@return nil
function M.unadvertise()
  if advertise_path then
    pcall(vim.uv.fs_unlink, advertise_path)
    advertise_path = nil
  end
  return nil
end

return M
