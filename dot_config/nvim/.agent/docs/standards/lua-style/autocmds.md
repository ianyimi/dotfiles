---
applies_to: ["lua/config/autocmds.lua", "lua/util/**/*.lua"]
---
# Autocmd and augroup conventions

## `augroup(name)` clears — create the id ONCE per group

`augroup()` (config/autocmds.lua:3) wraps `nvim_create_augroup(name, { clear = true })`, so
calling it a second time for the same name **deletes every autocmd already registered in that
group**. Registering two events through two `augroup("x")` calls silently leaves only the last
one alive:

```lua
-- WRONG: the VimLeavePre registration wipes the VimEnter one. The group ends up with a single
-- autocmd, and nothing warns you — `nvim_get_autocmds({group = ...})` returns 1, not 0.
vim.api.nvim_create_autocmd("VimEnter",    { group = augroup("undo_guard_advertise"), ... })
vim.api.nvim_create_autocmd("VimLeavePre", { group = augroup("undo_guard_advertise"), ... })

-- RIGHT: one id, reused.
local undo_guard_group = augroup("undo_guard_advertise")
vim.api.nvim_create_autocmd("VimEnter",    { group = undo_guard_group, ... })
vim.api.nvim_create_autocmd("VimLeavePre", { group = undo_guard_group, ... })
```

Cost of the wrong version when it happened: the undo-guard advertise file was never written at
startup, so every agent hook silently found no nvim to talk to. Text-level checks (`grep` for the
call) and unit tests of the called function both passed. Assert the runtime instead — that the
group actually contains each event you expect.

## `:checktime` without an argument only reaches windowed buffers

Bare `:checktime` skips loaded-but-hidden buffers. Use the per-buffer `:checktime {buf}` form when
sweeping for external changes, or hidden buffers stay stale (see the `lazyvim_checktime` autocmd).

## `eventignore` must be restored on every path

Anything that sets `vim.o.eventignore = "all"` around a risky call must restore it *outside* the
`pcall`, never inside the protected function. A throw that leaks `eventignore = "all"` disables
every autocmd for the rest of the session — no LSP attach, no `checktime`, no format-on-save —
which is far worse than whatever the guarded operation was protecting. Same reasoning for
`vim.o.swapfile`. Pattern: `lua/util/undo.lua#M.hold`.

## Never mutate a buffer you did not create

Code that opens a file behind the user's back (`bufadd` + `bufload`) must check whether the
buffer already existed *before* creating it, and leave pre-existing buffers alone:

```lua
local pre_existing = vim.fn.bufexists(path) == 1   -- BEFORE bufadd, which creates it
-- ... bufadd + bufload ...
if pre_existing then return "adopted" end          -- do not touch buflisted, do not delete
```

Harpoon pins and session restores put their files in the buffer list *before* loading them, so a
listed-but-unloaded buffer is normal and belongs to them. Setting `buflisted = false` on one drops
it from the barbar tabline; `nvim_buf_delete` closes it outright. Cost when this shipped wrong:
harpoon-pinned files appeared at startup and then silently vanished ~2s later when the deferred
preload adopted them. Pattern: `lua/util/undo.lua#M.hold`.

## A `vim.schedule_wrap` timer callback must finish idempotently

Every libuv tick of a `timer:start(ms, ms, vim.schedule_wrap(fn))` *queues* `fn` on the main loop.
Under load — opening a file while LSP and treesitter work — several can queue before any of them
runs, so `fn` must tolerate running again after it has already finished:

```lua
local finished = false
-- inside the callback:
if finished then return end
-- ... work ...
if done then
  finished = true
  timer:stop()
  if not timer:is_closing() then timer:close() end
end
```

Without the guard the second queued callback closes an already-closing handle and Neovim surfaces
`vim.schedule callback: ... handle 0x… is already closing`, plus a duplicate notification. Not
reproducible headlessly (blocking the loop with `vim.uv.sleep` stops timers from firing at all), so
assert the guard structurally. Pattern: `lua/util/undo.lua#M.arm`.

## Suppress events symmetrically, and cache negative results

`eventignore = "all"` around a `bufadd`/`bufload` but not around the matching
`nvim_buf_delete` is worse than not suppressing at all: the create is silent while the destroy
fires `BufWipeout` + `BufUnload` into every plugin watching the buffer list. barbar turns each of
those into a `render.update` plus an animation, so a routine that created-and-discarded a buffer per
call produced 5617 renders and 24s of CPU in one session, with tabs visibly rearranging and oil
floats slowing to ~48ms (baseline 18ms). Keep the whole create/inspect/maybe-delete sequence inside
one suppressed window, and cache the "not interesting" verdict per path so a repeat call does no
buffer work at all.

## Testing a config module: prepend runtimepath, not `package.path`

`nvim -u NONE` still has `~/.config/nvim` on `runtimepath`, and nvim's rtp loader runs before the
standard Lua searchers. A test that only prepends `package.path` therefore loads the **deployed**
copy of a module, not the working tree — which silently reports the old behavior after an edit. Copy
the file into a scratch dir and `vim.opt.rtp:prepend(dir)` (see
`.agent/docs/specs/2026-08-17-undo-guard/verify/step-1.sh`), or pass `--cmd 'set rtp^=<repo>'`.

## Coalesce a plugin's renders by replacing its pure-render autocmds

When a plugin re-renders on every event and that cost shows up in profiles, prefer replacing its
*pure-render* autocmds over wrapping its render function. Wrapping catches animation frames too
(barbar drives those through its own timers) and makes them stutter; replacing an autocmd whose
callback is nothing but `render.update()` has no state to reproduce:

```lua
pcall(vim.api.nvim_clear_autocmds, { group = "barbar_render", event = { "BufEnter", "BufNew" } })
vim.api.nvim_create_autocmd({ "BufEnter", "BufNew" }, {
  group = vim.api.nvim_create_augroup("barbar_render_coalesced", { clear = true }),
  callback = function() schedule_render(true) end,
})
```

Check first whether the handler does anything besides render — barbar's `BufDelete`/`BufWipeout`
handler also updates jump-mode letters and the recently-closed list, so it must be left alone.
nvim registers one autocmd entry **per event**, so clearing a subset of a multi-event handler's
events leaves the rest intact (used deliberately to keep `VimResized` repainting immediately).
Keep interactive events on a short window (~16ms — a tabline render also repaints which tab is
active) and push non-interactive ones (diagnostics) to ~60ms. Pattern:
`lua/plugins/ui/barbar.lua`, measured in `.agent/docs/decisions/2026-08-18-coalesce-barbar-renders.md`.

## barbar (and anything gated on VeryLazy) cannot be tested headlessly

`nvim --headless` never fires `UIEnter`, so lazy.nvim's `VeryLazy` never fires and any plugin
loaded on it never loads — `package.loaded["barbar"]` stays nil and its augroups do not exist. Live
checks for those plugins need a real PTY.

