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

**Revised 2026-08-25:** the markdown highlighter gate this baseline used to
depend on was replaced -- see "Markdown highlighting: conceal-sweep fix" below
and the updated "Fixes this baseline depends on" table. `captured_at` below is
left at the original capture date; session-wide numbers (stalls, schedule/defer
totals, RSS, etc.) are unaffected, only the markdown-specific rows changed.

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
| `oil.toggle_float` | **11.8ms** avg, 20.0ms max (was 18.2/26.4 before the barbar render fix) | > 40ms avg |
| `telescope.find_files` | **26.2ms** avg | > 60ms avg |
| `barbar render.update` | **787 calls**, 5.33ms/call, 4.2s total per session | calls in the thousands, or total > 8s |
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

Note these two `markdown <- ...` lines were captured 2026-08-17, under the
highlighter gate and with `;; extends` restored to
`after/queries/markdown/injections.scm` (the file existed then; it does not
now, see below). Both premises are gone: the gate was replaced 2026-08-25 by
stripping `conceal_lines` from the highlights query (see "Markdown
highlighting: conceal-sweep fix" below), and `injections.scm` was deleted
because its patterns duplicated core's and double-injected every fence. Expect
these numbers to shift on a fresh capture; the cost driver is the
`conceal_lines` directive, not injected-region count -- the 2026-08-25
investigation measured a 288-region buffer at 0.5ms warm ranged parse per
redraw with the directive stripped, against 35.4ms/redraw for the
`on_conceal_line` sweep it replaces.

**Red flag:** a markdown buffer whose highlighter has `_conceal_line == true`
(inspect via `vim.treesitter.highlighter.active[buf]`), or a warm ranged parse
cost above roughly 1ms/redraw on the `undo-guard` spec. The treesitter
highlighter is expected to be attached to markdown of any size now; either
symptom means the `conceal_lines` strip in `lua/plugins/editor/treesitter.lua`
did not apply.

`decoration providers` — `gitsigns on_win` ~1923 calls / 47.3ms and the two
`vim/lsp/*` providers at ~1463 calls each are normal. Individual provider totals
should stay under ~100ms.

## Buffer inventory check

The snapshot lists buffers with `v<N>` (visible) and `[ts]` (treesitter
highlighter attached). **Since the 2026-08-25 conceal-sweep fix, a markdown
buffer of any size SHOULD show `[ts]`** -- the size gate that used to strip it
above 1500 lines is gone:

```
b7   v1  3761 lines  markdown    spec.md              [ts]  <- correct
b8   v1   319 lines  typescript  hasPermission.ts     [ts]
```

If a large `.md` does NOT show `[ts]`,
`lua/plugins/editor/treesitter.lua` failed to install the stripped highlights
query (or an already-open buffer kept a pre-patch highlighter with
`_conceal_line = true`) -- expect the 35.4ms/redraw conceal sweep to be back.

## Markdown highlighting: conceal-sweep fix (2026-08-25)

The 2026-08-17 highlighter gate (the "markdown highlighter gate" / "regex
syntax fallback" rows this table used to carry) treated a symptom: it capped
the treesitter highlighter by file size instead of removing the
`conceal_lines` directive that caused the actual cost, and its own regex
fallback regressed further -- Vim's `syntax/markdown.vim` sets
`syn sync minlines=50`, so fenced blocks longer than the 50-line sync window
lost highlighting entirely below it. The fix removes the size gate and the
regex fallback, and strips `(#set! conceal_lines "")` from markdown's
highlights query at runtime instead. Markdown is the only language in the
runtime whose highlights query sets `conceal_lines` (verified by grep), which
is why markdown alone was pathological.

Measured on `.agent/docs/specs/2026-08-17-undo-guard/spec.md` (2179 lines, 288
injected regions of which 255 are `markdown_inline`, 38-row window):

| metric | before | after |
|---|---|---|
| `on_conceal_line` sweep per redraw | 35.4ms | 0.01ms |
| warm ranged parse per redraw | 0.2ms | 0.5ms |
| one screen of highlight queries | 4.5ms | 4.5ms |
| cold full parse (one-time, on open) | ~40ms | ~40ms |
| ranged parse after a 1-line edit | 14-17ms | 14-17ms |
| open + redraw + jump to line 700 + redraw, wall clock, 5-run avg | 1626ms | 1465ms |

The old decision record described the highlighter as re-resolving injections
"roughly once per visible line" and attributed that to markdown's injection
count. It was a `conceal_lines` artefact: that metadata made Nvim run
`on_conceal_line` once per screen row, and each call did a full
`prepare_highlight_states` walk of every injected child tree. With the
directive stripped, the warm per-redraw parse above is 0.5ms on the same
288-region buffer -- injection count is not the cost driver. Cold parse and
post-edit parse costs were already being paid under the gate (render-markdown
kept a parser alive and reparses on change), so removing the gate added no
parse cost; it only added the ~4.5ms/screen highlight query and removed the
35.4ms conceal sweep.

## Known-unfixed costs (expected in a healthy profile)

Do not treat these as regressions; they are open items, not new problems.

| item | cost | status |
|---|---|---|
| `lsp textDocument/documentColor` | 17 calls, 1288ms total, 752.9ms max | **Unfixed, and an attempted fix was reverted.** An `LspAttach` guard calling `vim.lsp.document_color.enable(false, { bufnr })` did disable the feature (`is_enabled` returned false) but the requests kept firing -- so it cost the inline colour swatches and saved nothing. Reverted deliberately; do not re-add it without first proving the request path actually stops. |
| `lsp textDocument/semanticTokens/*` | 1226ms max in a mid-size repo; **4300ms max** in a large Convex monorepo | **Intentional, but re-measure per project.** Async, so it does not freeze the editor -- the symptom is highlighting settling seconds after the buffer appears. Gating on buffer size does NOT help: a 42-line file measured 4300ms, so the cost is the server doing project-wide work, not the file. To remove it, disable semantic tokens for the client rather than by size. |
| `plenary Job:sync [SYNC]` | ~110-117ms per call, blocking | **Fully identified.** Two sources, both blocking the main loop: (1) **chezmoi.nvim** `commands/__base.lua:48` runs `chezmoi status` from `__edit.watch` on BufRead for non-denied paths under `~/.local/share/chezmoi/` only -- it does NOT affect other projects, and it buys auto-apply on write. (2) **telescope-tmuxinator.nvim** `tmuxinator.lua:15` shells out to `tmuxinator` (116.9ms) via `telescope/utils.lua:499`. |
| `LuaSnip` fs_event watchers | 10 and slowly climbing | Minor leak from `from_vscode.lua:394` (`lazy_load`). |
| `render-markdown` decorator timers | 9, scales with markdown buffers touched | Minor; bounded in practice. |

## Fixes this baseline depends on

If numbers regress, verify these are still present before looking further --
one of them was silently reverted by a broad `chezmoi re-add` mid-investigation.

| fix | file | marker |
|---|---|---|
| markdown `conceal_lines` strip | `lua/plugins/editor/treesitter.lua` | `vim.treesitter.query.set("markdown", "highlights", ...)` installs the highlights query with `(#set! conceal_lines "")` stripped -- if reverted, markdown redraws go back to a per-screen-row `on_conceal_line` sweep (35.4ms per redraw, measured on the 2179-line `undo-guard` spec) repaid after every keystroke. |
| fence-language aliases | `lua/plugins/editor/treesitter.lua` | `vim.treesitter.language.register` maps `shell`/`zsh` -> bash, `yml` -> yaml, `dataviewjs` -> javascript, `datacoretsx` -> tsx -- do not re-add hand-written `fenced_code_block` injection patterns for these; core already resolves them, and duplicate patterns double-inject every fence (measured 288 -> 302 regions, +20% post-edit parse, zero added coverage). |
| no markdown injections override | `after/queries/markdown/injections.scm` | file must stay **deleted**; `after/ftplugin/markdown.lua` must not set `vim.bo.syntax` or call `vim.treesitter.stop`. |
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
