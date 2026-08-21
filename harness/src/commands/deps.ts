import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { EXIT, HarnessError } from "../lib/errors.ts";
import { parseArgs } from "../lib/args.ts";
import { loadRegistry, saveRegistry, serializeRegistry, type RegistryRow } from "../lib/depsRegistry.ts";
import { lsRemoteTags, shallowCloneAtRef } from "../lib/git.ts";
import { loadManifest, saveManifest, type DependencyPin } from "../lib/manifest.ts";
import { Reporter } from "../lib/output.ts";
import { P, resolveProjectRoot } from "../lib/paths.ts";

export const DEP_GITIGNORE = "*\n!.gitignore\n!registry.md\n";

/**
 * Maps a package name to its clone dirname: strip leading "@", "/" → "__" (fs-safe,
 * collision-free).
 *
 * @param props.pkg - Package name, e.g. "@tanstack/form".
 * @returns Dirname, e.g. "tanstack__form".
 * @example depDirname({ pkg: "convex" }) // "convex"
 */
export function depDirname(props: { pkg: string }): string {
  return props.pkg.replace(/^@/, "").replaceAll("/", "__");
}

/**
 * Resolves DependencyPin.repo to a cloneable URL.
 *
 * @param props.repo - Host-relative ("github.com/org/repo"), full URL, or absolute local path.
 * @returns https://-prefixed URL, or the explicit/local form verbatim.
 */
export function resolveRepoUrl(props: { repo: string }): string {
  return props.repo.includes("://") || props.repo.startsWith("/") ? props.repo : `https://${props.repo}`;
}

const VERSION_RE = /\d+\.\d+(?:\.\d+)?/;

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Reads the version currently pinned for a package in the PROJECT manifest (not .agent/).
 * Sources in order: package.json dependencies/devDependencies, Cargo.toml, pyproject.toml.
 * Unreadable/unparseable manifests are skipped silently — doctor must survive broken projects.
 *
 * @param props.root - Project root.
 * @param props.pkg - Name as it appears in that manifest.
 * @returns Version substring of the pin ("^1.1.0" → "1.1.0"), or null when not found or the
 *   value has no version substring ("workspace:*", "*", git URLs).
 */
export function readProjectPin(props: { root: string; pkg: string }): string | null {
  try {
    const pkgJson = JSON.parse(readFileSync(join(props.root, "package.json"), "utf8")) as {
      dependencies?: Record<string, string>;
      devDependencies?: Record<string, string>;
    };
    const value = pkgJson.dependencies?.[props.pkg] ?? pkgJson.devDependencies?.[props.pkg];
    if (value !== undefined) {
      const m = value.match(VERSION_RE);
      // A "workspace:*" entry must not shadow a Cargo pin — keep looking on no substring.
      if (m !== null) return m[0];
    }
  } catch {
    // skip silently
  }

  if (!props.pkg.includes("/")) {
    try {
      const cargo = readFileSync(join(props.root, "Cargo.toml"), "utf8");
      const re = new RegExp(`^\\s*${escapeRe(props.pkg)}\\s*=\\s*(?:"([^"]+)"|\\{[^}]*version\\s*=\\s*"([^"]+)")`, "m");
      const m = cargo.match(re);
      const value = m?.[1] ?? m?.[2];
      const sub = value?.match(VERSION_RE);
      if (sub != null) return sub[0];
    } catch {
      // skip silently
    }
    try {
      const pyproject = readFileSync(join(props.root, "pyproject.toml"), "utf8");
      const re = new RegExp(`"${escapeRe(props.pkg)}\\s*[=><~!^]{1,2}=?\\s*([^",]+)"`);
      const sub = pyproject.match(re)?.[1]?.match(VERSION_RE);
      if (sub != null) return sub[0];
    } catch {
      // skip silently
    }
  }
  return null;
}

/**
 * Resolves the tag to clone for pkg@version (candidate order per proposal §9).
 *
 * @param props.repoUrl - Cloneable URL.
 * @param props.pkg - Package name.
 * @param props.version - Version substring, e.g. "1.1.0".
 * @returns Matching tag name, or null when nothing matches (caller clones the default branch).
 * @throws {HarnessError} propagated "git-ls-remote-failed" — caller decides warn-vs-fail.
 */
