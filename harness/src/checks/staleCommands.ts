import type { DoctorCheck } from "../commands/doctor.ts";
import { P } from "../lib/paths.ts";

const DEV_PROCESSES = `${P.product}/dev-processes.md`;

/** Backticked `<pm> run <script>` commands in dev-processes.md must exist in package.json. */
const check: DoctorCheck = {
  id: "stale-commands",
  severity: "warn",
  appliesWhen: ({ ctx }) => ctx.read(DEV_PROCESSES) !== null && ctx.read("package.json") !== null,
  run: ({ ctx }) => {
    const doc = ctx.read(DEV_PROCESSES) as string;
    const pkg = JSON.parse(ctx.read("package.json") as string) as { scripts?: Record<string, string> };
    const scripts = pkg.scripts ?? {};
    const findings = [];
    const seen = new Set<string>();
    for (const m of doc.matchAll(/`(pnpm|npm|bun|yarn) run (\S+?)`/g)) {
      const script = m[2] as string;
      if (seen.has(script)) continue;
      seen.add(script);
      if (!(script in scripts)) {
        findings.push({
          message: `dev-processes.md references \`${m[1]} run ${script}\` but package.json has no "${script}" script`,
          hint: "update .agent/docs/product/dev-processes.md",
        });
      }
    }
    return findings;
  },
};
export default check;
