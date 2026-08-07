import { describe, expect, test } from "bun:test";
import { parseFrontmatter, serializeFrontmatter } from "./frontmatter.ts";

const PI_SKILL = `---
name: 1-dev-spec
description: Write a scoped implementation spec for a feature or change.
invoke: "dev-spec"
---

# Dev Spec

Body here.
`;

const OMP_AGENT = `---
name: scout
description: Fast read-only scout returning compressed context.
tools: read, grep, glob
model: "@smol"
thinking-level: medium
read-summarize: false
---
Body.
`;

const INLINE_ARRAY = `---
name: spec-structure
applies_to: [".pi/agent-docs/specs/**/*.md"]
---
b
`;

const DASH_LIST = `---
name: x
scope:
  - "packages/*/src/**"
  - "apps/www/src/**"
---
b
`;

const FOLDED = `---
name: y
description: Use BEFORE any non-trivial code change — new features, adapters,
  anything touching multiple files.
---
b
`;

const EMPTY_BLOCK = `---
---
body text
`;

const COLON_VALUE = `---
description: Use BEFORE any change: always
---
b
`;

describe("parseFrontmatter", () => {
  test("pi skill frontmatter with quoted invoke", () => {
    const fm = parseFrontmatter({ text: PI_SKILL });
    expect(fm.data).toEqual({
      name: "1-dev-spec",
      description: "Write a scoped implementation spec for a feature or change.",
      invoke: "dev-spec",
    });
    expect(fm.body).toBe("\n# Dev Spec\n\nBody here.\n");
  });

  test("OMP kebab keys, booleans, @-model", () => {
    const fm = parseFrontmatter({ text: OMP_AGENT });
    expect(fm.data["thinking-level"]).toBe("medium");
    expect(fm.data["read-summarize"]).toBe(false);
    expect(fm.data["model"]).toBe("@smol");
    expect(fm.data["tools"]).toBe("read, grep, glob");
  });

  test("inline array", () => {
    expect(parseFrontmatter({ text: INLINE_ARRAY }).data["applies_to"]).toEqual([
      ".pi/agent-docs/specs/**/*.md",
    ]);
  });

  test("dash list", () => {
    expect(parseFrontmatter({ text: DASH_LIST }).data["scope"]).toEqual([
      "packages/*/src/**",
      "apps/www/src/**",
    ]);
  });

  test("folded multi-line description joins with a space", () => {
    expect(parseFrontmatter({ text: FOLDED }).data["description"]).toBe(
      "Use BEFORE any non-trivial code change — new features, adapters, anything touching multiple files.",
    );
  });

  test("no frontmatter", () => {
    const fm = parseFrontmatter({ text: "# Just markdown\n" });
    expect(fm.data).toEqual({});
    expect(fm.raw).toBe("");
    expect(fm.body).toBe("# Just markdown\n");
  });

  test("empty block", () => {
    const fm = parseFrontmatter({ text: EMPTY_BLOCK });
    expect(fm.data).toEqual({});
    expect(fm.body).toBe("body text\n");
  });

  test("colon-in-value splits on first colon only", () => {
    expect(parseFrontmatter({ text: COLON_VALUE }).data["description"]).toBe(
      "Use BEFORE any change: always",
    );
  });

  test("unclosed frontmatter treated as body", () => {
    const text = "---\nname: x\nno closing";
    const fm = parseFrontmatter({ text });
    expect(fm.data).toEqual({});
    expect(fm.body).toBe(text);
  });
});

describe("serializeFrontmatter round-trip", () => {
  for (const [name, text] of [
    ["pi skill", PI_SKILL],
    ["omp agent", OMP_AGENT],
    ["inline array", INLINE_ARRAY],
    ["dash list", DASH_LIST],
    ["folded", FOLDED],
    ["empty block", EMPTY_BLOCK],
    ["colon value", COLON_VALUE],
    ["no frontmatter", "# Just markdown\n"],
  ] as const) {
    test(`byte-exact: ${name}`, () => {
      const fm = parseFrontmatter({ text });
      expect(serializeFrontmatter({ data: fm.data, body: fm.body, raw: fm.raw })).toBe(text);
    });
  }

  test("changed data falls back to canonical emit", () => {
    const fm = parseFrontmatter({ text: PI_SKILL });
    fm.data["name"] = "renamed";
    const out = serializeFrontmatter({ data: fm.data, body: fm.body, raw: fm.raw });
    expect(out).toContain("name: renamed");
    expect(out.startsWith("---\n")).toBe(true);
  });
});
