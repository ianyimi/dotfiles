# Product Roadmap

## Current State

The following features are complete and working:

- Single-command bootstrap for fresh machines
- Bitwarden CLI integration for secure secret management
- Ansible playbook for macOS system configuration
- Homebrew package installation and management
- Shell environment (zsh + starship prompt)
- Development tools (tmux, tmuxinator, neovim)
- Git bare repository setup for project management
- Agent-OS integration for AI coding standards
- Template-based dotfile management with chezmoi
- Automatic project cloning and .env file population

## Phase 1: Agent System Setup

Establish an agent-based workflow for managing this dotfiles project:

- Configure agent-os for dotfiles/system configuration projects
- Create standards for managing chezmoi templates
- Define conventions for Bitwarden secret organization
- Set up development workflow with AI assistance

## Phase 2: Future Enhancements

### Terminal Survey on First Install

Interactive survey during bootstrap that runs after GitHub credentials are obtained:

- Present list of available repos from your GitHub account
- Multi-select interface (fzf or similar) to choose which repos to clone
- Option to skip entirely by pressing Enter
- Remembers selections for future reinstalls
- Integrates with `apCloneProjects` workflow

### Vaultwarden Session Timeout

Increase Bitwarden session timeout on Vaultwarden server to reduce re-authentication friction:

- Set `SESSION_TIMEOUT=43200` (12 hours) or `1440` (24 hours) in Vaultwarden container config
- Document in README for self-hosted users

### Background Session Refresh

Optional daemon to keep Bitwarden session alive:

- Refresh session before expiry
- Runs in background via launchd
- Fallback if server-side timeout cannot be increased
