import { EXIT, HarnessError } from "../lib/errors.ts";
import { loadManifest, saveManifest } from "../lib/manifest.ts";
import type { Reporter } from "../lib/output.ts";
import { KNOWN_PLATFORM_IDS, type PlatformId } from "../platforms/types.ts";
import { runSync } from "./sync.ts";

/**
 * `harness platform add <id> | list` — manage active bridge platforms.
 *
 * @param props.args - Tokens after "platform".
 * @param props.root - Project root.
 * @param props.reporter - Sink.
 * @returns Exit code (add returns runSync's code).
 * @throws {HarnessError} "unknown-platform" for an unregistered id; "usage" otherwise.
 */
export function runPlatform(props: { args: string[]; root: string; reporter: Reporter }): number {
  const [sub, id] = props.args;
  if (sub === "list") {
    const { manifest } = loadManifest({ root: props.root });
    for (const known of KNOWN_PLATFORM_IDS) {
      props.reporter.info(`${known.padEnd(6)} ${manifest.platforms.active.includes(known) ? "active" : "available"}`, "platform");
    }
    return EXIT.OK;
  }
  if (sub === "add") {
    if (id === undefined || !KNOWN_PLATFORM_IDS.includes(id as PlatformId)) {
      throw new HarnessError("unknown-platform", `unknown platform ${JSON.stringify(id ?? "")} (known: ${KNOWN_PLATFORM_IDS.join(", ")})`, {
        exitCode: EXIT.USAGE,
      });
    }
    const { manifest } = loadManifest({ root: props.root });
    if (manifest.platforms.active.includes(id as PlatformId)) {
      props.reporter.info(`${id} already active`, "platform");
    } else {
      manifest.platforms.active.push(id as PlatformId);
      saveManifest({ root: props.root, manifest });
    }
    return runSync({ root: props.root, reporter: props.reporter });
  }
  throw new HarnessError("usage", `platform: unknown subcommand ${JSON.stringify(sub)} — expected add | list`);
}
