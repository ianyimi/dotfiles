/**
 * Screenshot Extension
 *
 * /screenshot — Attach the most recent screenshot to the next message.
 *               Searches ~/Desktop and ~/Screenshots for the newest .png.
 *
 * Also works without this extension:
 *   - Ctrl+V in the pi editor to paste from clipboard
 *   - pi -p @~/Desktop/screenshot.png "what's wrong?"
 *   - Type @screenshot in the editor to fuzzy-find files
 *
 * Keybind: none (Pi keybindings.json only supports built-in actions).
 * Workaround: add a shell alias: alias pss='pi -p @$(ls -t ~/Desktop/*.png | head -1)'
 */

import { execSync } from "child_process";
import { existsSync, readFileSync } from "fs";
import { join } from "path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const SCREENSHOT_DIRS = [
  join(process.env.HOME ?? "~", "Desktop"),
  join(process.env.HOME ?? "~", "Screenshots"),
  join(process.env.HOME ?? "~", "Pictures", "Screenshots"),
];

function findLatestScreenshot(): string | null {
  for (const dir of SCREENSHOT_DIRS) {
    if (!existsSync(dir)) continue;
    try {
      const result = execSync(`ls -t "${dir}"/*.png 2>/dev/null | head -1`)
        .toString()
        .trim();
      if (result) return result;
    } catch {
      continue;
    }
  }
  return null;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("screenshot", {
    description: "Attach the most recent screenshot from ~/Desktop to the next message",
    handler: async (args, ctx) => {
      const latest = findLatestScreenshot();
      if (!latest) {
        ctx.ui.notify(
          "No screenshots found in ~/Desktop or ~/Screenshots.\n\nAlternatives:\n  Ctrl+V — paste from clipboard\n  @filename — fuzzy-find a file in the editor",
          "warning"
        );
        return;
      }

      let data: string;
      try {
        data = readFileSync(latest).toString("base64");
      } catch (e) {
        ctx.ui.notify(`Could not read file: ${latest}`, "error");
        return;
      }

      const filename = latest.split("/").pop() ?? "screenshot.png";
      const prompt = args.trim() || "What do you see in this screenshot?";

      ctx.ui.notify(`Attaching: ${filename}`, "info");

      const message: Array<{ type: "text"; text: string } | { type: "image"; data: string; mimeType: string }> = [
        { type: "text", text: prompt },
        { type: "image", data, mimeType: "image/png" },
      ];

      if (!ctx.isIdle()) {
        pi.sendUserMessage(message, { deliverAs: "followUp" });
      } else {
        pi.sendUserMessage(message);
      }
    },
  });
}
