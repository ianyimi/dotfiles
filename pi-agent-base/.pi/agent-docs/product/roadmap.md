# Roadmap

_Updated by the developer. Agent reads this for context when writing specs._

## Now
- Iterate on `prompts/0-project-init.md` and add specialized variants (e.g. `0-project-init-pnpm-monorepo.md`)
- Refine `extensions/browse.ts` Arc behavior (tab reuse, screenshot reliability)
- Keep `templates/*/SKILL.md` aligned with how `0-project-init` injects tokens

## Next
- Themes — populate `themes/` with at least one custom Pi theme
- Extract more reusable patterns from active project harnesses back into `templates/`
- Build a `/sync-harness` workflow that diffs project `.pi/` against base templates and surfaces drift

## Later
- Automated smoke test: spin up a throwaway Pi session against a temp config to catch broken prompts before `cma` deploys them globally
- Linux-side parity check for any extensions that assume macOS (Arc, AppleScript, screencapture)
