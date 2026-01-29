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

# Configuration
GITHUB_USERNAME="ianyimi"
REPO_URL="https://github.com/${GITHUB_USERNAME}/dotfiles"

echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}   Universal Dotfiles Bootstrap${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo -e "${BLUE}Detected System:${NC}"
echo "  OS: $OS"
echo "  Architecture: $ARCH"
echo ""

# Function to install chezmoi
install_chezmoi() {
    if command -v chezmoi &>/dev/null; then
        echo -e "${GREEN}✓${NC} chezmoi is already installed"
        return 0
    fi

    echo -e "${YELLOW}→${NC} Installing chezmoi..."

    case "$OS" in
        Darwin*)
            # macOS
            if command -v brew &>/dev/null; then
                brew install chezmoi
            else
                # Use official installer if brew not available
                sh -c "$(curl -fsLS get.chezmoi.io)"
                # Add ~/bin to PATH for this session (where get.chezmoi.io installs it)
                export PATH="$HOME/bin:$PATH"
            fi
            ;;
        Linux*)
            # Linux
            if command -v snap &>/dev/null; then
                sudo snap install chezmoi --classic
            elif command -v apt-get &>/dev/null; then
                # Debian/Ubuntu
                sudo apt-get update
                sudo apt-get install -y chezmoi
            elif command -v dnf &>/dev/null; then
                # Fedora
                sudo dnf install -y chezmoi
            elif command -v pacman &>/dev/null; then
                # Arch
                sudo pacman -S --noconfirm chezmoi
            else
                # Fallback to official installer
                sh -c "$(curl -fsLS get.chezmoi.io)"
                # Add ~/bin to PATH for this session (where get.chezmoi.io installs it)
                export PATH="$HOME/bin:$PATH"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows (Git Bash/MSYS2)
            echo -e "${YELLOW}⚠${NC}  Windows detected. Please install chezmoi manually:"
            echo "  https://www.chezmoi.io/install/#windows"
            exit 1
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓${NC} chezmoi installed successfully"
}

# Function to initialize chezmoi with dotfiles repo
init_chezmoi() {
    echo ""
    echo -e "${BLUE}Initializing chezmoi with dotfiles...${NC}"

    if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
        echo -e "${YELLOW}⚠${NC}  Chezmoi source directory already exists"
        read -p "Do you want to reinitialize? (y/N): " REINIT
        if [[ ! "$REINIT" =~ ^[Yy]$ ]]; then
            echo "Skipping initialization"
            return 0
        fi
        rm -rf "$HOME/.local/share/chezmoi"
    fi

    # Initialize and apply dotfiles
    if chezmoi init --apply "$REPO_URL"; then
        echo -e "${GREEN}✓${NC} Dotfiles initialized and applied"
    else
        echo -e "${RED}✗${NC} Failed to initialize dotfiles"
        echo "You can try manually with: chezmoi init --apply $REPO_URL"
        exit 1
    fi
}

# Function to run OS-specific setup
run_os_setup() {
    echo ""
    echo -e "${BLUE}Running OS-specific setup...${NC}"

    case "$OS" in
        Darwin*)
            # macOS
            echo "Running macOS setup..."

            # The run_once scripts should have already executed during chezmoi apply
            # But we can also manually trigger the main setup
            if command -v apConfig &>/dev/null; then
                echo -e "${YELLOW}→${NC} apConfig command is available"
                read -p "Do you want to run the full system configuration now? (Y/n): " RUN_CONFIG
                if [[ ! "$RUN_CONFIG" =~ ^[Nn]$ ]]; then
                    apConfig
                fi
            else
                echo -e "${YELLOW}⚠${NC}  apConfig not yet in PATH. Reload your shell and run 'apConfig' to complete setup."
            fi
            ;;
        Linux*)
            # Linux
            echo "Running Linux setup..."
            echo -e "${YELLOW}⚠${NC}  Linux-specific setup not yet implemented"
            echo "Please check your dotfiles for Linux-specific run_once scripts"
            ;;
        *)
            echo -e "${YELLOW}⚠${NC}  No OS-specific setup available for $OS"
            ;;
    esac
}

# Main execution
main() {
    echo -e "${BOLD}This script will:${NC}"
    echo "  1. Install chezmoi (if not present)"
    echo "  2. Clone your dotfiles from: $REPO_URL"
    echo "  3. Initialize your system configuration"
    echo ""
    read -p "Continue? (Y/n): " CONTINUE
    if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    echo -e "${CYAN}${BOLD}[1/3] Installing chezmoi...${NC}"
    install_chezmoi

    echo ""
    echo -e "${CYAN}${BOLD}[2/3] Initializing dotfiles...${NC}"
    init_chezmoi

    echo ""
    echo -e "${CYAN}${BOLD}[3/3] Running OS-specific setup...${NC}"
    run_os_setup

    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}   ✓ Bootstrap Complete!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Restart your terminal or run: source ~/.zshrc (or ~/.bashrc)"
    echo "  2. If apConfig didn't run automatically, run: apConfig"
    echo "  3. Your secrets will be populated from Bitwarden"
    echo ""
    echo -e "${YELLOW}Tip:${NC} You can re-run this script anytime with:"
    echo "  bash <(curl -fsSL https://raw.githubusercontent.com/$GITHUB_USERNAME/dotfiles/master/bootstrap.sh)"
    echo ""
}

# Run main function
main
