---
applies_to: ["dot_bootstrap/*.yml", "bootstrap.sh"]
---
# Where a New Package Goes

A package MUST be added to **both** playbooks, or the omission commented (nodejs comment,
cachyos.yml:120-122; macOS-only sketchybar/aerospace). Decision table:

| Kind | macos.yml | cachyos.yml |
|------|-----------|-------------|
| CLI tool | `Brew Install (CLI)` (:174), own `Check Install - X` task | `Pacman Install (CLI)` name list (:112-131) if in repos, else `AUR Install (paru)` loop (:150) |
| GUI app | `Brew Install (Apps)` cask + `ignore_errors: true` (:89) | `GUI Apps` pacman (:292) or `GUI Apps (AUR)` (:309) |
| npm global | npm section (`community.general.npm`, `global: true`) | same; user prefix `~/.local/share/npm` (:171-175) — never sudo npm |
| Font | `Brew Install (Fonts)` casks (:693) | `Fonts` ttf-* list (:348) |
| Pi extension | Pi block, `pi install npm:X` + `creates:` guard | same (:238-290) — keep both lists in sync |

- Prefer `<pkg>-bin` AUR variants over source builds (oxlint-bin, fnm-bin, cachyos.yml:154-158).
- **Bootstrap-owned tools** (tailscale, bitwarden-cli, chezmoi, ansible) are installed by
  bootstrap.sh; playbooks only re-assert them (cachyos.yml:133-140). New bootstrap-critical
  tools go in bootstrap.sh, not the playbooks.
- Unverified AUR names: add `# VERIFY` comment + `ignore_errors: true` until confirmed.
