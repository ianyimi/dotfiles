import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { EXIT, HarnessError } from "../lib/errors.ts";
import { writeFileAtomic } from "../lib/fsx.ts";
import { loadImplementState, saveImplementState, type ImplementState } from "../lib/implementState.ts";
import { P } from "../lib/paths.ts";
import { parseSpecTasks, tickGroup, type SpecTasks, type TaskGroup } from "../lib/specTasks.ts";
import { contextFilesFor } from "./context.ts";
import { appendLogLine } from "./log.ts";

export const VERIFY_TIMEOUT_MS = 300_000;

/** Group display state for the status table. */
export type GroupDisplayState = "done" | "failed" | "next" | "pending";

interface LoadedSpec {
  specDir: string;
  tasksPath: string;
  text: string;
  tasks: SpecTasks;
  state: ImplementState;
}

/** Loads a spec's tasks + implement state, with precise not-found errors. */
function loadSpec(props: { root: string; slug: string }): LoadedSpec {
  const specDir = join(props.root, P.specs, props.slug);
  if (!existsSync(specDir)) {
    throw new HarnessError("spec-not-found", `no spec directory for "${props.slug}"`, { hint: "harness spec list" });
  }
  const tasksPath = join(specDir, "spec-tasks.md");
  if (!existsSync(tasksPath)) {
    throw new HarnessError("spec-tasks-missing", `${props.slug} has no spec-tasks.md`, { hint: "harness spec new" });
  }
  const text = readFileSync(tasksPath, "utf8");
  return { specDir, tasksPath, text, tasks: parseSpecTasks({ text }), state: loadImplementState({ specDir, slug: props.slug }) };
}

function groupDone(group: TaskGroup): boolean {
  return group.steps.every((s) => s.checked);
}

function findGroup(loaded: LoadedSpec, groupId: string): TaskGroup {
  const group = loaded.tasks.groups.find((g) => g.id === groupId);
  if (group === undefined) {
    throw new HarnessError("group-not-found", `no task group ${groupId} (valid: ${loaded.tasks.groups.map((g) => g.id).join(", ")})`);
  }
  return group;
}

/**
 * Prints the task-group table. Columns: ID, Title, Steps (checked/total), Verify, State —
 * two-space separated, each padded to max(header, longest cell); no trailing pad on State.
 *
 * @param props.root - Project root.
 * @param props.slug - Spec slug.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK always (status never fails on content).
 */
export function implementStatus(props: { root: string; slug: string; stdout: (s: string) => void }): number {
  const loaded = loadSpec({ root: props.root, slug: props.slug });
  const groups = loaded.tasks.groups;
  const totalSteps = groups.reduce((n, g) => n + g.steps.length, 0);
  const checkedSteps = groups.reduce((n, g) => n + g.steps.filter((s) => s.checked).length, 0);
  props.stdout(`Spec: ${props.slug} — ${groups.length} task groups, ${checkedSteps}/${totalSteps} steps done`);
  props.stdout("");
  if (groups.length === 0) {
    props.stdout("(no task groups)");
    return EXIT.OK;
  }

  let nextAssigned = false;
  const rows = groups.map((g) => {
    let state: GroupDisplayState;
    if (groupDone(g)) {
      state = "done";
    } else if (loaded.state.groups[g.id]?.last_result === "fail") {
      state = "failed";
    } else if (!nextAssigned) {
      state = "next";
      nextAssigned = true;
    } else {
      state = "pending";
    }
    return {
      id: g.id,
      title: g.title,
      steps: `${g.steps.filter((s) => s.checked).length}/${g.steps.length}`,
      verify: g.verify,
      state,
    };
  });

  const headers = { id: "ID", title: "Title", steps: "Steps", verify: "Verify", state: "State" };
  const width = (key: "id" | "title" | "steps" | "verify") =>
    Math.max(headers[key].length, ...rows.map((r) => r[key].length));
  const w = { id: width("id"), title: width("title"), steps: width("steps"), verify: width("verify") };
  const render = (r: { id: string; title: string; steps: string; verify: string; state: string }) =>
    `${r.id.padEnd(w.id)}  ${r.title.padEnd(w.title)}  ${r.steps.padEnd(w.steps)}  ${r.verify.padEnd(w.verify)}  ${r.state}`;
  props.stdout(render({ ...headers }));
  for (const r of rows) props.stdout(render(r));
  return EXIT.OK;
}

