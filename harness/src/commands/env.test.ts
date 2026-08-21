import { describe, expect, test } from "bun:test";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject, runCli } from "../../test/helpers.ts";
import { Reporter } from "../lib/output.ts";
import { envCheck, parseEnvManifest } from "./env.ts";

const MANIFEST_MD = `# Environment Variables

> Parsed by \`harness env check\`. required = yes|no. Never put secret VALUES in this file.

| VAR | required | description |
|-----|----------|-------------|
| DATABASE_URL | yes | Postgres connection string |
| ANALYTICS_ID | no | Plausible site id |
`;

function seeded(): string {
  const dir = mkTmpProject({ fixture: "initialized" });
  writeFileSync(join(dir, ".agent/env.manifest.md"), MANIFEST_MD);
  return dir;
}

function check(dir: string, env: Record<string, string | undefined>): { code: number; out: string } {
  const lines: string[] = [];
  const reporter = new Reporter({ json: false, write: (s) => lines.push(s) });
  const code = envCheck({ root: dir, env, reporter });
  reporter.flush();
  return { code, out: lines.join("\n") };
}

describe("parseEnvManifest", () => {
  test("golden table → exactly the two docs; junk rows skipped", () => {
    expect(parseEnvManifest({ text: `${MANIFEST_MD}| not_caps | yes | skipped |\n| | | |\n` })).toEqual([
      { name: "DATABASE_URL", required: true, description: "Postgres connection string" },
      { name: "ANALYTICS_ID", required: false, description: "Plausible site id" },
    ]);
  });
});

describe("env check", () => {
  test("required set via injected env → exit 0", () => {
    const dir = seeded();
    const r = check(dir, { DATABASE_URL: "x" });
    expect(r.code).toBe(0);
    expect(r.out).toContain("✅ OK     DATABASE_URL");
    rmProject({ dir });
  });

  test("required only in .env → exit 0, value NEVER printed", () => {
    const dir = seeded();
    writeFileSync(join(dir, ".env"), 'DATABASE_URL="postgres://sekrit@host/db"\n');
    const r = check(dir, {});
    expect(r.code).toBe(0);
    expect(r.out).not.toContain("sekrit");
    rmProject({ dir });
  });

  test("required missing → exit 1 naming the var; optional missing → info", () => {
    const dir = seeded();
    const r = check(dir, {});
    expect(r.code).toBe(1);
    expect(r.out).toContain("missing required env var: DATABASE_URL — Postgres connection string");
    expect(r.out).toContain("optional env var unset: ANALYTICS_ID");
    rmProject({ dir });
  });

  test("manifest file missing → exit 1 env-manifest-missing", () => {
    const dir = seeded();
    rmSync(join(dir, ".agent/env.manifest.md"));
    const r = check(dir, { DATABASE_URL: "x" });
    expect(r.code).toBe(1);
    expect(r.out).toContain(".agent/env.manifest.md missing");
    rmProject({ dir });
  });

  test("module off → info + exit 0", () => {
    const dir = seeded();
    const manifestPath = join(dir, ".agent/manifest.json");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    manifest.modules.env_manifest = false;
    writeFileSync(manifestPath, JSON.stringify(manifest));
    const r = check(dir, {});
    expect(r.code).toBe(0);
    expect(r.out).toContain("env_manifest module disabled");
    rmProject({ dir });
  });

  test("CLI wiring: harness env check", async () => {
    const dir = seeded();
    const r = await runCli({ argv: ["env", "check"], cwd: dir });
    expect([0, 1]).toContain(r.code); // depends on live process.env, both valid
    rmProject({ dir });
  });
});
