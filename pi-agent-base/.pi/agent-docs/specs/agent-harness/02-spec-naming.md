# 02 — Spec, Naming, Structure, Context

> Phase spec 2 of 8. Prereqs: `00-master.md` (§2 conventions + §7 schemas binding) and
> `01-foundation.md` — this spec **reuses** 01's lib (`paths.P`, `parseArgs`, `Reporter`,
> frontmatter, `fsx.walk/sha256/writeFileAtomic`, `git`, `manifest`, doctor
> `CheckContext`/`DoctorCheck`, `runCli`/`mkTmpProject`/`gitInit` helpers, fixtures) and never
> respecs them. Proposal sources: §3.4, §4.3, §10, §11, §18.6, §18.7, §15.

## Overview

Deliver `harness spec new|list`, `struct [--check]`, `index rebuild`, `context --for`,
`pref compact|remove`; the naming-rules parser; the generated `directory-structure.md` +
`index.yml` formats (golden-tested); doctor checks `naming-violations`, `structure-stale`,
`index-stale`; and the `dev-spec` + `sync-spec` skills plus the init skill's missing
`naming-interview.md` reference.

## Design Decisions (contracts invented by this spec)

- **D02-1 Spec frontmatter.** `spec.md` AND `spec-tasks.md` carry the same block: `status`
  (`draft | in-progress | done | abandoned`), `spec_id` (`<YYYY-MM-DD>-<slug>` = dir name),
  `touches` (string[] globs, starts `[]`), `prompt_version` (int, starts `1`; bumped when the
  dev-spec spec-format changes). Both files because 01's `open-specs-stale` reads `touches` from
  `spec-tasks.md` while `harness state` reads `spec.md`.
- **D02-2 Dates come from git, never `Date.now()`** (master §2.8): `spec new` uses the HEAD
  commit date (`git log -1 --format=%cs`) or injected `--date YYYY-MM-DD`; neither available →
  `HarnessError("no-date", …, hint: "pass --date YYYY-MM-DD")`.
- **D02-3 Preference entry grammar**: `- P-NNN (YYYY-MM-DD) <text>` + optional
  ` [supersedes P-MMM]`. Ids monotonic (max + 1), **never reused or renumbered**; removals are
  recoverable via git history — that is the rollback story for `pref remove <id>`.
- **D02-4 Provenance line** in `directory-structure.md`:
  `> Last updated by harness struct (SHA: <full-sha|unknown>)`; `structure-stale` parses it.
- **D02-5 New lib `src/lib/glob.ts`** (`globMatch`; `**`/`*`/`?`, no braces) — 01 specs no glob
  matcher; naming scopes, `context --for`, and 04's context-rules compilation need one.
- **D02-6 git.ts additions** (extends, never respecs, 01): `headCommitDate`, `recentChangedFiles`.
- **D02-7 index.yml description extraction**: skip frontmatter, headings, fenced blocks, blank,
  list (`- `) and table (`| `) lines; first remaining line with leading `> ` stripped. None →
  `"(first paragraph missing — add one)"` (master §7.5).
- **D02-8 index.yml is hand-emitted** (stable flow style `key: { description: "…", lines: N }`)
  and parse-validated with the `yaml` package, which is also used to *read* the naming-rules
  block, `context-rules.yaml`, and `index.yml` (master §2.2).
- **D02-9 Checks needing git call `src/lib/git.ts` directly with `ctx.root`** (the pattern 01's
  `open-specs-stale` set); `CheckContext` is not extended.

## Out of Scope

Everything from specs 03–08: session log/commit/env (03), sync + adapters + context-rules
*generation* (04 — this spec only *consumes* an existing `context-rules.yaml`), implement/polish
(05), deps (06), templates mechanism (07), worktree/wiring (08). `preferences-over-budget` ships
in 01 — not respecced; this spec only provides the `harness pref compact` its hint names.

## Implementation Order

> `[agent]` = boilerplate/pattern-following · `[dev]` = core logic, guided stub named per step

1. `[agent]` Extend the `initialized` fixture (naming rules, seed files, P-NNN preferences, goldens)
2. `[dev]` `glob.ts` + `git.ts` additions — key fns: `globMatch`, `recentChangedFiles`
3. `[dev]` Naming-rules parser — key fns: `parseNamingRules`, `checkPath`
4. `[dev]` `harness spec new|list` — key fns: `specNew`, `specList`
5. `[dev]` `harness index rebuild` — key fn: `buildIndex` (golden)
6. `[dev]` `harness struct [--check]` — key fn: `buildStruct` (golden)
7. `[dev]` `harness context --for` — key fn: `matchContextRules`
8. `[dev]` `harness pref compact|remove` — key fns: `parsePrefEntries`, `compactPrefs`
9. `[dev]` Doctor checks: `naming-violations`, `structure-stale`, `index-stale`
10. `[agent]` `src/templates/standards/naming-conventions.template.md`
11. `[agent]` dev-spec skill (SKILL.md + 4 references)
12. `[agent]` sync-spec skill (SKILL.md + 2 references)
13. `[agent]` init skill reference `naming-interview.md`
14. Verification

---

## Step 1: Extend the `initialized` fixture `[agent]`

- [ ] Add the root files below + replace the three standards placeholders; re-run 01's suite —
      still green (01 asserts no fixture *content* this step touches; its budget tests seed
      their own files)
- [ ] After Steps 5–6 land, bootstrap the two GENERATED fixture files by running `struct` then
      `index rebuild` once on the fixture (no git → `SHA: unknown`) and committing the
      byte-exact output

