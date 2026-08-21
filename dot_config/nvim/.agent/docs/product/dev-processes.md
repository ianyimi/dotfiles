---
verified_at: 59382a5199bd055626537d995cb92dc1e4eda588
---

# Dev Processes

## Edit → apply → verify loop
This directory is the **chezmoi source** for `~/.config/nvim`. Edits here do NOT reach the
live config until `chezmoi apply` is run manually (the old "auto hot reload" claim is stale).

`~/.config/nvim` is a real directory copy, not a symlink. Neovim resolves `require` through
`runtimepath`, which points at the deployed copy — so `nvim -u <source>/init.lua` still loads
`lua/` from `~/.config/nvim`. **Any profiling or benchmark run before an apply measures the
old code.** Agents must stop and hand the apply to the developer.

Apply selectively. A bare `chezmoi apply` also rewrites `lazy-lock.json`, which is routinely
modified on both sides (`chezmoi status` shows `MM`) and would roll plugin versions back:

```sh
chezmoi apply ~/.config/nvim/lua ~/.config/nvim/after   # code + queries, lock untouched
chezmoi status ~/.config/nvim                           # confirm nothing unexpected remains
```

`chezmoi diff` and `chezmoi apply --dry-run` page their output; add `--no-pager` when running
non-interactively or the command hangs.

Not deployed at all (chezmoi-ignored, edit freely): `.agent/`, `.claude/`, `.omp/`, and every
`*.md` in the tree.

| Command | Purpose |
|---|---|
| `chezmoi apply <target paths>` | Push source changes to the live `~/.config/nvim` |
| `nvim --headless "+lua vim.print('config-ok')" +qa` | Smoke test — config loads cleanly (exit 0, errors on stderr) |
| `:checkhealth` | Full health audit after plugin/LSP changes (manual, in-editor) |
| `:checkhealth vim.lsp` | Replaces `:LspInfo`, removed because Nvim 0.12 ships a native `:lsp` |
| `:Lazy` | Plugin management (install/update/profile) |
| `:Mason` | LSP server management |
| `:Shipwright` / `:lua require('export-ghana-cozy')` | Export Ghana Cozy lush theme to `colors/` |
| `:StartupBenchLog` | Open startup benchmark log (custom `_bench` instrumentation in config/lazy.lua) |

## Interactive performance profiling
Headless runs cannot observe redraw, tabline/statusline, picker or virtual-text cost. Profile
inside a real session with the probe at `lua/util/perf-probe.lua`.

`plugin/perf-probe.lua` registers the commands during startup, so they are always available
and no `setup()` call is needed. Only the eight `nvim_create_user_command` calls run at
startup; the module itself is not read until a `Perf*` command is first invoked, which then
replaces the forwarders with the real handlers.

```vim
:PerfStart [stall_ms]   " begin recording (default threshold 80ms)
:PerfMark <label>       " label the action you are about to perform
:PerfSnap [label]       " buffers, RSS, lua heap, libuv handles, LSP clients, autocmd counts
:PerfLeak               " open libuv handles grouped by creation site
:PerfDup                " duplicate autocmds, vim.notify wrapper depth, extmark census
:PerfReport | :PerfStop | :PerfLog
```

Output goes to `stdpath('cache')/perf-probe.log`: main-loop stalls with Lua stack attribution
and event breadcrumbs, subprocess spawns, deferred-callback duration, and the snapshot fields
above.

To find an accumulation bug, bracket real work with two `:PerfLeak` calls — creation sites
whose counts climb between them are the leak. Compare two `:PerfSnap` outputs for RSS and
handle growth.

Caveats:
- LuaJIT does not fire `debug` count-hooks inside compiled traces, so a hot numeric loop can
  show as a stall with no Lua samples. The explicit wrappers and event breadcrumbs are the
  reliable signal; "no Lua samples" means the time went to C (redraw, treesitter, syntax).
- Never call methods on a stored libuv handle to test liveness — once closed and collected
  that is a use-after-free which aborts Nvim and `pcall` cannot catch it. Resolve liveness
  through `uv.walk`, which only yields handles the loop still owns.

Healthy reference numbers, capture conditions, red-flag thresholds and the list of
fixes the baseline depends on live in `.agent/docs/perf-baseline.md`. Compare a
fresh profile against it **before** forming a hypothesis about a new slowdown.

## Verification policy
Agents verify changes with the headless smoke test after `chezmoi apply`. Deeper interactive
behavior (keymaps, UI) is verified by the developer in a live session.
