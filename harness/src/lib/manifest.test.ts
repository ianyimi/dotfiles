import { describe, expect, test } from "bun:test";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";
import { loadManifest, saveManifest, validateManifest } from "./manifest.ts";

function fixtureManifest(): Record<string, unknown> {
  const dir = mkTmpProject({ fixture: "initialized" });
  const value = JSON.parse(readFileSync(join(dir, ".agent", "manifest.json"), "utf8"));
  rmProject({ dir });
  return value;
}

describe("validateManifest", () => {
  test("fixture manifest loads clean with no warnings", () => {
    const { manifest, warnings } = validateManifest({ value: fixtureManifest() });
    expect(manifest.project).toBe("initialized");
    expect(warnings).toEqual([]);
  });

  for (const key of [
    "schema_version",
    "project",
    "description",
    "harness",
    "platforms",
    "workflow",
    "modules",
    "standards_domains",
    "dependencies",
    "doctor",
  ]) {
    test(`missing required key throws naming it: ${key}`, () => {
      const value = fixtureManifest();
      delete value[key];
      expect(() => validateManifest({ value })).toThrow(new RegExp(key));
    });
  }

  test("fills defaults: budgets, stale_spec_days, commit_mode", () => {
    const value = fixtureManifest();
    delete (value["doctor"] as Record<string, unknown>)["budgets"];
    delete (value["doctor"] as Record<string, unknown>)["stale_spec_days"];
    delete (value["workflow"] as Record<string, unknown>)["commit_mode"];
    const { manifest } = validateManifest({ value });
    expect(manifest.doctor.budgets.preferences_lines).toBe(80);
    expect(manifest.doctor.budgets.anti_patterns_lines).toBe(40);
    expect(manifest.doctor.stale_spec_days).toBe(14);
    expect(manifest.workflow.commit_mode).toBe("message-only");
  });

  test("unknown top-level key warns and survives round-trip", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const value = JSON.parse(readFileSync(join(dir, ".agent", "manifest.json"), "utf8"));
    value["my_custom_key"] = { a: 1 };
    writeFileSync(join(dir, ".agent", "manifest.json"), JSON.stringify(value));
    const { manifest, warnings } = loadManifest({ root: dir });
    expect(warnings).toEqual(["manifest.json: unknown key `my_custom_key` — kept"]);
    saveManifest({ root: dir, manifest });
    const reloaded = JSON.parse(readFileSync(join(dir, ".agent", "manifest.json"), "utf8"));
    expect(reloaded["my_custom_key"]).toEqual({ a: 1 });
    rmProject({ dir });
  });

  test("unknown platform id throws", () => {
    const value = fixtureManifest();
    (value["platforms"] as Record<string, unknown>)["active"] = ["omp", "cursor"];
    expect(() => validateManifest({ value })).toThrow(/unknown platform id "cursor"/);
  });

  test("dependency missing repo throws", () => {
    const value = fixtureManifest();
    value["dependencies"] = [{ package: "convex", version: "1.0.0" }];
    expect(() => validateManifest({ value })).toThrow(/missing repo/);
  });
});

describe("loadManifest", () => {
  test("not-initialized when file missing", () => {
    const dir = mkTmpProject({ fixture: "empty-project" });
    expect(() => loadManifest({ root: dir })).toThrow(/not initialized/);
    rmProject({ dir });
  });
  test("invalid JSON reports manifest-invalid", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, ".agent", "manifest.json"), "{ nope");
    expect(() => loadManifest({ root: dir })).toThrow(/invalid JSON/);
    rmProject({ dir });
  });
});
