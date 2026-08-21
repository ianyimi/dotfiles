import { existsSync } from "node:fs";
import { join } from "node:path";
import type { DoctorCheck } from "../commands/doctor.ts";
import { parseFrontmatter } from "../lib/frontmatter.ts";
import { commitsTouching, isRepo } from "../lib/git.ts";
import { P } from "../lib/paths.ts";

/** Specs with open checkboxes but no commits on their touched paths recently → info. */
const check: DoctorCheck = {
  id: "open-specs-stale",
  severity: "info",
  appliesWhen: ({ ctx }) => ctx.manifest.modules.specs && isRepo({ root: ctx.root }),
  run: ({ ctx }) => {
    const findings = [];
    const specDirs = new Set(
      ctx
        .listFiles(P.specs)
        .map((f) => f.split("/").slice(0, 4).join("/")) // .agent/docs/specs/<slug>
        .filter((d) => d.split("/").length === 4),
    );
    for (const dir of [...specDirs].sort()) {
      if (!existsSync(join(ctx.root, dir))) continue;
      const tasks = ctx.read(`${dir}/spec-tasks.md`);
      if (tasks === null || !tasks.includes("- [ ]")) continue;
      const specMd = ctx.read(`${dir}/spec.md`);
      const touches =
        specMd !== null ? (parseFrontmatter({ text: specMd }).data["touches"] as unknown) : undefined;
      const paths = Array.isArray(touches) && touches.length > 0 ? (touches as string[]) : [dir];
      const days = ctx.manifest.doctor.stale_spec_days;
      if (commitsTouching({ root: ctx.root, paths, sinceDays: days }) === 0) {
        const slug = dir.split("/").pop() as string;
        findings.push({ message: `Spec ${slug}: open checkboxes, no commits on its paths in ${days} days` });
      }
    }
    return findings;
  },
};
export default check;
