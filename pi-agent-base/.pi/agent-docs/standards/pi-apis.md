# Pi APIs — Where to Look

Authoritative Pi documentation lives in the installed npm package. **Always check these local files before web search or asking** — they are the source of truth for the version of Pi running on this machine.

## Base path

```
/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-coding-agent/
```

A shell variable for convenience: `PI_PKG=/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-coding-agent`

## Top-level entries

| File | When to read |
|------|--------------|
| `README.md` | First-pass overview of Pi |
| `docs/` | All topic guides — see table below |
| `examples/extensions/` | Real working extension examples — copy their patterns |
| `examples/sdk/` | SDK integration examples |
| `examples/rpc-extension-ui.ts` | RPC + custom UI extension example |

## Topic-to-doc map

| Topic | Doc |
|-------|-----|
| Writing a Pi extension (`registerTool`, `setEditorComponent`, lifecycle) | `docs/extensions.md` + `examples/extensions/` |
| Settings schema (`packages[]`, `skills[]`, `defaultProvider`, etc.) | `docs/settings.md` |
| Slash-prompt frontmatter and behavior | `docs/prompt-templates.md` |
| Skill format (`SKILL.md`, `name`, `description`, references) | `docs/skills.md` |
| Custom TUI components (`Text`, `Box`, modal editors) | `docs/tui.md` |
| Keybindings | `docs/keybindings.md` |
| Themes | `docs/themes.md` |
| SDK / programmatic use of Pi | `docs/sdk.md` |
| Adding a custom LLM provider | `docs/custom-provider.md` |
| Adding new models to a provider | `docs/models.md` |
| Pi package install/discover (`pi install npm:...`, `git:...`) | `docs/packages.md` |
| Conversation / session storage | `docs/session.md` |
| Auto-compaction behavior | `docs/compaction.md` |
| RPC bridge (extension ↔ TUI) | `docs/rpc.md` |
| Tree rendering helpers | `docs/tree.md` |
| Provider-level details | `docs/providers.md` |
| Shell aliases helper | `docs/shell-aliases.md` |
| Dev workflow for Pi itself | `docs/development.md` |
| Termux / Windows / terminal-setup quirks | `docs/termux.md`, `docs/windows.md`, `docs/terminal-setup.md` |
| JSON quirks / repair | `docs/json.md` |
| Tmux integration (built-in) | `docs/tmux.md` |

## Reading discipline

When working on extensions or harness changes:
1. Read the relevant `docs/<topic>.md` **completely** — they cross-reference each other.
2. Follow `.md` links to related docs before implementing.
3. For extension work, read at least one matching `examples/extensions/*.ts` before writing new code — the patterns there are the contract.
4. When in doubt about API shape, check `node_modules/@mariozechner/pi-coding-agent/dist/*.d.ts` for the actual exported types.

## Pi-tui

Helper UI library imported as `@mariozechner/pi-tui`. Same install path, sibling directory:

```
/Users/zaye/.local/share/fnm/node-versions/v23.11.1/installation/lib/node_modules/@mariozechner/pi-tui/
```

Read its `README.md` and `dist/*.d.ts` for `Text`, `Box`, layout primitives.
