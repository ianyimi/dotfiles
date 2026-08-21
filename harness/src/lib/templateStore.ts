import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { HarnessError } from "./errors.ts";
import { walk } from "./fsx.ts";
import type { HarnessManifest } from "./manifest.ts";
import { harnessHome } from "./paths.ts";

/** On-disk schema of `<templates>/<name>/template.json`. */
export interface InitTemplate {
  schema_version: "1.0";
  /** kebab-case, equals its directory name. */
  name: string;
  /** UTC date (YYYY-MM-DD) from the injected clock at save time. */
  saved_at: string;
  /** git HEAD of the source project at save time; "" when unknown. */
  saved_at_sha: string;
  /** manifest.project of the source project. */
  source_project: string;
  /** CLI version that wrote the template. */
  harness_version: string;
  /**
   * Phase-keyed init data, mirroring 01's write-phase table minus project-specific fields
   * (D-07-2/D-07-3). Staged verbatim into .setup-progress.md by scaffold --template.
   */
  prefilled: {
    /** Never written by `template save`; hand-editable for org templates (D-07-2). */
    "2"?: { team: string };
    "3"?: { domains: string[] };
    /** DependencyPin minus version — versions re-resolve at init. */
    "6"?: { dependencies: Array<{ package: string; repo: string }> };
    "7"?: {
      workflow: HarnessManifest["workflow"];
      modules: HarnessManifest["modules"];
      platforms: HarnessManifest["platforms"];
    };
  };
}

/** Kebab-case template name guard (also blocks path traversal before any join). */
export const TEMPLATE_NAME_RE = /^[a-z0-9][a-z0-9-]*$/;

/**
 * Resolves a template's directory under the store. Validates the name FIRST.
 *
 * @param props.name - Template name.
 * @returns Absolute directory path `<harnessHome>/templates/<name>`.
 * @throws {HarnessError} code "template-name-invalid" when the name fails TEMPLATE_NAME_RE.
 */
export function templateDir(props: { name: string }): string {
  if (!TEMPLATE_NAME_RE.test(props.name)) {
    throw new HarnessError("template-name-invalid", `invalid template name "${props.name}" (want kebab-case)`);
  }
  return join(harnessHome(), "templates", props.name);
}

function invalid(name: string, detail: string): never {
  throw new HarnessError("template-invalid", `template "${name}": ${detail}`);
}

/**
 * Loads and validates one template.
 *
 * @param props.name - Template name.
 * @returns Parsed template plus its directory and seed inventories (root-relative sorted paths).
 * @throws {HarnessError} "template-not-found" when the dir or template.json is absent;
 *   "template-invalid" naming the offending key on schema violations.
 */
export function loadTemplate(props: { name: string }): {
  template: InitTemplate;
  dir: string;
  standardsSeed: string[];
  skillsSeed: string[];
} {
  const dir = templateDir({ name: props.name });
  const jsonPath = join(dir, "template.json");
  if (!existsSync(jsonPath)) {
    throw new HarnessError("template-not-found", `template "${props.name}" not found`, { hint: "harness template list" });
  }
  let value: unknown;
  try {
    value = JSON.parse(readFileSync(jsonPath, "utf8"));
  } catch (e) {
    invalid(props.name, `template.json is not valid JSON (${(e as Error).message})`);
  }
  const t = value as Record<string, unknown>;
  if (typeof t !== "object" || t === null) invalid(props.name, "template.json is not an object");
  if (t["schema_version"] !== "1.0") invalid(props.name, `unsupported schema_version ${JSON.stringify(t["schema_version"])}`);
  if (t["name"] !== props.name) invalid(props.name, `name mismatch (file says ${JSON.stringify(t["name"])})`);
  for (const key of ["saved_at", "saved_at_sha", "source_project", "harness_version"]) {
    if (typeof t[key] !== "string") invalid(props.name, `missing or non-string ${key}`);
  }
  const prefilled = (t["prefilled"] ?? {}) as Record<string, unknown>;
  if (typeof prefilled !== "object" || prefilled === null || Array.isArray(prefilled)) invalid(props.name, "prefilled must be an object");
  for (const key of Object.keys(prefilled)) {
    if (!["2", "3", "6", "7"].includes(key)) invalid(props.name, `prefilled phase ${key} is not allowed (only 2, 3, 6, 7)`);
  }
  const p3 = prefilled["3"] as { domains?: unknown } | undefined;
  if (p3 !== undefined && !Array.isArray(p3.domains)) invalid(props.name, "prefilled.3.domains must be a string[]");
  const p6 = prefilled["6"] as { dependencies?: unknown } | undefined;
  if (p6 !== undefined) {
    if (!Array.isArray(p6.dependencies)) invalid(props.name, "prefilled.6.dependencies must be an array");
    for (const dep of p6.dependencies as Array<Record<string, unknown>>) {
      if (typeof dep["package"] !== "string" || typeof dep["repo"] !== "string") {
        invalid(props.name, "prefilled.6 dependencies need package + repo");
      }
      if ("version" in dep) invalid(props.name, "dependency versions must not be templated");
    }
  }
  const p7 = prefilled["7"] as Record<string, unknown> | undefined;
  if (p7 !== undefined) {
    for (const key of ["workflow", "modules", "platforms"]) {
      if (typeof p7[key] !== "object" || p7[key] === null) invalid(props.name, `prefilled.7.${key} must be an object`);
    }
  }

  const standardsSeedDir = join(dir, "standards_seed");
  const skillsSeedDir = join(dir, "skills_seed");
  return {
    template: t as unknown as InitTemplate,
    dir,
    standardsSeed: existsSync(standardsSeedDir) ? walk({ root: standardsSeedDir }) : [],
    skillsSeed: existsSync(skillsSeedDir)
      ? readdirSync(skillsSeedDir, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort()
      : [],
  };
}

/**
 * Lists all templates in the store, sorted by name (determinism).
 *
 * @returns One entry per loadable template. Directories whose template.json is missing or
 *   invalid are returned with `invalid: true` (list must not crash on one bad entry).
 */
export function listTemplates(): Array<{
  name: string;
  saved_at: string;
  saved_at_sha: string;
  source_project: string;
  invalid?: boolean;
}> {
  const storeDir = join(harnessHome(), "templates");
  let entries: string[];
  try {
    entries = readdirSync(storeDir, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort();
  } catch {
    return [];
  }
  return entries.map((name) => {
    try {
      const { template } = loadTemplate({ name });
      return {
        name,
        saved_at: template.saved_at,
        saved_at_sha: template.saved_at_sha,
        source_project: template.source_project,
      };
    } catch {
      return { name, saved_at: "", saved_at_sha: "", source_project: "", invalid: true };
    }
  });
}
