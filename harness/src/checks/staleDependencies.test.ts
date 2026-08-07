import { describe, expect, test } from "bun:test";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { saveRegistry } from "../lib/depsRegistry.ts";

const row = (pkg: string, v: string) => ({ package: pkg, version: v, repo: `github.com/x/${pkg}`, clonedAtSha: "c".repeat(40) });
const findings = (stdout: string) =>
  JSON.parse(stdout).filter((i: { id?: string; level: string }) => i.id === "stale-dependencies" && i.level !== "ok");

describe("stale-dependencies", () => {
  test("drift → info + sync hint; missing clone dir → info + clone hint", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    saveRegistry({ root: dir, rows: [row("pkg", "1.0.0"), row("lost", "2.0.0")] });
    mkdirSync(join(dir, ".agent/dependencies/pkg"), { recursive: true }); // "lost" has no clone dir
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "x", dependencies: { pkg: "^1.1.0" } }));
    const f = findings((await runCli({ argv: ["doctor", "--json"], cwd: dir })).stdout);
    expect(f).toEqual([
      { level: "info", id: "stale-dependencies", message: "registry: lost registered but clone missing", hint: "harness deps clone lost" },
      { level: "info", id: "stale-dependencies", message: "registry: pkg cloned at 1.0.0, project pins 1.1.0", hint: "harness deps sync pkg" },
    ]);
    rmProject({ dir });
  });
  test("matching pin + present clone, and unpinned reference clones → no findings", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    saveRegistry({ root: dir, rows: [row("pkg", "1.1.0"), row("ref-only", "2.0.0")] });
    mkdirSync(join(dir, ".agent/dependencies/pkg"), { recursive: true });
    mkdirSync(join(dir, ".agent/dependencies/ref-only"), { recursive: true });
    writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "x", dependencies: { pkg: "1.1.0" } }));
    expect(findings((await runCli({ argv: ["doctor", "--json"], cwd: dir })).stdout)).toEqual([]);
    rmProject({ dir });
  });
});
