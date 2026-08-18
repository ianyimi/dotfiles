#!/usr/bin/env bash
# Step 3 verification — scripts/undo-guard-notify.ts.
#
# Runs the notifier against a real nvim over its real msgpack-RPC socket. The nvim under test
# uses -u NONE plus an rtp prepend, so this needs no `chezmoi apply`, and $TMPDIR is redirected
# so the real advertise directory and the real undodir are never touched.
set -uo pipefail
cd "$(dirname "$0")/../../../../.."   # repo root (dot_config/nvim)
REPO=$PWD
SCRIPT=$REPO/scripts/undo-guard-notify.ts

T=$(mktemp -d)
export TMPDIR="$T/tmp"
ADV="$TMPDIR/nvim-undo"
mkdir -p "$ADV" "$T/proj" "$T/undodir"
cleanup() { pkill -f "$T/nvim.sock" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

printf 'const x = 1;\n' > "$T/proj/file.ts"
printf 'const other = 2;\n' > "$T/proj/decoy.ts"

# Give file.ts real undo history; this session must be the LAST writer so the
# undofile's content hash still matches on disk.
nvim --headless -u NONE -i NONE --cmd "set undofile undodir=$T/undodir noswapfile" \
  "$T/proj/file.ts" -c 'normal Goconst y = 2;' -c write -c 'qa!' >/dev/null 2>&1

# A live instance whose cwd is the project, holding a DIFFERENT file. file.ts stays unloaded —
# that is the whole scenario: an agent is about to rewrite a file nvim never opened.
(cd "$T/proj" && nvim --headless -u NONE -i NONE \
  --cmd "set rtp^=$REPO" --cmd "set undofile undodir=$T/undodir noswapfile" \
  --listen "$T/nvim.sock" "$T/proj/decoy.ts" \
  -c 'lua require("util.undo").advertise()' >/dev/null 2>&1 &)
for _ in $(seq 1 40); do [ -S "$T/nvim.sock" ] && break; sleep 0.1; done
[ -S "$T/nvim.sock" ] || { echo "FAIL: test nvim never came up"; exit 1; }
sleep 0.3

adv=$(command ls "$ADV" | head -1)
[ -n "$adv" ] || { echo "FAIL: no advertise file written"; exit 1; }
echo "PASS: advertise file present ($adv)"

# (a) The notifier holds the unloaded file.
start=$(date +%s%N)
bun "$SCRIPT" "$T/proj/file.ts"; rc=$?
elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
[ "$rc" -eq 0 ] || { echo "FAIL: notifier exit=$rc"; exit 1; }

loaded=$(nvim --server "$T/nvim.sock" --remote-expr "bufloaded('$T/proj/file.ts')")
listed=$(nvim --server "$T/nvim.sock" --remote-expr "getbufvar(bufnr('$T/proj/file.ts'), '&buflisted')")
seq=$(nvim --server "$T/nvim.sock" --remote-expr "undotree(bufnr('$T/proj/file.ts')).seq_last")
[ "$loaded" = "1" ] || { echo "FAIL: file not held (bufloaded=$loaded)"; exit 1; }
[ "$listed" = "0" ] || { echo "FAIL: held buffer should be unlisted (buflisted=$listed)"; exit 1; }
[ "$seq" -ge 1 ] || { echo "FAIL: held buffer has no undo history (seq_last=$seq)"; exit 1; }
echo "PASS: file held, unlisted, undo tree intact (seq_last=$seq) in ${elapsed}ms total"

# (b) Cost: total wall time is dominated by Bun startup, and is what the agent actually pays.
[ "$elapsed" -lt 400 ] || { echo "FAIL: ${elapsed}ms exceeds the 400ms budget"; exit 1; }

# (c) Fail-open. Stale advertise file: dead pid, nonexistent socket.
printf '%s\n%s\n' "$T/proj" "$ADV/dead.sock" > "$ADV/999999"
start=$(date +%s%N)
bun "$SCRIPT" "$T/proj/file.ts"; rc=$?
stale_ms=$(( ($(date +%s%N) - start) / 1000000 ))
rm -f "$ADV/999999"
[ "$rc" -eq 0 ] || { echo "FAIL: stale advertise file gave exit=$rc"; exit 1; }
echo "PASS: stale advertise file ignored, exit 0 in ${stale_ms}ms"

# No instances at all.
pkill -f "$T/nvim.sock" 2>/dev/null; sleep 0.3; rm -f "$ADV"/*
start=$(date +%s%N)
out=$(bun "$SCRIPT" "$T/proj/file.ts"); rc=$?
none_ms=$(( ($(date +%s%N) - start) / 1000000 ))
[ "$rc" -eq 0 ] || { echo "FAIL: no-nvim case gave exit=$rc"; exit 1; }
[ -z "$out" ] || { echo "FAIL: wrote to stdout: [$out]"; exit 1; }
[ "$none_ms" -lt 400 ] || { echo "FAIL: no-nvim case took ${none_ms}ms"; exit 1; }
echo "PASS: no live nvim → silent exit 0 in ${none_ms}ms"

# Malformed stdin must also be silent and exit 0.
out=$(echo 'not json' | bun "$SCRIPT"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] || { echo "FAIL: malformed stdin rc=$rc out=[$out]"; exit 1; }
echo "PASS: malformed stdin → silent exit 0"
echo "Step 3: OK"
