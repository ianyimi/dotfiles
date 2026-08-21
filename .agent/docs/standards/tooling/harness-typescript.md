---
applies_to: ["harness/src/**/*.ts"]
---
# harness/ TypeScript Conventions

- Bun ≥ 1.3.14, run from source: `bin` → `./src/cli.ts` with `#!/usr/bin/env bun`
  (package.json:6, cli.ts:1). No build step; `noEmit` + `allowImportingTsExtensions`.
- **Imports**: node builtins with `node:` prefix; relative imports ALWAYS carry the explicit
  `.ts` extension (cli.ts:2-28). Prefer `node:fs`/`node:path` sync APIs; `Bun.spawn`/
  `Bun.spawnSync` only for subprocess work (commands/implement.ts:222). `Bun.file` unused.
- **Layout**: `src/cli.ts` is the single entry + command registry (`COMMANDS`, cli.ts:73);
  `src/commands/` one file per command; `src/lib/` helpers; `src/platforms/` pure adapters
  (I/O only via `loadProjectContext`, commands/sync.ts:92-96); `src/checks/` doctor checks,
  each `export default check`, aggregated in `checks/index.ts`. Otherwise named exports only.
- **Props-object style**: every exported function takes a single `props` object, even
  one-arg (`sha256({ text })`, lib/fsx.ts:20). JSDoc documents `@param props.x` + `@returns`.
- **Errors**: throw `new HarnessError(code, message, { hint?, exitCode? })`; caught EXACTLY
  once in `main()` (cli.ts:392-401). Codes are stable kebab-case ("module-disabled").
  `EXIT = { OK: 0, FINDINGS: 1, USAGE: 2, FAILURE: 3 }` (lib/errors.ts:2). Commands return
  an EXIT code, never call `process.exit` — only the `import.meta.main` block does.
- **Sink parameterization**: `main` and every command take `stdout`/`stderr` as
  `(s: string) => void` params, never write to console directly (cli.ts:31-36) — this is the
  in-process test contract. Human/structured output via `Reporter` + final `reporter.flush()`.
- `noUncheckedIndexedAccess` is on: handle `undefined` on indexed access (cli.ts:104-105);
  `as string` casts only where parseArgs guarantees a positional.
- Atomic writes only: `writeFileAtomic` (temp + rename, lib/fsx.ts:32-37); symlinks via
  `ensureSymlink`, which returns `"conflict"` instead of clobbering real files (fsx.ts:88-109).
