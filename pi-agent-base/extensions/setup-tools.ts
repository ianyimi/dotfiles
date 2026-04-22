import { existsSync, unlinkSync } from "fs";
import { join } from "path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/**
 * Tools for the project setup skill.
 * Registers `finish_setup` — called by 0-pi-project-setup as its final step.
 * Notifies the user and hot-reloads Pi so the new .pi/ config is active immediately.
 */
export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "finish_setup",
    description:
      "Call this as the final step of project setup. Notifies the user that setup is complete and reloads Pi so the project-local .pi/ config is active immediately. Pass a summary of what was created.",
    parameters: {
      type: "object",
      properties: {
        summary: {
          type: "string",
          description: "One-paragraph summary of what the setup created — skills, agent-docs files, etc.",
        },
        skills_created: {
          type: "array",
          items: { type: "string" },
          description: "List of skill names written to .pi/skills/",
        },
        next_steps: {
          type: "array",
          items: { type: "string" },
          description: "Suggested next steps for the developer (e.g. fill in roadmap, run dev-spec)",
        },
      },
      required: ["summary"],
    },
    execute: async ({ summary, skills_created, next_steps }, ctx) => {
      // Delete progress file now that setup is complete
      const progressFile = join(process.cwd(), ".pi", ".setup-progress.md");
      if (existsSync(progressFile)) unlinkSync(progressFile);
      const skillList =
        skills_created && skills_created.length > 0
          ? `\nSkills installed:\n${skills_created.map((s: string) => `  • ${s}`).join("\n")}`
          : "";

      const nextList =
        next_steps && next_steps.length > 0
          ? `\nNext steps:\n${next_steps.map((s: string) => `  → ${s}`).join("\n")}`
          : "";

      ctx.ui.notify(
        `Project harness ready.\n\n${summary}${skillList}${nextList}\n\nReloading Pi to activate project config...`,
        "success"
      );

      // Small delay so the user can read the notification before reload clears the screen
      await new Promise((resolve) => setTimeout(resolve, 1200));

      // Trigger hot-reload so .pi/ project layer is active immediately
      pi.sendUserMessage("/reload", { deliverAs: "steer" });

      return "Setup complete. Pi is reloading to activate the project config.";
    },
  });
}
