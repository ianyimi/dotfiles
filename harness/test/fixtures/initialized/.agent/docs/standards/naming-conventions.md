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
