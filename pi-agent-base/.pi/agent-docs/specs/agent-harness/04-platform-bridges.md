# 04 — Platform Bridges: sync, adapters, platform add

> Phase spec 4 of 8. Prereqs: 01–03 implemented; read `00-master.md` fully — §2 conventions,
> §3 corrections C1–C10 (OMP ground truth), §7 schemas, §9 bridge contract (the §9.2 table is
> authoritative for bridge contents), D6/D9/D10. This is the highest-risk phase: every generated
> file is pinned by a golden string; nothing here is "roughly right".

## Overview

Build the platform bridge layer: `buildContextRules` (context-rules.yaml compilation), the OMP and
Claude Code `PlatformAdapter` implementations (pure `plan()` functions), the adapter-agnostic
`harness sync` engine with D10 conflict handling, `harness platform add/list`, and doctor checks
`shims-stale` + `context-rules-stale`. After this spec, sync on the extended `initialized` fixture
produces byte-stable `.omp/` + `.claude/` bridges, re-sync is a byte-identical no-op, and user
edits are surfaced — never clobbered.

## Design Decisions (this spec)

- **`when` globs for domain rules** come from `applies_to` frontmatter (inline string array) on
  files under `docs/standards/<domain>/` — union, deduped, sorted. A domain whose files declare no
  `applies_to` gets **no rule** plus a sync warn line (never a match-everything glob). The `naming`
  rule's `when` = union of `scope` arrays from the naming-conventions machine-readable block via
  02's parser (`parseNamingRules`, `src/lib/namingRules.ts` — reuse it; no second parser).
- **context-rules.yaml is hand-templated**, not `yaml.stringify`'d — byte-exact goldens need
  deterministic quoting (`when` inline with JSON-quoted globs, `inject` as dash list).
- **`ROUTED_SKILLS`** fixed set = `["dev-spec", "sync-spec", "implement", "polish", "debug",
  "commit"]`. An OMP agent file is generated for every skill on disk that is in this set OR carries
  `harness_model_role` (C10). `model: "@<role>"` is emitted only when the role is present.
- **Merge paths**: `MERGE_PATHS = new Set([".claude/settings.json"])`. These bypass the
  hash-conflict rule (user additions to *other* keys must not read as conflicts) and go through
  `mergeManagedJson`. All other planned files use D10 verbatim.
- **Gitignore management** = one marker block, rewritten wholesale (sorted lines):
  `# >>> harness (managed by \`harness sync\`) >>>` … `# <<< harness <<<`. Sync-manifest records one
  entry per line: `path: ".gitignore#<line>"`, `kind: "gitignore-line"`, `target_or_hash: <line>`.
- **User-modified conflict keeps the stale manifest entry** (file stays recognized as managed;
  future syncs keep reporting until resolved). Unmanaged conflicts never gain an entry.
- **Sync exit code**: `EXIT.FINDINGS` (1) when any conflict was reported, else `EXIT.OK`.
- **`ProjectContext` gains one field**: `antiPatternRegexes: string[]` (the OMP rules compiler
  needs it; adapters are pure, so the I/O lives in `loadProjectContext`). Amend
  `src/platforms/types.ts` in Step 3 — the only type change this spec makes.
- **Anti-pattern TTSR opt-in syntax** (C2, §9.2 row `.omp/rules/anti-patterns.md`): a bullet in
  `anti-patterns.md` opts in via a 2-space-indented continuation line `pattern: <regex>` directly
  below it. No `pattern:` lines → no rules file generated.

## Out of Scope (this spec)

Deeper OMP-native integration (proposal Phase 9), `.pi/` bridges, opencode/codex implementations
(documented as a recipe only, §"Adding a future platform"), everything owned by 05–08.

---

## Verified Constants (fill in during Step 1 — MANDATORY before writing `omp.ts`)

Master §3 (C4, C8) mandates re-verification against the installed package at
`$(npm root -g)/@oh-my-pi/pi-coding-agent/` before emitting any `.omp/` output. Record findings in
the **Verified value** column IN THIS FILE, then reconcile every dependent golden string in
Steps 4–6. If a verified value differs from the expected one, the golden changes — never the source.

| # | Constant | Expected (00 §3 + authoring notes) | Verified value | Source file |
|---|---|---|---|---|
| V1 | `disabledProviders` config key name + location | top-level key in `.omp/config.yml`, string array | *(fill in)* | `src/config/settings-schema.ts` |
| V2 | Provider id that ingests `.claude/` | `claude` | *(fill in)* | `src/discovery/` |
| V3 | Provider id(s) that ingest `.agent`/`.agents` | `agent`, `agents` (may be a single id) | *(fill in)* | `src/discovery/` |
| V4 | Any other provider ids harness must disable | none (harness manages only `.claude`, `.agent`) | *(fill in)* | `src/discovery/` |
| V5 | `applyTo` multi-glob syntax in `*.instructions.md` | comma-separated globs in one string | *(fill in)* | instructions loader in `src/discovery/` |
| V6 | `thinking-level` allowed values (agents frontmatter) | kebab-case set, e.g. `off|minimal|low|medium|high` | *(fill in)* | `settings-schema.ts` / agents loader |
| V7 | Event-hook API: event name + notify surface | `pi.on("session_start", …)`; `ctx.ui.notify(msg)` shape | *(fill in)* | `@oh-my-pi/pi-coding-agent/hooks` types |
| V8 | `HookAPI` type import specifier | `"@oh-my-pi/pi-coding-agent/hooks"` | *(fill in)* | package.json `exports` |
| V9 | `modelRoles` key name + role set | `modelRoles:` group; roles incl. `default smol slow vision plan designer commit tiny task advisor` | *(fill in)* | `settings-schema.ts` |

