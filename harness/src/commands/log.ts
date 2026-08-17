import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";
import { HarnessError } from "../lib/errors.ts";
import { writeFileAtomic } from "../lib/fsx.ts";
import { changedFilesSince, uncommittedFiles } from "../lib/git.ts";
import { P } from "../lib/paths.ts";

/** Fixed entry skeleton ({date}/{time}/{slug} substituted); structure per proposal §12. */
export const ENTRY_TEMPLATE = `## {date} — {time} — {slug}

**Spec:** (none)
**Commit:** (pending)

### What was built

### Decisions made

### Problems hit

### Where I left off
`;

/** Marker appended by session-end; doubles as its idempotence guard. */
export const SESSION_END_MARKER =
  "_Session end — fill in: current state · next step · watch-outs._";

/** Questions session-end prints for the commit skill — the AGENT answers them from the diff
 * and its own session context; they are never relayed to the developer. */
export const SESSION_END_QUESTIONS = [
  "1. What was built this session?",
  "2. Any decisions that deviated from the spec — and why?",
  "3. Any problems hit, and how were they resolved?",
  "4. Where does the session leave off? (current state, next step, watch-outs)",
];

const ENTRY_HEADING_RE = /^## \d{4}-\d{2}-\d{2} — /m;

export interface LogDate {
  date: string; // "YYYY-MM-DD"
  time: string; // "HH:MM"
}

/**
 * Resolves the effective log date/time from the system wall clock — the source of truth for
 * "now". An explicit --date override wins (tests only); HEAD's commit time is never consulted.
 *
 * @param props.root - Project root.
 * @param props.dateOpt - Raw --date value, if given.
 * @returns date + time.
 * @throws {HarnessError} code "bad-date" on malformed --date.
 */
export function resolveLogDate(props: { root: string; dateOpt?: string }): LogDate {
  if (props.dateOpt !== undefined) {
    const m = props.dateOpt.match(/^(\d{4}-\d{2}-\d{2})(T(\d{2}:\d{2}))?$/);
    if (m === null) {
      throw new HarnessError("bad-date", `invalid --date "${props.dateOpt}" (want YYYY-MM-DD or YYYY-MM-DDTHH:MM)`);
    }
    return { date: m[1] as string, time: m[3] ?? "00:00" };
  }
  // The system wall clock is the source of truth for "now". (This previously preferred HEAD's
  // commit time, which stranded every session on a stale date until the day's first commit.)
  const now = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  return {
    date: `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`,
    time: `${pad(now.getHours())}:${pad(now.getMinutes())}`,
  };
}

/**
 * Root-relative log path for a date.
 *
 * @param props.date - "YYYY-MM-DD".
 * @returns e.g. ".agent/docs/session-log/2026/08/2026-08-02.log.md".
 */
export function logPathFor(props: { date: string }): string {
  return join(P.sessionLog, props.date.slice(0, 4), props.date.slice(5, 7), `${props.date}.log.md`);
}

/**
 * Appends a new entry skeleton to today's log (creates file + dirs on first entry of the day).
 * The append uses appendFileSync — the one non-atomic write; an atomic rewrite would violate
 * append-only for concurrent readers.
 *
 * @param props.root - Project root.
 * @param props.slug - Entry slug; default "session".
 * @param props.dateOpt - Raw --date.
 * @param props.stdout - Line sink.
 * @returns The root-relative log path (also printed).
 * @throws {HarnessError} "usage" when the slug spans multiple lines.
 */
export function logAppend(props: {
  root: string;
  slug?: string;
  dateOpt?: string;
  stdout: (s: string) => void;
}): string {
  const slug = props.slug ?? "session";
  if (slug.includes("\n")) throw new HarnessError("usage", "slug must be a single line");
  const d = resolveLogDate({ root: props.root, dateOpt: props.dateOpt });
  const rel = logPathFor({ date: d.date });
  const abs = join(props.root, rel);
  const entry = ENTRY_TEMPLATE.replace("{date}", d.date).replace("{time}", d.time).replace("{slug}", slug);
  if (!existsSync(abs)) {
    writeFileAtomic({ path: abs, content: `# Session Log — ${d.date}\n\n${entry}` });
  } else {
    const existing = readFileSync(abs, "utf8");
    appendFileSync(abs, `${existing.endsWith("\n") ? "\n" : "\n\n"}${entry}`);
  }
  props.stdout(rel);
  return rel;
}

