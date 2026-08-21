import { readFileSync } from "node:fs";
import { join } from "node:path";
import { countLines } from "../checks/budget.ts";
import { HarnessError } from "../lib/errors.ts";
import { writeFileAtomic } from "../lib/fsx.ts";
import { loadManifest } from "../lib/manifest.ts";
import type { Reporter } from "../lib/output.ts";
import { P } from "../lib/paths.ts";

export interface PrefEntry {
  id: string;
  num: number;
  date: string;
  text: string;
  supersedes?: string;
}

const ENTRY_RE = /^- (P-\d{3,}) \((\d{4}-\d{2}-\d{2})\) (.+?)(?: \[supersedes (P-\d{3,})\])?$/;

/**
 * Parses preferences.md into header, entries, and tolerated unparsed lines (D02-3 grammar).
 * Unparsed lines are preserved verbatim at the end of the file — never dropped.
 *
 * @param props.text - preferences.md content.
 * @returns header (lines before the first entry), entries in file order, unparsed lines.
 */
export function parsePrefEntries(props: { text: string }): {
  header: string[];
  entries: PrefEntry[];
  unparsed: string[];
} {
  const header: string[] = [];
  const entries: PrefEntry[] = [];
  const unparsed: string[] = [];
  for (const line of props.text.split("\n")) {
    const m = line.match(ENTRY_RE);
    if (m !== null) {
      entries.push({
        id: m[1] as string,
        num: Number((m[1] as string).slice(2)),
        date: m[2] as string,
        text: m[3] as string,
        ...(m[4] !== undefined ? { supersedes: m[4] } : {}),
      });
    } else if (entries.length === 0) {
      header.push(line);
    } else if (line.trim() !== "") {
      unparsed.push(line);
    }
  }
  while (header.length > 0 && header[header.length - 1]?.trim() === "") header.pop();
  return { header, entries, unparsed };
}

function render(header: string[], entries: PrefEntry[], unparsed: string[]): string {
  const lines = [
    ...header,
    "",
    ...entries
      .slice()
      .sort((a, b) => a.num - b.num)
      .map((e) => `- ${e.id} (${e.date}) ${e.text}${e.supersedes !== undefined ? ` [supersedes ${e.supersedes}]` : ""}`),
  ];
  if (unparsed.length > 0) lines.push("", ...unparsed);
  return `${lines.join("\n")}\n`;
}

/**
 * Compacts preferences: apply supersedes, merge duplicates, then drop oldest until within
 * budget. Ids are never renumbered (D02-3).
 *
 * @param props.text - preferences.md content.
 * @param props.budget - Non-empty-line budget.
 * @returns New text plus the removal ledger (id + reason each).
 */
export function compactPrefs(props: { text: string; budget: number }): {
  text: string;
  removed: Array<{ id: string; reason: string }>;
} {
  const { header, entries, unparsed } = parsePrefEntries({ text: props.text });
  if (entries.length === 0) return { text: props.text, removed: [] };
  const removed: Array<{ id: string; reason: string }> = [];
  let live = [...entries];

  // 1. Supersedes: drop targets, strip the applied tag from survivors.
  const supersededBy = new Map<string, string>();
  for (const e of live) {
    if (e.supersedes !== undefined) supersededBy.set(e.supersedes, e.id);
  }
  live = live.filter((e) => {
    const by = supersededBy.get(e.id);
    if (by !== undefined) {
      removed.push({ id: e.id, reason: `superseded by ${by}` });
      return false;
    }
    return true;
  });
  live = live.map((e) => {
    if (e.supersedes !== undefined && supersededBy.get(e.supersedes) === e.id) {
      const { supersedes: _dropped, ...rest } = e;
      return rest;
    }
    return e;
  });

  // 2. Merge exact-duplicate text: keep the lowest id.
  const seen = new Map<string, PrefEntry>();
  const deduped: PrefEntry[] = [];
  for (const e of live.slice().sort((a, b) => a.num - b.num)) {
    const key = e.text.trim();
    const first = seen.get(key);
    if (first !== undefined) {
      removed.push({ id: e.id, reason: `duplicate of ${first.id}` });
    } else {
      seen.set(key, e);
      deduped.push(e);
    }
  }
  live = deduped;

  // 3. Drop oldest-dated (tie → lowest id) until within budget.
  while (live.length > 0 && countLines({ text: render(header, live, unparsed) }) > props.budget) {
    const oldest = live.reduce((a, b) => (b.date < a.date || (b.date === a.date && b.num < a.num) ? b : a));
    removed.push({ id: oldest.id, reason: "over budget (oldest)" });
    live = live.filter((e) => e.id !== oldest.id);
  }

  return { text: render(header, live, unparsed), removed };
}

/**
 * `harness pref compact [--budget n]` — compacts preferences.md and reports removals.
 *
 * @param props.root - Project root.
 * @param props.budget - Optional budget override (default: manifest budget).
 * @param props.reporter - Sink for removal report lines.
 * @returns EXIT.OK.
 */
export function prefCompact(props: { root: string; budget?: number; reporter: Reporter }): number {
  const { manifest } = loadManifest({ root: props.root });
  const budget = props.budget ?? manifest.doctor.budgets.preferences_lines;
  const path = join(props.root, P.standards, "preferences.md");
  let text: string;
  try {
    text = readFileSync(path, "utf8");
  } catch {
    props.reporter.info("no preferences.md — nothing to compact", "pref");
    return 0;
  }
  const { text: next, removed } = compactPrefs({ text, budget });
  if (next !== text) writeFileAtomic({ path, content: next });
  for (const r of removed) props.reporter.info(`removed ${r.id} (${r.reason})`, "pref");
  if (removed.length === 0) props.reporter.ok("nothing to remove", "pref");
  return 0;
}

/**
 * `harness pref remove <id>` — deletes exactly one entry line (rollback = git history, D02-3).
 *
 * @param props.root - Project root.
 * @param props.id - Entry id, e.g. "P-004".
 * @param props.reporter - Sink for the removal line.
 * @returns EXIT.OK.
 * @throws {HarnessError} "pref-not-found" when the id has no entry.
 */
export function prefRemove(props: { root: string; id: string; reporter: Reporter }): number {
  const path = join(props.root, P.standards, "preferences.md");
  let text: string;
  try {
    text = readFileSync(path, "utf8");
  } catch {
    throw new HarnessError("pref-not-found", "no preferences.md");
  }
  const lines = text.split("\n");
  const idx = lines.findIndex((l) => {
    const m = l.match(ENTRY_RE);
    return m !== null && m[1] === props.id;
  });
  if (idx === -1) throw new HarnessError("pref-not-found", `no preference entry ${props.id}`);
  lines.splice(idx, 1);
  writeFileAtomic({ path, content: lines.join("\n") });
  props.reporter.info(`removed ${props.id}`, "pref");
  return 0;
}