export function resolveTag(props: { repoUrl: string; pkg: string; version: string }): string | null {
  const tags = lsRemoteTags({ repoUrl: props.repoUrl });
  const candidates = [`v${props.version}`, props.version, `${props.pkg}@${props.version}`];
  if (props.pkg.includes("/")) {
    candidates.push(`${props.pkg.split("/").pop() as string}@${props.version}`);
  }
  for (const c of candidates) {
    if (tags.includes(c)) return c;
  }
  // Never guess between monorepo packages: only a UNIQUE suffix match wins.
  const matches = tags.filter((t) => t.endsWith(`@${props.version}`) || t.endsWith(`-${props.version}`));
  return matches.length === 1 ? (matches[0] as string) : null;
}

/**
 * Clones one pinned dependency at its best-matching tag. Never throws for repo problems —
 * warns via the reporter and returns null so a batch run always completes (proposal §9).
 *
 * @param props.root - Project root.
 * @param props.pin - DependencyPin (package, version, repo).
 * @param props.reporter - Sink for ok/warn lines.
 * @returns The new registry row, or null when the repo was unreachable.
 */
export function cloneOne(props: { root: string; pin: DependencyPin; reporter: Reporter }): RegistryRow | null {
  const { pin } = props;
  const url = resolveRepoUrl({ repo: pin.repo });
  const dest = join(props.root, P.dependencies, depDirname({ pkg: pin.package }));

  const gitignorePath = join(props.root, P.dependencies, ".gitignore");
  if (!existsSync(gitignorePath)) writeFileSync(gitignorePath, DEP_GITIGNORE);

  let tag: string | null;
  let sha: string;
  try {
    tag = resolveTag({ repoUrl: url, pkg: pin.package, version: pin.version });
    sha = shallowCloneAtRef({ repoUrl: url, ...(tag !== null ? { ref: tag } : {}), dest });
  } catch (e) {
    const msg = e instanceof HarnessError ? e.message : (e as Error).message;
    props.reporter.warn(`${pin.package}: ${msg} — skipped`, "deps-clone");
    return null;
  }

  if (tag !== null) {
    props.reporter.ok(`${pin.package} ${pin.version} cloned at ${tag}`, "deps-clone");
  } else {
    props.reporter.warn(
      `${pin.package}: no tag matches ${pin.version} — cloned default branch`,
      "deps-clone",
      `verify ${P.dependencies}/${depDirname({ pkg: pin.package })} manually`,
    );
  }
  return {
    package: pin.package,
    version: pin.version,
    repo: pin.repo,
    clonedAtSha: tag !== null ? sha : `${sha} (no tag match)`,
  };
}

function upsert(rows: RegistryRow[], row: RegistryRow): RegistryRow[] {
  return [...rows.filter((r) => r.package !== row.package), row];
}

/**
 * `harness deps <clone|sync|add|remove|list>` dispatcher (wired into the cli.ts table).
 *
 * @param props.args - Tokens after "deps".
 * @param props.cwd - Working directory.
 * @param props.stdout - Line sink.
 * @param props.stderr - Error sink.
 * @returns EXIT code: OK on success (warnings included), USAGE on bad invocation/unknown package.
 */
