import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { EXIT } from "../lib/errors.ts";
import { loadManifest } from "../lib/manifest.ts";
import type { Reporter } from "../lib/output.ts";
import { P } from "../lib/paths.ts";

export interface EnvVarDoc {
  name: string;
  required: boolean;
  description: string;
}

/**
 * Parses the env.manifest.md table. Tolerant: non-table lines, the header row, separator rows,
 * and rows whose first cell isn't ALL_CAPS_SNAKE are skipped silently.
 *
 * @param props.text - File content.
 * @returns Documented vars in table order (duplicate VAR → first wins).
 */
export function parseEnvManifest(props: { text: string }): EnvVarDoc[] {
  const out: EnvVarDoc[] = [];
  const seen = new Set<string>();
  for (const line of props.text.split("\n")) {
    if (!line.trimStart().startsWith("|")) continue;
    const cells = line.split("|").map((c) => c.trim());
    while (cells.length > 0 && cells[0] === "") cells.shift();
    while (cells.length > 0 && cells[cells.length - 1] === "") cells.pop();
    const first = cells[0] ?? "";
    if (first.toLowerCase() === "var") continue; // header
    if (/^[-: ]+$/.test(first)) continue; // separator
    if (!/^[A-Z][A-Z0-9_]*$/.test(first)) continue;
    if (seen.has(first)) continue;
    seen.add(first);
    out.push({
      name: first,
      required: ["yes", "true"].includes((cells[1] ?? "").toLowerCase()),
      description: cells[2] ?? "",
    });
  }
  return out;
}

/** Names with non-empty values from a dotenv-format file (values discarded immediately). */
function dotenvNames(path: string): Set<string> {
  const names = new Set<string>();
  if (!existsSync(path)) return names;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const m = line.match(/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (m === null) continue;
    const value = (m[2] as string).trim().replace(/^(["'])(.*)\1$/, "$2");
    if (value !== "") names.add(m[1] as string);
  }
  return names;
}

/**
 * Checks documented vars against the live environment and .env/.env.local. NEVER reports
 * values — names only.
 *
 * @param props.root - Project root.
 * @param props.env - Injected environment (CLI passes process.env; tests pass literals).
 * @param props.reporter - Sink.
 * @returns EXIT.OK, or EXIT.FINDINGS when a required var is missing.
 */
export function envCheck(props: {
  root: string;
  env: Record<string, string | undefined>;
  reporter: Reporter;
}): number {
  const { manifest } = loadManifest({ root: props.root });
  if (!manifest.modules.env_manifest) {
    props.reporter.info("env_manifest module disabled", "env");
    return EXIT.OK;
  }
  const manifestPath = join(props.root, P.envManifest);
  if (!existsSync(manifestPath)) {
    props.reporter.error(".agent/env.manifest.md missing", "env-manifest-missing", "harness init write-phase 5");
    return EXIT.FINDINGS;
  }
  const fromDotenv = new Set([
    ...dotenvNames(join(props.root, ".env")),
    ...dotenvNames(join(props.root, ".env.local")),
  ]);
  for (const doc of parseEnvManifest({ text: readFileSync(manifestPath, "utf8") })) {
    const set = (props.env[doc.name] !== undefined && props.env[doc.name] !== "") || fromDotenv.has(doc.name);
    if (set) {
      props.reporter.ok(doc.name, "env");
    } else if (doc.required) {
      props.reporter.error(`missing required env var: ${doc.name} — ${doc.description}`, "env");
    } else {
      props.reporter.info(`optional env var unset: ${doc.name}`, "env");
    }
  }
  return props.reporter.hasErrors() ? EXIT.FINDINGS : EXIT.OK;
}
