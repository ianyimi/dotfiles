// Shared path extraction for the undo-guard hooks. Imported by scripts/undo-guard-notify.ts
// (Claude Code's Bash PreToolUse payload) and scripts/undo-guard-omp-hook.ts (omp's bash
// tool_call). Kept in its own module because the notifier runs main() and process.exit(0) at
// top level — importing *it* from a hook would execute the CLI and kill the host process.

import path from "node:path";
import { accessSync, constants, statSync } from "node:fs";

// ---------------------------------------------------------------------------
// Shell-command path extraction. Given a raw command string as a PreToolUse hook sees it
// (`tool_input.command`) plus the harness-provided cwd, returns absolute paths of files the
// command explicitly names that already exist on disk. A path that doesn't exist yet has no
// undo history to protect, so it is filtered out.
//
// Deliberately NOT caught: globs (`*.ts`), xargs-piped paths, heredocs, variable-substituted
// paths (`$FILE`), and commands that mutate an unpredictable set such as `prettier --write .`
// or `npm install`. The startup preload in lua/util/undo.lua covers that second category for
// every file under the cwd that already has an undofile, independent of any hook.
// ---------------------------------------------------------------------------

const PATH_COMMANDS = new Set(["sed", "tee", "patch", "mv", "cp", "install"]);

/** Splits a command string into shell-ish tokens: quotes group, nothing else is interpreted. */
export function tokenizeShell(command: string): string[] {
  const tokens: string[] = [];
  let cur = "";
  let quote: '"' | "'" | null = null;
  let inToken = false;

  for (const c of command) {
    if (quote) {
      if (c === quote) {
        quote = null;
      } else {
        cur += c;
      }
      continue;
    }
    if (c === '"' || c === "'") {
      quote = c;
      inToken = true;
      continue;
    }
    // Command separators: flush and emit the separator so each pipeline segment can be
    // treated independently (a `>`/`>>` binds to its own segment).
    if (c === "|" || c === "&" || c === ";") {
      if (inToken) tokens.push(cur);
      tokens.push(c);
      cur = "";
      inToken = false;
      continue;
    }
    if (/\s/.test(c)) {
      if (inToken) tokens.push(cur);
      cur = "";
      inToken = false;
      continue;
    }
    cur += c;
    inToken = true;
  }
  if (inToken) tokens.push(cur);
  return tokens;
}

/**
 * Extracts existing-file paths a shell command explicitly names, resolved against `cwd`.
 * Covers `sed -i FILE`, `tee FILE`, `> FILE` / `>> FILE`, `patch ... FILE` / `patch < FILE`,
 * `mv SRC DST`, `cp SRC DST`, `install -m ... FILE`.
 */
export function extractShellPaths(command: string, cwd: string): string[] {
  const tokens = tokenizeShell(command);
  const found = new Set<string>();

  const resolve = (rawTok: string | undefined): string | null => {
    // Skip flags, globs, and anything needing shell expansion we are not performing.
    if (!rawTok || rawTok.startsWith("-") || /[*?[\]$`]/.test(rawTok) || rawTok.startsWith("~")) {
      return null;
    }
    const abs = path.isAbsolute(rawTok) ? rawTok : path.join(cwd, rawTok);
    try {
      accessSync(abs, constants.R_OK);
      if (!statSync(abs).isFile()) return null;
    } catch {
      return null;
    }
    return abs;
  };

  for (let i = 0; i < tokens.length; i++) {
    const tok = tokens[i] as string;

    // Redirection anywhere in a segment, e.g. `echo x > f.ts`.
    if (tok === ">" || tok === ">>") {
      const resolved = resolve(tokens[i + 1]);
      if (resolved) found.add(resolved);
      continue;
    }

    // A `<` operand inside a covered command's segment is handled by the walk below, which
    // resolves every non-flag token. Matching on the previous token would miss the common
    // `patch -p1 < fix.patch`, where the operator is not adjacent to the command name.
    if (tok === "<") continue;

    if (!PATH_COMMANDS.has(tok.replace(/^.*\//, ""))) continue;

    // Walk the rest of this pipeline segment, collecting every non-flag argument that resolves
    // to an existing file. Deliberately permissive about argument order, so `sed -i FILE`,
    // `sed -i.bak FILE`, `cp SRC DST` and `install -m 0644 SRC DST` all fall out of the same rule.
    for (let j = i + 1; j < tokens.length; j++) {
      const t = tokens[j] as string;
      if (t === "|" || t === "&" || t === ";") break;
      // The operator itself is not a path; its operand resolves on the next iteration.
      if (t === "<" || t === ">" || t === ">>") continue;
      const resolved = resolve(t);
      if (resolved) found.add(resolved);
    }
  }

  return [...found];
}