---

## Implementation Order

> `[agent]` = boilerplate/pattern-following · `[dev]` = core logic, guided stub named per step

1. `[dev]` Verify OMP constants — fill the table above
2. `[agent]` Extend the `initialized` fixture (two skills + one context-rule source)
3. `[dev]` `buildContextRules` + `loadProjectContext` — key fns: `buildContextRules`, `loadProjectContext`
4. `[dev]` OMP adapter — key fn: `ompAdapter.plan`
5. `[dev]` Claude adapter — key fn: `claudeAdapter.plan`
6. `[dev]` `mergeManagedJson` + gitignore block — key fns: `mergeManagedJson`, `updateGitignoreBlock`
7. `[dev]` `harness sync` engine — key fn: `runSync`
8. `[agent]` `harness platform add|list` — key fn: `runPlatform`
9. `[dev]` Doctor checks `shims-stale`, `context-rules-stale`
10. Verification

---

## Step 1: Verify OMP constants `[dev]`

- [ ] Run `ls "$(npm root -g)/@oh-my-pi/pi-coding-agent/src"` — confirm source ships; read
      `src/config/settings-schema.ts` and every file in `src/discovery/` that mentions providers,
      instructions, agents, or hooks.
- [ ] Fill every **Verified value** cell in the table above (edit this spec file), then reconcile
      the golden strings in Steps 4–6 with any deviations (V1–V9 are referenced inline).
- [ ] If V5 shows comma-separated globs are NOT accepted: switch instructions generation to one
      file per glob (`<rule-id>-<n>.instructions.md`) and update the goldens accordingly.

No code in this step. Do not proceed to Step 4+ with an unfilled table.

## Step 2: Extend the `initialized` fixture `[agent]`

- [ ] Replace/add the four files below byte-exactly (01's tests pin none of these bytes; re-run the
      full suite after editing to confirm)
- [ ] `bun test` still green

**File: `test/fixtures/initialized/.agent/skills/dev-spec/SKILL.md`** (replace; routed via set, no role):

```markdown
---
name: dev-spec
description: Write a developer-led implementation spec. Triggers on "write a spec", "spec out", "what should we build".
---

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.

## Steps
1. Run `harness spec new <slug>` and follow the generated spec-tasks.md.
```

**File: `test/fixtures/initialized/.agent/skills/implement/SKILL.md`** (new; routed via role):

```markdown
---
name: implement
description: Drive spec implementation task-group by task-group. Triggers on "implement", "build this", "run the spec".
harness_model_role: task
---

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.

## Steps
1. Run `harness implement next` and follow its output.
```

**File: `test/fixtures/initialized/.agent/docs/standards/backend/api.md`** (replace):

```markdown
---
applies_to: ["convex/**", "src/server/**"]
---

# Backend API Standards

Route handlers validate input at the boundary and return typed results.
```

**File: `test/fixtures/initialized/.agent/docs/standards/naming-conventions.md`** (new):

````markdown
# Naming Conventions — initialized

## Rules (machine-readable)

```yaml
rules:
  - id: ts-file-names
    pattern: "^[a-z][a-zA-Z0-9]*\\.(ts|tsx)$"
    scope: ["**/*.ts", "**/*.tsx"]
    description: TypeScript files are camelCase.
```
````

## Step 3: `buildContextRules` + `loadProjectContext` `[dev]`

- [ ] Add `antiPatternRegexes: string[]` to `ProjectContext` in `src/platforms/types.ts`; add
      `export interface ContextRule { id: string; when: string[]; inject: string[] }` if 01 left it
      unexported
- [ ] Create `src/commands/sync.ts` with the two functions below + `src/commands/sync.test.ts`
      (grows through Step 7); run tests

**File: `harness/src/commands/sync.ts`** (begins here; Steps 6–7 append):

