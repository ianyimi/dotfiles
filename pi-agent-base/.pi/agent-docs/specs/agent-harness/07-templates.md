# 07 — Init Template Mechanism

> Phase spec 7 of 8. Prereqs: `00-master.md` (§2 conventions binding; D3: template *content* is
> deferred, only the mechanism ships here) and `01-foundation.md` (init primitives — write-phase
> data table, `.setup-progress.md`, scaffold — templates plug into that flow). Proposal §8 is the
> requirements source.

## Overview

Add the template store (`~/.harness/templates/<name>/`, `HARNESS_HOME` honored), the
`harness template save|list|inspect|delete` commands, and `harness init scaffold --template <name>`
wiring. A template snapshots the *structural* answers of a successful init (domains, dependency
names+repos, workflow/modules/platforms, naming conventions, customized skills) so a new project of
the same type only answers project-specific questions.

## Design Decisions

- **D-07-1 Prefill = staged draft, not written state.** `init scaffold --template` stages phase
  data into `.setup-progress.md` `## Collected Data` with checkboxes left UNTICKED (data + unticked
  box = "prefilled"); only `init write-phase` — validating everything exactly as in 01 — ticks
  boxes and writes files. The CLI stays dumb; the skill confirms.
- **D-07-2 Prefilled phases ⊆ {2, 3, 6, 7}.** Save derives 3/6/7 from `manifest.json` (domains,
  deps, workflow/modules/platforms). Phase 2 (`purpose`, `team`) lives only in the deleted progress
  file and `purpose` is project-specific anyway, so `save` never emits it — the schema keeps key
  `"2"` (as `{ team }`) so a hand-edited org template can pin it. Phases 1/4/5/8/9 are never
  prefilled (project-specific); naming travels as `standards_seed/` content instead, turning
  phase 8 into a confirm.
