# @zaye/harness

Platform-agnostic agent harness CLI. One committed `.agent/` directory is the source of truth
per project; `.omp/` (oh-my-pi) and `.claude/` (Claude Code) are generated bridges — mostly
symlinks into `.agent/` plus thin platform glue. Spec suite + implementation log:
`pi-agent-base/.pi/agent-docs/specs/agent-harness/`.

## Install (this machine)

Requires [Bun](https://bun.sh) ≥ 1.3.14.

```bash
cd ~/.local/share/chezmoi/harness
bun install
bun link          # → global `harness` command, running from this source tree
harness help
```

## Use in a project

```bash
cd ~/Documents/Projects/some-project
harness install        # or, better: open your agent and run /harness-init (Claude) or /init (OMP)
# … the init skill interviews you, mines any existing .pi/.claude setup, sweeps the codebase,
#   and finishes by writing .agent/docs/setup-report.md — read that.
harness sync                 # generate the platform bridges
harness doctor               # health check (also runs automatically on session start)
```

## Command surface

`init` (scaffold / write-phase / status / finish) · `doctor` · `state` · `sync` · `platform` ·
`spec` · `struct` · `index` · `context` · `pref` · `log` · `env` · `implement` · `polish` ·
`deps` · `template` · `tasks` · `worktree` — `harness help` lists them; almost all are called
by the skills, not by you. The human surface is: talk to your agent, plus `doctor` / `state` /
`sync` when working on the harness itself.

## Development

```bash
bun test           # 300+ tests, all hermetic (no network, no real ~/.harness)
bunx tsc --noEmit
```

Standalone compiled binaries (`bun build --compile`) are deferred — `bun link` covers
single-machine use.
