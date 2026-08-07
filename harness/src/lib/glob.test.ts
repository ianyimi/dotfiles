import { describe, expect, test } from "bun:test";
import { globMatch } from "./glob.ts";

describe("globMatch", () => {
  for (const [pattern, path, expected] of [
    ["src/components/**", "src/components/deep/A.tsx", true],
    ["src/components/**", "src/hooks/a.ts", false],
    ["**/*.ts", "a/b/c.ts", true],
    ["**/*.ts", "a/b/c.tsx", false],
    ["*.ts", "a/b.ts", false],
    ["convex/**", "convex/collections.ts", true],
    ["src/?ib/**", "src/lib/x.ts", true],
    [".agent/docs/specs/*/", ".agent/docs/specs/2026-08-02-x/spec.md", true],
    ["**", "anything/x", true],
    ["a/**", "a/b", true],
    ["a/**", "a", false],
  ] as const) {
    test(`("${pattern}", "${path}") → ${expected}`, () => {
      expect(globMatch({ pattern, path })).toBe(expected);
    });
  }
});
