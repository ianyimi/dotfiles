import { describe, expect, test } from "bun:test";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { buildIndex, extractDescription } from "./index.ts";

describe("index rebuild", () => {
  test("golden: output === committed fixture index.yml, byte-idempotent", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const fixture = readFileSync(join(dir, ".agent/docs/standards/index.yml"), "utf8");
    expect(buildIndex({ root: dir })).toBe(fixture);
    const r = await runCli({ argv: ["index", "rebuild"], cwd: dir });
    expect(r.code).toBe(0);
    expect(readFileSync(join(dir, ".agent/docs/standards/index.yml"), "utf8")).toBe(fixture);
    rmProject({ dir });
  });

  test("output parses with the yaml package and has the expected shape", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const parsed = parseYaml(buildIndex({ root: dir })) as Record<string, Record<string, { description: string; lines: number }>>;
    expect(parsed["root"]?.["anti-patterns"]?.lines).toBe(6);
    expect(parsed["backend"]?.["api"]?.description).toBe(
      "Convex function modules live in convex/ and follow the get/list/create naming verbs.",
    );
    rmProject({ dir });
  });

  test("file with only headings gets the missing-paragraph sentinel", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, ".agent/docs/standards/backend/empty-doc.md"), "# Only A Heading\n\n## Sub\n");
    const out = buildIndex({ root: dir });
    expect(out).toContain('empty-doc: { description: "(first paragraph missing — add one)", lines: 3 }');
    rmProject({ dir });
  });
});

describe("extractDescription", () => {
  test("frontmatter description wins", () => {
    expect(extractDescription({ text: "---\ndescription: From frontmatter\n---\n\n> Not this\n" })).toBe("From frontmatter");
  });
  test("skips fences, lists, tables; strips > prefix", () => {
    expect(
      extractDescription({ text: "# H\n\n```yaml\nx: 1\n```\n\n- list item\n| a |\n\n> The real one\n" }),
    ).toBe("The real one");
  });
});
