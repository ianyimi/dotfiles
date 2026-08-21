import { cpSync, existsSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "../lib/args.ts";
import { EXIT, HarnessError } from "../lib/errors.ts";
import { sha256, walk, writeFileAtomic } from "../lib/fsx.ts";
import { headSha } from "../lib/git.ts";
import { loadManifest, type HarnessManifest } from "../lib/manifest.ts";
import { P, resolveProjectRoot } from "../lib/paths.ts";
import { listTemplates, loadTemplate, templateDir, type InitTemplate } from "../lib/templateStore.ts";

/** Embedded default skills dir — the diff baseline for skills_seed derivation. */
export const EMBEDDED_SKILLS_DIR = join(dirname(fileURLToPath(import.meta.url)), "..", "templates", "skills");

const HARNESS_VERSION = "0.1.0"; // keep in sync with package.json (single dev-time constant)

/** Content fingerprint of a directory: sorted rel-path → sha256 map, as one hash. */
function dirFingerprint(dir: string): string {
  const files = walk({ root: dir });
  const parts = files.map((f) => `${f}:${sha256({ text: readFileSync(join(dir, f), "utf8") })}`);
  return sha256({ text: parts.join("\n") });
}

/**
 * Derives a template from an initialized project (pure planning — no writes).
 *
 * @param props.root - Project root (must be initialized; caller loads the manifest).
 * @param props.manifest - Loaded manifest.
 * @param props.name - Template name being saved.
 * @param props.embeddedSkillsDir - Absolute path of src/templates/skills (injectable for tests).
 * @param props.now - Clock for saved_at (master §2.8).
 * @returns The template.json object plus copy plans for both seed dirs
 *   (project-root-relative source → template-dir-relative dest).
 */
export function deriveTemplate(props: {
  root: string;
  manifest: HarnessManifest;
  name: string;
  embeddedSkillsDir: string;
  now: Date;
}): {
  template: InitTemplate;
  standardsSeedCopies: Array<{ from: string; to: string }>;
  skillsSeedCopies: Array<{ from: string; to: string }>;
} {
  const { manifest } = props;
  const prefilled: InitTemplate["prefilled"] = {};
  if (manifest.standards_domains.length > 0) prefilled["3"] = { domains: [...manifest.standards_domains] };
  if (manifest.dependencies.length > 0) {
    // Versions STRIPPED (D-07-3) — they re-resolve from the new project's manifest at init.
    prefilled["6"] = { dependencies: manifest.dependencies.map((d) => ({ package: d.package, repo: d.repo })) };
  }
  prefilled["7"] = { workflow: manifest.workflow, modules: manifest.modules, platforms: manifest.platforms };

  const standardsSeedCopies: Array<{ from: string; to: string }> = [];
  const namingRel = join(P.standards, "naming-conventions.md");
  if (existsSync(join(props.root, namingRel))) {
    standardsSeedCopies.push({ from: namingRel, to: "standards_seed/naming-conventions.md" });
  }

  const skillsSeedCopies: Array<{ from: string; to: string }> = [];
  const skillsAbs = join(props.root, P.skills);
  if (existsSync(skillsAbs)) {
    for (const entry of readdirSync(skillsAbs, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      if (!entry.isDirectory()) continue;
      const projectSkill = join(skillsAbs, entry.name);
      const embeddedSkill = join(props.embeddedSkillsDir, entry.name);
      const customized = !existsSync(embeddedSkill) || dirFingerprint(projectSkill) !== dirFingerprint(embeddedSkill);
      if (customized) {
        skillsSeedCopies.push({ from: `${P.skills}/${entry.name}`, to: `skills_seed/${entry.name}` });
      }
    }
  }

  const pad = (n: number) => String(n).padStart(2, "0");
  return {
    template: {
      schema_version: "1.0",
      name: props.name,
      saved_at: `${props.now.getUTCFullYear()}-${pad(props.now.getUTCMonth() + 1)}-${pad(props.now.getUTCDate())}`,
      saved_at_sha: headSha({ root: props.root }),
      source_project: manifest.project,
      harness_version: HARNESS_VERSION,
      prefilled,
    },
    standardsSeedCopies,
    skillsSeedCopies,
  };
}

/**
 * `harness template <save|list|inspect|delete>` dispatcher (wired into the cli.ts table).
 * list/inspect/delete never require a project root.
 *
 * @param props.args - Tokens after "template".
 * @param props.cwd - Working directory.
 * @param props.stdout - Line sink.
 * @returns EXIT code.
 */
export function runTemplate(props: { args: string[]; cwd: string; stdout: (s: string) => void }): number {
  const [sub, ...rest] = props.args;
  const shortSha = (sha: string) => (sha === "" ? "-" : sha.slice(0, 7));

  switch (sub) {
    case "save": {
      const parsed = parseArgs({ argv: rest, spec: { positionals: ["name"], flags: ["force"] } });
      const name = parsed.positionals["name"] as string;
      const root = resolveProjectRoot({ cwd: props.cwd });
      const { manifest } = loadManifest({ root });
      const dir = templateDir({ name });
      if (existsSync(dir) && parsed.flags["force"] !== true) {
        throw new HarnessError("template-exists", `template "${name}" exists`, { hint: `harness template save ${name} --force` });
      }
      const derived = deriveTemplate({ root, manifest, name, embeddedSkillsDir: EMBEDDED_SKILLS_DIR, now: new Date() });
      rmSync(dir, { recursive: true, force: true });
      writeFileAtomic({ path: join(dir, "template.json"), content: `${JSON.stringify(derived.template, null, 2)}\n` });
      for (const copy of [...derived.standardsSeedCopies, ...derived.skillsSeedCopies]) {
        cpSync(join(root, copy.from), join(dir, copy.to), { recursive: true });
        props.stdout(`seeded: ${copy.to}`);
      }
      props.stdout(`saved template ${name} → ${dir}`);
      return EXIT.OK;
    }

    case "list": {
      parseArgs({ argv: rest, spec: {} });
      const templates = listTemplates();
      if (templates.length === 0) {
        props.stdout("no templates saved");
        return EXIT.OK;
      }
      for (const t of templates) {
        props.stdout(t.invalid === true ? `${t.name}  (invalid template.json)` : `${t.name}  ${t.saved_at}  ${shortSha(t.saved_at_sha)}  ${t.source_project}`);
      }
      return EXIT.OK;
    }

    case "inspect": {
      const parsed = parseArgs({ argv: rest, spec: { positionals: ["name"] } });
      const { template, standardsSeed, skillsSeed } = loadTemplate({ name: parsed.positionals["name"] as string });
      const phaseDesc: Record<string, string> = {
        "2": "2 (team)",
        "3": "3 (domains)",
        "6": "6 (dependencies)",
        "7": "7 (workflow/modules/platforms)",
      };
      const phases = Object.keys(template.prefilled).sort().map((k) => phaseDesc[k] ?? k);
      props.stdout(`template: ${template.name}`);
      props.stdout(`source:   ${template.source_project} (saved ${template.saved_at} at ${shortSha(template.saved_at_sha)} by harness ${template.harness_version})`);
      props.stdout(`prefilled phases: ${phases.length > 0 ? phases.join(", ") : "(none)"}`);
      props.stdout(`standards_seed: ${standardsSeed.length > 0 ? standardsSeed.join(", ") : "(none)"}`);
      props.stdout(`skills_seed: ${skillsSeed.length > 0 ? skillsSeed.join(", ") : "(none)"}`);
      return EXIT.OK;
    }

    case "delete": {
      const parsed = parseArgs({ argv: rest, spec: { positionals: ["name"] } });
      const name = parsed.positionals["name"] as string;
      const dir = templateDir({ name });
      // Refuse to rm an arbitrary dir — only a real template (has template.json) is deletable.
      if (!existsSync(join(dir, "template.json"))) {
        throw new HarnessError("template-not-found", `template "${name}" not found`, { hint: "harness template list" });
      }
      rmSync(dir, { recursive: true, force: true });
      props.stdout(`deleted template ${name}`);
      return EXIT.OK;
    }

    default:
      throw new HarnessError("usage", "template: save|list|inspect|delete");
  }
}
