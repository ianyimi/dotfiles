#!/usr/bin/env bun
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { CHECKS } from "./checks/index.ts";
import { runConfig } from "./commands/config.ts";
import { contextCommand } from "./commands/context.ts";
import { runDeps } from "./commands/deps.ts";
import { runDoctor } from "./commands/doctor.ts";
import { envCheck } from "./commands/env.ts";
import { implementDone, implementNext, implementStatus, implementVerify } from "./commands/implement.ts";
import { logAppend, logBackfillSha, logCommitMsg, logSessionEnd } from "./commands/log.ts";
import { buildPolishPacket } from "./commands/polish.ts";
import { indexRebuild } from "./commands/index.ts";
import { initFinish, initScaffold, initStatus, initWritePhase } from "./commands/init.ts";
import { runPlatform } from "./commands/platform.ts";
import { prefCompact, prefRemove } from "./commands/pref.ts";
import { specList, specNew } from "./commands/spec.ts";
import { bootstrapBridges, runSync } from "./commands/sync.ts";
import { runTasks } from "./commands/tasks.ts";
import { runTemplate } from "./commands/template.ts";
import { worktreeAdd } from "./commands/worktree.ts";
import { stateCommand } from "./commands/state.ts";
import { structCommand } from "./commands/struct.ts";
import { runFetch } from "./commands/fetch.ts";
import { parseArgs } from "./lib/args.ts";
import { EXIT, HarnessError } from "./lib/errors.ts";
import { loadManifest } from "./lib/manifest.ts";
import { Reporter } from "./lib/output.ts";
import { resolveProjectRoot } from "./lib/paths.ts";

/** Sink-parameterized main so tests run in-process (test/helpers.ts contract). */
export interface MainProps {
  argv: string[];
  cwd: string;
  stdout: (s: string) => void;
  stderr: (s: string) => void;
}

interface CommandProps {
  args: string[];
  cwd: string;
  stdout: (s: string) => void;
  stderr: (s: string) => void;
}

interface Command {
  run(props: CommandProps): Promise<number> | number;
  help: string;
}

/** Reads --data value: a JSON file path or "-" for stdin (fd 0). */
function readDataArg(raw: string): Record<string, unknown> {
  let text: string;
  try {
    text = raw === "-" ? readFileSync(0, "utf8") : readFileSync(raw, "utf8");
  } catch (e) {
    throw new HarnessError("usage", `cannot read --data ${raw}: ${(e as Error).message}`);
  }
  try {
    const value = JSON.parse(text) as unknown;
    if (typeof value !== "object" || value === null || Array.isArray(value)) {
      throw new Error("expected a JSON object");
    }
    return value as Record<string, unknown>;
  } catch (e) {
    throw new HarnessError("usage", `--data is not a JSON object: ${(e as Error).message}`);
  }
}

