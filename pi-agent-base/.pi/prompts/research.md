---
description: Investigate a Pi API, extension pattern, or library and produce a concise findings doc. Project-local override — Pi installed docs are consulted first, then this repo's existing extensions/READMEs, then external sources.
---

# Research (pi-agent-base)

Project-local override of `/research`. Identical purpose to base, but with a fixed source-priority order tuned for harness work.

## Source priority

1. **Prior research in this repo** — `.pi/agent-docs/research/` (avoid duplicating work)
2. **Pi installed docs** — `/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-coding-agent/docs/` — see `.pi/agent-docs/standards/pi-apis.md` for the topic map
3. **Pi installed examples** — same path, under `examples/`
4. **Pi-tui** — `/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-tui/`
5. **This repo's READMEs in `extensions/`** — `EXTENSION-CONFLICTS-EXPLAINED.md`, `PI-EXTENSION-ARCHITECTURE.md`, `README-VIM-POWERLINE.md`, `vim-powerline-fix.md`
6. **TypeScript declarations** — `node_modules/@mariozechner/pi-coding-agent/dist/*.d.ts` and `@mariozechner/pi-tui/dist/*.d.ts`
7. **External web sources** — `web_fetch` / `batch_web_fetch` only after the above are exhausted

## Steps

1. Check `.pi/agent-docs/research/` for an existing doc on the topic. If found, summarize and ask whether to update it or write a new one.
2. Walk source priority 2→7, gathering only what's needed to answer the specific question.
3. Write findings to `.pi/agent-docs/research/<slug>.md` with sections:
   - **Question**
   - **Answer** (concise)
   - **Sources** (full paths, not just titles)
   - **Code references** (file:line ranges, or copied snippets ≤20 lines)
   - **Open questions** (anything still unclear)
4. Report the path. Do not paste the full doc into chat unless the user asks.

## Discipline

- Read `.md` files completely — don't skim.
- Follow cross-references between `docs/*.md` files.
- Never paraphrase API signatures from training data; always copy from `.d.ts` or `examples/`.
- If external search is used, prefer official Pi GitHub repo over blog posts.