```typescript
import type { HarnessManifest } from "../lib/manifest.ts";
import type { ContextRule, ProjectContext } from "../platforms/types.ts";

/**
 * Compiles context rules from standards inventory + naming scopes (master §7.2). Pure.
 *
 * @param props.manifest - Loaded manifest (standards_domains gives domain order).
 * @param props.standards - Every docs/standards file: .agent-relative path + parsed applies_to.
 * @param props.namingScopes - Union input from naming rules block scopes; null when the module is
 *   off or the file is absent.
 * @returns Ordered rules plus the exact context-rules.yaml text (byte-stable).
 */
export function buildContextRules(props: {
  manifest: HarnessManifest;
  standards: Array<{ path: string; appliesTo: string[] }>;
  namingScopes: string[] | null;
}): { rules: ContextRule[]; yaml: string; warnings: string[] } {
  // TODO: implement
  // 1. For each domain in manifest.standards_domains (manifest order): files =
  //    standards under `docs/standards/<domain>/` (sorted, README.md included if it has
  //    applies_to). when = sorted deduped union of their appliesTo. inject = sorted file paths
  //    whose parent is the domain dir (only .md files).
  //    - when empty but inject non-empty → push warning
  //      `domain <d> has no applies_to globs — rule omitted (add applies_to frontmatter)`, skip.
  //    - inject empty → skip silently (empty domain).
  //    Else push { id: `std-${domain}`, when, inject }.
  // 2. If namingScopes non-null and non-empty → push { id: "naming",
  //    when: sorted deduped namingScopes, inject: ["docs/standards/naming-conventions.md"] }.
  // 3. yaml = hand-templated (NOT yaml.stringify): header line
  //    "# GENERATED by harness sync — do not edit. Source: standards folders + naming rule scopes."
  //    then "version: 1", "rules:", per rule:
  //      `  - id: <id>` / `    when: [<JSON.stringify of each glob, ", "-joined>]` /
  //      `    inject:` / `      - <path>` per path. Trailing newline. rules empty →
  //    "rules: []" line instead.
  //
  // Edge cases: root-level standards files (anti-patterns, preferences) never form rules;
  // duplicate globs across files dedupe; determinism = sorting everywhere above.
  throw new Error("Not implemented");
}

/**
 * Loads everything adapters need. The ONLY I/O gateway for planning (adapters stay pure).
 *
 * @param props.root - Absolute project root.
 * @returns Fully-populated ProjectContext (contextRules built via buildContextRules) plus
 *   compilation warnings for the reporter.
 */
export function loadProjectContext(props: { root: string }): {
  ctx: ProjectContext; warnings: string[];
} {
  // TODO: implement
  // 1. manifest = loadManifest. skills = for each .agent/skills/*/SKILL.md (sorted):
  //    { name: frontmatter.name ?? dirname, dir, frontmatter } via parseFrontmatter.
  // 2. standardsFiles = walk(docs/standards) sorted; standards inventory = each file's
  //    applies_to frontmatter (string[] | absent → []).
  // 3. namingScopes: manifest.modules.naming_conventions && naming-conventions.md exists →
  //    union of parseNamingRules(...).rules[].scope (02's parser); else null.
  // 4. antiPatternRegexes: lines in docs/standards/anti-patterns.md matching /^  pattern: (.+)$/
  //    (trimmed capture), file order. Absent file → [].
  // 5. contextRules from buildContextRules; return { ctx, warnings }.
  throw new Error("Not implemented");
}
```

**Test (in `sync.test.ts`)** — golden for `buildContextRules` on the extended fixture inputs:

```typescript
import { describe, expect, test } from "bun:test";
import { buildContextRules, loadProjectContext } from "./sync.ts";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";

const CONTEXT_RULES_GOLDEN = `# GENERATED by harness sync — do not edit. Source: standards folders + naming rule scopes.
version: 1
rules:
  - id: std-backend
    when: ["convex/**", "src/server/**"]
    inject:
      - docs/standards/backend/api.md
  - id: naming
    when: ["**/*.ts", "**/*.tsx"]
    inject:
      - docs/standards/naming-conventions.md
`;

describe("buildContextRules", () => {
  test("golden yaml from the initialized fixture (unsorted inputs → sorted output)", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const { ctx, warnings } = loadProjectContext({ root: dir });
    expect(warnings).toEqual([]);
    expect(ctx.contextRules?.map((r) => r.id)).toEqual(["std-backend", "naming"]);
    const built = buildContextRules({
      manifest: ctx.manifest,
      standards: [{ path: "docs/standards/backend/api.md", appliesTo: ["src/server/**", "convex/**"] }],
      namingScopes: ["**/*.tsx", "**/*.ts"],
    });
    expect(built.yaml).toBe(CONTEXT_RULES_GOLDEN);
    rmProject({ dir });
  });
  test("domain without applies_to → omitted with warning; empty rules → 'rules: []'", () => {
    const built = buildContextRules({
      manifest: { standards_domains: ["backend"] } as never,
      standards: [{ path: "docs/standards/backend/api.md", appliesTo: [] }],
      namingScopes: null,
    });
    expect(built.rules).toEqual([]);
    expect(built.warnings[0]).toContain("backend");
    expect(built.yaml).toContain("rules: []");
  });
});
```

## Step 4: OMP adapter `[dev]`

- [ ] Create `src/platforms/omp.ts` + `src/platforms/omp.test.ts`; run tests

**File: `harness/src/platforms/omp.ts`**

