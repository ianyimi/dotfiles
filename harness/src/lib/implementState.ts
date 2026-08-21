import { readFileSync } from "node:fs";
import { join } from "node:path";
import { writeFileAtomic } from "./fsx.ts";

export const IMPLEMENT_STATE_FILE = ".implement-state.json";

/** Resume + audit state for one spec's implementation loop. Committed with the spec dir. */
export interface ImplementState {
  version: 1;
  slug: string;
  updated: string; // ISO-8601; from props.now (injected clock, master §2.8)
  groups: Record<string, GroupState>; // key = group id ("T1")
}

export interface GroupState {
  attempts: number; // total `verify` invocations for this group
  last_result: "pass" | "fail" | null; // manual --confirmed records "pass"
  last_exit_code: number | null; // null for manual confirmation / never-run
  last_output_tail: string[]; // last ≤40 lines of combined stdout+stderr
  forced?: { reason: string; at: string }; // set by `done --force`
}

/**
 * Loads a spec's implement state, defaulting to an empty ledger when absent or unparseable
 * (the file is derived state — tolerance over failure).
 *
 * @param props.specDir - Absolute spec directory.
 * @param props.slug - Spec slug (used for the default).
 * @returns The implement state.
 */
export function loadImplementState(props: { specDir: string; slug: string }): ImplementState {
  try {
    return JSON.parse(readFileSync(join(props.specDir, IMPLEMENT_STATE_FILE), "utf8")) as ImplementState;
  } catch {
    return { version: 1, slug: props.slug, updated: "", groups: {} };
  }
}

/**
 * Saves the implement state atomically with sorted group keys and a trailing newline.
 *
 * @param props.specDir - Absolute spec directory.
 * @param props.state - State to write.
 * @returns Nothing.
 */
export function saveImplementState(props: { specDir: string; state: ImplementState }): void {
  const sortedGroups: Record<string, GroupState> = {};
  for (const key of Object.keys(props.state.groups).sort()) {
    sortedGroups[key] = props.state.groups[key] as GroupState;
  }
  const stable: ImplementState = {
    version: 1,
    slug: props.state.slug,
    updated: props.state.updated,
    groups: sortedGroups,
  };
  writeFileAtomic({
    path: join(props.specDir, IMPLEMENT_STATE_FILE),
    content: `${JSON.stringify(stable, null, 2)}\n`,
  });
}
