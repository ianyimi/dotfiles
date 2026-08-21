import { readFileSync } from "node:fs";
import { join } from "node:path";
import { KNOWN_PLATFORM_IDS, type PlatformId } from "../platforms/types.ts";
import { HarnessError } from "./errors.ts";
import { writeFileAtomic } from "./fsx.ts";
import { P } from "./paths.ts";

/** Root manifest of a harness-initialized project. Committed at .agent/manifest.json. */
export interface HarnessManifest {
  schema_version: "1.0";
  project: string;
  description: string;
  harness: {
    base_version: string;
    template?: string;
  };
  platforms: {
    /** Bridge targets managed by `harness sync`. Order = generation order. */
    active: PlatformId[];
    /** Commit generated bridge dirs instead of gitignoring them (D9). Default false. */
    commit_bridges?: boolean;
  };
  workflow: {
    default_tier: "high-care" | "low-care";
    importance: "high" | "medium" | "low";
    developer_implements: boolean;
    post_implement_polish: boolean;
    commit_mode: "message-only" | "agent-commits";
    agent_can_edit?: string[];
    agent_needs_approval?: string[];
  };
  modules: {
    specs: boolean;
    tasks: boolean;
    session_log: boolean;
    roadmap: boolean;
    design: boolean;
    decisions: boolean;
    research: boolean;
    env_manifest: boolean;
    naming_conventions: boolean;
  };
  standards_domains: string[];
  /** Model economy (09 live-test additions): how agents pick model tiers. */
  models: {
    /** "dynamic": the spec author assigns the cheapest adequate tier per subagent task;
     *  "uniform": every subagent inherits the session model. */
    subagent_selection: "dynamic" | "uniform";
    /** Enable the harness-keeper advisor (OMP-native WATCHDOG; cheap watcher model). */
    advisor: boolean;
    /** Tier hints agents cite when requesting models. OMP: role selectors; else labels. */
    tiers: { frontier: string; standard: string; cheap: string };
  };
  dependencies: DependencyPin[];
  doctor: {
    checks?: string[];
    budgets: {
      preferences_lines: number;
      anti_patterns_lines: number;
      skill_lines: number;
      agents_md_directives_lines: number;
    };
    stale_spec_days: number;
  };
  repo?: {
    type: "standard" | "bare-git-worktrees";
    worktrees?: Record<string, { path: string; branch: string; readonly?: boolean }>;
  };
}

export interface DependencyPin {
  package: string;
  version: string;
  repo: string;
}

export const DEFAULT_BUDGETS = {
  preferences_lines: 80,
  anti_patterns_lines: 40,
  skill_lines: 150,
  agents_md_directives_lines: 20,
} as const;

export const DEFAULT_MODELS = {
  subagent_selection: "dynamic",
  advisor: true,
  // Concrete catalog ids (Anthropic-first defaults) — sync maps them onto OMP's model roles
  // so subagents/advisor genuinely run cheaper models. "@role" values skip the mapping and
  // leave that role to the platform's own configuration. Uncredentialed models fall back to
  // the parent model inside OMP, so a wrong id degrades gracefully, never breaks.
  tiers: {
    frontier: "anthropic/claude-fable-5",
    standard: "anthropic/claude-sonnet-5",
    cheap: "anthropic/claude-haiku-4-5",
  },
} as const;

const REQUIRED_KEYS = [
  "schema_version",
  "project",
  "description",
  "harness",
  "platforms",
  "workflow",
  "modules",
  "standards_domains",
  "dependencies",
  "doctor",
] as const;

function invalid(path: string, detail?: string): never {
  throw new HarnessError(
    "manifest-invalid",
    `manifest.json: ${detail !== undefined ? detail : `missing ${path}`}`,
  );
}

/**
 * Validates an unknown value as a HarnessManifest, filling defaults.
 *
 * @param props.value - Parsed JSON value.
 * @returns The validated manifest (unknown top-level keys kept) plus warnings for them.
 * @throws {HarnessError} code "manifest-invalid" naming the offending JSON path.
 */
