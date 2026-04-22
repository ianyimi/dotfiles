/**
 * Browse extension — navigate Arc to a URL and return a screenshot.
 *
 * Reuses an existing tab at the same origin instead of opening a new one,
 * so Arc stays clean. Pin a localhost tab in an Arc folder once and the
 * agent will always reuse it.
 *
 * Uses AppleScript to control Arc + screencapture for the screenshot.
 * Requires Arc on macOS.
 */

import { execSync } from "child_process";
import { existsSync, readFileSync, writeFileSync, unlinkSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

const SCREENSHOT_PATH = join(process.env.HOME ?? "/tmp", "Desktop", "pi-verify.png");

/** Write a script to a temp file and run it with osascript. Avoids shell quoting issues. */
function runScript(script: string): string {
	const tmp = join(tmpdir(), `pi-browse-${Date.now()}.scpt`);
	try {
		writeFileSync(tmp, script);
		return execSync(`osascript "${tmp}"`, { timeout: 8000 }).toString().trim();
	} finally {
		try {
			unlinkSync(tmp);
		} catch {}
	}
}

type TabResult = "reused" | "opened" | "fallback";

/**
 * Navigate Arc to `url`. If a tab at the same origin already exists, update
 * its URL (reuse). Otherwise open exactly one new tab.
 */
function navigateTab(url: string): TabResult {
	let origin: string;
	try {
		origin = new URL(url).origin;
	} catch {
		// Malformed URL — just open it and let Arc handle it
		try {
			execSync(`open "${url}"`);
		} catch {}
		return "fallback";
	}

	// Escape double quotes in URL/origin for embedding in AppleScript string literals
	const safeURL = url.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
	const safeOrigin = origin.replace(/\\/g, "\\\\").replace(/"/g, '\\"');

	const script = `
set targetURL to "${safeURL}"
set targetOrigin to "${safeOrigin}"
set didFind to false
tell application "Arc"
    repeat with w in windows
        repeat with t in tabs of w
            try
                set tabURL to URL of t
                if tabURL starts with targetOrigin then
                    set URL of t to targetURL
                    tell w to set active tab to t
                    set didFind to true
                    exit repeat
                end if
            end try
        end repeat
        if didFind then exit repeat
    end repeat
    if not didFind then
        tell front window
            make new tab with properties {URL:targetURL}
        end tell
    end if
    activate
end tell
return didFind`;

	try {
		const result = runScript(script);
		return result === "true" ? "reused" : "opened";
	} catch {
		// AppleScript failed — fall back to plain open
		try {
			execSync(`open "${url}"`);
		} catch {}
		return "fallback";
	}
}

/**
 * Screenshot Arc's front window using its window bounds for a precise capture.
 * Falls back to full-screen if bounds can't be read.
 */
function screenshotArc(): string | null {
	// Try bounds-based window capture first
	try {
		const boundsScript = `
tell application "Arc"
    set b to bounds of front window
    set x1 to item 1 of b
    set y1 to item 2 of b
    set x2 to item 3 of b
    set y2 to item 4 of b
    return (x1 as text) & "," & (y1 as text) & "," & (x2 as text) & "," & (y2 as text)
end tell`;
		const raw = runScript(boundsScript);
		const parts = raw.split(",").map(Number);
		if (parts.length === 4 && parts.every((n) => !isNaN(n))) {
			const [x1, y1, x2, y2] = parts;
			const w = x2 - x1;
			const h = y2 - y1;
			if (w > 0 && h > 0) {
				execSync(`screencapture -x -R ${x1},${y1},${w},${h} "${SCREENSHOT_PATH}"`);
				if (existsSync(SCREENSHOT_PATH)) return SCREENSHOT_PATH;
			}
		}
	} catch {}

	// Fallback: full-screen capture
	try {
		execSync(`screencapture -x "${SCREENSHOT_PATH}"`);
		if (existsSync(SCREENSHOT_PATH)) return SCREENSHOT_PATH;
	} catch {}

	return null;
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "browse",
		description:
			"Navigate Arc browser to a URL and return a screenshot of the result. Reuses an existing tab at the same origin (never opens more than one new tab per origin). Use for visually verifying UI changes, checking pages after edits, or debugging layout issues. Arc must be running.",
		parameters: {
			type: "object",
			properties: {
				url: {
					type: "string",
					description:
						"Full URL to navigate to, including protocol. Example: http://localhost:3000/dashboard",
				},
				wait_ms: {
					type: "number",
					description:
						"Milliseconds to wait for page load before taking the screenshot. Default 1200. Increase for slow routes or animations (e.g. 2500).",
				},
			},
			required: ["url"],
		},

		execute: async (
			_toolCallId: string,
			params: { url: string; wait_ms?: number },
			_signal: unknown,
			_onUpdate: unknown,
			_ctx: any,
		) => {
			const { url, wait_ms = 1200 } = params;

			const tabResult = navigateTab(url);

			// Wait for page to load
			await new Promise((r) => setTimeout(r, wait_ms));

			const screenshotPath = screenshotArc();

			if (!screenshotPath) {
				return {
					content: [
						{
							type: "text",
							text: `Navigated to ${url} (${tabResult}). Screenshot failed — use Ctrl+V to paste one manually if you need visual feedback.`,
						},
					],
				};
			}

			const imageData = readFileSync(screenshotPath).toString("base64");

			return {
				content: [
					{ type: "text", text: `Navigated to: ${url} (${tabResult})` },
					{ type: "image", data: imageData, mimeType: "image/png" },
				],
			};
		},

		renderCall(args: any, theme: any) {
			const url = typeof args?.url === "string" ? args.url : "";
			return new Text(
				theme.fg("toolTitle", theme.bold("browse ")) + theme.fg("muted", url),
				0,
				0,
			);
		},

		renderResult(result: any, _options: unknown, theme: any) {
			const hasImage = result?.content?.some((c: any) => c.type === "image");
			const firstText = result?.content?.find((c: any) => c.type === "text")?.text ?? "";
			if (hasImage) {
				return new Text(
					theme.fg("success", "✓ ") + theme.fg("dim", firstText),
					0,
					0,
				);
			}
			return new Text(theme.fg("warning", firstText || "no screenshot"), 0, 0);
		},
	});
}
