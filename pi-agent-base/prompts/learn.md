---
description: Deep-read a library, pattern, or codebase section to build the agent's working understanding. Produces a reference doc in .pi/agent-docs/research/. Use before writing specs that involve unfamiliar libraries.
---

# Learn

Build a working understanding of a library, pattern, or unfamiliar section of this codebase.

Use this before writing a spec that involves a library or pattern the agent hasn't seen in this project yet.

---

> **Questions:** Use the `ask_user_question` tool for every question in this prompt. Never write question lists as plain text.

## Process

### Step 1 — Read project context

Before searching, read `.pi/agent-docs/product/tech-stack.md` to know:
- The language and package manager — determines where installed packages live
- The runtime version — affects which APIs and syntax are available

Also check `.pi/agent-docs/research/` for an existing file on this subject. If one exists and is recent, ask whether to update it or start fresh.

### Step 2 — Identify the subject

Ask:
> What do you want me to learn? (library name, a pattern, a section of this codebase)

> What will I need to use this knowledge for? (e.g., "writing a spec for X feature")

### Step 3 — Locate the package source

Find the installed package using the language's tooling:

| Language | Where packages live | How to find |
|----------|---------------------|-------------|
| Node.js / TypeScript | `node_modules/<name>` | Read `README.md`, `*.d.ts` type definitions, key source files |
| Python | `site-packages/<name>` or `.venv/lib/` | `python -c "import <pkg>; print(<pkg>.__file__)"` |
| Rust | Cargo registry or workspace `Cargo.toml` | `cargo metadata --no-deps` or read source in the registry |
| Go | `$(go env GOPATH)/pkg/mod/<module>` | `go list -m -json all` |
| Ruby | `$(bundle exec gem env gemdir)/gems/<name>` | Read gem source |
| Other | Use the language's package manager to locate the source | Ask if unclear |

If the library is a codebase section (not an external package), read the relevant files directly.

### Step 4 — Build mental model

From the source, extract:
- What it does and what it explicitly does NOT do
- The core API surface — only what's needed for this project
- Patterns this project uses or should use when calling it
- Gotchas, deprecations, and version-specific behavior
- Any existing usage in this codebase to match style

### Step 5 — Write reference doc

Check for an existing file at `.pi/agent-docs/research/<subject>.md`. If it exists, update it. Otherwise create it:

```markdown
# <Subject>

**Learned for:** <what feature/spec this feeds>
**Version:** <version from manifest>
**Date:** <YYYY-MM-DD>

## What it is

<one paragraph — what this library/pattern does>

## API surface (relevant to this project)

<only the parts we'll actually use>

## Usage pattern

<code example in this project's language and style>

## Gotchas

- <thing that is non-obvious or surprising>

## What NOT to use

- <deprecated or footgun parts of the API and why>
```

### Step 6 — Confirm readiness

After writing:
> Learned `<subject>`. Ready to write specs using it.
> Reference at `.pi/agent-docs/research/<subject>.md`

If you found something the project is currently using incorrectly, flag it before confirming readiness.

---

## Rules

- Read actual source and type definitions — don't rely on training data for library internals
- Only document what's relevant to this project — not a full library reference
- Check the version in the manifest before describing behavior — APIs change across versions
- If the research directory doesn't exist, create it at `.pi/agent-docs/research/`
