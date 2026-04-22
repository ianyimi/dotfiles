# Pi-Vim + Pi-Powerline-Footer - SOLVED! 🎉

## The Solution

**Forked `pi-powerline-footer` to make it vim-compatible!**

Fork: https://github.com/ianyimi/pi-powerline-footer

### What Changed

Modified `bash-mode/editor.ts` to conditionally extend `ModalEditor` when `pi-vim` is detected:

```typescript
// Try to import ModalEditor from pi-vim
let BaseEditor: typeof CustomEditor = CustomEditor;
try {
  const piVim = await import("pi-vim");
  if (piVim?.ModalEditor) {
    BaseEditor = piVim.ModalEditor;
    console.log("[pi-powerline-footer] Using ModalEditor from pi-vim - vim keybindings enabled!");
  }
} catch (error) {
  // pi-vim not installed, use CustomEditor
}

export class BashModeEditor extends BaseEditor {
  // Now inherits vim modal editing when available!
}
```

### What You Get Now

✅ **Full powerline status bar** - Model, path, git branch, context usage, token count  
✅ **Vim modal editing** - hjkl navigation, dd/yy/p, visual mode, text objects  
✅ **Vim mode indicator** - Shows "NORMAL" or "INSERT" at bottom right  
✅ **Bash mode** - Powerline's sticky bash session with ghost suggestions  
✅ **All powerline features** - Working vibes, welcome overlay, stash, etc.

**You get EVERYTHING from both packages!**

---

## Installation

### From Your Dotfiles (Automated)

The Ansible playbook (`dot_bootstrap/macos.yml`) now installs:

```yaml
- name: Install Pi Coding Agent
  community.general.homebrew:
    name: pi-coding-agent
    state: latest

- name: Install Pi Vim extension
  ansible.builtin.shell: pi install npm:pi-vim

- name: Install Pi Powerline Footer extension (vim-compatible fork)
  ansible.builtin.shell: pi install git:https://github.com/ianyimi/pi-powerline-footer
```

### Manual Installation

```bash
# Install pi-vim first
pi install npm:pi-vim

# Install your vim-compatible fork of powerline
pi install git:https://github.com/ianyimi/pi-powerline-footer

# Restart Pi
pi
```

**Load order doesn't matter** - powerline auto-detects vim and extends it!

---

## How It Works

1. Pi loads `pi-vim` → registers `ModalEditor`
2. Pi loads `pi-powerline-footer` (fork) → detects `ModalEditor` is available
3. `BashModeEditor` extends `ModalEditor` instead of `CustomEditor`
4. Result: **Powerline UI + Vim keybindings in one editor**

The fork gracefully falls back to `CustomEditor` if `pi-vim` is not installed, so it works standalone too.

---

## Testing

Start Pi and verify both work:

```bash
pi
```

You should see:
- **Powerline status bar at top** with model, git branch, context %
- **Vim keybindings work**: Press `Esc` → `hjkl` → `dd` to test
- **Vim mode shows**: Bottom right displays "NORMAL" or "INSERT"
- **Powerline welcome overlay** (if `quietStartup: false`)

Try bash mode: `/bash-mode` or `Ctrl+Shift+B`

---

## Files Modified

**Fork repo:**
- `bash-mode/editor.ts` - Conditional ModalEditor extension
- `package.json` - Added pi-vim as optional peer dependency, updated version to `0.4.16-vim-compat`
- `README.md` - Added vim compatibility documentation

**Dotfiles:**
- `dot_bootstrap/macos.yml` - Install from GitHub fork instead of npm
- `pi-agent-base/settings.json` - Use `git:https://github.com/ianyimi/pi-powerline-footer`
- `~/.pi/agent/settings.json` - Same

---

## Publishing to npm (Optional)

You don't need to publish to npm - Pi can install directly from GitHub!

But if you want to publish:

```bash
cd /path/to/pi-powerline-footer
npm login
npm publish
```

Then you could use:
```bash
pi install npm:@yourusername/pi-powerline-footer
```

---

## Submitting Upstream PR

Consider submitting a PR to the original repo:
https://github.com/nicobailon/pi-powerline-footer

This change benefits the entire Pi community by making powerline vim-compatible out of the box.

**PR title:** "feat: add vim compatibility - extend ModalEditor when pi-vim is detected"

The maintainer might merge it into the official package!

---

## Maintenance

Your fork at `https://github.com/ianyimi/pi-powerline-footer` is now the source for your dotfiles.

**To update:**
1. Pull latest from upstream: `git remote add upstream https://github.com/nicobailon/pi-powerline-footer.git && git pull upstream main`
2. Resolve conflicts (your vim-compat changes)
3. Push to your fork
4. Run `pi update` to reinstall from GitHub

**To sync with upstream changes:**
```bash
cd ~/.pi/agent/git/github.com/ianyimi/pi-powerline-footer
git pull
```

Pi will use the updated version on next restart.
