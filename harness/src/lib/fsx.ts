import { createHash } from "node:crypto";
import {
  lstatSync,
  mkdirSync,
  readdirSync,
  readlinkSync,
  renameSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";

/**
 * Computes the sha256 hex digest of a string.
 *
 * @param props.text - Content to hash.
 * @returns Lowercase hex digest.
 */
export function sha256(props: { text: string }): string {
  return createHash("sha256").update(props.text).digest("hex");
}

/**
 * Writes a file atomically: temp file in the same directory, then rename.
 * Creates parent directories as needed.
 *
 * @param props.path - Absolute destination path.
 * @param props.content - File content.
 * @returns Nothing.
 */
export function writeFileAtomic(props: { path: string; content: string }): void {
  mkdirSync(dirname(props.path), { recursive: true });
  const tmp = join(dirname(props.path), `.${basename(props.path)}.tmp-${process.pid}`);
  writeFileSync(tmp, props.content);
  renameSync(tmp, props.path);
}

/**
 * Recursively lists files under root, returning root-relative POSIX paths, sorted.
 * Prunes: .git, node_modules (any depth), .agent/dependencies clone bodies, and any
 * directory name in props.prune. Symlinks are reported as files (never followed).
 *
 * @param props.root - Absolute directory.
 * @param props.prune - Extra directory names to skip.
 * @returns Sorted relative file paths (files only).
 */
export function walk(props: { root: string; prune?: string[] }): string[] {
  const pruneNames = new Set([".git", "node_modules", ...(props.prune ?? [])]);
  const out: string[] = [];
  const visit = (rel: string): void => {
    const abs = rel === "" ? props.root : join(props.root, rel);
    for (const entry of readdirSync(abs, { withFileTypes: true })) {
      const childRel = rel === "" ? entry.name : `${rel}/${entry.name}`;
      if (entry.isSymbolicLink()) {
        out.push(childRel);
        continue;
      }
      if (entry.isDirectory()) {
        if (pruneNames.has(entry.name)) continue;
        // Prune clone bodies but keep .agent/dependencies' own metadata files.
        if (childRel === ".agent/dependencies") {
          for (const sub of readdirSync(join(props.root, childRel), { withFileTypes: true })) {
            if (sub.isFile()) out.push(`${childRel}/${sub.name}`);
          }
          continue;
        }
        visit(childRel);
      } else {
        out.push(childRel);
      }
    }
  };
  visit("");
  return out.sort();
}

export type SymlinkResult = "created" | "replaced" | "ok" | "conflict";

/**
 * Ensures linkPath is a symlink pointing at targetPath (stored relative to linkPath's dir).
 *
 * @param props.linkPath - Absolute path where the link should live.
 * @param props.targetPath - Absolute path the link must resolve to.
 * @returns "ok" (already correct), "created", "replaced" (was a symlink to elsewhere),
 *   or "conflict" (a REAL file/dir occupies linkPath — untouched; caller reports per D10).
 */
export function ensureSymlink(props: { linkPath: string; targetPath: string }): SymlinkResult {
  const linkDir = dirname(props.linkPath);
  const desired = relative(linkDir, props.targetPath);
  let st;
  try {
    st = lstatSync(props.linkPath);
  } catch {
    mkdirSync(linkDir, { recursive: true });
    symlinkSync(desired, props.linkPath);
    return "created";
  }
  if (st.isSymbolicLink()) {
    const current = readlinkSync(props.linkPath);
    if (resolve(linkDir, current) === resolve(props.targetPath)) return "ok";
    unlinkSync(props.linkPath);
    symlinkSync(desired, props.linkPath);
    return "replaced";
  }
  return "conflict";
}