/**
 * Appends one bullet line under today's latest entry (consumed by 05's `implement done` —
 * always called as a function, never via the CLI). Creates the file and a "session" entry
 * first when today has none. End-of-file IS the latest entry (append-only discipline).
 *
 * @param props.root - Project root.
 * @param props.line - Single-line text; written as `- <line>` at the end of today's entry.
 * @param props.dateOpt - Raw --date injection for tests.
 * @returns Nothing.
 * @throws {HarnessError} code "usage" when props.line contains a newline.
 */
export function appendLogLine(props: { root: string; line: string; dateOpt?: string }): void {
  if (props.line.includes("\n")) throw new HarnessError("usage", "log line must be a single line");
  const d = resolveLogDate({ root: props.root, dateOpt: props.dateOpt });
  const abs = join(props.root, logPathFor({ date: d.date }));
  if (!existsSync(abs) || !ENTRY_HEADING_RE.test(readFileSync(abs, "utf8"))) {
    logAppend({ root: props.root, slug: "session", ...(props.dateOpt !== undefined ? { dateOpt: props.dateOpt } : {}), stdout: () => {} });
  }
  const text = readFileSync(abs, "utf8");
  appendFileSync(abs, `${text.endsWith("\n") ? "" : "\n"}- ${props.line}\n`);
}

/**
 * Ensures today's entry exists, then appends the SESSION_END_MARKER prompt-block at EOF —
 * landing inside the latest entry's "### Where I left off" section (always the file's last
 * section). Prints the questions the invoking agent must answer itself, then the answer path.
 *
 * @param props.root - Project root.
 * @param props.dateOpt - Raw --date.
 * @param props.stdout - Line sink.
 * @returns The root-relative log path.
 */
export function logSessionEnd(props: {
  root: string;
  dateOpt?: string;
  stdout: (s: string) => void;
}): string {
  const d = resolveLogDate({ root: props.root, dateOpt: props.dateOpt });
  const rel = logPathFor({ date: d.date });
  const abs = join(props.root, rel);
  if (!existsSync(abs) || !ENTRY_HEADING_RE.test(readFileSync(abs, "utf8"))) {
    logAppend({ root: props.root, slug: "session", ...(props.dateOpt !== undefined ? { dateOpt: props.dateOpt } : {}), stdout: () => {} });
  }
  const text = readFileSync(abs, "utf8");
  const headings = [...text.matchAll(/^## \d{4}-\d{2}-\d{2} — /gm)];
  const lastHeadingIdx = headings.length > 0 ? (headings[headings.length - 1] as RegExpMatchArray).index ?? 0 : 0;
  const latestEntry = text.slice(lastHeadingIdx);
  if (!latestEntry.includes(SESSION_END_MARKER)) {
    appendFileSync(abs, `${text.endsWith("\n") ? "" : "\n"}\n${SESSION_END_MARKER}\n`);
  }
  props.stdout("Ask the developer:");
  for (const q of SESSION_END_QUESTIONS) props.stdout(`  ${q}`);
  props.stdout(`Answer these yourself from git status/diff and the session context — do not ask the developer. Write the answers into: ${rel}`);
  return rel;
}

/**
 * Replaces the LAST "**Commit:** (pending)" in today's log with "**Commit:** <sha>" — the one
 * sanctioned in-place edit of a log file (D7 agent-commits mode).
 *
 * @param props.root - Project root.
 * @param props.sha - Commit SHA (7–40 hex chars), written verbatim, never shortened.
 * @param props.dateOpt - Raw --date.
 * @param props.stdout - Line sink.
 * @returns Nothing.
 * @throws {HarnessError} "usage" bad sha · "no-log-entry" file missing · "no-pending-commit"
 *   nothing to fill.
 */
export function logBackfillSha(props: {
  root: string;
  sha: string;
  dateOpt?: string;
  stdout: (s: string) => void;
}): void {
  if (!/^[0-9a-f]{7,40}$/i.test(props.sha)) {
    throw new HarnessError("usage", `invalid --sha "${props.sha}" (want 7–40 hex chars)`);
  }
  const d = resolveLogDate({ root: props.root, dateOpt: props.dateOpt });
  const rel = logPathFor({ date: d.date });
  const abs = join(props.root, rel);
  if (!existsSync(abs)) {
    throw new HarnessError("no-log-entry", `no session log for ${d.date}`, { hint: "harness log append" });
  }
  const text = readFileSync(abs, "utf8");
  const needle = "**Commit:** (pending)";
  const i = text.lastIndexOf(needle);
  if (i < 0) {
    throw new HarnessError("no-pending-commit", "no pending commit field to fill", {
      hint: "already backfilled? check the entry",
    });
  }
  writeFileAtomic({
    path: abs,
    content: `${text.slice(0, i)}**Commit:** ${props.sha}${text.slice(i + needle.length)}`,
  });
  props.stdout(rel);
}

/**
 * Bullet lines (`- …`, verbatim) between `### <heading>` and the next `###`/`##`/EOF.
 *
 * @param props.entryBody - The entry text (from its `## ` heading onward).
 * @param props.heading - Section name, e.g. "What was built".
 * @returns Verbatim bullet lines; [] when the section is absent or empty.
 */
export function sectionBullets(props: { entryBody: string; heading: string }): string[] {
  const lines = props.entryBody.split("\n");
  const start = lines.findIndex((l) => l.trim() === `### ${props.heading}`);
  if (start === -1) return [];
  const out: string[] = [];
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i] as string;
    if (line.startsWith("### ") || line.startsWith("## ")) break;
    if (line.startsWith("- ")) out.push(line);
  }
  return out;
}