```typescript
import type { BridgePlan, PlatformAdapter, ProjectContext } from "./types.ts";

/** Skills that always get an OMP subagent when present on disk (plus any with harness_model_role). */
export const ROUTED_SKILLS = ["dev-spec", "sync-spec", "implement", "polish", "debug", "commit"] as const;

/** Provider ids OMP must not double-ingest in harness projects (Step 1 table V2–V4). */
export const OMP_DISABLED_PROVIDERS = ["claude", "agent", "agents"] as const;

/**
 * OMP bridge planner (master §9.2 rows 1–7). Pure — string building only, no I/O.
 * @param props.ctx - Loaded project context.
 * @returns Complete .omp/ plan: 2 symlinks, generated agents/instructions/config/hook (+rules
 *   file only when ctx.antiPatternRegexes is non-empty), gitignore line unless commit_bridges.
 */
export const ompAdapter: PlatformAdapter = {
  id: "omp",
  dir: ".omp",
  plan(props: { ctx: ProjectContext }): BridgePlan {
    // TODO: implement
    // 1. symlinks: .omp/skills → ../.agent/skills ; .omp/AGENTS.md → ../.agent/AGENTS.md.
    // 2. agents: for each ctx.skills (sorted by name) where name ∈ ROUTED_SKILLS or
    //    frontmatter.harness_model_role present → .omp/agents/<name>.md (template below;
    //    C1: name+description REQUIRED — skip skills lacking a description).
    // 3. instructions: per ctx.contextRules rule → .omp/instructions/<id>.instructions.md
    //    (template below; applyTo = when.join(",") per V5; inject paths prefixed ".agent/").
    // 4. config: .omp/config.yml (template below; V1 key + OMP_DISABLED_PROVIDERS; commented
    //    modelRoles skeleton per V9). ALWAYS emitted — C5: empty .omp/ is ignored.
    // 5. hook: .omp/hooks/session-doctor.ts (template below, V7/V8 API).
    // 6. rules: ctx.antiPatternRegexes non-empty → .omp/rules/anti-patterns.md (template below).
    // 7. gitignoreLines: ctx.manifest.platforms.commit_bridges ? [] : [".omp/"].
    // Files sorted by path; every file ends with exactly one trailing newline.
    throw new Error("Not implemented");
  },
};
```

Templates (implement as private template-literal builders; goldens below are the contract):

- **Agent** (`.omp/agents/<name>.md`): frontmatter `name`, `description` (copied verbatim from the
  skill), `model: "@<role>"` only when `harness_model_role` set; body = generated-marker comment,
  the verbatim 3-line preflight (master §10.3), then `## Task` / `Load the skill \`<name>\` and
  follow it exactly.`
- **Instructions**: frontmatter `applyTo: "<globs comma-joined>"`; body = generated-marker comment +
  `Before creating or editing files matched by this rule, read:` + dash list of `.agent/`-prefixed
  inject paths.
- **Rules** (`.omp/rules/anti-patterns.md`): frontmatter `description: Anti-patterns from
  .agent/docs/standards/anti-patterns.md (auto-compiled)`, `condition: [<JSON-quoted regexes>]`,
  `interruptMode: prose-only`; body = marker + one line: `Matched output violates an anti-pattern.
  Read .agent/docs/standards/anti-patterns.md, point out the violation, and fix it.`

**File: `harness/src/platforms/omp.test.ts`** — full code:

```typescript
import { describe, expect, test } from "bun:test";
import { ompAdapter } from "./omp.ts";
import { loadProjectContext } from "../commands/sync.ts";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";

const AGENT_IMPLEMENT_GOLDEN = `---
name: implement
description: Drive spec implementation task-group by task-group. Triggers on "implement", "build this", "run the spec".
model: "@task"
---

<!-- GENERATED by harness sync — do not edit -->
## Preflight
1. If \`.agent/manifest.json\` is missing → stop; tell the user to run \`harness init\`.
2. Run \`harness doctor\`. Fix 🔴 errors before proceeding.
3. Run \`harness state\` and read the output.

## Task
Load the skill \`implement\` and follow it exactly.
`;

const INSTR_BACKEND_GOLDEN = `---
applyTo: "convex/**,src/server/**"
---

<!-- GENERATED by harness sync — do not edit -->
Before creating or editing files matched by this rule, read:

- .agent/docs/standards/backend/api.md
`;

// V1–V4, V9: reconcile with the Verified Constants table before pinning.
const CONFIG_GOLDEN = `# GENERATED by harness sync — do not edit (harness manages this whole file).
# Disables OMP's native ingestion of directories the harness already bridges,
# so .agent/ content never loads twice (harness spec 00 §3 C4).
disabledProviders:
  - claude
  - agent
  - agents

# Model role overrides — uncomment and edit to customize (roles: default, smol,
# slow, vision, plan, designer, commit, tiny, task, advisor).
# modelRoles:
#   task: "<provider/model>"
`;

const HOOK_GOLDEN = `// GENERATED by harness sync — do not edit.
import type { HookAPI } from "@oh-my-pi/pi-coding-agent/hooks";

/** On session start, run \`harness doctor --json\` and surface errors without blocking. */
export default function (pi: HookAPI) {
  pi.on("session_start", async (ctx) => {
    try {
      const proc = Bun.spawn(["harness", "doctor", "--json"], { stdout: "pipe", stderr: "pipe" });
      const out = await new Response(proc.stdout).text();
      await proc.exited;
      const errors = (JSON.parse(out) as Array<{ level: string }>).filter((i) => i.level === "error");
      if (errors.length > 0) ctx.ui.notify(\`harness doctor: \${errors.length} error(s) — run harness doctor\`);
    } catch {} // harness missing or doctor crashed — never block a session.
  });
}
`;

