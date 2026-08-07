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

  test("at least the init, dev-spec, and sync-spec skills exist", () => {
    for (const name of ["init", "dev-spec", "sync-spec"]) expect(skillDirs).toContain(name);
  });

  for (const skill of readdirSync(SKILLS_DIR, { withFileTypes: true }).filter((e) => e.isDirectory())) {
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
