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
