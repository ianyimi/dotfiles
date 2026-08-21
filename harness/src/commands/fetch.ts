import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { HarnessError } from "../lib/errors.ts";
import { P } from "../lib/paths.ts";
import { planSync, type SyncChange } from "./sync.ts";

const TEMPLATES = join(dirname(fileURLToPath(import.meta.url)), "..", "templates");

/** One incoming file change: what the upstream (main) harness ships vs the project's copy. */
export interface FetchPlanEntry {
  /** new — no project copy · changed — contents differ · same — identical. */
  status: "new" | "changed" | "same";
  /** Project-relative destination path (where the file lives / would live). */
  projectPath: string;
  /** Absolute path to the upstream harness's current source for this file. */
  upstreamPath: string;
}

/** Recursively lists files under `dir`, returned as paths relative to `dir`. */
function listFiles(dir: string): string[] {
  const out: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const abs = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...listFiles(abs).map((p) => join(entry.name, p)));
    else out.push(entry.name);
  }
  return out;
}

/**
 * Compares the upstream (main) harness's current files for a shipped skill against the
 * project's copy and reports what a pull WOULD change — WITHOUT writing anything.
 *
 * Think `git fetch` + `git diff origin`: this is the read side. The `harness-pull` skill consumes it,
 * reads each `upstreamPath` (the new version) plus the project file, and merges the changes by
 * hand — preserving project-specific hardening (e.g. a customized `commit-checklist.md`). It is
 * the safe counterpart to `install --refresh-skill`, which overwrites wholesale.
 *
 * @param props.root - Project root.
 * @param props.name - Shipped skill name to compare (e.g. "commit").
 * @returns The plan entries, upstream-source order.
 * @throws {HarnessError} "usage" when `name` is not an upstream-shipped skill.
 */
export function planSkillFetch(props: { root: string; name: string }): FetchPlanEntry[] {
  const skillsSrc = join(TEMPLATES, "skills");
  const shipped = readdirSync(skillsSrc, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name);
  if (!shipped.includes(props.name)) {
    throw new HarnessError("usage", `fetch: ${props.name} is not an upstream harness skill (available: ${shipped.join(", ")})`);
  }
  const tplDir = join(skillsSrc, props.name);
  const entries: FetchPlanEntry[] = [];
  for (const rel of listFiles(tplDir)) {
    const upstreamPath = join(tplDir, rel);
    const projectRel = join(P.skills, props.name, rel);
    const projectAbs = join(props.root, projectRel);
    let status: FetchPlanEntry["status"];
    if (!existsSync(projectAbs)) status = "new";
    else status = readFileSync(projectAbs, "utf8") === readFileSync(upstreamPath, "utf8") ? "same" : "changed";
    entries.push({ status, projectPath: projectRel, upstreamPath });
  }
  return entries;
}

/** Human label for a planned sync change, or null when it is a no-op (nothing to preview). */
function syncChangeLine(c: SyncChange): string | null {
  switch (c.op) {
    case "create":
      return `NEW      ${c.path}`;
    case "update":
      return `CHANGED  ${c.path}`;
    case "merge":
      return c.merged === null ? null : `MERGE    ${c.path} (key-level ${c.had ? "update" : "create"})`;
    case "symlink":
      return c.result === "ok" ? null : `SYMLINK  ${c.path} -> ${c.targetPath} (${c.result})`;
    case "delete":
      return `DELETE   ${c.path}`;
    case "gitignore":
      return c.nextText === null ? null : "CHANGED  .gitignore (managed block)";
    case "conflict":
      return `CONFLICT ${c.path} — ${c.message}`;
    case "unchanged":
      return null;
  }
}

/** Counts the actionable (non no-op) changes in a sync plan. */
function syncActionable(root: string): number {
  try {
    return planSync({ root }).changes.filter((c) => syncChangeLine(c) !== null).length;
  } catch {
    return 0;
  }
}

/**
 * `harness fetch sync` — render the read-only bridge/sync plan: what `harness sync` WOULD
 * create/update/delete/merge, without writing. The harness-pull skill applies these after review.
 *
 * @param props.root - Project root.
 * @param props.json - Emit machine-readable JSON instead of the human table.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK.
 */
