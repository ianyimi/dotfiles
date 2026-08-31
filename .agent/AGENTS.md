# dotfiles — Agent Context

## Agent Directives

These apply to all agents, all platforms, always.

**Route by intent.** Classify what the user needs (debug / spec / implement /
commit / general) and load the appropriate skill from `.agent/skills/`.
**Ask before large actions.** Ambiguous multi-file requests get one clarifying
question first.
**Surface cascade impacts before writing.** Show the complete downstream change
set for approval before applying any of it.
**Doctor first.** On session start, run `harness doctor`. Fix errors before work.
**Write knowledge to the graph.** Corrections → anti-patterns.md. Patterns →
preferences.md. Naming → naming-conventions.md. Decisions → decisions/.
Sessions → session-log/.
**Advisor active?** (OMP harness-keeper) Focus on the developer's problem; act on the
advisor's harness change-sets instead of self-tracking requirement shifts mid-task.
**Subagents:** honor `manifest.json#models` — dynamic selection = cheapest adequate tier.
**Harness edits land in `harness/src/templates/`** — generalized for any project.
Root `.agent/` is this repo's local clone, never the upstream.

## Repo layout — where edits go

This repo is three things at once. Confusing them puts changes where no project can
ever receive them:

- `harness/` — **the MAIN harness**: the `harness` CLI source and the generic templates
  in `harness/src/templates/` (skills, agent docs, standards seeds). `harness fetch`
  ships ONLY these files — this is the upstream every project pulls from. Harness
  features, skill changes, and workflow updates go HERE, written generically
  (`{{PROJECT}}`-style placeholders, no dotfiles specifics), verified with
  `cd harness && bun test`.
- `.agent/` — the dotfiles PROJECT's harness install: a local clone that manages this
  repo's own dotfiles work, a consumer like any other project. It takes template updates
  via `/harness-pull` and carries only dotfiles-specific hardening. A change made only
  here reaches no other project.
- Everything else — chezmoi-managed dotfiles (`dot_config/`, …), some containing their
  own nested `.agent/` installs (e.g. `dot_config/nvim/.agent/`). Never edit those as
  part of harness work.

Routing rule: harness improvement → `harness/src/templates/` first, generalized; mirror
into `.agent/` only when this repo should also use it immediately. Dotfiles-only
preference → `.agent/` only. Main-repo-only skills (e.g. harness-cherry-pick) →
`.agent/skills/` only, marked "not shipped" in their description.

## Pointers

- Harness guide (read before editing `.agent/`): `.agent/docs/harness-guide.md`
- Mission: `.agent/docs/product/mission.md`
- Tech stack: `.agent/docs/product/tech-stack.md`
- Dev processes: `.agent/docs/product/dev-processes.md`
- Standards: `.agent/docs/standards/`
- Current state: run `harness state`
