# Commit Checklist

> Customized during `harness init`'s commit-gate step; edit freely — the commit skill runs
> every line, every time, and blocks the commit message until "Must pass" items pass (or the
> developer explicitly waives them; waivers are logged).

## Must pass

- [ ] `harness doctor` exits 0
- [ ] `chezmoi apply` run — live config matches source
- [ ] `nvim --headless "+lua vim.print('config-ok')" +qa` exits 0 (config loads cleanly)
- [ ] `harness struct --check` reports no naming violations
- [ ] No unintended files staged (review `git status` before committing)
- [ ] `lazy-lock.json` staged if plugin set changed (specs and lockfile move together)

## Must be current

- [ ] Today's session-log entry is filled in (what/decisions/problems/left-off)
- [ ] `docs/tasks.md` reflects finished work (`harness tasks move … --to done`)
- [ ] `harness struct` run if files were added or moved
- [ ] `harness state` regenerated
- [ ] (modules.decisions) new architectural decisions captured as ADRs
