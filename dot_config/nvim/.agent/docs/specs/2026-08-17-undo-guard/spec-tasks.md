---
status: draft
spec_id: 2026-08-17-undo-guard
touches:
  - lua/util/undo.lua
  - lua/util/init.lua
  - lua/config/autocmds.lua
  - scripts/undo-guard-notify.ts
  - scripts/undo-guard-omp-hook.ts
  - .agent/docs/decisions/2026-08-17-undo-guard-hold-before-write.md
  - .agent/docs/specs/2026-08-17-undo-guard/e2e.sh
prompt_version: 1
---

# 2026-08-17-undo-guard — Tasks

## Step 1 — `lua/util/undo.lua` guard module `[agent]`
Why: every other step calls into this. Holding a file in a loaded buffer *before* an external
write is the entire mechanism — nvim keys persistent undo to a hash of the file contents, so a
file rewritten while unloaded loses its whole tree, while a loaded one absorbs the write as an
undo state via `undoreload` and gets its undofile rewritten.
Verify: bash .agent/docs/specs/2026-08-17-undo-guard/verify/step-1.sh
- [x] Create `lua/util/undo.lua` with `M.hold`, `M.release`, `M.advertise`, `M.unadvertise`
- [x] Register `---@field undo lazyvim.util.undo` in `lua/util/init.lua`
- [x] First-visit `BufEnter` re-attach autocmd inside the module

## Step 2 — Instance advertising + command delegation `[agent]`
Why: an external process has no way to find this nvim otherwise, and the existing inline
`UndoGuardHold` command leaks `eventignore = "all"` when `bufload` throws, which silently kills
every autocmd in the session (no LSP attach, no `checktime`, no format-on-save) until restart.
Verify: bash .agent/docs/specs/2026-08-17-undo-guard/verify/step-2.sh
- [x] Replace the inline `UndoGuardHold` body in `lua/config/autocmds.lua` with a delegate
- [x] Call `M.advertise()` at startup and `M.unadvertise()` on `VimLeavePre`
- [x] Stale advertise files from dead pids are pruned on write

## Step 3 — `scripts/undo-guard-notify.ts` notifier `[agent]`
Why: the hooks' only job is to call this. It owns instance selection, the msgpack round-trip over
the socket nvim already listens on (no `serverstart`, no `nvim --server` spawn), and the fail-open
guarantee.
Verify: bash .agent/docs/specs/2026-08-17-undo-guard/verify/step-3.sh
- [x] Create `scripts/undo-guard-notify.ts` — minimal msgpack encode/decode, no dependencies
- [x] Instance selection: longest cwd prefix, then newest pid; fall back to any live instance
- [x] Accept a path as argv or a `PreToolUse` JSON document on stdin
- [x] Hard timeout and `exit 0` on every failure path

## Step 4 — Claude Code `PreToolUse` wiring `[agent]`
Why: Claude Code is an active platform and `PreToolUse` fires before the tool executes and blocks
until the hook returns — which is what puts the hold strictly before the write.
Verify: bash .agent/docs/specs/2026-08-17-undo-guard/verify/step-4.sh
- [x] Add a `PreToolUse` matcher group for `Write|Edit|MultiEdit|NotebookEdit` to
      `~/.claude/settings.json` (NOT chezmoi-managed — edits are live immediately)
- [x] Use the `args` exec form with an absolute `bun` path so no shell spawns
- [x] Confirm the existing `SessionStart` `harness doctor` hook still fires

## Step 5 — omp `tool_call` hook `[agent]`
Why: omp is the other active platform. Its `write` input carries `path`, but its `edit` input is a
hashline document whose paths live in `[PATH#TAG]` section headers, so the hook must parse them.
omp **fails closed** when a handler throws, so an unguarded bug would block every agent edit.
Installing once at user level is what makes cross-project protection work — an agent editing vex
while the only running nvim sits in maprios-app.
Verify: bash .agent/docs/specs/2026-08-17-undo-guard/verify/step-5.sh
- [x] Create `scripts/undo-guard-omp-hook.ts` (versioned here, deployed by chezmoi)
- [x] Add one absolute-path entry to `~/.omp/agent/config.yml#extensions` — back it up first, the
      file ships without a trailing newline
- [x] Extract paths for `write` and `edit`, resolve against `ctx.cwd`, dedupe
- [x] Wrap the whole body in `try/catch` so a failure never blocks a tool call

## Step 6 — Windowed startup preload `[agent]`
Why: some rewrites have no pre-execution path list (`prettier --write .`, `npm install`, codegen)
and some involve no agent at all, so no hook can fire — a `git checkout` or `stash` run in a tmux
pane. A watcher cannot substitute: it fires *after* the write, when the hash mismatch already
exists. Only an already-loaded file survives.
Verify: bash .agent/docs/specs/2026-08-17-undo-guard/verify/step-6.sh
- [x] Add `WINDOW_DAYS`, `HOLD_CAP`, `M.candidates`, `M.arm` to `lua/util/undo.lua`
- [x] Give `M.release()` its caller via the cap check
- [x] `VimEnter` autocmd deferring `M.arm()` by 2000 ms, skipping `$HOME` and `/`

## Step 7 — Shell-command path extraction `[agent]`
Why: `sed -i f`, `tee f`, `> f`, `patch`, `mv`, `cp` all name their targets, so they are cheap to
cover precisely. Commands that choose their own file set stay uncovered by design and fall to the
Step 6 preload instead.
Verify: bash .agent/docs/specs/2026-08-17-undo-guard/verify/step-7.sh
- [x] Shared `extractShellPaths(command, cwd)`, existing-readable-files only
- [x] Batch multiple paths over one notifier invocation and one socket
- [x] Second `PreToolUse` matcher group for `Bash` in `~/.claude/settings.json`
- [x] `bash` branch in the omp handler, inside the existing `try/catch`

## Step 8 — End-to-end proof + record the pattern `[agent]`
Why: the contract is "an agent edits a file I never opened and its undo history survives". Only a
full run proves it, and the earlier measurements are the baseline it must beat.
Verify: bash .agent/docs/specs/2026-08-17-undo-guard/verify/step-8.sh
- [x] End-to-end script exercising both the Claude Code and omp entry points
- [x] Confirm no regression to startup time or the `CursorHold` sweep budget
- [x] Record the mechanism in `.agent/docs/decisions/` and note the known gaps
