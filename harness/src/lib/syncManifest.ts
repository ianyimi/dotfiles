import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { PlatformId } from "../platforms/types.ts";
import { writeFileAtomic } from "./fsx.ts";
import { P } from "./paths.ts";

/** Ledger of every path a `harness sync` run owns. Enables safe regen + cleanup (D10). */
export interface SyncManifest {
  version: 1;
  generated_at_sha: string; // git HEAD when last synced ("" if no repo)
  entries: SyncEntry[];
}

export interface SyncEntry {
  path: string; // project-root-relative, e.g. ".claude/CLAUDE.md"
  kind: "symlink" | "generated" | "gitignore-line";
  /** For symlink: the link target. For generated: sha256 of written content. */
  target_or_hash: string;
  platform: PlatformId | "core";
}

/**
 * Loads .agent/.sync-manifest.json, defaulting to an empty ledger when absent.
 *
 * @param props.root - Project root.
 * @returns The sync manifest (never throws on absence).
 */
export function loadSyncManifest(props: { root: string }): SyncManifest {
  try {
    const text = readFileSync(join(props.root, P.syncManifest), "utf8");
    return JSON.parse(text) as SyncManifest;
  } catch {
    return { version: 1, generated_at_sha: "", entries: [] };
  }
}

/**
 * Saves the sync manifest atomically with stable key order and path-sorted entries.
 *
 * @param props.root - Project root.
 * @param props.syncManifest - Ledger to write.
 * @returns Nothing.
 */
export function saveSyncManifest(props: { root: string; syncManifest: SyncManifest }): void {
  const stable: SyncManifest = {
    version: 1,
    generated_at_sha: props.syncManifest.generated_at_sha,
    entries: [...props.syncManifest.entries]
      .sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0))
      .map((e) => ({ path: e.path, kind: e.kind, target_or_hash: e.target_or_hash, platform: e.platform })),
  };
  writeFileAtomic({
    path: join(props.root, P.syncManifest),
    content: `${JSON.stringify(stable, null, 2)}\n`,
  });
}
