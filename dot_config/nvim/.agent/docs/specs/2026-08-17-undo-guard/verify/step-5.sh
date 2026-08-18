#!/usr/bin/env bash
# Step 5 verification — omp tool_call hook.
#
# Two halves:
#   1. The handler itself, driven with a fake HookAPI: path extraction, cwd resolution, dedupe,
#      internal-URI filtering, and the fail-open contract (a throwing exec must not propagate,
#      because omp fails CLOSED on a handler throw and would block every agent edit).
#   2. User-level registration: ~/.omp/agent/config.yml references the deployed hook, and the
#      file is still valid YAML with its original keys intact.
#
# The live end of this (a real `omp -p` run holding the file it edits) was verified manually and
# is recorded in the spec; it is not repeated here because it costs a model call per run.
set -uo pipefail
cd "$(dirname "$0")/../../../../.."   # repo root (dot_config/nvim)
REPO=$PWD

bun -e '
const hookMod = await import("'"$REPO"'/scripts/undo-guard-omp-hook.ts");
const hook = hookMod.default;

let handler;
const calls = [];
let execCount = 0;
const pi = {
  on: (evt, h) => { if (evt === "tool_call") handler = h; },
  // The hook batches every path into ONE invocation: args = [scriptPath, ...paths].
  exec: async (_cmd, args) => { calls.push(...args.slice(1)); execCount++; return { code: 0 }; },
};
hook(pi);
if (!handler) { console.log("FAIL: hook did not register a tool_call handler"); process.exit(1); }

const ctx = { cwd: "/tmp/proj" };
const fail = (msg) => { console.log("FAIL: " + msg); process.exit(1); };

// write: a relative path resolves against ctx.cwd
await handler({ type: "tool_call", toolName: "write", toolCallId: "1", input: { path: "rel/a.ts" } }, ctx);
if (calls.length !== 1 || calls[0] !== "/tmp/proj/rel/a.ts") fail("write path: " + JSON.stringify(calls));

// write: internal URLs and archive/sqlite selectors are skipped
calls.length = 0;
for (const p of ["xd://ast_edit", "local://plan.md", "memory://x", "pkg.zip:inner/f.txt", "app.sqlite:users:42"]) {
  await handler({ type: "tool_call", toolName: "write", toolCallId: "2", input: { path: p } }, ctx);
}
if (calls.length !== 0) fail("internal/selector targets should be skipped, got " + JSON.stringify(calls));

// edit: every [PATH#TAG] header, deduped, absolute preserved, internal skipped
calls.length = 0;
execCount = 0;
const doc = "[a/b.ts#1A2B]\n+x\n[xd://tool#2C3D]\n+y\n[a/b.ts#1A2B]\n+z\n[/abs/c.ts#3D4E]\n+w\n";
await handler({ type: "tool_call", toolName: "edit", toolCallId: "3", input: { input: doc } }, ctx);
const got = [...calls].sort();
const want = ["/abs/c.ts", "/tmp/proj/a/b.ts"];
if (JSON.stringify(got) !== JSON.stringify(want)) fail("edit paths: got " + JSON.stringify(got) + " want " + JSON.stringify(want));
// Two distinct paths must cost ONE notifier invocation, not one per path.
if (execCount !== 1) fail("expected 1 batched exec for 2 paths, got " + execCount);

// unrelated tools are ignored
calls.length = 0;
await handler({ type: "tool_call", toolName: "read", toolCallId: "4", input: { path: "/tmp/proj/a.ts" } }, ctx);
await handler({ type: "tool_call", toolName: "bash", toolCallId: "5", input: { command: "sed -i s/a/b/ f.ts" } }, ctx);
if (calls.length !== 0) fail("non-write/edit tools should be ignored, got " + JSON.stringify(calls));

// fail-open: a throwing exec must not propagate, and must never return { block: true }
const throwing = { on: (evt, h) => { if (evt === "tool_call") handler = h; }, exec: async () => { throw new Error("boom"); } };
hook(throwing);
const res = await handler({ type: "tool_call", toolName: "write", toolCallId: "6", input: { path: "/tmp/proj/a.ts" } }, ctx);
if (res !== undefined) fail("handler must return undefined, got " + JSON.stringify(res));

// a malformed event must not throw either
const res2 = await handler({ type: "tool_call", toolName: "write", toolCallId: "7", input: {} }, ctx);
if (res2 !== undefined) fail("malformed event must return undefined, got " + JSON.stringify(res2));

console.log("PASS: extraction, cwd resolution, dedupe, filtering, fail-open all correct");
' || exit 1

# --- user-level registration ----------------------------------------------------------
CFG=$HOME/.omp/agent/config.yml
[ -f "$CFG" ] || { echo "FAIL: $CFG missing"; exit 1; }
grep -q 'undo-guard-omp-hook.ts' "$CFG" || { echo "FAIL: hook not registered in config.yml"; exit 1; }
grep -q '^extensions:' "$CFG" || { echo "FAIL: extensions key is not top-level"; exit 1; }
# The append must not have fused onto the previous line (the file ships without a trailing newline).
grep -q 'autoextensions' "$CFG" && { echo "FAIL: config.yml corrupted by append"; exit 1; }
for key in providers setupVersion modelRoles defaultThinkingLevel; do
  grep -q "^$key:" "$CFG" || { echo "FAIL: lost pre-existing key $key"; exit 1; }
done
echo "PASS: config.yml registers the hook at user level, original keys intact"

# The referenced path is the deployed one; it only exists after chezmoi apply.
ref=$(grep -A1 '^extensions:' "$CFG" | tail -1 | sed 's/^[[:space:]]*-[[:space:]]*//')
if [ -f "$ref" ]; then
  echo "PASS: referenced hook exists at $ref"
else
  echo "NOTE: $ref not present yet — run 'chezmoi apply' to deploy it (hook fails open until then)"
fi
echo "Step 5: OK"
