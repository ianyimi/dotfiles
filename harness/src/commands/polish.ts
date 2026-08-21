import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { EXIT, HarnessError } from "../lib/errors.ts";
import { parseFrontmatter } from "../lib/frontmatter.ts";
import { loadManifest } from "../lib/manifest.ts";
import { P } from "../lib/paths.ts";

/**
 * Emits the polish working packet: spec edge cases, touches[] file globs, checklist path.
 * The ANALYSIS is the polish skill's job — this command is packaging only (D12).
 *
 * @param props.root - Project root.
 * @param props.slug - Spec slug.
 * @param props.stdout - Line sink.
 * @returns EXIT.OK.
 * @throws {HarnessError} "polish-disabled" when manifest.workflow.importance !== "high"
 *   (the gate error wins over spec lookup); "spec-not-found" when the spec dir or spec.md
 *   is missing.
 */
export function buildPolishPacket(props: { root: string; slug: string; stdout: (s: string) => void }): number {
  const { manifest } = loadManifest({ root: props.root });
  if (manifest.workflow.importance !== "high") {
    throw new HarnessError(
      "polish-disabled",
      "Polish is only enabled for high-importance projects. Set importance: high in manifest.json.",
    );
  }

  const specPath = join(props.root, P.specs, props.slug, "spec.md");
  if (!existsSync(specPath)) {
    throw new HarnessError("spec-not-found", `no spec.md for "${props.slug}"`, { hint: "harness spec list" });
  }
  const text = readFileSync(specPath, "utf8");
  const { data } = parseFrontmatter({ text });

  const lines = text.split("\n");
  const start = lines.findIndex((l) => l.trim() === "## Edge cases");
  let edgeCases: string[];
  if (start === -1) {
    edgeCases = ['(spec.md has no "## Edge cases" section — review the spec manually)'];
  } else {
    let end = lines.length;
    for (let i = start + 1; i < lines.length; i++) {
      if ((lines[i] as string).startsWith("## ")) {
        end = i;
        break;
      }
    }
    edgeCases = lines.slice(start + 1, end);
    while (edgeCases.length > 0 && (edgeCases[edgeCases.length - 1] as string).trim() === "") edgeCases.pop();
    while (edgeCases.length > 0 && (edgeCases[0] as string).trim() === "") edgeCases.shift();
  }

  const touches = Array.isArray(data["touches"]) ? (data["touches"] as string[]) : [];
  const touchLines = touches.length > 0 ? touches.map((t) => `- ${t}`) : ["- (touches[] empty — review files changed for this spec)"];

  const out = [
    `Polish packet for spec: ${props.slug}`,
    "",
    "## Edge cases (from spec.md)",
    ...edgeCases,
    "",
    "## Files to review (frontmatter touches[])",
    ...touchLines,
    "",
    "## Checklist",
    ".agent/skills/polish/references/polish-checklist.md",
    "",
    "Run the polish skill against this packet. The CLI does no code analysis (D12).",
  ];
  for (const line of out) props.stdout(line);
  return EXIT.OK;
}
