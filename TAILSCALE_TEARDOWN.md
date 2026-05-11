# Tailscale Teardown — Removing the Standalone (macsys) Install

Use this when rolling back from `tailscale-app` (the standalone/macsys variant)
so you can reinstall the brew formula `tailscale` for `tailscale ssh` server
support. Run the commands in order. Each section is annotated; stop and
verify between sections if anything looks off.

> Why this exists: The standalone variant uses a sandboxed System Extension,
> which silently disables the `tailscale ssh` *server* (you can still be a
> client). Only the open-source `tailscaled` formula can be an SSH server on
> macOS. See `.pi/agent-docs/implementation-log/2026/05/2026-05-10.ideaLog.md`
> and https://tailscale.com/kb/1065/macos-variants.

## 1. Quit the GUI app and the user-space process

```bash
osascript -e 'quit app "Tailscale"' 2>/dev/null || true
pkill -x Tailscale || true
```

## 2. Uninstall the cask

Runs the cask's built-in uninstaller and tries to deactivate the System
Extension automatically.

```bash
brew uninstall --cask tailscale-app
```

## 3. Deactivate / remove the System Extension if still present

Check first:

```bash
systemextensionsctl list
```

If you see `io.tailscale.ipn.macsys.network-extension`, deactivate it:

```bash
# Pops a System Settings prompt requiring confirm + Touch ID / password
systemextensionsctl uninstall W5364U7YZB io.tailscale.ipn.macsys.network-extension
```

(`W5364U7YZB` is Tailscale's Team ID, confirmed via `codesign -dv`.)

If `systemextensionsctl uninstall` complains that SIP must be disabled, just
delete the on-disk extension and let the next reboot reap it:

```bash
sudo rm -rf /Library/SystemExtensions/*/io.tailscale.ipn.macsys.network-extension.systemextension
```

## 4. Forget the pkgutil receipt

```bash
sudo pkgutil --forget com.tailscale.ipn.macsys 2>/dev/null || true
sudo pkgutil --forget io.tailscale.ipn.macsys  2>/dev/null || true
```

## 5. Remove the app bundle and the macsys CLI wrapper

```bash
sudo rm -rf /Applications/Tailscale.app
sudo rm -f  /usr/local/bin/tailscale
```

## 6. Remove macsys user data

```bash
rm -rf ~/Library/Containers/io.tailscale.ipn.macsys
rm -rf ~/Library/Group\ Containers/*.io.tailscale.ipn.macsys 2>/dev/null
rm -rf ~/Library/Caches/io.tailscale.ipn.macsys
rm -rf ~/Library/Application\ Support/Tailscale
rm -rf ~/Library/Preferences/io.tailscale.ipn.macsys.plist
```

## 7. Remove the GUI's auto-registered LaunchAgent

```bash
launchctl bootout "gui/$(id -u)/io.tailscale.ipn.macsys.login-item-helper" 2>/dev/null || true
rm -f ~/Library/LaunchAgents/io.tailscale.ipn.macsys.login-item-helper.plist
```

## 8. Also fully reset the formula daemon (we'll reinstall clean)

```bash
sudo brew services stop tailscale 2>/dev/null || true
sudo pkill -x tailscaled           2>/dev/null || true
brew uninstall tailscale           2>/dev/null || true
sudo rm -rf /opt/homebrew/var/lib/tailscale
sudo rm -f  /etc/resolver/*.tailscale
sudo rm -f  /etc/resolver/tail68d30.ts.net 2>/dev/null
```

## 9. Sanity check — everything below should print `(none)`

```bash
echo "--- brew ---";          brew list | grep -i tail || echo "  (none)"
echo "--- pkgutil ---";       pkgutil --pkgs | grep -i tail || echo "  (none)"
echo "--- /Applications ---"; ls /Applications | grep -i Tail || echo "  (none)"
echo "--- system ext ---";    systemextensionsctl list | grep -i tail || echo "  (none)"
echo "--- processes ---";     ps -Ao comm | grep -i tail || echo "  (none)"
echo "--- bins ---";          ls /usr/local/bin/tailscale /opt/homebrew/bin/tailscale 2>/dev/null || echo "  (none)"
echo "--- resolver ---";      ls /etc/resolver/ 2>/dev/null
echo "--- launchdaemons ---"; ls /Library/LaunchDaemons/ | grep -i tail || echo "  (none)"
```

(`/etc/resolver/` may still exist as an empty directory — that's fine.)

## After teardown

Next, `reinstall-tailscale` will be rewritten to:

1. `brew install tailscale` (formula — gives back SSH server).
2. `sudo brew services start tailscale`.
3. Prompt you to `sudo tailscale up --ssh`.
4. Auto-detect `MagicDNSSuffix` from `tailscale status --json` and write
   `/etc/resolver/<suffix>` with `nameserver 100.100.100.100` (the missing
   piece the formula refuses to create — this is what makes MagicDNS
   actually work for libresolv / `bw` / `cma`).
5. Flush DNS cache.
