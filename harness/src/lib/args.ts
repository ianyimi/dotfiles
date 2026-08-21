import { HarnessError } from "./errors.ts";

/** Declares what a (sub)command accepts. */
export interface ArgSpec {
  /** Named positionals in order; a trailing "...rest" name collects remainder. */
  positionals?: string[];
  /** Boolean flags, e.g. ["json", "check"]. --json → true. */
  flags?: string[];
  /** Value options, e.g. ["for", "from", "data", "template"]. --for X or --for=X. */
  options?: string[];
}

export interface ParsedArgs {
  positionals: Record<string, string>;
  rest: string[];
  flags: Record<string, boolean>;
  options: Record<string, string>;
}

/**
 * Minimal deterministic arg parser (no deps). Single-dash tokens are rejected to keep
 * the grammar tiny; repeated options keep the last value.
 *
 * @param props.argv - Tokens after the command name.
 * @param props.spec - Accepted shape.
 * @returns Parsed groups; missing flags are false, missing options absent.
 * @throws {HarnessError} code "usage" on unknown flag/option, missing positional,
 *   or an option with no value.
 */
export function parseArgs(props: { argv: string[]; spec: ArgSpec }): ParsedArgs {
  const flagNames = props.spec.flags ?? [];
  const optionNames = props.spec.options ?? [];
  const posNames = (props.spec.positionals ?? []).filter((p) => p !== "...rest");
  const hasRest = (props.spec.positionals ?? []).includes("...rest");

  const usage = (msg: string): never => {
    throw new HarnessError("usage", msg);
  };

  const out: ParsedArgs = { positionals: {}, rest: [], flags: {}, options: {} };
  for (const f of flagNames) out.flags[f] = false;

  let posIndex = 0;
  const argv = props.argv;
  for (let i = 0; i < argv.length; i++) {
    const tok = argv[i] as string;
    if (tok === "--") {
      out.rest.push(...argv.slice(i + 1));
      break;
    }
    if (tok.startsWith("--")) {
      const eq = tok.indexOf("=");
      if (eq !== -1) {
        const name = tok.slice(2, eq);
        const value = tok.slice(eq + 1);
        if (optionNames.includes(name)) out.options[name] = value;
        else if (flagNames.includes(name)) usage(`flag --${name} does not take a value`);
        else usage(`unknown option --${name}`);
        continue;
      }
      const name = tok.slice(2);
      if (flagNames.includes(name)) {
        out.flags[name] = true;
      } else if (optionNames.includes(name)) {
        const next = argv[i + 1];
        if (next === undefined || next.startsWith("--")) usage(`option --${name} requires a value`);
        out.options[name] = next as string;
        i++;
      } else {
        usage(`unknown flag --${name}`);
      }
      continue;
    }
    if (tok.startsWith("-") && tok.length > 1) usage(`single-dash options are not supported: ${tok}`);
    if (posIndex < posNames.length) {
      out.positionals[posNames[posIndex] as string] = tok;
      posIndex++;
    } else if (hasRest) {
      out.rest.push(tok);
    } else {
      usage(`unexpected argument: ${tok}`);
    }
  }

  for (let j = posIndex; j < posNames.length; j++) {
    usage(`missing required argument: <${posNames[j]}>`);
  }
  return out;
}
