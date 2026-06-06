---
description: Deep-read a Pi internal API, extension, prompt, or skill to build a working understanding before writing changes. Project-local override — checks local Pi package docs FIRST before any external sources.
---

# Learn (pi-agent-base)

Project-local override of `/learn` for harness work. The default `/learn` is general-purpose; this version always consults Pi's installed documentation first.

## Source priority (read in this order)

1. **Pi package docs** — `/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-coding-agent/docs/`
   - Cross-reference map: `.pi/agent-docs/standards/pi-apis.md`
   - Read the topic doc completely; follow `.md` links inside it before stopping.
2. **Pi package examples** — same install path under `examples/extensions/`, `examples/sdk/`, `examples/rpc-extension-ui.ts`
   - For any extension work, read at least one matching example before writing.
3. **Pi-tui docs** — `/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-tui/` (`README.md`, `dist/*.d.ts`)
4. **This repo's existing extensions** — `extensions/*.ts`, `extensions/_vim-powerline/`, `extensions/*.md` READMEs (especially `EXTENSION-CONFLICTS-EXPLAINED.md`, `PI-EXTENSION-ARCHITECTURE.md`, `README-VIM-POWERLINE.md`)
5. **Local `.d.ts` types** — `node_modules/@mariozechner/pi-coding-agent/dist/*.d.ts` for ground-truth API shapes
6. **External web search** — only if all of the above don't answer the question

## Steps

1. Identify the topic. If user gave a vague target (e.g. "how do extensions work"), ask once for the specific surface (extension API, prompt frontmatter, skill registration, custom editor component, etc.).
2. Walk source priority 1→6, stopping as soon as the question is answered.
3. Capture findings in `.pi/agent-docs/research/<slug>.md` with:
   - **Sources read** (file paths, not just topics)
   - **Key API shapes** (copy actual signatures from `.d.ts` or examples)
   - **Working example** (smallest possible snippet that demonstrates the concept)
   - **Gotchas** (anything from this repo's existing READMEs that documents known footguns — package load order, editor-component conflicts, etc.)
4. Report the path to the research doc.

## When the user says `/learn <topic>`

Treat the topic as scoped to Pi-agent-base concerns by default. If it's clearly a non-Pi topic (e.g. "/learn rsync flags"), fall back to the base `/learn` behavior.
