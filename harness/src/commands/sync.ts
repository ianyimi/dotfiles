import { existsSync, lstatSync, readFileSync, readdirSync, rmSync, rmdirSync, unlinkSync } from "node:fs";
import { dirname, join } from "node:path";
import { parse as parseYaml, stringify as stringifyYaml } from "yaml";
import { EXIT, HarnessError } from "../lib/errors.ts";
import { parseFrontmatter } from "../lib/frontmatter.ts";
import { checkSymlink, ensureSymlink, sha256, walk, writeFileAtomic } from "../lib/fsx.ts";
import { headSha } from "../lib/git.ts";
import { loadManifest, type HarnessManifest } from "../lib/manifest.ts";
import { parseNamingRules } from "../lib/namingRules.ts";
import type { Reporter } from "../lib/output.ts";
import { AGENT_DIR, P } from "../lib/paths.ts";
import { loadSyncManifest, saveSyncManifest, type SyncEntry } from "../lib/syncManifest.ts";
import { claudeAdapter, CLAUDE_MD, CLAUDE_SETTINGS_FRAGMENT, commandShim } from "../platforms/claude.ts";
import { OMP_CONFIG_FILE, OMP_DISABLED_PROVIDERS, ompAdapter, ompConfigFile, promptShim } from "../platforms/omp.ts";
import type { ContextRule, PlatformAdapter, PlatformId, ProjectContext, SkillInfo } from "../platforms/types.ts";

/** Adapter registry — the single place platform.ts and sync share. */
export const ADAPTERS: Record<PlatformId, PlatformAdapter> = { omp: ompAdapter, claude: claudeAdapter };

/** Paths applied via key-level merge instead of whole-file D10 hashing.
 * `.omp/config.yml` is CO-OWNED: OMP itself persists project-level `modelRoles` there,
 * so whole-file management would flag its writes as user-modified conflicts forever. */
export const MERGE_PATHS = new Set([".claude/settings.json", ".omp/config.yml"]);

/**
 * Merges the harness-managed keys into .omp/config.yml, preserving everything OMP or the
 * developer wrote. Managed keys: `disabledProviders` (whole array), `advisor.enabled`,
 * and the five tier-mapped entries under `modelRoles` (slow/task/smol/tiny/advisor —
 * skipped for "@role" tier refs). Other modelRoles/advisor keys are preserved.
 *
 * @param props.existingText - Current file text, or null when the file does not exist.
 * @param props.advisor - manifest.models.advisor.
 * @param props.tiers - manifest.models.tiers.
 * @returns merged: new full text (canonical template when creating; comment-free YAML when
 *   merging), or null when byte-identical already; conflict: set when the file is not valid
 *   YAML — caller reports, never writes.
 */
export function mergeManagedOmpConfig(props: {
  existingText: string | null;
  advisor: boolean;
  tiers: { frontier: string; standard: string; cheap: string };
}): { merged: string | null; conflict?: string } {
  // Creation goes through the same normalize-and-merge path as updates so the very next
  // sync is byte-identical (the commented bootstrap template normalizes once, harmlessly).
  let doc: Record<string, unknown>;
  try {
    const parsed = props.existingText === null ? {} : (parseYaml(props.existingText) as unknown);
    if (parsed !== null && (typeof parsed !== "object" || Array.isArray(parsed))) throw new Error("not a mapping");
    doc = (parsed ?? {}) as Record<string, unknown>;
  } catch {
    return { merged: null, conflict: "not valid YAML — fix or delete it, then re-run harness sync" };
  }

  doc["disabledProviders"] = [...OMP_DISABLED_PROVIDERS];
  const advisorBlock = (typeof doc["advisor"] === "object" && doc["advisor"] !== null && !Array.isArray(doc["advisor"])
    ? doc["advisor"]
    : {}) as Record<string, unknown>;
  advisorBlock["enabled"] = props.advisor;
  doc["advisor"] = advisorBlock;

  const roles = (typeof doc["modelRoles"] === "object" && doc["modelRoles"] !== null && !Array.isArray(doc["modelRoles"])
    ? doc["modelRoles"]
    : {}) as Record<string, unknown>;
  const managed: Array<[string, string]> = [
    ["slow", props.tiers.frontier],
    ["task", props.tiers.standard],
    ["smol", props.tiers.cheap],
    ["tiny", props.tiers.cheap],
    ["advisor", props.tiers.cheap],
  ];
  for (const [role, model] of managed) {
    if (!model.startsWith("@")) roles[role] = model;
  }
  if (Object.keys(roles).length > 0) doc["modelRoles"] = roles;

  const merged = `# MANAGED by harness sync — harness enforces disabledProviders, advisor.enabled,\n# and the tier-mapped modelRoles; every other key here is preserved.\n${stringifyYaml(doc)}`;
  return { merged: merged === props.existingText ? null : merged };
}

