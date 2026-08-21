#!/usr/bin/env bash
# Step 1 verification — lua/util/undo.lua guard module.
#
# Runs entirely in a throwaway directory with its own undodir, so the real
# ~/.local/state/nvim/undo is never touched. Uses -u NONE and prepends the repo to
# rtp, so this validates the module in isolation without needing `chezmoi apply`.
#
# The LSP/treesitter/gitsigns re-attach half of this group's Verify needs a live PTY
# nvim with the deployed config and cannot run deterministically here; it is recorded
# as manual evidence in the spec (verified: vtsls attached, treesitter active,
# gitsigns attached, filetype=typescript, undo tree intact).
set -euo pipefail
cd "$(dirname "$0")/../../../../.."   # repo root (dot_config/nvim)

d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
mkdir -p "$d/lua/util" "$d/proj" "$d/undodir" "$d/swapdir"
cp lua/util/undo.lua "$d/lua/util/undo.lua"
printf 'const x = 1;\n' > "$d/proj/file.ts"

# Session 1: create a real undofile the normal way.
nvim --headless -u NONE -i NONE \
  -c "set undofile undodir=$d/undodir directory=$d/swapdir//" \
  -c "edit $d/proj/file.ts" -c "normal Goconst y = 2;" -c write -c "qa!" >/dev/null 2>&1

# Session 2: file is unloaded — call hold() directly and assert every property.
cat > "$d/check.lua" <<LUA
vim.opt.rtp:prepend("$d")
vim.opt.undofile = true
vim.opt.undodir = "$d/undodir"
vim.opt.directory = "$d/swapdir//"
local undo = require("util.undo")
local path = "$d/proj/file.ts"

local status = undo.hold(path)
local buf = vim.fn.bufnr(path)
local ut = vim.fn.undotree(buf)
assert(status == "held", "status=" .. status)
assert(ut.seq_last > 0, "seq_last=" .. ut.seq_last)
assert(vim.bo[buf].buflisted == false, "buflisted should be false")
assert(vim.bo[buf].swapfile == false, "swapfile should be false")
assert(vim.o.eventignore == "", "eventignore=[" .. vim.o.eventignore .. "]")
print("PASS: hold=" .. status .. " seq_last=" .. ut.seq_last)

-- Idempotent once loaded.
assert(undo.hold(path) == "loaded", "second hold should report loaded")

-- A file with no usable undofile is released again rather than parked forever.
local fresh = "$d/proj/fresh.ts"
vim.fn.writefile({ "new" }, fresh)
assert(undo.hold(fresh) == "no-history", "file without undofile should be no-history")
assert(vim.fn.bufloaded(fresh) == 0, "no-history buffer should have been released")

-- Unreadable path.
assert(undo.hold("$d/proj/nope.ts") == "missing", "unreadable path should be missing")

-- The bug this module exists to fix: a throw inside the guarded window must still
-- restore eventignore/swapfile, or every autocmd in the session dies silently.
local saved = vim.fn.bufadd
vim.fn.bufadd = function() error("boom") end
local threw_status = undo.hold("$d/proj/file2.ts")
vim.fn.bufadd = saved
assert(vim.o.eventignore == "", "eventignore leaked after throw: [" .. vim.o.eventignore .. "]")
assert(vim.o.swapfile == true, "swapfile leaked after throw")
print("PASS: idempotent/no-history/missing/leak-on-throw correct (throw status=" .. threw_status .. ")")

-- REGRESSION: a buffer that already exists belongs to the user. Harpoon pins and session
-- restores list their files before loading them; unlisting one drops it from the tabline and
-- deleting one closes it. hold() must load such a buffer and change nothing else.
-- This shipped broken once: pinned files vanished ~2s after startup when the preload ran.
local pinned = "$d/proj/pinned.ts"
vim.fn.writefile({ "pinned one" }, pinned)
vim.fn.writefile({ "pinned one", "pinned two" }, pinned)
local pinned_buf = vim.fn.bufadd(pinned)
vim.bo[pinned_buf].buflisted = true
assert(vim.fn.bufloaded(pinned) == 0, "fixture should start unloaded")
local pinned_status = undo.hold(pinned)
assert(vim.fn.bufexists(pinned) == 1, "pre-existing buffer must NOT be deleted (was " .. pinned_status .. ")")
assert(vim.bo[pinned_buf].buflisted == true, "pre-existing buffer must stay listed (was " .. pinned_status .. ")")
assert(vim.fn.bufloaded(pinned) == 1, "pre-existing buffer should end up loaded, which is the protection")
assert(pinned_status == "adopted", "expected adopted, got " .. pinned_status)

