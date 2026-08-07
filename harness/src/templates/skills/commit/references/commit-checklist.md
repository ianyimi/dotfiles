# Commit Checklist

> Customized during `harness init`'s commit-gate step; edit freely — the commit skill runs
> every line, every time, and blocks the commit message until "Must pass" items pass (or the
> developer explicitly waives them; waivers are logged).

## Must pass

- [ ] `harness doctor` exits 0
- [ ] Project build passes (command in `.agent/docs/product/dev-processes.md`)
- [ ] Project tests pass (command in `.agent/docs/product/dev-processes.md`)
- [ ] `harness struct --check` reports no naming violations
- [ ] No unintended files staged (review `git status` before committing)

## Must be current

- [ ] Today's session-log entry is filled in (what/decisions/problems/left-off)
- [ ] `docs/tasks.md` reflects finished work (`harness tasks move … --to done`)
- [ ] `harness struct` run if files were added or moved
- [ ] `harness state` regenerated
- [ ] (modules.roadmap) completed milestones ticked in `docs/product/roadmap.md`
- [ ] (modules.decisions) new architectural decisions captured as ADRs