/**
 * Infers a commit scope from changed paths matched against workspace package globs.
 * Deterministic: no package.json reads — the candidate is the directory segment after the
 * glob prefix.
 *
 * @param props.root - Project root.
 * @param props.changedPaths - Root-relative changed files.
 * @returns Package dir basename (e.g. "core") or null (emit unscoped "type: desc").
 */
export function inferScope(props: { root: string; changedPaths: string[] }): string | null {
  let globs: string[] = [];
  const wsYaml = join(props.root, "pnpm-workspace.yaml");
  if (existsSync(wsYaml)) {
    const parsed = parseYaml(readFileSync(wsYaml, "utf8")) as { packages?: string[] } | null;
    if (Array.isArray(parsed?.packages)) globs = parsed.packages;
  } else {
    const pkgPath = join(props.root, "package.json");
    if (existsSync(pkgPath)) {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf8")) as {
        workspaces?: string[] | { packages?: string[] };
      };
      if (Array.isArray(pkg.workspaces)) globs = pkg.workspaces;
      else if (Array.isArray(pkg.workspaces?.packages)) globs = pkg.workspaces.packages;
    }
  }
  if (globs.length === 0) return null;

  const tally = new Map<string, number>();
  for (const glob of globs) {
    if (glob.startsWith("!")) continue;
    const star = glob.indexOf("*");
    const prefix = star === -1 ? (glob.endsWith("/") ? glob : `${glob}/`) : glob.slice(0, star);
    for (const path of props.changedPaths) {
      if (!path.startsWith(prefix)) continue;
      const candidate = path.slice(prefix.length).split("/")[0];
      if (candidate === undefined || candidate === "") continue;
      tally.set(candidate, (tally.get(candidate) ?? 0) + 1);
    }
  }
  let winner: string | null = null;
  let best = 0;
  for (const [name, count] of [...tally.entries()].sort(([a], [b]) => (a < b ? -1 : 1))) {
    if (count > best) {
      winner = name;
      best = count;
    }
  }
  return winner;
}

/**
 * Builds the commit message (title + why-body) from entry parts. The body is the
 * why-narrative from the log, never a file list (proposal §12).
 *
 * @param props.slug - Entry slug from the "## date — time — slug" heading.
 * @param props.built - "What was built" bullets, verbatim "- …" lines.
 * @param props.decisions - "Decisions made" bullets, verbatim.
 * @param props.scope - From inferScope, or null.
 * @returns Full commit.md content, trailing newline included.
 */
export function buildCommitMessage(props: {
  slug: string;
  built: string[];
  decisions: string[];
  scope: string | null;
}): string {
  const haystack = `${props.slug}\n${props.built.join("\n")}`;
  let type = "feat";
  if (/\b(fix|bug|broken|regression)\b/i.test(haystack)) type = "fix";
  else if (/\bdocs?\b/i.test(haystack)) type = "docs";
  else if (/\b(refactor|rename|extract)\b/i.test(haystack)) type = "refactor";
  else if (/\btest(s|ing)?\b/i.test(haystack)) type = "test";

  let title = props.scope !== null ? `${type}(${props.scope}): ${props.slug.toLowerCase()}` : `${type}: ${props.slug.toLowerCase()}`;
  while (title.length > 72) {
    const cut = title.lastIndexOf(" ");
    if (cut === -1) break;
    title = title.slice(0, cut);
  }

  let content = `${title}\n`;
  if (props.built.length > 0) content += `\n${props.built.join("\n")}\n`;
  if (props.decisions.length > 0) content += `\nWhy:\n${props.decisions.join("\n")}\n`;
  return content;
}

