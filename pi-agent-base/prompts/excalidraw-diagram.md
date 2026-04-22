---
description: Create Excalidraw diagram JSON files that make visual arguments. Use when the user wants to visualize workflows, architectures, or concepts.
---

# Excalidraw Diagram Creator

Generate `.excalidraw` JSON files that **argue visually**, not just display information.

**Reference files** (color palette, element templates, examples) live at:
`~/.pi/agent/skills/excalidraw-diagram/references/`

Read `references/color-palette.md` and `references/user-preferences.md` **before starting any diagram**.

**Setup:** If the render script hasn't been set up yet:
```bash
cd ~/.pi/agent/skills/excalidraw-diagram/references
uv sync
uv run playwright install chromium
```

## Customization

**All colors and brand-specific styles live in one file:** `~/.pi/agent/skills/excalidraw-diagram/references/color-palette.md`. Read it before generating any diagram and use it as the single source of truth for all color choices — shape fills, strokes, text colors, evidence artifact backgrounds, everything.

To make this prompt produce diagrams in your own brand style, edit `color-palette.md`. Everything else in this file is universal design methodology and Excalidraw best practices.

---

## Core Philosophy

**Diagrams should ARGUE, not DISPLAY.**

A diagram isn't formatted text. It's a visual argument that shows relationships, causality, and flow that words alone can't express. The shape should BE the meaning.

**The Isomorphism Test**: If you removed all text, would the structure alone communicate the concept? If not, redesign.

**The Education Test**: Could someone learn something concrete from this diagram, or does it just label boxes? A good diagram teaches—it shows actual formats, real event names, concrete examples.

---

## Depth Assessment (Do This First)

Before designing, determine what level of detail this diagram needs:

### Simple/Conceptual Diagrams
Use abstract shapes when:
- Explaining a mental model or philosophy
- The audience doesn't need technical specifics
- The concept IS the abstraction (e.g., "separation of concerns")

### Comprehensive/Technical Diagrams
Use concrete examples when:
- Diagramming a real system, protocol, or architecture
- The diagram will be used to teach or explain (e.g., YouTube video)
- The audience needs to understand what things actually look like
- You're showing how multiple technologies integrate

**For technical diagrams, you MUST include evidence artifacts** (see below).

---

## Research Mandate (For Technical Diagrams)

**Before drawing anything technical, research the actual specifications.**

If you're diagramming a protocol, API, or framework:
1. Look up the actual JSON/data formats
2. Find the real event names, method names, or API endpoints
3. Understand how the pieces actually connect
4. Use real terminology, not generic placeholders

Bad: "Protocol" → "Frontend"
Good: "AG-UI streams events (RUN_STARTED, STATE_DELTA, A2UI_UPDATE)" → "CopilotKit renders via createA2UIMessageRenderer()"

**Research makes diagrams accurate AND educational.**

---

## Evidence Artifacts

Evidence artifacts are concrete examples that prove your diagram is accurate and help viewers learn. Include them in technical diagrams.