/** True when dependencies/registry.md has at least one real entry row. */
function hasRegistryEntries(root: string): boolean {
  const path = join(root, P.depsRegistry);
  if (!existsSync(path)) return false;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    if (!line.trimStart().startsWith("|")) continue;
    const cells = line.split("|").map((c) => c.trim()).filter((c) => c !== "");
    const first = cells[0] ?? "";
    if (first.toLowerCase() === "package") continue; // table header
    if (/^[-: ]+$/.test(first)) continue; // separator
    if (first !== "") return true;
  }
  return false;
}

/**
 * Prints the working packet for the next unchecked group (or --from's group). This stdout IS
 * the implement skill's context bundle (D12 — packaging only).
 *
 * @param props.root - Project root.
 * @param props.slug - Spec slug.
 * @param props.from - Optional group id override (a done group is allowed — re-work).
 * @param props.stdout - Line sink.
 * @returns EXIT.OK; also EXIT.OK with "(all groups done)" when nothing is open.
 */
export function implementNext(props: { root: string; slug: string; from?: string; stdout: (s: string) => void }): number {
  const loaded = loadSpec({ root: props.root, slug: props.slug });
  const target = props.from !== undefined ? findGroup(loaded, props.from) : loaded.tasks.groups.find((g) => !groupDone(g));
  if (target === undefined) {
    props.stdout("(all groups done — run the commit skill)");
    return EXIT.OK;
  }

  const out: string[] = [];
  out.push(`# ${props.slug} — ${target.id}: ${target.title}`, "");
  out.push(`Why: ${target.why}`, `Verify: ${target.verify}`, "");
  out.push("## Steps");
  const taskLines = loaded.text.split("\n");
  for (const step of target.steps) out.push(taskLines[step.line] as string);
  out.push("");

  out.push("## Spec section (from spec.md)");
  const specPath = join(loaded.specDir, "spec.md");
  let sectionLines: string[] | null = null;
  if (existsSync(specPath)) {
    const specLines = readFileSync(specPath, "utf8").split("\n");
    const start = specLines.findIndex((l) => l.startsWith(`## ${target.id} — `));
    if (start !== -1) {
      let end = specLines.length;
      for (let i = start + 1; i < specLines.length; i++) {
        if ((specLines[i] as string).startsWith("## ")) {
          end = i;
          break;
        }
      }
      sectionLines = specLines.slice(start, end);
      while (sectionLines.length > 0 && (sectionLines[sectionLines.length - 1] as string).trim() === "") sectionLines.pop();
    }
  }
  out.push(...(sectionLines ?? ["(no matching spec section — read spec.md in full)"]));
  out.push("");

  out.push(`## Context files (harness context --for "${target.title}")`);
  const contextFiles = contextFilesFor({ root: props.root, task: target.title });
  out.push(...(contextFiles.length > 0 ? contextFiles : ["(none — no context rules matched)"]));
  out.push("");

  if (hasRegistryEntries(props.root)) {
    out.push("## Dependency sources", "Cloned dependency source is listed in .agent/dependencies/registry.md — read it when this group touches those libraries.", "");
  }

  out.push("## Conventions", "Read .agent/docs/standards/naming-conventions.md before writing any code.");
  for (const line of out) props.stdout(line);
  return EXIT.OK;
}

/**
 * Runs the group's Verify command and records the result in .implement-state.json.
 *
 * @param props.root - Project root.
 * @param props.slug - Spec slug.
 * @param props.groupId - Group id, e.g. "T1".
 * @param props.confirmed - Required for `Verify: manual` groups.
 * @param props.now - Injected ISO timestamp (tests); defaults to the current time.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK on pass/confirmed manual; EXIT.FINDINGS on fail or unconfirmed manual.
 */