describe("ompAdapter.plan", () => {
  const dir = mkTmpProject({ fixture: "initialized" });
  const { ctx } = loadProjectContext({ root: dir });
  const plan = ompAdapter.plan({ ctx });
  const file = (p: string) => plan.files.find((f) => f.path === p)?.content;

  test("symlinks + gitignore + full sorted file set", () => {
    expect(plan.symlinks).toEqual([
      { linkPath: ".omp/AGENTS.md", targetPath: ".agent/AGENTS.md" },
      { linkPath: ".omp/skills", targetPath: ".agent/skills" },
    ]);
    expect(plan.gitignoreLines).toEqual([".omp/"]);
    expect(plan.files.map((f) => f.path)).toEqual([
      ".omp/agents/dev-spec.md",
      ".omp/agents/implement.md",
      ".omp/config.yml",
      ".omp/hooks/session-doctor.ts",
      ".omp/instructions/naming.instructions.md",
      ".omp/instructions/std-backend.instructions.md",
    ]);
  });
  test("goldens: agent / instructions / config / hook", () => {
    expect(file(".omp/agents/implement.md")).toBe(AGENT_IMPLEMENT_GOLDEN);
    expect(file(".omp/agents/dev-spec.md")).not.toContain("model:");   // no role → no model line
    expect(file(".omp/instructions/std-backend.instructions.md")).toBe(INSTR_BACKEND_GOLDEN);
    expect(file(".omp/config.yml")).toBe(CONFIG_GOLDEN);
    expect(file(".omp/hooks/session-doctor.ts")).toBe(HOOK_GOLDEN);
  });
  test("anti-pattern rules file only when a pattern: line exists", () => {
    expect(file(".omp/rules/anti-patterns.md")).toBeUndefined();
    const ctx2 = { ...ctx, antiPatternRegexes: ["\\bany\\b"] };
    const rules = ompAdapter.plan({ ctx: ctx2 }).files.find((f) => f.path === ".omp/rules/anti-patterns.md");
    expect(rules?.content).toContain(`condition: ["\\\\bany\\\\b"]`);
    expect(rules?.content).toContain("interruptMode: prose-only");
  });
  test("commit_bridges suppresses gitignore line", () => {
    const ctx2 = { ...ctx, manifest: { ...ctx.manifest, platforms: { ...ctx.manifest.platforms, commit_bridges: true } } };
    expect(ompAdapter.plan({ ctx: ctx2 }).gitignoreLines).toEqual([]);
    rmProject({ dir });
  });
});
```

## Step 5: Claude adapter `[dev]`

- [ ] Create `src/platforms/claude.ts` + `src/platforms/claude.test.ts`; run tests

**File: `harness/src/platforms/claude.ts`** — `claudeAdapter: PlatformAdapter` (`id: "claude"`,
`dir: ".claude"`), guided stub mirroring Step 4: symlink `.claude/skills → ../.agent/skills`;
files `.claude/CLAUDE.md` + `.claude/settings.json` (goldens below are the full contract);
gitignoreLines `[".claude/"]` unless `commit_bridges`. Export
`CLAUDE_SETTINGS_FRAGMENT = { hooks: { SessionStart: [{ hooks: [{ type: "command", command: "harness doctor" }] }] } }`
— sync's merge step (Step 6) imports it; `plan()` serializes it with `JSON.stringify(…, null, 2) + "\n"`.

**File: `harness/src/platforms/claude.test.ts`** — full code:

```typescript
import { describe, expect, test } from "bun:test";
import { claudeAdapter } from "./claude.ts";
import { loadProjectContext } from "../commands/sync.ts";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";

const CLAUDE_MD_GOLDEN = `@.agent/AGENTS.md

<!-- GENERATED by harness sync — do not edit. Edit .agent/AGENTS.md instead. -->

At the start of every message, classify the intent:
  - "I need to debug / something is broken / this isn't working" → load debug/SKILL.md
  - "write a spec / spec out X / what should we build" → load dev-spec/SKILL.md
  - "implement / build this / run the spec" → load implement/SKILL.md
  - "commit / generate commit message / end of session" → load commit/SKILL.md
  - "sync spec / update the spec / extract patterns" → load sync-spec/SKILL.md
  - "polish / review the code / check for completeness" → load polish/SKILL.md
  - "research / learn about / how does X work" → load research/SKILL.md or learn/SKILL.md
  - General project question → read state.md, answer from harness context

If ambiguous, proceed with current skill but note the classification at top of response.

Claude Code has no native context injection: before writing or editing code for a
spec, run \`harness context --for <path>\` and read every file it lists.
`;

const SETTINGS_GOLDEN = `{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "harness doctor"
          }
        ]
      }
    ]
  }
}
`;

describe("claudeAdapter.plan", () => {
  test("symlink, goldens, gitignore", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const { ctx } = loadProjectContext({ root: dir });
    const plan = claudeAdapter.plan({ ctx });
    expect(plan.symlinks).toEqual([{ linkPath: ".claude/skills", targetPath: ".agent/skills" }]);
    expect(plan.files.map((f) => f.path)).toEqual([".claude/CLAUDE.md", ".claude/settings.json"]);
    expect(plan.files[0]?.content).toBe(CLAUDE_MD_GOLDEN);
    expect(plan.files[1]?.content).toBe(SETTINGS_GOLDEN);
    expect(plan.gitignoreLines).toEqual([".claude/"]);
    rmProject({ dir });
  });
});
```

The routing directive body is proposal §17 verbatim — do not paraphrase it.

## Step 6: `mergeManagedJson` + gitignore block `[dev]`

- [ ] Append both functions to `src/commands/sync.ts`; append tests to `sync.test.ts`; run tests

```typescript
/**
 * Merges the managed settings fragment into a user-owned JSON file, touching ONLY the keys sync
 * manages (D10). Managed today: the one hooks.SessionStart entry whose command is
 * "harness doctor". Everything else is preserved.
 *
 * @param props.existingText - Current file text, or null when the file does not exist.
 * @param props.fragment - The managed fragment (CLAUDE_SETTINGS_FRAGMENT shape).
 * @returns merged: full new file text (2-space indent + trailing newline), or null when no write
 *   is needed (already merged, byte-idempotent); conflict: set instead when existing is not
 *   parseable JSON — caller reports, never writes.
 */
