import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";
import { loadSyncManifest, saveSyncManifest } from "./syncManifest.ts";

describe("syncManifest", () => {
  test("defaults to empty ledger when absent", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    expect(loadSyncManifest({ root: dir })).toEqual({ version: 1, generated_at_sha: "", entries: [] });
    rmProject({ dir });
  });

  test("round-trips with entries sorted by path", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    saveSyncManifest({
      root: dir,
      syncManifest: {
        version: 1,
        generated_at_sha: "abc123",
        entries: [
          { path: ".omp/skills", kind: "symlink", target_or_hash: "../.agent/skills", platform: "omp" },
          { path: ".claude/CLAUDE.md", kind: "generated", target_or_hash: "deadbeef", platform: "claude" },
        ],
      },
    });
    const loaded = loadSyncManifest({ root: dir });
    expect(loaded.generated_at_sha).toBe("abc123");
    expect(loaded.entries.map((e) => e.path)).toEqual([".claude/CLAUDE.md", ".omp/skills"]);
    // Stable serialization: saving again produces identical bytes.
    const first = readFileSync(join(dir, ".agent", ".sync-manifest.json"), "utf8");
    saveSyncManifest({ root: dir, syncManifest: loaded });
    expect(readFileSync(join(dir, ".agent", ".sync-manifest.json"), "utf8")).toBe(first);
    rmProject({ dir });
  });
});