export function validateManifest(props: { value: unknown }): {
  manifest: HarnessManifest;
  warnings: string[];
} {
  const v = props.value;
  if (typeof v !== "object" || v === null || Array.isArray(v)) invalid("", "not an object");
  const obj = v as Record<string, unknown>;

  for (const key of REQUIRED_KEYS) {
    if (!(key in obj)) invalid(key);
  }
  if (obj["schema_version"] !== "1.0") {
    invalid("schema_version", `unsupported schema_version ${JSON.stringify(obj["schema_version"])} (expected "1.0")`);
  }
  if (typeof obj["project"] !== "string" || obj["project"] === "") invalid("project", "project must be a non-empty string");
  if (typeof obj["description"] !== "string") invalid("description", "description must be a string");

  const harness = obj["harness"] as Record<string, unknown>;
  if (typeof harness !== "object" || harness === null || typeof harness["base_version"] !== "string") {
    invalid("harness.base_version");
  }

  const platforms = obj["platforms"] as Record<string, unknown>;
  if (typeof platforms !== "object" || platforms === null || !Array.isArray(platforms["active"])) {
    invalid("platforms.active");
  }
  for (const id of platforms["active"] as unknown[]) {
    if (!KNOWN_PLATFORM_IDS.includes(id as PlatformId)) {
      invalid("platforms.active", `unknown platform id ${JSON.stringify(id)} (known: ${KNOWN_PLATFORM_IDS.join(", ")})`);
    }
  }

  const workflow = obj["workflow"] as Record<string, unknown>;
  if (typeof workflow !== "object" || workflow === null) invalid("workflow");
  if (workflow["commit_mode"] === undefined) workflow["commit_mode"] = "message-only";
  if (workflow["commit_mode"] !== "message-only" && workflow["commit_mode"] !== "agent-commits") {
    invalid("workflow.commit_mode", `commit_mode must be "message-only" or "agent-commits"`);
  }

  const modules = obj["modules"] as Record<string, unknown>;
  if (typeof modules !== "object" || modules === null) invalid("modules");
  if (!Array.isArray(obj["standards_domains"])) invalid("standards_domains");

  if (!Array.isArray(obj["dependencies"])) invalid("dependencies");
  for (const [i, dep] of (obj["dependencies"] as unknown[]).entries()) {
    const d = dep as Record<string, unknown>;
    if (typeof d !== "object" || d === null || typeof d["package"] !== "string") invalid(`dependencies[${i}].package`);
    if (typeof d["version"] !== "string") invalid(`dependencies[${i}].version`);
    if (typeof d["repo"] !== "string" || d["repo"] === "") {
      invalid(`dependencies[${i}].repo`, `dependencies[${i}] (${d["package"] as string}) is missing repo — deps clone needs it`);
    }
  }

  const doctor = obj["doctor"] as Record<string, unknown>;
  if (typeof doctor !== "object" || doctor === null) invalid("doctor");
  const budgets = (doctor["budgets"] ?? {}) as Record<string, unknown>;
  doctor["budgets"] = { ...DEFAULT_BUDGETS, ...budgets };
  if (typeof doctor["stale_spec_days"] !== "number") doctor["stale_spec_days"] = 14;

  // models is optional pre-09 — fill every missing piece from the defaults.
  const models = (obj["models"] ?? {}) as Record<string, unknown>;
  if (typeof models !== "object" || models === null || Array.isArray(models)) invalid("models", "models must be an object");
  if (models["subagent_selection"] === undefined) models["subagent_selection"] = DEFAULT_MODELS.subagent_selection;
  if (models["subagent_selection"] !== "dynamic" && models["subagent_selection"] !== "uniform") {
    invalid("models.subagent_selection", `models.subagent_selection must be "dynamic" or "uniform"`);
  }
  if (typeof models["advisor"] !== "boolean") models["advisor"] = DEFAULT_MODELS.advisor;
  const tiers = { ...DEFAULT_MODELS.tiers, ...((models["tiers"] ?? {}) as Record<string, unknown>) } as Record<string, string>;
  // Migrate the pre-2026-08-08 role-ref defaults: they were never a deliberate choice, and
  // "@role" values suppress the modelRoles emission → subagents/advisor silently run the
  // session model. Deliberate @-refs to OTHER roles are left alone.
  const LEGACY_TIER_DEFAULTS: Record<string, string> = { frontier: "@slow", standard: "@default", cheap: "@smol" };
  for (const key of Object.keys(LEGACY_TIER_DEFAULTS)) {
    if (tiers[key] === LEGACY_TIER_DEFAULTS[key]) tiers[key] = DEFAULT_MODELS.tiers[key as keyof typeof DEFAULT_MODELS.tiers];
  }
  models["tiers"] = tiers;
  obj["models"] = models;

  const knownKeys = new Set<string>([...REQUIRED_KEYS, "repo", "models"]);
  const warnings = Object.keys(obj)
    .filter((k) => !knownKeys.has(k))
    .map((k) => `manifest.json: unknown key \`${k}\` — kept`);

  return { manifest: obj as unknown as HarnessManifest, warnings };
}

/**
 * Loads and validates .agent/manifest.json.
 *
 * @param props.root - Project root.
 * @returns Validated manifest + warnings.
 * @throws {HarnessError} "not-initialized" when the file is missing; "manifest-invalid" on bad content.
 */
export function loadManifest(props: { root: string }): { manifest: HarnessManifest; warnings: string[] } {
  let text: string;
  try {
    text = readFileSync(join(props.root, P.manifest), "utf8");
  } catch {
    throw new HarnessError("not-initialized", "No .agent/manifest.json — the harness is not initialized", {
      hint: "harness install, then run the init skill (/harness-init)",
    });
  }
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch (e) {
    throw new HarnessError("manifest-invalid", `manifest.json: invalid JSON (${(e as Error).message})`);
  }
  return validateManifest({ value });
}

/**
 * Saves a manifest atomically with stable 2-space formatting and trailing newline.
 *
 * @param props.root - Project root.
 * @param props.manifest - Manifest to write (unknown keys preserved).
 * @returns Nothing.
 */
export function saveManifest(props: { root: string; manifest: HarnessManifest }): void {
  writeFileAtomic({
    path: join(props.root, P.manifest),
    content: `${JSON.stringify(props.manifest, null, 2)}\n`,
  });
}
