import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkHarnessHome, rmHarnessHome } from "../../test/helpers.ts";
import { listTemplates, loadTemplate, templateDir } from "./templateStore.ts";

const TPL = {
  schema_version: "1.0",
  name: "t-one",
  saved_at: "2026-08-06",
  saved_at_sha: "a".repeat(40),
  source_project: "initialized",
  harness_version: "0.1.0",
  prefilled: { "3": { domains: ["backend"] } },
};

let home = "";
beforeEach(() => {
  home = mkHarnessHome();
});
afterEach(() => {
  rmHarnessHome({ dir: home });
});

function seed(name: string, json: unknown): void {
  const dir = join(home, "templates", name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "template.json"), JSON.stringify(json, null, 2));
}

describe("templateStore", () => {
  test("templateDir honors HARNESS_HOME and rejects bad names", () => {
    expect(templateDir({ name: "t-one" })).toBe(join(home, "templates", "t-one"));
    for (const bad of ["", "Has-Caps", "../evil", "a b", "-lead"]) {
      expect(() => templateDir({ name: bad })).toThrow(/invalid template name/);
    }
  });
  test("load round-trips and inventories seeds", () => {
    seed("t-one", TPL);
    mkdirSync(join(home, "templates", "t-one", "skills_seed", "custom-x"), { recursive: true });
    writeFileSync(join(home, "templates", "t-one", "skills_seed", "custom-x", "SKILL.md"), "x");
    mkdirSync(join(home, "templates", "t-one", "standards_seed"), { recursive: true });
    writeFileSync(join(home, "templates", "t-one", "standards_seed", "naming-conventions.md"), "n");
    const got = loadTemplate({ name: "t-one" });
    expect(got.template).toEqual(TPL as never);
    expect(got.skillsSeed).toEqual(["custom-x"]);
    expect(got.standardsSeed).toEqual(["naming-conventions.md"]);
  });
  test("not found / invalid json / templated version rejected", () => {
    expect(() => loadTemplate({ name: "nope" })).toThrow(/not found/i);
    seed("bad-json", null);
    writeFileSync(join(home, "templates", "bad-json", "template.json"), "{");
    expect(() => loadTemplate({ name: "bad-json" })).toThrow();
    seed("has-ver", {
      ...TPL,
      name: "has-ver",
      prefilled: { "6": { dependencies: [{ package: "convex", repo: "r", version: "1.0.0" }] } },
    });
    expect(() => loadTemplate({ name: "has-ver" })).toThrow(/version/);
  });
  test("list: empty → []; sorted; survives one bad entry", () => {
    expect(listTemplates()).toEqual([]);
    seed("zz", { ...TPL, name: "zz" });
    seed("aa", { ...TPL, name: "aa" });
    mkdirSync(join(home, "templates", "broken"), { recursive: true });
    expect(listTemplates().map((t) => `${t.name}${t.invalid === true ? "!" : ""}`)).toEqual(["aa", "broken!", "zz"]);
  });
});