const GITIGNORE_OPEN = "# >>> harness (managed by `harness sync`) >>>";
const GITIGNORE_CLOSE = "# <<< harness <<<";

/**
 * Compiles context rules from standards inventory + naming scopes (master §7.2). Pure.
 *
 * @param props.manifest - Loaded manifest (standards_domains gives domain order).
 * @param props.standards - Every docs/standards file: .agent-relative path + parsed applies_to.
 * @param props.namingScopes - Union input from naming rules block scopes; null when the module
 *   is off or the file is absent.
 * @returns Ordered rules plus the exact context-rules.yaml text (byte-stable) and warnings.
 */
export function buildContextRules(props: {
  manifest: HarnessManifest;
  standards: Array<{ path: string; appliesTo: string[] }>;
  namingScopes: string[] | null;
}): { rules: ContextRule[]; yaml: string; warnings: string[] } {
  const rules: ContextRule[] = [];
  const warnings: string[] = [];

  for (const domain of props.manifest.standards_domains) {
    const domainPrefix = `docs/standards/${domain}/`;
    const files = props.standards
      .filter((s) => s.path.startsWith(domainPrefix) && s.path.endsWith(".md"))
      .sort((a, b) => (a.path < b.path ? -1 : 1));
    const inject = files.map((f) => f.path);
    if (inject.length === 0) continue; // empty domain — skip silently
    const when = [...new Set(files.flatMap((f) => f.appliesTo))].sort();
    if (when.length === 0) {
      warnings.push(`domain ${domain} has no applies_to globs — rule omitted (add applies_to frontmatter)`);
      continue;
    }
    rules.push({ id: `std-${domain}`, when, inject });
  }

  if (props.namingScopes !== null && props.namingScopes.length > 0) {
    rules.push({
      id: "naming",
      when: [...new Set(props.namingScopes)].sort(),
      inject: ["docs/standards/naming-conventions.md"],
    });
  }

  const lines = [
    "# GENERATED by harness sync — do not edit. Source: standards folders + naming rule scopes.",
    "version: 1",
  ];
  if (rules.length === 0) {
    lines.push("rules: []");
  } else {
    lines.push("rules:");
    for (const rule of rules) {
      lines.push(`  - id: ${rule.id}`);
      lines.push(`    when: [${rule.when.map((w) => JSON.stringify(w)).join(", ")}]`);
      lines.push("    inject:");
      for (const path of rule.inject) lines.push(`      - ${path}`);
    }
  }
  return { rules, yaml: `${lines.join("\n")}\n`, warnings };
}

/**
 * Loads everything adapters need. The ONLY I/O gateway for planning (adapters stay pure).
 *
 * @param props.root - Absolute project root.
 * @returns Fully-populated ProjectContext plus compilation warnings for the reporter.
 */
