import type { DoctorCheck } from "../commands/doctor.ts";
import { parseFrontmatter } from "../lib/frontmatter.ts";
import { P } from "../lib/paths.ts";

const TECH_STACK = `${P.product}/tech-stack.md`;

/** A superseded ADR whose `package:` still appears in tech-stack.md → warn. */
const check: DoctorCheck = {
  id: "decisions-inconsistent",
  severity: "warn",
  appliesWhen: ({ ctx }) => ctx.manifest.modules.decisions && ctx.read(TECH_STACK) !== null,
  run: ({ ctx }) => {
    const techStack = ctx.read(TECH_STACK) as string;
    const findings = [];
    for (const file of ctx.listFiles(P.decisions)) {
      if (!file.endsWith(".md")) continue;
      const text = ctx.read(file);
      if (text === null) continue;
      const { data } = parseFrontmatter({ text });
      const pkg = data["package"];
      if (data["status"] === "Superseded" && typeof pkg === "string" && techStack.includes(pkg)) {
        findings.push({
          message: `${file} is Superseded but tech-stack.md still lists \`${pkg}\``,
          hint: "update tech-stack.md or the ADR status",
        });
      }
    }
    return findings;
  },
};
export default check;
