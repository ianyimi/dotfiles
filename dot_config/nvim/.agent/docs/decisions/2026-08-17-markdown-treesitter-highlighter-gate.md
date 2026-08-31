---
date: 2026-08-17
status: superseded
supersedes: none
superseded_by: 2026-08-25-markdown-conceal-lines-not-a-size-gate
---

# Gate the treesitter highlighter on large markdown instead of trimming injections

> **Superseded 2026-08-25.** The size gate below is removed; the treesitter highlighter now
> runs on markdown of any size. The gate treated a symptom — see
> `2026-08-25-markdown-conceal-lines-not-a-size-gate.md` for the actual root cause
> (`conceal_lines` in markdown's highlights query) and the fix. This record's measurements and
> reasoning about the original stall are unchanged and still accurate.

## Context

Any full-screen redraw with a large markdown spec **visible** cost ~1.1 s. That one
mechanism produced every reported symptom: `<leader>e` (Oil float) taking over a
second, `find_files` degrading with the spec in a split, "LSP commands take more
than a second" (the request measured 0.6 ms; the redraw after it was the second),
and the float painting instantly then sitting empty while its populate callback
queued behind the stall.

Stack samples were entirely `vim/treesitter/languagetree.lua` and
`highlighter.lua` — Neovim **core**, not nvim-treesitter. The highlighter
re-resolves injected regions roughly once per visible line, each pass walking every
child tree, giving $O(\text{lines} \times \text{regions})$ per redraw. Measured on a
real 3761-line spec: 461 regions, 63.9 ms for one full re-resolution, and ~12× that
in a single observed redraw.

## Options considered

1. **Trim our own injections query.** Rejected as insufficient: 428 of 461 regions
   are `markdown_inline`, injected by `$VIMRUNTIME/queries/markdown/injections.scm`
   and unreachable from `after/queries/`. Removing our `ts`/`tsx` rules was worth
   at most 27% and left the per-line multiplication intact.
2. **Disable treesitter for large markdown entirely.** Rejected: render-markdown
   needs a parser, and the rendered view is the reason large specs are readable.
3. **Gate the highlighter only, keep the parser.** Chosen.
4. **Update nvim-treesitter.** Rejected as a fix: it ships no markdown injections
   and does not own the highlighter. Worth doing for parser fixes, separately.

## Decision

`after/ftplugin/markdown.lua` calls `vim.treesitter.stop()` for markdown buffers
above `vim.g.markdown_ts_highlight_max_lines` (1500), keeps a parser reachable via
`get_parser`, and sets `vim.bo.syntax = "markdown"` as a fallback.

`after/ftplugin/` is the **only** reliable override point: Nvim 0.12 ships
`$VIMRUNTIME/ftplugin/markdown.lua` whose first line is an unconditional
`vim.treesitter.start()`, which runs before any FileType autocmd. Verified by
wrapping `vim.treesitter.start` and capturing the caller.

## Consequences

- Worst stall 1129 ms → 107 ms. Oil 5 s → 18 ms. `find_files` snappy in a split.
- render-markdown keeps working — verified it restores all extmarks with the
  highlighter off, via its own `core.ui.update`. It does not depend on the
  highlighter, only on a parser.
- Raw-buffer treesitter colouring is lost on large markdown. The regex fallback
  covers headings and, via `vim.g.markdown_fenced_languages`, fenced code blocks —
  confirmed (`markdownH1`, `markdownHighlight_typescript`).
- `;; extends` in `after/queries/markdown/injections.scm` became affordable again
  (+28% per re-resolution ≈ +48 ms per 2-minute session) and was restored. It is
  affordable **only** because of this gate.
- Markdown between roughly 500 and 1500 lines still gets the full per-line
  highlighter plus the `extends` surcharge. Unmeasured. If files in that range feel
  sticky, lower the threshold — nothing breaks, the regex fallback just covers more
  files.

## Verification

`vim.treesitter.highlighter.active[buf] == nil` on a 3761-line spec while
`b:current_syntax == "markdown"`, render-markdown extmarks > 0, and a small
markdown buffer still carries the highlighter. The probe's buffer inventory shows
`[ts]` per buffer, making regressions visible in any profile.
