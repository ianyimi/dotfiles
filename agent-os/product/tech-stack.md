# Tech Stack

## Dotfile Management

- **Dotfile Manager:** chezmoi
- **Template Engine:** chezmoi built-in (Go templates)
- **Version Control:** git

## Secret Management

- **Secret Store:** Bitwarden (self-hosted)
- **CLI Tool:** Bitwarden CLI (bw)
- **Session Management:** BW_SESSION environment variable

## System Automation (macOS)

- **Configuration Management:** Ansible
- **Package Manager:** Homebrew
- **Window Manager:** Aerospace
- **Status Bar:** SketchyBar
- **Window Borders:** JankyBorders

## System Automation (Linux)

- **Configuration Management:** Ansible
- **Package Managers:** apt (primary), snap, flatpak
- **Window Manager:** Hyprland (Wayland)
- **Status Bar:** Waybar
- **Application Launcher:** Rofi
- **Notification Daemon:** Dunst

## Shell Environment

- **Shell:** zsh
- **Prompt:** starship
- **Plugins:** zsh-autosuggestions, zsh-syntax-highlighting

## Development Tools

- **Terminal Multiplexer:** tmux
- **Session Manager:** tmuxinator
- **Editor:** neovim
- **Git Tools:** lazygit, lazydocker
- **Search Tools:** fzf, ripgrep, bat

## Project Management

- **Repository Structure:** Git bare repositories + worktrees
- **Project Cloner:** Custom apCloneProjects script
- **AI Standards:** agent-os

## Languages & Runtimes

- **Node.js:** Via fnm (Fast Node Manager)
- **Go:** Via Homebrew
- **Lua:** Via Homebrew (with luarocks, lunajson)
- **C Toolchain:** Via Xcode Command Line Tools

## CLI Tools

- **Development:** gh (GitHub CLI), git, node, pnpm, npm
- **DevOps:** kubectl, k9s, k6, Azure CLI, mongosh
- **Utilities:** neofetch, starship
