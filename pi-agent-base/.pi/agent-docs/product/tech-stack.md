# Tech Stack

## Language + Runtime
- Primary: **TypeScript** (Pi extensions, loaded directly by `@mariozechner/pi-coding-agent` via esbuild at runtime — no build step for top-level files)
- Secondary: **Markdown** (prompts, skills, templates, docs)
- Tertiary: **Bash / chezmoi templates** (`run_after_sync-pi-agent-base.sh.tmpl` lives in chezmoi parent, not here)

## Repo Structure
- Type: **Sub-tree of the chezmoi dotfiles repo** (`https://github.com/ianyimi/dotfiles`)
- Synced to: `~/.pi/agent/` on every `cma` (chezmoi apply)
- Parent harness: `/Users/zaye/.local/share/chezmoi/.pi/` covers broader dotfiles work

## Directory Map

| Path | Purpose | Notes |
|------|---------|-------|
| `AGENTS.md` | Global agent context injected into every Pi session | Read by Pi at startup from `~/.pi/agent/AGENTS.md` |
| `WORKFLOW.md` | Authoritative chezmoi sync flow doc | Update if sync mechanics change |
| `settings.json` | Global Pi settings (provider, model, packages, skill paths) | `packages[]` order matters for editor-component conflicts |
| `keybindings.json` | Global keybindings | |
| `prompts/` | Global slash-prompts (`/dev-spec`, `/commit`, `/0-project-init`, etc.) | Available in every project that doesn't override |
| `templates/` | Project-init templates (`1-dev-spec/SKILL.md`, `2-sync-spec/SKILL.md`, `3-commit/SKILL.md`, `implement-spec/SKILL.md`) | Consumed by `/0-project-init` to scaffold per-project prompts |
| `skills/` | Loadable agent-os skills (`create-tasks`, `discover-standards`, `init-standards`, `inject-standards`, etc.) plus `excalidraw-diagram`, `sync-tmux-layout` | Path registered in `settings.json` → `skills[]` |
| `extensions/` | TypeScript extensions loaded by Pi at runtime | Top-level `*.ts` files are loaded directly. `_vim-powerline/` is a self-contained sub-package with its own build. |
| `docs/` | Misc internal docs | |
| `themes/` | Pi UI themes | Currently empty |

## Pi Extension API
- Package: `@mariozechner/pi-coding-agent` (npm global, currently at fnm v23.11.1 install)
- Helper UI: `@mariozechner/pi-tui` (Text, Box, etc.)
- Local docs: `/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-coding-agent/docs/`
- Local examples: same path, under `examples/extensions/`, `examples/sdk/`
- See `.pi/agent-docs/standards/pi-apis.md` for the full topic-to-doc map.

## Active Top-Level Extensions

| File | Purpose |
|------|---------|
| `extensions/browse.ts` | Arc + AppleScript + screencapture → screenshot any URL, reuse existing tab at same origin |
| `extensions/ask-user-question.ts` | Structured multi-tab TUI questions |
| `extensions/auto-unescape-paths.ts` | Cleans escaped paths in user input |
| `extensions/screenshot.ts` | Screenshot helper |
| `extensions/tmux-monitor.ts` | Watch tmux pane output |
| `extensions/progress-tracker.ts` | Long-running task progress UI |
| `extensions/setup-tools.ts` | Bootstrap helpers |
| `extensions/vim-powerline.ts` | Glue file (separate from `_vim-powerline/` sub-package) |

## Sub-Package: `extensions/_vim-powerline/`
- Has its own `package.json` and `tsconfig.json` under `vim/` and `powerline/`
- Compiles its own bundle separate from the runtime-loaded top-level extensions
- See `extensions/README-VIM-POWERLINE.md` and `extensions/EXTENSION-CONFLICTS-EXPLAINED.md`

## Installed Pi Packages (per `settings.json`)

| Package | Source | Purpose |
|---------|--------|---------|
| `pi-btw` | npm | Misc utilities |
| `pi-docparser` | npm | LiteParse `document_parse` tool |
| `lsp-pi` | npm | Language-server `lsp` tool |
| `@browser-annotations/pi` | npm | Browser annotation overlays |
| `pi-smart-fetch` | npm | `web_fetch` / `batch_web_fetch` tools |
| `pi-image-preview` | git (ianyimi) | Inline image previews |

## Workflow Tier
- Tier: **Low-care**
- Rule: Agent can implement extension/prompt/skill changes directly. After every change, agent runs typecheck + (where applicable) local build, then prompts the user to run `cma` and restart Pi to verify.
- Exception: Changes to `settings.json` `packages[]` order, the global `AGENTS.md`, or the `0-project-init.md` prompt should be flagged for explicit user review before writing — they affect every Pi session globally.
