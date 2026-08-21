---
applies_to: ["dot_zshrc.tmpl", "dot_bashrc"]
---
# Alias Conventions

- **`dot_zshrc.tmpl` is the single source of truth for all aliases.** `dot_bashrc` is a legacy
  snapshot (Windows-era paths, dot_bashrc:37) — never add or port aliases there.
- When the user uses an unfamiliar short command (`cma`, `nrd`, `lgCog`), look it up in
  `dot_zshrc.tmpl` before asking. "Run cma" is a literal instruction — don't expand it.
- **Verb-prefix triples** for locations, camelCase target name:
  - `cd<Name>` — cd into dir (dot_zshrc.tmpl:85-93, e.g. `cdConfig`, `cdChezmoi`)
  - `nv<Name>` — open in nvim (dot_zshrc.tmpl:94-110, e.g. `nvCog`, `nvZsh`)
  - `lg<Name>` — lazygit in repo (e.g. `lgChezmoi="lazygit -p ~/.local/share/chezmoi"`)
  A new project gets the full cd/nv/lg triple as a 3-line block (pattern at :93-95).
- **Short mnemonics** for tools are 2-4 lowercase letters: `cm`, `cma`, `cme`, `tm`, `tma`,
  `nrd/nrb/nrs/nrt` (dot_zshrc.tmpl:46-63). Tool actions are camelCase with tool prefix:
  `aeromonStart/Stop/Restart/Status/Logs` (:116-120), `hyprReload` (:124).
- **OS-specific aliases live inside `{{ if eq .chezmoi.os "darwin" -}}…{{ else -}}…{{ end -}}`
  blocks in the same file** — never separate files (:17-21, :79-83). macOS and CachyOS are both
  first-class; a mac-only alias usually wants a Linux equivalent in the `else` branch.
- **`cma` is the canonical deploy command** (:47). Never tell users to run bare `chezmoi apply`
  — templates need `BW_SESSION` in the invoking shell.
- Dot-navigation `.` … `.......` counts parent levels (:7-13); don't add alternatives.
