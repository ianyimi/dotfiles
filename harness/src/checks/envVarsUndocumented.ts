import type { DoctorCheck } from "../commands/doctor.ts";
import { parseEnvManifest } from "../commands/env.ts";
import { P } from "../lib/paths.ts";

/** Vars in .env.example absent from env.manifest.md → warn per var (proposal §15). */
const check: DoctorCheck = {
  id: "env-vars-undocumented",
  severity: "warn",
  appliesWhen: ({ ctx }) => ctx.manifest.modules.env_manifest && ctx.read(".env.example") !== null,
  run: ({ ctx }) => {
    const example = ctx.read(".env.example") as string;
    const documented = new Set(parseEnvManifest({ text: ctx.read(P.envManifest) ?? "" }).map((d) => d.name));
    const findings = [];
    for (const m of example.matchAll(/^([A-Za-z_][A-Za-z0-9_]*)=/gm)) {
      const name = m[1] as string;
      if (!documented.has(name)) {
        findings.push({
          message: `.env.example: ${name} not documented in env.manifest.md`,
          hint: "add a row to .agent/env.manifest.md",
        });
      }
    }
    return findings;
  },
};
export default check;
