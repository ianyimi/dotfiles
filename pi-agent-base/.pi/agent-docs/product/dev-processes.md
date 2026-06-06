# Dev Processes

## Core Workflow

```
edit pi-agent-base/<file>
    ↓
typecheck (if .ts)         ← agent runs
    ↓
local build (if sub-pkg)   ← agent runs
    ↓
cma                        ← user runs (requires Bitwarden session)
    ↓
restart Pi                 ← user runs
    ↓
verify behavior in fresh Pi session
```

## Dev Commands

| Command | What it does | Run by |
|---------|-------------|--------|
| `npx tsc --noEmit <file>` | Typecheck a single top-level extension file | agent (after edit) |
| `cd extensions/_vim-powerline/vim && pnpm build` | Build the vim sub-package | agent (after edits there) |
| `cd extensions/_vim-powerline/vim && pnpm test` | Run vim sub-package vitest suite | agent (after edits there) |
| `cma` | Apply chezmoi → sync `pi-agent-base/` to `~/.pi/agent/` + reload shell | **user only** (needs Bitwarden) |
| `chezmoi diff` | Preview chezmoi changes before applying | user or agent |
| `pi` | Restart Pi with updated config | user |
| `pi update` | Reinstall packages listed in `settings.json` | user (only if `packages[]` changed) |

## Verification Loop

After agent makes changes:
1. **Typecheck** — for any edited `.ts` file:
   - Top-level: `npx tsc --noEmit --target es2022 --module esnext --moduleResolution bundler extensions/<file>.ts` (Pi loads with esbuild at runtime, but tsc catches type errors)
   - Sub-package (`_vim-powerline/vim/`): `cd extensions/_vim-powerline/vim && pnpm typecheck` (uses local `tsconfig.json`)
2. **Build** — only if a sub-package was touched: `pnpm build` in that sub-package
3. **Test** — only if `_vim-powerline/vim/` test files exist and were affected: `pnpm test`
4. **Report** — agent reports typecheck/build/test results, then says: *"Ready — run `cma` and restart Pi to test."*
5. **User verifies** in a fresh Pi session.

The agent does **not** run `cma` itself (it requires a live Bitwarden session and side-effects across the whole filesystem).

## Testing
- Status: **Partial** — only `extensions/_vim-powerline/vim/test/` has automated tests (vitest, motions + modal-editor)
- Top-level extensions, prompts, skills, and templates have **no automated tests**. Verification is manual via fresh Pi sessions.

## Error Surfaces (Debug Hierarchy)

When something breaks, errors appear in:

1. **Pi session terminal output** — Primary surface. Extension load errors, prompt parse errors, skill registration errors all surface here on Pi startup.
2. **TypeScript compiler output** — Type errors before runtime. Agent runs `tsc --noEmit` after every `.ts` edit.
3. **Chezmoi apply output** — Sync errors, template render failures. Run `chezmoi diff` to preview, `cma` to apply.
4. **`~/.pi/agent/` after `cma`** — Inspect the deployed result if Pi behavior diverges from the source. Should always exactly mirror `pi-agent-base/` (minus runtime files: `auth.json`, `sessions/`, `bin/`, `.git/`).
5. **Pi session logs / transcript** — For runtime extension errors during a session.

## Background Services

None required for editing `pi-agent-base/`. To deploy via `cma`:

| Service | Purpose | Check |
|---------|---------|-------|
| **Tailscale** | Reach self-hosted Bitwarden | `tailscale status` |
| **Bitwarden CLI session** | Render chezmoi templates that reference vault items | `bw unlock --check` (or `bwsr`) |

## Rules of Thumb

- **Always edit here, never in `~/.pi/agent/`** — the deployed copy gets clobbered on every `cma`.
- **`packages[]` order in `settings.json` matters** — last-loaded extension wins editor-component slots. See `extensions/README-VIM-POWERLINE.md`.
- **New skill?** Drop the directory in `skills/<name>/` with a `SKILL.md`. The path is already registered in `settings.json → skills[]`.
- **New global prompt?** Drop a `.md` file in `prompts/` with a frontmatter `description`. It becomes available as `/<filename>` after `cma` + Pi restart.
- **New project-init template?** Add a directory under `templates/<name>/SKILL.md`, then add a wrapper prompt at `prompts/0-project-init-<type>.md` that pre-fills answers and dispatches to base `0-project-init.md`.
