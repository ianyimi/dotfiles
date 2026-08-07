import { existsSync } from "node:fs";
import { join } from "node:path";
import type { DoctorCheck } from "../commands/doctor.ts";
import { HarnessError } from "../lib/errors.ts";
import { isRepo, recentChangedFiles } from "../lib/git.ts";
import { checkPath, parseNamingRules } from "../lib/namingRules.ts";
import { P } from "../lib/paths.ts";

const NAMING = `${P.standards}/naming-conventions.md`;

/** Files changed in the last 10 commits that violate a naming rule → warn per file. */
const check: DoctorCheck = {
  id: "naming-violations",
  severity: "warn",
  appliesWhen: ({ ctx }) => ctx.read(NAMING) !== null && isRepo({ root: ctx.root }),
  run: ({ ctx }) => {
    let rules;
    try {
      rules = parseNamingRules({ text: ctx.read(NAMING) as string });
    } catch (e) {
      const msg = e instanceof HarnessError ? e.message : (e as Error).message;
      return [{ message: `naming-conventions.md rules block unparseable — ${msg}` }];
    }
    const findings = [];
    for (const file of recentChangedFiles({ root: ctx.root, commits: 10 })) {
      if (!existsSync(join(ctx.root, file))) continue;
      const result = checkPath({ path: file, rules });
      if (!result.ok) {
        findings.push({ message: `${file} violates ${result.matched[0]}`, hint: "harness struct --check" });
      }
    }
    return findings;
  },
};
export default check;