Root additions (normative — the Step 6 golden assumes exactly this tree; align the fixture):
`package.json` = `{"name":"initialized","version":"0.0.0","scripts":{"build":"true","test":"true"}}`;
seed files each containing `export const a = 1;`: `src/components/FilterPanel.tsx` (complies),
`src/components/badFile.tsx` (VIOLATES react-components), `src/hooks/useFilterState.ts`
(complies), `src/lib/date-utils.ts` (complies), `src/lib/helperStuff.ts` (VIOLATES lib-modules).
Standards additions: `naming-conventions.md`, `directory-structure.md`, `index.yml`,
`backend/api.md` (3 lines: `# Backend API Standards`, blank,
`Convex function modules live in convex/ and follow the get/list/create naming verbs.`).
01 left `docs/specs/` empty — represent it as `docs/specs/.gitkeep`. Keep `dev-processes.md`
referencing only the `build`/`test` scripts above (keeps 01's `stale-commands` green). `walk`
prunes `.agent/dependencies`, so `registry.md`/`.gitignore` stay but never appear in struct
output.

**File: `.agent/docs/standards/anti-patterns.md`** (replaces 01's placeholder; 6 lines):

```markdown
# Anti-Patterns

> MAX 40 lines. Real corrections only. Never auto-compact. Append-only via sync-spec.

- AP-001 (2026-06-12, seen 2x) Never use Date.now() in generated files — timestamps come from git or an injected clock
- AP-002 (2026-07-01, seen 1x) Never add npm runtime dependencies to the CLI core
```

**File: `.agent/docs/standards/preferences.md`** (replaces 01's placeholder; 10 lines; P-001/P-003
are deliberate duplicates, P-005 supersedes P-002 — `pref compact` tests depend on this):

```markdown
# Preferences

> MAX 80 lines (manifest budget). Entry format: `- P-NNN (YYYY-MM-DD) text [supersedes P-MMM]`.

- P-001 (2026-06-01) Prefer type aliases over interfaces except for public extendable contracts
- P-002 (2026-06-08) Use bun:test describe/test blocks, never it()
- P-003 (2026-06-15) Prefer type aliases over interfaces except for public extendable contracts
- P-004 (2026-06-20) Name Convex mutations create/update/delete, never save or upsert
- P-005 (2026-07-02) Import node builtins with the node: prefix [supersedes P-002]
- P-006 (2026-07-10) Keep React components under 150 lines
```

**File: `.agent/docs/standards/naming-conventions.md`** (30 lines; the 3-rule block drives every
naming test; format per proposal §18.6):

````markdown
# Naming Conventions — initialized

> See also: directory-structure.md — these rules applied to the actual project layout.
> Updated by sync-spec when spec naming deviates from developer implementation.

## Rules (machine-readable)

Used by `harness struct --check` and `harness doctor` (naming-violations check).

```yaml
rules:
  - id: react-components
    pattern: "^[A-Z][a-zA-Z0-9]+\\.tsx$"
    scope: ["src/components/**"]
    description: React components — PascalCase .tsx
    examples: ["FilterPanel.tsx"]
    counter_examples: ["badFile.tsx"]
  - id: react-hooks
    pattern: "^use[A-Z][a-zA-Z0-9]+\\.ts$"
    scope: ["src/hooks/**"]
    description: React hooks — use-prefixed camelCase .ts
  - id: lib-modules
    pattern: "^[a-z][a-z0-9-]+\\.ts$"
    scope: ["src/lib/**"]
    description: Lib modules — kebab-case .ts
```

## Code Identifier Conventions

- Props objects: the parameter name is always `props` — never `opts` or `options`.
````

**File: `.agent/docs/standards/directory-structure.md`** — byte-identical to the Step 6 struct
golden (bootstrap it from the implemented command; SHA `unknown` because the fixture is not a
repo). **File: `.agent/docs/standards/index.yml`** — byte-identical to the Step 5 index golden.
Both files are asserted in both directions: fixture content == command output.

---

## Step 2: `glob.ts` + `git.ts` additions `[dev]`

- [ ] Create `src/lib/glob.ts` + `src/lib/glob.test.ts`
- [ ] Append two functions to `src/lib/git.ts` + tests to `src/lib/git.test.ts`; run tests

**File: `harness/src/lib/glob.ts`**

```typescript
/**
 * Minimal deterministic glob matcher for root-relative POSIX paths.
 * Supports `**` (any depth incl. none), `*` (within a segment), `?` (one char);
 * no braces/extglobs. A trailing "/" matches everything under that directory.
 *
 * @param props.pattern - Glob pattern, e.g. "src/components/**".
 * @param props.path - Root-relative POSIX path.
 * @returns True when the path matches.
 */
export function globMatch(props: { pattern: string; path: string }): boolean {
  // TODO: implement
  // 1. Normalize: strip leading "./"; trailing "/" → append "**".
  // 2. Compile → RegExp (module-level cache): escape regex chars, then
  //    "**/" → "(?:[^/]+/)*", "**" → ".*", "*" → "[^/]*", "?" → "[^/]". Anchor ^…$.
  // Edge cases: "**" matches everything; "a/**" matches "a/b" but NOT "a" itself;
  //   dotfiles match like any other name.
  throw new Error("Not implemented");
}
```

Test (full file): exact cases —
`("src/components/**","src/components/deep/A.tsx")→true`, `("src/components/**","src/hooks/a.ts")→false`,
`("**/*.ts","a/b/c.ts")→true`, `("**/*.ts","a/b/c.tsx")→false`, `("*.ts","a/b.ts")→false`,
`("convex/**","convex/collections.ts")→true`, `("src/?ib/**","src/lib/x.ts")→true`,
`(".agent/docs/specs/*/","​.agent/docs/specs/2026-08-02-x/spec.md")→true`, `("**","anything/x")→true`.

**Additions to `harness/src/lib/git.ts`** (full code, execSync wrappers, same safe-default style
as 01): `headCommitDate(props: { root: string }): string` — `git log -1 --format=%cs` →
`"YYYY-MM-DD"`, `""` on any error/no commits; `recentChangedFiles(props: { root; commits: number
}): string[]` — `git log -n <commits> --name-only --format=` (handles repos with fewer than
`commits` commits without error), deduped, sorted, `[]` on any error. Tests: after `gitInit` with
`GIT_AUTHOR_DATE=GIT_COMMITTER_DATE="2026-01-15T12:00:00Z"`, `headCommitDate` is `"2026-01-15"`;
`recentChangedFiles` on a repo with 2 commits and `commits: 10` returns the exact sorted union;
non-repo → `""` / `[]`.

---

## Step 3: Naming-rules parser `[dev]`

- [ ] Create `src/lib/namingRules.ts` + `src/lib/namingRules.test.ts`; run tests

**File: `harness/src/lib/namingRules.ts`**

```typescript
import { parse as parseYaml } from "yaml";
import { globMatch } from "./glob.ts";
import { HarnessError } from "./errors.ts";

/** One machine-readable naming rule (master §7.4 / proposal §18.6). */
export interface NamingRule {
  id: string;
  /** Regex tested against the file BASENAME only. */
  pattern: string;
  /** Globs tested against the root-relative path. */
  scope: string[];
  description: string;
  examples?: string[];
  counter_examples?: string[];
}

/**
 * Extracts and parses the fenced ```yaml block containing top-level `rules:` from
 * naming-conventions.md. Prose sections are never machine-parsed (master §7.4).
 *
 * @param props.text - Full naming-conventions.md content.
 * @returns Rules in file order.
 * @throws {HarnessError} code "naming-rules-invalid" — no ```yaml fence with a top-level
 *   `rules:` array; YAML parse failure; rule missing id/pattern/scope/description;
 *   pattern not a valid RegExp.
 */
export function parseNamingRules(props: { text: string }): NamingRule[] {
  // TODO: implement
  // 1. Scan column-0 ```yaml fences; pick the FIRST whose parsed value has an array `rules`.
  //    None → naming-rules-invalid ("no rules block found").
  // 2. Validate each rule: required keys; scope non-empty string[]; new RegExp(pattern)
  //    must not throw. Error names the offending rule id/index.
  // Edge cases: multiple yaml fences (only the rules one counts); CRLF input.
  throw new Error("Not implemented");
}

/**
 * Checks one path. In-scope when ≥1 rule's scope glob matches the path; compliant when
 * AT LEAST ONE in-scope rule's regex accepts the BASENAME (lets a broad rule like
 * test-files coexist with per-dir rules).
 *
 * @param props.path - Root-relative POSIX path.
 * @param props.rules - Parsed rules.
 * @returns matched = in-scope rule ids in rule order ([] = not governed → ok);
 *   ok = compliant; when !ok, matched[0] is the rule to report.
 */
export function checkPath(props: { path: string; rules: NamingRule[] }): {
  matched: string[]; ok: boolean;
} {
  // TODO: implement — basename after last "/"; globMatch for scope; RegExp for pattern.
  throw new Error("Not implemented");
}
```

Test (full file) against the exact fixture block (inline string copy of Step 1's yaml): parses 3
rules, ids `["react-components","react-hooks","lib-modules"]` in order; `checkPath` exact:
`src/components/FilterPanel.tsx → {matched:["react-components"], ok:true}`;
`src/components/badFile.tsx → {matched:["react-components"], ok:false}`;
`src/lib/helperStuff.ts → {matched:["lib-modules"], ok:false}`;
`README.md → {matched:[], ok:true}`; missing `rules:` doc and bad regex both throw
`/naming-rules-invalid|no rules block|invalid/`.

---

## Step 4: `harness spec new | list` `[dev]`

- [ ] Create `src/commands/spec.ts` + `src/commands/spec.test.ts`; register `spec` in the cli
      table; run tests

Grammar: `harness spec new "<slug>" [--date YYYY-MM-DD]`, `harness spec list [--all] [--json]`.

`specNew` contract (guided stub, key fn `specNew(props: { root; slug; date?: string })`):

```
// TODO: implement
// 1. Validate slug: /^[a-z][a-z0-9-]+$/ else HarnessError("usage", …, exit USAGE).
// 2. date = props.date (validate /^\d{4}-\d{2}-\d{2}$/) ?? headCommitDate(root);
//    still "" → HarnessError("no-date", "no git commit date available",
//    { hint: "pass --date YYYY-MM-DD" }).   [D02-2 — never Date.now()]
// 3. specId = `${date}-${slug}`; dir = P.specs/specId; exists → HarnessError("spec-exists").
// 4. writeFileAtomic spec.md and spec-tasks.md from the templates below; print both paths.
// Edge cases: modules.specs === false → HarnessError("module-disabled", hint
//   "enable modules.specs in .agent/manifest.json").
```

Both files start with the D02-1 frontmatter block — exactly the four lines `status: draft`,
`spec_id: <specId>`, `touches: []`, `prompt_version: 1` between `---` delimiters — then:
`spec.md` body `# <specId> — Spec\n\n## Overview\n\n## Design Decisions\n\n## Out of Scope\n\n## Implementation\n`;
`spec-tasks.md` body `# <specId> — Tasks\n\n## T1 — <title>\nWhy:\nVerify:\n- [ ] \n`.

`specList(props: { root })`: read every `P.specs/*/spec.md` frontmatter (01 parser); skip
`status: done|abandoned` unless `--all`; count `- [ ]` (open) and `- [ ]`+`- [x]` (total) in the
sibling `spec-tasks.md`; print one line per spec, sorted by dir name:
`<spec_id>  <status>  <open> open / <total> total`. Empty → `(no open specs)`, exit 0. `--json`
emits `[{ spec_id, status, open, total }]`.

Tests (full, via `runCli` on `initialized`): `spec new "collections-ui" --date 2026-02-03` creates
`​.agent/docs/specs/2026-02-03-collections-ui/{spec.md,spec-tasks.md}`; spec.md frontmatter parses
to `{ status: "draft", spec_id: "2026-02-03-collections-ui", touches: [], prompt_version: 1 }`
(exact); re-run → exit 2 `/spec-exists|already exists/`; bad slug `"My Spec"` → exit 2; no `--date`
in a non-repo → exit 2 `/no-date|--date/`; with `gitInit` under
`GIT_COMMITTER_DATE=2026-01-15T12:00:00Z` and no `--date` → dir prefix `2026-01-15-`; `spec list`
after creating two specs (one edited to `status: done`) shows exactly one line
`2026-02-03-collections-ui  draft  1 open / 1 total`; `--all` shows both.

---

## Step 5: `harness index rebuild` `[dev]`

- [ ] Create `src/commands/index.ts` + `src/commands/index.test.ts`; register `index`; run tests

Key fn `buildIndex(props: { root: string }): string` (guided stub):

```
// TODO: implement
// 1. files = walk(P.standards abs) filtered to *.md (index.yml is not .md — excluded
//    naturally). Group: no "/" → "root"; else group = first segment, key = remaining path
//    minus ".md" (slashes kept for depth>2).
// 2. description per D02-7 (frontmatter `description` wins); lines = count of
//    "\n"-terminated lines.
// 3. Emit "# GENERATED by harness index rebuild\n", then groups — "root" first, rest
//    alphabetical; keys alphabetical; entries `  <key>: { description: "<escaped>", lines: <n> }`
//    (always double-quoted, internal `"` escaped).
// Edge cases: empty standards dir → header + "root: {}\n"; file with only headings → the
//   "(first paragraph missing — add one)" description (never silent rot).
```

Command: writes `P.standards/index.yml` atomically, prints the path. **Golden test** (full):
running `index rebuild` on the extended fixture (after `struct` has produced
`directory-structure.md`) writes EXACTLY this — which is also the fixture's committed `index.yml`
(assert output === fixture file, and re-run is byte-idempotent):

```yaml
# GENERATED by harness index rebuild
root:
  anti-patterns: { description: "MAX 40 lines. Real corrections only. Never auto-compact. Append-only via sync-spec.", lines: 6 }
  directory-structure: { description: "GENERATED by `harness struct`. Do not edit manually.", lines: 55 }
  naming-conventions: { description: "See also: directory-structure.md — these rules applied to the actual project layout.", lines: 30 }
  preferences: { description: "MAX 80 lines (manifest budget). Entry format: `- P-NNN (YYYY-MM-DD) text [supersedes P-MMM]`.", lines: 10 }
backend:
  api: { description: "Convex function modules live in convex/ and follow the get/list/create naming verbs.", lines: 3 }
```

Additional test: output parses with the `yaml` package and round-trips the same object.

---

## Step 6: `harness struct [--check]` `[dev]`

- [ ] Create `src/commands/struct.ts` + `src/commands/struct.test.ts`; register `struct`; run tests

Key fn `buildStruct(props: { root: string; project: string; rules: NamingRule[]; headSha: string }): string`:

```
// TODO: implement
// 1. files = walk(root) (01's prune list). Split: workspace (not under .agent/) vs harness
//    (under .agent/).
// 2. Render each tree from a nested dir map: at every level subdirectories first
//    (alphabetical), then files (alphabetical), ├──/└──/│ box-drawing, 4-col indent — exactly
//    as the golden below.
// 3. Annotations: per directory, sorted rule ids matched (checkPath) by files DIRECTLY inside
//    → `  ← [→ id]` per id on the dir line. Per failing file → `  ← ✗ violates <matched[0]>`.
//    Two spaces before every `←`; no column alignment (determinism over prettiness).
// 4. Assemble: 4-line header (D02-4 SHA line, sha = props.headSha || "unknown"),
//    "## Workspace" fenced tree rooted `<project>/`, "## Agent Harness Structure" fenced tree
//    rooted `.agent/`, "## Naming Rule Summary" table — one row per rule in rule order:
//    `| \`<scope.join(", ")>\` | <id> | <description> |`.
// Edge cases: rules = [] (file missing/invalid) → no annotations, summary body =
//   "(no naming rules — populate naming-conventions.md)"; §18.7's "Recently Added" section is
//   DROPPED (needs wall-clock dates — nondeterministic).
```

`harness struct` writes `P.standards/directory-structure.md` + prints the path. `--check` writes
nothing: `checkPath` every walked file; each failure →
`reporter.error("<path> violates <rule-id> (<description>)", ruleId)`; none →
`reporter.ok("no naming violations")`; exit `FINDINGS` iff any. Unparseable rules block →
`HarnessError("naming-rules-invalid")` propagates (exit 2, hint names the file).

**Golden test** (full): `struct` on the extended fixture (no git) produces EXACTLY the fixture's
committed `directory-structure.md` (assert both directions, re-run idempotent) — 55 lines:

````markdown
# Directory Structure — initialized
> GENERATED by `harness struct`. Do not edit manually.
> See also: naming-conventions.md — full rule definitions and regex patterns.
> Last updated by harness struct (SHA: unknown)

## Workspace

```
initialized/
├── src/
│   ├── components/  ← [→ react-components]
│   │   ├── FilterPanel.tsx
│   │   └── badFile.tsx  ← ✗ violates react-components
│   ├── hooks/  ← [→ react-hooks]
│   │   └── useFilterState.ts
│   └── lib/  ← [→ lib-modules]
│       ├── date-utils.ts
│       └── helperStuff.ts  ← ✗ violates lib-modules
└── package.json
```

## Agent Harness Structure

```
.agent/
├── docs/
│   ├── product/
│   │   ├── dev-processes.md
│   │   ├── mission.md
│   │   └── tech-stack.md
│   ├── specs/
│   │   └── .gitkeep
│   ├── standards/
│   │   ├── backend/
│   │   │   └── api.md
│   │   ├── anti-patterns.md
│   │   ├── directory-structure.md
│   │   ├── index.yml
│   │   ├── naming-conventions.md
│   │   └── preferences.md
│   └── tasks.md
├── skills/
│   └── dev-spec/
│       └── SKILL.md
├── AGENTS.md
└── manifest.json
```

## Naming Rule Summary

| Scope | Rule ID | Convention |
|---|---|---|
| `src/components/**` | react-components | React components — PascalCase .tsx |
| `src/hooks/**` | react-hooks | React hooks — use-prefixed camelCase .ts |
| `src/lib/**` | lib-modules | Lib modules — kebab-case .ts |
````

(If 01's fixture as built contains files beyond Step 1's normative tree, align the fixture to the
tree — the golden is authoritative.) `--check` test: exit 1; stderr/stdout contains exactly the two
lines `🔴 ERROR  src/components/badFile.tsx violates react-components (React components — PascalCase .tsx)`
and `🔴 ERROR  src/lib/helperStuff.ts violates lib-modules (Lib modules — kebab-case .ts)` (order:
walk order); after renaming both offenders to `BadFile.tsx`/`helper-stuff.ts` → exit 0 +
`✅ OK     no naming violations`. With git (`gitInit`), the header's SHA equals `headSha(root)`.

---

## Step 7: `harness context --for` `[dev]`

- [ ] Create `src/commands/context.ts` + `src/commands/context.test.ts`; register `context`; run tests

Grammar: `harness context --for "<task>" [--files a,b,…]` (`--files` = comma-separated paths/globs;
comma because 01's parser keeps last repeated option only).

Key fn `matchContextRules(props: { rules: ContextRule[]; task: string; files: string[] }): string[]`
where `ContextRule = { id: string; when: string[]; inject: string[] }` (master §7.2; loaded with
the `yaml` package):

```
// TODO: implement
// 1. pathTokens = props.files (split done by caller) + whitespace tokens of props.task that
//    contain "/" or "." (trim trailing punctuation ,.;:).
// 2. wordTokens = lowercased task tokens stripped of non-[a-z0-9-] chars.
// 3. A rule matches when: any pathToken matches any `when` glob (globMatch), OR any wordToken
//    equals the rule id or one of the id's "-"-split segments (so "backend work" hits
//    "std-backend").
// 4. Return the deduped concatenation of matched rules' inject lists, rule order preserved.
// Edge cases: empty task + empty files → []; a when glob never matches word tokens.
```

Command behavior: `context-rules.yaml` absent → print `(no context rules — run harness sync)`,
exit 0 (04 owns generation). Matches → print each inject path on its own line, nothing else
(skills consume stdout). No matches → `(no matching context rules)`, exit 0. Inject paths that
don't exist on disk → `⚠️` warn line via Reporter to stderr, path still printed.

Also export the convenience wrapper (05's `implement next` imports it — contract C-05c):

```typescript
/**
 * Loads context-rules.yaml and matches in one call.
 * @param props.root - Project root. @param props.task - Task description.
 * @param props.files - Optional path/glob hints.
 * @returns Root-relative inject paths; [] when the rules file is absent or nothing matches.
 */
export function contextFilesFor(props: { root: string; task: string; files?: string[] }): string[]
```

(Full code — load via the yaml package, delegate to `matchContextRules`; one test: absent file → [].)

Tests (full): seed a `context-rules.yaml` (`version: 1`) with two rules into a tmp `initialized`
copy — `std-backend` (`when: ["convex/**"]`, `inject: [docs/standards/backend/api.md]`) and
`naming` (`when: ["**/*.ts", "**/*.tsx"]`, `inject: [docs/standards/naming-conventions.md]`).
Exact expectations: `--for "add a convex mutation in convex/collections.ts"` → stdout exactly
`docs/standards/backend/api.md\ndocs/standards/naming-conventions.md`; `--for "tweak css"` →
`(no matching context rules)`; `--for "backend cleanup"` → api.md only (word-token match);
`--for "x" --files src/lib/date-utils.ts` → naming-conventions.md only; no context-rules.yaml →
the "(no context rules — run harness sync)" note, exit 0.

---

## Step 8: `harness pref compact | remove` `[dev]`

- [ ] Create `src/commands/pref.ts` + `src/commands/pref.test.ts`; register `pref`; run tests

Grammar: `harness pref compact [--budget <n>]` (default budget =
`manifest.doctor.budgets.preferences_lines`), `harness pref remove <id>`.

Full-code helper `parsePrefEntries(props: { text: string }): { header: string[]; entries: PrefEntry[]; unparsed: string[] }`
— `PrefEntry = { id: string; num: number; date: string; text: string; supersedes?: string }`; entry
regex `^- (P-\d{3,}) \((\d{4}-\d{2}-\d{2})\) (.+?)(?: \[supersedes (P-\d{3,})\])?$`; `header` =
lines before the first entry; `unparsed` = later non-blank non-entry lines (preserved verbatim at
the end of the file, never dropped — tolerance is the contract).

Key fn `compactPrefs(props: { text: string; budget: number }): { text: string; removed: Array<{ id: string; reason: string }> }`:

```
// TODO: implement
// 1. Parse. Apply supersedes: drop every entry whose id appears in another entry's
//    `supersedes`; strip the applied "[supersedes …]" tag from the survivor.
//    reason: "superseded by P-NNN".
// 2. Merge exact-duplicate text (post-trim, case-sensitive): keep the LOWEST id;
//    reason: "duplicate of P-NNN".
// 3. While countLines(render) > budget (countLines = 01's non-empty-line counter):
//    drop the entry with the OLDEST date (tie → lowest id); reason "over budget (oldest)".
//    → "keep newest-N" semantics.
// 4. Render: header verbatim + blank + surviving entries in ascending id order + blank +
//    unparsed lines (if any). Ids are NEVER renumbered (D02-3).
// Edge cases: zero entries → text unchanged; budget already met → only steps 1–2 apply
//    (supersedes/duplicates are always cleaned).
```

`pref compact` writes the file atomically and reports each removal as
`ℹ️  INFO   removed P-002 (superseded by P-005)` style lines; exit 0. `pref remove <id>` deletes
that entry line only; unknown id → `HarnessError("pref-not-found", …)` exit 2 (rollback of a
removal = git history, D02-3).

Tests (full, fixture preferences.md from Step 1 — exact): after `pref compact` the file's entries
are exactly `P-001, P-004, P-005, P-006` (P-002 superseded, P-003 duplicate of P-001) and P-005's
line no longer carries the supersedes tag; reported removals are exactly those two with those
reasons; `pref compact --budget 5` additionally drops `P-001` (oldest) leaving `P-004, P-005,
P-006`; `pref remove P-004` leaves `P-001…P-006` minus P-004 with header byte-identical;
`pref remove P-999` → exit 2; compact is idempotent (second run removes nothing).

---

## Step 9: Doctor checks `[dev]`

- [ ] One file per check in `src/checks/` + one test each; append all three to `doctor.ts`'s
      static registry (01 Step 12 contract); run full suite

Contracts (implement `run` from these; checks use `ctx.read`/`ctx.listFiles` plus direct
`src/lib/git.ts` calls with `ctx.root` per D02-9):

1. **`naming-violations`** · warn · appliesWhen `docs/standards/naming-conventions.md` exists AND
   `isRepo` · `recentChangedFiles({ root, commits: 10 })`, filter to paths that still exist, run
   `checkPath` with the parsed rules → one finding per violation:
   `<path> violates <rule-id>`, hint `harness struct --check`. Rules block unparseable → single
   finding `naming-conventions.md rules block unparseable — <msg>` (catch the HarnessError; a
   broken block must not crash doctor). Test: `gitInit` the extended fixture (commits include
   `badFile.tsx` + `helperStuff.ts`) → exactly 2 findings naming both paths; delete the offenders,
   commit, and the finding count drops to 0.
2. **`structure-stale`** · info · appliesWhen `directory-structure.md` exists AND `ctx.headSha !== ""` ·
   parse `\(SHA: ([0-9a-f]{7,40}|unknown)\)` (line missing → finding `directory-structure.md has
   no SHA line`). Stale iff recorded is `"unknown"` (repo exists now), OR recorded ≠ headSha AND
   `changedFilesSince({ root, sha: recorded })` is non-empty → one finding
   `directory-structure.md generated at <short-sha>, tree changed since`, hint `harness struct`.
   Test: gitInit → `struct` (records HEAD) → passes; add+commit a file → exactly one finding;
   re-run `struct` → passes again.
3. **`index-stale`** · warn · appliesWhen `docs/standards/` exists · `index.yml` missing → single
   finding hint `harness index rebuild`; else parse with `yaml`: every `docs/standards/**/*.md`
   (via `ctx.listFiles`) absent from the index → finding `<path> not in index.yml`; every index
   entry whose file is gone → finding `index.yml lists missing <group>/<key>`. Hints all
   `harness index rebuild`. Test: fixture is clean (bootstrapped index) → 0 findings; add
   `docs/standards/backend/migrations.md` → exactly one finding naming it; delete `backend/api.md`
   → one "lists missing" finding.

Doctor on the pristine extended fixture (no git) still exits 0; with git but no violations it
still exits 0 (all three are warn/info — master §2.9: only errors flip the exit code).

---

## Step 10: naming-conventions template `[agent]`

- [ ] Create `src/templates/standards/naming-conventions.template.md`

Skeleton the init skill (Phase 8) and `naming-interview.md` fill: the Step 1 fixture file's shape
with `<project>` placeholder, an empty ` ```yaml\nrules: []\n``` ` block, the two `> See also` /
`> Updated by sync-spec` banner lines, and empty `## Code Identifier Conventions` subheadings
(Hooks / Event Handlers / Booleans / Components / Types / Constants / Props Objects). ≤ 30 lines.
(`directory-structure.md` needs no static template — `buildStruct` IS its template, golden-pinned
in Step 6.)

---

## Step 11: dev-spec skill `[agent]`

- [ ] Create `src/templates/skills/dev-spec/SKILL.md` + `references/{interview.md,spec-format.md,code-rules.md,build-order.md}`
- [ ] Add `src/templates/templates.test.ts` walking `src/templates/skills/*/`: every SKILL.md
      ≤ 150 lines, every reference ≤ 120 lines, frontmatter has `name` + `description` (covers
      01's init skill and Step 12 too)

**File: `src/templates/skills/dev-spec/SKILL.md`** (full content; proposal §11 + §18.7 router;
preflight per master §10.3 plus the context line):

```markdown
---
name: dev-spec
description: Use BEFORE any non-trivial code change — new features, adapters, API changes,
  anything touching multiple files. Triggers on "write a spec", "spec out X", "/dev-spec",
  or when the work is clearly substantial. Skip for typos and single-line tweaks.
harness_model_role: slow
---

# Dev Spec

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.
4. Run `harness context --for "<feature being specced>"` and read every file it prints.

## Steps
1. **Interview** — load `references/interview.md`; run its question phases. Use the structured
   question tool if available (`ask_user_question` / `AskUserQuestion`); else a numbered list.
2. **Explore** — check `.agent/dependencies/registry.md`; read dep source when relevant. For
   high-care projects read `docs/standards/naming-conventions.md` FIRST — before writing any
   code in the spec — then `anti-patterns.md`, `preferences.md`, then the domain files from
   `harness context`. Note existing patterns to mirror.
3. **Edge cases** — present design questions, edge cases, scope check. Confirm in/out of scope.
4. **Build order** — load `references/build-order.md`; order task groups by its rules.
5. **spec-tasks.md** — run `harness spec new "<slug>"`; fill spec-tasks.md with ordered task
   groups, each with `Why:` and `Verify:`. Show the developer. "Just the tasks"? Stop and wait.
6. **spec.md** — load `references/spec-format.md` + `references/code-rules.md`. ≤3 task groups:
   one pass. >3: subagent loop — one subagent per group with the project description
   (manifest.json), spec-tasks.md in full, `harness context --for "<group topic>"` output,
   naming-conventions.md, and anti-patterns.md. Stitch; review consistency, cross-references.
7. **Naming pass** — scan every file/function/type/variable name in the spec against
   naming-conventions.md; fix mismatches before presenting. Silent step.
8. **Review build order** — build+test runnable after every step? Every step tagged
   `[dev]`/`[agent]`? Files in declaration-before-consumer order?
9. **Present + update tasks** — spec path, agent/dev split, build-order summary; set frontmatter
   `touches:` to the paths it will change; move the task to "In Progress" in `docs/tasks.md`.
```

References (full content authored here, each ≤ 120 lines):

- **`interview.md`** — three question phases. P1 Intent: what is being built (one sentence);
  who/what consumes it; what breaks or is missing today. P2 Shape: new module or extension of
  which paths; inputs/outputs or UI surface; data/schema changes; candidate `touches` globs.
  P3 Constraints + scope: hard requirements (perf/compat/platform); what is explicitly OUT; how
  the developer verifies done; tier check (high-care → dev implements, spec is guided stubs).
  Close by restating answers as a confirmed summary.
- **`spec-format.md`** — target spec.md layout: D02-1 frontmatter (spec_id stays = dir name);
  `## Overview` (3–6 lines); `## Design Decisions` (numbered, each with a why); `## Out of
  Scope`; `## Implementation` with one `### T<n> — <title>` per task group mirroring
  spec-tasks.md — checkbox list, `[dev]`/`[agent]` tag, code blocks (full code for boilerplate,
  guided stubs where the developer implements), `Verify:` command; final `## Verification`
  running the project's build+test. Status lifecycle: draft → in-progress → done (sync-spec).
- **`code-rules.md`** — every name satisfies the naming-conventions rules block + identifier
  conventions; follow preferences.md, never contradict anti-patterns.md; guided stubs =
  signature + JSDoc + numbered `// TODO` pseudo-code + edge cases + `throw new Error("Not
  implemented")`; tests colocated in the same task group with exact expected values; no
  speculative code; every step leaves the LSP clean.
- **`build-order.md`** — the six rules of proposal §11 step 4: environment first (build+test
  clean after step 1); visual feedback early (stubs before internals, visible by step 2);
  LSP-clean at every step (B before A when A imports B; mutual imports share a step);
  test infrastructure before test files; tests colocated, never pooled at the end;
  dependencies before dependents.

---

## Step 12: sync-spec skill `[agent]`

- [ ] Create `src/templates/skills/sync-spec/SKILL.md` + `references/{pattern-extraction.md,compaction-rules.md}`

**File: `src/templates/skills/sync-spec/SKILL.md`** (full content):

```markdown
---
name: sync-spec
description: Run AFTER implementation and BEFORE commit on high-care projects. Aligns the
  spec with what was actually built and harvests patterns into the standards files.
  Triggers on "sync spec", "update the spec", "extract patterns", "/sync-spec".
---

# Sync Spec

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness doctor`. Fix 🔴 errors before proceeding.
3. Run `harness state` and read the output.

## Steps
1. **Identify** — `harness spec list`; confirm with the developer which spec was implemented.
2. **Diff** — compare the implemented code (git diff + files matched by the spec's `touches`
   globs) against the spec's code blocks. Load `references/pattern-extraction.md`; classify
   every deviation: naming, structure, API shape, style, scope.
3. **Update the spec** — edit spec.md until it matches reality; tick finished boxes in
   spec-tasks.md; all boxes checked → set frontmatter `status: done` in both files.
4. **Preferences** — for each style deviation seen ≥2 times (or stated explicitly): append ONE
   line to `docs/standards/preferences.md` in exactly the format `- P-NNN (YYYY-MM-DD) <rule>`
   — NNN = highest existing id + 1 (never reuse ids), date = the HEAD commit date
   (`git log -1 --format=%cs`), never the wall clock. A rule replacing an old one appends
   ` [supersedes P-MMM]` instead of editing the old entry. If doctor reports
   preferences-over-budget → run `harness pref compact` (see `references/compaction-rules.md`)
   — never hand-compact.
5. **Anti-patterns** — every corrected agent mistake appends to `docs/standards/anti-patterns.md`
   as `- AP-NNN (YYYY-MM-DD, seen 1x) <rule>`, or bumps an existing entry's `seen Nx` counter.
   NEVER compact or delete from this file.
6. **Naming** — the developer renamed something the spec generated? Update
   `naming-conventions.md` (fix the rule's pattern/examples, or record the identifier
   convention in prose), then run `harness struct` so directory-structure.md re-annotates.
7. **Structure + index** — new files or folders? `harness struct`. Standards files added or
   changed? `harness index rebuild`.
8. **Report** — list every file updated and every P-/AP- entry added. Nothing is changed
   silently. (Session-log entry: the commit skill's job — spec 03.)
```

References (full content authored here, each ≤ 120 lines):

- **`pattern-extraction.md`** — diff each spec code block against the merged file it targeted;
  deviation classes with examples (naming: spec `useTextfield` → dev `useTextField`; structure:
  helper moved into `lib/`; API shape: object param over positional; style: early-return over
  nesting; scope: functionality added/dropped — scope goes to spec.md, never preferences); the
  write threshold (≥2 sightings or an explicit developer statement — one-offs are noise); where
  each class lands (naming → naming-conventions.md, style/API → preferences.md, agent mistakes →
  anti-patterns.md); one-line-per-rule discipline — a preference is a rule, not an essay.
- **`compaction-rules.md`** — the D02-3 grammar; what `harness pref compact` does (1 drop
  superseded, tag stripped from survivor; 2 merge exact duplicates keeping the lowest id; 3 drop
  oldest-dated until within budget); ids never renumbered, removals recoverable via git
  (`harness pref remove <id>` for manual rollback); anti-patterns.md is exempt — append-only,
  over-budget is a human review signal, never a compaction target.

---

## Step 13: init skill naming-interview reference `[agent]`

- [ ] Create `src/templates/skills/init/references/naming-interview.md` (fills the phase-8 gap
      01 left; 01's `references/phases.md` already points here by path)

Full content (≤ 120 lines; proposal §7 Phase 8): high-care projects — low-care may skip with a
minimal rules block. **Infer first**: scan existing code, propose detected conventions, only ask
about what can't be inferred. Questions — Hooks: `useXxx` / `useXxxState` / `useXxxMutation`?
Event handlers: `onXxx` (props) vs `handleXxx` (internal)? Booleans: `isXxx` / `hasXxx` /
`canXxx` / `shouldXxx` — which mean what? Components: suffix conventions (`XxxPanel` / no
suffix / `XxxPage` / `XxxLayout`)? Types: `Xxx` vs `XxxType` / `XxxT` / `IXxx`; input vs
resolved variants? Constants: exported vs file-local casing? Project-specific patterns (e.g.
Convex query/mutation verbs)? Then **file/folder rules**: per major directory, the expected
basename pattern → regex rules (id, pattern, scope, description, examples, counter_examples)
filled into the Step 10 template. Output: assemble naming-conventions.md, submit via
`harness init write-phase 8 --data -` (`{ naming_conventions_md: "<content>" }`), then run
`harness struct` to generate the linked directory-structure.md.

---

## Step 14: Verification (mandatory)

- [ ] `cd harness && bun install && bun test` — all green, including 01's untouched suite
- [ ] `bunx tsc --noEmit` — clean
- [ ] Manual smoke on a scratch copy of the extended fixture (`gitInit` first): `spec new "smoke"
      --date 2026-08-06` → `spec list` → `struct` → `struct --check` (2 violations) →
      `index rebuild` → `pref compact` → `doctor` exit 0. Re-runs of `struct`/`index rebuild`
      change nothing (byte-idempotent). Fix anything broken; no skipped tests.

## Success Criteria

- [ ] `spec new` dates come from git or `--date`, never the wall clock
- [ ] `struct` + `index rebuild` outputs byte-identical to the fixture goldens, idempotent
- [ ] `struct --check` catches exactly the two seeded violations; passes after rename
- [ ] `context --for` matches by path token, word token, and `--files`; degrades gracefully
      without `context-rules.yaml`
- [ ] `pref compact` applies supersedes → dedupe → newest-N in order, never renumbers ids, is
      idempotent; `pref remove` deletes exactly one entry
- [ ] The three new doctor checks catch their seeded fixtures, stay silent on the healthy one,
      and doctor still exits 0 on the pristine fixture
- [ ] dev-spec / sync-spec / naming-interview templates exist within line budgets with valid
      frontmatter (`templates.test.ts` enforces this)
