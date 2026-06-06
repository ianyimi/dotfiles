# Mission

`pi-agent-base/` is a development environment for building and refining the **global Pi agent harness** — TypeScript extensions, prompt templates, agent-os skills, and project-init templates that ship to every Pi session on this machine.

Edits here flow through chezmoi to `~/.pi/agent/` on `cma`, where they become live for all Pi sessions across all projects.

## Current Focus

- Maintain and extend the global prompt library (`prompts/`)
- Build and refine TypeScript extensions in `extensions/` (browse, ask-user-question, vim-powerline, tmux-monitor, screenshot, etc.)
- Curate agent-os skills under `skills/agent-os/` and other skill packages
- Iterate on the project-init templates (`templates/`) consumed by `/0-project-init`
- Keep `WORKFLOW.md` accurate as the chezmoi sync flow evolves

## Constraints + Non-Goals

- **Never edit `~/.pi/agent/` directly** — it is overwritten by chezmoi on every `cma`. Always edit here in `pi-agent-base/`.
- **Never break existing prompts silently** — these are loaded by every Pi session. Test by running `cma`, then start a fresh Pi session.
- **Don't introduce build steps for top-level `extensions/*.ts`** — Pi loads them directly with esbuild at runtime. Only sub-packages like `extensions/_vim-powerline/vim/` have their own `tsconfig.json` + build step.
- **Respect package load order in `settings.json`** — see `extensions/README-VIM-POWERLINE.md`. Editor-component conflicts (e.g. `pi-vim` vs `pi-powerline-footer`) depend on the order in the `packages` array.
- This is **scoped to `pi-agent-base/` only**. Broader chezmoi/dotfiles work belongs in the parent harness at `/Users/zaye/.local/share/chezmoi/.pi/`.
