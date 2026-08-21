import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "../lib/args.ts";
import { EXIT, HarnessError } from "../lib/errors.ts";
import { writeFileAtomic } from "../lib/fsx.ts";
import { loadManifest } from "../lib/manifest.ts";
import { P } from "../lib/paths.ts";
import { addTask, moveTask, parseTasksFile, serializeTasksFile, TASK_SECTIONS, type TaskSectionId } from "../lib/tasksFile.ts";

const SCAFFOLD_SHAPE = "## In Progress\n\n## Inbox\n\n## Recently Done\n";

function sectionId(raw: string | undefined, fallback: TaskSectionId | null): TaskSectionId {
  const value = raw ?? fallback;
  if (value === null || !TASK_SECTIONS.includes(value as TaskSectionId)) {
    throw new HarnessError("usage", `--to must be one of: ${TASK_SECTIONS.join(", ")}`);
  }
  return value as TaskSectionId;
}

/**
 * `harness tasks add <title> [--to <section>] | move <title-substr> --to <section>` —
 * the only sanctioned way skills touch docs/tasks.md (D08-1).
 *
 * @param props.args - Tokens after "tasks".
 * @param props.root - Project root.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK on success (including idempotent no-op moves, D08-3).
 * @throws {HarnessError} "module-disabled" when modules.tasks is off; "usage" on bad
 *   subcommand/section; moveTask's "task-not-found"/"task-ambiguous" propagate.
 */
export function runTasks(props: { args: string[]; root: string; stdout: (s: string) => void }): number {
  const { manifest } = loadManifest({ root: props.root });
  if (!manifest.modules.tasks) {
    throw new HarnessError("module-disabled", "the tasks module is disabled", {
      hint: "enable modules.tasks in .agent/manifest.json",
    });
  }
  const tasksAbs = join(props.root, P.tasks);
  const doc = parseTasksFile({ text: existsSync(tasksAbs) ? readFileSync(tasksAbs, "utf8") : SCAFFOLD_SHAPE });

  const [sub, ...rest] = props.args;
  if (sub === "add") {
    const parsed = parseArgs({ argv: rest, spec: { positionals: ["title"], options: ["to"] } });
    const section = sectionId(parsed.options["to"], "inbox");
    const title = parsed.positionals["title"] as string;
    addTask({ doc, title, section });
    writeFileAtomic({ path: tasksAbs, content: serializeTasksFile({ doc }) });
    props.stdout(`added "${title}" to ${section}`);
    return EXIT.OK;
  }
  if (sub === "move") {
    const parsed = parseArgs({ argv: rest, spec: { positionals: ["title"], options: ["to"] } });
    const to = sectionId(parsed.options["to"], null);
    const result = moveTask({ doc, titleSubstr: parsed.positionals["title"] as string, to });
    if (result.noop) {
      props.stdout(`"${result.line}" already in ${to}`);
      return EXIT.OK;
    }
    writeFileAtomic({ path: tasksAbs, content: serializeTasksFile({ doc }) });
    props.stdout(`moved "${result.line}" ${result.from ?? "(unknown section)"} → ${to}`);
    return EXIT.OK;
  }
  throw new HarnessError("usage", `tasks: unknown subcommand ${JSON.stringify(sub)} — expected add | move`);
}
