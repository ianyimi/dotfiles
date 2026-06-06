# pi-agent-base — Agent Context

> You are working **inside the source of truth for the global Pi agent harness**. Edits here are deployed to `~/.pi/agent/` on every `cma` (chezmoi apply) and become live for every Pi session on this machine.

## Critical rules (read first)

1. **Never edit `~/.pi/agent/` directly.** It is overwritten on every `cma`. Always edit here in `pi-agent-base/`.
2. **Never run `cma` yourself.** It requires a live Bitwarden session and side-effects across the whole filesystem. Your job ends at "typecheck + build clean — ready for `cma`."
3. **The `.pi/` directory you are reading from is excluded from chezmoi sync** (via `run_after_sync-pi-agent-base.sh.tmpl`). It exists only as the meta-harness for editing this repo. Do not deploy it.
4. **Flag for explicit user review before writing** any change that touches:
   - `pi-agent-base/AGENTS.md` (global agent context for every Pi session)
   - `pi-agent-base/settings.json` (especially `packages[]` order)
   - `pi-agent-base/prompts/0-project-init.md` (consumed by every project init)

## Mission
→ `.pi/agent-docs/product/mission.md`

A development environment for building and refining the global Pi agent harness — TypeScript extensions, prompt templates, agent-os skills, and `0-project-init` templates that ship via chezmoi to `~/.pi/agent/` on every `cma`.

## Stack at a glance
- **TypeScript** — top-level `extensions/*.ts` loaded directly by Pi at runtime (no build); `extensions/_vim-powerline/` is a self-contained sub-package with its own `package.json` + `tsconfig.json` + vitest
- **Markdown** — `prompts/`, `skills/`, `templates/`, docs
- **Chezmoi** — sync layer; `pi-agent-base/` → `~/.pi/agent/` on `cma`
- Full stack details: `.pi/agent-docs/product/tech-stack.md`

## Workflow Tier
**Low-care** — agent can implement directly. Exceptions in the "Critical rules" list above require user review first.

## Dev workflow

```
edit file
  ↓
agent: typecheck (.ts) + build (sub-pkg only)
  ↓
agent reports: "Ready — run cma and restart Pi"
  ↓
user: cma
  ↓
user: restart Pi
  ↓
verify in fresh Pi session
```

Full details: `.pi/agent-docs/product/dev-processes.md` and `.pi/agent-docs/standards/verification.md`.

## Pi APIs — where to look
**Always consult installed Pi docs before web search.** Path:

```
/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-coding-agent/docs/
```

Topic-to-doc map: `.pi/agent-docs/standards/pi-apis.md`. Examples: same install path under `examples/`.

## Debug Hierarchy
→ `.pi/agent-docs/standards/debug-hierarchy.md`

Quick: Pi terminal output → `tsc --noEmit` → `git diff` → diff `~/.pi/agent/` vs source → chezmoi apply output → ideaLog.

## Active Specs
→ `.pi/agent-docs/specs/` (none yet)

## IdeaLog
→ `.pi/agent-docs/implementation-log/`

Latest: `2026/05/2026-05-06.ideaLog.md` — meta-harness setup.

## Prompts available

| Prompt | Invoke | Purpose |
|--------|--------|---------|
| 1-dev-spec | `/dev-spec` | Write scoped spec for a harness change (extensions, prompts, skills, templates) |
| 2-sync-spec | `/sync-spec` | Extract recurring patterns from recent harness work into developer-preferences.md |
| 3-commit | `/commit` | Stage + commit; `cd`s up to chezmoi root, scopes message as `type(pi-base): ...` |
| learn | `/learn` | Project-local override — Pi installed docs read first |
| research | `/research` | Project-local override — Pi installed docs read first |

Base prompts (`/debug`, `/build-prompt`, `/excalidraw-diagram`, `/sync-tmux-layout`, `/templatize`, `/review`, `/document`, `/sync-harness`) come from the global harness unchanged.

## Repository layout (high-level)

```
pi-agent-base/
├── AGENTS.md            ← global agent context (loaded by every Pi session)
├── settings.json        ← global Pi settings — packages[] order matters
├── keybindings.json
├── WORKFLOW.md          ← chezmoi sync workflow doc
├── prompts/             ← global slash-prompts (deployed to ~/.pi/agent/prompts/)
├── templates/           ← /0-project-init templates (1-dev-spec, 2-sync-spec, 3-commit, implement-spec)
├── skills/              ← agent-os + custom skills (loaded via settings.json skills[])
├── extensions/          ← TypeScript extensions
│   ├── *.ts             ← top-level: loaded directly at runtime (no build)
│   ├── _vim-powerline/  ← sub-package with its own build (pnpm)
│   └── *.md             ← architecture/conflict docs — read these before extension work
├── docs/
├── themes/              ← currently empty
└── .pi/                 ← THIS meta-harness (excluded from chezmoi sync)
```
