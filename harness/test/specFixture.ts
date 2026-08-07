import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const FM = `---
spec_id: demo-feature
status: in-progress
touches: ["src/demo/**"]
prompt_version: 1
---
`;

export const DEMO_SPEC_TASKS = `${FM}
# Tasks — demo-feature

## T1 — Scaffold demo module
Why: every later group imports from these files.
Verify: bun -e "console.log('t1 ok')"

- [ ] 1. Create \`src/demo/types.ts\` with the \`DemoItem\` interface
- [ ] 2. Create \`src/demo/store.ts\` + \`src/demo/store.test.ts\`

## T2 — Wire list rendering
Why: visible output early — the developer can see items render.
Verify: bun -e "process.exit(0)"

- [ ] 1. Create \`src/demo/render.ts\` + test
- [ ] 2. Wire \`render\` into \`src/demo/index.ts\`

## T3 — Manual smoke
Why: rendering quality needs human eyes.
Verify: manual

- [ ] 1. Open the demo page and confirm items render with empty + error states
`;

export const DEMO_SPEC = `${FM}
# Demo Feature

## Overview
A tiny demo feature used by implement/polish tests.

## Edge cases
- Empty item list renders the "No items" state
- Store rejects duplicate ids with a clear error

## T1 — Scaffold demo module
Create \`types.ts\` (interface \`DemoItem { id: string; label: string }\`) and \`store.ts\`
(\`createDemoStore(props: { items: DemoItem[] })\`).

## T2 — Wire list rendering
\`render(props: { store: DemoStore }): string\` returns one line per item.

## T3 — Manual smoke
Open the demo page; confirm empty and error states.
`;

/**
 * Seeds the demo-feature spec dir into a project created by mkTmpProject.
 *
 * @param props.dir - Project root (tmp copy of the `initialized` fixture).
 * @returns Absolute path of the spec dir.
 */
export function seedDemoSpec(props: { dir: string }): string {
  const specDir = join(props.dir, ".agent", "docs", "specs", "demo-feature");
  mkdirSync(specDir, { recursive: true });
  writeFileSync(join(specDir, "spec.md"), DEMO_SPEC);
  writeFileSync(join(specDir, "spec-tasks.md"), DEMO_SPEC_TASKS);
  return specDir;
}
