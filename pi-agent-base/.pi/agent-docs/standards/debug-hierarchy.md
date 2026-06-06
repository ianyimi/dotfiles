# Debug Hierarchy

When something breaks while working on `pi-agent-base/`, check sources in this order:

1. **Pi session terminal output** — Primary. Extension load failures, prompt parse errors, skill registration errors all surface on Pi startup. Look for stack traces referencing `~/.pi/agent/extensions/<file>.ts` or `~/.pi/agent/prompts/<file>.md`.
2. **TypeScript compiler output** — `npx tsc --noEmit <file>` against the edited `.ts` file. Catches type errors before runtime.
3. **Git diff (uncommitted changes)** — `git diff` from `pi-agent-base/` upward. Recent edits to `settings.json`, `AGENTS.md`, or top-level prompts are the most common cause of regressions because they affect every Pi session.
4. **`~/.pi/agent/` deployed copy** — After `cma`, the deployed tree should mirror `pi-agent-base/` exactly (minus runtime: `auth.json`, `sessions/`, `bin/`, `.git/`). If Pi behavior diverges from source, diff: `diff -r pi-agent-base/ ~/.pi/agent/ | head -50`.
5. **Chezmoi apply output** — Re-run `chezmoi diff` and inspect `run_after_sync-pi-agent-base.sh.tmpl` (in chezmoi parent) for rsync errors.
6. **IdeaLog** — `.pi/agent-docs/implementation-log/` for recent decisions about extension load order, package additions, or prompt rewrites.
7. **Pi docs** — `/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-coding-agent/docs/` — authoritative for extension API, settings schema, prompt frontmatter, skill format.

## Known Fragile Areas

| Area | Signs of trouble | Notes |
|------|-----------------|-------|
| `settings.json` `packages[]` order | One extension's UI features stop working (footer disappears, vim mode doesn't engage) when another package is added | Editor-component conflict — only one wins. Last loaded wins. See `extensions/README-VIM-POWERLINE.md`. |
| Prompt frontmatter | Prompt fails to register or appears under wrong name | Must have `---\ndescription: ...\n---` block. Some prompts also use `name:` and `invoke:`. Check working examples in `prompts/`. |
| Skill paths | `/<skill>` not found after `cma` | `settings.json → skills[]` array must include the absolute path to the skills directory. Currently `/Users/zaye/.pi/agent/skills` (deployed path, not source). |
| Top-level `.ts` extension imports | Module resolution fails at runtime | Pi loads with esbuild and resolves `@mariozechner/pi-coding-agent` from the global node_modules. Don't rely on local `node_modules`. |
| `_vim-powerline/` sub-package | Build outputs go stale | This is a separate buildable project — `cd extensions/_vim-powerline/vim && pnpm build` after edits. |
| chezmoi rsync exclusions | Runtime state lost | `run_after_sync-pi-agent-base.sh.tmpl` excludes `auth.json`, `sessions/`, `bin/`, `.git/` from the rsync. If those start getting clobbered on `cma`, check the exclude list. |
| Editing in `~/.pi/agent/` by mistake | Changes vanish on next `cma` | Always edit in `pi-agent-base/`. Symptom: an edit "works" until the next `cma`, then disappears. |
