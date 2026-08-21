---
date: 2026-08-18
status: accepted
supersedes: none
---

# Coalesce barbar's tabline renders instead of letting every event trigger one

## Context

Moving around the project in oil — especially going back to a parent directory — paused for
~100ms, and with enough buffers open the editor became unusable (killing the tmux pane was the
only way out). The symptom was long-standing, predating the undo-guard work, but that work made
it surface sooner by keeping more buffers loaded.

Profiling (`plugin/perf-probe.lua`, `~/.cache/nvim/perf-probe.log`) put the cost in the tabline,
not in oil. One 87ms oil stall sampled 96 times in `lua/plugins/ui/barbar.lua:303` and 65 times
in `:219`; a later run recorded **5617 `barbar render.update` calls at 4.31ms each — 24 seconds
of CPU in a single session** — while a 129.7ms stall window contained 21 `DiagnosticChanged`
events. barbar renders were invisible as a tabline problem (the tabline always ended up correct)
but they blocked oil from painting.

Three separate multipliers were at work:

1. `get_unique_name` (config override at `barbar.lua:271` → `:303`) scanned **every loaded
   buffer** and called `vim.fn.fnamemodify` per iteration, once per rendered tab. Cost scaled as
   tabs × loaded buffers, so it grew as a session accumulated buffers — and undo-guard's preload
   inflated the loaded count (measured 0.24ms/render at 20 loaded vs 0.84ms at 116).
2. Barbar renders on **every** `{BufEnter, BufNew}` (`events.lua:215`, with `update_names=true`,
   the variant that recomputes every label) and on eight more window/buffer events
   (`events.lua:220`). Oil creates a new `oil://` buffer per directory, so one directory change
   fired four full renders.
3. Barbar renders on **every** `DiagnosticChanged` (`events.lua:242-246`, unconditional). Three
   LSP servers across a monorepo deliver those in bursts of 20+.

## Options considered

1. **Disable barbar's diagnostic icons.** Rejected: loses a feature that is actually used, and
   the autocmd is registered unconditionally, so it may not even have helped.
2. **Disable animations and wrap `render.update` globally with a debounce.** Rejected: animations
   drive `render.update` through their own timers, so a blanket debounce makes tabs jump instead
   of slide — a visible regression.
3. **Patch barbar itself.** Rejected: lost on every plugin update.
4. **Replace barbar's pure-render autocmds with coalesced equivalents, in config** (chosen). Its
   `{BufEnter, BufNew}` and eight-event handlers are *nothing but* a `render.update` call, so
   there is no plugin state to replicate. Its `{BufDelete, BufWipeout}` handler also updates
   jump-mode letters and the recently-closed list, so that one is left alone.

## Decision

- `get_unique_name` builds a basename map from **one** `getbufinfo({buflisted = 1})` call,
  memoized and invalidated on `BufAdd`/`BufDelete`/`BufWipeout`/`BufFilePost`/`BufEnter`, with
  basenames via `string.match` and path splits memoized. Only **listed** buffers are considered,
  which is also more correct: barbar renders listed buffers, so an unlisted one can never collide
  for a tab label. Measured 0.809ms → 0.074ms per render (11x). Label output was diffed old vs
  new across 7 buffer sets (unique, 2-way, 4-way collisions, collisions 2 and 3 levels up, mixed
  depths, dotfiles) — byte-identical, no feature lost.
- All reactive renders go through one `schedule_render(update_names, delay_ms)` with a single
  reused `vim.uv.new_timer()` handle. `update_names` sticks across a coalesced burst, so no label
  refresh is dropped. 16ms for interactive events (a render also repaints which tab is active, so
  a longer delay would visibly lag buffer switching); 60ms for diagnostics, which nothing
  interactive waits on.
- barbar's `{BufEnter, BufNew}`, `{BufWinEnter, BufWinLeave, BufWritePost, TabEnter, WinEnter,
  WinLeave}` and `DiagnosticChanged` autocmds are cleared from its `barbar_render` group and
  re-registered coalesced. `VimResized` is deliberately left to barbar (nvim registers one
  autocmd entry per event, so its handler survives for that event alone) so resizes still repaint
  immediately.
- The diagnostic replacement additionally skips **unlisted** buffers; upstream checks only
  `nvim_buf_is_loaded`, which is why undo-guard's held buffers could reach it.

## Consequences

Measured across successive profiles of comparable sessions:

| | before | after |
|---|---|---|
| `oil.toggle_float` | 116ms avg, 139ms max | **11.8ms avg, 20.0ms max** |
| `barbar render.update` | 5617 calls, 4.31ms, 24.2s | **787 calls, 5.33ms, 4.2s** |
| stalls in run | several | **0** |
| lua heap | 150.2MB | **32.9MB** |
| `timer (idle)` / `fs_event (idle)` | 196 / 94 | **35 / 37** |

Navigating oil is now instant on every directory change, which was the original complaint.

Verified live that the swap took effect: `barbar_render` reports 0 handlers for
`BufEnter`/`BufNew` and `DiagnosticChanged`, 1 for `VimResized`, 2 for `BufDelete`/`BufWipeout`,
alongside 4 in `barbar_render_coalesced` and 1 in `barbar_diagnostics_coalesced`.

### Risks

- If anything calls `barbar.setup()` or `events.enable()` again after startup, barbar re-registers
  its own handlers next to the coalesced ones. That degrades to the old behavior, not worse.
- Barbar's remaining ~5.3ms per render is its own `state.update_names` → `buffer.get_name` →
  `fs.split` over listed buffers. It scales with how many buffers stay listed, so the lever there
  is fewer open tabs rather than more config.
- These overrides read barbar's internals (`events.lua` group name `barbar_render`, and which of
  its handlers are pure renders). A barbar update could invalidate that; the `pcall` around
  `nvim_clear_autocmds` fails open, so the worst case is losing the coalescing, not breaking the
  tabline.

## Verification

`plugin/perf-probe.lua` before/after in comparable sessions; numbers above and in
`.agent/docs/perf-baseline.md`. Label parity and the coalescing semantics (burst → one render,
`update_names` preserved, later bursts still render) were checked with standalone scripts under
`nvim --headless`. Note that barbar cannot be exercised headlessly at all — with no UI,
`UIEnter`/`VeryLazy` never fires and the plugin never loads, so any live check needs a PTY.
