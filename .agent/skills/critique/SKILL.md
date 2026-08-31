---
name: critique
description: Review developer-written code for improvements and silly mistakes — a fresh-eyes
  critique of a named file, feature, or the uncommitted diff. Triggers on "critique",
  "/critique", "review my changes", "check my work", "did I miss anything". Read-only by
  default; grounds every finding in the real code, the active spec, and test/typecheck runs.
---

# Critique

Review code the developer wrote (or heavily edited) and report improvements and mistakes.
This is NOT a fix pass: analyze, verify, report. Only change code if the developer asks.

## Preflight
1. If `.agent/manifest.json` is missing → stop; tell the user to run `harness init`.
2. Run `harness state` — note the active spec; it is the contract the code answers to.

## Steps

1. **Identify the subject.** The developer names files/a feature, else take the uncommitted
   work: `git status --short` + `git diff` (and `git diff --stat` to scope). Distinguish THEIR
   changes from prior agent work — critique what they wrote.
2. **Ground before judging.** Read every changed file IN FULL, plus its immediate contracts:
   the types it implements, callers (LSP references for exported symbols — missed callsites
   are findings), sibling implementations of the same pattern, and the tests that cover it.
   Never critique from the diff alone — the bug is usually in the interaction with unchanged
   code.
3. **Load the project contract.** Active spec (when the project uses specs) — deviations from
   ratified decisions are findings, but deliberate improvements are credits; ask which when
   unclear. Then `docs/standards/anti-patterns.md` (violations are findings by definition),
   `preferences.md`, `naming-conventions.md`, and `harness context --for "<topic>"`. If a
   **Project Context Map** section exists below, read every pointer in it first.
4. **Verify with tools, not opinions.** Run the narrowest real checks the project defines
   (package.json scripts / spec `Verify:` lines): targeted tests, the type checker, lint on
   touched files. A failing check is a confirmed finding; a passing suite bounds how bad
   anything can be. Quote actual output.
5. **Hunt the silly-mistake catalog** (each of these ships constantly):
   - Async handler computes a result but never `return`s it.
   - Guard gated on the wrong condition — presence of *data* instead of presence of *config*
     (fail-open for unauthenticated/unconfigured paths). Check every guard's negative space:
     who reaches the operation when the condition is false?
   - Early exit inside a loop that aggregates (merge/OR/AND semantics inverted by returning
     on the first element's result).
   - Dead code: helpers written but never wired at the call site; leftover debug/no-op
     statements; unreachable stub comments after a `throw`.
   - `!x` conflating `false` with `undefined`/`null` where they mean different things.
   - Required context not threaded: a function gained a param but one caller doesn't pass it.
   - Type-level (typed languages): generic defaults that create index signatures, constraints
     on map-shaped `infer`s, literal widening from missing `const`/`as const`, casts that
     paper over a contract change.
   - Doc drift: doc comments/`@param`/`@example` contradicting the current signature or
     behavior; error messages with wrong paths/names.
   - Tests not updated for an API change (or worse: updated to pass without testing the new
     behavior).
6. **Report, severity-ordered.** For each finding: `file:line`, what's wrong, WHY (the
   failure it causes, with a concrete scenario), and the shape of the fix. Order: correctness
   bugs/regressions → security/fail-open → semantic gaps vs spec → consistency with sibling
   code → type-safety erosion → doc drift → nits. Lead with what's GOOD and worth keeping —
   the developer needs to know which parts not to churn. Be candid about "silly" mistakes;
   they asked.

## Project Context Map

*Project-specific: replace this section per project (keep the heading). List the
non-discoverable knowledge a reviewer needs before judging code here — the things grep
cannot find:*

- *Where the source-of-truth contracts live (specs, ADRs, API docs).*
- *Architectural invariants that make locally-fine code globally wrong (e.g. "identity never
  crosses the wire as an argument", "this registry type silently collapses on constraint
  failure", "mutations are transactional so throw-mid-loop is safe").*
- *The exact verify commands (test filters, typecheck, lint) and their expected-green state.*
- *Naming/placement rules that gate where new files may go.*

*Until customized, derive all of the above dynamically: AGENTS.md pointers, `harness state`,
`harness context`, standards files, and package.json scripts.*
