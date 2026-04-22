---
name: 1-dev-spec
description: Write a scoped implementation spec for a feature or change. Produces plan.md, shape.md, standards.md, and references.md in .pi/agent-docs/specs/. Evolves per project via sync-spec.
invoke: "dev-spec"
---

# Dev Spec

---

## Project Context

**Project:** chezmoi dotfiles
**Stack:** Shell scripting (Bash/Zsh), chezmoi for templating and dotfile management, Bitwarden CLI for secret injection, Ansible for macOS system automation
**Workflow tier:** Agent can implement fully. Make changes directly to dotfiles, scripts, and configurations.

<!-- sync-spec:dev-commands -->
**Dev commands:**
| Command | What it does |
|---------|-------------|
| `cma` | **Apply dotfiles** — Check Bitwarden session, sync vault, apply all changes, reload shell |
| `cm diff` | Preview what would change before applying |
| `cm add <file>` | Track a new file in chezmoi |
| `cme <file>` | Edit a tracked file with live preview (`chezmoi edit --watch`) |
| `./bootstrap.sh` | Full setup from scratch — installs Homebrew, Tailscale, Bitwarden, applies dotfiles |
| `lgChezmoi` | Open lazygit in chezmoi source directory |
<!-- /sync-spec:dev-commands -->

<!-- sync-spec:monorepo-packages -->
<!-- /sync-spec:monorepo-packages -->

---

## When to use

Run `dev-spec` when:
- Adding new tool configurations (tmux, Neovim plugins, shell aliases)
- Creating new chezmoi templates
- Modifying Ansible playbooks or bootstrap scripts
- Building new automation scripts
- Refactoring existing dotfile structure

Skip dev-spec only for: single alias additions, typo fixes, version bumps in existing configs.

---

> **Questions:** Use the `ask_user_question` tool for every question in this skill. Never write question lists as plain text.

## Spec interview

Use `ask_user_question` for every question in this section. Never write question blocks as plain text.

### Phase 1 — Scope

Ask:
> What are we building? Give a one-line description of the feature or change.

Ask:
> What files or directories will this touch? (dotfiles, scripts, templates, playbooks)

Ask:
> Which platform(s)? Darwin only, Linux only, or both? (Check for existing darwin/ or linux/ specific versions.)

Ask:
> Are there any parts of the dotfiles this spec must NOT touch?

Ask:
> Is there an existing spec for this in `.pi/agent-docs/specs/`? If yes, are we continuing or starting fresh?

### Phase 2 — Shape

Ask:
> What are the inputs and outputs? (Environment variables, Bitwarden secrets, file templates, installed packages.)

