import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { EXIT } from "../lib/errors.ts";
import { walk } from "../lib/fsx.ts";
import { headSha } from "../lib/git.ts";
import { loadManifest, type HarnessManifest } from "../lib/manifest.ts";
import type { Reporter, ReportItem } from "../lib/output.ts";

/** Context handed to every check. Built once per doctor run. */
export interface CheckContext {
  root: string;
  manifest: HarnessManifest;
  headSha: string; // "" when unknown
  /** Lazy cached reader; null when the file is absent. */
  read: (relPath: string) => string | null;
  /** Recursive root-relative file listing under relDir; [] when absent. Sorted. */
  listFiles: (relDir: string) => string[];
}

/** A finding; level defaults to the check's severity but may be overridden per item. */
export type CheckFinding = Omit<ReportItem, "level"> & { level?: ReportItem["level"] };

export interface DoctorCheck {
  id: string; // e.g. "preferences-over-budget"
  severity: "error" | "warn" | "info";
  /**
   * Skip silently when false (e.g. module disabled).
   * @param props.ctx - Run context.
   * @returns Whether to run this check.
   */
  appliesWhen(props: { ctx: CheckContext }): boolean;
  /**
   * @param props.ctx - Run context.
   * @returns Findings; [] = pass (reported as one ✅ line).
   */
  run(props: { ctx: CheckContext }): CheckFinding[];
}

/**
 * Builds the shared check context with memoized file access.
 *
 * @param props.root - Project root.
 * @param props.manifest - Loaded manifest.
 * @returns The context passed to every check.
 */
export function buildCheckContext(props: { root: string; manifest: HarnessManifest }): CheckContext {
  const readCache = new Map<string, string | null>();
  const listCache = new Map<string, string[]>();
  return {
    root: props.root,
    manifest: props.manifest,
    headSha: headSha({ root: props.root }),
    read: (relPath) => {
      if (!readCache.has(relPath)) {
        try {
          readCache.set(relPath, readFileSync(join(props.root, relPath), "utf8"));
        } catch {
          readCache.set(relPath, null);
        }
      }
      return readCache.get(relPath) as string | null;
    },
    listFiles: (relDir) => {
      if (!listCache.has(relDir)) {
        const abs = join(props.root, relDir);
        if (!existsSync(abs)) {
          listCache.set(relDir, []);
        } else {
          listCache.set(relDir, walk({ root: abs }).map((f) => `${relDir}/${f}`));
        }
      }
      return listCache.get(relDir) as string[];
    },
  };
}

/**
 * Runs all registered checks honoring manifest.doctor.checks filtering.
 *
 * @param props.root - Project root.
 * @param props.checks - Registry (static import list; tests inject subsets).
 * @param props.reporter - Sink for results.
 * @returns EXIT.FINDINGS if any error-severity finding, else EXIT.OK.
 * @throws {HarnessError} "not-initialized" when .agent/manifest.json is missing.
 */
export function runDoctor(props: { root: string; checks: DoctorCheck[]; reporter: Reporter }): number {
  const { manifest, warnings } = loadManifest({ root: props.root });
  for (const w of warnings) props.reporter.warn(w, "manifest");

  const ctx = buildCheckContext({ root: props.root, manifest });

  const filter = manifest.doctor.checks;
  let checks = props.checks;
  if (filter !== undefined) {
    const known = new Set(props.checks.map((c) => c.id));
    for (const id of filter) {
      if (!known.has(id)) props.reporter.warn(`doctor.checks lists unknown check \`${id}\``, "doctor-config");
    }
    checks = props.checks.filter((c) => filter.includes(c.id));
  }

  for (const check of checks) {
    let applies: boolean;
    try {
      applies = check.appliesWhen({ ctx });
    } catch {
      applies = false;
    }
    if (!applies) continue;
    try {
      const findings = check.run({ ctx });
      if (findings.length === 0) {
        props.reporter.ok(check.id, check.id);
      } else {
        for (const f of findings) {
          const level = f.level ?? check.severity;
          props.reporter[level](f.message, f.id ?? check.id, f.hint);
        }
      }
    } catch (e) {
      props.reporter.error(`check ${check.id} crashed: ${(e as Error).message}`, check.id);
    }
  }

  return props.reporter.hasErrors() ? EXIT.FINDINGS : EXIT.OK;
}
