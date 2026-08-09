---
applies_to: ["bootstrap.sh", "reset.sh", "run_once_*", "run_after_*", "dot_local/bin/*"]
---
# Shell Script Conventions

- **Shebang + strictness**: `#!/bin/bash` with `set -e` only (bootstrap.sh:1-3, reset.sh:1-3).
  No `set -u`/`pipefail` — scripts rely on unset-var checks (`[ -n "$BW_SESSION" ]`), and
  `bw-session-check` deliberately omits `set -e` because it branches on command failure.
- **Compat target is macOS bash 3.2**: `find … | while read` instead of globstar
  (run_after_sync-pi-agent-base.sh.tmpl:60-64), `grep`+`awk`/`cut` instead of jq for JSON
  (bootstrap.sh:398-400).
- **Idempotency guard**: every install step checks first and prints `✓ … already installed`
  then returns/exits 0 (bootstrap.sh:106-109; run_once_install_ansible.sh:3-6). run_once
  scripts are idempotent safety nets for what bootstrap.sh already did — must tolerate re-runs.
- **OS detection**: `OS="$(uname -s)"` + `case "$OS" in Darwin*) … Linux*)` (bootstrap.sh:27,
  119-152). Arch/CachyOS: `[[ -f /etc/arch-release ]] || grep -qi 'arch|cachyos'
  /etc/os-release` → `IS_ARCH=true` flag (bootstrap.sh:31-36). On Linux check `pacman` before
  snap (bootstrap.sh:131-133).
- **Output convention**: ANSI color vars at top (`RED/GREEN/YELLOW/BLUE/CYAN/BOLD/NC`),
  status glyphs `✓` done / `→` in progress / `⚠` warning / `✗` fatal + `exit 1`
  (bootstrap.sh:6-13, 63, 68, 146). Simple run_once scripts use plain `echo "✓ …"`.
- **Failure shape**: fail loudly — `✗` message + actionable next command, then `exit 1`
  (bootstrap.sh:377-380). Atomic writes: render to `.partial` then `mv`
  (run_after_sync-pi-agent-base.sh.tmpl:70-73). Non-critical cleanup uses `|| true`.
- **Bitwarden plumbing**: session persists in `~/.bw-session` (chmod 600); always `source`
  then validate with `bw unlock --check --session "$BW_SESSION"`
  (executable_bw-session-check:9-15). `export NODE_OPTIONS="--no-deprecation"` before any
  `bw` call. Any file a helper writes containing secrets gets `chmod 600`.
- Interactive prompts: `read -p "…? (y/n): "` + `[[ "$ans" =~ ^[Yy]$ ]]`; pipe-to-bash
  contexts read from `</dev/tty` (bootstrap.sh:514).
