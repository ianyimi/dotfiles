import { HarnessError } from "./errors.ts";

/** Stable CLI ids for the three canonical sections (D08-1). */
export const TASK_SECTIONS = ["in-progress", "inbox", "done"] as const;
export type TaskSectionId = (typeof TASK_SECTIONS)[number];

/** id → exact heading text written by 01's scaffold. */
export const SECTION_HEADINGS: Record<TaskSectionId, string> = {
  "in-progress": "## In Progress",
  inbox: "## Inbox",
  done: "## Recently Done",
};

export interface TasksSection {
  /** Canonical id, or null for an unknown user section (preserved, never targeted). */
  id: TaskSectionId | null;
  /** Exact heading line, e.g. "## In Progress". */
  heading: string;
  /** Task lines starting with "- ", verbatim (including the "- "). */
  items: string[];
  /** Non-item, non-blank lines inside the section, verbatim, in order (D08-2). */
  extra: string[];
}

export interface TasksDoc {
  /** Everything before the first "## " line, verbatim ("" if none). */
  preamble: string;
  sections: TasksSection[];
}

/**
 * Parses .agent/docs/tasks.md into sections (D08-2 tolerance rules).
 *
 * @param props.text - Full tasks.md content.
 * @returns Parsed doc; canonical sections recognized by exact heading match.
 * @throws Never — unknown content is preserved, not rejected.
 */
export function parseTasksFile(props: { text: string }): TasksDoc {
  const headingToId = new Map<string, TaskSectionId>(
    (Object.entries(SECTION_HEADINGS) as Array<[TaskSectionId, string]>).map(([id, h]) => [h, id]),
  );
  const preambleLines: string[] = [];
  const sections: TasksSection[] = [];
  const seenIds = new Set<TaskSectionId>();
  let current: TasksSection | null = null;

  for (const line of props.text.split("\n")) {
    if (line.startsWith("## ")) {
      let id = headingToId.get(line.trimEnd()) ?? null;
      // Duplicate canonical heading → first wins the id (doctor territory, not ours).
      if (id !== null && seenIds.has(id)) id = null;
      if (id !== null) seenIds.add(id);
      current = { id, heading: line, items: [], extra: [] };
      sections.push(current);
      continue;
    }
    if (current === null) {
      preambleLines.push(line);
    } else if (line.startsWith("- ")) {
      current.items.push(line);
    } else if (line.trim() !== "") {
      current.extra.push(line);
    }
  }
  while (preambleLines.length > 0 && (preambleLines[preambleLines.length - 1] as string).trim() === "") preambleLines.pop();
  return { preamble: preambleLines.join("\n"), sections };
}

/**
 * Serializes a TasksDoc back to markdown. Canonical sections are emitted in canonical order
 * (in-progress, inbox, done) with any missing one recreated empty; unknown sections follow in
 * their original order. Layout per section: heading, extra lines, items, one blank line.
 *
 * @param props.doc - Parsed/modified doc.
 * @returns Full file text ending in exactly one trailing newline.
 */
export function serializeTasksFile(props: { doc: TasksDoc }): string {
  const parts: string[] = [];
  if (props.doc.preamble !== "") parts.push(props.doc.preamble.trimEnd());
  for (const id of TASK_SECTIONS) {
    const section = props.doc.sections.find((s) => s.id === id);
    const heading = section?.heading ?? SECTION_HEADINGS[id];
    const body = section !== undefined ? [...section.extra, ...section.items] : [];
    parts.push([heading, ...body].join("\n"));
  }
  for (const section of props.doc.sections) {
    if (section.id !== null) continue;
    parts.push([section.heading, ...section.extra, ...section.items].join("\n"));
  }
  return `${parts.join("\n\n")}\n`;
}

/** Finds a canonical section, creating it (in canonical position) when missing (D08-2). */
function findOrCreate(doc: TasksDoc, id: TaskSectionId): TasksSection {
  const existing = doc.sections.find((s) => s.id === id);
  if (existing !== undefined) return existing;
  const created: TasksSection = { id, heading: SECTION_HEADINGS[id], items: [], extra: [] };
  doc.sections.push(created);
  return created;
}

/**
 * Appends a task to a section.
 *
 * @param props.doc - Doc to mutate.
 * @param props.title - Task title (no leading "- ").
 * @param props.section - Target section id.
 * @returns Nothing (mutates doc; missing section is created per D08-2).
 */
export function addTask(props: { doc: TasksDoc; title: string; section: TaskSectionId }): void {
  findOrCreate(props.doc, props.section).items.push(`- ${props.title}`);
}

export type MoveResult = { line: string; from: TaskSectionId | null; noop: boolean };

/**
 * Moves the task whose line contains titleSubstr (case-insensitive) to the target section.
 * Searches canonical AND unknown sections — a task in a user-added section can be moved out.
 *
 * @param props.doc - Doc to mutate.
 * @param props.titleSubstr - Substring matched against item lines across ALL sections.
 * @param props.to - Target section id.
 * @returns The moved line, its source section, and noop=true when already there (D08-3).
 * @throws {HarnessError} "task-not-found" (0 matches) · "task-ambiguous" (2+ matches;
 *   message lists every matching line).
 */
export function moveTask(props: { doc: TasksDoc; titleSubstr: string; to: TaskSectionId }): MoveResult {
  const needle = props.titleSubstr.toLowerCase();
  const matches: Array<{ section: TasksSection; index: number; line: string }> = [];
  for (const section of props.doc.sections) {
    section.items.forEach((line, index) => {
      if (line.toLowerCase().includes(needle)) matches.push({ section, index, line });
    });
  }
  if (matches.length === 0) {
    throw new HarnessError("task-not-found", `no task matches "${props.titleSubstr}"`, { hint: "harness tasks add" });
  }
  if (matches.length > 1) {
    throw new HarnessError("task-ambiguous", `"${props.titleSubstr}" is ambiguous:\n${matches.map((m) => m.line).join("\n")}`);
  }
  const match = matches[0] as { section: TasksSection; index: number; line: string };
  if (match.section.id === props.to) {
    return { line: match.line, from: props.to, noop: true };
  }
  match.section.items.splice(match.index, 1);
  findOrCreate(props.doc, props.to).items.push(match.line);
  return { line: match.line, from: match.section.id, noop: false };
}
