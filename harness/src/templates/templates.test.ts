import { describe, expect, test } from "bun:test";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parseFrontmatter } from "../lib/frontmatter.ts";

const SKILLS_DIR = join(dirname(fileURLToPath(import.meta.url)), "skills");

function lineCount(path: string): number {
  return readFileSync(path, "utf8").split("\n").filter((l) => l.trim() !== "").length;
}

describe("embedded skill templates", () => {
  const skillDirs = readdirSync(SKILLS_DIR, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name);

  test("all embedded skills exist", () => {
    for (const name of ["init", "dev-spec", "sync-spec", "commit", "debug", "document", "research", "learn"]) {
      expect(skillDirs).toContain(name);
    }
  });

  for (const [name, budget] of [["document", 60], ["research", 60], ["learn", 60]] as const) {
    test(`router skill ${name} stays within ${budget} non-empty lines`, () => {
      const text = readFileSync(join(SKILLS_DIR, name, "SKILL.md"), "utf8");
      expect(text.split("\n").filter((l) => l.trim() !== "").length).toBeLessThanOrEqual(budget);
      expect(text).toContain("## Preflight");
    });
  }

  test("03 references ship with their content anchors", () => {
    expect(readFileSync(join(SKILLS_DIR, "commit/references/session-log-format.md"), "utf8")).toContain(
      "**Commit:** (pending)",
    );
    expect(readFileSync(join(SKILLS_DIR, "debug/references/debug-hierarchy.md"), "utf8")).toContain(
      "most-fragile-first",
    );
  });

  test("shared-references ships the cascade checklist (no SKILL.md — not a skill, D08-6)", () => {
    const text = readFileSync(join(SKILLS_DIR, "shared-references", "cascade-checks.md"), "utf8");
    expect(text).toContain("Confirm this full set before I apply anything");
    expect(readdirSync(join(SKILLS_DIR, "shared-references"))).not.toContain("SKILL.md");
  });

  const skillOnlyDirs = readdirSync(SKILLS_DIR, { withFileTypes: true }).filter(
    (e) => e.isDirectory() && readdirSync(join(SKILLS_DIR, e.name)).includes("SKILL.md"),
  );
  for (const skill of skillOnlyDirs) {
    const skillPath = join(SKILLS_DIR, skill.name, "SKILL.md");

    test(`${skill.name}/SKILL.md ≤150 lines with name + description frontmatter`, () => {
      expect(lineCount(skillPath)).toBeLessThanOrEqual(150);
      const { data } = parseFrontmatter({ text: readFileSync(skillPath, "utf8") });
      expect(data["name"]).toBe(skill.name);
      expect(typeof data["description"]).toBe("string");
      expect((data["description"] as string).length).toBeGreaterThan(20);
    });

    const refsDir = join(SKILLS_DIR, skill.name, "references");
    let refs: string[] = [];
    try {
      refs = readdirSync(refsDir).filter((f) => f.endsWith(".md"));
    } catch {
      refs = [];
    }
    for (const ref of refs) {
      test(`${skill.name}/references/${ref} ≤120 lines`, () => {
        expect(lineCount(join(refsDir, ref))).toBeLessThanOrEqual(120);
      });
    }
  }
});
