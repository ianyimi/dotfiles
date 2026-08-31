---
date: 2026-08-25
status: accepted
supersedes: 2026-08-17-markdown-treesitter-highlighter-gate
---

# Strip `conceal_lines` from markdown's highlights query instead of gating the highlighter by size

## Context

The developer reported fenced-code syntax highlighting dropping out partway down long markdown
specs, for large sections at a time. Reproduced on `.agent/docs/specs/2026-08-17-undo-guard/spec.md`
(2179 lines, a ```typescript fence spanning lines 487-873, i.e. 386 lines), in the live
pre-change config: `synstack()` returned `markdownHighlight_typescript` at line 500 and
**nothing at all** at lines 700, 800 and 870. With `syntax sync fromstart` every probe resolved
correctly, confirming the sync window as the cause.

The cause is the 2026-08-17 gate's own fallback (`2026-08-17-markdown-treesitter-highlighter-gate.md`,
now superseded by this record): above `vim.g.markdown_ts_highlight_max_lines` it stopped the
treesitter highlighter and dropped to Vim's regex `syntax/markdown.vim`, which sets
`syn sync minlines=50` (`g:markdown_minlines`, default 50). The regex engine resolves at most 50
lines above the window top when no syntax state is cached, so it cannot tell it is inside a
fenced block that opened 386+ lines back.

That gate correctly identified a real ~1.1 s stall and correctly located it in Nvim core, but it
treated a symptom. The actual root cause: `$VIMRUNTIME/queries/markdown/highlights.scm` lines 53
and 59 carry `(#set! conceal_lines "")` on the fenced-code delimiter and the info-string language
label. That metadata sets `has_conceal_line` on the query, which sets
`TSHighlighter._conceal_line` (`highlighter.lua:108-112`), which makes Nvim invoke the
`on_conceal_line` decoration callback **once per screen row**. Each call runs
`tree:parse({row, row})` plus a full `prepare_highlight_states` — a walk of every injected child
tree (`highlighter.lua:521-533`). The per-row memo `_conceal_checked` is cleared on every
`on_bytes`, so the whole sweep is repaid after each keystroke. Markdown is the **only** language
in the runtime + installed-plugin query set that uses `conceal_lines` (verified by grep), which
is exactly why markdown alone was pathological.

## Options considered

1. **Raise `g:markdown_minlines` / force `syntax sync fromstart`.** Rejected: this keeps the
   strictly worse regex highlighter in the loop instead of removing it — the old live config
   (gate + regex fallback) already measured 1626 ms wall-clock for open + redraw + jump-to-line-700
   + redraw against 1465 ms for the new approach — and `fromstart` trades a bounded-but-wrong sync
   window for re-parsing syntax state from line 1 on every cache miss.
2. **Strip `injection.combined` to stop the forced full-document injection scan
   (`languagetree.lua:1102`).** Rejected after measurement: the post-edit parse was unchanged at
   ~19 ms with this stripped. Not worth an invasive query override for no measured gain.
3. **Disable the `markdown_inline` injection.** Rejected: would break render-markdown's inline
   rendering, which consumes that tree.
4. **Patch `conceal_lines` out of markdown's highlights query and remove the size gate entirely.**
   Chosen — see Decision.

## Decision

Four changes in `lua/plugins/editor/treesitter.lua` and `after/ftplugin/markdown.lua`:

- **Query patch.** Read the markdown `highlights` query text via
  `vim.treesitter.query.get_files`, strip `(#set! conceal_lines "")`, install the result with
  `vim.treesitter.query.set("markdown", "highlights", ...)`. The query TEXT is patched rather
  than shadowing the `.scm` file so upstream query fixes keep flowing through on Nvim upgrades —
  a shadowed file freezes at whatever `highlights.scm` looked like on the day it was copied.
- **Gate removal.** Deleted `HEAVY_INJECTION_FT` / `HEAVY_INJECTION_LINES` / `skip_highlighter`
  from `treesitter.lua`; the treesitter highlighter now starts for markdown at any size. The
  already-open-buffers loop now calls `vim.treesitter.stop()` on an attached buffer before
  restarting the highlighter, because `start()` no-ops on an already-attached buffer and would
  otherwise leave a pre-patch `_conceal_line = true` in place.
- **Language aliases.** Added `vim.treesitter.language.register` aliases for fence info-strings
  Nvim cannot resolve alone: `shell`/`zsh` -> bash, `yml` -> yaml, `dataviewjs` -> javascript,
  `datacoretsx` -> tsx.
- **`after/queries/markdown/injections.scm` deleted.** Its `ts`/`tsx`/`js`/`json`/`yaml`/`bash`
  patterns duplicated core's generic `(info_string (language) @injection.language)` pattern and
  injected a second region over every fence core already covered — measured 288 -> 302 regions
  and +20% on the post-edit parse, for zero added coverage. `dataviewjs` and `datacoretsx`, the
  only genuinely custom entries, are now covered by the `language.register` aliases above instead.

## Consequences

Measured on the 2179-line spec (288 injected regions, 255 `markdown_inline`, 38-row window):

| metric | before | after |
|---|---|---|
| `on_conceal_line` sweep per redraw | 35.4 ms | 0.01 ms |
| warm ranged parse per redraw | 0.2 ms | 0.5 ms |
| one screen of highlight queries | 4.5 ms | 4.5 ms |
| cold full parse (one-time, on open) | ~40 ms | ~40 ms |
| ranged parse after a 1-line edit | 14-17 ms | 14-17 ms |
| open + redraw + jump to line 700 + redraw, wall clock, 5-run avg | 1626 ms (old live config) | 1465 ms (new) |

The cold parse and post-edit parse were **already** being paid under the gate: the old ftplugin
deliberately kept a parser alive via `get_parser` so render-markdown would keep rendering, and
render-markdown parses on change. Removing the gate therefore adds no parse cost — it only adds
the highlight query (~4.5 ms/screen) and removes the 35.4 ms conceal sweep.

One real behavioural trade: markdown buffers **without** render-markdown attached (e.g. a plain
`filetype=markdown` scratch buffer) no longer have their ``` fence delimiter lines hidden by
treesitter, because render-markdown is what conceals them now, not the (patched) highlighter.

LSP hover floats — the obvious surface to worry about, since render-markdown does not attach to
them — are **unaffected**. Running the same `vim.lsp.util.open_floating_preview` against the
pre-change config and the patched one produced byte-identical screen output (fence markers visible
in both); the only difference was the internal `_conceal_line` flag. Nvim's float path never
applied `conceal_lines` to those buffers in the first place.

## Verification

Booted nvim from the chezmoi source tree via an `XDG_CONFIG_HOME` symlink shim (no `chezmoi
apply`). On the 2179-line spec: `b:ts_highlight == true`, `&syntax == ""`, `_conceal_line == nil`;
`get_captures_at_pos` returns `typescript` captures at lines 490, 540, 700, 800, 870, 1021, 1080,
1460, 1560 — the exact positions the regex fallback left uncoloured. render-markdown still
renders (776 extmarks, fence delimiter lines still concealed by its own `conceal_lines`
extmarks); a screen-grid readback shows 7 distinct highlight attributes on a code row deep in the
file; injection region counts are back to core-only levels (typescript=3, bash=7, json=3, yaml=3).