- **D-07-3 Strip project-specifics at save.** No `project`, `description`, `mission`, env var
  values (env manifest is not templated at all), dep `version`s (keep `package`+`repo`; versions
  re-resolve from the new project's manifest files at init).
- **D-07-4 Seeds win over embedded defaults.** During a `--template` scaffold, `skills_seed/<name>/`
  dirs overwrite the just-copied embedded default skill dirs; `standards_seed/` files copy into
  `docs/standards/` (mirrored relative paths). Plain-scaffold skip-existing semantics are unchanged
  elsewhere; prefill never overwrites an existing Collected Data block.
- **D-07-5** Template store code lives in `src/lib/templateStore.ts` (addition to master §5 layout —
  both `template.ts` and `init.ts` need it; cross-command imports would be worse).
- **No doctor checks in this spec.**

## Out of Scope

Built-in template *content* (D3), template upgrade/migration (`harness upgrade`, deferred), doctor
checks, any change to platform bridges.

## Implementation Order

1. `[agent]` `harnessHome()` in `src/lib/paths.ts` + test-helper additions
2. `[dev]` Template store `src/lib/templateStore.ts` — key fns: `loadTemplate`, `listTemplates`
3. `[dev]` Derivation — key fn: `deriveTemplate` (manifest→prefilled, sha256 skill diff, seeds)
4. `[dev]` `harness template save|list|inspect|delete` — key fn: `runTemplate`
5. `[dev]` `init scaffold --template` wiring + `init status` prefilled rendering + phase-7
   `harness.template` backfill — key fn deltas: `initScaffold`, `initStatus`, `initWritePhase`
6. `[agent]` Init SKILL.md `--template` note (exact diff)
7. Verification

---

## Step 1: `harnessHome()` + test helpers `[agent]`

- [ ] Add `harnessHome` to `src/lib/paths.ts`; extend `src/lib/paths.test.ts`
- [ ] Add `mkHarnessHome`/`rmHarnessHome` to `test/helpers.ts`

**Addition to `harness/src/lib/paths.ts`** — full code (zero-param helper, exempt from props rule):

```typescript
import { homedir } from "node:os";

/**
 * User-level harness directory (templates, caches). `HARNESS_HOME` env var overrides the
 * default `~/.harness` — read at call time so tests can point it at a temp dir.
 * @returns Absolute path of the harness home directory (not created — callers ensureDir).
 */
export function harnessHome(): string {
  return process.env.HARNESS_HOME ?? join(homedir(), ".harness");
}
```

**Addition to `harness/test/helpers.ts`** — full code. Every test in this spec (and 06's cache
tests) MUST route through these; the real `~/.harness` is never touched.

```typescript
/** Creates a temp dir and sets HARNESS_HOME to it (call in beforeEach). @returns Its absolute path. */
export function mkHarnessHome(): string {
  const dir = mkdtempSync(join(tmpdir(), "harness-home-"));
  process.env.HARNESS_HOME = dir;
  return dir;
}

/** Removes a temp harness home and unsets the env var. @param props.dir - Path from mkHarnessHome. @returns Nothing. */
export function rmHarnessHome(props: { dir: string }): void {
  rmSync(props.dir, { recursive: true, force: true });
  delete process.env.HARNESS_HOME;
}
```

**Test additions (`paths.test.ts`)**: `HARNESS_HOME` set → returned exactly; unset → equals
`join(homedir(), ".harness")`. Wrap in try/finally restoring the var.

---

## Step 2: Template store `[dev]`

- [ ] Create `src/lib/templateStore.ts` + `src/lib/templateStore.test.ts`; run tests

**File: `harness/src/lib/templateStore.ts`** — types + `templateDir` full code; `loadTemplate`
guided stub; `listTemplates` guided stub.

```typescript
import { join } from "node:path";
import { harnessHome } from "./paths.ts";
import { HarnessError } from "./errors.ts";
import type { HarnessManifest } from "./manifest.ts";

/** On-disk schema of `<templates>/<name>/template.json`. */
export interface InitTemplate {
  schema_version: "1.0";
  /** kebab-case, equals its directory name. */
  name: string;
  /** UTC date (YYYY-MM-DD) from the injected clock at save time. */
  saved_at: string;
  /** git HEAD of the source project at save time; "" when unknown. */
  saved_at_sha: string;
  /** manifest.project of the source project. */
  source_project: string;
  /** CLI version that wrote the template. */
  harness_version: string;
  /**
   * Phase-keyed init data, mirroring 01's write-phase table minus project-specific fields
   * (D-07-2/D-07-3). Staged verbatim into .setup-progress.md by scaffold --template.
   */
  prefilled: {
    /** Never written by `template save`; hand-editable for org templates (D-07-2). */
    "2"?: { team: string };
    "3"?: { domains: string[] };
    /** DependencyPin minus version — versions re-resolve at init. */
    "6"?: { dependencies: Array<{ package: string; repo: string }> };
    "7"?: {
      workflow: HarnessManifest["workflow"];
      modules: HarnessManifest["modules"];
      platforms: HarnessManifest["platforms"];
    };
  };
}

/** Kebab-case template name guard (also blocks path traversal before any join). */
export const TEMPLATE_NAME_RE = /^[a-z0-9][a-z0-9-]*$/;

/**
 * Resolves a template's directory under the store. Validates the name FIRST.
 *
 * @param props.name - Template name.
 * @returns Absolute directory path `<harnessHome>/templates/<name>`.
 * @throws {HarnessError} code "template-name-invalid" when the name fails TEMPLATE_NAME_RE.
 */
export function templateDir(props: { name: string }): string {
  if (!TEMPLATE_NAME_RE.test(props.name)) {
    throw new HarnessError("template-name-invalid",
      `invalid template name "${props.name}" (want kebab-case)`);
  }
  return join(harnessHome(), "templates", props.name);
}

/**
 * Loads and validates one template.
 *
 * @param props.name - Template name.
 * @returns Parsed template plus its directory and seed inventories (root-relative sorted paths).
 * @throws {HarnessError} "template-not-found" (hint: "harness template list") when the dir or
 *   template.json is absent; "template-invalid" naming the offending key on schema violations.
 */
export function loadTemplate(props: { name: string }): {
  template: InitTemplate; dir: string; standardsSeed: string[]; skillsSeed: string[];
} {
  // TODO: implement
  //
  // 1. dir = templateDir(props). template.json absent → template-not-found.
  // 2. JSON.parse (syntax error → template-invalid). Validate: schema_version === "1.0";
  //    name === props.name; saved_at/saved_at_sha/source_project/harness_version strings;
  //    prefilled keys ⊆ {"2","3","6","7"}; "3".domains string[]; "6".dependencies entries
  //    have package+repo and NO version key (present → template-invalid "dependency
  //    versions must not be templated"); "7" has workflow+modules+platforms objects.
  //    Unknown top-level keys tolerated (save rewrites clean).
  // 3. standardsSeed = walk(dir/standards_seed) if present else []; skillsSeed = sorted
  //    top-level dir names under skills_seed/ if present else [].
  // Edge cases: unreadable JSON → template-invalid, not a crash; empty prefilled {} is
  // valid (a seeds-only template).
  throw new Error("Not implemented");
}

/**
 * Lists all templates in the store, sorted by name (determinism).
 *
 * @returns One entry per loadable template. Directories whose template.json is missing or
 *   invalid are returned with `invalid: true` (list must not crash on one bad entry).
 */
export function listTemplates(): Array<{
  name: string; saved_at: string; saved_at_sha: string; source_project: string; invalid?: boolean;
}> {
  // TODO: implement
  // 1. readdir(<harnessHome>/templates) — ENOENT → [].
  // 2. For each dir entry sorted by name: try loadTemplate; on HarnessError → push
  //    { name, saved_at: "", saved_at_sha: "", source_project: "", invalid: true }.
  throw new Error("Not implemented");
}
```

**File: `harness/src/lib/templateStore.test.ts`** — full code:

```typescript
import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkHarnessHome, rmHarnessHome } from "../../test/helpers.ts";
import { listTemplates, loadTemplate, templateDir } from "./templateStore.ts";

const TPL = {
  schema_version: "1.0", name: "t-one", saved_at: "2026-08-06", saved_at_sha: "a".repeat(40),
  source_project: "initialized", harness_version: "0.1.0",
  prefilled: { "3": { domains: ["backend"] } },
};

let home = "";
beforeEach(() => { home = mkHarnessHome(); });
afterEach(() => { rmHarnessHome({ dir: home }); });

function seed(name: string, json: unknown): void {
  const dir = join(home, "templates", name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "template.json"), JSON.stringify(json, null, 2));
}

describe("templateStore", () => {
  test("templateDir honors HARNESS_HOME and rejects bad names", () => {
    expect(templateDir({ name: "t-one" })).toBe(join(home, "templates", "t-one"));
    for (const bad of ["", "Has-Caps", "../evil", "a b", "-lead"])
      expect(() => templateDir({ name: bad })).toThrow(/invalid template name/);
  });
  test("load round-trips and inventories seeds", () => {
    seed("t-one", TPL);
    mkdirSync(join(home, "templates", "t-one", "skills_seed", "custom-x"), { recursive: true });
    writeFileSync(join(home, "templates", "t-one", "skills_seed", "custom-x", "SKILL.md"), "x");
    mkdirSync(join(home, "templates", "t-one", "standards_seed"), { recursive: true });
    writeFileSync(join(home, "templates", "t-one", "standards_seed", "naming-conventions.md"), "n");
    const got = loadTemplate({ name: "t-one" });
    expect(got.template).toEqual(TPL as never);
    expect(got.skillsSeed).toEqual(["custom-x"]);
    expect(got.standardsSeed).toEqual(["naming-conventions.md"]);
  });
  test("not found / invalid json / templated version rejected", () => {
    expect(() => loadTemplate({ name: "nope" })).toThrow(/template-not-found|not found/i);
    seed("bad-json", null); writeFileSync(join(home, "templates", "bad-json", "template.json"), "{");
    expect(() => loadTemplate({ name: "bad-json" })).toThrow();
    seed("has-ver", { ...TPL, name: "has-ver",
      prefilled: { "6": { dependencies: [{ package: "convex", repo: "r", version: "1.0.0" }] } } });
    expect(() => loadTemplate({ name: "has-ver" })).toThrow(/version/);
  });
  test("list: empty → []; sorted; survives one bad entry", () => {
    expect(listTemplates()).toEqual([]);
    seed("zz", { ...TPL, name: "zz" }); seed("aa", { ...TPL, name: "aa" });
    mkdirSync(join(home, "templates", "broken"), { recursive: true });
    expect(listTemplates().map((t) => `${t.name}${t.invalid ? "!" : ""}`))
      .toEqual(["aa", "broken!", "zz"]);
  });
});
```

---

## Step 3: Derivation `[dev]`

- [ ] Create `src/commands/template.ts` with `deriveTemplate` + `src/commands/template.test.ts`
      (test file grows in Step 4); run tests

`.setup-progress.md` is deleted by `init finish`, so save derives everything from `manifest.json` +
`.agent/` contents — never from remembered interview data.

```typescript
/**
 * Derives a template from an initialized project (pure planning — no writes).
 *
 * @param props.root - Project root (must be initialized; caller loads the manifest).
 * @param props.manifest - Loaded manifest.
 * @param props.name - Template name being saved.
 * @param props.embeddedSkillsDir - Absolute path of src/templates/skills (injectable for tests).
 * @param props.now - Clock for saved_at (master §2.8).
 * @returns The template.json object plus copy plans for both seed dirs
 *   (project-root-relative source → template-dir-relative dest).
 */
export function deriveTemplate(props: {
  root: string; manifest: HarnessManifest; name: string; embeddedSkillsDir: string; now: Date;
}): {
  template: InitTemplate;
  standardsSeedCopies: Array<{ from: string; to: string }>;
  skillsSeedCopies: Array<{ from: string; to: string }>;
} {
  // TODO: implement
  //
  // 1. prefilled["3"] = { domains: manifest.standards_domains } — omit key when [].
  // 2. prefilled["6"] = { dependencies: manifest.dependencies.map(d =>
  //    ({ package: d.package, repo: d.repo })) } — version STRIPPED (D-07-3); omit when [].
  // 3. prefilled["7"] = { workflow, modules, platforms } copied verbatim from the manifest.
  //    Never emit prefilled["2"] (D-07-2).
  // 4. standardsSeedCopies: docs/standards/naming-conventions.md if it exists →
  //    standards_seed/naming-conventions.md. Nothing else — anti-patterns/preferences/domain
  //    content are per-project learned knowledge, never templated.
  // 5. skillsSeedCopies: for each dir under .agent/skills/: sha256 every file (walk, sorted)
  //    and compare against the same-named dir under props.embeddedSkillsDir. Differs in any
  //    file, or has extra/missing files, or has no embedded counterpart (custom skill) →
  //    copy the WHOLE skill dir to skills_seed/<name>/. Byte-identical to embedded → skip.
  // 6. template.json fields: name; saved_at = props.now UTC "YYYY-MM-DD"; saved_at_sha =
  //    headSha({ root }) ("" tolerated); source_project = manifest.project; harness_version
  //    from package.json (import ... with { type: "json" }).
  //
  // Edge cases: no .agent/skills dir → skillsSeedCopies []; empty prefilled is valid;
  // symlinked skill files hash their content, not the link.
  throw new Error("Not implemented");
}
```

---

## Step 4: `harness template` command `[dev]`

- [ ] Add `runTemplate` to `src/commands/template.ts`; register `template` in the cli.ts command
      table; grow `src/commands/template.test.ts`; run tests

`runTemplate(props: CommandProps)` routes `save <name> [--force]` / `list` / `inspect <name>` /
`delete <name>` (parseArgs per sub; unknown sub → usage). Guided stub:

```
// TODO: implement
// save:    resolveProjectRoot + loadManifest (not-initialized propagates with its hint).
//          templateDir(name) exists && !--force → HarnessError("template-exists",
//          `template "<name>" exists`, { hint: "harness template save <name> --force" }).
//          deriveTemplate → rm existing dir (force path only) → write template.json
//          (writeFileAtomic, 2-space indent, trailing newline) → execute both copy plans →
//          print `saved template <name> → <dir>` + one line per seeded file.
// list:    listTemplates(). Empty → info "no templates saved". Else one line per entry:
//          `<name>  <saved_at>  <shortSha|->  <source_project>` (shortSha = first 7 chars,
//          "-" when ""); invalid entries render `<name>  (invalid template.json)`.
// inspect: loadTemplate → print exactly:
//          template: <name>
//          source:   <source_project> (saved <saved_at> at <shortSha|-> by harness <version>)
//          prefilled phases: <comma list like "3 (domains), 6 (dependencies), 7 (workflow/modules/platforms)" | "(none)">
//          standards_seed: <comma list | "(none)">
//          skills_seed: <comma list | "(none)">
// delete:  templateDir must contain template.json (else template-not-found — refuses to rm
//          an arbitrary dir) → rmSync recursive → print `deleted template <name>`.
// list/inspect/delete never require a project root.
```

**Test additions (`template.test.ts`)** — full code; every test brackets with `mkHarnessHome`/
`rmHarnessHome` as in Step 2. The **round-trip test is the centerpiece**:

```typescript
test("round-trip: save from initialized → init scaffold --template on empty project", async () => {
  const src = mkTmpProject({ fixture: "initialized" });   // + git, one dep pin, skill customizations
  const m = JSON.parse(readFileSync(join(src, ".agent/manifest.json"), "utf8"));
  m.dependencies = [{ package: "convex", version: "1.17.0", repo: "github.com/get-convex/convex-backend" }];
  writeFileSync(join(src, ".agent/manifest.json"), JSON.stringify(m, null, 2));
  writeFileSync(join(src, ".agent/docs/standards/naming-conventions.md"), "# Naming\nrules here\n");
  // custom skill (no embedded counterpart) → must be seeded
  mkdirSync(join(src, ".agent/skills/custom-x"), { recursive: true });
  writeFileSync(join(src, ".agent/skills/custom-x/SKILL.md"), "---\nname: custom-x\ndescription: d\n---\nbody\n");
  // pristine copy of an embedded default → must NOT be seeded
  cpSync(join(EMBEDDED_SKILLS, "init"), join(src, ".agent/skills/init"), { recursive: true });
  gitInit({ dir: src });

  const saved = await runCli({ argv: ["template", "save", "round-trip"], cwd: src });
  expect(saved.code).toBe(0);
  const tpl = JSON.parse(readFileSync(join(home, "templates/round-trip/template.json"), "utf8"));
  expect(tpl.saved_at_sha).toMatch(/^[0-9a-f]{40}$/);
  expect(tpl.source_project).toBe("initialized");
  expect(tpl.prefilled["3"]).toEqual({ domains: ["backend"] });
  expect(tpl.prefilled["6"]).toEqual({ dependencies: [
    { package: "convex", repo: "github.com/get-convex/convex-backend" }] });   // version STRIPPED
  expect(tpl.prefilled["7"]).toEqual({ workflow: m.workflow, modules: m.modules, platforms: m.platforms });
  expect(tpl.prefilled["2"]).toBeUndefined();
  expect(existsSync(join(home, "templates/round-trip/skills_seed/custom-x/SKILL.md"))).toBe(true);
  expect(existsSync(join(home, "templates/round-trip/skills_seed/init"))).toBe(false);
  expect(existsSync(join(home, "templates/round-trip/standards_seed/naming-conventions.md"))).toBe(true);

  const dst = mkTmpProject({ fixture: "empty-project" }); // fresh project: scaffold from template
  const scaf = await runCli({ argv: ["init", "scaffold", "--template", "round-trip"], cwd: dst });
  expect(scaf.code).toBe(0);
  const progress = readFileSync(join(dst, ".agent/.setup-progress.md"), "utf8");
  for (const n of ["3", "6", "7"]) expect(progress).toContain(`### Phase ${n}`);
  expect(JSON.parse(progress.match(/### Phase 6\n+```json\n([\s\S]*?)\n```/)![1]!))
    .toEqual(tpl.prefilled["6"]);                                              // staged verbatim
  expect(progress).toMatch(/template: round-trip/);                            // phase-7 backfill source
  expect(readFileSync(join(dst, ".agent/skills/custom-x/SKILL.md"), "utf8")).toContain("custom-x");
  expect(existsSync(join(dst, ".agent/docs/standards/naming-conventions.md"))).toBe(true);

  const status = await runCli({ argv: ["init", "status"], cwd: dst });
  for (const line of ["Phase 3", "Phase 6", "Phase 7"])
    expect(status.stdout).toMatch(new RegExp(`${line}.*prefilled \\(confirm or edit\\)`));
  expect(status.stdout).not.toMatch(/Phase 1.*prefilled/);
  rmProject({ dir: src }); rmProject({ dir: dst });
});
```

Plus (each its own test, exact expectations): `save` twice → exit ≠0 mentioning `--force`; with
`--force` → overwrites and drops stale seed files from the previous save; `save` in a
non-initialized project → "not initialized" + `harness init` hint; `list` empty → "no templates
saved", after two saves → both lines name-sorted with 7-hex short sha; `inspect` → the exact 5-line
block above (assert full string, sha interpolated); `inspect`/`delete` unknown name → exit ≠0 with
`harness template list` hint; `delete` → dir gone, second delete errors.

---

## Step 5: `init scaffold --template` wiring `[dev]`

- [ ] Extend `src/commands/init.ts` (`initScaffold`, `initStatus`, `initWritePhase` phase 7);
      extend `src/commands/init.test.ts`; run tests

**`initScaffold` delta** — new optional `props.template?: string`. Appended guided-stub comments:

```
// 6. (--template) loadTemplate(name) FIRST — template-not-found aborts before any writes.
// 7. After the normal scaffold (dirs, AGENTS.md fallback, progress file, embedded skills):
//    a. Copy skills_seed/<skill>/ over .agent/skills/<skill>/ — seeds OVERWRITE the embedded
//       defaults just copied (D-07-4). Print each as "skill <name> (from template)".
//    b. Copy standards_seed/* into .agent/docs/standards/* (mirrored paths, ensureDir).
//    c. Stage prefilled data: for each phase key (ascending), append under ## Collected Data:
//       "### Phase <n>\n\n```json\n<JSON.stringify(data, null, 2)>\n```\n"
//       — checkbox stays UNTICKED (D-07-1). Skip any phase that already has a block.
//    d. Record the template in the progress file frontmatter: `template: <name>`
//       (parseFrontmatter-compatible; written once, kept on re-run).
// Edge cases: re-run is idempotent (existing blocks untouched; seeds re-copied only where the
// target is missing); plain scaffold on a progress file that has a template line → no change.
```

**`initStatus` delta** — a phase whose Collected Data block exists but whose checkbox is unticked
renders `— prefilled (confirm or edit)` appended to its checklist line, e.g.
`- [ ] Phase 3: Domains + standards folders — prefilled (confirm or edit)`. Ticked phases and
data-less phases render exactly as in 01.

**`initWritePhase` phase-7 delta** — when assembling `manifest.json`, read the progress file
frontmatter; if `template` is present set `manifest.harness.template` to it (schema §7.1 already
has the field). No other phase changes; **write-phase validation is unchanged** — prefilled data
goes through exactly the same validators when the skill confirms it (phase 6 therefore requires the
skill to add re-resolved `version` fields before submitting; the staged block alone is not valid
phase-6 input, by design).

**Test additions (`init.test.ts`)** — full code; HARNESS_HOME bracketed:
`scaffold --template nope` → exit ≠0, "template-not-found", no `.agent/` created; staging skips a
phase that already has data (seed a `### Phase 3` block, re-scaffold with a template whose
`prefilled["3"]` differs → original block byte-unchanged); full prefilled flow ends in the manifest:
write-phase 1 (sample data) → write-phase 6 with the staged deps plus `version: "9.9.9"` added →
write-phase 7 with the staged block verbatim → `loadManifest` succeeds and
`manifest.harness.template === "round-trip"` with `dependencies[0].version === "9.9.9"`.

**Questions that remain under a template** (document verbatim in `references/phases.md` — Step 6):
name + description (1), purpose + team (2, unless a hand-edited template pins `team`), tech-stack
confirm (4, inference-driven), env var names + ports + dev commands (5), dependency version confirm
(6), mission/roadmap (9), naming *confirmation* (8 — the seeded `naming-conventions.md` is
presented for confirm-or-edit instead of a full interview). Phases 3 and 7 are confirm-only.

## Step 6: Init skill `--template` note `[agent]`

- [ ] Apply this exact diff to `src/templates/skills/init/SKILL.md` (anchor: immediately after the
      `## Preflight` section, before the phase loop); stay within the 150-line budget
- [ ] Append the "Questions that remain" table from Step 5 to `references/phases.md`

```diff
 ## Preflight
 ...
+
+## Using a Template
+
+If the developer named a template ("use the <name> template", `--template <name>`):
+1. `harness template list` — if the name is missing, show the list and stop.
+2. Run `harness init scaffold --template <name>` instead of plain scaffold.
+3. `harness init status`: phases marked `prefilled (confirm or edit)` carry staged data from
+   the template. Skip codebase inference for those phases — present the staged block as the
+   draft, confirm or edit, then `harness init write-phase <n> --data -` as usual.
+4. Phase 6 staged deps have no versions: re-resolve each from THIS project's manifest files
+   before submitting. All other phases proceed normally (see references/phases.md).
```

## Verification (mandatory)

- [ ] `cd harness && bun test` — all green, including 01–06 suites (no regressions from the
      init.ts deltas); no test touches the real `~/.harness` (grep the new tests for
      `mkHarnessHome` bracketing)
- [ ] `bunx tsc --noEmit` — clean
- [ ] Manual smoke: in a scratch copy of `test/fixtures/initialized`, `HARNESS_HOME=$(mktemp -d)
      harness template save smoke` → `list` → `inspect smoke` → in a scratch `empty-project`,
      `harness init scaffold --template smoke` → `harness init status` shows the prefilled marks →
      `template delete smoke`
- [ ] Fix anything broken; no skipped tests

## Success Criteria

- [ ] Round-trip test passes: save → scaffold --template stages golden Collected Data, applies
      skills_seed/standards_seed, dep versions stripped and re-resolved at init
- [ ] `template save|list|inspect|delete` behave per Step 4 including `--force`, hints, and the
      exact inspect block; store fully relocatable via `HARNESS_HOME`
- [ ] Prefilled phases show `prefilled (confirm or edit)` in `init status`; write-phase validation
      is byte-for-byte the 01 behavior; `manifest.harness.template` records the template name
- [ ] No doctor changes; no built-in template content shipped (D3)
