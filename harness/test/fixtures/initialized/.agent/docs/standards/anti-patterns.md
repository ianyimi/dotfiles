# Anti-Patterns

> MAX 40 lines. Real corrections only. Never auto-compact. Append-only via sync-spec.

- AP-001 (2026-06-12, seen 2x) Never use Date.now() in generated files — timestamps come from git or an injected clock
- AP-002 (2026-07-01, seen 1x) Never add npm runtime dependencies to the CLI core
