---
applies_to: ["lua/config/keymaps.lua", "lua/plugins/**/*.lua", "lua/util/toggle.lua"]
---
# Keymap placement & structure

## Where a new binding goes (decide first)
- Global, plugin-independent, always-on (editing ops, window/tab/buffer control, save,
  void-register cuts) → `lua/config/keymaps.lua`. It is required eagerly at
  config/lazy.lua:56, BEFORE lazy.setup, so maps exist from startup (keymaps.lua:6-8, 44-47).
- Tied to a plugin → that spec's `keys` table, so the binding also lazy-loads the plugin on
  first press (barbar.lua:5-38, grug-far.lua:4-51, undotree.lua:5).
- Needs runtime data (harpoon list, telescope builtins) → `keys = function() ... return
  {...} end`, building entries in the closure (harpoon.lua:71-172, grug-far.lua:4).
- Buffer-local / attach-time (LSP) → set inside `on_attach`/config via a local `map()`
  helper, never globally (nvim-lspconfig.lua:91-104).
- Toggles → `LazyVim.toggle.map(lhs, {...})` (util/toggle.lua:29-35); wires which-key
  icon+desc automatically (indent-blankline.lua:5).

## Declaration API
- In keymaps.lua: `local keymap = vim.keymap` then `keymap.set(...)` (keymaps.lua:1).
- In plugin `keys` tables: lazy's list form `{ lhs, rhs_or_fn, desc = ..., mode = ... }` —
  NOT `vim.keymap.set` (barbar.lua:6, grug-far.lua:9-20).
- Maps set inside a plugin config that MIGHT duplicate a lazy `keys` entry: call
  `LazyVim.safe_keymap_set` — skips creation when a lazy keys handler owns the lhs,
  defaults `silent=true` (util/init.lua:230-252, toggle.lua:32).

## desc convention
- Every leader/user-facing map REQUIRES a `desc`. Trivial operator remaps may omit it
  (keymaps.lua:6-8, `<S-q>` nop at :157).
- Style: Title Case with the mnemonic letter bracketed: `"[F]ind [F]iles"`, `"[W]rite file"`,
  `"[R]e[n]ame"` (keymaps.lua:11, telescope.lua:564-599, nvim-lspconfig.lua:102). Plain
  Title Case is acceptable for command-like maps: `"Previous Buffer"` (barbar.lua:6).

## mode convention
Default `"n"`. Multi-mode maps pass a list: `mode = { "n", "v" }` (grug-far.lua:18).
Visual/select editing uses `"v"`/`"x"` explicitly, often both (keymaps.lua:130-133, 148).
