---
applies_to: ["lua/config/keymaps.lua", "lua/plugins/**/*.lua"]
---
# Leader namespaces, reserved keys & collisions

Leader is `<space>`. Before adding a `<leader>X...` map, place it in the right namespace.
Groups are declared in which-key.lua:10-27; owners below (ACTIVE plugins only).

| Prefix | Meaning | Owners / evidence |
|---|---|---|
| `<leader><tab>` | tabs (group) | which-key.lua:10 |
| `<leader>b` | buffer (group) + split-below direct map | barbar `bp` :36; CONFLICT keymaps.lua:33 |
| `<leader>c` | code | LSP `ca`/`cd` lspconfig.lua:92-103; `cw` worktree; `cp` copy-path |
| `<leader>d`/`D` | delete-to-void (n/v/x) | keymaps.lua:163-165; also LSP `D`/`ds` :96-99 |
| `<leader>e` | explore files (oil float) | keymaps.lua:26 |
| `<leader>f` | file/find (group) | telescope.lua:564-599, grug-far `fr/fR/fc`, `fy` |
| `<leader>g` | git | lazygit `gg`/`gG` keymaps.lua:135-140 |
| `<leader>h/j/k/l` | window focus | keymaps.lua:44-47 |
| `<leader>m` | format buffer (`mp`) | conform.lua:64 |
| `<leader>r` | LSP restart `rr` / rename `rn` | keymaps.lua:200, lspconfig.lua:102 |
| `<leader>s` | toggle harpoon file | harpoon.lua:76 |
| `<leader>t` | theme/toggle (`to/tf/tl/te` huez:41-44, `tc` ts-context:7) | |
| `<leader>u` | undotree | undotree.lua:5 |
| `<leader>v`/`x` | split-right / close-split | keymaps.lua:31,36 |
| `<leader>w` | write (group + direct save) | which-key.lua:14, keymaps.lua:8 |
| `<leader>y` | harpoon quick menu | harpoon.lua:112 |
| `<leader>1..9` | harpoon select N | harpoon.lua:160-170 |
| `<leader>X`/`Z` | barbar close-right / close-left | barbar.lua:37-38 |

Disabled specs still holding namespaces (do NOT assume free): opencode `<leader>o*`, avante
`<leader>c{o,t,a,b,c}`, mini-files `<leader>e/E`, bufferline `<leader>b*`, codesnap `<leader>Y`.

## Reserved control keys — three navigation planes, distinct modifiers
- `<S-h>`/`<S-l>` = prev/next buffer; `<C-h>`/`<C-l>` = move buffer + harpoon-order sync
  (barbar.lua:6-33). Barbar owns C-h/C-l uncontested.
- Tmux navigation is NOT on C-h/j/k/l — it is `<a-z>{h,j,k,l,.}` (vim-tmux-navigator.lua:11-15).
- `<a-...>` = tabs (`<a-t>/<a-x>/<a-h>/<a-l>` keymaps.lua:50-55) + telescope insert-mode.

## Collision practice (accepted tradeoffs — do not extend)
1. `<leader>b` and `<leader>w` are both group prefixes AND complete maps — forces a
   timeoutlen wait. Avoid mapping a bare leader key that other maps extend.
2. `<leader>d` (void-delete) coexists with `<leader>ds` (LSP) — add no more `<leader>d...`.
3. Buffer-close is split: `<S-x>`/`<C-S-x>` smart close (keymaps.lua:96/121) vs barbar
   `<leader>X`/`<leader>Z` range-close — keep new buffer ops consistent with this split.
