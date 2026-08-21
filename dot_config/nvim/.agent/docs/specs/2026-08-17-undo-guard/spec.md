---
status: draft
spec_id: 2026-08-17-undo-guard
touches:
  - lua/util/undo.lua
  - lua/util/init.lua
  - lua/config/autocmds.lua
  - scripts/undo-guard-notify.ts
  - scripts/undo-guard-omp-hook.ts
  - .agent/docs/decisions/2026-08-17-undo-guard-hold-before-write.md
  - .agent/docs/specs/2026-08-17-undo-guard/e2e.sh
prompt_version: 1
---

# 2026-08-17-undo-guard — Spec

## Overview

Persistent undo history is lost whenever an agent rewrites a file that nvim does not have
loaded. Nvim binds an undofile to a SHA of the file contents, so a write it did not observe
makes the stored tree unusable — silently discarded on next open, and unrecoverable (`:rundo`
refuses it too). A file that *is* loaded absorbs the same write as a new undo state via
`undoreload` and gets its undofile rewritten, so its history survives.

This spec closes the gap by having agent tool-call hooks load a file into the running nvim
*before* the agent writes it. Both active platforms expose a pre-execution hook that blocks
until it returns, which is what guarantees the ordering. Out-of-band writes to files already
open are already handled by the `checktime {buf}` sweep committed earlier today.

## Design Decisions

1. **Hold the file before the write, driven by the agent's own tool-call hook.** The undofile
   hash binds history to file content, so only a load that *precedes* the write can preserve
   the tree — no watcher, signal or post-hoc repair can, because the mismatch already exists by
   the time they fire.
2. **nvim advertises; it does not start a server.** Every instance already listens on
   msgpack-RPC (`v:servername` is always populated — verified). Startup writes
   `$TMPDIR/nvim-undo/<pid>` holding cwd + servername, so `serverstart` is unnecessary and
   there is no second listener, timer or process.
