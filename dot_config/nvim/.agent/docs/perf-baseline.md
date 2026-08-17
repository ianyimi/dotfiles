---
captured_at: 2026-08-17
nvim: 0.12.4
probe: lua/util/perf-probe.lua
log: stdpath('cache')/perf-probe.log
---

# Performance Baseline

Reference numbers for this config in a **healthy** state, captured after the
August 2026 perf investigation. Compare a fresh profile against these before
theorising about a new slowdown.

## How to capture a comparable profile

```vim
:PerfStart
" work normally for ~2 minutes: open Oil with <leader>e, run find_files,
" edit a TypeScript file, keep a large spec open in a split
:PerfStop
:PerfLog
```

Auto-capture writes a snapshot + leak census + attribution tables every 30s, so
no other commands are needed. Read the final `===== REPORT =====` block.

## Capture conditions

The numbers below come from a **108-second** session and are only comparable to a
similar one. Reproduce roughly:

- project: a TypeScript monorepo (`vex.git/dev`), 3 LSP clients attached
  (`vtsls`, `eslint`, `tailwindcss`)
- layout: 6-7 windows, ~10 loaded buffers
- visible: a 3761-line markdown spec in one split, a ~320-line `.ts` in another
- actions: several Oil float toggles, several `find_files`, normal editing

Scale totals by session length; per-call figures are directly comparable.

## Baseline: healthy numbers

| metric | baseline | investigate if |
|---|---|---|
| stalls >= 80ms | **1** (107.3ms) | more than 3, or any single stall > 300ms |
| `vim.schedule cb` total | **4,003ms / 108s** (~3.7% duty) | duty cycle > 10% |
| `vim.schedule cb` per call | **0.30ms** | > 1.0ms |
| `vim.defer_fn cb` total | **374ms**, 0.11ms/call | > 1.5ms/call |
| `oil.toggle_float` | **18.2ms** avg, 26.4ms max | > 50ms avg |
| `telescope.find_files` | **26.2ms** avg | > 60ms avg |
| `barbar render.update` | **1.21ms**/call | > 3ms/call |
| `lualine.statusline` | **0.83ms**/call | > 2ms/call |
| `treesitter.start` | **0.61ms** avg, 34.4ms max | > 3ms avg |
| `util.root.get` | **0.003ms**/call | > 0.5ms/call (cache broken) |
| `spawn: defaults` | **1** call / session | more than ~2/minute (auto-dark-mode poll regressed) |
| `timer (idle)` handles | **53**, flat across captures | > 150, or climbing between captures |
| `fs_event (idle)` handles | **23** | > 60, or climbing |
| nvim RSS @ ~2min | **138.8MB** | > 300MB |
| lua heap | **44.3MB** | > 100MB |

## Attribution tables: what healthy looks like

`vim.schedule by creation site` — top entries should be core (`vim/_core/editor`)
plus small plugin contributions. **Red flags:**

- `satellite/async.lua` appearing at all. It was 3,455 calls / 29,075ms before
  `current_only = true`; healthy is `satellite/view.lua:304` only, ~43ms total.
- any single site above ~500ms total in a 2-minute session.

`LanguageTree:parse by caller` — healthy totals:

- `typescript <- highlighter.lua:580` ~823 calls / 97.6ms (0.12ms each)
- `markdown <- highlighter.lua:529` ~328 calls / 14.2ms
- `markdown <- render-markdown/request/view.lua:62` ~10 calls / ~168ms (~75ms max)

Note the markdown figures were captured before `;; extends` was restored to
`after/queries/markdown/injections.scm`. That raises injected regions in a
3761-line spec from 461 to 493 (typescript 32 -> 64) and adds ~28% to every
markdown re-resolution -- roughly +48ms across a 2-minute session. Expect
markdown parse totals about a quarter higher than the numbers above; that is
intentional, not a regression.

**Red flag:** hundreds of `markdown` parses from `highlighter.lua`, or per-call
cost in the tens of ms. That means the large-markdown highlighter gate broke --
check the buffer inventory for a big `.md` marked `[ts]`.

