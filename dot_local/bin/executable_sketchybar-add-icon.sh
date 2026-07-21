#!/usr/bin/env bash
# Add a custom icon to sketchybar-app-font
# Usage: sketchybar-add-icon.sh <app-name> <svg-content-or-file>

set -e

APP_NAME="$1"
SVG_INPUT="$2"

if [ -z "$APP_NAME" ] || [ -z "$SVG_INPUT" ]; then
    echo "Usage: $0 <app-name> <svg-content-or-file>"
    echo ""
    echo "Example:"
    echo "  $0 'My App' /path/to/icon.svg"
    echo "  $0 'My App' '<svg>...</svg>'"
    exit 1
fi

FONT_DIR="$HOME/packages/sketchybar-app-font"
ICON_SLUG=":${APP_NAME,,}:"  # Convert to lowercase
ICON_SLUG="${ICON_SLUG// /_}"  # Replace spaces with underscores

if [ ! -d "$FONT_DIR" ]; then
    echo "Error: sketchybar-app-font directory not found at $FONT_DIR"
    exit 1
fi

# Handle SVG input
if [ -f "$SVG_INPUT" ]; then
    cp "$SVG_INPUT" "$FONT_DIR/svgs/${ICON_SLUG}.svg"
    echo "✓ Copied SVG from file"
else
    echo "$SVG_INPUT" > "$FONT_DIR/svgs/${ICON_SLUG}.svg"
    echo "✓ Created SVG from content"
fi

# Create mapping
echo "\"$APP_NAME\"" > "$FONT_DIR/mappings/${ICON_SLUG}"
echo "✓ Created mapping for '$APP_NAME'"

# Rebuild font
echo "Building font..."
cd "$FONT_DIR"
pnpm run build:install "$HOME/.config/sketchybar/scripts/my-script.sh"

# Install font
cp "$FONT_DIR/dist/sketchybar-app-font.ttf" "$HOME/Library/Fonts/"
echo "✓ Font installed"

# Update icon map
cp "$FONT_DIR/dist/icon_map.lua" "$HOME/.config/sketchybar/helpers/app_icons.lua"
echo "✓ Icon map updated"

# Restart sketchybar
brew services restart sketchybar
echo "✓ SketchyBar restarted"

echo ""
echo "Icon '$APP_NAME' successfully added!"
echo "Icon slug: $ICON_SLUG"