export async function runDeps(props: {
  args: string[];
  cwd: string;
  stdout: (s: string) => void;
  stderr: (s: string) => void;
}): Promise<number> {
  const root = resolveProjectRoot({ cwd: props.cwd });
  const { manifest } = loadManifest({ root });
  let rows = loadRegistry({ root });
  const [sub, ...rest] = props.args;
  const reporter = new Reporter({ json: false, write: props.stdout });

  const finish = (code: number): number => {
    reporter.flush();
    return code;
  };

  switch (sub) {
    case "clone": {
      const parsed = parseArgs({ argv: rest, spec: { positionals: ["...rest"] } });
      const named = parsed.rest[0];
      let pins = manifest.dependencies;
      if (named !== undefined) {
        pins = pins.filter((p) => p.package === named);
        if (pins.length === 0) {
          throw new HarnessError("dep-unknown", `"${named}" is not a pinned dependency`, {
            hint: `harness deps add ${named} --repo <url>`,
          });
        }
      }
      if (pins.length === 0) {
        reporter.info("(no dependencies pinned)", "deps");
        return finish(EXIT.OK);
      }
      for (const pin of pins) {
        const row = cloneOne({ root, pin, reporter });
        if (row !== null) rows = upsert(rows, row);
      }
      saveRegistry({ root, rows });
      return finish(EXIT.OK);
    }

    case "sync": {
      const parsed = parseArgs({ argv: rest, spec: { positionals: ["...rest"] } });
      const named = parsed.rest[0];
      let targets = rows;
      if (named !== undefined) {
        targets = targets.filter((r) => r.package === named);
        if (targets.length === 0) throw new HarnessError("dep-unknown", `"${named}" is not in the registry`);
      }
      let registryChanged = false;
      let manifestChanged = false;
      for (const row of targets) {
        const pin = readProjectPin({ root, pkg: row.package });
        if (pin === null) {
          reporter.info(`${row.package}: no project pin — skipped`, "deps-sync");
          continue;
        }
        if (pin === row.version) {
          reporter.ok(`${row.package} up to date (${pin})`, "deps-sync");
          continue;
        }
        const fresh = cloneOne({ root, pin: { package: row.package, repo: row.repo, version: pin }, reporter });
        if (fresh !== null) {
          rows = upsert(rows, fresh);
          registryChanged = true;
          const manifestPin = manifest.dependencies.find((d) => d.package === row.package);
          if (manifestPin !== undefined && manifestPin.version !== pin) {
            manifestPin.version = pin;
            manifestChanged = true;
          }
        }
      }
      if (registryChanged) saveRegistry({ root, rows });
      if (manifestChanged) saveManifest({ root, manifest });
      return finish(EXIT.OK);
    }

    case "add": {
      const parsed = parseArgs({ argv: rest, spec: { positionals: ["package"], options: ["repo", "version"] } });
      const pkg = parsed.positionals["package"] as string;
      const repo = parsed.options["repo"];
      if (repo === undefined) throw new HarnessError("usage", "deps add requires --repo <url>");
      if (manifest.dependencies.some((d) => d.package === pkg)) {
        throw new HarnessError("dep-exists", `"${pkg}" is already pinned`, { hint: `harness deps sync ${pkg}` });
      }
      const version = parsed.options["version"] ?? readProjectPin({ root, pkg });
      if (version === null || version === undefined) {
        throw new HarnessError("dep-version-unknown", `${pkg}: not in the project manifest — pass --version`);
      }
      const pin: DependencyPin = { package: pkg, version, repo };
      const row = cloneOne({ root, pin, reporter });
      if (row === null) return finish(EXIT.OK); // failed add must not leave a dead pin
      manifest.dependencies.push(pin);
      saveManifest({ root, manifest });
      saveRegistry({ root, rows: upsert(rows, row) });
      return finish(EXIT.OK);
    }

    case "remove": {
      const parsed = parseArgs({ argv: rest, spec: { positionals: ["package"] } });
      const pkg = parsed.positionals["package"] as string;
      const inRegistry = rows.some((r) => r.package === pkg);
      const inManifest = manifest.dependencies.some((d) => d.package === pkg);
      if (!inRegistry && !inManifest) throw new HarnessError("dep-unknown", `"${pkg}" is not a registered dependency`);
      rmSync(join(root, P.dependencies, depDirname({ pkg })), { recursive: true, force: true });
      saveRegistry({ root, rows: rows.filter((r) => r.package !== pkg) });
      manifest.dependencies = manifest.dependencies.filter((d) => d.package !== pkg);
      saveManifest({ root, manifest });
      reporter.ok(`${pkg} removed (clone, registry row, manifest pin)`, "deps");
      return finish(EXIT.OK);
    }

    case "list": {
      parseArgs({ argv: rest, spec: { flags: ["json"] } });
      if (rows.length === 0) {
        props.stdout("(no dependencies registered)");
        return EXIT.OK;
      }
      const table = serializeRegistry({ rows });
      const start = table.indexOf("| package |");
      props.stdout(table.slice(start).trimEnd());
      return EXIT.OK;
    }

    default:
      throw new HarnessError("usage", "deps: clone|sync|add|remove|list");
  }
}
