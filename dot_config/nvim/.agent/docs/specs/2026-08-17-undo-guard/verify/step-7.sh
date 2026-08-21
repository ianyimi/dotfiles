#!/usr/bin/env bash
# Step 7 verification — shell-command path extraction.
#
# Table-drives the extractor against concrete commands, proves multi-path batching reaches nvim
# over a single connection, and checks both hooks are wired for shell tool calls.
set -uo pipefail
cd "$(dirname "$0")/../../../../.."   # repo root (dot_config/nvim)
REPO=$PWD

T=$(mktemp -d)
export TMPDIR="$T/tmp"
mkdir -p "$TMPDIR/nvim-undo" "$T/proj/sub" "$T/undodir"
cleanup() { pkill -f "$T/nvim.sock" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

printf 'a\n' > "$T/proj/one.ts"
printf 'b\n' > "$T/proj/two.ts"
printf 'c\n' > "$T/proj/sub/three.ts"
printf 'p\n' > "$T/proj/fix.patch"

# --- 1. extractor table --------------------------------------------------------------------
bun -e '
const { extractShellPaths } = await import("'"$REPO"'/scripts/undo-guard-paths.ts");
const cwd = "'"$T"'/proj";
const cases = [
  ["sed -i s/a/b/ one.ts",                       ["one.ts"]],
  ["sed -i.bak s/a/b/ one.ts two.ts",            ["one.ts", "two.ts"]],
  ["echo x > one.ts",                            ["one.ts"]],
  ["echo x >> two.ts",                           ["two.ts"]],
  ["cat one.ts | tee two.ts",                    ["two.ts"]],
  ["mv one.ts two.ts",                           ["one.ts", "two.ts"]],
  ["cp sub/three.ts one.ts",                     ["sub/three.ts", "one.ts"]],
  ["install -m 0644 one.ts two.ts",              ["one.ts", "two.ts"]],
  ["patch -p1 < fix.patch",                      ["fix.patch"]],
  ["sed -i s/a/b/ \"one.ts\"",                   ["one.ts"]],
  // must extract NOTHING:
  ["prettier --write .",                         []],
  ["npm install",                                []],
  ["git checkout main",                          []],
  ["sed -i s/a/b/ *.ts",                         []],   // glob unexpanded
  ["sed -i s/a/b/ $FILE",                        []],   // variable
  ["sed -i s/a/b/ nonexistent.ts",               []],   // no history to protect
  ["cat one.ts",                                 []],   // read-only command
  ["rm -rf one.ts",                              []],   // not a path-naming command we cover
];
let bad = 0;
for (const [cmd, want] of cases) {
  const got = extractShellPaths(cmd, cwd).map((p) => p.replace(cwd + "/", "")).sort();
  const exp = [...want].sort();
  if (JSON.stringify(got) !== JSON.stringify(exp)) {
    console.log(`  MISMATCH  ${JSON.stringify(cmd)}\n            got ${JSON.stringify(got)} want ${JSON.stringify(exp)}`);
    bad++;
  }
}
if (bad > 0) { console.log(`FAIL: ${bad} extractor case(s) wrong`); process.exit(1); }
console.log(`PASS: all ${cases.length} extractor cases match (including 8 that must extract nothing)`);
' || exit 1

# --- 2. batching: several paths, one nvim, one invocation -----------------------------------
seed() {
  nvim --headless -u NONE -i NONE --cmd "set undofile undodir=$T/undodir noswapfile" "$1" \
    -c 'normal Goseeded' -c write -c 'qa!' >/dev/null 2>&1
}
seed "$T/proj/one.ts"; seed "$T/proj/two.ts"; seed "$T/proj/sub/three.ts"
printf 'decoy\n' > "$T/proj/decoy.ts"

(cd "$T/proj" && nvim --headless -u NONE -i NONE \
  --cmd "set rtp^=$REPO" --cmd "set undofile undodir=$T/undodir noswapfile" \
  --listen "$T/nvim.sock" "$T/proj/decoy.ts" \
  -c 'lua require("util.undo").advertise()' >/dev/null 2>&1 &)
for _ in $(seq 1 40); do [ -S "$T/nvim.sock" ] && break; sleep 0.1; done
[ -S "$T/nvim.sock" ] || { echo "FAIL: test nvim never came up"; exit 1; }
sleep 0.3

start=$(date +%s%N)
bun "$REPO/scripts/undo-guard-notify.ts" "$T/proj/one.ts" "$T/proj/two.ts" "$T/proj/sub/three.ts"
rc=$?; ms=$(( ($(date +%s%N) - start) / 1000000 ))
[ "$rc" -eq 0 ] || { echo "FAIL: batched notifier exit=$rc"; exit 1; }
for f in "$T/proj/one.ts" "$T/proj/two.ts" "$T/proj/sub/three.ts"; do
  got=$(nvim --server "$T/nvim.sock" --remote-expr "bufloaded('$f')")
  [ "$got" = "1" ] || { echo "FAIL: $f not held (bufloaded=$got)"; exit 1; }
done
echo "PASS: 3 paths held in one invocation (${ms}ms total, one Bun startup)"

# A Bash PreToolUse document on stdin must reach the same extraction path.
payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"sed -i s/x/y/ %s/proj/one.ts"},"cwd":"%s/proj"}' "$T" "$T")
out=$(printf '%s' "$payload" | bun "$REPO/scripts/undo-guard-notify.ts"); rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: Bash payload exit=$rc"; exit 1; }
[ -z "$out" ] || { echo "FAIL: Bash payload wrote to stdout: [$out]"; exit 1; }
echo "PASS: Bash PreToolUse document extracted and held, silent exit 0"

# --- 3. wiring -----------------------------------------------------------------------------
jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash")' "$HOME/.claude/settings.json" >/dev/null \
  || { echo "FAIL: Claude Bash matcher group missing"; exit 1; }
jq -e '[.hooks.PreToolUse[]] | length == 2' "$HOME/.claude/settings.json" >/dev/null \
  || { echo "FAIL: expected 2 PreToolUse groups (edit tools + Bash)"; exit 1; }
grep -q 'extractShellPaths' scripts/undo-guard-omp-hook.ts \
  || { echo "FAIL: omp hook does not handle shell commands"; exit 1; }
grep -q 'toolName === "bash"' scripts/undo-guard-omp-hook.ts \
  || { echo "FAIL: omp hook does not match the bash tool"; exit 1; }
# The hook must not *import* the CLI (that would run main() and process.exit(0) in the host).
# Referencing its path as an exec target is expected and fine.
grep -qE '^import .*undo-guard-notify' scripts/undo-guard-omp-hook.ts \
  && { echo "FAIL: hook imports the CLI module"; exit 1; }
grep -q 'NOTIFIER_SCRIPT' scripts/undo-guard-omp-hook.ts \
  || { echo "FAIL: hook lost its notifier exec target"; exit 1; }
echo "PASS: both hooks wired for shell commands, no CLI import in the hook"
echo "Step 7: OK"