export function mergeManagedJson(props: {
  existingText: string | null;
  fragment: Record<string, unknown>;
}): { merged: string | null; conflict?: string } {
  // TODO: implement
  // 1. existingText null → merged = stringify(fragment). Parse failure → { merged: null,
  //    conflict: "not valid JSON — fix or delete it, then re-run harness sync" }.
  // 2. obj.hooks ??= {}; obj.hooks.SessionStart ??= []. If NO entry in SessionStart has a
  //    nested hooks[] item with command === "harness doctor" → append fragment's entry.
  //    User's own entries keep their positions; ours appends last.
  // 3. Reserialize. Identical to existingText → { merged: null } (idempotent no-op).
  //
  // Edge cases: user entry ALSO runs "harness doctor" (theirs counts — do not duplicate);
  // hooks.SessionStart is not an array → conflict (do not guess); user formatting/key order
  // outside managed keys is preserved by mutating the parsed object in place, not rebuilding it.
  throw new Error("Not implemented");
}

/**
 * Rewrites the managed marker block in the project .gitignore.
 *
 * @param props.existingText - Current .gitignore text or null.
 * @param props.lines - Desired managed lines (engine sorts them).
 * @returns New full text, or null when no change is needed. Empty lines + no existing block →
 *   null; empty lines + existing block → block removed.
 */
