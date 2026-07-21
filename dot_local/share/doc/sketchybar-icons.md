# SketchyBar Custom Icons Guide

## Overview

Custom icons for SketchyBar are managed through the `sketchybar-app-font` repository located at `~/packages/sketchybar-app-font/`.

## Current Custom Icons

- **Helium Browser** - Added for Helium browsing app
- **djay Pro** - Added for djay Pro DJ software

## Adding New Icons

### Method 1: Using the Helper Script (Recommended)

```bash
sketchybar-add-icon.sh "App Name" /path/to/icon.svg
```

Or with inline SVG:

```bash
sketchybar-add-icon.sh "App Name" '<svg>...</svg>'
```

### Method 2: Manual Process

1. **Create SVG Icon**
   - Icon should be 24x24 viewbox
   - Use simple, minimalist design
   - Place in `~/packages/sketchybar-app-font/svgs/:iconname:.svg`

2. **Create Mapping File**
   - File: `~/packages/sketchybar-app-font/mappings/:iconname:`
   - Content: Just the app name(s), one per line
   ```
   "Exact App Name"
   "Alternate Name"
   ```

3. **Get the exact app name:**
   ```bash
   osascript -e 'id of app "AppName"'
   ```

4. **Rebuild Font**
   ```bash
   cd ~/packages/sketchybar-app-font
   pnpm run build:install "$HOME/.config/sketchybar/scripts/my-script.sh"
   ```

5. **Install Updated Files**
   ```bash
   cp ~/packages/sketchybar-app-font/dist/sketchybar-app-font.ttf ~/Library/Fonts/
   cp ~/packages/sketchybar-app-font/dist/icon_map.lua ~/.config/sketchybar/helpers/app_icons.lua
   brew services restart sketchybar
   ```

## Automatic Updates

The Ansible playbook (`~/.bootstrap/macos.yml`) now includes automatic restart logic:

- **SketchyBar**: Automatically restarted after updates
- **Aerospace**: Automatically restarted after updates with version compatibility check

This prevents version mismatch errors like the one you experienced.

## Troubleshooting

### Icons Not Showing
1. Check if app is running: `aerospace list-workspaces --focused`
2. Verify icon exists: `ls ~/packages/sketchybar-app-font/svgs/ | grep appname`
3. Check SketchyBar logs: `log show --predicate 'subsystem == "com.felixkratz.sketchybar"' --last 5m`

### After Installing/Updating SketchyBar or Aerospace
```bash
# Restart Aerospace
killall AeroSpace && sleep 1 && open -a AeroSpace

# Restart SketchyBar
brew services restart sketchybar
```

## Resources

- [SketchyBar App Font Repo](https://github.com/kvndrsslr/sketchybar-app-font)
- [Simple Icons](https://simpleicons.org/) - Icon library for inspiration
- [Dashboard Icons](https://dashboardicons.com/) - Another icon source
