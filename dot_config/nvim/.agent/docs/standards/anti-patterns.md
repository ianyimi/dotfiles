# Anti-Patterns

Learned agent mistakes, corrected. Format: `- AP-NNN (date, seen Nx) rule`.

- AP-001 (2026-08-25, seen 1x) Do not cap a feature by input size when the cost
  is a fixed per-redraw mechanism, not the input itself. The 2026-08-17 fix
  gated the markdown treesitter highlighter above 1500 lines after measuring a
  ~1.1s stall on a large file — a real measurement, wrong mechanism. It
  silently substituted Vim's regex markdown syntax above the threshold, whose
  50-line `syn sync` window cannot resolve a fenced code block that opened
  further back, so long specs lost fenced-code highlighting entirely below the
  sync window. The actual cost was one query directive (`conceal_lines`) that
  forced a per-screen-row tree walk on every redraw; removing the directive
  made the highlighter affordable at any size, no gate needed. When a cost
  scales with something you did not measure, find the mechanism before adding
  a size threshold — and treat any fallback path the threshold triggers as a
  feature in its own right that needs its own verification, not a discount
  assumed to be equivalent.
