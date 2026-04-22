# Mission

Personal dotfiles for consistent development environment across machines. Manages shell configuration (zsh with starship), tmux workflows, Neovim setup, window management (Aerospace + SketchyBar), and secure secret management via self-hosted Bitwarden. Built on chezmoi for templating and cross-machine synchronization.

## Current Focus

Daily maintenance and incremental improvements:
- Tracking new tools and configurations as adopted
- Agent-assisted fixes for config issues
- Expanding macOS setup automation via Ansible playbook
- Keeping dotfiles in sync across multiple machines

## Constraints + Non-Goals

- **Never modify secrets**: Don't change Bitwarden vault structure or secret references without explicit approval. Secrets are managed separately in the self-hosted instance.
- **Platform-specific care**: Properly handle Darwin vs Linux differences using chezmoi's `darwin/` and `linux/` directories. Don't assume macOS-only.
- **Stability over novelty**: Changes should be tested and reliable. This is a working system used daily across machines.
- **Backward compatibility**: New changes must work on machines that haven't pulled the latest dotfiles yet.