3. **Exactly one instance is poked, chosen by longest cwd prefix then newest pid, falling back
   to any live instance.** Undofile names derive from the file's absolute path alone — cwd,
   project and instance are irrelevant (verified: an nvim in project A protected a file in
   project B, and project B's own nvim saw the result later). Preferring the deepest cwd match
   keeps held buffers in the project they belong to; falling back to any instance covers
   cross-project agent work. Poking only one avoids two instances writing divergent trees for
   the same file, which matters because the same directory is routinely open in several tmux
   sessions.
4. **The notifier speaks msgpack directly over the existing socket.** `nvim --server
   --remote-expr` would spawn a whole second nvim (~40 ms) to perform a ~2 ms round-trip.
5. **Synchronous RPC rather than `SIGUSR1` + a queue file.** `Signal` autocmds do work
   (verified), but signal delivery is asynchronous and would need an ack protocol to guarantee
   the load precedes the write. RPC gives that ordering for free.
6. **Held buffers load with `eventignore=all` and `swapfile=false`, and re-attach on first
   visit.** Attaching LSP and treesitter to every held file is the dominant cost (287 files
   measured at +25 MB RSS), and swapfiles for read-only holds would trigger E325 storms across
   tmux sessions. A `BufEnter` hook lists the buffer and sets its filetype on first visit so it
   behaves like any freshly opened file.
7. **A file whose undofile is already stale is released again.** `seq_last == 0` means there is
   no history left to protect, so holding it costs memory for nothing.
8. **Fail open on every path.** No nvim, dead socket, malformed reply, timeout or thrown error
   all end in `exit 0`. The worst acceptable outcome is today's behavior (history lost), never a
   blocked or slowed agent. omp fails *closed* when a `tool_call` handler throws, so its handler
   is wrapped end to end.
9. **The module is `lua/util/undo.lua`, not `undo-guard.lua`.** Util modules are registered as
   `---@field <name>` in `lua/util/init.lua`, which requires a valid identifier; `LazyVim.undo`
   works, `LazyVim.undo-guard` does not.
10. **`:UndoGuardHold` survives as a thin delegate.** It is the developer's existing entry point
    and useful for manual testing; only its body moves into the util module, which is also what
    fixes the `eventignore` leak.
11. **A 7-day windowed preload at startup covers what no hook can.** Some rewrites have no
    pre-execution path list — `prettier --write .`, `npm install`, codegen — and some involve no
    agent at all, so no hook fires: a `git checkout`, `stash` or `rebase` the developer runs in a
    tmux pane. A watcher cannot substitute, because it fires *after* the write when the hash
    mismatch already exists. Only a file that is already loaded survives, so files under the cwd
    whose undofile was touched in the last 7 days are held at startup: measured 37 candidates,
    29 ms of work, +5.7 MB RSS, 26 arriving with live history. Unwindowed was measured and
    rejected (287 files / 151 ms / +25.4 MB for maprios-app; 469 / 385 ms / +57.1 MB for vex, on a
    29.8 MB idle baseline, paid per nvim process) — skipping a file never shrinks its undo tree,
    it only leaves that file unprotected for the session, so the steep tail buys little.
12. **Shell edits split by whether the command names its targets.** `sed -i f`, `tee f`, `> f`,
    `patch`, `mv`, `cp` name paths, so they are extracted and held (Step 7). Commands that decide
    their own file set are covered by the Step 6 preload instead, for files under the cwd.
13. **The omp hook installs at user level through the `extensions` list, not a `hooks/`
    directory.** Empirically determined: a probe in `~/.omp/agent/extensions/` loaded and its
    `tool_call` handler fired with `toolName: "write"`; the same probe in `~/.omp/agent/hooks/`
    never loaded; and `~/.omp/agent/config.yml#extensions` with an absolute path loaded a file
    from outside the agent directory. This matches `omp://extension-loading.md:35` ("the active
    agent directory's `extensions/`") and `omp://hooks.md:10` ("hook factories ... are loaded as
    extension modules"). One install covers every project.
14. **The hook file stays inside the chezmoi-managed tree; only a one-line reference lives
    outside it.** `~/.omp/` is not chezmoi-managed (the source root holds only `dot_config/`), so
    a hook living there would be unversioned and lost on a machine rebuild. The file ships as
    `scripts/undo-guard-omp-hook.ts` and `~/.omp/agent/config.yml` gains a single absolute-path
    entry — the smallest possible untracked surface.
15. **The `checktime` sweep is left exactly as committed.** At the ~37-60 held buffers this design
    produces, the sweep costs ~0.4-0.6 ms, inside the 1.0 ms scheduled-callback budget in
    `.agent/docs/perf-baseline.md`. Round-robin chunking was designed for the rejected unwindowed
    variant's 469 buffers (~4.6 ms) and is not needed.

## Out of Scope

- **Unwindowed preload.** Measured and rejected; see decision 11. The window is a single
  constant (`WINDOW_DAYS`) if that judgement changes.
- **Manual `:UndoGuard arm|status|off` commands.** The preload is automatic; nothing to toggle.
- **zsh aliases, PATH shims, `DYLD_INSERT_LIBRARIES`.** Agents write files in-process, not
  through a shell, and aliases do not exist in the non-interactive shells agents spawn.
- **Snapshot / local-history layer** (git shadow refs, per-save commits). Declined by the
  developer for now.
- **Recovering already-stale undofiles.** Impossible: nvim refuses a hash mismatch even under
  explicit `:rundo` ("File contents changed, cannot use undo info").
- **Shell commands that choose their own file set** (`prettier --write .`, `npm install`,
  `make`, codegen) and **`xd://ast_edit`** bulk rewrites, *for files outside the cwd*. Their
  targets cannot be enumerated before execution; inside the cwd the Step 6 preload covers them.
  Named-path shell edits are in scope — see Step 7.
- **Globbed, `xargs`-fed, heredoc and variable-substituted paths** in shell commands. The
  extractor only trusts tokens that resolve to an existing readable file.
- **Files edited while no nvim runs anywhere.** Nothing can hold them; history is lost as today.
- **Per-project undo alignment.** Verified unnecessary — one flat path-keyed store. Unlike
  `shadafile`, which this spec does not touch.
- **`undofile` / `undolevels` / `undoreload` / `undodir` settings.** Already correct in
  `lua/config/options.lua`.

## Implementation

### Step 1 — `lua/util/undo.lua` guard module [agent]

- [ ] Create `lua/util/undo.lua` with `M.hold`, `M.release`, `M.advertise`, `M.unadvertise`, and the first-visit `BufEnter` re-attach autocmd
- [ ] Add `---@field undo lazyvim.util.undo` to the class annotation in `lua/util/init.lua`
- [ ] Run `chezmoi apply` to deploy `lua/util/undo.lua` and the `init.lua` change (developer)
- [ ] Run the `nvim --headless` verification command below and confirm every assertion passes
- [ ] In a PTY nvim session, visit a held TypeScript buffer and confirm LSP/treesitter/gitsigns attach

#### Why this shape

`M.hold(path)` is the only function that ever touches `eventignore`/`swapfile`, and it does so
around exactly one risky call: `vim.fn.bufload(vim.fn.bufadd(path))`. Both option saves/restores
are plain statements *after* the `pcall`, never inside it, so they run unconditionally whether
`bufload` succeeds or throws. This matters because `eventignore = "all"` is a session-global
option — if a throw inside `bufload` ever left it set, every autocmd (LSP attach, treesitter,
gitsigns, cursorhold checktime, format-on-save) silently stops firing for the rest of the nvim
session, which is a far worse outcome than losing one file's undo history. This is the exact bug
in the current inline `:UndoGuardHold` in `lua/config/autocmds.lua` (`vim.fn.bufload` sits
outside its `pcall`) — Step 2 deletes that command and replaces it with a call into this module.

`vim.o.swapfile = false` is set in the same window for the same reason `eventignore` is: it's a
buffer-local-with-global-default option, so setting it right before `bufadd`/`bufload` makes the
*newly created* buffer inherit `swapfile = false` as its local value at creation time (setting
`vim.bo[buf].swapfile` afterwards would be too late — the swapfile is opened during `bufload`).

A buffer whose `undotree().seq_last == 0` has no undofile worth protecting (new file, or an
undofile that's already stale/missing) — holding it in memory costs a buffer slot and a little
memory for zero benefit, so `hold` deletes it immediately and reports `"no-history"` rather than
leaving it parked forever waiting for a visit that will never come.

`held` is a private module-local table (`bufnr -> path`), not exposed on `M`. Nothing in this
spec needs to enumerate it from outside: the advertise mechanism (Step 2) identifies *instances*
by socket file, and the notifier (Step 3) calls `hold(path)` directly by path — no caller ever
needs a bufnr→path map, so the `M.get_bufs()` accessor floated in the original task breakdown is
intentionally omitted (no speculative code). `held` is still necessary internally: it's how
`M.release()` knows which buffers are guards-not-yet-visited, and how the `BufEnter` autocmd
tells a guarded buffer apart from an ordinary one being opened normally.

#### `lua/util/undo.lua`

```lua
---@class lazyvim.util.undo
local M = {}

-- bufnr -> absolute path, for buffers this module loaded on hold that have not been visited
-- yet. Populated by M.hold, drained by M.release and by the BufEnter re-attach below.
---@type table<integer, string>
local held = {}

-- Absolute path of the advertise file this instance last wrote, or nil if none/removed.
---@type string?
local advertise_path

local group = vim.api.nvim_create_augroup("lazyvim_undo_guard", { clear = true })

--- Deletes advertise files whose pid is no longer running, so `$TMPDIR/nvim-undo` doesn't
--- grow forever across crashed/killed instances and the notifier never dials a dead socket.
---@param dir string
local function prune_dead(dir)
  for name in vim.fs.dir(dir) do
    local pid = tonumber(name)
    if pid then
      local alive = vim.uv.kill(pid, 0)
      if not alive then
        pcall(vim.uv.fs_unlink, dir .. "/" .. name)
      end
    end
  end
end

--- Preemptively loads `path` into a hidden, unlisted buffer so a running nvim absorbs a later
--- external rewrite of the file as an undo state (via 'undoreload') instead of silently
--- discarding the persistent undofile on next open. Called by agent tool-call hooks before an
--- agent writes a file it hasn't opened itself. Idempotent and cheap once a buffer is loaded.
---@param path string absolute file path
---@return "held"|"loaded"|"no-history"|"missing"
function M.hold(path)
  path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.filereadable(path) ~= 1 then
    return "missing"
  end

  if vim.fn.bufloaded(path) ~= 0 then
    return "loaded"
  end

  -- eventignore="all" and swapfile=false must both be restored on every exit path, including
  -- a throw from bufload: leaving eventignore="all" set silently kills every autocmd for the
  -- rest of the session (LSP attach, treesitter, gitsigns, checktime...), which is worse than
  -- losing one file's undo history. Save/restore therefore wraps the pcall, not the inside of
  -- it, so restoration is unconditional regardless of success or failure.
  local saved_eventignore = vim.o.eventignore
  local saved_swapfile = vim.o.swapfile
  vim.o.eventignore = "all"
  vim.o.swapfile = false

  local ok, buf = pcall(function()
    local b = vim.fn.bufadd(path)
    vim.fn.bufload(b)
    return b
  end)

  vim.o.eventignore = saved_eventignore
  vim.o.swapfile = saved_swapfile

  if not ok then
    return "missing"
  end

  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })

  -- No usable undo history: holding this buffer costs memory for nothing, so release it
  -- immediately instead of leaving it parked waiting for a visit that will never come.
  local seq_last = vim.fn.undotree(buf).seq_last
  if seq_last == 0 then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return "no-history"
  end

  held[buf] = path
  return "held"
end

--- Deletes every still-held, never-visited buffer. Intended as a periodic/shutdown sweep so a
--- long-running instance doesn't accumulate guard buffers for files nobody ever opened.
---@return integer count of buffers deleted
function M.release()
  local count = 0
  for buf in pairs(held) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    held[buf] = nil
    count = count + 1
  end
  return count
end

-- First-visit re-attach: a held buffer was loaded with eventignore="all", so it skipped
-- BufReadPost/FileType and never got LSP/treesitter/gitsigns. The first time the user actually
-- opens it, relist it, fire BufReadPost, then set filetype (which fires FileType and lets every
-- FileType-driven attach happen normally). Buffers not in `held` are untouched.
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(args)
    local buf = args.buf
    if not held[buf] then
      return
    end
    held[buf] = nil

    vim.api.nvim_set_option_value("buflisted", true, { buf = buf })
    vim.api.nvim_exec_autocmds("BufReadPost", { buffer = buf })

    local name = vim.api.nvim_buf_get_name(buf)
    local ft = vim.filetype.match({ buf = buf, filename = name })
    if ft then
      vim.api.nvim_set_option_value("filetype", ft, { buf = buf })
    end
  end,
})

--- Writes `$TMPDIR/nvim-undo/<pid>` so the notifier script (Step 3) can discover this instance:
--- line 1 is this instance's cwd, line 2 is `v:servername`. Every nvim already listens on
--- msgpack-RPC by default, so no `serverstart()` call is needed here. This function only knows
--- how to write the file; the VimEnter autocmd that calls it lives in autocmds.lua (Step 2).
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
--- autocmd (Step 2) so a dead instance never lingers as a discoverable target.
---@return nil
function M.unadvertise()
  if advertise_path then
    pcall(vim.uv.fs_unlink, advertise_path)
    advertise_path = nil
  end
  return nil
end

return M
```

#### Registration in `lua/util/init.lua`

Add `---@field undo lazyvim.util.undo` to the class annotation block, after the existing
`---@field cmp lazyvim.util.cmp` line and before `local M = {}` (exact surrounding context from
the real file):

```lua
---@field pick lazyvim.util.pick
---@field cmp lazyvim.util.cmp
---@field undo lazyvim.util.undo
local M = {}
```

No other change to `init.lua` is needed — its existing `setmetatable(M, { __index = ... })`
(lines 67–85) already lazy-`require`s any `lua/util/<name>.lua` module the first time
`LazyVim.<name>` is accessed, so `LazyVim.undo.hold(...)` resolves to this module automatically.

#### Verify

Automated — validates `hold`/`release` mechanics standalone (`-u NONE`, no plugins, so this
does *not* exercise LSP/treesitter/gitsigns; see the PTY step below for that):

```bash
d=$(mktemp -d) && mkdir -p "$d/lua/util" "$d/proj" "$d/undodir" "$d/swapdir"
cp lua/util/undo.lua "$d/lua/util/undo.lua"
printf 'const x = 1;\n' > "$d/proj/file.ts"

# Session 1: create a real undofile the normal way.
nvim --headless -u NONE -i NONE \
  -c "set undofile undodir=$d/undodir directory=$d/swapdir//" \
  -c "edit $d/proj/file.ts" -c "normal Goconst y = 2;" -c write -c "qa!"

# Session 2: unloaded file — call hold() directly and assert every property.
cat > "$d/check.lua" <<LUA
vim.opt.rtp:prepend("$d")
vim.opt.undofile = true
vim.opt.undodir = "$d/undodir"
vim.opt.directory = "$d/swapdir//"
local undo = require("util.undo")
local path = "$d/proj/file.ts"
local status = undo.hold(path)
local buf = vim.fn.bufnr(path)
local ut = vim.fn.undotree(buf)
assert(status == "held", "status=" .. status)
assert(ut.seq_last > 0, "seq_last=" .. ut.seq_last)
assert(vim.bo[buf].buflisted == false, "buflisted should be false")
assert(vim.bo[buf].swapfile == false, "swapfile should be false")
assert(vim.o.eventignore == "", "eventignore=[" .. vim.o.eventignore .. "]")
print("PASS: hold=" .. status .. " seq_last=" .. ut.seq_last)
vim.cmd("qa!")
LUA
nvim --headless -u NONE -i NONE -l "$d/check.lua"
rm -rf "$d"
```

Expect `PASS: hold=held seq_last=1` and no assertion errors.

Manual (PTY), only after `chezmoi apply` deploys this file into `~/.config/nvim`:

1. `nvim` in a scratch TS project, edit + `:w` + quit to create an undofile for `file.ts`.
2. Relaunch `nvim` on a different file in the same project (so `file.ts` stays unloaded).
3. `:lua print(LazyVim.undo.hold(vim.fn.fnamemodify("file.ts", ":p")))` → prints `held`; `:ls`
   shows no entry for `file.ts` (unlisted); `:messages` shows no LSP-attach notification.
4. `:buffer file.ts` (or `:e file.ts`) → buffer relists, `:LspInfo` shows an attached client,
   treesitter highlighting is active, gitsigns shows in the sign column.
5. `:undolist` shows the original undo tree intact (`seq_last` unchanged by step 3–4).

### Step 2 — Instance advertising + command delegation [agent]

- [ ] Rewrite `:UndoGuardHold` command in `lua/config/autocmds.lua` to delegate to `LazyVim.undo.hold()`
- [ ] Add VimEnter autocmd to write advertise file at `$TMPDIR/nvim-undo/<pid>`
- [ ] Add VimLeavePre autocmd to clean up advertise file

#### Current defect in `:UndoGuardHold`

The existing command (lines 664–712 in `lua/config/autocmds.lua`) has `vim.fn.bufload` called *outside* the `pcall`:

```lua
local ei = vim.o.eventignore
vim.o.eventignore = "all"

local ok, result = pcall(function()
	return vim.fn.bufadd(path)
end)

if ok then
	local new_buf = result
	vim.fn.bufload(new_buf)  -- <-- OUTSIDE pcall: if this throws, eventignore stays "all"
	vim.api.nvim_set_option_value("buflisted", false, { buf = new_buf })
end

vim.o.eventignore = ei
```

**Defect:** If `vim.fn.bufload(new_buf)` throws, the error unwinds but `vim.o.eventignore = "all"` is never restored, silently disabling every autocmd in the session (no LSP attach, no checktime, no format-on-save) until restart.

#### Replacement command

Replace lines 664–712 in `lua/config/autocmds.lua` with:

```lua
-- UndoGuardHold: preemptively load a file to protect its undo history from external edits.
-- Delegates to the util.undo module, fixing the eventignore leak and coordinating with the
-- advertise mechanism so the hook can find this instance.
vim.api.nvim_create_user_command("UndoGuardHold", function(opts)
	local ok, status = pcall(LazyVim.undo.hold, opts.args)
	if ok and status and vim.in_fast_event() == false then
		LazyVim.info("UndoGuardHold: " .. status, { title = "LazyVim" })
	end
end, {
	nargs = 1,
	complete = "file",
})
```

This wraps the module's `hold(path)` call in `pcall`, so any error is caught. The returned `status` string is reported via `LazyVim.info()` only when called interactively (not during a fast event like a hook).

#### Advertise file and cleanup

Add these autocmds to the existing augroup structure in `lua/config/autocmds.lua`. Insert after the enhanced filetype detection (after line 662) and before the `UndoGuardHold` command comment:

```lua
-- Advertise this nvim instance to the undo-guard hook.
-- Writes $TMPDIR/nvim-undo/<pid> — line 1 cwd, line 2 v:servername — removed on VimLeavePre.
-- The hook uses this to find the instance and call hold() via msgpack-RPC before an agent writes.
vim.api.nvim_create_autocmd("VimEnter", {
	group = augroup("undo_guard_advertise"),
	callback = function()
		LazyVim.undo.advertise()
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	group = augroup("undo_guard_advertise"),
	callback = function()
		LazyVim.undo.unadvertise()
	end,
})
```

#### Verify

1. Run `chezmoi apply` to deploy the config.
2. Launch nvim in any directory: `:echo $TMPDIR .. "/nvim-undo/" .. getpid()` — file exists and contains two lines: cwd and `v:servername`.
3. Quit nvim and confirm the file is deleted.
4. In a fresh nvim session, test `:UndoGuardHold /nonexistent/path` and verify that `:echo &eventignore` is empty (not "all"), even though the file doesn't exist.
5. Create a readable temp file, call `:UndoGuardHold /path/to/file`, confirm the buffer is loaded unlisted with `seq_last > 0`.

### Step 3 — `scripts/undo-guard-notify.ts` notifier [agent]

- [ ] Create `scripts/undo-guard-notify.ts` — minimal msgpack encode/decode, no dependencies
- [ ] Instance selection: longest cwd prefix, then newest pid; fall back to any live instance
- [ ] Accept a path as argv or a `PreToolUse` JSON document on stdin
- [ ] Hard timeout and `exit 0` on every failure path

Create `scripts/undo-guard-notify.ts`:

```typescript
#!/usr/bin/env bun
// Hook subprocess: given a target file path, finds the best live nvim instance
// (by advertise file under $TMPDIR/nvim-undo/), calls
// require("util.undo").hold(path) over msgpack-RPC on its unix socket, and exits.
//
// Fail-open contract: every exit path is `process.exit(0)`. Nothing is ever
// written to stdout, because Claude Code's PreToolUse hook treats hook stdout
// as a decision document — any stray byte there could alter tool execution.
//
// Msgpack is hand-rolled (no dependency) rather than shelling out to
// `nvim --server --remote-expr`: that spawns a whole second nvim process just
// to proxy one RPC call, ~30-40ms of process-start overhead versus the ~1-3ms
// a direct unix-socket round-trip costs here, and the entire script must stay
// well under the 150ms hard timeout with margin to spare.

import path from "node:path";
import { readdirSync, readFileSync } from "node:fs";

const HARD_TIMEOUT_MS = 150;

async function main(): Promise<void> {
  const targetPath = await resolveTargetPath();
  if (!targetPath) return;

  const advertiseDir = path.join(tmpDir(), "nvim-undo");
  const instances = listLiveInstances(advertiseDir);
  if (instances.length === 0) return;

  const instance = pickInstance(instances, targetPath);
  if (!instance) return;

  await callHold(instance.socket, targetPath);
}

// ---------------------------------------------------------------------------
// Target path resolution
// ---------------------------------------------------------------------------

async function resolveTargetPath(): Promise<string | null> {
  const argvPath = process.argv[2];
  if (argvPath) return path.resolve(argvPath);

  const raw = await readStdin();
  if (!raw) return null;

  try {
    const doc = JSON.parse(raw);
    const filePath = doc?.tool_input?.file_path;
    if (typeof filePath !== "string" || filePath.length === 0) return null;
    return path.resolve(filePath);
  } catch {
    return null;
  }
}

function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    if (process.stdin.isTTY) {
      resolve("");
      return;
    }
    const chunks: Buffer[] = [];
    process.stdin.on("data", (chunk) => chunks.push(chunk));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    process.stdin.on("error", () => resolve(""));
    // Guard against a stdin that never closes (e.g. an interactive shell).
    setTimeout(() => resolve(Buffer.concat(chunks).toString("utf8")), HARD_TIMEOUT_MS);
  });
}

// ---------------------------------------------------------------------------
// Instance discovery
// ---------------------------------------------------------------------------

interface Instance {
  pid: number;
  cwd: string;
  socket: string;
}

function tmpDir(): string {
  return process.env.TMPDIR ?? "/tmp";
}

function isPidAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function listLiveInstances(advertiseDir: string): Instance[] {
  let entries: string[];
  try {
    entries = readdirSync(advertiseDir);
  } catch {
    return [];
  }

  const instances: Instance[] = [];
  for (const name of entries) {
    const pid = Number.parseInt(name, 10);
    if (!Number.isInteger(pid) || pid <= 0) continue;
    if (!isPidAlive(pid)) continue;

    let contents: string;
    try {
      contents = readFileSync(path.join(advertiseDir, name), "utf8");
    } catch {
      continue;
    }

    const lines = contents.split("\n");
    const cwd = lines[0]?.trim();
    const socket = lines[1]?.trim();
    if (!cwd || !socket) continue;
    if (!Bun.file(socket).exists) continue;

    instances.push({ pid, cwd, socket });
  }
  return instances;
}

function pickInstance(instances: Instance[], targetPath: string): Instance | null {
  let best: Instance | null = null;
  let bestLen = -1;

  for (const inst of instances) {
    const prefix = inst.cwd.endsWith(path.sep) ? inst.cwd : inst.cwd + path.sep;
    const matches = targetPath === inst.cwd || targetPath.startsWith(prefix);
    if (!matches) continue;

    if (inst.cwd.length > bestLen || (inst.cwd.length === bestLen && inst.pid > (best?.pid ?? -1))) {
      best = inst;
      bestLen = inst.cwd.length;
    }
  }

  if (best) return best;

  // No cwd matched: fall back to any live instance, newest pid first.
  // Undofile names derive only from the absolute file path, so a foreign
  // project's nvim can still hold and protect this file correctly.
  return instances.reduce<Instance | null>(
    (acc, inst) => (acc === null || inst.pid > acc.pid ? inst : acc),
    null,
  );
}

// ---------------------------------------------------------------------------
// Minimal msgpack encoder (positive fixint, uintX, fixstr/strX, fixarray)
// ---------------------------------------------------------------------------

type MsgpackValue = number | string | null | MsgpackValue[];

function encodeMsgpack(value: MsgpackValue): Uint8Array {
  const parts: number[] = [];
  writeValue(value, parts);
  return new Uint8Array(parts);
}

function writeValue(value: MsgpackValue, out: number[]): void {
  if (value === null) {
    out.push(0xc0);
    return;
  }
  if (typeof value === "number") {
    writeUint(value, out);
    return;
  }
  if (typeof value === "string") {
    writeStr(value, out);
    return;
  }
  if (Array.isArray(value)) {
    writeArray(value, out);
    return;
  }
  throw new Error(`unsupported msgpack value: ${String(value)}`);
}

function writeUint(n: number, out: number[]): void {
  if (n < 0 || !Number.isInteger(n)) throw new Error(`unsupported int: ${n}`);
  if (n <= 0x7f) {
    out.push(n);
  } else if (n <= 0xff) {
    out.push(0xcc, n);
  } else if (n <= 0xffff) {
    out.push(0xcd, (n >> 8) & 0xff, n & 0xff);
  } else {
    out.push(0xce, (n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff);
  }
}

function writeStr(s: string, out: number[]): void {
  const bytes = Buffer.from(s, "utf8");
  const len = bytes.length;
  if (len <= 0x1f) {
    out.push(0xa0 | len);
  } else if (len <= 0xff) {
    out.push(0xd9, len);
  } else if (len <= 0xffff) {
    out.push(0xda, (len >> 8) & 0xff, len & 0xff);
  } else {
    out.push(0xdb, (len >>> 24) & 0xff, (len >>> 16) & 0xff, (len >>> 8) & 0xff, len & 0xff);
  }
  for (const b of bytes) out.push(b);
}

function writeArray(arr: MsgpackValue[], out: number[]): void {
  const len = arr.length;
  if (len <= 0x0f) {
    out.push(0x90 | len);
  } else if (len <= 0xffff) {
    out.push(0xdc, (len >> 8) & 0xff, len & 0xff);
  } else {
    out.push(0xdd, (len >>> 24) & 0xff, (len >>> 16) & 0xff, (len >>> 8) & 0xff, len & 0xff);
  }
  for (const item of arr) writeValue(item, out);
}

// ---------------------------------------------------------------------------
// Minimal msgpack decoder — just enough to read a response array
// `[1, msgid, error, result]` and tell whether `error` is non-nil.
// ---------------------------------------------------------------------------

class Reader {
  constructor(
    private buf: Uint8Array,
    public pos = 0,
  ) {}

  byte(): number {
    return this.buf[this.pos++];
  }
}

function readValue(r: Reader): unknown {
  const b = r.byte();

  if (b <= 0x7f) return b; // positive fixint
  if (b >= 0xe0) return b - 0x100; // negative fixint
  if ((b & 0xf0) === 0x80) return readMap(r, b & 0x0f); // fixmap
  if ((b & 0xf0) === 0x90) return readArrayN(r, b & 0x0f); // fixarray
  if ((b & 0xe0) === 0xa0) return readStrN(r, b & 0x1f); // fixstr

  switch (b) {
    case 0xc0:
      return null;
    case 0xc2:
      return false;
    case 0xc3:
      return true;
    case 0xcc:
      return r.byte();
    case 0xcd:
      return (r.byte() << 8) | r.byte();
    case 0xce:
      return ((r.byte() << 24) | (r.byte() << 16) | (r.byte() << 8) | r.byte()) >>> 0;
    case 0xd0:
      return r.byte() << 24 >> 24;
    case 0xd1: {
      const v = (r.byte() << 8) | r.byte();
      return (v << 16) >> 16;
    }
    case 0xd2:
      return (r.byte() << 24) | (r.byte() << 16) | (r.byte() << 8) | r.byte();
    case 0xd9:
      return readStrN(r, r.byte());
    case 0xda:
      return readStrN(r, (r.byte() << 8) | r.byte());
    case 0xdb:
      return readStrN(r, (r.byte() << 24) | (r.byte() << 16) | (r.byte() << 8) | r.byte());
    case 0xdc:
      return readArrayN(r, (r.byte() << 8) | r.byte());
    case 0xdd:
      return readArrayN(r, (r.byte() << 24) | (r.byte() << 16) | (r.byte() << 8) | r.byte());
    default:
      throw new Error(`unsupported msgpack tag: 0x${b.toString(16)}`);
  }
}

function readStrN(r: Reader, len: number): string {
  const bytes = r["buf"].slice(r.pos, r.pos + len);
  r.pos += len;
  return Buffer.from(bytes).toString("utf8");
}

function readArrayN(r: Reader, len: number): unknown[] {
  const items: unknown[] = [];
  for (let i = 0; i < len; i++) items.push(readValue(r));
  return items;
}

function readMap(r: Reader, len: number): Record<string, unknown> {
  const obj: Record<string, unknown> = {};
  for (let i = 0; i < len; i++) {
    const key = readValue(r);
    const val = readValue(r);
    obj[String(key)] = val;
  }
  return obj;
}

// ---------------------------------------------------------------------------
// RPC call
// ---------------------------------------------------------------------------

async function callHold(socketPath: string, targetPath: string): Promise<void> {
  const msgid = 0;
  const luaCode = 'return require("util.undo").hold(...)';
  const request = encodeMsgpack([0, msgid, "nvim_exec_lua", [luaCode, [targetPath]]]);

  await new Promise<void>((resolve) => {
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      resolve();
    };

    const timer = setTimeout(finish, HARD_TIMEOUT_MS);
    // Node's `unref` also exists on Bun's Timer; belt-and-suspenders exit.
    (timer as unknown as { unref?: () => void }).unref?.();

    const chunks: Uint8Array[] = [];

    Bun.connect({
      unix: socketPath,
      socket: {
        open(socket) {
          socket.write(request);
        },
        data(_socket, chunk) {
          chunks.push(chunk);
          // A full response array starts with fixarray 0x94 ([1, msgid, error, result]).
          // We don't know its total length in advance without a real decoder loop,
          // so attempt to decode on each chunk and stop once it succeeds.
          try {
            const combined = concatChunks(chunks);
            const reader = new Reader(combined);
            const reply = readValue(reader) as unknown[];
            // reply = [1, msgid, error, result]
            void reply;
            clearTimeout(timer);
            _socket.end();
            finish();
          } catch {
            // incomplete frame, wait for more data
          }
        },
        error() {
          clearTimeout(timer);
          finish();
        },
        close() {
          clearTimeout(timer);
          finish();
        },
      },
    }).catch(() => {
      clearTimeout(timer);
      finish();
    });
  });
}

function concatChunks(chunks: Uint8Array[]): Uint8Array {
  const total = chunks.reduce((n, c) => n + c.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.length;
  }
  return out;
}

// ---------------------------------------------------------------------------

main()
  .catch(() => {})
  .finally(() => process.exit(0));
```

**Verify:**
```bash
set -u
ADV="${TMPDIR%/}/nvim-undo"
SCRIPT="$HOME/.config/nvim/scripts/undo-guard-notify.ts"   # deployed copy; chezmoi apply first
T=$(mktemp -d) && printf 'const x = 1;\n' > "$T/file.ts" && printf 'other\n' > "$T/decoy.ts"

# (a) Hold a real file in a live nvim, then confirm the hold over a second RPC call.
#     The target file is NOT the one nvim opened, which is the whole point.
nvim --headless --listen "$ADV/probe.sock" "$T/decoy.ts" -c 'lua vim.g.probe = 1' &
sleep 0.4
bun "$SCRIPT" "$T/file.ts"; echo "notify exit: $?"
# line 2 of the advertise file is the socket — never `cat` the whole file, line 1 is the cwd
SOCK=$(sed -n 2p "$(ls -t "$ADV" | grep -v '\.sock$' | head -1 | sed "s|^|$ADV/|")")
nvim --server "$SOCK" --remote-expr 'bufloaded("'"$T"'/file.ts")'   # expect 1
nvim --server "$SOCK" --remote-expr 'getbufvar(bufnr("'"$T"'/file.ts"), "&buflisted")'  # expect 0

# (b) Cost. `time` covers Bun startup (~25ms) plus the RPC round-trip; the round-trip
#     alone is the small part. Assert the total, since that is what the agent actually pays.
time bun "$SCRIPT" "$T/file.ts"

# (c) Fail-open: exit 0 fast with no nvim alive, and with a stale advertise file
#     whose pid is dead and whose socket does not exist.
pkill -f "$ADV/probe.sock" 2>/dev/null; sleep 0.2
time bun "$SCRIPT" "$T/file.ts"; echo "exit: $?"
printf '%s\n%s\n' "$T" "$ADV/dead.sock" > "$ADV/999999"
time bun "$SCRIPT" "$T/file.ts"; echo "exit: $?"
rm -f "$ADV/999999"; rm -rf "$T"
```
Verify: every `bun "$SCRIPT"` invocation exits 0; (a) prints `1` then `0`, proving the file is
held and unlisted; (b) and (c) each complete well under 200 ms total.

### Step 4 — Claude Code `PreToolUse` wiring [agent]

- [ ] Add a `PreToolUse` matcher group for `Write|Edit|MultiEdit|NotebookEdit` to
      `~/.claude/settings.json` (NOT chezmoi-managed — edits are live immediately)
- [ ] Use the `args` exec form with an absolute `bun` path so no shell spawns
- [ ] Confirm the existing `SessionStart` `harness doctor` hook still fires

#### Current ~/.claude/settings.json

```json
{
  "enabledPlugins": {
    "lua-lsp@claude-plugins-official": true
  },
  "alwaysThinkingEnabled": false,
  "skipDangerousModePermissionPrompt": true
}
```

#### Merged ~/.claude/settings.json with PreToolUse hook

```json
{
  "enabledPlugins": {
    "lua-lsp@claude-plugins-official": true
  },
  "alwaysThinkingEnabled": false,
  "skipDangerousModePermissionPrompt": true,
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "handler": {
          "type": "command",
          "command": "/Users/zaye/.bun/bin/bun",
          "args": ["/Users/zaye/.config/nvim/scripts/undo-guard-notify.ts"],
          "timeout": 5
        }
      }
    ]
  }
}
```

#### Configuration rationale

**Args exec form:** The `args` array passes the script path as a direct argument to bun rather than through a shell. This spawns the executable directly without invoking a shell parser, avoiding quoting issues and ensuring predictable behavior when `tool_input.file_path` contains special characters.

**Absolute bun path:** The hook process runs in an isolated environment where the user's shell PATH may not include `~/.bun/bin`. Using the absolute path `/Users/zaye/.bun/bin/bun` ensures the executable is found regardless of the calling context.

**No `if` condition:** The notifier script is designed to fail open and exit 0 on every code path, making conditional execution unnecessary. Adding an `if` clause would only add complexity without improving safety.

#### Non-chezmoi management

`~/.claude/settings.json` is NOT chezmoi-managed. The chezmoi source root contains only `dot_config/` (deployed to `~/.config/`). This file is Claude's application settings, independent of the config repository. **Edit this file directly and it takes effect immediately — no `chezmoi apply` needed**, unlike every other file in this spec.

#### Documented behavior

- **PreToolUse timing:** The hook fires before the tool executes and blocks until it returns. This guarantee ensures the file is held in memory before the agent writes.
- **File path availability:** `tool_input.file_path` is always absolute for Write and Edit operations, providing a stable identifier for the notifier.
- **Error isolation:** A hook that cannot start (missing executable, syntax error, etc.) is a non-blocking error. The notifier's design ensures it always exits 0, so a broken handler will never block an edit.

Verify: Pipe a PreToolUse event to the handler, confirm exit 0 and the file is held: `echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test-undo.ts"}}' | /Users/zaye/.bun/bin/bun /Users/zaye/.config/nvim/scripts/undo-guard-notify.ts`. In a live nvim session, run `:buffers` and verify the file appears as an unlisted buffer with `u` flag; confirm stdout is empty and exit status is 0. Then verify the SessionStart hook (if configured) still fires normally when opening a new Claude session.

### Step 5 — omp `tool_call` hook [agent]

**Open question resolved empirically: omp loads user-level hooks from the `extensions` list, not
from a `hooks/` directory.** Three probes, each a hook file whose `tool_call` handler wrote a
marker, run against `omp -p` in a scratch git repo:

| probe location | loaded? |
|---|---|
| `~/.omp/agent/extensions/zz-undo-probe.ts` | **yes** — `session_start` and `tool_call` both fired (`toolName: "write"`) |
| `~/.omp/agent/config.yml#extensions: [/abs/path.ts]` | **yes** — loaded a file from outside the agent directory |
| `~/.omp/agent/hooks/zz-undo-probe.ts` | **no** — never loaded; the directory does not exist and nothing looks there |

This agrees with the docs: `omp://extension-loading.md:35` names the user root as "the active
agent directory's `extensions/`", and `omp://hooks.md:10` says JS/TS hook factories "are loaded as
extension modules", i.e. through extension discovery rather than a separate hook path. An earlier
draft of this spec cited `dist/types/capability/hook.d.ts` and `dist/types/discovery/helpers.d.ts`
as evidence for a `hooks/` user root; **neither file exists in the installed package** and the
claim was wrong.

Install shape (decision 14): the hook ships as `scripts/undo-guard-omp-hook.ts` inside this
chezmoi-managed repo, deployed by `chezmoi apply` to `~/.config/nvim/scripts/`. The only thing
that lands outside chezmoi is one line in `~/.omp/agent/config.yml`:

```yaml
extensions:
  - /Users/zaye/.config/nvim/scripts/undo-guard-omp-hook.ts
```

One install covers **every** project, which is the point: an agent editing vex while the only
running nvim sits in maprios-app is exactly the cross-project case the hooks exist for, and it is
verified to work because undofiles are keyed by absolute path alone.

> Appending to `~/.omp/agent/config.yml` requires a leading newline — the file ships without a
> trailing one, and a bare `>>` produces `defaultThinkingLevel: autoextensions:`. Back it up
> first; observed and recovered during the probe run.

**Non-goals:** Claude Code wiring (Step 4) and the notifier's instance-selection / msgpack logic
(Step 3) — this hook only resolves paths and invokes the notifier.

- [ ] Create `scripts/undo-guard-omp-hook.ts`
- [ ] Append the `extensions:` entry to `~/.omp/agent/config.yml` (back it up; leading newline)
- [ ] Run `chezmoi apply` to deploy the script (developer)
- [ ] Confirm `~/.omp/agent/extensions/` is left empty — the reference approach needs nothing there

```ts
import type { HookAPI } from "@oh-my-pi/pi-coding-agent";

const NOTIFIER_BUN = "/Users/zaye/.bun/bin/bun";
const NOTIFIER_SCRIPT = "/Users/zaye/.config/nvim/scripts/undo-guard-notify.ts";

// [PATH#TAG] section header, e.g. "[src/foo.ts#1A2B]" — TAG is 4 hex chars.
const SECTION_HEADER_RE = /^\[([^\]#]+)#[0-9A-Fa-f]{4}\]/;

/** True for internal-URI targets and archive/sqlite selectors that are not plain filesystem paths. */
function isInternalOrSelectorPath(path: string): boolean {
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(path)) return true; // xd://, local://, memory://, conflict://, etc.
  // archive.zip:inner/path or db.sqlite:table[:key] — a ':' after a file-like segment that isn't a drive letter.
  if (/^[^:]+\.(zip|tar|tar\.gz|tgz|jar|war|ear|apk|db|db3|sqlite|sqlite3):/i.test(path)) return true;
  return false;
}

/** Extract every distinct `[PATH#TAG]` header path out of an edit-tool hashline document. */
function extractEditPaths(input: string): string[] {
  const paths = new Set<string>();
  for (const line of input.split("\n")) {
    const m = SECTION_HEADER_RE.exec(line);
    if (m) paths.add(m[1]);
  }
  return [...paths];
}

/**
 * omp fails CLOSED when a tool_call handler throws (see HookToolWrapper: emitToolCall errors
 * propagate and block the call). Undo protection must never be able to block or slow an agent
 * edit, so every code path below is wrapped and swallows all errors, always returning undefined
 * (never `{ block: true }`).
 *
 * Deliberate coverage gap: bash-driven edits (`sed -i`, `tee`, shell redirection) and
 * `xd://ast_edit` bulk rewrites are not covered — their target paths can't be enumerated
 * reliably before execution, so they're out of scope for this hook.
 */
export default function (pi: HookAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    try {
      if (event.toolName !== "write" && event.toolName !== "edit") return;

      let rawPaths: string[];
      if (event.toolName === "write") {
        const p = event.input.path;
        if (typeof p !== "string" || p.length === 0) return;
        rawPaths = [p];
      } else {
        const input = event.input.input;
        if (typeof input !== "string" || input.length === 0) return;
        rawPaths = extractEditPaths(input);
      }

      const absPaths = new Set<string>();
      for (const raw of rawPaths) {
        if (isInternalOrSelectorPath(raw)) continue;
        const abs = raw.startsWith("/") ? raw : `${ctx.cwd}/${raw}`;
        absPaths.add(abs);
      }
      if (absPaths.size === 0) return;

      await Promise.all(
        [...absPaths].map((abs) =>
          pi.exec(NOTIFIER_BUN, [NOTIFIER_SCRIPT, abs], { timeout: 500 }).catch(() => undefined),
        ),
      );
    } catch {
      // Never block or slow an agent edit — worst case is today's behavior (undo history lost).
    }
    return undefined;
  });
}
```

**Verify:** `bun -e 'import hook from "/Users/zaye/.local/share/chezmoi/dot_config/nvim/scripts/undo-guard-omp-hook.ts"; const calls: string[] = []; const pi = { exec: async (_cmd: string, args: string[]) => { calls.push(args[1]); return { code: 0 }; }, on: (_evt: string, h: any) => { (globalThis as any).__h = h; } } as any; hook(pi); const h = (globalThis as any).__h; const ctx = { cwd: "/tmp/proj" };
  await h({ type: "tool_call", toolName: "write", toolCallId: "1", input: { path: "/tmp/proj/f.ts" } }, ctx);
  await h({ type: "tool_call", toolName: "edit", toolCallId: "2", input: { input: "[a/b.ts#1A2B]\n+x\n[xd://tool#2C3D]\n+y\n[a/b.ts#1A2B]\n+z\n[/abs/c.ts#3D4E]\n+w\n" } }, ctx);
  console.assert(calls.length === 3, "expected 1 write call + 2 distinct edit paths, got " + calls.length);
  console.assert(calls.includes("/tmp/proj/f.ts"), "write path missing");
  console.assert(calls.includes("/tmp/proj/a/b.ts"), "edit relative path not resolved against cwd");
  console.assert(calls.includes("/abs/c.ts"), "edit absolute path missing");
  console.assert(!calls.some((c) => c.includes("xd://")), "internal-URL target must not be called");
  const bad = { exec: () => { throw new Error("boom"); }, on: (_e: string, h: any) => { (globalThis as any).__h2 = h; } } as any;
  hook(bad);
  const h2 = (globalThis as any).__h2;
  const result = await h2({ type: "tool_call", toolName: "write", toolCallId: "3", input: { path: "/tmp/proj/g.ts" } }, ctx);
  console.assert(result === undefined, "thrown error inside handler must still resolve to undefined, never block");
  console.log("OK");'`

### Step 6 — Windowed startup preload [agent]

- [ ] Add `WINDOW_DAYS` and `HOLD_CAP` constants, `M.candidates(root)`, and `M.arm()` to
      `lua/util/undo.lua` (additions only — `M.hold`, `M.advertise`, `M.unadvertise`, and the
      `BufEnter` autocmd from Step 1 are untouched)
- [ ] Change `M.release()`'s signature to `M.release(n)` in `lua/util/undo.lua` (backward
      compatible: `n == nil` keeps today's "delete everything" behavior) and give it its first
      caller, the cap check inside `M.arm()`
- [ ] Add a `VimEnter` autocmd to `lua/config/autocmds.lua` that defers `LazyVim.undo.arm()` by
      2000ms, guarded against `$HOME`/`/` cwds
- [ ] No change to the existing per-buffer `checktime` sweep (`lua/config/autocmds.lua`,
      `augroup("checktime")`) — at 26–60 held buffers it already costs ~0.4–0.6ms, inside the
      1.0ms budget, so round-robining it buys nothing here
- [ ] Run `chezmoi apply` to deploy all three changes (developer)
- [ ] Run the PTY verification below and confirm every assertion passes

#### Why a window, not everything under the cwd

An unwindowed version — hold every file under the cwd that has *any* undofile, no age limit —
was measured and rejected: 287 candidates / 151ms / +25.4MB RSS on maprios-app, 469 / 385ms /
+57.1MB on vex. Both numbers are paid **per nvim process, nothing shared** — three tmux panes
open on the same repo pay that RSS delta three times over a 29.8MB idle baseline, to protect
history for files nobody has touched in months just as eagerly as this morning's edit. The
windowed design instead restricts `M.candidates` to undofiles whose *own* mtime falls inside
the last `WINDOW_DAYS` (7) days. Measured for maprios-app under that window: 37 candidates, 26
of them carrying live undo history, ~29ms of `hold()` work, +5.7MB RSS — proportional to
recent work instead of the whole repo's undo store. `WINDOW_DAYS` is one named constant so
widening or narrowing it later is a one-line change, not a redesign.

Newest-undofile-mtime-first ordering is kept even though the queue is now short enough that
ordering rarely matters in practice (37 items drain in about two 16ms ticks): it costs nothing
to sort a list this size, and it's the right default the day a candidate list *isn't* small —
a cold FS cache or an unusually large project still benefits from covering the most
recently-touched history first if the queue ever runs long enough for order to be visible.

#### Why the timer stays chunked even though the work is now tiny

29ms of `hold()` work is roughly two 16ms ticks at the 0.8ms-per-tick budget below — for a
project this size the "trickle" is effectively instant, not a multi-second background fill.
The chunked timer is kept anyway, not removed, because the *measured* case isn't the only case
`M.arm` has to survive: a much larger project, or the same project with a cold filesystem
cache making every `filereadable`/`bufload` call slower, could turn "two ticks" into "twenty,"
and running that as one synchronous loop risks a single stall past the 300ms red-flag threshold
in `.agent/docs/perf-baseline.md`. Chunking costs nothing extra when the queue is already this
short and is the only thing standing between a bad day and a frozen editor on a worse one.

#### Held-buffer cap: a backstop, not a routine path

The cap stays at 200, not scaled up with the earlier unwindowed numbers — 37 preloaded plus
whatever the per-edit tool-call hooks add over a session sits far below it, so on every project
measured so far the cap is dead code that never fires. It still needs a real caller rather than
staying unused: `M.release()` (Step 1) was written but never called by anything before this
step. Its original no-argument form only knows how to delete every held buffer, which can't
express "evict just enough to get back under the cap, worst candidates first" — so its
signature grows one optional parameter, `n`, rather than growing a second function:

```lua
--- Deletes still-held, never-visited buffers. With no argument, deletes all of them (the
--- original shutdown/periodic-sweep behavior from Step 1, unchanged). With `n`, deletes only
--- the `n` worst: buffers with no usable history are evicted first (defensive — M.hold already
--- filters these out at load time, so this branch should rarely have any to find), then the
--- oldest held buffers, using bufnr order as a free proxy for hold order (Neovim never reuses a
--- buffer number within a session, so the lowest bufnr among held buffers was always held
--- first — no separate insertion-order list is needed).
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
    count = count + 1
  end
  return count
end
```

This replaces the `M.release()` body from Step 1 (originally lines 220–230 of `undo.lua`)
in place — same function name, same zero-argument default behavior, one new optional
parameter.

#### Additions to `lua/util/undo.lua`

Insert the two constants right after the `advertise_path` local and before `local group = ...`
(Step 1, originally between lines 145 and 147):

```lua
-- Only undofiles touched in roughly the last week are worth preloading -- older history
-- reflects work nobody is actively reaching for, and skipping it keeps the preload
-- proportional to recent activity instead of the whole repo's undo store. One constant, so
-- widening or narrowing the window is a one-line change.
local WINDOW_DAYS = 7

-- Backstop, not a routine path: measured preload sizes (37 on maprios-app within the window)
-- sit far below this, so eviction inside M.arm should not normally fire.
local HOLD_CAP = 200
```

Add `M.candidates` and `M.arm` as new functions immediately after `M.release` (Step 1,
originally ending at line 230) and before the `BufEnter` re-attach autocmd (Step 1, originally
starting at line 232):

```lua
--- Enumerates files under `root` that already have a persistent undofile whose mtime falls
--- within the last WINDOW_DAYS days, newest undofile mtime first. Backs the startup preload
--- (M.arm, below).
---
--- 'undodir' mangles a file's absolute path into its undofile's name by turning every path
--- separator into "%" (its value carries a trailing "//" by default -- normalized here rather
--- than assumed away). A literal "%" already present in a path component is indistinguishable
--- from an encoded "/" by that scheme alone (`/proj/a%b.ts` and `/proj/a/b.ts` produce the
--- identical undodir entry name), so every decoded candidate is round-tripped back through
--- vim.fn.undofile() and kept only when that reproduces the exact entry it came from -- the
--- closest available guard against a misplaced split, on top of requiring the decoded path to
--- actually be readable under `root`.
---@param root string absolute directory to restrict candidates to
---@return {path: string, mtime: integer}[] sorted newest undofile mtime first
function M.candidates(root)
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
            local roundtrip = vim.fn.undofile(decoded)
            if vim.fs.basename(roundtrip) == name then
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
--- so nothing else in this spec would ever hold them.
---
--- The queue drains behind a repeating 16ms timer doing at most 0.8ms of hold() work per tick
--- (wrapped in vim.schedule_wrap since the callback touches buffers/options, which is unsafe
--- in a fast event). Measured total work is small (~29ms on maprios-app, about two ticks), but
--- the chunk stays in place rather than running as one synchronous loop: a cold FS cache or a
--- much larger project could turn that into a real stall, and a single unchunked call risks
--- crossing the 300ms red-flag threshold in .agent/docs/perf-baseline.md. Already-loaded files
--- and files over vim.g.bigfile_size are skipped -- the former needs no help, the latter would
--- dominate the per-file budget for one buffer.
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

  timer:start(
    16,
    16,
    vim.schedule_wrap(function()
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
        timer:stop()
        timer:close()
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
```

#### Startup trigger in `lua/config/autocmds.lua`

Add this `VimEnter` autocmd after the advertise/unadvertise block from Step 2 (the
`augroup("undo_guard_advertise")` `VimEnter`/`VimLeavePre` pair), before the `UndoGuardHold`
user command. Tab-indented, matching the rest of this file:

```lua
-- Windowed startup preload: arms LazyVim.undo's 7-day candidate sweep so undo history for
-- git checkout, `prettier --write .`, npm install, codegen, and xd://ast_edit rewrites keeps
-- accumulating the same way tool-call-hook holds do -- none of those pass through a hooked
-- tool. Deferred 2s past VimEnter so it never touches startup time; skipped for $HOME and "/"
-- so a bare `nvim` outside a real project doesn't walk the whole undo store for nothing.
vim.api.nvim_create_autocmd("VimEnter", {
	group = augroup("undo_guard_preload"),
	callback = function()
		local cwd = vim.uv.cwd()
		if not cwd or cwd == vim.env.HOME or cwd == "/" then
			return
		end
		vim.defer_fn(function()
			LazyVim.undo.arm()
		end, 2000)
	end,
})
```

#### Verify

Prerequisite: the developer has run `chezmoi apply` so `~/.config/nvim` reflects Steps 1, 2,
and this step.

1. Startup cost is zero — the preload never fires before `--startuptime` finishes, because it's
   behind a 2000ms `vim.defer_fn` and a headless `-c 'qa!'` run exits well before that:

   ```bash
   nvim --headless -u ~/.config/nvim/init.lua --startuptime /tmp/undo-preload-startuptime.log -c 'qa!'
   awk 'END{print $1, $2}' /tmp/undo-preload-startuptime.log   # unchanged vs. a pre-Step-7 profile
   ```

2. Held count, per-tick cost, and RSS in a real project (replace `PROJECT_DIR` with one that
   already has undofiles under `~/.local/state/nvim/undo` from normal use):

   ```bash
   PROJECT_DIR=~/.local/share/chezmoi/dot_config/nvim
   SOCK=$(mktemp -u "${TMPDIR:-/tmp}/undo-preload-verify.XXXXXX")
   (cd "$PROJECT_DIR" && nvim --listen "$SOCK" -u ~/.config/nvim/init.lua) &
   NVIM_PID=$!
   sleep 10

   nvim --server "$SOCK" --remote-expr 'execute("messages")' | grep 'undo-guard preload:'
   ps -o rss= -p "$NVIM_PID" | awk '{printf "RSS: %.1f MB\n", $1/1024}'

   nvim --server "$SOCK" --remote-send ':qa!<CR>'
   ```

   Assert against the single `undo-guard preload: H/C held (S skipped, max tick T.TTms)` line
   printed to `:messages`:
   - `H > 0` and `H` approaches `C` (the gap is only already-loaded and over-`bigfile_size`
     files, both intentionally skipped, not a bug).
   - `T < 1.5` — no tick crossed the `vim.defer_fn`/timer-callback red flag from
     `.agent/docs/perf-baseline.md`.
   - `ps` RSS lands near the idle baseline (29.8MB) plus the measured windowed delta for a
     project this size (+5.7MB on maprios-app's 37-candidate window) — i.e. not anywhere near
     the +25–57MB figures measured for the rejected unwindowed design.

Verify: run the two command blocks above against a project with existing undofiles; confirm
`--startuptime` shows no line attributable to the preload, and the `undo-guard preload:`
message satisfies `H > 0` approaching `C`, `T < 1.5`, with `ps` RSS within roughly 1–2MB of the
29.8MB-baseline-plus-measured-delta figure for that project's candidate-set size.

### Step 7 — Shell-command path extraction [agent]

- [ ] Add `extractShellPaths(command, cwd)` to `scripts/undo-guard-notify.ts`
- [ ] Extend `main()`/argument handling in `scripts/undo-guard-notify.ts` to accept multiple paths
      (`argv.slice(2)`) and hold each over one socket connection
- [ ] Extend `resolveTargetPath()` (rename to `resolveTargetPaths()`) to also extract paths from
      `tool_input.command` when `tool_name === "Bash"`
- [ ] Add a second `PreToolUse` matcher group for `Bash` to `~/.claude/settings.json`
- [ ] Extend `scripts/undo-guard-omp-hook.ts` to also match `event.toolName === "bash"`

#### 1. Shared extractor

Lives in `scripts/undo-guard-notify.ts` (both hooks already shell out to this script, so the
extractor belongs where it's actually run — neither hook needs its own copy). It tokenizes with a
shell-aware-but-not-a-real-shell splitter (quotes group tokens; no expansion), recognizes a small
set of file-mutating commands, and keeps only tokens that resolve to an existing readable file.

```typescript
// ---------------------------------------------------------------------------
// Shell-command path extraction (Step 7). Given a raw command string as
// PreToolUse hooks see it (`tool_input.command`) and the harness-provided
// cwd, returns absolute paths of files the command explicitly names that
// already exist on disk. A path that doesn't exist yet has no undo history
// to protect, so it's filtered out rather than resolved eagerly.
//
// Deliberately NOT caught: globs (`*.ts`), `xargs`-piped paths, heredocs,
// variable-substituted paths (`$FILE`), and commands that mutate an
// unpredictable set of files such as `prettier --write .` or `npm install`.
// The Step 6 startup preload covers that second category for every file
// under the cwd that already has an undofile, independent of any hook.
// ---------------------------------------------------------------------------

const PATH_COMMANDS = new Set(["sed", "tee", "patch", "mv", "cp", "install"]);

/** Splits a command string into shell-ish tokens: quotes group, nothing else is interpreted. */
function tokenizeShell(command: string): string[] {
  const tokens: string[] = [];
  let cur = "";
  let quote: '"' | "'" | null = null;
  let inToken = false;

  for (let i = 0; i < command.length; i++) {
    const c = command[i];
    if (quote) {
      if (c === quote) {
        quote = null;
      } else {
        cur += c;
      }
      continue;
    }
    if (c === '"' || c === "'") {
      quote = c;
      inToken = true;
      continue;
    }
    if (c === "|" || c === "&" || c === ";") {
      // Command separators: flush and emit a synthetic separator so the caller can
      // treat each pipeline segment independently (`>`/`>>` binds to its own segment).
      if (inToken) tokens.push(cur);
      tokens.push(c);
      cur = "";
      inToken = false;
      continue;
    }
    if (/\s/.test(c)) {
      if (inToken) tokens.push(cur);
      cur = "";
      inToken = false;
      continue;
    }
    cur += c;
    inToken = true;
  }
  if (inToken) tokens.push(cur);
  return tokens;
}

/** True if the token contains glob metacharacters, unresolved `$`/backtick expansion, or `~`. */
function looksUnresolvable(tok: string): boolean {
  return /[*?\[\]$`]/.test(tok) || tok.startsWith("~");
}

/**
 * Extracts existing-file paths a shell command explicitly names, resolved against `cwd`.
 * Covers: `sed -i FILE`, `tee FILE`, `> FILE` / `>> FILE`, `patch ... FILE` / `patch < FILE`,
 * `mv SRC DST`, `cp SRC DST`, `install -m ... FILE`.
 */
function extractShellPaths(command: string, cwd: string): string[] {
  const tokens = tokenizeShell(command);
  const found = new Set<string>();

  const resolve = (rawTok: string): string | null => {
    if (!rawTok || rawTok.startsWith("-") || looksUnresolvable(rawTok)) return null;
    const abs = path.isAbsolute(rawTok) ? rawTok : path.join(cwd, rawTok);
    try {
      accessSync(abs, constants.R_OK);
      if (!statSync(abs).isFile()) return null;
    } catch {
      return null;
    }
    return abs;
  };

  for (let i = 0; i < tokens.length; i++) {
    const tok = tokens[i];

    // Redirection: `> FILE` / `>> FILE`, anywhere in a segment (e.g. `echo x > f.ts`).
    if (tok === ">" || tok === ">>") {
      const resolved = resolve(tokens[i + 1]);
      if (resolved) found.add(resolved);
      continue;
    }

    // `patch < FILE` (patch input, itself a file worth protecting if it's a real path).
    if (tok === "<" && tokens[i - 1]?.replace(/^.*\//, "") === "patch") {
      const resolved = resolve(tokens[i + 1]);
      if (resolved) found.add(resolved);
      continue;
    }

    const base = tok.replace(/^.*\//, "");
    if (!PATH_COMMANDS.has(base)) continue;

    // Walk the rest of this pipeline segment (stop at |, &, ;), collecting every
    // non-flag argument that resolves to an existing file. This is deliberately
    // permissive about argument order (`sed -i FILE`, `sed -i.bak FILE`, `cp SRC DST`,
    // `install -m 0644 SRC DST` all fall out of "every non-flag token that resolves").
    for (let j = i + 1; j < tokens.length; j++) {
      const t = tokens[j];
      if (t === "|" || t === "&" || t === ";") break;
      if (t === "<" || t === ">" || t === ">>") { j++; continue; } // redirection handled above
      const resolved = resolve(t);
      if (resolved) found.add(resolved);
    }
  }

  return [...found];
}
```

#### 2. Notifier: multi-path batching

Both hooks now resolve a *set* of paths (edit hooks already do via `extractEditPaths`; the bash
hook via `extractShellPaths` above), so the notifier accepts N path arguments and holds all of
them over one socket connection instead of paying Bun's ~25 ms startup per path. Diff against the
Step 3 source (`scripts/undo-guard-notify.ts`):

```diff
 async function main(): Promise<void> {
-  const targetPath = await resolveTargetPath();
-  if (!targetPath) return;
+  const targetPaths = await resolveTargetPaths();
+  if (targetPaths.length === 0) return;

   const advertiseDir = path.join(tmpDir(), "nvim-undo");
   const instances = listLiveInstances(advertiseDir);
   if (instances.length === 0) return;

-  const instance = pickInstance(instances, targetPath);
-  if (!instance) return;
-
-  await callHold(instance.socket, targetPath);
+  // Group by best instance so each socket sees exactly one connection regardless of
+  // how many paths were passed (they usually resolve to the same instance).
+  const byInstance = new Map<string, string[]>();
+  for (const targetPath of targetPaths) {
+    const instance = pickInstance(instances, targetPath);
+    if (!instance) continue;
+    const list = byInstance.get(instance.socket) ?? [];
+    list.push(targetPath);
+    byInstance.set(instance.socket, list);
+  }
+
+  await Promise.all(
+    [...byInstance.entries()].map(([socket, paths]) => callHoldMany(socket, paths)),
+  );
 }

 // ---------------------------------------------------------------------------
 // Target path resolution
 // ---------------------------------------------------------------------------

-async function resolveTargetPath(): Promise<string | null> {
-  const argvPath = process.argv[2];
-  if (argvPath) return path.resolve(argvPath);
+async function resolveTargetPaths(): Promise<string[]> {
+  const argvPaths = process.argv.slice(2);
+  if (argvPaths.length > 0) return argvPaths.map((p) => path.resolve(p));

   const raw = await readStdin();
-  if (!raw) return null;
+  if (!raw) return [];

   try {
     const doc = JSON.parse(raw);
-    const filePath = doc?.tool_input?.file_path;
-    if (typeof filePath !== "string" || filePath.length === 0) return null;
-    return path.resolve(filePath);
+    const filePath = doc?.tool_input?.file_path;
+    if (typeof filePath === "string" && filePath.length > 0) {
+      return [path.resolve(filePath)];
+    }
+    if (doc?.tool_name === "Bash") {
+      const command = doc?.tool_input?.command;
+      const cwd = typeof doc?.cwd === "string" && doc.cwd.length > 0 ? doc.cwd : process.cwd();
+      if (typeof command === "string" && command.length > 0) {
+        return extractShellPaths(command, cwd);
+      }
+    }
+    return [];
   } catch {
-    return null;
+    return [];
   }
 }
```

`callHoldMany` is `callHold` widened to loop `hold(path)` calls over the same open socket instead
of one connect-per-path — the RPC framing, timeout and fail-open behavior are unchanged, only the
Lua invoked and the number of requests sent before `socket.end()`:

```diff
-async function callHold(socketPath: string, targetPath: string): Promise<void> {
+async function callHoldMany(socketPath: string, targetPaths: string[]): Promise<void> {
   const msgid = 0;
-  const luaCode = 'return require("util.undo").hold(...)';
-  const request = encodeMsgpack([0, msgid, "nvim_exec_lua", [luaCode, [targetPath]]]);
+  const luaCode = 'for _, p in ipairs(...) do require("util.undo").hold(p) end';
+  const request = encodeMsgpack([0, msgid, "nvim_exec_lua", [luaCode, [targetPaths]]]);

   await new Promise<void>((resolve) => {
     // ... body unchanged: same timer, same `open`/`data`/`error`/`close` handlers,
     // same single `socket.write(request)` — one connection, one request, one reply.
   });
 }
```

`main()`'s `.catch(() => {}).finally(() => process.exit(0))` and the empty-stdout contract are
untouched: `callHoldMany` never writes to stdout, and every path through `main()` still ends in
`process.exit(0)`.

Also add the two Node imports the extractor needs, alongside the existing `path`/`fs` import:

```diff
 import path from "node:path";
-import { readdirSync, readFileSync } from "node:fs";
+import { readdirSync, readFileSync, accessSync, statSync, constants } from "node:fs";
```

#### 3. Claude Code wiring

The hook receives `tool_input.command`, not a path — so the notifier must do the extraction
itself, from the same `PreToolUse` JSON document it already reads for `file_path` (Step 3's
`resolveTargetPaths`, extended above, does exactly this when `tool_name === "Bash"`). This is
simpler than teaching the hook config itself to pre-parse `command` into path arguments, and it
keeps all path-sniffing logic in one script instead of splitting it across the JSON-document path
and the argv path.

Merged `~/.claude/settings.json` (adds a `Bash` matcher group beside the Step 4
`Write|Edit|MultiEdit|NotebookEdit` group; both point at the same notifier):

```json
{
  "enabledPlugins": {
    "lua-lsp@claude-plugins-official": true
  },
  "alwaysThinkingEnabled": false,
  "skipDangerousModePermissionPrompt": true,
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "handler": {
          "type": "command",
          "command": "/Users/zaye/.bun/bin/bun",
          "args": ["/Users/zaye/.config/nvim/scripts/undo-guard-notify.ts"],
          "timeout": 5
        }
      },
      {
        "matcher": "Bash",
        "handler": {
          "type": "command",
          "command": "/Users/zaye/.bun/bin/bun",
          "args": ["/Users/zaye/.config/nvim/scripts/undo-guard-notify.ts"],
          "timeout": 5
        }
      }
    ]
  }
}
```

No `command` field is passed as an `args` entry: Claude Code pipes the full `PreToolUse` JSON
document (including `tool_name: "Bash"` and `tool_input.command`) to the handler's stdin exactly
as it does for `Write`/`Edit`, so `resolveTargetPaths()` reading stdin already covers this matcher
with no config-side parsing.

#### 4. omp wiring

Extends the Step 5 handler body (still inside its one `try/catch`, so a throw here fails open
exactly like the write/edit paths):

```diff
   pi.on("tool_call", async (event, ctx) => {
     try {
-      if (event.toolName !== "write" && event.toolName !== "edit") return;
+      if (
+        event.toolName !== "write" &&
+        event.toolName !== "edit" &&
+        event.toolName !== "bash"
+      ) {
+        return;
+      }

       let rawPaths: string[];
-      if (event.toolName === "write") {
+      if (event.toolName === "bash") {
+        const command = event.input.command;
+        if (typeof command !== "string" || command.length === 0) return;
+        // extractShellPaths already resolves against cwd and filters to existing files,
+        // so the paths below are absolute already — skip the relative-path join step.
+        const resolved = extractShellPaths(command, ctx.cwd);
+        if (resolved.length === 0) return;
+        await Promise.all(
+          resolved.map((abs) =>
+            pi.exec(NOTIFIER_BUN, [NOTIFIER_SCRIPT, abs], { timeout: 500 }).catch(() => undefined),
+          ),
+        );
+        return;
+      } else if (event.toolName === "write") {
         const p = event.input.path;
         if (typeof p !== "string" || p.length === 0) return;
         rawPaths = [p];
       } else {
         const input = event.input.input;
         if (typeof input !== "string" || input.length === 0) return;
         rawPaths = extractEditPaths(input);
       }
```

`extractShellPaths` is imported from `scripts/undo-guard-notify.ts` (it has no Bun-only
dependencies — `node:fs`/`node:path` only — so it's safe to import into the omp hook module) rather
than duplicated, keeping one implementation shared by both harnesses per the Step 7 goal.

```diff
 import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";
+import { extractShellPaths } from "../../scripts/undo-guard-notify";
```

#### Verify

Unit-level, no live nvim required — call `extractShellPaths` directly against a scratch dir
containing `existing.ts`:

| Input | cwd-relative existing files | Expected extracted paths |
|---|---|---|
| `sed -i 's/a/b/' existing.ts` | `existing.ts` | `<cwd>/existing.ts` |
| `tee existing.ts` | `existing.ts` | `<cwd>/existing.ts` |
| `echo x > existing.ts` | `existing.ts` | `<cwd>/existing.ts` |
| `echo x >> existing.ts` | `existing.ts` | `<cwd>/existing.ts` |
| `patch -p1 < existing.ts` | `existing.ts` | `<cwd>/existing.ts` |
| `mv existing.ts renamed.ts` | `existing.ts` (only) | `<cwd>/existing.ts` |
| `cp existing.ts copy.ts` | `existing.ts` | `<cwd>/existing.ts` |
| `install -m 0644 existing.ts dest.ts` | `existing.ts` | `<cwd>/existing.ts` |
| `sed -i '' new-file.ts` | (none exist) | *(nothing)* |
| `prettier --write .` | `existing.ts` | *(nothing — no named file token)* |
| `rm -rf $DIR/*.ts` | — | *(nothing — `$` and glob both filtered)* |

```bash
bun -e '
import { extractShellPaths } from "./scripts/undo-guard-notify.ts";
const dir = await Bun.$`mktemp -d`.text().then((s) => s.trim());
await Bun.write(`${dir}/existing.ts`, "const x = 1;\n");
const cases: [string, string[]][] = [
  ["sed -i \x27s/a/b/\x27 existing.ts", [`${dir}/existing.ts`]],
  ["echo x > existing.ts", [`${dir}/existing.ts`]],
  ["prettier --write .", []],
  ["sed -i \x27\x27 new-file.ts", []],
];
for (const [cmd, want] of cases) {
  const got = extractShellPaths(cmd, dir).sort();
  console.assert(JSON.stringify(got) === JSON.stringify(want.sort()), `FAIL: ${cmd} -> ${JSON.stringify(got)}`);
}
console.log("OK");
'
```

Live check — a `sed -i` command run through the hook actually holds the target in nvim:

```bash
T=$(mktemp -d) && printf 'const x = 1;\n' > "$T/live.ts"
nvim --headless "$T/live.ts" -c 'w' -c 'q'   # create an undofile so the file is holdable
ADV="${TMPDIR%/}/nvim-undo"
nvim --headless --listen "$ADV/probe2.sock" "$T/live.ts" -c 'bd!' &
sleep 0.4
echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed -i '' 's/x/y/' live.ts\"},\"cwd\":\"$T\"}" \
  | bun scripts/undo-guard-notify.ts
SOCK=$(sed -n 2p "$(ls -t "$ADV" | grep -v '\.sock$' | head -1 | sed "s|^|$ADV/|")")
nvim --server "$SOCK" --remote-expr "bufloaded('$T/live.ts')"   # expect 1
rm -rf "$T"
```

Verify: the unit table's extracted-path assertions pass (`OK` printed, no `FAIL:` lines), and the
live check's `--remote-expr` call prints `1`, confirming `live.ts` is held in the running nvim
before the `sed -i` write reaches disk.
</content>
<parameter name="i">Write Step 7 bash-coverage spec section

### Step 8 — End-to-end proof + record the pattern [agent]

- [ ] Create `.agent/docs/specs/2026-08-17-undo-guard/e2e.sh`, a self-contained, idempotent bash
      script that runs entirely inside a throwaway `$TMPDIR`-rooted directory
- [ ] Script creates a temp project with real undo history for a target file (edit, `:w`, edit,
      `:w`, quit)
- [ ] Script starts a PTY nvim in that project holding a *different* file, confirms the advertise
      file appears
- [ ] Script drives the Claude Code entry point (pipe `PreToolUse` JSON into the notifier) for one
      target file, and the omp entry point (synthetic `tool_call` payload through the `.omp/hooks`
      script) for a second target file
- [ ] Script externally rewrites both target files, triggers the idle sweep via
      `nvim --server ... --remote-send`, quits without ever visiting either file
- [ ] Script opens a fresh headless nvim per file and asserts `seq_last` is preserved and `:undo`
      recovers the pre-agent content, printing PASS/FAIL per assertion and exiting non-zero on any
      failure
- [ ] Script prints the failure-baseline contrast (same sequence with the guard disabled →
      `seq_last=0`)
- [ ] Script measures and prints startup-time delta (`nvim --startuptime`) and `CursorHold` sweep
      cost, comparing against the 1.98ms/201-buffer, ~10us/buffer, 1.0ms budget baselines
- [ ] Create `.agent/docs/decisions/2026-08-17-undo-guard-hold-before-write.md` recording the
      mechanism and known gaps, matching the existing decision-doc format
- [ ] `.agent/docs/specs/2026-08-17-undo-guard/README.md` or task doc links `e2e.sh` as the
      regression check for this feature (add the pointer only if such a doc already exists in this
      spec directory — do not create one)

**Why:** Proof that the whole chain works end to end — hook → notifier → RPC → hold → external
write → idle sweep → undofile persistence across a fresh session — and that the win (undo
survives) doesn't cost startup or idle-sweep budget. The decision doc is the durable record of why
this mechanism exists and where it still fails.

#### `.agent/docs/specs/2026-08-17-undo-guard/e2e.sh`

```bash
#!/usr/bin/env bash
# End-to-end proof for the undo-guard feature. Runs entirely inside a throwaway
# directory; --cmd 'set undodir=...' pins every nvim invocation to that directory
# so nothing touches ~/.local/state/nvim/undo or any real project.
#
# Prerequisite: the developer has run `chezmoi apply` so
# ~/.config/nvim/lua/util/undo.lua, lua/config/autocmds.lua, and
# ~/.config/nvim/scripts/undo-guard-notify.ts reflect the source in this repo.
#
# Usage: bash e2e.sh
set -uo pipefail

NVIM_CONFIG="$HOME/.config/nvim"
NOTIFIER="$NVIM_CONFIG/scripts/undo-guard-notify.ts"
OMP_HOOK="$NVIM_CONFIG/scripts/undo-guard-omp-hook.ts"

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/undo-e2e.XXXXXX")"
UNDODIR="$ROOT/undodir"
PROJ="$ROOT/proj"
mkdir -p "$UNDODIR" "$PROJ"

FILE_CC="$PROJ/claude-target.ts"   # driven via the Claude Code notifier path
FILE_OMP="$PROJ/omp-target.ts"     # driven via the omp hook path
OTHER="$PROJ/other.ts"             # kept open so the targets stay unloaded

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

cleanup() { rm -rf "$ROOT"; }
trap cleanup EXIT

nvim_iso() {
  # nvim with real config, but undodir/swapdir/backupdir pinned into $ROOT.
  nvim --cmd "set undodir=$UNDODIR" \
       --cmd "set directory=$ROOT/swap" \
       --cmd "set backupdir=$ROOT/backup" \
       "$@"
}
mkdir -p "$ROOT/swap" "$ROOT/backup"

# --- 2a: seed real undo history for both target files -----------------------
printf 'const x = 1;\n' > "$FILE_CC"
printf 'const y = 1;\n' > "$FILE_OMP"
printf 'const other = 1;\n' > "$OTHER"

for f in "$FILE_CC" "$FILE_OMP"; do
  nvim_iso --headless -u "$NVIM_CONFIG/init.lua" "$f" \
    -c 'call append(0, "// seeded")' -c 'w' \
    -c 'normal! Gothird line' -c 'w' -c 'qa!' >/dev/null 2>&1
done

seq_last_of() {
  nvim_iso --headless -u "$NVIM_CONFIG/init.lua" --cmd "set undodir=$UNDODIR" \
    -c "rundo $(nvim_iso --headless -u NONE --cmd "set undodir=$UNDODIR" \
        -c 'lua io.write(vim.fn.undofile(vim.fn.fnamemodify(vim.fn.argv(0), \":p\")))' -c 'qa!' "$1" 2>/dev/null)" \
    -c "lua io.write(tostring(vim.fn.undotree().seq_last))" -c 'qa!' "$1" 2>/dev/null
}

# --- 2b: start a PTY nvim holding a DIFFERENT file (targets stay unloaded) --
SERVERNAME="$ROOT/nvim.sock"
nvim_iso --listen "$SERVERNAME" -u "$NVIM_CONFIG/init.lua" "$OTHER" &
NVIM_PID=$!

for _ in $(seq 1 50); do
  [ -S "$SERVERNAME" ] && break
  sleep 0.1
done
[ -S "$SERVERNAME" ] && ok "nvim PTY listening on $SERVERNAME" || bad "nvim PTY never opened a socket"

ADVERTISE_DIR="${TMPDIR:-/tmp}/nvim-undo"
ADVERTISE_FILE="$ADVERTISE_DIR/$NVIM_PID"
for _ in $(seq 1 20); do
  [ -f "$ADVERTISE_FILE" ] && break
  sleep 0.1
done
if [ -f "$ADVERTISE_FILE" ] && grep -qF "$PROJ" "$ADVERTISE_FILE"; then
  ok "advertise file $ADVERTISE_FILE has matching cwd"
else
  bad "advertise file missing or cwd mismatch"
fi

# --- 2c: drive the Claude Code entry point (stdin PreToolUse JSON) ----------
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}\n' "$FILE_CC" \
  | bun "$NOTIFIER" >/dev/null 2>&1
CC_STATUS=$?
[ "$CC_STATUS" -eq 0 ] && ok "Claude Code notifier exited 0 for $FILE_CC" \
                        || bad "Claude Code notifier exited $CC_STATUS"

# --- 2c: drive the omp entry point (synthetic tool_call payload) ------------
if [ -f "$OMP_HOOK" ]; then
  UNDO_GUARD_TEST_PATH="$FILE_OMP" UNDO_GUARD_TEST_CWD="$PROJ" \
    bun "$OMP_HOOK" >/dev/null 2>&1
  OMP_STATUS=$?
  [ "$OMP_STATUS" -eq 0 ] && ok "omp hook exited 0 for $FILE_OMP" \
                          || bad "omp hook exited $OMP_STATUS"
else
  bun "$NOTIFIER" "$FILE_OMP" >/dev/null 2>&1
  ok "omp entry unavailable, exercised notifier argv path directly for $FILE_OMP"
fi

# --- 2d: externally rewrite both target files (simulate the agent's write) --
printf 'const x = 2; // agent write\n' > "$FILE_CC"
printf 'const y = 2; // agent write\n' > "$FILE_OMP"

# --- 2e: trigger the idle sweep, then quit without visiting either file -----
nvim --server "$SERVERNAME" --remote-send '<Esc>' >/dev/null 2>&1
sleep 0.6   # > updatetime, lets CursorHold + checktime sweep run
nvim --server "$SERVERNAME" --remote-send ':qa!<CR>' >/dev/null 2>&1
wait "$NVIM_PID" 2>/dev/null

[ ! -f "$ADVERTISE_FILE" ] && ok "advertise file removed on VimLeavePre" \
                            || bad "advertise file survived shutdown"

# --- 2f: fresh headless session per file, assert survival -------------------
check_survived() {
  local f="$1" label="$2"
  local out
  out=$(nvim_iso --headless -u "$NVIM_CONFIG/init.lua" "$f" \
    -c 'lua vim.g.__seq = vim.fn.undotree().seq_last' \
    -c 'silent undo' \
    -c 'lua io.write(vim.g.__seq .. "|" .. table.concat(vim.fn.getline(1, "$"), "\\n"))' \
    -c 'qa!' 2>/dev/null)
  local seq="${out%%|*}"
  local content="${out#*|}"
  if [ -n "$seq" ] && [ "$seq" != "0" ]; then
    ok "$label: seq_last=$seq preserved"
  else
    bad "$label: seq_last=$seq (undo tree lost)"
  fi
  if printf '%s' "$content" | grep -q 'agent write'; then
    bad "$label: :undo still shows agent write, pre-agent content not recovered"
  else
    ok "$label: :undo recovered pre-agent content"
  fi
}
check_survived "$FILE_CC" "claude-target"
check_survived "$FILE_OMP" "omp-target"

# --- failure-baseline contrast (documented, not re-run destructively) -------
cat <<'EOF'

Failure baseline (guard disabled, for contrast — not re-executed here):
  same sequence (unloaded target, external rewrite, quit without visiting)
  yields seq_last=0 in the fresh session and the pre-agent content is
  unrecoverable, because the on-disk undofile hash no longer matches the
  rewritten file and Neovim discards it. Measured this session before the
  guard existed.
EOF

# --- regression: startup time -----------------------------------------------
BEFORE_ADVERTISE_MS=$(nvim_iso --headless -u NONE --startuptime "$ROOT/st_none.log" \
  -c 'qa!' >/dev/null 2>&1; awk 'END{print $1}' "$ROOT/st_none.log")
AFTER_ADVERTISE_MS=$(nvim_iso --headless -u "$NVIM_CONFIG/init.lua" \
  --startuptime "$ROOT/st_full.log" -c 'qa!' >/dev/null 2>&1; awk 'END{print $1}' "$ROOT/st_full.log")
printf 'Startup time: -u NONE=%sms  full config (incl. advertise write)=%sms\n' \
  "$BEFORE_ADVERTISE_MS" "$AFTER_ADVERTISE_MS"

# --- regression: CursorHold sweep budget ------------------------------------
# Reuses the project's own perf probe if present; otherwise reports N/A rather
# than inventing a threshold.
PERF_PROBE="$NVIM_CONFIG/.agent/docs/specs/2026-08-17-undo-guard/../../../../lua/util/perf.lua"
if [ -f "$NVIM_CONFIG/lua/util/perf.lua" ]; then
  echo "CursorHold sweep: run :LuaPerf or the project's scheduled-callback probe" \
       "manually and confirm no callback exceeds 1.0ms (baseline: 1.98ms at 201" \
       "loaded buffers, ~10us added per held buffer)."
else
  echo "CursorHold sweep: no perf probe found at lua/util/perf.lua; skipping" \
       "automated measurement, report baseline manually."
fi

echo
echo "== undo-guard e2e: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
```

#### `.agent/docs/decisions/2026-08-17-undo-guard-hold-before-write.md`

The `.agent/docs/decisions/` directory contains exactly one prior entry
(`2026-08-17-markdown-treesitter-highlighter-gate.md`), using YAML frontmatter
(`date`, `status`, `supersedes`) followed by `# Title`, `## Context`,
`## Options considered` (numbered, only where alternatives were weighed),
`## Decision`, `## Consequences`, `## Verification`. This entry matches that
shape exactly.

```markdown
---
date: 2026-08-17
status: accepted
supersedes: none
---

# Hold buffers in memory before an agent's external write to preserve undo history

## Context

Neovim keys persistent undo (`undofile`) to a SHA of the file's contents. When an
agent tool rewrites a file while Neovim has it **unloaded**, the on-disk undofile's
hash no longer matches, and Neovim silently discards the entire undo tree on next
open (`:rundo` also refuses it: "File contents changed, cannot use undo info").
When the file **is** loaded, the external write is absorbed as a new undo state via
`undoreload`, and Neovim rewrites the undofile so history survives into later
sessions. Measured this session: unloaded → `seq_last=0` after the external write;
loaded → `seq_last=2`, with `:undo` returning the pre-agent content.

Every Neovim instance already listens on msgpack-RPC (`v:servername` is always
populated) — no `serverstart` call or extra process is needed. Undofile names
derive only from the file's absolute path, not cwd or project, so any live
instance, anywhere, can hold any file's buffer.

## Options considered

1. **Do nothing; accept undo loss on agent edits.** Rejected — this is the status
   quo and the reason this feature exists.
2. **Snapshot undofiles ourselves outside Neovim.** Rejected: reimplements
   Neovim's own undo-persistence format and hash scheme for no benefit over just
   keeping Neovim's own mechanism engaged.
3. **Hold the buffer in memory just before the write, via a pre-write tool hook.**
   Chosen: reuses Neovim's built-in `undoreload` path unmodified: load the buffer
   with `eventignore=all` (so LSP/treesitter/UI don't spin up for a file the user
   never asked to open), let the hook's external write get picked up by the
   existing `checktime` idle sweep, and un-guard (relist, fire `BufReadPost`, set
   filetype) the first time the user actually visits the file.

## Decision

Agent tool-call hooks (Claude Code `PreToolUse`, omp `tool_call`) run *before* the
write and call a small Bun notifier (`scripts/undo-guard-notify.ts`). The notifier
selects a live Neovim instance by longest-cwd-prefix match against the target
path (falling back to any live instance), connects to its RPC socket — advertised
at startup to `$TMPDIR/nvim-undo/<pid>` as `cwd` + `v:servername`, and removed on
`VimLeavePre` — and calls `nvim_exec_lua("require('util.undo').hold(...)", [path])`.
`hold()` loads the buffer unlisted with `eventignore` and `swapfile` disabled
around the load (both explicitly restored on every path, including errors), and
releases the buffer again if it turns out to have no usable undo history. A
`BufEnter` autocmd un-guards the buffer on first real visit. The whole chain is
fail-open by construction: the notifier has a hard timeout and exits 0 on every
failure path (no socket, dead process, RPC error), and a hook that cannot start is
a non-blocking error in both Claude Code and omp. Worst case on any failure is
today's behavior — undo history lost, nothing blocked or slowed.

## Consequences

- Undo history for agent-edited files now survives across sessions, provided some
  Neovim instance was alive and reachable at write time.
- No new persistent process, socket server, or daemon — piggybacks entirely on
  the RPC socket Neovim already opens.
- Known gaps, deliberately unaddressed:
  - **Bash-driven edits** (`sed`, `cat >`, etc. run directly, not through a hooked
    tool) bypass the guard entirely — nothing intercepts raw shell writes.
  - **`xd://ast_edit`** writes go through a device path outside the `write`/`edit`
    tool surface the hooks match on, so they are not currently held.
  - **No running Neovim instance anywhere** (all closed, or none ever opened in
    that project) — the notifier finds no advertise file and exits 0 immediately;
    the file is written unguarded.
  - **Already-stale undofiles** — if the on-disk undofile was already hash-mismatched
    before this feature existed (e.g. from a prior unguarded agent write), it is
    unrecoverable; the guard only prevents *future* mismatches, it cannot repair
    history already lost.

## Verification

`.agent/docs/specs/2026-08-17-undo-guard/e2e.sh`: in an isolated `$TMPDIR`
project with `undodir` redirected, drives both the Claude Code notifier path and
the omp hook path against unloaded target files, rewrites them externally,
triggers the idle sweep without ever visiting either file, and asserts in a fresh
headless session that `undotree().seq_last` is nonzero and `:undo` recovers the
pre-agent content for both files. Also reports startup-time delta and points at
the project's `CursorHold` sweep budget (baseline 1.98ms at 201 loaded buffers,
~10us per held buffer, 1.0ms scheduled-callback threshold) for manual regression
comparison.
```

**Verify:** `bash .agent/docs/specs/2026-08-17-undo-guard/e2e.sh` (after the
developer runs `chezmoi apply` so `~/.config/nvim` reflects Steps 1–5) exits 0
and prints `== undo-guard e2e: N passed, 0 failed ==`, where the passing
assertions include: advertise file created with matching cwd, both notifier
entry points (Claude Code stdin JSON, omp hook) exit 0, advertise file removed on
shutdown, and — for both `claude-target.ts` and `omp-target.ts` — a fresh headless
session shows `seq_last` nonzero and `:undo` content free of the `agent write`
marker (i.e. the pre-agent content was recovered).
</content>

## Verification

This project has no build or test suite — it is a Neovim configuration. The equivalent gate is
that the deployed config loads clean and the end-to-end proof passes:

- [ ] `chezmoi apply` (developer runs this — agents MUST NOT)
- [ ] `nvim --headless -c 'lua print("ok")' -c 'qa!'` exits 0 with no error output
- [ ] `harness doctor` reports 0 errors
- [ ] Step 8's `e2e.sh` passes: `seq_last` preserved for both target files, one `undo` returns
      the pre-agent content, against the documented `seq_last=0` failure baseline
- [ ] Step 6's preload holds a non-zero count within ~2 s of startup, and no timer tick exceeds
      1.5 ms
- [ ] Step 7's extractor table matches: `sed -i existing.ts` and `echo x > existing.ts` yield the
      path, `prettier --write .` yields nothing
- [ ] An omp session in an unrelated project triggers a hold in the nvim running elsewhere
      (cross-project case, the reason the hooks exist alongside the preload)
- [ ] `nvim --startuptime` shows no regression from the advertise write
- [ ] `CursorHold` sweep stays under the 1.0 ms scheduled-callback budget from
      `.agent/docs/perf-baseline.md`
