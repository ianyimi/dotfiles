import type { DoctorCheck } from "../commands/doctor.ts";
import { P } from "../lib/paths.ts";
import { countLines } from "./budget.ts";

/** Any SKILL.md under .agent/skills/ over the skill line budget → warn per skill. */
const check: DoctorCheck = {
  id: "skill-over-budget",
  severity: "warn",
  appliesWhen: () => true,
  run: ({ ctx }) => {
    const budget = ctx.manifest.doctor.budgets.skill_lines;
    const findings = [];
    for (const file of ctx.listFiles(P.skills)) {
      if (!file.endsWith("/SKILL.md")) continue;
      const text = ctx.read(file);
      if (text === null) continue;
      const n = countLines({ text });
      if (n > budget) {
        findings.push({ message: `${file} is ${n} lines (budget: ${budget})`, hint: "move content into references/" });
      }
    }
    return findings;
  },
};
export default check;
