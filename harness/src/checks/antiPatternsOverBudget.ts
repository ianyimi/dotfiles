import type { DoctorCheck } from "../commands/doctor.ts";
import { P } from "../lib/paths.ts";
import { countLines } from "./budget.ts";

const FILE = `${P.standards}/anti-patterns.md`;

/** anti-patterns.md over its line budget → warn; never auto-compacted. */
const check: DoctorCheck = {
  id: "anti-patterns-over-budget",
  severity: "warn",
  appliesWhen: () => true,
  run: ({ ctx }) => {
    const text = ctx.read(FILE);
    if (text === null) return [];
    const n = countLines({ text });
    const budget = ctx.manifest.doctor.budgets.anti_patterns_lines;
    if (n <= budget) return [];
    return [{ message: `anti-patterns.md is ${n} lines (budget: ${budget})`, hint: "manual review — never auto-compact" }];
  },
};
export default check;
