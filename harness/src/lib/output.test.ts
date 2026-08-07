import { describe, expect, test } from "bun:test";
import { Reporter } from "./output.ts";

function mkReporter(json: boolean): { r: Reporter; lines: string[] } {
  const lines: string[] = [];
  const r = new Reporter({ json, write: (s) => lines.push(s) });
  return { r, lines };
}

describe("Reporter", () => {
  test("accumulates items in order and detects errors", () => {
    const { r } = mkReporter(false);
    r.ok("all good", "check-a");
    r.warn("watch out", "check-b", "harness sync");
    expect(r.hasErrors()).toBe(false);
    r.error("broken", "check-c", "harness pref compact");
    expect(r.hasErrors()).toBe(true);
    expect(r.items.map((i) => i.level)).toEqual(["ok", "warn", "error"]);
  });

  test("human render matches exact format", () => {
    const { r, lines } = mkReporter(false);
    r.error("preferences.md is 97 lines (budget: 80)", "preferences-over-budget", "Run: harness pref compact");
    r.warn("tech-stack.md: pkg not in workspace", "stale-packages");
    r.info("spec open 8 days", "open-specs-stale");
    r.ok("anti-patterns.md within budget");
    r.flush();
    expect(lines.join("\n")).toBe(
      [
        "🔴 ERROR  preferences.md is 97 lines (budget: 80)",
        "          → Run: harness pref compact",
        "⚠️  WARN   tech-stack.md: pkg not in workspace",
        "ℹ️  INFO   spec open 8 days",
        "✅ OK     anti-patterns.md within budget",
      ].join("\n"),
    );
  });

  test("json mode emits parseable items with id and hint preserved", () => {
    const { r, lines } = mkReporter(true);
    r.warn("w", "my-id", "do the thing");
    r.flush();
    const parsed = JSON.parse(lines.join("\n"));
    expect(parsed).toEqual([{ level: "warn", message: "w", id: "my-id", hint: "do the thing" }]);
  });
});
