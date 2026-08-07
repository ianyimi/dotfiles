import type { CheckFinding, DoctorCheck } from "../commands/doctor.ts";
import { parseFrontmatter } from "../lib/frontmatter.ts";
import { P } from "../lib/paths.ts";

const TECH_STACK = `${P.product}/tech-stack.md`;

/**
 * Backticked package tokens in tech-stack.md list/table lines must exist in package.json
 * deps. Also flags a stale `verified_at` sha (info) when git HEAD is known.
 */
const check: DoctorCheck = {
  id: "stale-packages",
  severity: "warn",
  appliesWhen: ({ ctx }) => ctx.read(TECH_STACK) !== null && ctx.read("package.json") !== null,
  run: ({ ctx }) => {
    const doc = ctx.read(TECH_STACK) as string;
    const pkg = JSON.parse(ctx.read("package.json") as string) as {
      dependencies?: Record<string, string>;
      devDependencies?: Record<string, string>;
    };
    const declared = new Set([...Object.keys(pkg.dependencies ?? {}), ...Object.keys(pkg.devDependencies ?? {})]);
    const findings: CheckFinding[] = [];

    const { data, body } = parseFrontmatter({ text: doc });
    for (const line of body.split("\n")) {
      if (!line.startsWith("| ") && !line.startsWith("- ")) continue;
      for (const m of line.matchAll(/`(@?[a-z0-9][a-z0-9._/-]*)`/g)) {
        const name = m[1] as string;
        if (!declared.has(name)) {
          findings.push({
            message: `tech-stack.md lists \`${name}\` but package.json does not declare it`,
            hint: "update .agent/docs/product/tech-stack.md",
          });
        }
      }
    }

    const verifiedAt = data["verified_at"];
    if (typeof verifiedAt === "string" && ctx.headSha !== "" && verifiedAt !== ctx.headSha) {
      findings.push({
        level: "info",
        message: `tech-stack.md last verified at ${verifiedAt}`,
        hint: "review it, then update verified_at to the current sha",
      });
    }
    return findings;
  },
};
export default check;