`decoration providers` — `gitsigns on_win` ~1923 calls / 47.3ms and the two
`vim/lsp/*` providers at ~1463 calls each are normal. Individual provider totals
should stay under ~100ms.

## Buffer inventory check

The snapshot lists buffers with `v<N>` (visible) and `[ts]` (treesitter
highlighter attached). **A markdown buffer over 1500 lines must NOT show `[ts]`:**

```
b7   v1  3761 lines  markdown    spec.md              <- correct: no [ts]
b8   v1   319 lines  typescript  hasPermission.ts     [ts]
```

If a large `.md` shows `[ts]`, `after/ftplugin/markdown.lua` is not winning
against Nvim's bundled `ftplugin/markdown.lua`, and 1s+ stalls will return.

## Known-unfixed costs (expected in a healthy profile)

Do not treat these as regressions; they are open items, not new problems.

| item | cost | status |
|---|---|---|
| `lsp textDocument/documentColor` | 17 calls, 1288ms total, 752.9ms max | **Unfixed, and an attempted fix was reverted.** An `LspAttach` guard calling `vim.lsp.document_color.enable(false, { bufnr })` did disable the feature (`is_enabled` returned false) but the requests kept firing -- so it cost the inline colour swatches and saved nothing. Reverted deliberately; do not re-add it without first proving the request path actually stops. |
| `lsp textDocument/semanticTokens/full` | 6 calls, 1225.9ms max | **Intentional.** Cost is per document version, not per action, and it materially improves TS highlighting. Gate on buffer size if file-open latency becomes the complaint. |
| `plenary Job:sync [SYNC]` | 5 calls, 117.9ms max, blocking | **Unidentified.** Present through the whole investigation; fires around `find_files`. Blocking, so each occurrence is felt. |
| `LuaSnip` fs_event watchers | 10 and slowly climbing | Minor leak from `from_vscode.lua:394` (`lazy_load`). |
| `render-markdown` decorator timers | 9, scales with markdown buffers touched | Minor; bounded in practice. |

## Fixes this baseline depends on

If numbers regress, verify these are still present before looking further --
one of them was silently reverted by a broad `chezmoi re-add` mid-investigation.

| fix | file | marker |
|---|---|---|
| markdown highlighter gate | `after/ftplugin/markdown.lua` | stops treesitter above `vim.g.markdown_ts_highlight_max_lines` (1500) |
| regex syntax fallback | `after/ftplugin/markdown.lua` | `vim.bo.syntax = "markdown"` |
| md injections use `;; extends` | `after/queries/markdown/injections.scm` | first line IS `;; extends` -- affordable only because of the gate above; costs +28% per markdown re-resolution. If the gate is removed or its threshold raised, re-measure before keeping it. |
| satellite single-window | `lua/plugins/ui/satellite.lua` | `current_only = true` |
| satellite gitsigns handler off | `lua/plugins/ui/satellite.lua` | `gitsigns = { enable = false }` |
| auto-dark-mode poll | `lua/plugins/ui/auto-dark-mode.lua` | `update_interval = 60000` |
| lazy update checker off | `lua/config/lazy.lua` | `checker = { enabled = false }` |
| indent-blankline timer release | `lua/plugins/ui/indent-blankline.lua` | `ibl_timer_release` augroup |
| chezmoi watch guard | `lua/plugins/util/chezmoi.lua` | `should_watch` deny-list |

## Method notes for whoever reads this next

- **Headless profiling cannot see this class of bug.** Redraw, tabline, picker
  and virtual-text cost is invisible without a UI, and redraw cost was the entire
  answer. Profile in a real session.
- **Wall-clock stalls matter more than CPU totals.** The lateness-timer stall
  detector measures what the developer actually feels; span totals over-count
  because nested wrappers double-count.
- **Attribution beats sampling.** LuaJIT does not fire `debug` count-hooks inside
  compiled traces, so stack samples can come back empty. The creation-site
  attribution tables (schedule/defer/parse/decoration) and the handle-leak census
  are what actually named every culprit found here.
- **A named subsystem is not a named cause.** Stack samples pointed at
  `languagetree.lua` for days; the fix only arrived after finding *who* started
  the highlighter (Nvim's bundled `ftplugin/markdown.lua`).
