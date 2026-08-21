import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";
import { checkPath, parseNamingRules } from "./namingRules.ts";

function fixtureRules() {
  const dir = mkTmpProject({ fixture: "initialized" });
  const text = readFileSync(join(dir, ".agent/docs/standards/naming-conventions.md"), "utf8");
  rmProject({ dir });
  return parseNamingRules({ text });
}

describe("parseNamingRules", () => {
  test("parses the fixture's 3 rules in order", () => {
    const rules = fixtureRules();
    expect(rules.map((r) => r.id)).toEqual(["react-components", "react-hooks", "lib-modules"]);
    expect(rules[0]?.pattern).toBe("^[A-Z][a-zA-Z0-9]+\\.tsx$");
    expect(rules[0]?.scope).toEqual(["src/components/**"]);
    expect(rules[0]?.counter_examples).toEqual(["badFile.tsx"]);
  });

  test("no rules block → naming-rules-invalid", () => {
    expect(() => parseNamingRules({ text: "# Nothing here\n" })).toThrow(/no rules block/);
  });

  test("non-rules yaml fence is skipped, rules fence still found", () => {
    const text = "```yaml\nfoo: 1\n```\n\n```yaml\nrules:\n  - id: x\n    pattern: \"^a$\"\n    scope: [\"src/**\"]\n    description: d\n```\n";
    expect(parseNamingRules({ text }).map((r) => r.id)).toEqual(["x"]);
  });

  test("bad regex → naming-rules-invalid naming the rule", () => {
    const text = "```yaml\nrules:\n  - id: broken\n    pattern: \"([\"\n    scope: [\"src/**\"]\n    description: d\n```\n";
    expect(() => parseNamingRules({ text })).toThrow(/broken.*invalid pattern/);
  });

  test("missing scope → naming-rules-invalid", () => {
    const text = "```yaml\nrules:\n  - id: noscope\n    pattern: \"^a$\"\n    description: d\n```\n";
    expect(() => parseNamingRules({ text })).toThrow(/noscope/);
  });
});

describe("checkPath", () => {
  const rules = fixtureRules();
  for (const [path, matched, ok] of [
    ["src/components/FilterPanel.tsx", ["react-components"], true],
    ["src/components/badFile.tsx", ["react-components"], false],
    ["src/hooks/useFilterState.ts", ["react-hooks"], true],
    ["src/lib/helperStuff.ts", ["lib-modules"], false],
    ["src/lib/date-utils.ts", ["lib-modules"], true],
    ["README.md", [], true],
  ] as const) {
    test(`${path} → matched=${JSON.stringify(matched)}, ok=${ok}`, () => {
      expect(checkPath({ path, rules })).toEqual({ matched: [...matched], ok });
    });
  }
});