/** The single command registration point (master §8). Later specs append rows. */
const COMMANDS: Record<string, Command> = {
  install: {
    help: "install [--template <name>] [--refresh-skills | --refresh-skill <name>[,<name>…]] — install the .agent/ harness skeleton + skills here (refresh re-copies harness default skills from the current templates, discarding local edits to them; prefer --refresh-skill for just the one you need)",
    run: (props) => {
      const parsed = parseArgs({ argv: props.args, spec: { options: ["template", "refresh-skill"], flags: ["refresh-skills"] } });
      const refreshOne = parsed.options["refresh-skill"];
      if (parsed.flags["refresh-skills"] === true && refreshOne !== undefined) {
        throw new HarnessError("usage", "pass either --refresh-skills (all) or --refresh-skill <name>, not both");
      }
      const refreshSkills = refreshOne !== undefined ? refreshOne.split(",").map((s) => s.trim()).filter((s) => s !== "") : parsed.flags["refresh-skills"];
      // install must work on a brand-new directory: fall back to cwd when neither
      // .agent/ nor .git/ exists yet (the install creates the .agent marker).
      let root: string;
      try {
        root = resolveProjectRoot({ cwd: props.cwd });
      } catch {
        root = props.cwd;
      }
      const code = initScaffold({
        root,
        template: parsed.options["template"],
        refreshSkills,
        stdout: props.stdout,
      });
      // Pre-init bridge: make /init (OMP) and /harness-init (Claude Code) visible immediately
      // — the full bridge arrives with `harness sync` after the interview finishes.
      bootstrapBridges({ root, stdout: props.stdout });
      return code;
    },
  },
  init: {
    help: "init write-phase <n> --data <path|-> | init status | init finish (skill plumbing)",
    run: (props) => {
      const [sub, ...rest] = props.args;
      let root: string;
      try {
        root = resolveProjectRoot({ cwd: props.cwd });
      } catch {
        root = props.cwd;
      }
      switch (sub) {
        case "write-phase": {
          const parsed = parseArgs({ argv: rest, spec: { positionals: ["phase"], options: ["data"] } });
          const dataRaw = parsed.options["data"];
          if (dataRaw === undefined) throw new HarnessError("usage", "write-phase requires --data <path|->");
          return initWritePhase({
            root,
            phase: Number(parsed.positionals["phase"]),
            data: readDataArg(dataRaw),
            stdout: props.stdout,
          });
        }
        case "status":
          return initStatus({ root, stdout: props.stdout });
        case "finish":
          return initFinish({ root, stdout: props.stdout });
        default:
          throw new HarnessError("usage", `init: unknown subcommand ${JSON.stringify(sub)} — expected write-phase | status | finish (project setup starts with \`harness install\`)`);
      }
    },
  },
  doctor: {
    help: "doctor [--json] — staleness checks; exits 1 on errors",
    run: (props) => {
      const parsed = parseArgs({ argv: props.args, spec: { flags: ["json"] } });
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: parsed.flags["json"] === true, write: props.stdout });
      const code = runDoctor({ root, checks: CHECKS, reporter });
      reporter.flush();
      return code;
    },
  },
  state: {
    help: "state — regenerate .agent/docs/state.md and print it",
    run: (props) => {
      parseArgs({ argv: props.args, spec: {} });
      const root = resolveProjectRoot({ cwd: props.cwd });
      return stateCommand({ root, checks: CHECKS, stdout: props.stdout });
    },
  },
  spec: {
    help: 'spec new "<slug>" [--date YYYY-MM-DD] | spec list [--all] [--json]',
    run: (props) => {
      const [sub, ...rest] = props.args;
      const root = resolveProjectRoot({ cwd: props.cwd });
      if (sub === "new") {
        const parsed = parseArgs({ argv: rest, spec: { positionals: ["slug"], options: ["date"] } });
        return specNew({ root, slug: parsed.positionals["slug"] as string, date: parsed.options["date"], stdout: props.stdout });
      }
      if (sub === "list") {
        const parsed = parseArgs({ argv: rest, spec: { flags: ["all", "json"] } });
        return specList({ root, all: parsed.flags["all"] === true, json: parsed.flags["json"] === true, stdout: props.stdout });
      }
      throw new HarnessError("usage", `spec: unknown subcommand ${JSON.stringify(sub)} — expected new | list`);
    },
  },
  struct: {
    help: "struct — regenerate directory-structure.md | struct --check — naming violations only",
    run: (props) => {
      const parsed = parseArgs({ argv: props.args, spec: { flags: ["check"] } });
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: false, write: props.stdout });
      const code = structCommand({ root, check: parsed.flags["check"] === true, reporter, stdout: props.stdout });
      reporter.flush();
      return code;
    },
  },
  index: {
    help: "index rebuild — regenerate docs/standards/index.yml",
    run: (props) => {
      const [sub, ...rest] = props.args;
      if (sub !== "rebuild") throw new HarnessError("usage", "index: expected `index rebuild`");
      parseArgs({ argv: rest, spec: {} });
      const root = resolveProjectRoot({ cwd: props.cwd });
      return indexRebuild({ root, stdout: props.stdout });
    },
  },
  context: {
    help: 'context --for "<task>" [--files a,b] — print relevant context files',
    run: (props) => {
      const parsed = parseArgs({ argv: props.args, spec: { options: ["for", "files"] } });
      const task = parsed.options["for"];
      if (task === undefined) throw new HarnessError("usage", 'context requires --for "<task>"');
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: false, write: props.stderr });
      const code = contextCommand({ root, task, files: parsed.options["files"], stdout: props.stdout, reporter });
      reporter.flush();
      return code;
    },
  },
  config: {
    help: "config [list] | get <key> | set <key> <value> — toggles (models.*, workflow.*)",
    run: (props) => {
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: false, write: props.stdout });
      const code = runConfig({ args: props.args, root, reporter });
      reporter.flush();
      return code;
    },
  },
  sync: {
    help: "sync [--json] — regenerate platform bridges from .agent/ (symlinks + glue)",
    run: (props) => {
      const parsed = parseArgs({ argv: props.args, spec: { flags: ["json"] } });
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: parsed.flags["json"] === true, write: props.stdout });
      const code = runSync({ root, reporter });
      reporter.flush();
      return code;
    },
  },
  platform: {
    help: "platform add <id> | platform list — manage bridge platforms",
    run: (props) => {
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: false, write: props.stdout });
      const code = runPlatform({ args: props.args, root, reporter });
      reporter.flush();
      return code;
    },
  },
  log: {
    help: "log append [--slug s] | session-end | backfill-sha --sha <sha> | commit-msg (all: [--date d])",
    run: (props) => {
      const [sub, ...rest] = props.args;
      const root = resolveProjectRoot({ cwd: props.cwd });
      const { manifest } = loadManifest({ root });
      if (!manifest.modules.session_log) {
        throw new HarnessError("module-disabled", "session_log module is disabled in manifest.json", {
          hint: "enable modules.session_log",
        });
      }
      switch (sub) {
        case "append": {
          const parsed = parseArgs({ argv: rest, spec: { options: ["slug", "date"] } });
          logAppend({ root, slug: parsed.options["slug"], dateOpt: parsed.options["date"], stdout: props.stdout });
          return EXIT.OK;
        }
        case "session-end": {
          const parsed = parseArgs({ argv: rest, spec: { options: ["date"] } });
          logSessionEnd({ root, dateOpt: parsed.options["date"], stdout: props.stdout });
          return EXIT.OK;
        }
        case "backfill-sha": {
          const parsed = parseArgs({ argv: rest, spec: { options: ["sha", "date"] } });
          const sha = parsed.options["sha"];
          if (sha === undefined) throw new HarnessError("usage", "backfill-sha requires --sha <sha>");
          logBackfillSha({ root, sha, dateOpt: parsed.options["date"], stdout: props.stdout });
          return EXIT.OK;
        }
        case "commit-msg": {
          const parsed = parseArgs({ argv: rest, spec: { options: ["date"] } });
          return logCommitMsg({ root, dateOpt: parsed.options["date"], stdout: props.stdout });
        }
        default:
          throw new HarnessError("usage", `log: unknown subcommand ${JSON.stringify(sub)} — expected append | session-end | backfill-sha | commit-msg`);
      }
    },
  },
  deps: {
    help: "deps clone|sync|add|remove|list — dependency source clones",
    run: (props) => runDeps({ args: props.args, cwd: props.cwd, stdout: props.stdout, stderr: props.stderr }),
  },
  implement: {
    help: "implement <slug> [status|next|verify <Tn>|done <Tn>] — spec implementation state machine",
    run: (props) => {
      const parsed = parseArgs({
        argv: props.args,
        spec: { positionals: ["slug", "...rest"], flags: ["json", "force", "confirmed"], options: ["from", "reason"] },
      });
      const root = resolveProjectRoot({ cwd: props.cwd });
      const slug = parsed.positionals["slug"] as string;
      const sub = parsed.rest[0] ?? "status";
      const groupId = parsed.rest[1];
      switch (sub) {
        case "status": {
          const code = implementStatus({ root, slug, stdout: props.stdout });
          if (parsed.rest.length === 0) props.stdout("\ndrive the loop with the implement skill");
          return code;
        }
        case "next":
          return implementNext({ root, slug, from: parsed.options["from"], stdout: props.stdout });
        case "verify":
          if (groupId === undefined) throw new HarnessError("usage", "verify requires a group id, e.g. `verify T1`");
          return implementVerify({ root, slug, groupId, confirmed: parsed.flags["confirmed"], stdout: props.stdout });
        case "done":
          if (groupId === undefined) throw new HarnessError("usage", "done requires a group id, e.g. `done T1`");
          return implementDone({
            root,
            slug,
            groupId,
            force: parsed.flags["force"],
            reason: parsed.options["reason"],
            stdout: props.stdout,
          });
        default:
          throw new HarnessError("usage", `implement: unknown subcommand ${JSON.stringify(sub)} — expected status | next | verify | done`);
      }
    },
  },
  polish: {
    help: "polish <slug> — emit the polish packet (high-importance projects only)",
    run: (props) => {
      const parsed = parseArgs({ argv: props.args, spec: { positionals: ["slug"], flags: ["json"] } });
      const root = resolveProjectRoot({ cwd: props.cwd });
      return buildPolishPacket({ root, slug: parsed.positionals["slug"] as string, stdout: props.stdout });
    },
  },
  env: {
    help: "env check — verify documented env vars are set (names only, never values)",
    run: (props) => {
      const [sub, ...rest] = props.args;
      if (sub !== "check") throw new HarnessError("usage", "env: expected `env check`");
      parseArgs({ argv: rest, spec: {} });
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: false, write: props.stdout });
      const code = envCheck({ root, env: process.env as Record<string, string | undefined>, reporter });
      reporter.flush();
      return code;
    },
  },
  template: {
    help: "template save <name> [--force] | list | inspect <name> | delete <name>",
    run: (props) => runTemplate({ args: props.args, cwd: props.cwd, stdout: props.stdout }),
  },
  tasks: {
    help: 'tasks add <title> [--to <section>] | move <title-substr> --to <section>',
    run: (props) => {
      const root = resolveProjectRoot({ cwd: props.cwd });
      return runTasks({ args: props.args, root, stdout: props.stdout });
    },
  },
  worktree: {
    help: "worktree <feature> [--path <p>] — new sibling worktree + branch (+tmux window)",
    run: (props) => {
      const parsed = parseArgs({ argv: props.args, spec: { positionals: ["feature"], options: ["path"] } });
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: false, write: props.stdout });
      const code = worktreeAdd({
        root,
        feature: parsed.positionals["feature"] as string,
        path: parsed.options["path"],
        env: process.env as Record<string, string | undefined>,
        tmuxSpawn: (p) => execFileSync("tmux", p.args, { stdio: "ignore" }),
        reporter,
      });
      reporter.flush();
      return code;
    },
  },
  pref: {
    help: "pref compact [--budget n] | pref remove <id>",
    run: (props) => {
      const [sub, ...rest] = props.args;
      const root = resolveProjectRoot({ cwd: props.cwd });
      const reporter = new Reporter({ json: false, write: props.stdout });
      let code: number;
      if (sub === "compact") {
        const parsed = parseArgs({ argv: rest, spec: { options: ["budget"] } });
        const budget = parsed.options["budget"] !== undefined ? Number(parsed.options["budget"]) : undefined;
        code = prefCompact({ root, budget, reporter });
      } else if (sub === "remove") {
        const parsed = parseArgs({ argv: rest, spec: { positionals: ["id"] } });
        code = prefRemove({ root, id: parsed.positionals["id"] as string, reporter });
      } else {
        throw new HarnessError("usage", `pref: unknown subcommand ${JSON.stringify(sub)} — expected compact | remove`);
      }
      reporter.flush();
      return code;
    },
  },
  fetch: {
    help: "fetch [<skill>] [--json] — report what the upstream harness WOULD change vs this project (read-only; nothing is written), like `git fetch`. Run by the `harness-pull` skill from the agent IDE — humans shouldn't invoke it directly. Omit <skill> for a summary of skills with incoming changes.",
    run: (props) => {
      const parsed = parseArgs({ argv: props.args, spec: { positionals: ["...rest"], flags: ["json"] } });
      const name = parsed.rest.find((a) => !a.startsWith("-"));
      const root = resolveProjectRoot({ cwd: props.cwd });
      return runFetch({
        root,
        name,
        json: parsed.flags["json"] === true,
        stdout: props.stdout,
      });
    },
  },
};

