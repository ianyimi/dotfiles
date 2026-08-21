import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";

function entryIds(dir: string): string[] {
  const text = readFileSync(join(dir, ".agent/docs/standards/preferences.md"), "utf8");
  return [...text.matchAll(/^- (P-\d{3,}) /gm)].map((m) => m[1] as string);
}

describe("pref compact", () => {
  test("supersedes + duplicate removal with exact report", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["pref", "compact"], cwd: dir });
    expect(r.code).toBe(0);
    expect(entryIds(dir)).toEqual(["P-001", "P-004", "P-005", "P-006"]);
    const text = readFileSync(join(dir, ".agent/docs/standards/preferences.md"), "utf8");
    expect(text).toContain("- P-005 (2026-07-02) Import node builtins with the node: prefix\n"); // tag stripped
    const infos = r.stdout.split("\n").filter((l) => l.includes("removed"));
    expect(infos).toEqual([
      "ℹ️  INFO   removed P-002 (superseded by P-005)",
      "ℹ️  INFO   removed P-003 (duplicate of P-001)",
    ]);
    rmProject({ dir });
  });

  test("--budget 5 additionally drops the oldest", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["pref", "compact", "--budget", "5"], cwd: dir });
    expect(r.code).toBe(0);
    expect(entryIds(dir)).toEqual(["P-004", "P-005", "P-006"]);
    expect(r.stdout).toContain("removed P-001 (over budget (oldest))");
    rmProject({ dir });
  });

  test("idempotent: second run removes nothing", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    await runCli({ argv: ["pref", "compact"], cwd: dir });
    const before = readFileSync(join(dir, ".agent/docs/standards/preferences.md"), "utf8");
    const r = await runCli({ argv: ["pref", "compact"], cwd: dir });
    expect(r.stdout).toContain("nothing to remove");
    expect(readFileSync(join(dir, ".agent/docs/standards/preferences.md"), "utf8")).toBe(before);
    rmProject({ dir });
  });
});

describe("pref remove", () => {
  test("deletes exactly one entry, header untouched", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const before = readFileSync(join(dir, ".agent/docs/standards/preferences.md"), "utf8");
    const headerBefore = before.split("\n").slice(0, 3).join("\n");
    const r = await runCli({ argv: ["pref", "remove", "P-004"], cwd: dir });
    expect(r.code).toBe(0);
    expect(entryIds(dir)).toEqual(["P-001", "P-002", "P-003", "P-005", "P-006"]);
    const after = readFileSync(join(dir, ".agent/docs/standards/preferences.md"), "utf8");
    expect(after.split("\n").slice(0, 3).join("\n")).toBe(headerBefore);
    rmProject({ dir });
  });

  test("unknown id → pref-not-found, exit 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["pref", "remove", "P-999"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("pref-not-found");
    rmProject({ dir });
  });
});
