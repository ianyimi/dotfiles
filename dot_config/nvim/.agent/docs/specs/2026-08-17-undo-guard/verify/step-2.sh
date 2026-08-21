#!/usr/bin/env bash
# Step 2 verification — instance advertising + :UndoGuardHold delegation.
#
# Two halves:
#   1. Module behaviour (advertise / unadvertise / dead-pid pruning) exercised directly with
#      an isolated $TMPDIR, so the real $TMPDIR/nvim-undo is never touched.
#   2. Static checks on lua/config/autocmds.lua: the glue is present and the file still parses.
#      The glue is 6 lines of autocmd wiring whose live behaviour can only be observed after
#      `chezmoi apply` deploys the config; the logic it calls is covered by half 1.
set -euo pipefail
cd "$(dirname "$0")/../../../../.."   # repo root (dot_config/nvim)

d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
mkdir -p "$d/lua/util"
cp lua/util/undo.lua "$d/lua/util/undo.lua"

cat > "$d/check.lua" <<LUA
vim.env.TMPDIR = "$d/tmp"
package.path = "$d/lua/?.lua;" .. package.path
local undo = require("util.undo")

-- advertise(): writes \$TMPDIR/nvim-undo/<pid>, line 1 cwd, line 2 v:servername.
local path = undo.advertise()
assert(path ~= nil, "advertise returned nil (v:servername empty?)")
assert(path == "$d/tmp/nvim-undo/" .. vim.fn.getpid(), "unexpected advertise path: " .. path)
local lines = vim.fn.readfile(path)
assert(#lines == 2, "expected exactly 2 lines, got " .. #lines)
assert(lines[1] == (vim.uv.cwd() or ""), "line 1 should be cwd, got [" .. lines[1] .. "]")
assert(lines[2] == vim.v.servername, "line 2 should be servername, got [" .. lines[2] .. "]")
print("PASS: advertise wrote cwd + servername")

-- prune_dead runs on every advertise(): a dead pid's file goes, a live one stays.
local dir = "$d/tmp/nvim-undo"
vim.fn.writefile({ "/nowhere", "/dead.sock" }, dir .. "/999999")
undo.advertise()
assert(vim.fn.filereadable(dir .. "/999999") == 0, "dead-pid advertise file should be pruned")
assert(vim.fn.filereadable(path) == 1, "live instance's own file must survive pruning")
print("PASS: dead-pid files pruned, live file kept")

-- unadvertise(): removes it, and is safe to call twice.
undo.unadvertise()
assert(vim.fn.filereadable(path) == 0, "unadvertise should remove the file")
undo.unadvertise()
print("PASS: unadvertise removed the file and is idempotent")
vim.cmd("qa!")
LUA

nvim --headless -u NONE -i NONE --listen "$d/sock" -c "luafile $d/check.lua" -c "qa!"

# Half 2: the wiring in autocmds.lua.
f=lua/config/autocmds.lua
grep -q 'augroup("undo_guard_advertise")' "$f" || { echo "FAIL: advertise augroup missing"; exit 1; }
grep -q 'LazyVim.undo.advertise()' "$f"       || { echo "FAIL: VimEnter advertise call missing"; exit 1; }
grep -q 'LazyVim.undo.unadvertise()' "$f"     || { echo "FAIL: VimLeavePre cleanup missing"; exit 1; }
grep -q 'pcall(LazyVim.undo.hold, opts.args)' "$f" || { echo "FAIL: command does not delegate"; exit 1; }
# The old leaking implementation must be gone.
grep -q 'vim.o.eventignore = "all"' "$f" && { echo "FAIL: inline eventignore juggling still present"; exit 1; }
nvim --headless -u NONE -i NONE \
  -c "lua local _, e = loadfile('$f'); if e then print('FAIL: ' .. e) vim.cmd('cq') end" -c "qa!"

# augroup() passes clear = true, so calling it twice for one name deletes the first
# registration. Registering VimEnter and VimLeavePre through two separate augroup() calls
# silently left only VimLeavePre alive, and the advertise file was never written.
n=$(grep -c 'augroup("undo_guard_advertise")' "$f")
[ "$n" -eq 1 ] || { echo "FAIL: augroup(\"undo_guard_advertise\") called $n times; create it once and reuse the id"; exit 1; }
echo "PASS: autocmds.lua wiring present, old leaking body gone, augroup created once, file parses"

# Live check, only meaningful when the deployed copy matches this source (post chezmoi apply):
# both events must actually be registered in the running instance.
DEPLOYED=$HOME/.config/nvim/lua/config/autocmds.lua
if [ -f "$DEPLOYED" ] && diff -q "$f" "$DEPLOYED" >/dev/null 2>&1; then
  p=$(mktemp -d); printf 'x\n' > "$p/a.txt"
  (cd "$p" && nvim --headless --listen "$p/s.sock" a.txt >/dev/null 2>&1 &)
  for _ in $(seq 1 100); do [ -S "$p/s.sock" ] && break; sleep 0.1; done
  sleep 2
  events=$(nvim --server "$p/s.sock" --remote-expr \
    'luaeval("table.concat(vim.tbl_map(function(a) return a.event end, vim.api.nvim_get_autocmds({group = \"lazyvim_undo_guard_advertise\"})), \",\")")' 2>/dev/null)
  pkill -f "$p/s.sock" 2>/dev/null; rm -rf "$p"
  case "$events" in
    *VimEnter*) case "$events" in
                  *VimLeavePre*) echo "PASS: live instance has both VimEnter and VimLeavePre registered" ;;
                  *) echo "FAIL: live group lost VimLeavePre (events: $events)"; exit 1 ;;
                esac ;;
    *) echo "FAIL: live group is missing VimEnter (events: $events) — the advertise file will never be written"; exit 1 ;;
  esac
else
  echo "NOTE: deployed autocmds.lua differs from source — run 'chezmoi apply', then re-run for the live check"
fi
echo "Step 2: OK"
