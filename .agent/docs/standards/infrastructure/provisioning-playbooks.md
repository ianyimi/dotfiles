---
applies_to: ["dot_bootstrap/*.yml"]
---
# Ansible Playbook Conventions (macos.yml / cachyos.yml)

- **Structure**: one flat playbook per OS, multiple plays, no roles/tags/inventory:
  `hosts: localhost`, `connection: local`, explicit `become:` per play. Plays grouped by
  package domain (`Brew Install (CLI)` macos.yml:174, `Pacman Install (CLI)` cachyos.yml:107).
  cachyos.yml deliberately mirrors macos.yml structure (cachyos.yml:2).
- **Task naming**: simple installs are `Check Install - <Name>`; multi-step installs use a
  `block:` with check → conditional install (pnpm: macos.yml:246, cachyos.yml:196).
- **Idempotency** (in order of preference):
  1. Package module `state: present` (`community.general.homebrew`/`homebrew_cask`/`pacman`);
     `state: latest` only for head-tracking tools (neovim, sketchybar).
  2. Shell installers guarded by `args: creates:` (pi extensions, cachyos.yml:262-290).
  3. `which <cmd>` probe with `failed_when: false` + `changed_when: false`, then
     `when: <probe>.rc != 0` (paru: cachyos.yml:24-37).
  4. paru loops: `paru -S --needed --noconfirm {{ item }}` with stdout-based `changed_when`
     and `ignore_errors: true` (cachyos.yml:150-164).
- **become**: per play, never per task. pacman plays `become: true`; paru/npm/pi plays MUST
  be `become: false` (AUR builds run as user, cachyos.yml:5-6). Passwordless pacman for paru
  via visudo-validated sudoers drop-in (cachyos.yml:43-52). macOS brew plays `become: false`.
- **Secrets**: Bitwarden reads use `environment: BW_SESSION` lookup + `no_log: true` +
  `timeout: 30`, guarded by session-length check, with a debug warn fallback
  (macos.yml:41-58, cachyos.yml:60-80). Never inline secrets.
- **`# VERIFY` marker**: flags an unconfirmed AUR package name; keep `ignore_errors: true`
  until verified on real hardware, then delete the marker (cachyos.yml:250,319,343,388).
- **GUI apps always get `ignore_errors: true`** — a broken app must not abort provisioning.
- Ordering: service-dependent plays go last (Aerospace, macos.yml:715).
