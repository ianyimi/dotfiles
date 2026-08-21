import { describe, expect, test } from "bun:test";
import { parseArgs } from "./args.ts";

const spec = { positionals: ["slug"], flags: ["json", "check"], options: ["for", "from"] };

describe("parseArgs", () => {
  test("positionals + flags + options", () => {
    expect(parseArgs({ argv: ["my-spec", "--json", "--for", "auth"], spec })).toEqual({
      positionals: { slug: "my-spec" },
      rest: [],
      flags: { json: true, check: false },
      options: { for: "auth" },
    });
  });
  test("--key=value form", () => {
    expect(parseArgs({ argv: ["s", "--from=T3"], spec }).options.from).toBe("T3");
  });
  test("-- passthrough", () => {
    expect(parseArgs({ argv: ["s", "--", "--json", "x"], spec }).rest).toEqual(["--json", "x"]);
  });
  test("...rest collector", () => {
    const p = parseArgs({ argv: ["a", "b", "c"], spec: { positionals: ["first", "...rest"] } });
    expect(p.positionals.first).toBe("a");
    expect(p.rest).toEqual(["b", "c"]);
  });
  test("repeated option: last wins", () => {
    expect(parseArgs({ argv: ["s", "--for", "a", "--for", "b"], spec }).options.for).toBe("b");
  });
  for (const [name, argv] of [
    ["unknown flag", ["s", "--nope"]],
    ["missing positional", []],
    ["option without value", ["s", "--for"]],
    ["option eats a flag-looking token", ["s", "--for", "--json"]],
    ["unexpected extra positional", ["s", "extra"]],
    ["single dash", ["s", "-j"]],
    ["flag with =value", ["s", "--json=1"]],
  ] as const) {
    test(`usage error: ${name}`, () => {
      expect(() => parseArgs({ argv: [...argv], spec })).toThrow();
    });
  }
});
