import { existsSync } from "node:fs";
import { join } from "node:path";
import type { DoctorCheck } from "../commands/doctor.ts";
import { depDirname, readProjectPin } from "../commands/deps.ts";
import { loadRegistry } from "../lib/depsRegistry.ts";
import { P } from "../lib/paths.ts";

/** Cloned dep versions drifting from project pins, or registered clones gone missing → info. */
const check: DoctorCheck = {
  id: "stale-dependencies",
  severity: "info",
  appliesWhen: ({ ctx }) => loadRegistry({ root: ctx.root }).length > 0,
  run: ({ ctx }) => {
    const findings = [];
    for (const row of loadRegistry({ root: ctx.root })) {
      const cloneDir = join(ctx.root, P.dependencies, depDirname({ pkg: row.package }));
      if (!existsSync(cloneDir)) {
        findings.push({
          message: `registry: ${row.package} registered but clone missing`,
          hint: `harness deps clone ${row.package}`,
        });
        continue;
      }
      const pin = readProjectPin({ root: ctx.root, pkg: row.package });
      // pin === null → reference-only clone not in the project manifest — legitimate, no finding.
      if (pin !== null && pin !== row.version) {
        findings.push({
          message: `registry: ${row.package} cloned at ${row.version}, project pins ${pin}`,
          hint: `harness deps sync ${row.package}`,
        });
      }
    }
    return findings;
  },
};
export default check;
