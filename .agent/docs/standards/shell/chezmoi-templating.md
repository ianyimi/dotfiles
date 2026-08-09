---
applies_to: ["*.tmpl", ".chezmoiignore", ".chezmoi.toml.tmpl", "run_once_*", "run_after_*", "dot_config/**", "dot_*"]
---
# Chezmoi Templating Rules

- **Golden rule**: edit ONLY in this repo; NEVER edit deployed files (`~/.zshrc`,
  `~/.config/**`, `~/.bootstrap/**`, `~/.pi/agent/**`). Deploy with `cma`.
- **OS conditionals**: `{{ if eq .chezmoi.os "darwin" -}} … {{ else -}} … {{ end -}}` with
  trailing `-` to trim newlines (dot_zshrc.tmpl:17-21); script templates use the non-trimming
  `{{ else if eq .chezmoi.os "linux" }}` form (run_once_before_010:5,40). Linux = CachyOS/Arch,
  first-class — always consider both branches.
- **Secrets**: NEVER literal secrets in git. `{{ (bitwarden "item" "NAME").login.password }}`
  or `{{ (bitwardenFields "item" "NAME").<field>.value }}` (dot_zshrc.tmpl:4,
  pi-agent-base/models.json.tmpl:6). Requires `BW_SESSION` — hence deploy via `cma`.
  Never modify Bitwarden vault structure or secret references without explicit approval.
- **`.chezmoi.toml.tmpl` data chain**: env var → `stdinIsATTY` promptString → fallback
  (.chezmoi.toml.tmpl:2-15). Env override exists because `stdinIsATTY` is false under
  `curl | bash` (bootstrap.sh:460-464). New template data follows the same 3-step chain.
- **Script ordering**: `run_once_before_NNN_<verb>.sh.tmpl`, NNN in tens (010, 020) — runs
  before file placement; `run_after_<verb>.sh.tmpl` runs after apply. New pre-install steps
  take the next free tens slot.
- **`.chezmoiignore` roles** (keep the explanatory comments): runtime artifacts (:1-2);
  repo-only dirs synced by run_after scripts (`pi-agent-base/`, :4-13); `*.bak*` and `*.md`
  (:26-38); **per-OS deploy gating** — `{{ if ne .chezmoi.os "darwin" }}` lists mac-only
  targets and vice versa (:40-53). Any new OS-specific config MUST be added to the
  opposite-OS block or it deploys everywhere.
- **Opaque-dir sync**: dirs that can't be `dot_*` (e.g. `pi-agent-base/` → `~/.pi/agent`) are
  rsync'd by a run_after script; `*.tmpl` members render via
  `chezmoi execute-template < in > out.partial && mv`, chmod 600, rsync `--exclude` for
  runtime state (run_after_sync-pi-agent-base.sh.tmpl:38-79). Follow it for new sync targets.
