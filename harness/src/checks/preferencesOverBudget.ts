import type { DoctorCheck } from "../commands/doctor.ts";
import { P } from "../lib/paths.ts";
import { countLines } from "./budget.ts";

const PREFS = `${P.standards}/preferences.md`;

/** preferences.md over its line budget → error (compaction is overdue). */
const check: DoctorCheck = {
  id: "preferences-over-budget",
  severity: "error",
  appliesWhen: () => true,
  run: ({ ctx }) => {
    const text = ctx.read(PREFS);
    if (text === null) return [];
    const n = countLines({ text });
    const budget = ctx.manifest.doctor.budgets.preferences_lines;
    if (n <= budget) return [];
    return [{ message: `preferences.md is ${n} lines (budget: ${budget})`, hint: "Run: harness pref compact" }];
  },
};
export default check;