Ask:
> Does this require new Bitwarden secrets? If yes, specify the item name and field keys expected. (Don't create them — just document what the template will reference.)

Ask:
> Are there new dependencies to install? (Homebrew packages, Node packages, etc.) Should they go in the Ansible playbook or a run_once script?

Ask:
> What are the edge cases? (Missing secrets, platform differences, existing file conflicts, chezmoi apply failures.)

### Phase 3 — Standards check

Read `.pi/agent-docs/standards/developer-preferences.md`. For each preference that applies to this spec, note it. Do not ask the developer to re-confirm standing rules — just apply them.

If a preference is ambiguous for this specific feature, ask one targeted question.

### Phase 4 — References

Identify files the developer will need to read before implementing:
- Existing dotfiles or templates being modified
- Ansible playbook structure
- chezmoi template syntax examples
- Bitwarden CLI integration patterns
- Recent ideaLog entries that affect this feature

---

## Build order rule

Specs must be ordered so each step produces something testable before the next step begins.

**Build order for dotfile changes:**
1. Dependencies first (Ansible tasks, Homebrew packages, run_once scripts)
2. Static config files (no templating) — test with `cm diff`
3. Templates that reference secrets — test with `cma` (requires Bitwarden session)
4. Dependent configs (configs that reference the new tool) — test full workflow
5. Documentation updates (README, comments in complex templates)

After drafting the spec, self-check: can we run `cma` after step N and have a working system before step N+1? If not, reorder.

---

## Spec output format

Create `.pi/agent-docs/specs/YYYY-MM-DD-HHMM-<feature-slug>/` with four files:

### plan.md

```markdown
# <Feature Name> — Plan

## Summary
<one paragraph — what this builds and why>

## Build Order
- [ ] Step 1: <what + testable outcome>
- [ ] Step 2: <what + testable outcome>
- [ ] Step 3: <what + testable outcome>
...

## Out of scope
- <thing explicitly excluded>
```

### shape.md

Full boilerplate and implementation guidance:
- New file paths in chezmoi source structure
- Complete template syntax for Bitwarden lookups:
  ```
  {{ (bitwarden "item" "my-item-name").login.password }}
  {{ (bitwarden "item" "my-item-name").fields.apiKey }}
  ```
- Ansible task definitions (complete YAML blocks)
- Shell script structure with numbered comment guidance:
  ```bash
  # 1. Check if required command exists — exit early if missing
  # 2. Fetch value from Bitwarden or environment
  # 3. Validate input — handle missing/malformed data
  # 4. Apply configuration
  # 5. Verify result — check exit code or file existence
  ```
- Expected file permissions and ownership (especially for secrets)

Platform-specific files:
- Use chezmoi's naming: `darwin/file.tmpl` or `linux/file.tmpl`
- Or use `{{ if eq .chezmoi.os "darwin" }}` in templates

### standards.md

```markdown
# Standards for This Spec

## Applied preferences
<list each rule from developer-preferences.md that applies here>

## Spec-specific conventions
<any one-off rules for this feature>

## Known gotchas
- Platform-specific paths (e.g., Homebrew location: /opt/homebrew on ARM, /usr/local on Intel)
- Bitwarden session expiration during apply
- chezmoi apply order (run_once scripts execute before templates)
- File conflicts on first apply (existing files not yet tracked)
```

### references.md

```markdown
# References

## Files to read before implementing
- `<path>` — <why>

## Docs
- chezmoi templating: https://www.chezmoi.io/user-guide/templating/
- Bitwarden CLI: https://bitwarden.com/help/cli/

## Related specs
- `<path>` — <relationship>
```

---

## Workflow tier behavior

Agent can implement fully. Make changes directly to dotfiles, scripts, and configurations.

<!-- sync-spec:workflow-tier-detail -->
**Low-care tier:**
- Agent implements code directly from the spec's `shape.md` and numbered comments
- Agent runs `cm diff` to verify changes before applying
- Agent runs `cma` to test the full workflow (requires Bitwarden session)
- Agent reports completion with verification results

**Exception for secrets:**
- Never modify Bitwarden vault structure or create new secret items
- Never change existing `{{ bitwarden ... }}` template references without explicit approval
- New secret references must be documented in the spec and confirmed before implementation
<!-- /sync-spec:workflow-tier-detail -->

---

## After presenting the spec

Ask:
> Does this spec look right? Anything to add, remove, or change before implementing?

On approval:
- For **low-care tier**: proceed with implementation immediately unless user says otherwise
- Save spec to `.pi/agent-docs/specs/YYYY-MM-DD-HHMM-<slug>/`
- After implementation completes, remind: "Run `sync-spec` to extract patterns from this implementation."

---

## Developer preferences

<!-- sync-spec:developer-preferences -->
_No preferences recorded yet. Run `sync-spec` after your first implementation to start building this section._
<!-- /sync-spec:developer-preferences -->

---

## Continuous improvement

This file evolves. Every `sync-spec` run extracts patterns from how changes were implemented and updates the `<!-- sync-spec:* -->` sections above. Over time, specs require fewer corrections and match the developer's actual workflow.

→ see `.pi/agent-docs/standards/developer-preferences.md` for the full audit trail
