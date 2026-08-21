#!/usr/bin/env bash
# Step 8 verification — end-to-end proof, regression budgets, and the decision record.
set -uo pipefail
cd "$(dirname "$0")/../../../../.."   # repo root (dot_config/nvim)
REPO=$PWD
[ -d "${TMPDIR:-/tmp}" ] || export TMPDIR=/tmp

# --- 1. the end-to-end proof ---------------------------------------------------------------
bash .agent/docs/specs/2026-08-17-undo-guard/e2e.sh || { echo "FAIL: e2e.sh"; exit 1; }

# --- 2. startup budget ----------------------------------------------------------------------
# The preload sits behind a 2000ms defer_fn, so a headless run that exits immediately must never
# pay for it. Compare total startup against the perf-baseline stall threshold (80ms is the
# flag for a single stall; startup itself is dominated by plugin loading).
log=$(mktemp)
nvim --headless -u "$REPO/init.lua" --startuptime "$log" -c 'qa!' >/dev/null 2>&1
total=$(awk 'NF { v = $1 } END { print v }' "$log")
rm -f "$log"
case "$total" in
  ''|*[!0-9.]*) echo "FAIL: could not parse a startup time from --startuptime (got [$total])"; exit 1 ;;
esac
awk -v t="$total" 'BEGIN{ if (t+0 <= 0) { print "FAIL: nonsensical startup time " t; exit 1 }
  else if (t+0 > 600) { print "FAIL: startup " t "ms exceeds 600ms"; exit 1 }
  else print "PASS: startup " t "ms (preload is deferred 2000ms, so it never lands here)" }' || exit 1

# --- 3. sweep budget at the held-buffer counts this design produces -------------------------
nvim --headless -u NONE -i NONE -l /dev/stdin <<'LUA' || exit 1
-- 60 loaded buffers is well above the ~37 the 7-day window produces plus per-edit holds.
local d = vim.fn.tempname()
vim.fn.mkdir(d, "p")
for i = 1, 60 do
  local p = d .. "/f" .. i .. ".txt"
  vim.fn.writefile({ "line one", "line two" }, p)
  vim.fn.bufload(vim.fn.bufadd(p))
end
local function sweep()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == ""
      and vim.api.nvim_buf_get_name(buf) ~= "" then
      pcall(vim.cmd, "checktime " .. buf)
    end
  end
end
sweep()
local t0 = vim.uv.hrtime()
for _ = 1, 20 do sweep() end
local per = (vim.uv.hrtime() - t0) / 1e6 / 20
io.write(string.format("%s: CursorHold sweep %.2fms at 60 loaded buffers (budget 1.0ms/callback)\n",
  per < 1.0 and "PASS" or "FAIL", per))
vim.cmd(per < 1.0 and "qa!" or "cq")
LUA

# --- 4. the decision record -----------------------------------------------------------------
doc=.agent/docs/decisions/2026-08-17-undo-guard-hold-before-write.md
[ -f "$doc" ] || { echo "FAIL: decision record missing"; exit 1; }
head -1 "$doc" | grep -q '^---$' || { echo "FAIL: decision record has no frontmatter"; exit 1; }
for section in '## Context' '## Options considered' '## Decision' '## Consequences'; do
  grep -q "^$section" "$doc" || { echo "FAIL: decision record missing '$section'"; exit 1; }
done
grep -q '### Known gaps' "$doc" || { echo "FAIL: decision record does not record the known gaps"; exit 1; }
echo "PASS: decision record present, matching the existing format, gaps recorded"
echo "Step 8: OK"
