import { describe, expect, test } from "bun:test";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";

const MANIFEST_MD = `# Environment Variables

| VAR | required | description |
|-----|----------|-------------|
| DATABASE_URL | yes | Postgres connection string |
`;

describe("env-vars-undocumented check", () => {
  test("flags exactly the undocumented example var; passes once documented", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, ".env.example"), "DATABASE_URL=\nAPI_KEY=\n#COMMENTED=\n");
    writeFileSync(join(dir, ".agent/env.manifest.md"), MANIFEST_MD);
    const r = await runCli({ argv: ["doctor"], cwd: dir });
    const lines = r.stdout.split("\n").filter((l) => l.includes("not documented"));
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain(".env.example: API_KEY not documented in env.manifest.md");

    writeFileSync(join(dir, ".agent/env.manifest.md"), `${MANIFEST_MD}| API_KEY | no | External API key |\n`);
    const r2 = await runCli({ argv: ["doctor"], cwd: dir });
    expect(r2.stdout).not.toContain("not documented");
    rmProject({ dir });
  });

  test("skipped when the env_manifest module is off", async () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    writeFileSync(join(dir, ".env.example"), "API_KEY=\n");
    const manifestPath = join(dir, ".agent/manifest.json");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    manifest.modules.env_manifest = false;
    writeFileSync(manifestPath, JSON.stringify(manifest));
    const r = await runCli({ argv: ["doctor", "--json"], cwd: dir });
    const items = JSON.parse(r.stdout) as Array<{ id?: string }>;
    expect(items.some((i) => i.id === "env-vars-undocumented")).toBe(false);
    rmProject({ dir });
  });
});
