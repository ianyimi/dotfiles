import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { HarnessError } from "../lib/errors.ts";
import { parseFrontmatter } from "../lib/frontmatter.ts";
import { writeFileAtomic } from "../lib/fsx.ts";
import { headCommitDate } from "../lib/git.ts";
import { loadManifest } from "../lib/manifest.ts";
import { P } from "../lib/paths.ts";

/** D02-1 frontmatter block shared by spec.md and spec-tasks.md. */
function frontmatterBlock(specId: string): string {
  return `---\nstatus: draft\nspec_id: ${specId}\ntouches: []\nprompt_version: 1\n---\n\n`;
}

/**
 * `harness spec new "<slug>"` — creates docs/specs/<date>-<slug>/{spec.md,spec-tasks.md}.
 * Dates come from --date or the HEAD commit date, never the wall clock (D02-2).
 *
 * @param props.root - Project root.
 * @param props.slug - Kebab-case feature slug.
 * @param props.date - Optional YYYY-MM-DD override.
 * @param props.stdout - Line sink; both created paths are printed.
 * @returns EXIT.OK.
 * @throws {HarnessError} "usage" bad slug/date; "no-date" when no git date and no --date;
 *   "spec-exists" when the directory already exists; "module-disabled" when modules.specs is off.
 */
export function specNew(props: {
  root: string;
  slug: string;
  date?: string;
  stdout: (s: string) => void;
}): number {
  const { manifest } = loadManifest({ root: props.root });
  if (!manifest.modules.specs) {
    throw new HarnessError("module-disabled", "the specs module is disabled", {
      hint: "enable modules.specs in .agent/manifest.json",
    });
  }
  if (!/^[a-z][a-z0-9-]+$/.test(props.slug)) {
    throw new HarnessError("usage", `invalid slug ${JSON.stringify(props.slug)} — expected kebab-case (e.g. "collections-ui")`);
  }
  let date = props.date;
  if (date !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HarnessError("usage", `invalid --date ${JSON.stringify(date)} — expected YYYY-MM-DD`);
  }
  if (date === undefined) {
    const gitDate = headCommitDate({ root: props.root });
    if (gitDate === "") {
      throw new HarnessError("no-date", "no git commit date available", { hint: "pass --date YYYY-MM-DD" });
    }
    date = gitDate;
  }
  const specId = `${date}-${props.slug}`;
  const dirRel = join(P.specs, specId);
  if (existsSync(join(props.root, dirRel))) {
    throw new HarnessError("spec-exists", `spec ${specId} already exists at ${dirRel}`);
  }
  const specPath = join(dirRel, "spec.md");
  const tasksPath = join(dirRel, "spec-tasks.md");
  writeFileAtomic({
    path: join(props.root, specPath),
    content: `${frontmatterBlock(specId)}# ${specId} — Spec\n\n## Overview\n\n## Design Decisions\n\n## Out of Scope\n\n## Implementation\n`,
  });
  writeFileAtomic({
    path: join(props.root, tasksPath),
    content: `${frontmatterBlock(specId)}# ${specId} — Tasks\n\n## T1 — <title>\nWhy:\nVerify:\n- [ ] \n`,
  });
  props.stdout(specPath);
  props.stdout(tasksPath);
  return 0;
}

/**
 * `harness spec list` — one line per spec from frontmatter + checkbox counts.
 *
 * @param props.root - Project root.
 * @param props.all - Include done/abandoned specs.
 * @param props.json - Emit JSON array instead of lines.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK.
 */
export function specList(props: {
  root: string;
  all: boolean;
  json: boolean;
  stdout: (s: string) => void;
}): number {
  const specsAbs = join(props.root, P.specs);
  const rows: Array<{ spec_id: string; status: string; open: number; total: number }> = [];
  if (existsSync(specsAbs)) {
    for (const entry of readdirSync(specsAbs, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      if (!entry.isDirectory()) continue;
      const specMd = join(specsAbs, entry.name, "spec.md");
      if (!existsSync(specMd)) continue;
      const { data } = parseFrontmatter({ text: readFileSync(specMd, "utf8") });
      const status = String(data["status"] ?? "draft");
      if (!props.all && (status === "done" || status === "abandoned")) continue;
      let open = 0;
      let total = 0;
      const tasksMd = join(specsAbs, entry.name, "spec-tasks.md");
      if (existsSync(tasksMd)) {
        const tasks = readFileSync(tasksMd, "utf8");
        open = (tasks.match(/- \[ \]/g) ?? []).length;
        total = open + (tasks.match(/- \[x\]/gi) ?? []).length;
      }
      rows.push({ spec_id: String(data["spec_id"] ?? entry.name), status, open, total });
    }
  }
  if (props.json) {
    props.stdout(JSON.stringify(rows, null, 2));
  } else if (rows.length === 0) {
    props.stdout("(no open specs)");
  } else {
    for (const r of rows) props.stdout(`${r.spec_id}  ${r.status}  ${r.open} open / ${r.total} total`);
  }
  return 0;
}