export function loadProjectContext(props: { root: string }): {
  ctx: ProjectContext;
  warnings: string[];
} {
  const { manifest } = loadManifest({ root: props.root });

  const skills: SkillInfo[] = [];
  const skillsAbs = join(props.root, P.skills);
  if (existsSync(skillsAbs)) {
    for (const entry of readdirSync(skillsAbs, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      if (!entry.isDirectory()) continue;
      const skillMd = join(skillsAbs, entry.name, "SKILL.md");
      if (!existsSync(skillMd)) continue;
      const { data } = parseFrontmatter({ text: readFileSync(skillMd, "utf8") });
      skills.push({
        name: typeof data["name"] === "string" && data["name"] !== "" ? (data["name"] as string) : entry.name,
        dir: `${P.skills}/${entry.name}`,
        frontmatter: data,
      });
    }
  }

  const standardsAbs = join(props.root, P.standards);
  const standardsFiles = existsSync(standardsAbs)
    ? walk({ root: standardsAbs }).map((f) => `docs/standards/${f}`)
    : [];
  const standards = standardsFiles.map((path) => {
    const text = readFileSync(join(props.root, AGENT_DIR, path), "utf8");
    const appliesTo = parseFrontmatter({ text }).data["applies_to"];
    return { path, appliesTo: Array.isArray(appliesTo) ? (appliesTo as string[]) : [] };
  });

  let namingScopes: string[] | null = null;
  const namingPath = join(standardsAbs, "naming-conventions.md");
  if (manifest.modules.naming_conventions && existsSync(namingPath)) {
    try {
      namingScopes = [...new Set(parseNamingRules({ text: readFileSync(namingPath, "utf8") }).flatMap((r) => r.scope))];
    } catch {
      namingScopes = null; // unparseable rules block — naming-violations check owns reporting
    }
  }

  const antiPatternRegexes: string[] = [];
  const apPath = join(standardsAbs, "anti-patterns.md");
  if (existsSync(apPath)) {
    for (const line of readFileSync(apPath, "utf8").split("\n")) {
      const m = line.match(/^ {2}pattern: (.+)$/);
      if (m !== null) antiPatternRegexes.push((m[1] as string).trim());
    }
  }

  const built = buildContextRules({ manifest, standards, namingScopes });
  return {
    ctx: {
      root: props.root,
      manifest,
      skills,
      standardsFiles,
      contextRules: built.rules,
      antiPatternRegexes,
    },
    warnings: built.warnings,
  };
}

/**
 * Merges the managed settings fragment into a user-owned JSON file, touching ONLY the keys sync
 * manages (D10). Managed today: the one hooks.SessionStart entry whose command is
 * "harness doctor". Everything else is preserved.
 *
 * @param props.existingText - Current file text, or null when the file does not exist.
 * @param props.fragment - The managed fragment (CLAUDE_SETTINGS_FRAGMENT shape).
 * @returns merged: full new file text, or null when no write is needed; conflict: set instead
 *   when existing is not parseable JSON — caller reports, never writes.
 */
export function mergeManagedJson(props: {
  existingText: string | null;
  fragment: Record<string, unknown>;
}): { merged: string | null; conflict?: string } {
  const stringify = (v: unknown) => `${JSON.stringify(v, null, 2)}\n`;
  if (props.existingText === null) return { merged: stringify(props.fragment) };

  let obj: Record<string, unknown>;
  try {
    obj = JSON.parse(props.existingText) as Record<string, unknown>;
    if (typeof obj !== "object" || obj === null || Array.isArray(obj)) throw new Error("not an object");
  } catch {
    return { merged: null, conflict: "not valid JSON — fix or delete it, then re-run harness sync" };
  }

  const hooks = (obj["hooks"] ??= {}) as Record<string, unknown>;
  if (hooks["SessionStart"] === undefined) hooks["SessionStart"] = [];
  const sessionStart = hooks["SessionStart"];
  if (!Array.isArray(sessionStart)) {
    return { merged: null, conflict: "hooks.SessionStart is not an array — fix it, then re-run harness sync" };
  }
  const hasDoctor = sessionStart.some((entry) => {
    const inner = (entry as Record<string, unknown>)?.["hooks"];
    return Array.isArray(inner) && inner.some((h) => (h as Record<string, unknown>)?.["command"] === "harness doctor");
  });
  if (!hasDoctor) {
    const fragmentHooks = (props.fragment["hooks"] as Record<string, unknown>)["SessionStart"] as unknown[];
    sessionStart.push(...fragmentHooks);
  }
  const merged = stringify(obj);
  return { merged: merged === props.existingText ? null : merged };
}

/**
 * Rewrites the managed marker block in the project .gitignore, preserving user lines byte-exact.
 *
 * @param props.existingText - Current .gitignore text or null.
 * @param props.lines - Desired managed lines (caller sorts them).
 * @returns New full text, or null when no change is needed.
 */
export function updateGitignoreBlock(props: { existingText: string | null; lines: string[] }): string | null {
  const block =
    props.lines.length > 0 ? `${GITIGNORE_OPEN}\n${props.lines.join("\n")}\n${GITIGNORE_CLOSE}\n` : null;

  if (props.existingText === null) {
    return block; // null lines + null file → null (no change)
  }
  const text = props.existingText;
  const open = text.indexOf(GITIGNORE_OPEN);
  if (open === -1) {
    if (block === null) return null;
    const sep = text === "" || text.endsWith("\n\n") ? "" : text.endsWith("\n") ? "\n" : "\n\n";
    return `${text}${sep}${block}`;
  }
  const close = text.indexOf(GITIGNORE_CLOSE, open);
  const blockEnd = close === -1 ? text.length : close + GITIGNORE_CLOSE.length + 1;
  const before = text.slice(0, open);
  const after = text.slice(Math.min(blockEnd, text.length));
  const next = block === null ? `${before}${after}` : `${before}${block}${after}`;
  return next === text ? null : next;
}

/**
 * Pre-init bridge bootstrap, run by `harness install` (09 live-test fix): a fresh project has
 * no manifest yet, so `harness sync` cannot run — but the platforms must still see the init
 * skill (`/init` on OMP, `/harness-init` on Claude Code) or the developer cannot start the
 * interview from their agent. Writes the minimal bridge (skills symlinks, init shims, the
 * OMP double-load guard, CLAUDE.md, gitignore block) with sync-manifest entries so the first
 * full sync adopts everything hash-clean and prunes whatever the chosen platforms drop.
 *
 * @param props.root - Project root (post-scaffold: .agent/skills/init must exist).
 * @param props.stdout - Line sink; prints only what it actually created (quiet when complete).
 * @returns Nothing.
 */
export function bootstrapBridges(props: { root: string; stdout: (s: string) => void }): void {
  const initSkillPath = join(props.root, P.skills, "init", "SKILL.md");
  if (!existsSync(initSkillPath)) return; // nothing to shim — scaffold failed upstream
  const description = parseFrontmatter({ text: readFileSync(initSkillPath, "utf8") }).data["description"];
  if (typeof description !== "string" || description === "") return;

  const prev = loadSyncManifest({ root: props.root });
  const entries = new Map(prev.entries.map((e) => [e.path, e]));

  const files: Array<{ path: string; content: string; platform: PlatformId }> = [
    { path: ".omp/prompts/harness-init.md", content: promptShim({ name: "init", description }), platform: "omp" },
    { path: ".omp/config.yml", content: OMP_CONFIG_FILE, platform: "omp" },
    { path: ".claude/commands/harness-init.md", content: commandShim({ name: "init", description }), platform: "claude" },
    { path: ".claude/CLAUDE.md", content: CLAUDE_MD, platform: "claude" },
  ];
  for (const f of files) {
    const abs = join(props.root, f.path);
    if (!existsSync(abs)) {
      writeFileAtomic({ path: abs, content: f.content });
      props.stdout(`bridge: created ${f.path}`);
    } // existing-but-different files are left alone — the first full sync reconciles/reports
    entries.set(f.path, { path: f.path, kind: "generated", target_or_hash: sha256({ text: f.content }), platform: f.platform });
  }

  const symlinks: Array<{ linkPath: string; targetPath: string; platform: PlatformId }> = [
    { linkPath: ".omp/skills", targetPath: ".agent/skills", platform: "omp" },
    { linkPath: ".omp/AGENTS.md", targetPath: ".agent/AGENTS.md", platform: "omp" },
    { linkPath: ".claude/skills", targetPath: ".agent/skills", platform: "claude" },
  ];
  for (const s of symlinks) {
    const result = ensureSymlink({ linkPath: join(props.root, s.linkPath), targetPath: join(props.root, s.targetPath) });
    if (result === "created" || result === "replaced") props.stdout(`bridge: linked ${s.linkPath} → ${s.targetPath}`);
    if (result !== "conflict") {
      entries.set(s.linkPath, { path: s.linkPath, kind: "symlink", target_or_hash: s.targetPath, platform: s.platform });
    }
  }

  const lines = [".agent/dependencies/*", ".claude/", ".omp/"];
  const gitignoreAbs = join(props.root, ".gitignore");
  const next = updateGitignoreBlock({ existingText: existsSync(gitignoreAbs) ? readFileSync(gitignoreAbs, "utf8") : null, lines });
  if (next !== null) writeFileAtomic({ path: gitignoreAbs, content: next });
  for (const line of lines) {
    const platform: PlatformId | "core" = line === ".claude/" ? "claude" : line === ".omp/" ? "omp" : "core";
    entries.set(`.gitignore#${line}`, { path: `.gitignore#${line}`, kind: "gitignore-line", target_or_hash: line, platform });
  }

  saveSyncManifest({
    root: props.root,
    syncManifest: { version: 1, generated_at_sha: headSha({ root: props.root }), entries: [...entries.values()] },
  });
}

/**
 * One planned filesystem operation the sync engine would perform. Produced by {@link planSync}
 * (read-only) and executed by {@link applySync}. `harness fetch sync` renders these without
 * applying, so `/harness-pull` can preview bridge changes before anything is written.
 */
export type SyncChange =
  | { op: "create"; path: string; content: string; platform: PlatformId | "core" }
  | { op: "update"; path: string; content: string; platform: PlatformId | "core" }
  | { op: "unchanged"; path: string; platform: PlatformId | "core" }
  | { op: "merge"; path: string; platform: PlatformId | "core"; merged: string | null; had: boolean }
  | { op: "symlink"; path: string; targetPath: string; platform: PlatformId; result: "created" | "replaced" | "ok" }
  | { op: "delete"; path: string; symlink: boolean; present: boolean }
  | { op: "gitignore"; nextText: string | null }
  | { op: "conflict"; path: string; message: string; hint?: string };

/** The full read-only result of planning a sync: what would change + the resulting manifest. */
export interface SyncPlan {
  changes: SyncChange[];
  nextEntries: SyncEntry[];
  warnings: string[];
}

/**
 * Read side of the sync engine (master §9.1 flow + D10 conflict rules): computes every
 * filesystem operation a sync WOULD perform, WITHOUT writing anything. Reads disk + the prior
 * sync manifest to make the same create/update/unchanged/conflict/delete decisions runSync makes.
 *
 * @param props.root - Absolute project root.
 * @returns The planned changes, the manifest entries that would be saved, and context warnings.
 */
export function planSync(props: { root: string }): SyncPlan {
  const { ctx, warnings } = loadProjectContext({ root: props.root });
  const prev = loadSyncManifest({ root: props.root });
  const prevByPath = new Map(prev.entries.map((e) => [e.path, e]));

  const contextRulesYaml = buildContextRules({
    manifest: ctx.manifest,
    standards: ctx.standardsFiles.map((path) => {
      const text = readFileSync(join(props.root, AGENT_DIR, path), "utf8");
      const appliesTo = parseFrontmatter({ text }).data["applies_to"];
      return { path, appliesTo: Array.isArray(appliesTo) ? (appliesTo as string[]) : [] };
    }),
    namingScopes: ctx.contextRules?.some((r) => r.id === "naming")
      ? (ctx.contextRules.find((r) => r.id === "naming")?.when ?? null)
      : null,
  }).yaml;

  interface DesiredFile {
    path: string;
    content: string;
    platform: PlatformId | "core";
  }
  const files: DesiredFile[] = [{ path: P.contextRules, content: contextRulesYaml, platform: "core" }];
  const symlinks: Array<{ linkPath: string; targetPath: string; platform: PlatformId }> = [];
  const gitignoreLines: string[] = [".agent/dependencies/*"];
  const gitignorePlatform = new Map<string, PlatformId | "core">([[".agent/dependencies/*", "core"]]);

  for (const id of ctx.manifest.platforms.active) {
    const adapter = ADAPTERS[id];
    if (adapter === undefined) throw new HarnessError("unknown-platform", `no adapter for platform "${id}"`);
    const plan = adapter.plan({ ctx });
    for (const f of plan.files) files.push({ ...f, platform: id });
    for (const s of plan.symlinks) symlinks.push({ ...s, platform: id });
    for (const line of plan.gitignoreLines) {
      gitignoreLines.push(line);
      gitignorePlatform.set(line, id);
    }
  }
  files.sort((a, b) => (a.path < b.path ? -1 : 1));

  const changes: SyncChange[] = [];
  const nextEntries: SyncEntry[] = [];

  // FILES
  for (const f of files) {
    const abs = join(props.root, f.path);
    const diskText = existsSync(abs) && lstatSync(abs).isFile() ? readFileSync(abs, "utf8") : null;
    const prevEntry = prevByPath.get(f.path);

    if (MERGE_PATHS.has(f.path)) {
      const result =
        f.path === ".omp/config.yml"
          ? mergeManagedOmpConfig({ existingText: diskText, advisor: ctx.manifest.models.advisor, tiers: ctx.manifest.models.tiers })
          : mergeManagedJson({ existingText: diskText, fragment: CLAUDE_SETTINGS_FRAGMENT });
      if (result.conflict !== undefined) {
        changes.push({ op: "conflict", path: f.path, message: result.conflict });
        if (prevEntry !== undefined) nextEntries.push(prevEntry);
        continue;
      }
      const finalText = result.merged ?? (diskText as string);
      changes.push({ op: "merge", path: f.path, platform: f.platform, merged: result.merged, had: diskText !== null });
      nextEntries.push({ path: f.path, kind: "generated", target_or_hash: sha256({ text: finalText }), platform: f.platform });
      continue;
    }

    if (diskText === null) {
      changes.push({ op: "create", path: f.path, content: f.content, platform: f.platform });
    } else if (prevEntry !== undefined && sha256({ text: diskText }) === prevEntry.target_or_hash) {
      changes.push(
        diskText === f.content
          ? { op: "unchanged", path: f.path, platform: f.platform }
          : { op: "update", path: f.path, content: f.content, platform: f.platform },
      );
    } else if (prevEntry !== undefined) {
      changes.push({
        op: "conflict",
        path: f.path,
        message: "user-modified managed file — left in place",
        hint: `move your edits into .agent/ and delete ${f.path}, then re-run harness sync`,
      });
      nextEntries.push(prevEntry); // keep the stale entry (design decision)
      continue;
    } else {
      changes.push({ op: "conflict", path: f.path, message: "exists but is not managed by harness — left untouched" });
      continue;
    }
    nextEntries.push({ path: f.path, kind: "generated", target_or_hash: sha256({ text: f.content }), platform: f.platform });
  }

  // SYMLINKS
  for (const s of symlinks) {
    const result = checkSymlink({ linkPath: join(props.root, s.linkPath), targetPath: join(props.root, s.targetPath) });
    if (result === "conflict") {
      changes.push({ op: "conflict", path: s.linkPath, message: "exists but is not a harness symlink — left untouched" });
      continue;
    }
    changes.push({ op: "symlink", path: s.linkPath, targetPath: s.targetPath, platform: s.platform, result });
    nextEntries.push({ path: s.linkPath, kind: "symlink", target_or_hash: s.targetPath, platform: s.platform });
  }

  // DELETIONS — formerly-managed paths absent from the desired plan.
  const desiredPaths = new Set([...files.map((f) => f.path), ...symlinks.map((s) => s.linkPath)]);
  for (const entry of prev.entries) {
    if (entry.kind === "gitignore-line") continue; // handled by the block rewrite
    if (desiredPaths.has(entry.path)) continue;
    const abs = join(props.root, entry.path);
    let st;
    try {
      st = lstatSync(abs);
    } catch {
      changes.push({ op: "delete", path: entry.path, symlink: entry.kind === "symlink", present: false });
      continue;
    }
    if (entry.kind === "symlink") {
      if (st.isSymbolicLink()) {
        changes.push({ op: "delete", path: entry.path, symlink: true, present: true });
      } else {
        changes.push({ op: "conflict", path: entry.path, message: "was managed, now removed from plan, but is no longer a symlink — delete manually" });
        nextEntries.push(entry);
      }
    } else {
      const diskText = st.isFile() ? readFileSync(abs, "utf8") : null;
      if (diskText !== null && sha256({ text: diskText }) === entry.target_or_hash) {
        changes.push({ op: "delete", path: entry.path, symlink: false, present: true });
      } else {
        changes.push({ op: "conflict", path: entry.path, message: "was managed, now removed from plan, but user-modified — delete manually" });
        nextEntries.push(entry);
      }
    }
  }

  // GITIGNORE
  const gitignoreAbs = join(props.root, ".gitignore");
  const sortedLines = [...new Set(gitignoreLines)].sort();
  const gitignoreText = existsSync(gitignoreAbs) ? readFileSync(gitignoreAbs, "utf8") : null;
  changes.push({ op: "gitignore", nextText: updateGitignoreBlock({ existingText: gitignoreText, lines: sortedLines }) });
  for (const line of sortedLines) {
    nextEntries.push({
      path: `.gitignore#${line}`,
      kind: "gitignore-line",
      target_or_hash: line,
      platform: gitignorePlatform.get(line) ?? "core",
    });
  }

  return { changes, nextEntries, warnings };
}

/**
 * Write side of the sync engine: executes a {@link SyncPlan}, emitting one reporter line per
 * created/updated/deleted/conflict, pruning emptied bridge dirs, and saving the sync manifest.
 *
 * @param props.root - Absolute project root.
 * @param props.plan - The plan from {@link planSync}.
 * @param props.reporter - Sink for per-change lines + the final summary.
 * @returns EXIT.FINDINGS when any conflict was reported, else EXIT.OK.
 */
export function applySync(props: { root: string; plan: SyncPlan; reporter: Reporter }): number {
  for (const w of props.plan.warnings) props.reporter.warn(w, "sync");
  let created = 0;
  let updated = 0;
  let unchanged = 0;
  let deleted = 0;
  let conflicts = 0;
  const emptyDirCandidates = new Set<string>();

  for (const c of props.plan.changes) {
    const abs = c.op === "conflict" || c.op === "gitignore" ? "" : join(props.root, c.path);
    switch (c.op) {
      case "create":
        writeFileAtomic({ path: abs, content: c.content });
        created++;
        props.reporter.info(`created ${c.path}`, "sync");
        break;
      case "update":
        writeFileAtomic({ path: abs, content: c.content });
        updated++;
        props.reporter.info(`updated ${c.path}`, "sync");
        break;
      case "unchanged":
        unchanged++;
        break;
      case "merge":
        if (c.merged !== null) {
          writeFileAtomic({ path: abs, content: c.merged });
          if (c.had) {
            updated++;
            props.reporter.info(`updated ${c.path}`, "sync");
          } else {
            created++;
            props.reporter.info(`created ${c.path}`, "sync");
          }
        } else {
          unchanged++;
        }
        break;
      case "symlink": {
        if (c.result === "ok") {
          unchanged++;
          break;
        }
        ensureSymlink({ linkPath: abs, targetPath: join(props.root, c.targetPath) });
        if (c.result === "created") {
          created++;
          props.reporter.info(`created ${c.path} → ${c.targetPath}`, "sync");
        } else {
          updated++;
          props.reporter.info(`repaired ${c.path} → ${c.targetPath}`, "sync");
        }
        break;
      }
      case "delete":
        if (c.present) {
          if (c.symlink) unlinkSync(abs);
          else rmSync(abs);
          props.reporter.info(`deleted ${c.path}`, "sync");
        }
        deleted++;
        emptyDirCandidates.add(dirname(abs));
        break;
      case "gitignore":
        if (c.nextText !== null) {
          writeFileAtomic({ path: join(props.root, ".gitignore"), content: c.nextText });
          props.reporter.info("updated .gitignore managed block", "sync");
        }
        break;
      case "conflict":
        conflicts++;
        props.reporter.warn(`${c.path}: ${c.message}`, "sync", c.hint);
        break;
    }
  }

  // Prune now-empty bridge dirs, deepest first.
  for (const dir of [...emptyDirCandidates].sort((a, b) => b.length - a.length)) {
    let current = dir;
    while (current.startsWith(props.root) && current !== props.root) {
      try {
        if (readdirSync(current).length > 0) break;
        rmdirSync(current);
      } catch {
        break;
      }
      current = dirname(current);
    }
  }

  saveSyncManifest({
    root: props.root,
    syncManifest: { version: 1, generated_at_sha: headSha({ root: props.root }), entries: props.plan.nextEntries },
  });
  props.reporter.info(
    `sync: ${created} created, ${updated} updated, ${unchanged} unchanged, ${deleted} deleted, ${conflicts} conflicts`,
    "sync",
  );
  return conflicts > 0 ? EXIT.FINDINGS : EXIT.OK;
}

/**
 * The adapter-agnostic sync engine (master §9.1 flow + D10 conflict rules): plan, then apply.
 *
 * @param props.root - Absolute project root.
 * @param props.reporter - Sink; one line per created/updated/deleted/conflict + final summary.
 * @returns EXIT.FINDINGS when any conflict was reported, else EXIT.OK.
 */
export function runSync(props: { root: string; reporter: Reporter }): number {
  return applySync({ root: props.root, plan: planSync({ root: props.root }), reporter: props.reporter });
}
