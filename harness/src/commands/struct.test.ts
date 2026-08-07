import { describe, expect, test } from "bun:test";
import { readFileSync, renameSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gitInit, mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { headSha } from "../lib/git.ts";

describe("struct", () => {
  test("golden: output === committed fixture directory-structure.md, byte-idempotent", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const fixture = readFileSync(join(dir, ".agent/docs/standards/directory-structure.md"), "utf8");
    const r = await runCli({ argv: ["struct"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toBe(".agent/docs/standards/directory-structure.md");
    expect(readFileSync(join(dir, ".agent/docs/standards/directory-structure.md"), "utf8")).toBe(fixture);
    rmProject({ dir });
  });

  test("with git, the header SHA equals headSha", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    gitInit({ dir });
    await runCli({ argv: ["struct"], cwd: dir });
    const text = readFileSync(join(dir, ".agent/docs/standards/directory-structure.md"), "utf8");
    expect(text).toContain(`(SHA: ${headSha({ root: dir })})`);
    rmProject({ dir });
  });

  test("--check reports exactly the two seeded violations, exit 1", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const r = await runCli({ argv: ["struct", "--check"], cwd: dir });
    expect(r.code).toBe(1);
    const errors = r.stdout.split("\n").filter((l) => l.startsWith("🔴"));
    expect(errors).toEqual([
      "🔴 ERROR  src/components/badFile.tsx violates react-components (React components — PascalCase .tsx)",
      "🔴 ERROR  src/lib/helperStuff.ts violates lib-modules (Lib modules — kebab-case .ts)",
    ]);
    rmProject({ dir });
  });

  test("--check passes after renaming the offenders", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    renameSync(join(dir, "src/components/badFile.tsx"), join(dir, "src/components/BadFile.tsx"));
    renameSync(join(dir, "src/lib/helperStuff.ts"), join(dir, "src/lib/helper-stuff.ts"));
    const r = await runCli({ argv: ["struct", "--check"], cwd: dir });
    expect(r.code).toBe(0);
    expect(r.stdout).toContain("✅ OK     no naming violations");
    rmProject({ dir });
  });

  test("unparseable rules block → naming-rules-invalid, exit 2", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(
      join(dir, ".agent/docs/standards/naming-conventions.md"),
      "# NC\n\n```yaml\nrules:\n  - id: broken\n    pattern: \"([\"\n    scope: [\"src/**\"]\n    description: d\n```\n",
    );
    const r = await runCli({ argv: ["struct", "--check"], cwd: dir });
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("naming-rules-invalid");
    rmProject({ dir });
  });
});
