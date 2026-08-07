import { parse as parseYaml } from "yaml";
import type { DoctorCheck } from "../commands/doctor.ts";
import { parseFrontmatter } from "../lib/frontmatter.ts";
import { P } from "../lib/paths.ts";

/** context-rules.yaml rule ids out of sync with their standards/naming sources → warn. */
const check: DoctorCheck = {
  id: "context-rules-stale",
  severity: "warn",
  // Only meaningful after a first sync — a never-synced project has no drift to report.
  appliesWhen: ({ ctx }) => ctx.read(P.contextRules) !== null || ctx.read(P.syncManifest) !== null,
  run: ({ ctx }) => {
    const expected = new Set<string>();
    for (const domain of ctx.manifest.standards_domains) {
      const domainFiles = ctx
        .listFiles(P.standards)
        .filter((f) => f.startsWith(`${P.standards}/${domain}/`) && f.endsWith(".md"));
      const hasApplies = domainFiles.some((f) => {
        const text = ctx.read(f);
        if (text === null) return false;
        const appliesTo = parseFrontmatter({ text }).data["applies_to"];
        return Array.isArray(appliesTo) && appliesTo.length > 0;
      });
      if (hasApplies) expected.add(`std-${domain}`);
    }
    if (ctx.manifest.modules.naming_conventions && ctx.read(`${P.standards}/naming-conventions.md`) !== null) {
      expected.add("naming");
    }

    let actual = new Set<string>();
    const rulesText = ctx.read(P.contextRules);
    if (rulesText !== null) {
      try {
        const parsed = parseYaml(rulesText) as { rules?: Array<{ id: string }> } | null;
        actual = new Set((parsed?.rules ?? []).map((r) => r.id));
      } catch {
        return [{ message: "context-rules.yaml unparseable", hint: "harness sync" }];
      }
    }

    const findings = [];
    for (const id of [...expected].sort()) {
      if (!actual.has(id)) findings.push({ message: `rule ${id} missing from context-rules.yaml`, hint: "harness sync" });
    }
    for (const id of [...actual].sort()) {
      if (!expected.has(id)) findings.push({ message: `rule ${id} is stale (source gone)`, hint: "harness sync" });
    }
    return findings;
  },
};
export default check;
