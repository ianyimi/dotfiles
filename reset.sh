#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
    echo "Usage: reset.sh [OPTIONS]"
    echo ""
    echo "Reset dotfiles installation. Without flags, shows interactive menu."
    echo ""
    echo "Options:"
    echo "  --dotfiles      Remove chezmoi source, config, and applied dotfiles"
    echo "  --tailscale     Remove Tailscale app and config"
    echo "  --bitwarden     Remove Bitwarden CLI and session"
    echo "  --homebrew      Remove Homebrew and all packages"
    echo "  --xcode         Remove Xcode Command Line Tools"
    echo "  --all           Remove everything (full reset)"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  reset.sh                          # Interactive menu"
    echo "  reset.sh --dotfiles               # Quick reset (dotfiles only)"
    echo "  reset.sh --tailscale              # Reset dotfiles + Tailscale"
    echo "  reset.sh --tailscale --bitwarden  # Reset dotfiles + Tailscale + Bitwarden"
    echo "  reset.sh --all                    # Full reset (everything)"
}

# Interactive menu
show_interactive_menu() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}   Dotfiles Reset Script${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Select reset type:${NC}"
    echo ""
    echo "  1) Simple reset (recommended)"
    echo "     - Removes dotfiles, chezmoi config, applied configs"
    echo "     - Keeps Homebrew, Tailscale, Bitwarden, Xcode CLT"
    echo ""
    echo "  2) Select components"
    echo "     - Choose which components to remove"
    echo ""
    echo "  3) Complete reset"
    echo "     - Removes everything (full factory reset)"
    echo ""
    read -p "Enter choice [1-3] (default: 1): " CHOICE </dev/tty
    CHOICE=${CHOICE:-1}

    case $CHOICE in
        1)
            RESET_DOTFILES=true
            ;;
        2)
            select_components
            ;;
        3)
            RESET_DOTFILES=true
            RESET_TAILSCALE=true
            RESET_BITWARDEN=true
            RESET_HOMEBREW=true
            RESET_XCODE=true
            ;;
        *)
            echo -e "${RED}Invalid choice. Defaulting to simple reset.${NC}"
            RESET_DOTFILES=true
            ;;
    esac
}

# Component selection menu
select_components() {
    echo ""
    echo -e "${BOLD}Select components to remove:${NC}"
    echo "(Press Enter for default, or type y/n)"
    echo ""

    read -p "  Dotfiles & chezmoi config? [Y/n]: " ans </dev/tty
    [[ ! "$ans" =~ ^[Nn]$ ]] && RESET_DOTFILES=true

    read -p "  Tailscale? [y/N]: " ans </dev/tty
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_TAILSCALE=true

    read -p "  Bitwarden CLI? [y/N]: " ans </dev/tty
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_BITWARDEN=true

    read -p "  Homebrew & all packages? [y/N]: " ans </dev/tty
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_HOMEBREW=true

    read -p "  Xcode Command Line Tools? [y/N]: " ans </dev/tty
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_XCODE=true
}

# Default flags
RESET_DOTFILES=false
RESET_TAILSCALE=false
RESET_BITWARDEN=false
RESET_HOMEBREW=false
RESET_XCODE=false
USE_FLAGS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    USE_FLAGS=true
    case $1 in
        --dotfiles)
            RESET_DOTFILES=true
            shift
            ;;
        --tailscale)
            RESET_TAILSCALE=true
            shift
            ;;
        --bitwarden)
            RESET_BITWARDEN=true
            shift
            ;;
        --homebrew)
            RESET_HOMEBREW=true
            shift
            ;;
        --xcode)
            RESET_XCODE=true
            shift
            ;;
        --all)
            RESET_DOTFILES=true
            RESET_TAILSCALE=true
            RESET_BITWARDEN=true
            RESET_HOMEBREW=true
            RESET_XCODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# If no flags provided, show interactive menu
if [ "$USE_FLAGS" = false ]; then
    show_interactive_menu
fi

# Show header if using flags (interactive already shows it)
if [ "$USE_FLAGS" = true ]; then
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}   Dotfiles Reset Script${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo ""
fi

# Check if anything selected
if ! $RESET_DOTFILES && ! $RESET_TAILSCALE && ! $RESET_BITWARDEN && ! $RESET_HOMEBREW && ! $RESET_XCODE; then
    echo -e "${YELLOW}Nothing selected to remove.${NC}"
    exit 0
fi

# Confirm
echo ""
echo -e "${YELLOW}This will remove:${NC}"
$RESET_DOTFILES && echo "  - Chezmoi source, config, and applied dotfiles"
$RESET_TAILSCALE && echo "  - Tailscale app and config"
$RESET_BITWARDEN && echo "  - Bitwarden CLI and session"
$RESET_HOMEBREW && echo "  - Homebrew and all packages"
$RESET_XCODE && echo "  - Xcode Command Line Tools"
echo ""
read -p "Continue? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# Reset dotfiles
if $RESET_DOTFILES; then
    echo -e "${YELLOW}→${NC} Removing dotfiles and chezmoi config..."
    rm -rf ~/.local/share/chezmoi
    rm -rf ~/.config
    rm -rf ~/.local/bin
    rm -rf ~/.zshrc ~/.bashrc ~/.gitconfig ~/.zprofile
    rm -rf ~/.bootstrap
    rm -rf ~/bin/chezmoi
    rm -rf ~/.chezmoi.toml
    echo -e "${GREEN}✓${NC} Dotfiles removed"
fi

# Reset Tailscale
if $RESET_TAILSCALE; then
    echo -e "${YELLOW}→${NC} Removing Tailscale..."
    # Quit Tailscale if running
    osascript -e 'quit app "Tailscale"' 2>/dev/null || true
    # Remove via brew if available
    if command -v brew &>/dev/null; then
        brew uninstall --cask tailscale 2>/dev/null || true
    fi
    # Remove app manually if still present
    rm -rf /Applications/Tailscale.app
    # Remove Tailscale config
    rm -rf ~/Library/Containers/io.tailscale.ipn.macos
    rm -rf ~/Library/Group\ Containers/*.tailscale.*
    echo -e "${GREEN}✓${NC} Tailscale removed"
fi

# Reset Bitwarden
if $RESET_BITWARDEN; then
    echo -e "${YELLOW}→${NC} Removing Bitwarden CLI..."
    rm -rf ~/.bw-session
    if command -v brew &>/dev/null; then
        brew uninstall bitwarden-cli 2>/dev/null || true
    fi
    # Remove bw config
    rm -rf ~/.config/Bitwarden\ CLI
    echo -e "${GREEN}✓${NC} Bitwarden CLI removed"
fi

# Reset Homebrew
if $RESET_HOMEBREW; then
    echo -e "${YELLOW}→${NC} Removing Homebrew (this may take a while)..."
    if command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    else
        echo "  Homebrew not found, skipping"
    fi
    echo -e "${GREEN}✓${NC} Homebrew removed"
fi

# Reset Xcode CLT
if $RESET_XCODE; then
    echo -e "${YELLOW}→${NC} Removing Xcode Command Line Tools..."
    sudo rm -rf /Library/Developer/CommandLineTools
    echo -e "${GREEN}✓${NC} Xcode Command Line Tools removed"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}   ✓ Reset Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "You can now re-run the bootstrap:"
echo "  curl -fsSL https://raw.githubusercontent.com/ianyimi/dotfiles/master/bootstrap.sh | bash"
echo ""
