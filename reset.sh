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
    echo "  --apps          Remove all brew-installed apps (Ghostty, Discord, Spotify, etc.)"
    echo "  --wm            Remove window manager (Aerospace, SketchyBar, JankyBorders)"
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
    echo "  reset.sh --apps                   # Remove installed applications"
    echo "  reset.sh --wm                     # Remove window manager tools"
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
    echo "     - Keeps Homebrew, Tailscale, Bitwarden, Xcode CLT, Apps"
    echo ""
    echo "  2) Select components"
    echo "     - Choose which components to remove"
    echo ""
    echo "  3) Complete reset"
    echo "     - Removes everything (full factory reset)"
    echo ""
    read -p "Enter choice [1-3] (default: 1): " CHOICE
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
            RESET_APPS=true
            RESET_WM=true
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

    read -p "  Dotfiles & chezmoi config? [Y/n]: " ans
    [[ ! "$ans" =~ ^[Nn]$ ]] && RESET_DOTFILES=true

    read -p "  Installed Apps (Ghostty, Discord, Spotify, etc.)? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_APPS=true

    read -p "  Window Manager (Aerospace, SketchyBar, JankyBorders)? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_WM=true

    read -p "  Tailscale? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_TAILSCALE=true

    read -p "  Bitwarden CLI? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_BITWARDEN=true

    read -p "  Homebrew & all packages? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_HOMEBREW=true

    read -p "  Xcode Command Line Tools? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && RESET_XCODE=true
}

# Default flags
RESET_DOTFILES=false
RESET_APPS=false
RESET_WM=false
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
        --apps)
            RESET_APPS=true
            shift
            ;;
        --wm)
            RESET_WM=true
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
            RESET_APPS=true
            RESET_WM=true
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
if ! $RESET_DOTFILES && ! $RESET_APPS && ! $RESET_WM && ! $RESET_TAILSCALE && ! $RESET_BITWARDEN && ! $RESET_HOMEBREW && ! $RESET_XCODE; then
    echo -e "${YELLOW}Nothing selected to remove.${NC}"
    exit 0
fi

# Confirm
echo ""
echo -e "${YELLOW}This will remove:${NC}"
$RESET_DOTFILES && echo "  - Chezmoi source, config, and applied dotfiles"
$RESET_APPS && echo "  - Installed Apps (Ghostty, Discord, Spotify, Arc, Obsidian, etc.)"
$RESET_WM && echo "  - Window Manager (Aerospace, SketchyBar, JankyBorders)"
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

