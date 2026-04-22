---
description: Extract the current project's Pi harness into a reusable 0-project-init-<type>.md template. Goes back and forth with the developer to separate what's project-specific from what should be a pre-configured default for all future projects of the same type.
invoke: templatize
---

# Templatize Project Setup

Turn this project's Pi harness into a reusable init template for future projects that share the same technology stack. The result is a new `~/.pi/agent/prompts/0-project-init-<type>.md` that future projects can invoke with `/0-project-init-<type>` to skip detection phases and get a head start.

> **Questions:** Use the `ask_user_question` tool for every structured question. Never write question lists as plain text.

---

## Step 1 — Read the current harness

Read all of the following that exist:

- `.pi/AGENTS.md` — project context and prompts list
- `.pi/agent-docs/product/tech-stack.md` — language, stack, libraries, workflow tier
- `.pi/agent-docs/product/dev-processes.md` — dev commands, test runner, verification method
- `.pi/agent-docs/product/mission.md` — project mission (to understand what's specific vs generic)
- `.pi/agent-docs/standards/debug-hierarchy.md` — debug order
- `.pi/agent-docs/standards/verification.md` — verification loop config
- `.pi/prompts/1-dev-spec.md` — verify commands and workflow tier
- `.pi/prompts/2-sync-spec.md` — upkeep tasks
- `.pi/prompts/3-commit.md` — commit conventions

Announce what was found:
> Read: <list of files found>
> Missing: <list of files not found>

---

## Step 2 — Name the template

Ask:
> What should this template type be called? This becomes the invoke name: `/0-project-init-<type>`.
>
> Examples: `pnpm-monorepo`, `next-app`, `z3-app`, `fastapi-backend`, `rust-cli`
>
> What type name fits this project?

---

## Step 3 — Identify the fixed stack

Based on what was read, present the detected stack and ask the developer to confirm what should be **pre-configured** in the template (the same for every project of this type) vs what should be **asked per project** (varies each time):

Present a table like:

| Setting | Detected value | Fixed in template? |
|---------|---------------|-------------------|
| Language | TypeScript | ✓ fixed |
| Package manager | pnpm | ✓ fixed |
| Monorepo tool | Turborepo | ✓ fixed |
| Framework | Next.js | ✓ fixed |
| Test runner | `pnpm test` | ✓ fixed |
| Dev URL | http://localhost:3000 | ask per project |
| Workflow tier | high-care | ask per project |
| Commit scope format | app name | ✓ fixed |

Ask the developer to correct the table. For each row marked "ask per project", it becomes a question in the template's setup flow.

---

## Step 4 — Identify project-specific questions

For every setting marked "ask per project" in Step 3, draft the question the template will ask when run on a future project.

Present the list:
> These questions will be asked when `/0-project-init-<type>` is run on a new project:
> 1. Project name and one-line mission
> 2. Dev server URL (default: http://localhost:3000)
> 3. Workflow tier — confirm high-care or override
> 4. ...

Ask:
> Are these the right questions? Add, remove, or reword any.

---

## Step 5 — Extract reusable prompt conventions

Scan `1-dev-spec.md`, `2-sync-spec.md`, and `3-commit.md` for patterns that are generic to this stack type vs patterns that are specific to this project.

**Generic to stack** (goes in template pre-filled):
- Verify commands: `pnpm typecheck && pnpm test`
- Scope format: monorepo app name
- Turbo pipeline references

**Specific to this project** (template leaves as stubs for the developer to fill in):
- The actual app names in the monorepo
- Custom commit conventions beyond the standard
- Project-specific upkeep tasks

Present findings and ask:
> Do any of these "project-specific" items actually apply to all <type> projects and should be pre-filled?

---

## Step 6 — Handle custom extensions and packages

Check if this project uses any Pi extensions or packages that future projects of this type would also benefit from.

Present:
> These extensions/packages are configured for this project:
> - `browse.ts` — browser verification (Arc)
> - `ask-user-question.ts` — structured questions
> - ...
>
> Should the template recommend installing any of these for future <type> projects?

For each: note whether it's already global (no action needed) or project-local (template should suggest `pi install -l npm:...`).

---

## Step 7 — Draft the template

Generate the full `0-project-init-<type>.md` draft following this structure:

```markdown
---
description: Pi harness setup for <type> projects. Pre-configured for <stack summary>. Only asks for project-specific details.
invoke: 0-project-init-<type>
---

# Pi Setup — <Type> Project

Specialized init for <type> projects. Stack and tooling are pre-configured — only project-specific details are collected.

> **Questions:** Use the `ask_user_question` tool for every question. Never write question lists as plain text.

---

## Pre-configured for this stack

| Setting | Value |
|---------|-------|
| Language | <language> |
| Package manager | <pkg manager> |
| <...> | <...> |

Verify commands: `<commands>`
Commit scope: <scope rule>

---

## Questions to ask

Collect these via `ask_user_question` before writing any files:

1. **Project name** — used in AGENTS.md and ideaLog headers
2. **Mission** — one sentence: what does this project do and who is it for?
3. <...additional per-project questions from Step 4...>

---

## Setup phases to run

After collecting answers, run these phases from `~/.pi/agent/prompts/0-project-init.md`:

### Phase 6a — 1-dev-spec
Use pre-configured verify commands. Inject project name and mission.
Write to `.pi/prompts/1-dev-spec.md`.

### Phase 6b — 2-sync-spec
Use pre-configured upkeep tasks. Write to `.pi/prompts/2-sync-spec.md`.

### Phase 6c — 3-commit
Use pre-configured scope format and commit conventions. Write to `.pi/prompts/3-commit.md`.

### Phase 7 — Debug hierarchy
Use this pre-configured order:
1. <debug order from Step 3>

Write to `.pi/agent-docs/standards/debug-hierarchy.md`.

### Phase 8 — Standards initialization
Write `.pi/agent-docs/standards/developer-preferences.md` (empty stub).
Write first ideaLog entry with stack and setup decisions.

### Phase 9 — Suggestions
Suggest these packages for this stack type:
<packages identified in Step 6>

### Phase 10 — AGENTS.md
Generate `.pi/AGENTS.md` using collected project name, mission, and dev commands.

---

## What to avoid

- Do not ask questions already pre-configured above
- Do not re-detect the stack — it is known
- Do not skip any phase output — all files must be written before calling finish_setup
```

Show the full draft to the developer and ask:
> Does this template look right? Anything to add, remove, or adjust before I write it?

---

## Step 8 — Write the template

On confirmation, write the finalized template to:
`~/.pi/agent/prompts/0-project-init-<type>.md`

Also copy to `~/.local/share/chezmoi/pi-agent-base/prompts/0-project-init-<type>.md` if the chezmoi dotfiles repo is detected at that path (so the template is version-controlled).

---

## Step 9 — Update global AGENTS.md

Add the new template to `~/.pi/agent/AGENTS.md` under the "Available Prompts" table:

```markdown
| `0-project-init-<type>` | `/0-project-init-<type>` | Bootstrap harness for <type> projects |
```

---

## Final report

> Template created: `/0-project-init-<type>`
>
> Pre-configured: <list of fixed settings>
> Per-project questions: <list of questions>
>
> To use on a new <type> project:
> 1. `cd <new-project-directory>`
> 2. `pi` → `/0-project-init-<type>`
>
> Template location: `~/.pi/agent/prompts/0-project-init-<type>.md`
