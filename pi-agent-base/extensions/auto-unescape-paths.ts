/**
 * auto-unescape-paths.ts
 * Automatically removes backslash-escapes from file paths.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    let lastText = "";
    let cooldownUntil = 0;
    
    const checkInterval = setInterval(() => {
      try {
        const now = Date.now();
        if (now < cooldownUntil) return;
        
        const currentText = ctx.ui.getEditorText();
        
        if (currentText !== lastText && currentText.includes("\\ ")) {
          const unescaped = currentText.replace(/\\ /g, " ");
          if (unescaped !== currentText) {
            ctx.ui.setEditorText(unescaped);
            lastText = unescaped;
            cooldownUntil = now + 2000;
          }
        } else {
          lastText = currentText;
        }
      } catch (e) {
        // Not ready yet
      }
    }, 100);
    
    pi.on("session_shutdown", () => {
      clearInterval(checkInterval);
    });
  });
}
