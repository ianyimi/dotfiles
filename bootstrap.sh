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

# Setup PATH for tools that might already be installed
# This ensures command -v checks work even when running via curl | bash
if [[ "$ARCH" == "arm64" ]] && [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

echo -e "${BLUE}Detected System:${NC}"
echo "  OS: $OS"
echo "  Architecture: $ARCH"
echo ""

# Function to install Xcode Command Line Tools (required for git on macOS)
install_xcode_clt() {
    if xcode-select -p &>/dev/null; then
        echo -e "${GREEN}✓${NC} Xcode Command Line Tools already installed"
        return 0
    fi

    echo -e "${YELLOW}→${NC} Installing Xcode Command Line Tools (required for git)..."
    echo -e "${YELLOW}  Please click 'Install' in the popup dialog and wait for it to complete.${NC}"

    # Trigger the install dialog
    xcode-select --install 2>/dev/null || true

    # Wait for installation to complete
    echo -e "${YELLOW}  Waiting for installation to complete...${NC}"
    until xcode-select -p &>/dev/null; do
        sleep 5
    done

    echo -e "${GREEN}✓${NC} Xcode Command Line Tools installed"
}

# Function to install Homebrew (macOS)
install_homebrew() {
    # Add brew to PATH first (in case shell doesn't have it yet)
    if [[ "$ARCH" == "arm64" ]] && [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        echo -e "${GREEN}✓${NC} Homebrew already installed"
        return 0
    fi

    echo -e "${YELLOW}→${NC} Installing Homebrew..."
    echo -e "${YELLOW}  You may be prompted for your password.${NC}"

    # Run Homebrew installer with proper TTY handling
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty

    # Add brew to PATH for this session
    if [[ "$ARCH" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    echo -e "${GREEN}✓${NC} Homebrew installed"
}

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

# Function to setup Tailscale (must connect before Bitwarden for self-hosted access)
setup_tailscale() {
    echo ""
    echo -e "${BLUE}Setting up Tailscale...${NC}"

    # Install Tailscale CLI if not present
    if ! command -v tailscale &>/dev/null; then
        echo -e "${YELLOW}→${NC} Installing Tailscale..."
        brew install tailscale
        echo -e "${GREEN}✓${NC} Tailscale installed"
    else
        echo -e "${GREEN}✓${NC} Tailscale already installed"
    fi

    # Check if already connected - tailscale status shows IPs when connected
    TAILSCALE_STATUS=$(tailscale status 2>&1 || true)
    if echo "$TAILSCALE_STATUS" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
        echo -e "${GREEN}✓${NC} Tailscale already connected"
        return 0
    fi

    # Not connected - check if service needs to be started
    if echo "$TAILSCALE_STATUS" | grep -qi "stopped\|not running\|failed to connect"; then
        if ! brew services list | grep -E "tailscale\s+started" &>/dev/null; then
            echo -e "${YELLOW}→${NC} Starting Tailscale service..."
            sudo brew services start tailscale
            sleep 2
        else
            echo -e "${GREEN}✓${NC} Tailscale service already running"
        fi
    fi

    # Authenticate with Tailscale
    echo ""
    echo -e "${YELLOW}→${NC} Tailscale authentication required"
    echo "  A login URL will be displayed below."
    echo "  Open it in your browser and authenticate to continue."
    echo ""

    # tailscale login prints URL and waits for authentication to complete
    sudo tailscale login --accept-routes

    echo -e "${GREEN}✓${NC} Tailscale connected"
}

# Function to setup Bitwarden CLI (must run before chezmoi init so BW_SESSION is available)
setup_bitwarden() {
    local bw_email="$1"
    local bw_server="$2"

    echo ""
    echo -e "${BLUE}Setting up Bitwarden CLI...${NC}"

    # Install Bitwarden CLI if not present
    if ! command -v bw &>/dev/null; then
        echo -e "${YELLOW}→${NC} Installing Bitwarden CLI..."
        brew install bitwarden-cli
        echo -e "${GREEN}✓${NC} Bitwarden CLI installed"
    else
        echo -e "${GREEN}✓${NC} Bitwarden CLI already installed"
    fi

    # Suppress Node.js deprecation warnings
    export NODE_OPTIONS="--no-deprecation"

    # Check for existing valid session first
    if [ -f ~/.bw-session ]; then
        source ~/.bw-session
        if [ -n "$BW_SESSION" ] && bw unlock --check --session "$BW_SESSION" &>/dev/null; then
            echo -e "${GREEN}✓${NC} Bitwarden session already valid"
            return 0
        fi
    fi

    # Configure Bitwarden server
    CURRENT_SERVER=$(bw config server 2>/dev/null || echo "")
    if [ "$CURRENT_SERVER" != "$bw_server" ]; then
        echo -e "${YELLOW}→${NC} Configuring Bitwarden server: $bw_server"
        # Logout first if logged in to different server
        if bw login --check &>/dev/null; then
            bw logout
        fi
        bw config server "$bw_server"
    else
        echo -e "${GREEN}✓${NC} Bitwarden server already configured"
    fi

    # Login if not already logged in
    if ! bw login --check &>/dev/null; then
        echo ""
        echo -e "${YELLOW}→${NC} Please log in to Bitwarden:"
        BW_SESSION=$(bw login "$bw_email" --raw </dev/tty)
    else
        # Already logged in, just unlock
        echo -e "${GREEN}✓${NC} Bitwarden already logged in"
        echo -e "${YELLOW}→${NC} Unlocking Bitwarden vault..."
        BW_SESSION=$(bw unlock --raw </dev/tty)
    fi

    if [ -n "$BW_SESSION" ]; then
        export BW_SESSION
        echo "export BW_SESSION=\"$BW_SESSION\"" > ~/.bw-session
        chmod 600 ~/.bw-session
        echo -e "${GREEN}✓${NC} Bitwarden authenticated"
    else
        echo -e "${RED}✗${NC} Failed to authenticate with Bitwarden"
        exit 1
    fi
}

# Function to initialize chezmoi with dotfiles repo
init_chezmoi() {
    echo ""
    echo -e "${BLUE}Initializing chezmoi with dotfiles...${NC}"

    # Get existing values - try config file directly (most reliable)
    DEFAULT_BW_EMAIL=""
    DEFAULT_BW_SERVER=""
    DEFAULT_GITHUB_USER=""
    CHEZMOI_CONFIG="$HOME/.config/chezmoi/chezmoi.toml"

    if [ -f "$CHEZMOI_CONFIG" ]; then
        # Read from config file - extract value between quotes
        DEFAULT_BW_EMAIL=$(sed -n 's/.*bwEmail *= *"\([^"]*\)".*/\1/p' "$CHEZMOI_CONFIG" | head -1)
        DEFAULT_BW_SERVER=$(sed -n 's/.*bwServer *= *"\([^"]*\)".*/\1/p' "$CHEZMOI_CONFIG" | head -1)
        DEFAULT_GITHUB_USER=$(sed -n 's/.*githubUsername *= *"\([^"]*\)".*/\1/p' "$CHEZMOI_CONFIG" | head -1)
    fi

    # Fallback to bw config for server if not found
    if [ -z "$DEFAULT_BW_SERVER" ] && command -v bw &>/dev/null; then
        DEFAULT_BW_SERVER=$(bw config server 2>/dev/null || echo "")
    fi

    if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
        echo -e "${YELLOW}⚠${NC}  Chezmoi source directory already exists"
        read -p "Do you want to reinitialize? (y/N): " REINIT </dev/tty
        if [[ ! "$REINIT" =~ ^[Yy]$ ]]; then
            echo "Skipping initialization"
            return 0
        fi
        rm -rf "$HOME/.local/share/chezmoi"
    fi

    # Prompt for chezmoi template values with defaults
    echo ""
    if [ -n "$DEFAULT_BW_EMAIL" ] || [ -n "$DEFAULT_BW_SERVER" ] || [ -n "$DEFAULT_GITHUB_USER" ]; then
        echo -e "${BLUE}Please provide configuration values (press Enter to accept default):${NC}"
    else
        echo -e "${BLUE}Please provide configuration values:${NC}"
    fi

    # Always show what the default is, even in the prompt format
    if [ -n "$DEFAULT_BW_EMAIL" ]; then
        read -p "Bitwarden email [$DEFAULT_BW_EMAIL]: " BW_EMAIL </dev/tty
        BW_EMAIL=${BW_EMAIL:-$DEFAULT_BW_EMAIL}
    else
        read -p "Bitwarden email: " BW_EMAIL </dev/tty
    fi

    if [ -n "$DEFAULT_BW_SERVER" ]; then
        read -p "Bitwarden server URL [$DEFAULT_BW_SERVER]: " BW_SERVER </dev/tty
        BW_SERVER=${BW_SERVER:-$DEFAULT_BW_SERVER}
    else
        read -p "Bitwarden server URL: " BW_SERVER </dev/tty
    fi

    if [ -n "$DEFAULT_GITHUB_USER" ]; then
        read -p "GitHub username [$DEFAULT_GITHUB_USER]: " GITHUB_USER </dev/tty
        GITHUB_USER=${GITHUB_USER:-$DEFAULT_GITHUB_USER}
    else
        read -p "GitHub username: " GITHUB_USER </dev/tty
    fi

    # Setup Bitwarden before chezmoi init so BW_SESSION is available for templates
    setup_bitwarden "$BW_EMAIL" "$BW_SERVER"

    # Export values as environment variables for chezmoi template
    # (required because stdinIsATTY is false when running via curl | bash)
    export BITWARDEN_EMAIL="$BW_EMAIL"
    export BITWARDEN_SERVER="$BW_SERVER"
    export GITHUB_USERNAME="$GITHUB_USER"

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

            # Run apConfig directly by path (PATH won't have ~/.local/bin yet)
            APCONFIG_PATH="$HOME/.local/bin/apConfig"
            if [ -x "$APCONFIG_PATH" ]; then
                echo -e "${YELLOW}→${NC} Found apConfig script"
                read -p "Do you want to run the full system configuration now? (Y/n): " RUN_CONFIG </dev/tty
                if [[ ! "$RUN_CONFIG" =~ ^[Nn]$ ]]; then
                    "$APCONFIG_PATH"
                fi
            else
                echo -e "${YELLOW}⚠${NC}  apConfig not found at $APCONFIG_PATH"
                echo "    Reload your shell and run 'apConfig' to complete setup."
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
    read -p "Continue? (Y/n): " CONTINUE </dev/tty
    if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    # On macOS, install prerequisites first
    if [[ "$OS" == "Darwin"* ]]; then
        echo -e "${CYAN}${BOLD}[1/6] Installing Xcode Command Line Tools...${NC}"
        install_xcode_clt

        echo ""
        echo -e "${CYAN}${BOLD}[2/6] Installing Homebrew...${NC}"
        install_homebrew

        echo ""
        echo -e "${CYAN}${BOLD}[3/6] Installing chezmoi...${NC}"
        install_chezmoi

        echo ""
        echo -e "${CYAN}${BOLD}[4/6] Setting up Tailscale...${NC}"
        setup_tailscale

        echo ""
        echo -e "${CYAN}${BOLD}[5/6] Initializing dotfiles...${NC}"
        init_chezmoi

        echo ""
        echo -e "${CYAN}${BOLD}[6/6] Running OS-specific setup...${NC}"
        run_os_setup
    else
        echo -e "${CYAN}${BOLD}[1/3] Installing chezmoi...${NC}"
        install_chezmoi

        echo ""
        echo -e "${CYAN}${BOLD}[2/3] Initializing dotfiles...${NC}"
        init_chezmoi

        echo ""
        echo -e "${CYAN}${BOLD}[3/3] Running OS-specific setup...${NC}"
        run_os_setup
    fi

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
    echo "  curl -fsSL https://raw.githubusercontent.com/$GITHUB_USERNAME/dotfiles/master/bootstrap.sh | bash"
    echo ""
}

# Run main function
main
