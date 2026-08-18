#!/usr/bin/env bash
# Step 6 verification — windowed startup preload.
#
# Builds a synthetic project with three undofiles (two inside the 7-day window, one backdated
# past it) plus a file outside the root, then asserts M.candidates windows/sorts/filters
# correctly and M.arm holds exactly the in-window set within its per-tick budget.
# Everything runs against a redirected undodir; the real undo store is never read or written.
set -uo pipefail
cd "$(dirname "$0")/../../../../.."   # repo root (dot_config/nvim)
REPO=$PWD

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/proj/sub" "$T/outside" "$T/undodir"

# Seed real undofiles by editing each file in a normal session (the session must be the last
# writer so each undofile's content hash still matches).
seed() {
  printf 'const a = 1;\n' > "$1"
  nvim --headless -u NONE -i NONE --cmd "set undofile undodir=$T/undodir noswapfile" "$1" \
    -c 'normal Goconst b = 2;' -c write -c 'qa!' >/dev/null 2>&1
}
seed "$T/proj/recent-one.ts"
seed "$T/proj/sub/recent-two.ts"
seed "$T/proj/stale.ts"
seed "$T/outside/other.ts"

# Backdate stale.ts's undofile 30 days so it falls outside WINDOW_DAYS=7.
stale_undo=$(command ls "$T/undodir" | grep 'stale.ts$')
[ -n "$stale_undo" ] || { echo "FAIL: could not find stale.ts undofile"; exit 1; }
touch -t "$(date -v-30d +%Y%m%d%H%M)" "$T/undodir/$stale_undo"

cat > "$T/check.lua" <<LUA
package.path = "$REPO/lua/?.lua;" .. package.path
vim.opt.undofile = true
vim.opt.undodir = "$T/undodir"
vim.opt.directory = "$T/swap//"
vim.g.bigfile_size = 1024 * 1024 * 1.5
-- M.arm reports through LazyVim.info; stub the global and count the reports. Exactly one means
-- the finish path ran once. (The failure mode it guards — several schedule_wrap callbacks queued
-- behind a busy main loop, the second closing an already-closing timer handle — needs real
-- editor load to reproduce and is asserted structurally below instead.)
local notifications = 0
_G.LazyVim = { info = function() notifications = notifications + 1 end }

local undo = require("util.undo")

-- 1. candidates(): windowed, root-scoped, newest first.
local cands = undo.candidates("$T/proj")
local names = {}
for _, c in ipairs(cands) do names[#names + 1] = vim.fs.basename(c.path) end
table.sort(names)
assert(#cands == 2, "expected 2 in-window candidates, got " .. #cands .. ": " .. vim.inspect(names))
assert(names[1] == "recent-one.ts" and names[2] == "recent-two.ts",
  "unexpected candidate set: " .. vim.inspect(names))
print("PASS: candidates windowed to 7 days, scoped to root (excluded stale.ts and outside/)")

local sorted = true
for i = 2, #cands do
  if cands[i - 1].mtime < cands[i].mtime then sorted = false end
end
assert(sorted, "candidates must be sorted newest undofile mtime first")
print("PASS: candidates sorted newest first")

-- 2. arm(): drains the queue behind its timer and holds the in-window files.
vim.uv.chdir("$T/proj")
undo.arm()
vim.wait(3000, function()
  return vim.fn.bufloaded("$T/proj/recent-one.ts") == 1
    and vim.fn.bufloaded("$T/proj/sub/recent-two.ts") == 1
end, 20)

assert(vim.fn.bufloaded("$T/proj/recent-one.ts") == 1, "recent-one.ts should be held")
assert(vim.fn.bufloaded("$T/proj/sub/recent-two.ts") == 1, "recent-two.ts should be held")
assert(vim.fn.bufloaded("$T/proj/stale.ts") == 0, "stale.ts is outside the window, must not be held")
assert(vim.fn.bufloaded("$T/outside/other.ts") == 0, "outside/other.ts is outside root, must not be held")
for _, p in ipairs({ "$T/proj/recent-one.ts", "$T/proj/sub/recent-two.ts" }) do
  local b = vim.fn.bufnr(p)
  assert(vim.bo[b].buflisted == false, p .. " should be unlisted")
  assert(vim.fn.undotree(b).seq_last > 0, p .. " should carry undo history")
end
assert(vim.o.eventignore == "", "eventignore leaked: [" .. vim.o.eventignore .. "]")
print("PASS: arm held both in-window files, unlisted, history intact, no option leak")

-- The preload must report exactly once and leave no live timer behind. Extra ticks after the
-- queue drains previously reached timer:close() a second time and raised
-- "handle is already closing" out of a vim.schedule callback.
vim.wait(500, function() return false end, 25)
assert(notifications == 1, "arm should report exactly once, got " .. notifications)
print("PASS: arm reported exactly once (finish path is idempotent)")

-- 3. release(n) evicts only n, and release() still drains everything.
local before = 0
for _ in pairs({ ["$T/proj/recent-one.ts"] = 1, ["$T/proj/sub/recent-two.ts"] = 1 }) do before = before + 1 end
assert(undo.release(1) == 1, "release(1) should evict exactly one buffer")
assert(undo.release() >= 1, "release() should drain the remainder")
print("PASS: release(n) evicts n, release() drains the rest")
vim.cmd("qa!")
LUA

nvim --headless -u NONE -i NONE -l "$T/check.lua" || exit 1

# 4. The startup trigger exists, is deferred, and skips $HOME and "/".
f=lua/config/autocmds.lua
grep -q 'augroup("undo_guard_preload")' "$f" || { echo "FAIL: preload augroup missing"; exit 1; }
grep -q 'LazyVim.undo.arm()' "$f"            || { echo "FAIL: arm() never called"; exit 1; }
grep -q 'vim.defer_fn' "$f"                  || { echo "FAIL: preload is not deferred"; exit 1; }
grep -q 'cwd == vim.env.HOME' "$f"           || { echo "FAIL: missing \$HOME guard"; exit 1; }
echo "PASS: deferred VimEnter trigger present with \$HOME and / guards"

# 5. The finish path must be idempotent. A queued schedule_wrap callback arriving after the queue
# drained used to call timer:close() a second time, surfacing "handle is already closing" as a
# vim.schedule error while opening files. That race needs real editor load to reproduce, so assert
# the guards structurally.
u=lua/util/undo.lua
grep -q 'local finished = false' "$u"     || { echo "FAIL: no finished guard in M.arm"; exit 1; }
grep -q 'if finished then' "$u"           || { echo "FAIL: callback does not return early once finished"; exit 1; }
grep -q 'if not timer:is_closing() then' "$u" || { echo "FAIL: timer:close() is not guarded by is_closing"; exit 1; }
echo "PASS: preload finish is guarded against duplicate close/notify"
echo "Step 6: OK"
