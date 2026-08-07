import { parse as parseYaml } from "yaml";
import type { DoctorCheck } from "../commands/doctor.ts";
import { P } from "../lib/paths.ts";

const INDEX = `${P.standards}/index.yml`;

/** Standards files missing from index.yml (or indexed files gone) → warn. */
const check: DoctorCheck = {
  id: "index-stale",
  severity: "warn",
  appliesWhen: ({ ctx }) => ctx.listFiles(P.standards).length > 0,
  run: ({ ctx }) => {
    const text = ctx.read(INDEX);
    if (text === null) {
      return [{ message: "docs/standards/index.yml is missing", hint: "harness index rebuild" }];
    }
    let parsed: Record<string, Record<string, unknown>>;
    try {
      parsed = (parseYaml(text) ?? {}) as Record<string, Record<string, unknown>>;
    } catch (e) {
      return [{ message: `index.yml unparseable — ${(e as Error).message}`, hint: "harness index rebuild" }];
    }

    const indexed = new Set<string>();
    for (const [group, entries] of Object.entries(parsed)) {
      if (typeof entries !== "object" || entries === null) continue;
      for (const key of Object.keys(entries)) {
        indexed.add(group === "root" ? `${key}.md` : `${group}/${key}.md`);
      }
    }

    const onDisk = ctx
      .listFiles(P.standards)
      .filter((f) => f.endsWith(".md"))
      .map((f) => f.slice(P.standards.length + 1));

    const findings = [];
    for (const file of onDisk) {
      if (!indexed.has(file)) {
        findings.push({ message: `${P.standards}/${file} not in index.yml`, hint: "harness index rebuild" });
      }
    }
    const onDiskSet = new Set(onDisk);
    for (const file of [...indexed].sort()) {
      if (!onDiskSet.has(file)) {
        findings.push({ message: `index.yml lists missing ${file.replace(/\.md$/, "")}`, hint: "harness index rebuild" });
      }
    }
    return findings;
  },
};
export default check;
