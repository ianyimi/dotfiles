# Verification Loop

How the agent checks that changes to `pi-agent-base/` are working before reporting back.

## Method
**TypeScript typecheck + local build (sub-packages) + manual user verification after `cma`.**

The agent does **not** run `cma` itself — it requires a Bitwarden session and side-effects across the whole filesystem. The agent's job ends at "typecheck + build clean — ready for `cma`."

## Per-File-Type Checklist

### `extensions/<file>.ts` (top-level)
1. `npx tsc --noEmit --target es2022 --module esnext --moduleResolution bundler --skipLibCheck --esModuleInterop extensions/<file>.ts`
2. If it imports from `@mariozechner/pi-coding-agent` or `@mariozechner/pi-tui`, those resolve from the global node_modules at `/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/`. If tsc complains it can't find them, add `--paths` or just ensure imports use the published types.
3. Report typecheck result.
4. Tell user: *"Typecheck clean. Run `cma` and restart Pi to test."*

### `extensions/_vim-powerline/vim/**` or `extensions/_vim-powerline/powerline/**`
1. `cd extensions/_vim-powerline/vim && pnpm typecheck` (or in `powerline/`)
2. `pnpm build`
3. `pnpm test` if test files were touched
4. Report all three results.
5. Tell user: *"Build + tests pass. Run `cma` and restart Pi to test."*

### `prompts/<file>.md`
1. Verify frontmatter is valid: starts with `---`, has at least `description:`, ends with `---`.
2. Verify referenced files/paths in the prompt body exist.
3. No automated check beyond that — prompts are interpreted at runtime by Pi.
4. Tell user: *"Prompt updated. Run `cma` and restart Pi, then invoke `/<name>` to test."*

### `skills/<name>/SKILL.md` or new skill directories
1. Verify `SKILL.md` exists at the skill root.
2. Verify frontmatter has `name:` and `description:`.
3. Tell user: *"Skill updated. Run `cma` and restart Pi to load."*

### `templates/<name>/SKILL.md`
1. These are consumed by `/0-project-init`. Verify the token placeholders (`{{PROJECT_NAME}}`, `{{TECH_STACK_SUMMARY}}`, etc.) match what `0-project-init.md` actually injects.
2. No runtime check. User tests by running `/0-project-init` in a throwaway directory after `cma`.

### `settings.json`
1. Validate JSON: `python3 -m json.tool settings.json > /dev/null` or `jq . settings.json > /dev/null`.
2. **Flag for user review before writing** if changes touch `packages[]` order or `defaultProvider`/`defaultModel` — these affect every Pi session.
3. Tell user: *"settings.json updated. Run `cma`. If `packages[]` changed, also run `pi update`. Restart Pi."*

### `AGENTS.md` (root global one)
1. **Flag for user review before writing** — this is the global agent context for every Pi session on this machine.
2. After approval: render check (just a markdown-syntax sanity scan).
3. Tell user: *"Global AGENTS.md updated. Run `cma` and restart Pi."*

### `WORKFLOW.md`, `keybindings.json`, `themes/**`
- Light syntax check; otherwise manual.

## Dev Server / tmux
There is no long-running dev server. Verification happens in fresh Pi sessions started by the user. The agent does not need to monitor a tmux pane during this work.

## Standard Reporting Format

After verification, the agent reports in this shape:

```
✓ Typecheck: clean
✓ Build: clean (extensions/_vim-powerline/vim/dist updated)
✓ Tests: 14 passing

Ready — run `cma` and restart Pi to test the change in a fresh session.
```

If any step fails, stop, report the failure, and propose a fix. Do not tell the user to `cma` until everything is clean.