export function updateGitignoreBlock(props: { existingText: string | null; lines: string[] }): string | null {
  // TODO: implement — markers per the Design Decisions; replace existing block in place, else
  // append (blank-line separated); preserve all user lines byte-exact; create the file when
  // existingText is null and lines is non-empty.
  throw new Error("Not implemented");
}
```

**Tests** (append to `sync.test.ts`, full code): (a) null existing → golden fragment text;
(b) user file `{"permissions":{"allow":["Bash(ls:*)"]},"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}`
→ merged output keeps `permissions` and the `echo hi` entry and appends the harness entry last;
(c) re-merge of (b)'s output → `merged: null`; (d) `not json{` → conflict set, merged null;
(e) gitignore: null + `[".omp/"]` → block created; existing user lines survive a block rewrite;
lines `[]` with a block present → block removed, user lines intact.

## Step 7: `harness sync` engine `[dev]`

- [ ] Append `MERGE_PATHS`, `ADAPTERS`, `runSync`, and the CLI `run` export to `sync.ts`; wire
      `sync` into the cli.ts command table; append tests; run tests

```typescript
import { ompAdapter } from "../platforms/omp.ts";
import { claudeAdapter } from "../platforms/claude.ts";

/** Adapter registry — the single place platform.ts and sync share. */
export const ADAPTERS = { omp: ompAdapter, claude: claudeAdapter } as const;

/** Paths applied via mergeManagedJson instead of whole-file D10 hashing. */
export const MERGE_PATHS = new Set([".claude/settings.json"]);

/**
 * The adapter-agnostic sync engine (master §9.1 flow + D10).
 *
 * @param props.root - Absolute project root.
 * @param props.reporter - Sink; one line per created/updated/deleted/conflict + final summary.
 * @returns EXIT.FINDINGS when any conflict was reported, else EXIT.OK.
 */
export function runSync(props: { root: string; reporter: Reporter }): number {
  // TODO: implement
  // 1. { ctx, warnings } = loadProjectContext; warnings → reporter.warn. prev = loadSyncManifest.
  // 2. Desired state, in order: core file { path: ".agent/context-rules.yaml", content:
  //    ctx-rules yaml, platform "core" } + core gitignore line ".agent/dependencies/*", then for
  //    each manifest.platforms.active id → ADAPTERS[id].plan({ ctx }) (unknown id →
  //    HarnessError "unknown-platform"). Tag every item with its platform.
  // 3. FILES — for each desired file, diskText = read(path), prevEntry = prev by path:
  //    a. path ∈ MERGE_PATHS → mergeManagedJson({ existingText: diskText, fragment:
  //       CLAUDE_SETTINGS_FRAGMENT }); conflict → report(skip); merged null → "unchanged";
  //       else write → diskText===null ? "created" : "updated". Entry hash = sha256(final text).
  //    b. diskText null → writeFileAtomic → "created".
  //    c. prevEntry && sha256(diskText) === prevEntry.target_or_hash → managed-unchanged:
  //       content same → "unchanged" (no write); differs → writeFileAtomic → "updated".
  //    d. prevEntry && hash differs → CONFLICT "user-modified managed file — left in place"
  //       (hint: "move your edits into .agent/ and delete <path>, then re-run harness sync").
  //       KEEP prevEntry in the new manifest (design decision).
  //    e. no prevEntry && diskText non-null → CONFLICT "exists but is not managed by harness —
  //       left untouched". No manifest entry.
  // 4. SYMLINKS — ensureSymlink(abs paths); "created"/"replaced" → report; "ok" → unchanged;
  //    "conflict" → report like 3e. Entry { kind: "symlink", target_or_hash: targetPath }.
  // 5. DELETIONS — prev entries whose path is absent from desired (and whose platform is either
  //    "core" or still-active — inactive platforms' entries are exactly the removal case):
  //    symlink → rm iff lstat says symlink; generated → rm iff sha256(disk) === recorded hash,
  //    else CONFLICT "was managed, now removed from plan, but user-modified — delete manually";
  //    gitignore-line → handled by step 6. rmdir now-empty bridge dirs (.omp, .claude, and their
  //    subdirs), deepest first.
  // 6. GITIGNORE — updateGitignoreBlock with sorted desired lines (skip entirely when
  //    commit_bridges? NO — adapters already returned [] then; core dependencies line remains).
  //    Manifest entries per line, path ".gitignore#<line>".
  // 7. saveSyncManifest({ version: 1, generated_at_sha: headSha(root), entries: sorted by path }).
  // 8. reporter.info(`sync: <c> created, <u> updated, <n> unchanged, <d> deleted, <x> conflicts`);
  //    return conflicts > 0 ? EXIT.FINDINGS : EXIT.OK.
  //
  // Edge cases: first run (empty prev manifest); no git repo → generated_at_sha "";
  // a desired file whose parent dir is a planned symlink (never happens — plans keep generated
  // files outside symlinked dirs; assert in dev).
  throw new Error("Not implemented");
}
```

CLI: `harness sync [--json]`.

**Tests** (append to `sync.test.ts`, full code — every test on a fresh `initialized` temp copy with
`gitInit`):

1. **Full first sync** — exit 0; on-disk file set under `.omp/` + `.claude/` equals exactly the
   plan paths from Steps 4–5; `readlinkSync(.omp/skills)` → `../.agent/skills` (relative — uses
   ensureSymlink's contract), same for `.omp/AGENTS.md`, `.claude/skills`;
   `.agent/context-rules.yaml` equals `CONTEXT_RULES_GOLDEN`; `.gitignore` marker block holds
   exactly `.agent/dependencies/*`, `.claude/`, `.omp/` (sorted); sync-manifest has 15 entries
   (9 generated + 3 symlinks + 3 gitignore-lines), sorted by path, `generated_at_sha` 40-hex.
2. **Idempotency** — snapshot `Map<path, sha256>` of every file under `.omp/`, `.claude/`, plus
   `.agent/context-rules.yaml` and `.gitignore` after sync #1; sync #2 → summary reports
   `0 created, 0 updated, … 0 deleted, 0 conflicts`; snapshot #2 deep-equals #1 (byte-identical).
3. **D10a managed-unchanged rewrite** — edit `description` in `.agent/skills/implement/SKILL.md`;
   sync #2 reports `.omp/agents/implement.md` updated; file contains the new description.
4. **D10b user-modified managed** — append `# mine\n` to `.omp/config.yml`; sync → exit 1, warn
   names `.omp/config.yml`, file still ends `# mine`, manifest entry kept with the OLD hash.
5. **D10c unmanaged existing** — pre-create `.claude/CLAUDE.md` (`custom\n`) before first sync →
   exit 1, conflict reported, file still `custom\n`, no manifest entry; all other files created.
6. **D10d formerly-managed cleanup** — sync both platforms; set `platforms.active: ["omp"]`
   (saveManifest); sync → `.claude/` gone entirely (files, symlink, then empty dir), `.claude/`
   line gone from the gitignore block, no `claude`-platform manifest entries; exit 0.
7. **Symlink repair + conflict** — `rm .omp/skills && ln -s ../nowhere .omp/skills` → sync reports
   replaced, readlink correct again. Then `rm -r .claude/skills && mkdir .claude/skills` → sync
   reports conflict, dir untouched, exit 1.
8. **settings.json merge** — hand-edit `.claude/settings.json` adding
   `"permissions": {"allow": ["Bash(ls:*)"]}` and a user SessionStart entry (`echo hi`); sync →
   exit 0 (merge path, never a conflict), file keeps both user pieces AND the `harness doctor`
   entry; sync again → byte-identical (assert hash).

## Step 8: `harness platform add|list` `[agent]`

- [ ] Create `src/commands/platform.ts` + `src/commands/platform.test.ts`; wire `platform` into
      the cli table; run tests

`runPlatform(props: { args; root; reporter }): Promise<number>` — full code (it is thin):

- `add <id>`: `id` not in `KNOWN_PLATFORM_IDS` → `HarnessError("unknown-platform",
  "unknown platform \"<id>\" (known: omp, claude)", { exitCode: EXIT.USAGE })`. Already in
  `platforms.active` → `reporter.info("<id> already active")`, still run `runSync`, exit OK.
  Else append to `platforms.active`, `saveManifest`, `runSync` (full sync — plans are cheap and
  the engine is idempotent), return sync's exit code.
- `list`: one line per known id: `omp    active` / `claude available` (active when in
  `platforms.active`); exit OK.
- No/unknown subcommand → usage error.

**Tests** (full code): fixture with manifest edited to `platforms.active: ["omp"]` → `platform add
claude` exits 0, manifest now `["omp","claude"]`, `.claude/CLAUDE.md` exists; `platform add nope`
→ exit 2 naming `nope`; duplicate add → "already active" + exit 0 + still idempotent on disk;
`platform list` before/after shows `claude available` then `claude active`.

## Step 9: Doctor checks `[dev]`

- [ ] Create `src/checks/shimsStale.ts` + `src/checks/contextRulesStale.ts` (follow 01's check
      file-naming pattern) + one test file each; register both in doctor.ts's static list; run tests

**`shims-stale`** · warn · appliesWhen: sync-manifest exists with ≥1 entry AND `isRepo`:

```
// run() contract:
// 1. sm = JSON.parse(ctx.read(P.syncManifest)). For each entry: lstat-style existence probe via
//    ctx.read/listFiles is NOT enough for symlinks — use existsSync(join(root, path)) for
//    generated files and lstat for symlinks (gitignore-line entries: check the line is present in
//    .gitignore). Missing → finding `<path> is missing on disk` (hint "harness sync").
// 2. sm.generated_at_sha non-empty → changed = changedFilesSince({ root, sha }); any path
//    starting ".agent/" (excluding ".agent/.sync-manifest.json" and ".agent/docs/state.md") →
//    ONE finding `.agent/ changed since last sync (<n> files)` (hint "harness sync").
```

**`context-rules-stale`** · warn · appliesWhen: `.agent/` exists (always for an initialized project):

```
// run() contract:
// 1. expected ids = for each manifest.standards_domains domain with ≥1 .md file under its folder
//    whose frontmatter has non-empty applies_to → `std-<domain>`; plus "naming" when
//    modules.naming_conventions && naming-conventions.md exists.
// 2. actual ids = yaml-parse ctx.read(P.contextRules) → rules[].id ([] when file absent).
// 3. Set difference in either direction → one finding per id: `rule <id> missing from
//    context-rules.yaml` / `rule <id> is stale (source gone)`, hint "harness sync".
```

**Tests** (full code, git fixture): after `runSync` + `git add -A && git commit`, doctor reports
both checks ✅. Seed shims-stale: commit a change to `.agent/docs/standards/backend/api.md` →
warn with "changed since last sync"; `rm .omp/AGENTS.md` → warn naming it. Seed
context-rules-stale: add `docs/standards/frontend/state.md` (with `applies_to: ["src/app/**"]`)
and push `"frontend"` onto `standards_domains` → warn `rule std-frontend missing…`; delete
`naming-conventions.md` → warn `rule naming is stale…`.

---

## Adding a Future Platform (opencode / codex) — recipe, no code now

1. **Verify ingestion** in the target tool: where skills/instructions/agent files live, whether it
   tolerates unknown frontmatter keys (the shared-skills symlink depends on this), whether it
   ingests `.agent/` natively (if so the bridge may be a disable-guard plus symlinks, like OMP's).
2. **Implement** `src/platforms/<id>.ts` exporting a `PlatformAdapter` with a pure `plan()`,
   symlinks-first (D6): symlink everything readable in place, generate only glue it cannot read.
   Emit at least one generated file if the platform ignores empty dirs.
3. **Register**: add the id to `KNOWN_PLATFORM_IDS` in `src/platforms/types.ts` (widens
   `PlatformId` and manifest validation automatically) and to `ADAPTERS` in `sync.ts`.
4. **Golden-test** like Steps 4–5: pin every generated file's bytes against the `initialized`
   fixture, plus an idempotency run. The sync engine, D10 rules, gitignore block, and
   `platform add` need zero changes — that is the point of the contract.

---

## Verification (mandatory)

- [ ] Verified Constants table fully filled in; goldens reconciled with it
- [ ] `cd harness && bun test` — all green, no skipped tests
- [ ] `bunx tsc --noEmit` — clean
- [ ] Manual smoke (master §12): on a scratch copy of this dotfiles repo, run `harness init`
      (skill or primitives) then `harness sync`. Open Claude Code in it — skills visible through
      `.claude/skills`; `cat .claude/CLAUDE.md` shows the import + routing directive. If bun/OMP
      installed: open OMP, confirm skills + AGENTS.md load once (no double context — the
      `disabledProviders` guard works) and `.omp/agents/*` appear as subagents.
- [ ] Re-run `harness sync` on the smoke repo → summary reports zero changes

## Success Criteria

- [ ] Every generated bridge file is byte-pinned by a golden test and stable across re-runs
- [ ] Second sync is a byte-identical no-op (hash-map assertion, not just the summary line)
- [ ] All four D10 cases behave per their tests: rewrite / skip+report / never-touch+report /
      delete+cleanup (including gitignore line removal and empty-dir pruning)
- [ ] `.claude/settings.json` merge preserves arbitrary user keys and user hook entries
- [ ] `harness platform add` validates ids, mutates the manifest, and bridges the new platform in
      one command; `list` distinguishes active from available
- [ ] `shims-stale` and `context-rules-stale` catch their seeded fixtures and pass when clean
- [ ] Generated `.omp/config.yml` disables the verified provider ids so harness content loads
      exactly once in OMP
