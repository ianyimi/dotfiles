---
name: design
description: Use this skill when the user wants to save, update, or reference visual design assets for the project. Triggers on "save design", "update designs", "sync designs", "add visual", "design assets", "claude design export", "design folder", "/design". Also fires proactively when the agent is about to write UI code (React components, CSS, Tailwind classes, layout) — in that case, read the active design first so code matches the visual spec. The design folder is always at `.pi/design/` and the agent should always check it before writing any UI-facing code.
---

# Design

**Single source of truth for project visuals:** `.pi/design/`

The `.pi/design/` folder is the agent's visual reference system. It holds all
design assets — UI mockups, brand guidelines, CSS tokens, component specs,
screenshots, and exports from Claude Design sessions. The agent reads this
folder before writing any UI code so that implementations match the intended
visual design.

## Location

```
.pi/design/
  README.md                  ← Always read first. Index of all design assets + how to use them.
  claude-design/             ← Visual source of truth from Claude Design sessions
    README.md                ← Token translation table + file guide (if applicable)
    <app-or-section>/        ← Per-section mockups (admin, www, mobile, etc.)
  <theme-or-variant>/        ← Optional theme/variant folders (brand-guidelines.md, DESIGN.md, globals.css)
```

## When to read designs

**Always read `.pi/design/README.md` before:**
- Writing any React component that renders UI
- Editing CSS/Tailwind classes that affect visual appearance
- Creating new pages, layouts, or navigation
- Choosing colors, spacing, typography, or radii
- Writing specs that describe visual behavior

**Workflow:**
1. Read `.pi/design/README.md` — it tells you which subfolder is the active design and how to use each asset
2. Read the relevant section subfolder's files (JSX mockups, CSS, brand guidelines)
3. Implement matching the design spec — not from memory, from the file

## When to update designs

The **Claude Design agent** (claude.ai/design) exports design revisions. When
a new export arrives:

1. Drop new files into the appropriate `.pi/design/claude-design/<section>/` subfolder
2. Update `.pi/design/README.md` if the folder structure or active design changes
3. If token names changed, update the translation table in `claude-design/README.md`
4. If a `globals.css` changed, propagate changes to the project's actual globals file
   (using the token translation table — never copy Claude Design CSS directly)

**This skill does NOT auto-sync from Claude Design.** The developer exports
from Claude Design and places files. The agent then updates the README and
propagates token changes when asked.

## When the design folder is empty or missing

If `.pi/design/` doesn't exist or has no active design:
- Ask the developer if there are visual designs to reference
- If not, note in the session that UI decisions are ad-hoc (no visual spec)
- The agent should still follow any existing patterns in the codebase

## File types supported

| Type | Purpose | Agent action |
|------|---------|-------------|
| `.jsx` / `.tsx` | Component mockups | Read as visual specs, port patterns to project components |
| `.css` / `.globals.css` | Token definitions | Read for color/spacing/radius values; translate via token table |
| `.html` | Canvas index / artboard | Read for layout structure |
| `.md` / `DESIGN.md` | Design system docs | Read for rules, constraints, brand guidelines |
| `.svg` / `.png` / `.jpg` | Static assets (logos, icons, screenshots) | Reference for placement; view with `read` or `browse` |
| `.pdf` | Design documents | Parse with `document_parse` tool |

## Key rule: never copy Claude Design CSS directly

Claude Design uses its own token vocabulary that differs from the project's
CSS framework (shadcn, Tailwind, etc.). Always translate tokens via the
translation table in `claude-design/README.md`. If no table exists yet,
create one by comparing Claude Design's token names against the project's
CSS variable names.
