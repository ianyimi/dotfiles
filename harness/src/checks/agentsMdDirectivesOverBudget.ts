import type { DoctorCheck } from "../commands/doctor.ts";
import { P } from "../lib/paths.ts";
import { countLines } from "./budget.ts";

/** The AGENTS.md "## Agent Directives" section must stay tiny — it loads on every prompt. */
const check: DoctorCheck = {
  id: "agents-md-directives-over-budget",
  severity: "warn",
  appliesWhen: () => true,
  run: ({ ctx }) => {
    const text = ctx.read(P.agentsMd);
    if (text === null) return [];
    const lines = text.split("\n");
    const start = lines.findIndex((l) => l.trim() === "## Agent Directives");
    if (start === -1) {
      return [{ message: `AGENTS.md has no "## Agent Directives" section` }];
    }
    let end = lines.length;
    for (let i = start + 1; i < lines.length; i++) {
      if ((lines[i] as string).startsWith("## ")) {
        end = i;
        break;
      }
    }
    const n = countLines({ text: lines.slice(start + 1, end).join("\n") });
    const budget = ctx.manifest.doctor.budgets.agents_md_directives_lines;
    if (n <= budget) return [];
    return [{ message: `AGENTS.md directives section is ${n} lines (budget: ${budget})`, hint: "move rules into standards files" }];
  },
};
export default check;
