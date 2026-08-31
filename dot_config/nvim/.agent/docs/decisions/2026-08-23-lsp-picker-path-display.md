---
date: 2026-08-23
status: accepted
supersedes: none
---

# Give telescope's LSP pickers unbounded path columns instead of wider ones

## Context

`gr` (`lsp_references`) rendered every result as the same string. All references in a project
sit under a shared directory, and telescope's `gen_from_quickfix` puts `path:lnum:col` in a
column declared `{ width = vim.F.if_nil(opts.fname_width, 30) }` (`make_entry.lua:449`), then
truncates it **head-first** (`entry_display.lua:83`) — keeping the common prefix and discarding
the part that distinguishes the rows. `find_files` was unaffected, which made the two pickers
look gratuitously inconsistent: `gen_from_file` has a single unbounded column.

The linked upstream issue (telescope#1958) is about `path_display` on `find_files` and does not
apply; `path_display` controls how the path string is *transformed*, not the column that clips
it.

Auditing every LSP picker against its entry maker found three distinct situations:

| Entry maker | Pickers | Path cap |
|---|---|---|
| `gen_from_quickfix` | references, definitions, type_definitions, implementations, incoming_calls, outgoing_calls | 30 cols, path first |
| `gen_from_lsp_symbols` | document_symbols, workspace_symbols, dynamic_workspace_symbols | 30 cols, path first of three |
| `gen_from_diagnostics` | `builtin.diagnostics` | none — path is already `remaining` |

## Options considered

1. **Raise `fname_width`.** Rejected. A fixed column truncates at *some* width; 80 clips on a
   narrow split, and an oversized column pushes the code text off-screen entirely.
2. **Compute `fname_width` from `vim.o.columns`.** Rejected for the same reason — it moves the
   cliff rather than removing it. Measured: `fname_width = 0.5` shifted truncation from 30 to
   50 columns on a 100-column results pane, still truncating a realistically deep path.
3. **`path_display = { "tail" }` / `"smart"`.** Rejected: discards the path information the
   developer explicitly wanted, and remains subject to the same column cap.
4. **Custom entry makers with unbounded path columns** (chosen). A column is truncated *only*
   if it carries a `width` key; keyless columns and `remaining = true` pass through untouched
   (`entry_display.lua:89`). So the fix is structural — put the path where nothing clips it.

## Decision

- Config lives in the telescope spec's `pickers` table, **not** on the `gr` keymap. Picker-level
  config applies to every invocation path — keymaps, `:Telescope lsp_*`, future callsites. An
  initial keymap-local fix covered only 4 of 9 pickers, which is precisely the failure mode.
- `quickfix_path_first` wraps `gen_from_quickfix` and overrides only `display`, using columns
  `{ {}, { remaining = true } }`. Neither carries a `width`, so the path always renders in full
  and the inline code text takes the remainder, clipped by the window edge.
- `symbols_path_last` wraps `gen_from_lsp_symbols` for the two workspace symbol pickers. That
  maker orders columns path, symbol, kind — the path is structurally never last, so no width
  value can free it. The wrapper reorders to symbol, kind, path.
- `lsp_document_symbols` hides its path (`path_display = { "hidden" }`): single-buffer picker,
  so the path is identical on every row and the width is better spent on symbol names.
- `builtin.diagnostics` is left alone; its path is already the `remaining` column.
- Both wrappers delegate to telescope's maker and override *only* `display`, preserving
  `filename`/`lnum`/`col`, which drive the preview pane and the jump on select.
- Bounded columns use **absolute** widths only. `entry_display` memoizes a resolved fractional
  width from the first window it renders into, so a fraction in a shared displayer would leak
  one picker's geometry into another's.

## Consequences

Paths never truncate in any LSP picker, at any window width. The code text survives in the
quickfix family, subordinate to the path.

The trade accepted: **column alignment is gone** in those pickers. Paths vary in length, so the
code text begins at a different screen column on every row. Aligning it requires a fixed path
column, which is the original bug — the two are mutually exclusive, and path precedence was the
developer's explicit choice. Losing the fixed column also lost its padding, so the separator
carries its own (`" ▏ "`) and the text is trimmed of source indentation.

### Risks

- Both wrappers depend on telescope internals: the field names its makers set, and the column
  order of `gen_from_lsp_symbols`. A telescope update could change either. Failure mode is a
  wrong-looking row, not a broken picker.
- `symbols_path_last` mirrors telescope's `lsp_type_highlight` map to keep symbol-kind colors;
  that table is file-local to `make_entry.lua` and cannot be required. New LSP symbol kinds
  upstream would render uncolored until the map is extended.
- A lazily-built `entry_maker` via an `__index` metatable was tried and abandoned: telescope
  merges picker opts with `pairs`, which never fires `__index`. Built eagerly instead, which is
  safe because the spec's `opts()` already requires telescope submodules.

## Verification

Headless only — these are chezmoi sources, and `chezmoi apply` is the developer's to run, so no
in-editor check was possible. `telescope.setup()` was called with the real `spec.opts()`, then
all nine pickers were rendered through their configured entry makers at 60/100/120-column
widths with deep and shallow paths: no truncation anywhere, code text present in the quickfix
family, and `filename`/`lnum`/`col` asserted intact on every entry.
