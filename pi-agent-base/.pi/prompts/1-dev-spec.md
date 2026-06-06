---
name: 1-dev-spec
description: Write a scoped implementation spec for a pi-agent-base change — new extension, prompt rewrite, skill, or template update. Produces plan.md, shape.md, and references.md in .pi/agent-docs/specs/<slug>/.
invoke: "dev-spec"
---

# Dev Spec — pi-agent-base

Write a focused implementation spec for a change to the global Pi harness source. Project-local: pre-populated with this repo's stack, workflow tier, and verification loop so the agent never guesses.

## Pre-loaded context

- **Stack**: TypeScript (loaded directly by Pi at runtime via esbuild) + Markdown prompts/skills/templates. See `.pi/agent-docs/product/tech-stack.md`.
- **Workflow tier**: Low-care — agent can implement directly. Exception: changes to `settings.json` `packages[]` order, the global `AGENTS.md`, or `prompts/0-project-init.md` must be flagged for explicit user review before writing (they affect every Pi session globally).
- **Verification**: typecheck (top-level `.ts`) or build+test (`_vim-powerline/` sub-pkg) → user runs `cma` → user restarts Pi. See `.pi/agent-docs/standards/verification.md`.
- **Pi APIs**: see `.pi/agent-docs/standards/pi-apis.md` for the topic-to-doc map of installed Pi documentation.

## What this prompt produces

Create `.pi/agent-docs/specs/<YYYY-MM-DD>-<slug>/` with:

### `plan.md`
- **Goal** (1–2 sentences)
- **Scope** — exact list of files to add/modify in `pi-agent-base/`
- **Out of scope** — explicit non-goals
- **Risk surface** — does this change affect every Pi session? (yes if it touches global `AGENTS.md`, `settings.json`, or `prompts/0-project-init.md`; flag for review)
- **Verification steps** — concrete commands the agent will run before reporting done

### `shape.md`
- File-by-file outline with:
  - Path
  - Purpose
  - Key signatures or sections (TypeScript exports, prompt frontmatter, skill metadata)
  - Numbered comment stubs for the implementer
- For TypeScript extensions: include the imports from `@mariozechner/pi-coding-agent` and `@mariozechner/pi-tui` that will be used, copied from real signatures (don't guess)

### `references.md`
- **Pi docs read**: list specific files from `/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-coding-agent/docs/`
- **Examples consulted**: list specific `examples/extensions/*.ts` files
- **Existing repo files referenced**: list relevant `extensions/*.ts`, READMEs, prompts, etc.

## Steps

1. **Clarify scope**. If the user request is vague, ask one structured question via `ask_user_question` to narrow it (e.g. "new top-level extension or sub-package?", "global prompt or template for /0-project-init?").
2. **Read Pi docs first**. Before drafting `shape.md`, consult the relevant `docs/*.md` from the Pi install path. For extensions, also read at least one example.
3. **Check this repo for prior art**. Grep `extensions/` for similar patterns. Don't invent new patterns when an existing one works.
4. **Draft the three files** in `.pi/agent-docs/specs/<slug>/`.
5. **Pause for review** before any implementation if the change is in the "exception" list above (global AGENTS.md, settings.json packages order, 0-project-init.md). Otherwise proceed to implement directly per low-care tier.
6. **Implement**, then run the verification steps from `plan.md`, then report: *"Verification clean. Run `cma` and restart Pi to test."*

## Don'ts

- Don't propose a build step for top-level `extensions/*.ts` files — Pi loads them directly.
- Don't edit `~/.pi/agent/` ever. All edits go in `pi-agent-base/`.
- Don't run `cma` yourself — it requires Bitwarden and is the user's responsibility.
- Don't modify `settings.json` `packages[]` order without an explicit user-confirmed rationale; package order controls editor-component winners.
