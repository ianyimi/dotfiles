import { readFileSync } from "node:fs";
import { CHECKS } from "./checks/index.ts";
import { contextCommand } from "./commands/context.ts";
import { runDoctor } from "./commands/doctor.ts";
import { envCheck } from "./commands/env.ts";
import { logAppend, logBackfillSha, logCommitMsg, logSessionEnd } from "./commands/log.ts";
import { indexRebuild } from "./commands/index.ts";
import { initFinish, initScaffold, initStatus, initWritePhase } from "./commands/init.ts";
import { runPlatform } from "./commands/platform.ts";
import { prefCompact, prefRemove } from "./commands/pref.ts";
import { specList, specNew } from "./commands/spec.ts";
import { runSync } from "./commands/sync.ts";
import { stateCommand } from "./commands/state.ts";
import { structCommand } from "./commands/struct.ts";
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
  init: {
    help: "init scaffold | init write-phase <n> --data <path|-> | init status | init finish",
    run: (props) => {
      const [sub, ...rest] = props.args;
      // init must work on a brand-new directory: fall back to cwd when neither
      // .agent/ nor .git/ exists yet (the scaffold creates the .agent marker).
      let root: string;
      try {
        root = resolveProjectRoot({ cwd: props.cwd });
      } catch {
        root = props.cwd;
      }
      switch (sub) {
        case "scaffold":
          return initScaffold({ root, stdout: props.stdout });
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
          throw new HarnessError("usage", `init: unknown subcommand ${JSON.stringify(sub)} — expected scaffold | write-phase | status | finish`);
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
