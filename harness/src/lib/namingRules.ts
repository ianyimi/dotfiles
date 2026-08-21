import { parse as parseYaml } from "yaml";
import { HarnessError } from "./errors.ts";
import { globMatch } from "./glob.ts";

/** One machine-readable naming rule (master §7.4 / proposal §18.6). */
export interface NamingRule {
  id: string;
  /** Regex tested against the file BASENAME only. */
  pattern: string;
  /** Globs tested against the root-relative path. */
  scope: string[];
  description: string;
  examples?: string[];
  counter_examples?: string[];
}

/**
 * Extracts and parses the fenced ```yaml block containing top-level `rules:` from
 * naming-conventions.md. Prose sections are never machine-parsed (master §7.4).
 *
 * @param props.text - Full naming-conventions.md content.
 * @returns Rules in file order.
 * @throws {HarnessError} code "naming-rules-invalid" — no ```yaml fence with a top-level
 *   `rules:` array; YAML parse failure; rule missing id/pattern/scope/description;
 *   pattern not a valid RegExp.
 */
export function parseNamingRules(props: { text: string }): NamingRule[] {
  const text = props.text.replaceAll("\r\n", "\n");
  const fenceRe = /^```yaml\n([\s\S]*?)^```/gm;
  let rulesValue: unknown = null;
  for (const m of text.matchAll(fenceRe)) {
    let parsed: unknown;
    try {
      parsed = parseYaml(m[1] as string);
    } catch (e) {
      throw new HarnessError("naming-rules-invalid", `naming-conventions.md: yaml parse failure — ${(e as Error).message}`);
    }
    if (typeof parsed === "object" && parsed !== null && Array.isArray((parsed as Record<string, unknown>)["rules"])) {
      rulesValue = (parsed as Record<string, unknown>)["rules"];
      break;
    }
  }
  if (rulesValue === null) {
    throw new HarnessError("naming-rules-invalid", "naming-conventions.md: no rules block found (expected a ```yaml fence with a top-level `rules:` array)");
  }

  const rules: NamingRule[] = [];
  for (const [i, raw] of (rulesValue as unknown[]).entries()) {
    const r = raw as Record<string, unknown>;
    const label = typeof r?.["id"] === "string" ? (r["id"] as string) : `#${i}`;
    if (typeof r?.["id"] !== "string" || typeof r["pattern"] !== "string" || typeof r["description"] !== "string") {
      throw new HarnessError("naming-rules-invalid", `naming-conventions.md: rule ${label} is missing id/pattern/description`);
    }
    const scope = r["scope"];
    if (!Array.isArray(scope) || scope.length === 0 || !scope.every((s) => typeof s === "string")) {
      throw new HarnessError("naming-rules-invalid", `naming-conventions.md: rule ${label} needs a non-empty string[] scope`);
    }
    try {
      new RegExp(r["pattern"] as string);
    } catch (e) {
      throw new HarnessError("naming-rules-invalid", `naming-conventions.md: rule ${label} has an invalid pattern regex — ${(e as Error).message}`);
    }
    rules.push({
      id: r["id"] as string,
      pattern: r["pattern"] as string,
      scope: scope as string[],
      description: r["description"] as string,
      ...(Array.isArray(r["examples"]) ? { examples: r["examples"] as string[] } : {}),
      ...(Array.isArray(r["counter_examples"]) ? { counter_examples: r["counter_examples"] as string[] } : {}),
    });
  }
  return rules;
}

/**
 * Checks one path. In-scope when ≥1 rule's scope glob matches the path; compliant when
 * AT LEAST ONE in-scope rule's regex accepts the BASENAME (lets a broad rule like
 * test-files coexist with per-dir rules).
 *
 * @param props.path - Root-relative POSIX path.
 * @param props.rules - Parsed rules.
 * @returns matched = in-scope rule ids in rule order ([] = not governed → ok);
 *   ok = compliant; when !ok, matched[0] is the rule to report.
 */
export function checkPath(props: { path: string; rules: NamingRule[] }): {
  matched: string[];
  ok: boolean;
} {
  const basename = props.path.split("/").pop() as string;
  const matched: string[] = [];
  let ok = false;
  for (const rule of props.rules) {
    if (rule.scope.some((s) => globMatch({ pattern: s, path: props.path }))) {
      matched.push(rule.id);
      if (new RegExp(rule.pattern).test(basename)) ok = true;
    }
  }
  return { matched, ok: matched.length === 0 ? true : ok };
}
