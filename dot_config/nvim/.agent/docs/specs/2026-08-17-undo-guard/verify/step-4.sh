#!/usr/bin/env bash
# Step 4 verification — Claude Code PreToolUse wiring in ~/.claude/settings.json.
#
# Checks the settings shape against Claude Code's documented schema, then drives the exact
# command the hook would run with a real PreToolUse payload and asserts the file gets held.
# $TMPDIR is redirected so the real advertise dir and undodir are untouched.
set -uo pipefail
cd "$(dirname "$0")/../../../../.."   # repo root (dot_config/nvim)
REPO=$PWD
SETTINGS=$HOME/.claude/settings.json

# --- settings shape -------------------------------------------------------------------
jq -e . "$SETTINGS" >/dev/null || { echo "FAIL: settings.json is not valid JSON"; exit 1; }

# Claude Code nests handlers in a "hooks" array inside the matcher group (per the hooks
# reference and the project's own .claude/settings.json) — NOT a "handler" object.
jq -e '.hooks.PreToolUse[0].hooks[0].type == "command"' "$SETTINGS" >/dev/null \
  || { echo "FAIL: PreToolUse handler missing or wrong shape (expected .hooks[].type == command)"; exit 1; }
jq -e '.hooks.PreToolUse[] | select(.matcher == "Write|Edit|MultiEdit|NotebookEdit")' "$SETTINGS" >/dev/null \
  || { echo "FAIL: edit-tool matcher group missing"; exit 1; }
jq -e '.hooks.PreToolUse[0].hooks[0].args[0] | endswith("scripts/undo-guard-notify.ts")' "$SETTINGS" >/dev/null \
  || { echo "FAIL: notifier not referenced in args"; exit 1; }

BUN=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$SETTINGS")
[ -x "$BUN" ] || { echo "FAIL: bun path from settings is not executable: $BUN"; exit 1; }

# Pre-existing keys must survive the merge.
for key in enabledPlugins alwaysThinkingEnabled skipDangerousModePermissionPrompt; do
  jq -e "has(\"$key\")" "$SETTINGS" >/dev/null || { echo "FAIL: lost pre-existing key $key"; exit 1; }
done
echo "PASS: settings.json shape matches the documented schema, existing keys intact"

# --- behaviour: drive the hook command with a real payload ----------------------------
T=$(mktemp -d)
export TMPDIR="$T/tmp"
mkdir -p "$TMPDIR/nvim-undo" "$T/proj" "$T/undodir"
cleanup() { pkill -f "$T/nvim.sock" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

printf 'const x = 1;\n' > "$T/proj/file.ts"
printf 'const other = 2;\n' > "$T/proj/decoy.ts"
nvim --headless -u NONE -i NONE --cmd "set undofile undodir=$T/undodir noswapfile" \
  "$T/proj/file.ts" -c 'normal Goconst y = 2;' -c write -c 'qa!' >/dev/null 2>&1

(cd "$T/proj" && nvim --headless -u NONE -i NONE \
  --cmd "set rtp^=$REPO" --cmd "set undofile undodir=$T/undodir noswapfile" \
  --listen "$T/nvim.sock" "$T/proj/decoy.ts" \
  -c 'lua require("util.undo").advertise()' >/dev/null 2>&1 &)
for _ in $(seq 1 40); do [ -S "$T/nvim.sock" ] && break; sleep 0.1; done
[ -S "$T/nvim.sock" ] || { echo "FAIL: test nvim never came up"; exit 1; }
sleep 0.3

# The notifier is invoked exactly as the hook would: bun + script path, payload on stdin.
# The repo copy is used because the deployed ~/.config/nvim copy only exists after chezmoi apply.
payload=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/proj/file.ts"}}' "$T")
out=$(printf '%s' "$payload" | "$BUN" "$REPO/scripts/undo-guard-notify.ts"); rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: hook command exit=$rc"; exit 1; }
[ -z "$out" ] || { echo "FAIL: hook wrote to stdout: [$out] (Claude parses stdout as a decision)"; exit 1; }

loaded=$(nvim --server "$T/nvim.sock" --remote-expr "bufloaded('$T/proj/file.ts')")
listed=$(nvim --server "$T/nvim.sock" --remote-expr "getbufvar(bufnr('$T/proj/file.ts'), '&buflisted')")
[ "$loaded" = "1" ] || { echo "FAIL: PreToolUse payload did not hold the file (bufloaded=$loaded)"; exit 1; }
[ "$listed" = "0" ] || { echo "FAIL: held buffer should be unlisted (buflisted=$listed)"; exit 1; }
echo "PASS: PreToolUse payload held the file, unlisted, silent stdout, exit 0"

# A payload for a path with no history must still be silent and exit 0.
payload=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/proj/brand-new.ts"}}' "$T")
out=$(printf '%s' "$payload" | "$BUN" "$REPO/scripts/undo-guard-notify.ts"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] || { echo "FAIL: missing-file payload rc=$rc out=[$out]"; exit 1; }
echo "PASS: payload for a nonexistent file → silent exit 0"
echo "Step 4: OK"
