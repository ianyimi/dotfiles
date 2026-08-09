import { parseArgs } from "../lib/args.ts";
import { EXIT, HarnessError } from "../lib/errors.ts";
import { loadManifest, saveManifest, type HarnessManifest } from "../lib/manifest.ts";
import type { Reporter } from "../lib/output.ts";
import { runSync } from "./sync.ts";

interface ConfigKey {
  /** Dotted path shown to the user. */
  key: string;
  /** Allowed literals; null = any non-empty string. */
  values: string[] | null;
  get(m: HarnessManifest): string;
  set(m: HarnessManifest, value: string): void;
  /** Changing this key changes generated bridges → auto-run sync. */
  affectsBridges: boolean;
}

/** The settable surface — deliberately small; everything else is `manifest.json` by hand. */
const KEYS: ConfigKey[] = [
  {
    key: "models.subagent_selection",
    values: ["dynamic", "uniform"],
    get: (m) => m.models.subagent_selection,
    set: (m, v) => {
      m.models.subagent_selection = v as "dynamic" | "uniform";
    },
    affectsBridges: false,
  },
  {
    key: "models.advisor",
    values: ["true", "false"],
    get: (m) => String(m.models.advisor),
    set: (m, v) => {
      m.models.advisor = v === "true";
    },
    affectsBridges: true,
  },
  {
    key: "models.tiers.frontier",
    values: null,
    get: (m) => m.models.tiers.frontier,
    set: (m, v) => {
      m.models.tiers.frontier = v;
    },
    affectsBridges: true,
  },
  {
    key: "models.tiers.standard",
    values: null,
    get: (m) => m.models.tiers.standard,
    set: (m, v) => {
      m.models.tiers.standard = v;
    },
    affectsBridges: true,
  },
  {
    key: "models.tiers.cheap",
    values: null,
    get: (m) => m.models.tiers.cheap,
    set: (m, v) => {
      m.models.tiers.cheap = v;
    },
    affectsBridges: true,
  },
  {
    key: "workflow.commit_mode",
    values: ["message-only", "agent-commits"],
    get: (m) => m.workflow.commit_mode,
    set: (m, v) => {
      m.workflow.commit_mode = v as "message-only" | "agent-commits";
    },
    affectsBridges: false,
  },
  {
    key: "workflow.importance",
    values: ["high", "medium", "low"],
    get: (m) => m.workflow.importance,
    set: (m, v) => {
      m.workflow.importance = v as "high" | "medium" | "low";
    },
    affectsBridges: false,
  },
];

function findKey(key: string): ConfigKey {
  const found = KEYS.find((k) => k.key === key);
  if (found === undefined) {
    throw new HarnessError("usage", `unknown config key ${JSON.stringify(key)} (known: ${KEYS.map((k) => k.key).join(", ")})`);
  }
  return found;
}

/**
 * `harness config [get <key> | set <key> <value>]` — the toggles for harness behavior.
 * Bare `config` lists every settable key with its current value. Setting a key that
 * changes generated bridges auto-runs `harness sync`.
 *
 * @param props.args - Tokens after "config".
 * @param props.root - Project root.
 * @param props.reporter - Sink.
 * @returns EXIT.OK (set returns sync's code when a bridge-affecting key changed).
 */
export function runConfig(props: { args: string[]; root: string; reporter: Reporter }): number {
  const [sub, ...rest] = props.args;
  const { manifest } = loadManifest({ root: props.root });

  if (sub === undefined || sub === "list") {
    for (const k of KEYS) {
      props.reporter.info(`${k.key} = ${k.get(manifest)}${k.values !== null ? `  (${k.values.join(" | ")})` : ""}`, "config");
    }
    return EXIT.OK;
  }
  if (sub === "get") {
    const parsed = parseArgs({ argv: rest, spec: { positionals: ["key"] } });
    props.reporter.info(findKey(parsed.positionals["key"] as string).get(manifest), "config");
    return EXIT.OK;
  }
  if (sub === "set") {
    const parsed = parseArgs({ argv: rest, spec: { positionals: ["key", "value"] } });
    const k = findKey(parsed.positionals["key"] as string);
    const value = parsed.positionals["value"] as string;
    if (k.values !== null && !k.values.includes(value)) {
      throw new HarnessError("usage", `${k.key} must be one of: ${k.values.join(" | ")}`);
    }
    if (value === "") throw new HarnessError("usage", `${k.key} cannot be empty`);
    k.set(manifest, value);
    saveManifest({ root: props.root, manifest });
    props.reporter.ok(`${k.key} = ${value}`, "config");
    if (k.affectsBridges) {
      return runSync({ root: props.root, reporter: props.reporter });
    }
    return EXIT.OK;
  }
  throw new HarnessError("usage", `config: unknown subcommand ${JSON.stringify(sub)} — expected list | get | set`);
}
