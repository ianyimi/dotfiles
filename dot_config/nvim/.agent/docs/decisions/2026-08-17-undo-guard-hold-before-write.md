---
date: 2026-08-17
status: accepted
supersedes: none
---

# Hold files in a buffer before an agent writes them, because undofiles are content-hashed

## Context

Persistent undo (`undofile`) was configured correctly and had been for a long time —
`undofile`, `undolevels=10000`, `undoreload=10000`, and the default `undodir` holding
2600+ entries. Undo trees still vanished unpredictably.

The cause is that Neovim binds an undofile to a SHA of the file's contents. When a file
is rewritten while Neovim has it **unloaded**, the stored hash no longer matches and the
entire tree is silently discarded on next open. Measured directly: a file with three undo
states reopened at `seq_last=3` untouched, and at `seq_last=0` after an out-of-band
rewrite. The loss is unrecoverable — even an explicit `:rundo` refuses it
("File contents changed, cannot use undo info"). By contrast a file that **is** loaded
absorbs the same external write as a new undo state via `'undoreload'` and gets its
undofile rewritten, so its history survives.

Two secondary defects were found in the same area and fixed on the way:

1. `:checktime` without an argument only reaches buffers displayed in a window. An agent
   rewriting nine files held as hidden buffers left all nine stale, and their trees died
   at exit. The per-buffer `:checktime {buf}` form has no window requirement.
2. A previous `FileChangedShell`/`FileChangedShellPost` pair intended to preserve undo
   never fired at all on unmodified buffers (only `FileChangedShellPost` does), while its
   mere registration suppressed Neovim's default action — so the `W12` conflict warning
   was silently swallowed. A `v:fcs_choice = "reload"` handler replaced it.

## Options considered

1. **Do nothing.** Rejected: this is the status quo that loses history.
2. **Watch the filesystem** (`fs_event` on the project, or on `.git/HEAD`). Rejected as
   structurally incapable: a watcher fires *after* the write, when the hash mismatch
   already exists. Nothing can be recovered at that point.
3. **Force-load the stale undofile** with `:rundo`. Rejected — Neovim refuses a hash
   mismatch there too; verified.
4. **Shell aliases / PATH shims / `DYLD_INSERT_LIBRARIES`** to notice agent edits.
   Rejected: agents write files in-process, not through a shell, so aliases see almost
   nothing, and they do not exist in the non-interactive shells agents spawn.
5. **A snapshot layer** (git shadow refs, per-save commits). Declined by the developer as
   a separate concern from undo.
6. **Hold the file before the write** (chosen). The only point at which the outcome can
   still be changed is before the write lands.

## Decision

Load the file into a hidden, unlisted buffer *before* the write, from three directions:

- **Agent tool-call hooks.** Claude Code `PreToolUse` (matchers
  `Write|Edit|MultiEdit|NotebookEdit` and `Bash`) and omp `tool_call` both fire
  pre-execution and block until they return, which is what guarantees ordering. They call
  `scripts/undo-guard-notify.ts`, which speaks msgpack-RPC directly to the socket every
  Neovim already listens on (`v:servername`) — no `serverstart`, and no `nvim --server`
  subprocess, which would cost ~40 ms of process start for a ~2 ms round-trip. Measured
  26 ms total per invocation, dominated by Bun startup.
- **A 7-day windowed startup preload.** Covers what no hook can see: `git checkout`,
  `prettier --write .`, `npm install`, codegen, `xd://ast_edit`, and the developer's own
  manual git operations, none of which pass through a tool call. Measured 37 candidates /
  29 ms / +5.7 MB RSS on maprios-app. Unwindowed was measured and rejected (287 files /
  151 ms / +25.4 MB there; 469 / 385 ms / +57.1 MB on vex, per nvim process, against a
  29.8 MB idle baseline) — skipping a file never shrinks its tree, it only leaves that
  file unprotected for the session, so the long tail buys little.
- **Shell path extraction** for commands that name their targets (`sed -i f`, `tee f`,
  `> f`, `patch`, `mv`, `cp`, `install`), sharing one extractor between both hooks.

Instances advertise themselves by writing `$TMPDIR/nvim-undo/<pid>` (line 1 cwd, line 2
`v:servername`), pruned on write and removed on `VimLeavePre`. Exactly one instance is
poked, chosen by longest cwd prefix then newest pid, falling back to any live instance —
undofile names derive from the absolute path alone, so an nvim in project A can protect a
file in project B (verified). Poking only one avoids two instances writing divergent trees
for the same file, which matters because the same directory is routinely open in several
tmux sessions.

Held buffers load with `eventignore=all` and `swapfile=false`, then re-attach on first
visit (relist, fire `BufReadPost`, set filetype) so LSP, treesitter and gitsigns come up
normally — verified in a real project: `vtsls` attached, treesitter active, gitsigns
attached, undo tree intact.

Fail-open is a hard requirement throughout: no nvim, dead socket, malformed reply, timeout
or thrown error all end in `exit 0`. omp fails *closed* when a `tool_call` handler throws,
so its handler is wrapped end to end.

## Consequences

- Undo history for agent-edited files now survives across sessions, provided some Neovim
  instance was alive and reachable at write time.
- ~+5.7 MB RSS and ~29 ms of chunked background work per nvim process, per project. The
  cost is paid per process; three tmux sessions in three projects pay it three times.
- One line lives outside version control: the `extensions:` entry in
  `~/.omp/agent/config.yml`. `~/.claude/settings.json` is likewise unmanaged. Both are
  outside chezmoi's tree, so they take effect immediately and are not restored by
  `chezmoi apply` on a new machine.
- `M.hold` is the only code that touches `eventignore`; it restores it unconditionally,
  including on a throw. A leak there would silently disable every autocmd in the session,
  which is far worse than losing one file's history.
- `M.hold` only unlists, tracks or deletes a buffer **it created**. A pre-existing buffer is
  loaded and otherwise left alone (status `adopted`). Shipped wrong once: harpoon-pinned files
  are listed before they are loaded, so the deferred preload adopted them, unlisted the ones
  with history and deleted the ones without — they appeared at startup and vanished seconds
  later. Regression-tested in `verify/step-1.sh`.

### Known gaps

- **Shell commands that choose their own file set** (`prettier --write .`, `npm install`,
  `make`) and **`xd://ast_edit`** bulk rewrites, *for files outside the cwd*. Inside the
  cwd the preload covers them.
- **Globbed, `xargs`-fed, heredoc and variable-substituted paths** in shell commands. The
  extractor only trusts tokens resolving to an existing readable file.
- **Files edited while no nvim is running anywhere.** Nothing can hold them.
- **Already-stale undofiles.** Unrecoverable, by design of the hash check. At the time of
  writing, 50 of 287 files under maprios-app were already in this state.
- **History older than the 7-day window** is unprotected against surprise rewrites.
  `WINDOW_DAYS` in `lua/util/undo.lua` is the single knob.

## Verification

`.agent/docs/specs/2026-08-17-undo-guard/e2e.sh` — in an isolated project with `undodir`
redirected, drives both the Claude Code and omp entry points, rewrites the files
externally, sweeps, quits without ever visiting them, then asserts in a fresh session that
`seq_last` is preserved and one `undo` returns the pre-agent line. A third file that was
never held is asserted to come back at `seq_last=0`, so the run also demonstrates the
failure mode it prevents. Per-group scripts live in
`.agent/docs/specs/2026-08-17-undo-guard/verify/`.
