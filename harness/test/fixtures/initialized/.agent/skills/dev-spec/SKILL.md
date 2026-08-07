---
name: dev-spec
description: Write a scoped implementation spec. Triggers on "write a spec", "spec out X".
---

# Dev Spec

## Preflight
1. If `.agent/manifest.json` is missing, stop; tell the user to run harness init.
2. Run `harness doctor`. Fix errors before proceeding.
3. Run `harness state` and read the output.

## Steps
1. Interview the developer.
2. Explore the codebase.
3. Write the spec.