/**
 * Root-relative commits-ledger path for a date — the developer-facing copy source.
 *
 * @param props.date - "YYYY-MM-DD".
 * @returns e.g. ".agent/docs/commits/08-08-2026.md" (MM-DD-YYYY per developer preference).
 */
export function commitsLedgerPathFor(props: { date: string }): string {
  return join(P.commits, `${props.date.slice(5, 7)}-${props.date.slice(8, 10)}-${props.date.slice(0, 4)}.md`);
}

/**
 * `harness log commit-msg` — derives the conventional message from today's latest entry,
 * writes <date>.commit.md (the `git commit -F` source), appends the message to the day's
 * commits ledger (`.agent/docs/commits/MM-DD-YYYY.md` — multiple runs per day stack as
 * sections; an unchanged rerun appends nothing), links the ledger from today's log entry,
 * and prints the message then both paths.
 *
 * @param props.root - Project root.
 * @param props.dateOpt - Raw --date.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK.
 * @throws {HarnessError} "no-log-entry" when today has no entry.
 */
export function logCommitMsg(props: {
  root: string;
  dateOpt?: string;
  stdout: (s: string) => void;
}): number {
  const d = resolveLogDate({ root: props.root, dateOpt: props.dateOpt });
  const logRel = logPathFor({ date: d.date });
  const abs = join(props.root, logRel);
  if (!existsSync(abs)) {
    throw new HarnessError("no-log-entry", `no session log entry for ${d.date}`, { hint: "harness log append" });
  }
  const text = readFileSync(abs, "utf8");
  const headings = [...text.matchAll(/^## \d{4}-\d{2}-\d{2} — /gm)];
  if (headings.length === 0) {
    throw new HarnessError("no-log-entry", `no session log entry for ${d.date}`, { hint: "harness log append" });
  }
  const lastIdx = (headings[headings.length - 1] as RegExpMatchArray).index ?? 0;
  const entry = text.slice(lastIdx);
  const headingLine = entry.split("\n")[0] as string;
  const slug = headingLine.split(" — ").slice(2).join(" — ");

  // Session baseline: the last filled commit sha BEFORE the latest entry.
  const before = text.slice(0, lastIdx);
  const filled = [...before.matchAll(/\*\*Commit:\*\* ([0-9a-f]{7,40})\b/gi)];
  const baseline = filled.length > 0 ? ((filled[filled.length - 1] as RegExpMatchArray)[1] as string) : null;
  const changed = [
    ...new Set([
      ...(baseline !== null ? changedFilesSince({ root: props.root, sha: baseline }) : []),
      ...uncommittedFiles({ root: props.root }),
    ]),
  ].sort();

  const msg = buildCommitMessage({
    slug,
    built: sectionBullets({ entryBody: entry, heading: "What was built" }),
    decisions: sectionBullets({ entryBody: entry, heading: "Decisions made" }),
    scope: inferScope({ root: props.root, changedPaths: changed }),
  });
  const commitRel = logRel.replace(/\.log\.md$/, ".commit.md");
  writeFileAtomic({ path: join(props.root, commitRel), content: msg });

  // Day ledger: the copy-friendly file the developer returns to. Appends a fenced section
  // per generated message; a rerun with an identical message is a no-op (no dup sections,
  // no dup log links). The fence keeps the message byte-exact for copying.
  const ledgerRel = commitsLedgerPathFor({ date: d.date });
  const ledgerAbs = join(props.root, ledgerRel);
  const block = `## ${d.time}\n\n\`\`\`\n${msg.trimEnd()}\n\`\`\`\n`;
  const ledgerText = existsSync(ledgerAbs) ? readFileSync(ledgerAbs, "utf8") : "";
  if (!ledgerText.includes(block)) {
    if (ledgerText === "") {
      writeFileAtomic({ path: ledgerAbs, content: `# Commits — ${d.date}\n\n${block}` });
    } else {
      appendFileSync(ledgerAbs, `${ledgerText.endsWith("\n") ? "" : "\n"}\n${block}`);
    }
    // Mark the commit point in today's log entry with a link back to the ledger.
    const linkLine = `_Committed → [${ledgerRel}](../../../commits/${ledgerRel.split("/").pop() as string}) at ${d.time}._`;
    appendFileSync(abs, `${text.endsWith("\n") ? "" : "\n"}\n${linkLine}\n`);
  }

  props.stdout(msg.trimEnd());
  props.stdout(`Written: ${commitRel}`);
  props.stdout(`Ledger: ${ledgerRel}`);
  return 0;
}
