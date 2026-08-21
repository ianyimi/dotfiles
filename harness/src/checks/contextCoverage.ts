import { parse as parseYaml } from "yaml";
import type { DoctorCheck } from "../commands/doctor.ts";
import { walk } from "../lib/fsx.ts";
import { globMatch } from "../lib/glob.ts";
import { P } from "../lib/paths.ts";

const SOURCE_EXTENSIONS = new Set(["ts", "tsx", "js", "jsx", "py", "rs", "go", "java", "rb", "swift", "kt", "c", "h", "cpp"]);
const MIN_FILES = 5;

/** Top-level source directories no context rule covers → info (map holes made visible). */
const check: DoctorCheck = {
  id: "context-coverage",
  severity: "info",
  appliesWhen: ({ ctx }) => ctx.read(P.contextRules) !== null,
  run: ({ ctx }) => {
    let globs: string[];
    try {
      const parsed = parseYaml(ctx.read(P.contextRules) as string) as { rules?: Array<{ when?: string[] }> } | null;
      globs = (parsed?.rules ?? []).flatMap((r) => r.when ?? []);
    } catch {
      return [{ message: "context-rules.yaml unparseable", hint: "harness sync" }];
    }

    const byDir = new Map<string, string[]>();
    for (const file of walk({ root: ctx.root, prune: [".omp", ".claude", ".agent"] })) {
      if (!file.includes("/")) continue; // root files never form a coverage bucket
      const ext = file.split(".").pop() ?? "";
      if (!SOURCE_EXTENSIONS.has(ext)) continue;
      const dir = file.split("/")[0] as string;
      if (dir.startsWith(".")) continue;
      const bucket = byDir.get(dir) ?? [];
      bucket.push(file);
      byDir.set(dir, bucket);
    }

    const findings = [];
    for (const [dir, files] of [...byDir.entries()].sort(([a], [b]) => (a < b ? -1 : 1))) {
      if (files.length < MIN_FILES) continue;
      const covered = files.some((f) => globs.some((g) => globMatch({ pattern: g, path: f })));
      if (!covered) {
        findings.push({
          message: `${dir}/ (${files.length} source files) matches no context rule`,
          hint: "add applies_to globs to a standards doc covering it (see docs/harness-guide.md)",
        });
      }
    }
    return findings;
  },
};
export default check;
