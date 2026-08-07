import type { HarnessManifest } from "../lib/manifest.ts";

/** Platform ids with a registered adapter. Widened as future adapters land. */
export const KNOWN_PLATFORM_IDS = ["omp", "claude"] as const;
export type PlatformId = (typeof KNOWN_PLATFORM_IDS)[number];

/** One context-injection rule from context-rules.yaml (master §7.2). */
export interface ContextRule {
  id: string;
  when: string[];
  inject: string[];
}

/** One discovered skill under .agent/skills/. */
export interface SkillInfo {
  name: string;
  /** Root-relative skill directory, e.g. ".agent/skills/dev-spec". */
  dir: string;
  frontmatter: Record<string, unknown>;
}

/** Everything an adapter's plan() may read. Built once per sync run. */
export interface ProjectContext {
  root: string;
  manifest: HarnessManifest;
  skills: SkillInfo[];
  /** Root-relative paths of every file under docs/standards/. */
  standardsFiles: string[];
  /** Parsed context rules, or null when context-rules.yaml is absent. */
  contextRules: ContextRule[] | null;
}

export interface BridgePlan {
  symlinks: Array<{ linkPath: string; targetPath: string }>; // both root-relative
  files: Array<{ path: string; content: string }>; // generated glue
  gitignoreLines: string[]; // e.g. ".omp/" unless commit_bridges
}

/** Everything `harness sync` needs to (re)generate one platform's bridge. */
export interface PlatformAdapter {
  id: PlatformId;
  /** Directory the bridge lives in, project-root-relative ("." + id by convention). */
  dir: string; // ".omp" | ".claude"
  /**
   * Computes the full desired bridge state from the .agent/ source. Pure — no I/O.
   *
   * @param props.ctx - Loaded project context.
   * @returns The complete plan: every symlink and generated file this platform wants.
   */
  plan(props: { ctx: ProjectContext }): BridgePlan;
}
