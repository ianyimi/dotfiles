# User Preferences

Learned preferences for this specific user. Updated automatically after each completed diagram session via the self-improvement protocol. Read this file **before starting any diagram**.

---

## Domain & Context

- **Primary domain**: Web development (Next.js, React, TypeScript, Convex, monorepos)
- **Secondary domains**: Full-stack architecture, CMS/admin tooling, CLI tooling, SaaS products
- **Typical diagram purpose**: Architecture blueprints used as rebuild/implementation guides — these need to be comprehensive enough to derive variable names, package boundaries, and feature scope from the diagram alone

---

## Diagram Style Preferences

### Complexity
- Always lean toward **complex and articulate** — this user will not ask for simple diagrams
- When in doubt, add more detail, not less
- Every feature of a system should be a **distinct visual node** — not collapsed into a parent
- Diagrams should be usable as a **complete blueprint** for building from scratch

### Approach
- User describes systems in terms of **features and functionality** — translate those into visual structure
- Do not ask for confirmation on layout choices — make strong decisions and render
- Prefer **top-down flows** for architecture (entry point at top, external services at bottom)
- Use **color coding by package/layer** for monorepo or multi-package architectures

### Specificity
- Use **real function names, method names, and file names** from the codebase — not generic placeholders
- Show actual data flow labels on arrows (what is being passed, not just "data")
- For package architectures: always show **which packages are pure vs. have external deps** — this is a key architectural constraint worth visualizing

---

## Output Format

- Primary output: **Obsidian Excalidraw plugin format** (`.excalidraw.md`)
- File location: User's Obsidian vault at `/Users/zaye/Documents/Obsidian/Vaults/The Lab v2/Projects/<ProjectName>/`
- The Obsidian folder may appear empty via `ls` — create the file anyway, Obsidian handles it
- Use exact format:
  ```
  ---
  excalidraw-plugin: parsed
  tags: [excalidraw]
  ---

  ==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠==

  ## Text Elements

  %%

  ## Drawing
  ```json
  { ... }
  ```

  %%
  ```

---

## What to Avoid

- Do not collapse related nodes into a single box with a list — give each node its own shape
- Do not use generic labels like "Data", "Input", "Process" — use the real names
- Do not ask the user to confirm obvious architectural decisions — just render and iterate
- Do not produce diagrams that look like org charts or uniform grids — vary the visual patterns

---

## Notes from Past Sessions

<!-- Add dated notes here after each session. Format: YYYY-MM-DD: observation -->

- 2026-03-28: First diagram request was a comprehensive monorepo architecture for VexCMS. User wants to use diagrams as pre-implementation blueprints to iron out package boundaries and feature scope before writing code. This is the primary use case going forward.
- 2026-03-28: User prefers discussing in terms of features, and wants the diagram agent to do the translation to visual structure — not the other way around.
- 2026-03-28: User confirmed the "vex.config.ts as center node" pattern — config is the anchor, each section of the config connects outward to the package that controls it. This is the base diagram; variation diagrams will follow (collections config, globals config, blocks config).
- 2026-03-28: Obsidian snippet embed syntax `![[snippets#Heading Name]]` should always be placed near the relevant package or concept — acts as a live-updating code reference inside Excalidraw. Code examples go in `/VexCMS/snippets.md` under H1 headings in ```ts blocks.
- 2026-03-28: For monorepo package diagrams: use a large filled rectangle for the "pure/core" package (orange fill, darker stroke). Use solid blue for the active primary framework package. Use dashed border with light fill for future/planned packages. Color-code adapter packages by semantic purpose (purple=auth, green=storage, blue=richtext, yellow=plugins).
- 2026-03-28: Column layout inside a large node (like vex.config.ts): use vertical dashed divider lines + column title text in title color + body text in #374151. Keep col widths generous (180-320px) to avoid overflow.
- 2026-03-29: **Obsidian strips unbound text elements on open/save.** When Obsidian opens a `.excalidraw.md` file it reformats the JSON and silently drops text elements that are not bound to a shape via `containerId`. All diagram text must be generated fresh from the build script each session — never rely on previously written text elements surviving an Obsidian open. Always re-write the full diagram by removing by ID set and re-appending from the temp file.
- 2026-03-29: **ID collisions cause silent element displacement.** If two diagrams on the same canvas share element IDs, Excalidraw deduplicates — one version wins and the other's position/content is lost. Every diagram must use a unique prefix (e.g. `sg3_`, `fld_`, `dbf_`). Never reuse generic prefixes like `fs_` across diagrams.
- 2026-03-29: **Coordinate layout rules for multi-diagram canvas.** Diagrams must be assigned non-overlapping x-ranges and verified before writing. Current layout: feature rows x=0–1999, field system x=3240–4720, schema gen x=5640–7100, feature architecture rows x=7333–8600+, defineBlock hero x=7329–8873 y=5655+. Always compute total width before placing: n_boxes * (box_w + gap) determines right edge.
- 2026-03-29: **Update strategy — always remove by ID set, never by coordinate region.** The safe update pattern: (1) build fresh diagram to temp `.excalidraw` file, (2) collect all IDs from that file into a set, (3) remove all matching IDs from main file, (4) append fresh elements. Never use coordinate-range deletion — it risks hitting manually maintained content that lives in the same region.
- 2026-03-29: **Stale element accumulation.** Each time a diagram is regenerated with new content but slightly different random-UUID elements remain from prior Obsidian edits, dead text builds up. The remove-by-ID-set pattern prevents this as long as element IDs stay stable across rebuilds (i.e. use deterministic string IDs in build scripts, not random UUIDs).
- 2026-03-29: **Black-box referencing pattern for reused subsystems.** When diagram A depends on subsystem B that has its own detailed diagram, show B as a single labeled box in A (e.g. "Field System · @vexcms/core (see Field System diagram)") with just inputs/outputs noted. Do not re-diagram B's internals. This was applied: Schema Generation Pipeline references Field System as a black-box; future diagrams (defineCollection, defineGlobal, etc.) should reference Schema Generation as a black-box the same way.
- 2026-03-29: **Two rows for wide sets of uniform boxes.** When a row of N similar boxes would exceed the allocated x-range, split into 2 rows of N/2. Used for 12 field helpers and 12 React field components (2 rows of 6 at w=210, gap=12 = 1320px total).
