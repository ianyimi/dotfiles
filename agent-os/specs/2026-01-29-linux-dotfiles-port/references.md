# Linux Dotfiles Port - References

## Existing macOS Configurations

### Aerospace (Window Manager)
- Config: `dot_aerospace.toml`
- Key features:
  - ALT-based keybindings
  - Named workspaces (1-9, A-Y)
  - Window rules for app assignment
  - Service mode for special operations
  - Integration with SketchyBar

### SketchyBar (Status Bar)
- Config: `dot_config/sketchybar/`
- Key files:
  - `colors.lua` - Color scheme
  - `bar.lua` - Bar configuration
  - `items/spaces.lua` - Workspace display
  - `items/widgets/` - System stats (CPU, RAM, battery, etc.)

### Bootstrap
- Main script: `bootstrap.sh`
- macOS playbook: `dot_bootstrap/macos.yml`
- Run-once scripts: `run_once_before_*.sh.tmpl`

## Linux Component Documentation

### Hyprland
- Wiki: https://wiki.hyprland.org/
- Config reference: https://wiki.hyprland.org/Configuring/Configuring-Hyprland/
- Keybinds: https://wiki.hyprland.org/Configuring/Binds/
- Window rules: https://wiki.hyprland.org/Configuring/Window-Rules/

### Waybar
- GitHub: https://github.com/Alexays/Waybar
- Wiki: https://github.com/Alexays/Waybar/wiki
- Styling: https://github.com/Alexays/Waybar/wiki/Styling

### Rofi
- GitHub: https://github.com/davatorium/rofi
- Themes: https://github.com/davatorium/rofi-themes

### Dunst
- GitHub: https://github.com/dunst-project/dunst
- Config: https://dunst-project.org/documentation/

## Color Scheme Reference

From `dot_config/sketchybar/colors.lua`:

```lua
black = 0xff181819
white = 0xffe2e2e3
red = 0xfffc5d7c
green = 0xff9ed072
blue = 0xff76cce0
yellow = 0xffe7c664
orange = 0xfff39660
magenta = 0xffb39df3
grey = 0xff7f8490

bar.bg = 0xf02c2e34
bar.border = 0xff2c2e34
popup.bg = 0xc02c2e34
popup.border = 0xff7f8490
bg1 = 0xff363944
bg2 = 0xff414550
```

Converted to CSS hex:
- Black: #181819
- White: #e2e2e3
- Red: #fc5d7c
- Green: #9ed072
- Blue: #76cce0
- Yellow: #e7c664
- Orange: #f39660
- Magenta: #b39df3
- Grey: #7f8490
- Bar BG: #2c2e34
- BG1: #363944
- BG2: #414550

## Package Installation Commands

### Hyprland (Ubuntu)
```bash
sudo add-apt-repository ppa:hyprwm/hyprland
sudo apt update
sudo apt install hyprland
```

### GitHub CLI
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### NodeSource (Node.js)
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
```

### Starship
```bash
curl -sS https://starship.rs/install.sh | sh
```

### Flatpak (for Zen Browser)
```bash
sudo apt install flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub io.github.nickvision.money
```

### Snap packages
```bash
sudo snap install spotify
sudo snap install discord
sudo snap install slack --classic
sudo snap install obsidian --classic
```
