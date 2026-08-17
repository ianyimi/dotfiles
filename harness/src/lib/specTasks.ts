import { HarnessError } from "./errors.ts";
import { parseFrontmatter } from "./frontmatter.ts";

export interface TaskStep {
  text: string;
  checked: boolean;
  line: number;
}

export interface TaskGroup {
  id: string; // "Step 1" (legacy specs: "T1")
  title: string;
  why: string; // "" when the Why: line is absent (tolerated)
  verify: string; // shell command, or exactly "manual"
  steps: TaskStep[];
  startLine: number; // 0-based line index of the "## Step n — " (or legacy "## Tn — ") heading
  endLine: number; // exclusive — next "## " heading or EOF
}

export interface SpecTasks {
  frontmatter: Record<string, unknown>;
  groups: TaskGroup[];
}

const GROUP_HEADING_RE = /^## (Step \d+|T\d+) — (.+)$/;

/**
 * Parses a spec-tasks.md document into ordered task groups (contract C-05a).
 * Line indexes refer to the FULL document so tickGroup can splice byte-faithfully.
 *
 * @param props.text - Full spec-tasks.md content.
 * @returns Frontmatter + groups in document order.
 * @throws {HarnessError} code "spec-tasks-invalid" when a group has no Verify: line,
 *   has zero steps, or a duplicate group id appears.
 */
export function parseSpecTasks(props: { text: string }): SpecTasks {
  const frontmatter = parseFrontmatter({ text: props.text }).data;
  const lines = props.text.split("\n").map((l) => l.replace(/\r$/, ""));

  // Every "## " line is a boundary; group headings are the subset matching the Tn pattern.
  const boundaries: number[] = [];
  const headings: Array<{ id: string; title: string; line: number }> = [];
  for (const [i, line] of lines.entries()) {
    if (line.startsWith("## ")) {
      boundaries.push(i);
      const m = line.match(GROUP_HEADING_RE);
      if (m !== null) headings.push({ id: m[1] as string, title: m[2] as string, line: i });
    }
  }

  const seen = new Set<string>();
  const groups: TaskGroup[] = [];
  for (const h of headings) {
    if (seen.has(h.id)) {
      throw new HarnessError("spec-tasks-invalid", `duplicate group id ${h.id}`);
    }
    seen.add(h.id);
    const endLine = boundaries.find((b) => b > h.line) ?? lines.length;
    let why = "";
    let verify: string | null = null;
    const steps: TaskStep[] = [];
    for (let i = h.line + 1; i < endLine; i++) {
      const line = lines[i] as string;
      // "Why:"/"Verify:" may be present with an empty value (spec new's fill-me template) —
      // presence is the contract; an empty Verify means "draft, not yet runnable".
      const whyMatch = line.match(/^Why:\s?(.*)$/);
      if (whyMatch !== null && why === "") why = (whyMatch[1] as string).trim();
      const verifyMatch = line.match(/^Verify:\s?(.*)$/);
      if (verifyMatch !== null && verify === null) verify = (verifyMatch[1] as string).trim();
      const stepMatch = line.match(/^- \[( |x)\] (.*)$/);
      if (stepMatch !== null) {
        steps.push({ checked: stepMatch[1] === "x", text: stepMatch[2] as string, line: i });
      }
    }
    if (verify === null) {
      throw new HarnessError("spec-tasks-invalid", `${h.id} has no Verify: line`);
    }
    if (steps.length === 0) {
      throw new HarnessError("spec-tasks-invalid", `${h.id} has no steps`);
    }
    groups.push({ id: h.id, title: h.title, why, verify, steps, startLine: h.line, endLine });
  }
  return { frontmatter, groups };
}

/**
 * Returns the document with every step checkbox of one group ticked ("- [ ]" → "- [x]").
 * All other bytes are preserved exactly.
 *
 * @param props.text - Full spec-tasks.md content.
 * @param props.groupId - Group to tick, e.g. "T1".
 * @returns Updated document text.
 * @throws {HarnessError} code "group-not-found" when the id has no group.
 */
export function tickGroup(props: { text: string; groupId: string }): string {
  const tasks = parseSpecTasks({ text: props.text });
  const group = tasks.groups.find((g) => g.id === props.groupId);
  if (group === undefined) {
    throw new HarnessError(
      "group-not-found",
      `no task group ${props.groupId} (valid: ${tasks.groups.map((g) => g.id).join(", ")})`,
    );
  }
  const lines = props.text.split("\n");
  for (const step of group.steps) {
    const line = lines[step.line] as string;
    if (line.includes("- [ ]")) lines[step.line] = line.replace("- [ ]", "- [x]");
  }
  return lines.join("\n");
}
