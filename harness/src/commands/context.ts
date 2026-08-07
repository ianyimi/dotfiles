import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";
import type { ContextRule } from "../platforms/types.ts";
import { globMatch } from "../lib/glob.ts";
import type { Reporter } from "../lib/output.ts";
import { P } from "../lib/paths.ts";

/**
 * Matches context rules against a task description and file hints (master §7.2).
 *
 * @param props.rules - Parsed context rules.
 * @param props.task - Free-text task description.
 * @param props.files - Path/glob hints (already split by the caller).
 * @returns Deduped inject paths of matched rules, rule order preserved.
 */
export function matchContextRules(props: {
  rules: ContextRule[];
  task: string;
  files: string[];
}): string[] {
  const rawTokens = props.task.split(/\s+/).filter((t) => t !== "");
  const pathTokens = [
    ...props.files,
    ...rawTokens.filter((t) => t.includes("/") || t.includes(".")).map((t) => t.replace(/[,.;:]+$/, "")),
  ];
  const wordTokens = rawTokens.map((t) => t.toLowerCase().replaceAll(/[^a-z0-9-]/g, "")).filter((t) => t !== "");

  const out: string[] = [];
  for (const rule of props.rules) {
    const pathHit = pathTokens.some((p) => rule.when.some((w) => globMatch({ pattern: w, path: p })));
    const idSegments = rule.id.split("-");
    const wordHit = wordTokens.some((w) => w === rule.id || idSegments.includes(w));
    if (pathHit || wordHit) {
      for (const inject of rule.inject) {
        if (!out.includes(inject)) out.push(inject);
      }
    }
  }
  return out;
}

/** Loads context-rules.yaml; null when absent. */
function loadContextRules(root: string): ContextRule[] | null {
  const path = join(root, P.contextRules);
  if (!existsSync(path)) return null;
  const parsed = parseYaml(readFileSync(path, "utf8")) as { rules?: ContextRule[] } | null;
  return parsed?.rules ?? [];
}

/**
 * Loads context-rules.yaml and matches in one call (contract C-05c — 05's `implement next`
 * imports this).
 *
 * @param props.root - Project root.
 * @param props.task - Task description.
 * @param props.files - Optional path/glob hints.
 * @returns Root-relative inject paths; [] when the rules file is absent or nothing matches.
 */
export function contextFilesFor(props: { root: string; task: string; files?: string[] }): string[] {
  const rules = loadContextRules(props.root);
  if (rules === null) return [];
  return matchContextRules({ rules, task: props.task, files: props.files ?? [] });
}

/**
 * `harness context --for "<task>" [--files a,b]` — prints matched inject paths, one per line.
 *
 * @param props.root - Project root.
 * @param props.task - Task description.
 * @param props.files - Comma-separated file hints (raw option value).
 * @param props.stdout - Line sink for inject paths.
 * @param props.reporter - Stderr reporter for missing-file warnings.
 * @returns EXIT.OK always (degrades gracefully — 04 owns generation).
 */
export function contextCommand(props: {
  root: string;
  task: string;
  files?: string;
  stdout: (s: string) => void;
  reporter: Reporter;
}): number {
  const rules = loadContextRules(props.root);
  if (rules === null) {
    props.stdout("(no context rules — run harness sync)");
    return 0;
  }
  const files = (props.files ?? "").split(",").map((f) => f.trim()).filter((f) => f !== "");
  const matched = matchContextRules({ rules, task: props.task, files });
  if (matched.length === 0) {
    props.stdout("(no matching context rules)");
    return 0;
  }
  for (const path of matched) {
    if (!existsSync(join(props.root, ".agent", path)) && !existsSync(join(props.root, path))) {
      props.reporter.warn(`${path} does not exist on disk`, "context");
    }
    props.stdout(path);
  }
  return 0;
}
