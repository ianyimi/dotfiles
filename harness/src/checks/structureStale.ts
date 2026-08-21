import type { DoctorCheck } from "../commands/doctor.ts";
import { changedFilesSince } from "../lib/git.ts";
import { P } from "../lib/paths.ts";

const STRUCTURE = `${P.standards}/directory-structure.md`;

/** directory-structure.md generated at an older sha while the tree changed → info. */
const check: DoctorCheck = {
  id: "structure-stale",
  severity: "info",
  appliesWhen: ({ ctx }) => ctx.read(STRUCTURE) !== null && ctx.headSha !== "",
  run: ({ ctx }) => {
    const text = ctx.read(STRUCTURE) as string;
    const m = text.match(/\(SHA: ([0-9a-f]{7,40}|unknown)\)/);
    if (m === null) {
      return [{ message: "directory-structure.md has no SHA line", hint: "harness struct" }];
    }
    const recorded = m[1] as string;
    // The commit that records the struct output changes the tree by exactly this file —
    // exclude it, or every struct→commit cycle self-flags as stale forever.
    const stale =
      recorded === "unknown" ||
      (recorded !== ctx.headSha &&
        changedFilesSince({ root: ctx.root, sha: recorded }).filter((f) => f !== STRUCTURE).length > 0);
    if (!stale) return [];
    const short = recorded === "unknown" ? "unknown" : recorded.slice(0, 7);
    return [{ message: `directory-structure.md generated at ${short}, tree changed since`, hint: "harness struct" }];
  },
};
export default check;