**Types of evidence artifacts** (choose what's relevant to your diagram):

| Artifact Type | When to Use | How to Render |
|---------------|-------------|---------------|
| **Code snippets** | APIs, integrations, implementation details | Dark rectangle + syntax-colored text (see color palette for evidence artifact colors) |
| **Data/JSON examples** | Data formats, schemas, payloads | Dark rectangle + colored text (see color palette) |
| **Event/step sequences** | Protocols, workflows, lifecycles | Timeline pattern (line + dots + labels) |
| **UI mockups** | Showing actual output/results | Nested rectangles mimicking real UI |
| **Real input content** | Showing what goes IN to a system | Rectangle with sample content visible |
| **API/method names** | Real function calls, endpoints | Use actual names from docs, not placeholders |

---

## Multi-Zoom Architecture

Comprehensive diagrams operate at multiple zoom levels simultaneously.

### Level 1: Summary Flow
A simplified overview showing the full pipeline or process at a glance.

### Level 2: Section Boundaries
Labeled regions that group related components.

### Level 3: Detail Inside Sections
Evidence artifacts, code snippets, and concrete examples within each section.

**For comprehensive diagrams, aim to include all three levels.**

---

## Design Process (Do This BEFORE Generating JSON)

### Step 0: Assess Depth Required
Determine if this needs to be Simple/Conceptual or Comprehensive/Technical. If comprehensive: research first.

### Step 1: Understand Deeply
Read the content. For each concept, ask:
- What does this concept **DO**? (not what IS it)
- What relationships exist between concepts?
- What's the core transformation or flow?
- **What would someone need to SEE to understand this?**

### Step 2: Map Concepts to Patterns

| If the concept... | Use this pattern |
|-------------------|------------------|
| Spawns multiple outputs | **Fan-out** (radial arrows from center) |
| Combines inputs into one | **Convergence** (funnel, arrows merging) |
| Has hierarchy/nesting | **Tree** (lines + free-floating text) |
| Is a sequence of steps | **Timeline** (line + dots + free-floating labels) |
| Loops or improves continuously | **Spiral/Cycle** (arrow returning to start) |
| Is an abstract state or context | **Cloud** (overlapping ellipses) |
| Transforms input to output | **Assembly line** (before → process → after) |
| Compares two things | **Side-by-side** (parallel with contrast) |
| Separates into phases | **Gap/Break** (visual separation between sections) |

### Step 3: Ensure Variety
For multi-concept diagrams: **each major concept must use a different visual pattern**.

### Step 4: Sketch the Flow
Before JSON, mentally trace how the eye moves through the diagram.

### Step 5: Generate JSON
Only now create the Excalidraw elements. **For large diagrams, build one section at a time.**

### Step 6: Render & Validate (MANDATORY)

```bash
cd ~/.pi/agent/skills/excalidraw-diagram/references && uv run python render_excalidraw.py <path-to-file.excalidraw>
```

Then use the Read tool to view the PNG. Repeat the render-view-fix loop until the diagram looks right.

---

## Large / Comprehensive Diagram Strategy

**Build the JSON one section at a time.** Do NOT attempt to generate the entire file in a single pass.

1. Create the base file with the first section
2. Add one section per edit — think carefully about layout and cross-section connections
3. Use descriptive string IDs (e.g., `"trigger_rect"`, `"arrow_fan_left"`)
4. Namespace seeds by section (section 1 uses 100xxx, section 2 uses 200xxx)
5. Update cross-section bindings as you go

After all sections: review the whole, fix alignment, then render & validate.

---

## Container vs. Free-Floating Text

**Not every piece of text needs a shape around it.** Default to free-floating text. Add containers only when they serve a purpose.

| Use a Container When... | Use Free-Floating Text When... |
|------------------------|-------------------------------|
| It's the focal point of a section | It's a label or description |
| Arrows need to connect to it | It describes something nearby |
| The shape itself carries meaning | Typography alone creates sufficient hierarchy |

**Rule**: Default to no container. Aim for <30% of text elements to be inside containers.

---

## Shape Meaning

| Concept Type | Shape |
|--------------|-------|
| Labels, descriptions, details | **none** (free-floating text) |
| Start, trigger, input | `ellipse` |
| End, output, result | `ellipse` |
| Decision, condition | `diamond` |
| Process, action, step | `rectangle` |
| Abstract state, context | overlapping `ellipse` |

---

## JSON Structure

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [...],
  "appState": {
    "viewBackgroundColor": "#ffffff",
    "gridSize": 20
  },
  "files": {}
}
```

See `~/.pi/agent/skills/excalidraw-diagram/references/element-templates.md` for copy-paste JSON templates for each element type.

---

## Render & Validate (MANDATORY)

After generating or editing the JSON:

1. **Render & View** — Run the render script, then Read the PNG
2. **Audit against your vision** — Does the visual structure match what you designed?
3. **Check for visual defects** — Text overflow, overlapping elements, misrouted arrows, uneven spacing
4. **Fix** — Edit the JSON to address everything found
5. **Re-render & re-view** — Keep cycling until it passes both the vision check and defect check

---

## "Done for Now" Checkpoint (MANDATORY)

After the render-view-fix loop reaches a passable state, ask:

> "Is this diagram done for now, or do you want to keep refining it?"

If done: run the self-improvement protocol (save PNG to examples/, update examples/index.md, update user-preferences.md).

---

## Self-Improvement Protocol

After every completed diagram:

1. Copy final PNG to `~/.pi/agent/skills/excalidraw-diagram/references/examples/YYYY-MM-DD-<topic>.png`
2. Update `references/examples/index.md` with filename, type, complexity (1-5), and notes
3. Prune if >12 examples (remove lowest-complexity entry not representative of typical requests)
4. Update `references/user-preferences.md` with new learnings about this user's preferences

---

## Quality Checklist

### Depth & Evidence
1. Research done for technical diagrams?
2. Evidence artifacts included?
3. Multi-zoom levels present?

### Conceptual
4. Isomorphism — does visual structure mirror concept behavior?
5. Variety — each major concept uses a different visual pattern?

### Technical
6. `text` property contains only readable words
7. `fontFamily: 3`
8. `roughness: 0` for clean/modern
9. `opacity: 100` for all elements
10. <30% of text elements inside containers

### Visual Validation
11. Rendered to PNG and visually inspected
12. No text overflow, no overlapping elements
13. Arrows connect to intended elements
14. Balanced composition, readable text
