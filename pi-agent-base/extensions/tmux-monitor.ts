/**
 * Tmux Monitor Extension
 *
 * Registers a `tmux_pane` tool the LLM can call to read output from other
 * tmux panes — dev server logs, test output, build status, etc.
 *
 * Also shows a status line with the current pane commands.
 *
 * Usage examples (agent uses this automatically, or you can invoke):
 *   !tmux capture-pane -p -t 1          ← quick one-off in the editor
 *   Ask: "check the dev server logs"    ← agent calls tmux_pane tool
 */

import { execSync } from "child_process";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

function inTmux(): boolean {
  return !!process.env.TMUX;
}

export default function (pi: ExtensionAPI) {
  if (!inTmux()) return; // Skip registration outside tmux

  // Status line showing pane commands
  pi.on("session_start", async (_event, ctx) => {
    try {
      const panes = execSync(
        "tmux list-panes -F '#{pane_index}:#{pane_current_command}'",
        { timeout: 1000 }
      )
        .toString()
        .trim()
        .split("\n")
        .filter((p) => !p.startsWith("0:")) // Skip the pi pane itself
        .join(" │ ");
      if (panes) {
        ctx.ui.setStatus("tmux", ctx.ui.theme.fg("dim", `tmux: ${panes}`));
      }
    } catch {
      // Not in tmux or tmux not available
    }
  });

  // Register tmux_pane tool for the LLM
  pi.registerTool({
    name: "tmux_pane",
    label: "Tmux Pane",
    description:
      "Read output from a tmux pane. Use to check dev server logs, test runner output, build status, or any running process. Pane 0 is pi itself; start with pane 1.",
    parameters: Type.Object({
      pane: Type.String({
        description:
          "Pane target. Simple index: '1', '2'. Full target: 'session:window.pane' e.g. 'main:0.1'",
      }),
      lines: Type.Optional(
        Type.Number({
          description: "Number of lines to capture from the bottom (default: 50, max: 200)",
        })
      ),
    }),

    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const n = Math.min(params.lines ?? 50, 200);
      try {
        const output = execSync(
          `tmux capture-pane -p -t ${params.pane} 2>/dev/null | tail -n ${n}`,
          { timeout: 5000, cwd: process.cwd() }
        ).toString();

        if (!output.trim()) {
          return {
            content: [{ type: "text", text: `Pane ${params.pane}: (empty or no output)` }],
          };
        }

        return {
          content: [
            {
              type: "text",
              text: `Pane ${params.pane} (last ${n} lines):\n\`\`\`\n${output}\`\`\``,
            },
          ],
        };
      } catch (e) {
        return {
          content: [
            {
              type: "text",
              text: `Error reading pane ${params.pane}: ${(e as Error).message}`,
            },
          ],
        };
      }
    },
  });
}