/**
 * CLI entry. Routes `harness <command> [subcommand] [...args]` to command modules.
 *
 * @param props.argv - Tokens after the binary name.
 * @param props.cwd - Working directory.
 * @param props.stdout - Line sink for normal output.
 * @param props.stderr - Line sink for errors/usage.
 * @returns Process exit code (EXIT.*).
 */
export async function main(props: MainProps): Promise<number> {
  const [command, ...args] = props.argv;
  if (command === undefined || command === "help" || command === "--help") {
    props.stdout("harness — platform-agnostic agent harness CLI");
    props.stdout("");
    for (const [name, cmd] of Object.entries(COMMANDS)) {
      props.stdout(`  harness ${name.padEnd(8)} ${cmd.help}`);
    }
    return EXIT.OK;
  }
  const cmd = COMMANDS[command];
  if (cmd === undefined) {
    props.stderr(`unknown command: ${command}`);
    props.stderr(`run \`harness help\` for the command list`);
    return EXIT.USAGE;
  }
  try {
    return await cmd.run({ args, cwd: props.cwd, stdout: props.stdout, stderr: props.stderr });
  } catch (e) {
    if (e instanceof HarnessError) {
      props.stderr(`error(${e.code}): ${e.message}`);
      if (e.hint !== undefined) props.stderr(`  → ${e.hint}`);
      return e.exitCode;
    }
    props.stderr(`unexpected: ${(e as Error).message}`);
    if ((e as Error).stack !== undefined) props.stderr((e as Error).stack as string);
    return EXIT.FAILURE;
  }
}

if (import.meta.main) {
  const code = await main({
    argv: process.argv.slice(2),
    cwd: process.cwd(),
    stdout: console.log,
    stderr: console.error,
  });
  process.exit(code);
}
