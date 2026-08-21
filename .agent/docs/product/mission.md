# Mission

Personal dotfiles for a consistent development environment across machines (macOS + CachyOS).
Manages shell configuration (zsh + starship), tmux workflows, Neovim, window management
(AeroSpace/SketchyBar on macOS, Hyprland/noctalia on CachyOS), machine provisioning (Ansible),
and secure secret management via self-hosted Bitwarden. Built on chezmoi for templating and
cross-machine synchronization. Also home of `harness/`, the platform-agnostic agent harness CLI,
and `pi-agent-base/`, the global agent config synced to every machine.

## Current Focus

Daily maintenance and incremental improvements:
- Tracking new tools and configurations as adopted
- Agent-assisted fixes for config issues
- Rolling out the agent harness across projects
- Keeping dotfiles in sync across machines

## Constraints + Non-Goals

- **Never modify secrets**: no changes to Bitwarden vault structure or secret references without
  explicit approval. Secrets live in the self-hosted instance.
- **Platform-specific care**: guard Darwin vs Linux differences with chezmoi templating
  (`{{ if eq .chezmoi.os ... }}`). Never assume macOS-only.
- **Stability over novelty**: this is a working system used daily; changes must be tested.
- **Backward compatibility**: changes must not break machines that haven't pulled latest.
