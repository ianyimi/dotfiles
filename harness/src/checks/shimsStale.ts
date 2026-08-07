import { existsSync, lstatSync } from "node:fs";
import { join } from "node:path";
import type { DoctorCheck } from "../commands/doctor.ts";
import { changedFilesSince, isRepo } from "../lib/git.ts";
import { P } from "../lib/paths.ts";
import type { SyncManifest } from "../lib/syncManifest.ts";

/** Bridges older than the last .agent/ change, or managed paths missing on disk → warn. */
const check: DoctorCheck = {
  id: "shims-stale",
  severity: "warn",
  appliesWhen: ({ ctx }) => {
    const raw = ctx.read(P.syncManifest);
    if (raw === null) return false;
    try {
      return (JSON.parse(raw) as SyncManifest).entries.length > 0 && isRepo({ root: ctx.root });
    } catch {
      return false;
    }
  },
  run: ({ ctx }) => {
    const sm = JSON.parse(ctx.read(P.syncManifest) as string) as SyncManifest;
    const findings = [];

    for (const entry of sm.entries) {
      if (entry.kind === "gitignore-line") {
        const gitignore = ctx.read(".gitignore") ?? "";
        if (!gitignore.split("\n").includes(entry.target_or_hash)) {
          findings.push({ message: `.gitignore is missing managed line ${entry.target_or_hash}`, hint: "harness sync" });
        }
        continue;
      }
      const abs = join(ctx.root, entry.path);
      let present: boolean;
      if (entry.kind === "symlink") {
        try {
          present = lstatSync(abs).isSymbolicLink();
        } catch {
          present = false;
        }
      } else {
        present = existsSync(abs);
      }
      if (!present) findings.push({ message: `${entry.path} is missing on disk`, hint: "harness sync" });
    }

    if (sm.generated_at_sha !== "") {
      const changed = changedFilesSince({ root: ctx.root, sha: sm.generated_at_sha }).filter(
        (f) => f.startsWith(".agent/") && f !== P.syncManifest && f !== P.state,
      );
      if (changed.length > 0) {
        findings.push({ message: `.agent/ changed since last sync (${changed.length} files)`, hint: "harness sync" });
      }
    }
    return findings;
  },
};
export default check;
