const cache = new Map<string, RegExp>();

/** Compiles a glob to an anchored RegExp (module-level cache for determinism + speed). */
function compile(pattern: string): RegExp {
  let p = pattern.startsWith("./") ? pattern.slice(2) : pattern;
  if (p.endsWith("/")) p = `${p}**`;
  const cached = cache.get(p);
  if (cached !== undefined) return cached;

  let re = "";
  let i = 0;
  while (i < p.length) {
    const ch = p[i] as string;
    if (ch === "*") {
      if (p.startsWith("**/", i)) {
        re += "(?:[^/]+/)*";
        i += 3;
      } else if (p.startsWith("**", i)) {
        re += ".*";
        i += 2;
      } else {
        re += "[^/]*";
        i += 1;
      }
    } else if (ch === "?") {
      re += "[^/]";
      i += 1;
    } else {
      re += ch.replace(/[.+^${}()|[\]\\]/g, "\\$&");
      i += 1;
    }
  }
  const compiled = new RegExp(`^${re}$`);
  cache.set(p, compiled);
  return compiled;
}

/**
 * Minimal deterministic glob matcher for root-relative POSIX paths.
 * Supports `**` (any depth incl. none), `*` (within a segment), `?` (one char);
 * no braces/extglobs. A trailing "/" matches everything under that directory.
 *
 * @param props.pattern - Glob pattern, e.g. "src/components/**".
 * @param props.path - Root-relative POSIX path.
 * @returns True when the path matches.
 */
export function globMatch(props: { pattern: string; path: string }): boolean {
  return compile(props.pattern).test(props.path);
}