# Reset Apps (before homebrew so we can use brew to uninstall)
if $RESET_APPS; then
    echo -e "${YELLOW}→${NC} Removing all brew-installed applications..."

    # Apps controlled by other flags - skip unless those flags are also set
    SKIP_CASKS=""
    SKIP_FORMULAE=""
    if ! $RESET_TAILSCALE; then
        SKIP_CASKS="$SKIP_CASKS tailscale"
    fi
    if ! $RESET_BITWARDEN; then
        SKIP_FORMULAE="$SKIP_FORMULAE bitwarden-cli"
    fi

    if command -v brew &>/dev/null; then
        # Get all installed casks and uninstall them
        INSTALLED_CASKS=$(brew list --cask 2>/dev/null)
        if [ -n "$INSTALLED_CASKS" ]; then
            echo "  Removing cask apps..."
            for cask in $INSTALLED_CASKS; do
                # Skip if in exclusion list
                if echo "$SKIP_CASKS" | grep -qw "$cask"; then
                    echo "    Skipping $cask (controlled by separate flag)"
                    continue
                fi
                echo "    Removing $cask..."
                # Use --force to handle running apps, --zap to remove all associated files, --ignore-dependencies to skip dependency checks
                brew uninstall --cask --force --zap --ignore-dependencies "$cask" 2>&1 || echo "      Warning: failed to fully remove $cask"
            done
        fi

        # Get all installed formulae and uninstall them
        INSTALLED_FORMULAE=$(brew list --formula 2>/dev/null)
        if [ -n "$INSTALLED_FORMULAE" ]; then
            echo "  Removing CLI tools..."
            for formula in $INSTALLED_FORMULAE; do
                # Skip if in exclusion list
                if echo "$SKIP_FORMULAE" | grep -qw "$formula"; then
                    echo "    Skipping $formula (controlled by separate flag)"
                    continue
                fi
                echo "    Removing $formula..."
                brew uninstall --force --ignore-dependencies "$formula" 2>&1 || echo "      Warning: failed to remove $formula"
            done
        fi

        # Clean up orphaned dependencies and cache
        echo "  Cleaning up..."
        brew autoremove 2>/dev/null || true
        brew cleanup --prune=all 2>/dev/null || true
    else
        echo "  Homebrew not found, skipping brew uninstalls"
    fi

    # Remove all apps from /Applications except macOS defaults and flag-controlled apps
    echo "  Removing apps from /Applications..."

    # Default macOS apps to always keep (factory reset state)
    DEFAULT_APPS=(
        "App Store.app"
        "Automator.app"
        "Books.app"
        "Calculator.app"
        "Calendar.app"
        "Chess.app"
        "Clock.app"
        "Contacts.app"
        "Dictionary.app"
        "FaceTime.app"
        "Finder.app"
        "Font Book.app"
        "Freeform.app"
        "Home.app"
        "Image Capture.app"
        "Keynote.app"
        "Launchpad.app"
        "Mail.app"
        "Maps.app"
        "Messages.app"
        "Migration Assistant.app"
        "Music.app"
        "News.app"
        "Notes.app"
        "Numbers.app"
        "Pages.app"
        "Passwords.app"
        "Photo Booth.app"
        "Photos.app"
        "Podcasts.app"
        "Preview.app"
        "QuickTime Player.app"
        "Reminders.app"
        "Safari.app"
        "Shortcuts.app"
        "Siri.app"
        "Stickies.app"
        "Stocks.app"
        "System Preferences.app"
        "System Settings.app"
        "TextEdit.app"
        "Time Machine.app"
        "TV.app"
        "Utilities"
        "VoiceMemos.app"
        "Weather.app"
    )

    # Apps controlled by other flags
    SKIP_APPS=()
    if ! $RESET_TAILSCALE; then
        SKIP_APPS+=("Tailscale.app")
    fi

    for app in /Applications/*.app /Applications/Utilities/*.app; do
        [ -d "$app" ] || continue
        app_name=$(basename "$app")

        # Skip default macOS apps
        skip=false
        for default_app in "${DEFAULT_APPS[@]}"; do
            if [ "$app_name" = "$default_app" ]; then
                skip=true
                break
            fi
        done
        if $skip; then
            continue
        fi

        # Skip apps controlled by other flags
        for skip_app in "${SKIP_APPS[@]}"; do
            if [ "$app_name" = "$skip_app" ]; then
                echo "    Skipping $app_name (controlled by separate flag)"
                skip=true
                break
            fi
        done
        if $skip; then
            continue
        fi

        echo "    Removing $app_name..."
        rm -rf "$app" 2>/dev/null || sudo rm -rf "$app" 2>/dev/null || echo "      Warning: failed to remove $app_name"
    done

    # Remove managed fonts from ~/Library/Fonts
    echo "  Removing managed fonts..."
    MANAGED_FONTS=(
        "HackNerdFont*.ttf"
        "HackNerdFontMono*.ttf"
        "HackNerdFontPropo*.ttf"
        "JetBrainsMonoNerdFont*.ttf"
        "JetBrainsMonoNLNerdFont*.ttf"
        "CascadiaCode*.ttf"
        "CascadiaMono*.ttf"
        "sketchybar-app-font.ttf"
    )
    for font_pattern in "${MANAGED_FONTS[@]}"; do
        for font in ~/Library/Fonts/$font_pattern; do
            [ -e "$font" ] || continue
            echo "    Removing $font..."
            rm -f "$font" 2>/dev/null || echo "      Warning: failed to remove $font"
        done
    done

    echo -e "${GREEN}✓${NC} Applications removed"
fi

# Reset Window Manager (before dotfiles so configs are still accessible)
if $RESET_WM; then
    echo -e "${YELLOW}→${NC} Removing Window Manager tools..."

    # Stop and remove Aerospace
    if pgrep -x "AeroSpace" &>/dev/null; then
        killall AeroSpace 2>/dev/null || true
    fi
    if command -v brew &>/dev/null; then
        brew uninstall --cask aerospace 2>/dev/null || true
    fi
    rm -rf ~/.aerospace.toml
    rm -rf ~/.config/aerospace-monitor

    # Stop and remove SketchyBar
    if pgrep -x "sketchybar" &>/dev/null; then
        brew services stop sketchybar 2>/dev/null || true
        killall sketchybar 2>/dev/null || true
    fi
    if command -v brew &>/dev/null; then
        brew uninstall sketchybar 2>/dev/null || true
    fi
    rm -rf ~/.config/sketchybar
    rm -rf ~/.local/share/sketchybar_lua

    # Remove JankyBorders
    if pgrep -x "borders" &>/dev/null; then
        killall borders 2>/dev/null || true
    fi
    if command -v brew &>/dev/null; then
        brew uninstall borders 2>/dev/null || true
    fi

    # Unhide the macOS menu bar
    osascript -e 'tell application "System Events" to tell dock preferences to set autohide menu bar to false' 2>/dev/null || true

    # Show the Dock again
    defaults write com.apple.dock autohide -bool false
    killall Dock 2>/dev/null || true

    echo -e "${GREEN}✓${NC} Window Manager tools removed"
fi

# Reset dotfiles
if $RESET_DOTFILES; then
    echo -e "${YELLOW}→${NC} Removing dotfiles and chezmoi config..."
    rm -rf ~/.local/share/chezmoi
    rm -rf ~/.config
    rm -rf ~/.local/bin
    rm -rf ~/.zshrc ~/.bashrc ~/.gitconfig ~/.zprofile ~/.zshenv
    rm -rf ~/.bootstrap
    rm -rf ~/bin/chezmoi
    rm -rf ~/.chezmoi.toml

    # Reset shell back to bash
    if [ "$SHELL" != "/bin/bash" ]; then
        echo -e "${YELLOW}→${NC} Resetting shell to bash..."
        chsh -s /bin/bash 2>/dev/null || true
    fi

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
    # Remove app manually if still present (requires sudo for protected files)
    if [ -d "/Applications/Tailscale.app" ]; then
        echo -e "${YELLOW}  Removing /Applications/Tailscale.app (requires password)...${NC}"
        sudo rm -rf /Applications/Tailscale.app
    fi
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
    rm -rf ~/.config/"Bitwarden CLI"
    rm -rf ~/Library/Application\ Support/Bitwarden\ CLI
    echo -e "${GREEN}✓${NC} Bitwarden CLI removed"
fi

# Reset Homebrew
if $RESET_HOMEBREW; then
    echo -e "${YELLOW}→${NC} Removing Homebrew (this may take a while)..."
    if command -v brew &>/dev/null; then
        # Homebrew uninstaller needs TTY for prompts
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    else
        echo "  Homebrew not found, skipping"
    fi
    echo -e "${GREEN}✓${NC} Homebrew removed"
fi

# Reset Xcode CLT
if $RESET_XCODE; then
    echo -e "${YELLOW}→${NC} Removing Xcode Command Line Tools..."
    if [ -d "/Library/Developer/CommandLineTools" ]; then
        echo -e "${YELLOW}  Requires password to remove system directory...${NC}"
        sudo rm -rf /Library/Developer/CommandLineTools
        echo -e "${GREEN}✓${NC} Xcode Command Line Tools removed"
    else
        echo "  Xcode Command Line Tools not found, skipping"
    fi
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}   ✓ Reset Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "You can now re-run the bootstrap:"
echo "  curl -fsSL https://raw.githubusercontent.com/ianyimi/dotfiles/master/bootstrap.sh -o /tmp/bootstrap.sh && bash /tmp/bootstrap.sh && rm /tmp/bootstrap.sh"
echo ""
