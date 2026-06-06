---
name: 2-sync-spec
description: Extract recurring patterns from recent pi-agent-base work into developer-preferences.md and refine prompts. Run after a feature is merged or after several harness changes have accumulated.
invoke: "sync-spec"
---

# Sync Spec — pi-agent-base

Extract patterns from recent harness work and feed them back into the agent's standing instructions. Project-local — patterns extracted here are scoped to harness work, not general TypeScript conventions.

## Pattern categories to scan for

| Category | What to look for |
|----------|-----------------|
| **Extension structure** | Imports, lifecycle hooks, error handling, how `ctx.ui` and `ctx.tools` are used |
| **TUI patterns** | Recurring uses of `Text`, `Box`, modal editors, layout primitives from `@mariozechner/pi-tui` |
| **Prompt frontmatter** | What fields are consistently set (`name`, `description`, `invoke`); recurring section structures inside prompts |
| **Skill format** | Conventions for `SKILL.md` (description style, references block, step numbering) |
| **Template tokens** | New `{{TOKEN}}` placeholders introduced in `templates/*/SKILL.md` and how `0-project-init.md` injects them |
| **Naming** | File naming (kebab-case for prompts, what for extensions?), prompt invoke aliases |
| **Settings.json discipline** | Package additions, ordering rules, when to flag for review |
| **chezmoi/cma flow** | Any deviations from the standard "edit → typecheck → cma → restart Pi" loop |

## Steps

1. **Survey recent work** — git log + diffs since the last sync-spec run, plus open specs in `.pi/agent-docs/specs/`.
2. **Identify deviations** — any place where the agent's draft differed from what the user actually committed. Each deviation is a candidate pattern.
3. **Append to `developer-preferences.md`** — one entry per real pattern:
   ```
   - <pattern> → <why> → <YYYY-MM-DD>
   ```
   Don't append fluff. If recent work shows no new patterns, say so and stop.
4. **Refine prompts** — if a pattern is universal enough, update the corresponding prompt (`1-dev-spec.md`, etc.) directly.

## Upkeep tasks (run after extraction)

In order:

1. `npx tsc --noEmit` against any `.ts` files touched in the survey window — confirms still typechecks.
2. If `extensions/_vim-powerline/vim/` was touched: `cd extensions/_vim-powerline/vim && pnpm typecheck && pnpm test`.
3. **Skip** roadmap updates unless the user explicitly mentions a roadmap item completed.
4. **Skip** doc regeneration — there is no auto-doc step in this repo.
5. Close any specs in `.pi/agent-docs/specs/` whose `plan.md` is fully implemented (move to `.pi/agent-docs/specs/closed/`).
6. Tell the user: *"Sync complete. Run `cma` if any prompts were updated."*

## Don'ts

- Don't add patterns based on a single occurrence — wait for a second instance before promoting it to `developer-preferences.md`.
- Don't rewrite prompts based on speculative future needs. Only patterns observed in actual recent work.
- Don't attempt to run `cma`.