-- Same for a pre-existing buffer with NO undo history: previously deleted outright.
local plain = "$d/proj/plain.ts"
vim.fn.writefile({ "no history here" }, plain)
local plain_buf = vim.fn.bufadd(plain)
vim.bo[plain_buf].buflisted = true
local plain_status = undo.hold(plain)
assert(vim.fn.bufexists(plain) == 1, "pre-existing no-history buffer must NOT be deleted (was " .. plain_status .. ")")
assert(vim.bo[plain_buf].buflisted == true, "pre-existing no-history buffer must stay listed")
print("PASS: pre-existing (harpoon/session) buffers are adopted, never unlisted or deleted")

-- REGRESSION: a buffer loaded with eventignore="all" has no filetype, so no syntax, treesitter
-- or LSP. Neovim never delivers BufReadPost/FileType later on its own, because the buffer is
-- already loaded and opening it does not re-read it. Entering it must fire them once — for
-- ADOPTED buffers too, not just created ones. This shipped broken: harpoon-pinned files opened
-- with no highlighting until closed and reopened.
assert(vim.bo[pinned_buf].filetype == "", "fixture should have no filetype while unvisited")
vim.cmd("buffer " .. pinned_buf)
vim.wait(200)
assert(vim.bo[pinned_buf].filetype == "typescript",
  "adopted buffer must get its filetype on first visit, got [" .. vim.bo[pinned_buf].filetype .. "]")

-- Same for a buffer this module created and unlisted: visiting relists it AND sets filetype.
local created = "$d/proj/created.ts"
vim.fn.writefile({ "export const one = 1;" }, created)
vim.fn.writefile({ "export const one = 1;", "export const two = 2;" }, created)
-- give it a real undofile so hold() keeps it
vim.cmd("edit " .. created)
vim.cmd("normal Goexport const three = 3;")
vim.cmd("silent write")
vim.cmd("bwipeout " .. vim.fn.bufnr(created))
assert(undo.hold(created) == "held", "created fixture should be held")
local created_buf = vim.fn.bufnr(created)
assert(vim.bo[created_buf].buflisted == false, "held buffer starts unlisted")
vim.cmd("buffer " .. created_buf)
vim.wait(200)
assert(vim.bo[created_buf].buflisted == true, "visiting a held buffer must relist it")
assert(vim.bo[created_buf].filetype == "typescript",
  "held buffer must get its filetype on first visit, got [" .. vim.bo[created_buf].filetype .. "]")
print("PASS: first visit restores filetype (and relists) for both adopted and created buffers")

-- REGRESSION: repeat holds of a historyless file must not churn buffers. Each hold used to
-- create a buffer and delete it, and because the delete ran AFTER eventignore was restored it
-- leaked BufWipeout/BufUnload into barbar's state — measured as 5617 barbar render.update calls
-- and 24s of CPU in one session, with tabs visibly rearranging. Now: the whole
-- create/inspect/delete window is event-suppressed, and the verdict is cached per path.
local churn_events = 0
for _, e in ipairs({ "BufAdd", "BufNew", "BufDelete", "BufWipeout", "BufUnload" }) do
  vim.api.nvim_create_autocmd(e, { callback = function() churn_events = churn_events + 1 end })
end
local churn_adds = 0
local real_bufadd = vim.fn.bufadd
vim.fn.bufadd = function(p)
  churn_adds = churn_adds + 1
  return real_bufadd(p)
end
local historyless = "$d/proj/historyless.ts"
vim.fn.writefile({ "no undofile for this one" }, historyless)
for _ = 1, 10 do
  assert(undo.hold(historyless) == "no-history", "historyless file should report no-history")
end
vim.fn.bufadd = real_bufadd
assert(churn_adds == 1, "10 holds must create at most one buffer, got " .. churn_adds)
assert(churn_events == 0, "buffer create/delete must not emit events (barbar storm), got " .. churn_events)
print("PASS: repeat holds of a historyless file cost 1 buffer and 0 buffer events")

-- release() drains held buffers.
assert(undo.release() >= 1, "release should report held buffers")
assert(vim.fn.bufloaded(path) == 0, "release should have deleted the held buffer")
print("PASS: release drained held buffers")
vim.cmd("qa!")
LUA

nvim --headless -u NONE -i NONE -l "$d/check.lua"
echo "Step 1: OK"