function renderSyncPlan(props: { root: string; json?: boolean; stdout: (s: string) => void }): number {
  const plan = planSync({ root: props.root });
  if (props.json === true) {
    props.stdout(JSON.stringify({ sync: plan.changes.filter((c) => syncChangeLine(c) !== null) }, null, 2));
    return 0;
  }
  props.stdout("Incoming bridge/sync changes (nothing written — the harness-pull skill applies these):");
  let n = 0;
  for (const c of plan.changes) {
    const line = syncChangeLine(c);
    if (line === null) continue;
    props.stdout(`  ${line}`);
    n++;
  }
  if (n === 0) props.stdout("  (up to date — bridges match .agent/)");
  else {
    props.stdout("\nThese regenerate from `.agent/` via `harness sync`. CONFLICT lines are user-modified");
    props.stdout("managed files sync won't touch — resolve by moving edits into `.agent/`.");
  }
  return 0;
}

/**
 * `harness fetch [<skill>]` — report what the upstream harness would change in this project,
 * WITHOUT applying anything (the read side of a harness pull).
 *
 * Humans don't run this directly — the `harness-pull` skill runs it from the agent IDE so an agent with
 * full project context decides what merges and what stays. With no name, lists shipped skills
 * that have any new/changed file against this project.
 *
 * @param props.root - Project root.
 * @param props.name - Optional skill name; omitted → summary across all shipped skills.
 * @param props.json - Emit machine-readable JSON instead of the human table.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK.
 */
export function runFetch(props: { root: string; name?: string; json?: boolean; stdout: (s: string) => void }): number {
  const skillsSrc = join(TEMPLATES, "skills");
  const shipped = readdirSync(skillsSrc, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name);

  if (props.name === "sync") return renderSyncPlan({ root: props.root, json: props.json, stdout: props.stdout });

  if (props.name === undefined) {
    const summary = shipped
      .map((name) => ({ name, entries: planSkillFetch({ root: props.root, name }) }))
      .map(({ name, entries }) => ({
        name,
        changed: entries.filter((e) => e.status === "changed").length,
        added: entries.filter((e) => e.status === "new").length,
      }))
      .filter((s) => s.changed + s.added > 0);
    const syncCount = syncActionable(props.root);
    if (props.json === true) {
      props.stdout(JSON.stringify({ skills: summary, sync: syncCount }, null, 2));
      return 0;
    }
    if (summary.length === 0 && syncCount === 0) {
      props.stdout("up to date — no upstream skill differs from this project.");
      return 0;
    }
    props.stdout("Incoming from upstream harness (run the `harness-pull` skill to merge):");
    for (const s of summary) props.stdout(`  ${s.name}: ${s.changed} changed, ${s.added} new`);
    if (syncCount > 0) props.stdout(`  sync (bridges): ${syncCount} change(s) — run \`harness fetch sync\` for the plan`);
    props.stdout("\nNothing is applied. The `harness-pull` skill reads this and merges by hand,");
    props.stdout("preserving project-specific config — nothing is overwritten wholesale.");
    return 0;
  }

  const entries = planSkillFetch({ root: props.root, name: props.name });
  if (props.json === true) {
    props.stdout(JSON.stringify({ skill: props.name, files: entries }, null, 2));
    return 0;
  }
  props.stdout(`Incoming changes for skill "${props.name}" (nothing written — merge via the harness-pull skill):`);
  for (const e of entries) {
    if (e.status === "same") continue;
    const tag = e.status === "new" ? "NEW    " : "CHANGED";
    props.stdout(`  ${tag}  ${e.projectPath}`);
    props.stdout(`           upstream version: ${e.upstreamPath}`);
  }
  const changed = entries.filter((e) => e.status !== "same").length;
  if (changed === 0) props.stdout("  (up to date — project copy matches upstream)");
  else {
    props.stdout("\nFor each CHANGED file, read the upstream version and the project file, then merge the");
    props.stdout("meaningful updates into the project copy — keep project-specific hardening (e.g. a");
    props.stdout("customized commit-checklist). NEW files can be copied in as-is unless they conflict.");
  }
  return 0;
}
