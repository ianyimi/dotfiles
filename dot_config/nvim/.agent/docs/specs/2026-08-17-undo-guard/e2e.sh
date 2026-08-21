#!/usr/bin/env bash
# End-to-end proof for the undo-guard feature.
#
# Contract under test: an agent rewrites a file this nvim never opened, and the file's persistent
# undo history still survives into the next session.
#
# Runs entirely inside a throwaway directory with `undodir` pinned there, so the real
# ~/.local/state/nvim/undo is never read or written. The real config is loaded from the chezmoi
# SOURCE tree (`-u <repo>/init.lua` plus a package.path prepend, because lazy.nvim rebuilds
# runtimepath during setup and would otherwise drop the prepended entry), so this runs before
# `chezmoi apply`. After applying, the same assertions hold against ~/.config/nvim.
set -uo pipefail
cd "$(dirname "$0")/../../../.."   # repo root (dot_config/nvim) — four levels, not five: this
                                   # script sits one directory above verify/, which needs five
REPO=$PWD
NOTIFY=$REPO/scripts/undo-guard-notify.ts
OMP_HOOK=$REPO/scripts/undo-guard-omp-hook.ts

# An inherited TMPDIR pointing at a deleted directory makes mktemp fail and every path below
# resolve to empty, which looks exactly like a feature failure. Fail fast on it instead.
[ -d "${TMPDIR:-/tmp}" ] || export TMPDIR=/tmp
T=$(mktemp -d) || { echo "FAIL: mktemp -d failed (TMPDIR=${TMPDIR:-unset})"; exit 1; }
export TMPDIR="$T/tmp"
ADV="$TMPDIR/nvim-undo"
mkdir -p "$ADV" "$T/proj" "$T/undodir" || { echo "FAIL: could not create scratch dirs"; exit 1; }
cleanup() { pkill -f "$T/nvim.sock" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
FAIL=0

# Seed real undo history. Each seeding session must be the LAST writer of its file, or the
# undofile's content hash won't match and nvim discards the history on open (the very failure
# this feature exists to prevent).
seed() {
  printf 'export const original = 1;\n' > "$1"
  nvim --headless -u NONE -i NONE --cmd "set undofile undodir=$T/undodir noswapfile" "$1" \
    -c 'normal Goexport const second = 2;' -c write -c 'qa!' >/dev/null 2>&1
}
seed "$T/proj/via-claude.ts"     # held through the Claude Code entry point
seed "$T/proj/via-omp.ts"        # held through the omp entry point
seed "$T/proj/unprotected.ts"    # never held — the failure baseline for contrast
printf 'export const decoy = 0;\n' > "$T/proj/decoy.ts"

# Deployed config, or source? `require("config.lazy")` resolves through runtimepath, so a
# source-tree run still picks up the DEPLOYED lua/config/autocmds.lua — meaning the advertise
# and CursorHold-sweep autocmds only exist once `chezmoi apply` has run. Detect that and say so
# instead of silently testing the wrong tree.
DEPLOYED=$HOME/.config/nvim
if grep -q 'undo_guard_advertise' "$DEPLOYED/lua/config/autocmds.lua" 2>/dev/null \
   && [ -f "$DEPLOYED/lua/util/undo.lua" ]; then
  MODE=deployed
  NVIM_ARGS=(--cmd "set undodir=$T/undodir")
else
  MODE=source
  NVIM_ARGS=(-u "$REPO/init.lua"
             --cmd "lua package.path = '$REPO/lua/?.lua;' .. package.path"
             --cmd "set undodir=$T/undodir")
  echo "NOTE: ~/.config/nvim does not have this feature yet — running in SOURCE mode."
  echo "      The advertise and CursorHold-sweep autocmds cannot load pre-apply, so this run"
  echo "      calls advertise() and the per-buffer checktime directly. Their wiring is covered"
  echo "      by verify/step-2.sh and verify/step-6.sh. Re-run after 'chezmoi apply' for the"
  echo "      full path through the real autocmds."
fi

# A real-config nvim in the project, holding only decoy.ts. All three targets stay UNLOADED.
(cd "$T/proj" && nvim --headless "${NVIM_ARGS[@]}" \
  --listen "$T/nvim.sock" "$T/proj/decoy.ts" >/dev/null 2>&1 &)
for _ in $(seq 1 100); do [ -S "$T/nvim.sock" ] && break; sleep 0.1; done
[ -S "$T/nvim.sock" ] || { echo "FAIL: nvim never came up"; exit 1; }

rpc() { nvim --server "$T/nvim.sock" --remote-expr "$1"; }

if [ "$MODE" = source ]; then
  # Wait for the config to finish loading: lazy.nvim runs during startup and resets both
  # runtimepath and the Lua searchers, so anything injected before it settles is discarded.
  for _ in $(seq 1 60); do
    [ "$(rpc 'exists("*luaeval")' 2>/dev/null)" = "1" ] && break
    sleep 0.1
  done
  sleep 1.5
  # Put the source tree back on runtimepath so `require("util.undo")` resolves to the code under
  # test — including the requires the notifier issues inside nvim_exec_lua.
  rpc "execute('set rtp^=$REPO')" >/dev/null 2>&1
  rpc 'luaeval("(function() return tostring(require(\"util.undo\").advertise()) end)()")' >/dev/null 2>&1
fi
# Wait for the instance to publish itself (VimEnter autocmd in deployed mode).
for _ in $(seq 1 60); do [ -n "$(command ls -A "$ADV" 2>/dev/null)" ] && break; sleep 0.1; done
[ -n "$(command ls -A "$ADV" 2>/dev/null)" ] || { echo "FAIL: no advertise file appeared"; exit 1; }
echo "PASS: config up in $MODE mode, instance advertised at $ADV/$(command ls -A "$ADV" | head -1)"

# --- entry point 1: Claude Code PreToolUse document on stdin -------------------------------
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/proj/via-claude.ts"}}' "$T" \
  | bun "$NOTIFY" >/dev/null 2>&1
[ "$(rpc "bufloaded('$T/proj/via-claude.ts')")" = "1" ] \
  && echo "PASS: Claude Code entry point held via-claude.ts" \
  || { echo "FAIL: Claude Code entry point did not hold the file"; FAIL=1; }

# --- entry point 2: omp tool_call handler ---------------------------------------------------
bun -e '
const hook = (await import("'"$OMP_HOOK"'")).default;
let handler;
const { spawnSync } = await import("node:child_process");
hook({
  on: (evt, h) => { if (evt === "tool_call") handler = h; },
  // The hook hardcodes the DEPLOYED notifier path, which does not exist before chezmoi apply.
  // Rewrite it to the repo copy so a pre-apply run still exercises the real handler; once
  // deployed the two paths are identical and this substitution is a no-op.
  exec: async (cmd, args) => {
    const mapped = args.map((a) =>
      a.replace("/Users/zaye/.config/nvim/scripts/", "'"$REPO"'/scripts/"),
    );
    spawnSync(cmd, mapped, { stdio: "ignore" });
    return { code: 0 };
  },
});
await handler(
  { type: "tool_call", toolName: "write", toolCallId: "1", input: { path: "via-omp.ts" } },
  { cwd: "'"$T"'/proj" },
);
' >/dev/null 2>&1
[ "$(rpc "bufloaded('$T/proj/via-omp.ts')")" = "1" ] \
  && echo "PASS: omp entry point held via-omp.ts" \
  || { echo "FAIL: omp entry point did not hold the file"; FAIL=1; }

[ "$(rpc "bufloaded('$T/proj/unprotected.ts')")" = "0" ] \
  || { echo "FAIL: unprotected.ts should NOT be held (baseline is invalid)"; FAIL=1; }

# --- the agent's write ---------------------------------------------------------------------
sleep 1.1   # ensure a detectable mtime change
for f in via-claude via-omp unprotected; do
  printf 'export const original = 1;\nexport const second = 2;\nexport const AGENT_LINE = 3;\n' \
    > "$T/proj/$f.ts"
done
echo "PASS: agent rewrote all three files on disk"

# Something has to notice the change. In deployed mode fire the real CursorHold autocmd, so the
# assertion covers the committed wiring in lua/config/autocmds.lua; in source mode that autocmd
# does not exist, so run the same per-buffer checktime sweep it performs.
if [ "$MODE" = deployed ]; then
  rpc 'execute("doautocmd CursorHold")' >/dev/null
else
  rpc 'luaeval("(function() for _, b in ipairs(vim.api.nvim_list_bufs()) do if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == \"\" and vim.api.nvim_buf_get_name(b) ~= \"\" then pcall(vim.cmd, \"checktime \" .. b) end end return 1 end)()")' >/dev/null
fi
sleep 0.5

for f in via-claude via-omp; do
  seq=$(rpc "undotree(bufnr('$T/proj/$f.ts')).seq_last")
  [ "$seq" -ge 2 ] \
    && echo "PASS: $f.ts absorbed the write as an undo state in-session (seq_last=$seq)" \
    || { echo "FAIL: $f.ts did not absorb the write (seq_last=$seq)"; FAIL=1; }
done

# Quit WITHOUT ever visiting the target buffers — the undofiles must already be correct on disk.
nvim --server "$T/nvim.sock" --remote-send ':qa!<CR>' 2>/dev/null
sleep 1

# --- the payoff: a brand-new session on each file -------------------------------------------
check_next_session() {
  local f=$1 expect_history=$2
  local out
  out=$(nvim --headless -u NONE -i NONE --cmd "set undofile undodir=$T/undodir noswapfile" \
    "$T/proj/$f.ts" \
    -c 'lua local t = vim.fn.undotree(); io.write("seq_last=" .. t.seq_last .. "\n")' \
    -c 'silent undo' \
    -c 'lua io.write("after_undo=" .. (vim.fn.getline("$")) .. "\n")' -c 'qa!' 2>&1)
  local seq after
  seq=$(printf '%s' "$out" | sed -n 's/.*seq_last=\([0-9]*\).*/\1/p' | head -1)
  after=$(printf '%s' "$out" | sed -n 's/.*after_undo=\(.*\)/\1/p' | head -1)

  if [ "$expect_history" = "yes" ]; then
    if [ "${seq:-0}" -ge 2 ] && [ "$after" = "export const second = 2;" ]; then
      echo "PASS: $f.ts — history survived (seq_last=$seq), undo returns the pre-agent line"
    else
      echo "FAIL: $f.ts — expected surviving history, got seq_last=${seq:-?} after_undo=[$after]"
      FAIL=1
    fi
  else
    if [ "${seq:-0}" -eq 0 ]; then
      echo "PASS: $f.ts — baseline confirmed: unheld file lost its entire tree (seq_last=0)"
    else
      echo "FAIL: $f.ts — baseline invalid, expected seq_last=0, got ${seq:-?}"
      FAIL=1
    fi
  fi
}

check_next_session via-claude yes
check_next_session via-omp yes
check_next_session unprotected no

[ "$FAIL" -eq 0 ] && echo "e2e: OK" || echo "e2e: FAILED"
exit "$FAIL"
