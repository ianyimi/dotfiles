---
applies_to: ["harness/src/**/*.test.ts", "harness/test/**"]
---
# harness/ Test Conventions

- `bun:test` (`describe`/`test`/`expect`). Unit tests **colocated** as `<module>.test.ts`
  beside the source (src/lib/fsx.test.ts); cross-command flows in `test/e2e.test.ts` +
  `test/e2e-session.test.ts`. Run `bun test`; typecheck `bunx tsc --noEmit`.
- **Hermetic, always**: build throwaway dirs via `mkTmpProject({ fixture })` (copies
  `test/fixtures/<name>` into `mkdtempSync(tmpdir())`, test/helpers.ts:17-21), clean with
  `rmProject`. NEVER touch the network or real `~/.harness` — point `HARNESS_HOME` at a temp
  dir via `mkHarnessHome()`/`rmHarnessHome()` (helpers.ts:88-108).
- Network stand-in: fake remote git deps with a local **bare** repo via
  `mkBareRepoWithTags()` (helpers.ts:52-84).
- CLI exercised **in-process**, not as a subprocess: `runCli({ argv, cwd })` imports `main`
  and captures stdout/stderr via array sinks (helpers.ts:112-133). Real `Bun.spawn` only when
  testing generated hook code (src/platforms/omp.test.ts:58).
- Git determinism: `gitInit({ dir, date? })` pins author/committer identity + dates
  (helpers.ts:33-48); e2e derives dates from `headCommitDate`, never `Date.now()`.
- Assertions exact where possible: golden full-output comparison with SHA normalized
  (e2e.test.ts:97-124); `walk` asserts the exact sorted list (fsx.test.ts:28-36).
- Fixtures are minimal named trees under `test/fixtures/` (`empty-project`, `ts-monorepo`,
  `initialized`); add a fixture dir instead of building trees inline when >2 files needed.