export function implementVerify(props: {
  root: string;
  slug: string;
  groupId: string;
  confirmed?: boolean;
  now?: string;
  stdout: (s: string) => void;
}): number {
  const loaded = loadSpec({ root: props.root, slug: props.slug });
  const group = findGroup(loaded, props.groupId);
  const now = props.now ?? new Date().toISOString();

  if (group.verify === "manual") {
    if (props.confirmed !== true) {
      props.stdout(`manual verification required for ${group.id} — confirm with the developer, then re-run with --confirmed`);
      return EXIT.FINDINGS;
    }
    const prev = loaded.state.groups[group.id];
    loaded.state.groups[group.id] = {
      attempts: (prev?.attempts ?? 0) + 1,
      last_result: "pass",
      last_exit_code: null,
      last_output_tail: [],
      ...(prev?.forced !== undefined ? { forced: prev.forced } : {}),
    };
    loaded.state.updated = now;
    saveImplementState({ specDir: loaded.specDir, state: loaded.state });
    props.stdout(`${group.id} verify: manual — confirmed`);
    return EXIT.OK;
  }

  const proc = Bun.spawnSync({
    cmd: ["sh", "-c", group.verify],
    cwd: props.root,
    stdout: "pipe",
    stderr: "pipe",
    timeout: VERIFY_TIMEOUT_MS,
    // Verify commands often invoke the same runtime the harness runs under (bun/node);
    // prepend its bin dir so they resolve regardless of the caller's login PATH.
    env: { ...process.env, PATH: `${dirname(process.execPath)}:${process.env["PATH"] ?? ""}` },
  });
  const exitCode = proc.exitCode ?? -1;
  const combined = `${proc.stdout.toString()}${proc.stderr.toString()}`;
  const tail = combined.split("\n").filter((l) => l !== "").slice(-40);
  if (proc.exitCode === null) tail.push("verify timed out after 300s");
  const pass = exitCode === 0;

  const prev = loaded.state.groups[group.id];
  loaded.state.groups[group.id] = {
    attempts: (prev?.attempts ?? 0) + 1,
    last_result: pass ? "pass" : "fail",
    last_exit_code: exitCode,
    last_output_tail: tail,
    ...(prev?.forced !== undefined ? { forced: prev.forced } : {}),
  };
  loaded.state.updated = now;
  saveImplementState({ specDir: loaded.specDir, state: loaded.state });

  for (const line of tail) props.stdout(line);
  if (pass) {
    props.stdout(`${group.id} verify: pass`);
    return EXIT.OK;
  }
  props.stdout(`${group.id} verify: FAIL (exit ${exitCode}) — done is blocked until verify passes`);
  return EXIT.FINDINGS;
}

/**
 * Marks a group complete: requires a recorded passing verify (or --force with a reason),
 * ticks the group's checkboxes, appends a session-log line via 03's appendLogLine.
 *
 * @param props.root - Project root.
 * @param props.slug - Spec slug.
 * @param props.groupId - Group id, e.g. "T1".
 * @param props.force - Bypass the verify gate (developer-approved only).
 * @param props.reason - Required with force; recorded in state + log.
 * @param props.now - Injected ISO timestamp.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK.
 * @throws {HarnessError} "verify-not-passed" when last_result !== "pass" and !force;
 *   "force-reason-required" when force && !reason.
 */
export function implementDone(props: {
  root: string;
  slug: string;
  groupId: string;
  force?: boolean;
  reason?: string;
  now?: string;
  stdout: (s: string) => void;
}): number {
  const loaded = loadSpec({ root: props.root, slug: props.slug });
  const group = findGroup(loaded, props.groupId);
  const now = props.now ?? new Date().toISOString();

  if (groupDone(group)) {
    props.stdout(`${group.id} already done`);
    return EXIT.OK;
  }

  const gs = loaded.state.groups[group.id];
  let logSuffix: string;
  if (gs?.last_result === "pass") {
    logSuffix = `(verify pass, ${gs.attempts} attempt(s))`;
  } else if (props.force !== true) {
    const lastDesc = gs?.last_result === "fail" ? `fail (exit ${gs.last_exit_code})` : "never run";
    throw new HarnessError("verify-not-passed", `${group.id} verify is ${lastDesc} — done is blocked`, {
      hint: `harness implement ${props.slug} verify ${group.id}`,
    });
  } else if (props.reason === undefined || props.reason === "") {
    throw new HarnessError("force-reason-required", "--force requires --reason \"<why>\"");
  } else {
    loaded.state.groups[group.id] = {
      attempts: gs?.attempts ?? 0,
      last_result: gs?.last_result ?? null,
      last_exit_code: gs?.last_exit_code ?? null,
      last_output_tail: gs?.last_output_tail ?? [],
      forced: { reason: props.reason, at: now },
    };
    logSuffix = `(FORCED: ${props.reason})`;
  }

  writeFileAtomic({ path: loaded.tasksPath, content: tickGroup({ text: loaded.text, groupId: group.id }) });
  loaded.state.updated = now;
  saveImplementState({ specDir: loaded.specDir, state: loaded.state });
  appendLogLine({ root: props.root, line: `implement ${props.slug}: ${group.id} done — ${group.title} ${logSuffix}` });

  const after = parseSpecTasks({ text: readFileSync(loaded.tasksPath, "utf8") });
  const done = after.groups.find((g) => g.id === group.id) as TaskGroup;
  const nextOpen = after.groups.find((g) => !groupDone(g));
  props.stdout(
    `${group.id} done — ${done.steps.filter((s) => s.checked).length}/${done.steps.length} steps ticked${nextOpen !== undefined ? ` (next: ${nextOpen.id})` : ""}`,
  );
  return EXIT.OK;
}
