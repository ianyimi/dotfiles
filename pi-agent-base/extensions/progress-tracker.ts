/**
 * Progress Tracker — Gamified project roadmap + pause/resume system
 *
 * Commands:
 *   /progress       — Visual roadmap TUI with XP, streaks, phase progress bars
 *   /pause          — Save full session state (runs even mid-execution)
 *   /unpause        — Restore paused state, brief the agent, and continue
 *   /task list      — Show all tasks with ids
 *   /task start <id>— Mark a task active
 *   /task done      — Complete the active task (+XP, streak)
 *   /roadmap-init   — Ask the agent to scaffold .pi/roadmap.json for this project
 */

import { execSync } from "child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import type { ExtensionAPI, Theme } from "@mariozechner/pi-coding-agent";
import { matchesKey, truncateToWidth } from "@mariozechner/pi-tui";

// ─── Types ───────────────────────────────────────────────────────────────────

interface Task {
  id: string;
  title: string;
  status: "todo" | "active" | "done" | "paused";
  phase: string;
  xp: number;
  startedAt?: string;
  completedAt?: string;
}

interface Phase {
  name: string;
  tasks: Task[];
}

interface Roadmap {
  project: string;
  xp: number;
  streak: number;
  lastWorkedAt?: string;
  phases: Phase[];
}

interface PauseState {
  pausedAt: string;
  activeTask?: { id: string; title: string; phase: string };
  summary: string;
  changedFiles: string[];
  gitStatus: string;
  xp: number;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function piDir(): string {
  return join(process.cwd(), ".pi");
}

function ensurePiDir(): void {
  if (!existsSync(piDir())) mkdirSync(piDir(), { recursive: true });
}

function roadmapPath(): string {
  return join(piDir(), "roadmap.json");
}

function pausePath(): string {
  return join(piDir(), "pause-state.json");
}

function loadRoadmap(): Roadmap | null {
  if (!existsSync(roadmapPath())) return null;
  try {
    return JSON.parse(readFileSync(roadmapPath(), "utf-8"));
  } catch {
    return null;
  }
}

function saveRoadmap(r: Roadmap): void {
  ensurePiDir();
  writeFileSync(roadmapPath(), JSON.stringify(r, null, 2));
}

function loadPause(): PauseState | null {
  if (!existsSync(pausePath())) return null;
  try {
    return JSON.parse(readFileSync(pausePath(), "utf-8"));
  } catch {
    return null;
  }
}

function getActive(r: Roadmap): Task | undefined {
  return r.phases.flatMap((p) => p.tasks).find((t) => t.status === "active");
}

function bar(done: number, total: number, width = 20): string {
  if (total === 0) return "░".repeat(width);
  const filled = Math.round((done / total) * width);
  return "█".repeat(filled) + "░".repeat(width - filled);
}

function gitInfo(): { status: string; changed: string[] } {
  try {
    const status = execSync("git status --short 2>/dev/null", { cwd: process.cwd() })
      .toString()
      .trim();
    const diffFiles = execSync("git diff --name-only HEAD 2>/dev/null", { cwd: process.cwd() })
      .toString()
      .trim()
      .split("\n")
      .filter(Boolean);
    const untracked = execSync("git ls-files --others --exclude-standard 2>/dev/null", {
      cwd: process.cwd(),
    })
      .toString()
      .trim()
      .split("\n")
      .filter(Boolean);
    return { status, changed: [...new Set([...diffFiles, ...untracked])] };
  } catch {
    return { status: "", changed: [] };
  }
}

// ─── Progress TUI Component ───────────────────────────────────────────────────

class ProgressView {
  private roadmap: Roadmap;
  private theme: Theme;
  private onClose: () => void;
  private sel = 0;
  private cache?: { w: number; lines: string[] };

  constructor(roadmap: Roadmap, theme: Theme, onClose: () => void) {
    this.roadmap = roadmap;
    this.theme = theme;
    this.onClose = onClose;
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "q")) {
      this.onClose();
    } else if (matchesKey(data, "up") || matchesKey(data, "k")) {
      this.sel = Math.max(0, this.sel - 1);
      this.cache = undefined;
    } else if (matchesKey(data, "down") || matchesKey(data, "j")) {
      this.sel = Math.min(this.roadmap.phases.length - 1, this.sel + 1);
      this.cache = undefined;
    }
  }

  render(width: number): string[] {
    if (this.cache?.w === width) return this.cache.lines;
    const th = this.theme;
    const lines: string[] = [];
    const r = this.roadmap;

    // ── Header
    const allTasks = r.phases.flatMap((p) => p.tasks);
    const done = allTasks.filter((t) => t.status === "done").length;
    const total = allTasks.length;
    const pct = total > 0 ? Math.round((done / total) * 100) : 0;

    lines.push("");
    lines.push(
      truncateToWidth(
        " " + th.fg("accent", th.bold(`◆ ${r.project}`)),
        width
      )
    );
    lines.push(truncateToWidth(th.fg("borderMuted", " " + "─".repeat(width - 2)), width));

    // ── Stats
    const totalBar = bar(done, total, 24);
    const streakStr = r.streak > 0 ? `  🔥 ${r.streak}d` : "";
    lines.push(
      truncateToWidth(
        ` ${th.fg("success", totalBar)}  ` +
          th.fg("accent", `${pct}%`) +
          th.fg("dim", ` ${done}/${total}`) +
          `  ⚡ ` +
          th.fg("text", `${r.xp} XP`) +
          th.fg("accent", streakStr),
        width
      )
    );
    lines.push("");

    // ── Phases
    for (let i = 0; i < r.phases.length; i++) {
      const phase = r.phases[i];
      const phDone = phase.tasks.filter((t) => t.status === "done").length;
      const phTotal = phase.tasks.length;
      const phPct = phTotal > 0 ? Math.round((phDone / phTotal) * 100) : 0;
      const phBar = bar(phDone, phTotal, 12);
      const isSel = i === this.sel;

      const prefix = isSel ? th.fg("accent", " ▶ ") : "   ";
      const name = isSel
        ? th.fg("accent", th.bold(phase.name))
        : th.fg("muted", phase.name);
      lines.push(
        truncateToWidth(
          `${prefix}${name}  ${th.fg("borderMuted", phBar)} ${th.fg("dim", `${phPct}%`)}`,
          width
        )
      );

      if (isSel) {
        for (const task of phase.tasks) {
          const icon =
            task.status === "done"
              ? th.fg("success", "   ✓")
              : task.status === "active"
              ? th.fg("accent", "   ●")
              : task.status === "paused"
              ? th.fg("warning", "   ⏸")
              : th.fg("dim", "   ○");
          const text =
            task.status === "done"
              ? th.fg("dim", task.title)
              : task.status === "active"
              ? th.fg("text", th.bold(task.title))
              : th.fg("muted", task.title);
          const xpTag =
            task.status === "done" ? th.fg("success", ` +${task.xp}xp`) : "";
          const idTag = th.fg("dim", ` [${task.id}]`);
          lines.push(truncateToWidth(`${icon} ${text}${xpTag}${idTag}`, width));
        }
        lines.push("");
      }
    }

    lines.push(
      truncateToWidth(
        th.fg("dim", "  ↑↓/jk navigate  q/Esc close  /task start <id>  /task done"),
        width
      )
    );
    lines.push("");

    this.cache = { w: width, lines };
    return lines;
  }

  invalidate(): void {
    this.cache = undefined;
  }
}

// ─── Extension ───────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  // Status footer: show active task + XP, or paused indicator
  function refreshStatus(ctx: { ui: { setStatus: (id: string, text: string) => void; theme: Theme } }): void {
    const th = ctx.ui.theme;
    const pause = loadPause();
    if (pause) {
      const at = new Date(pause.pausedAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
      ctx.ui.setStatus(
        "progress",
        th.fg("warning", "⏸ paused " + at) + th.fg("dim", "  /unpause to continue")
      );
      return;
    }
    const r = loadRoadmap();
    if (!r) return;
    const active = getActive(r);
    if (active) {
      ctx.ui.setStatus(
        "progress",
        th.fg("accent", "● ") + th.fg("dim", active.title) + th.fg("dim", `  ${r.xp}xp`)
      );
    } else {
      ctx.ui.setStatus(
        "progress",
        th.fg("dim", `${r.project}  ${r.xp}xp`)
      );
    }
  }

  pi.on("session_start", async (_event, ctx) => refreshStatus(ctx));
  pi.on("turn_end", async (_event, ctx) => refreshStatus(ctx));

  // ── /progress ──────────────────────────────────────────────────────────────
  pi.registerCommand("progress", {
    description: "Visual project roadmap with XP, streaks, and phase progress bars",
    handler: async (_args, ctx) => {
      const r = loadRoadmap();
      if (!r) {
        ctx.ui.notify(
          "No roadmap found for this project.\nRun /roadmap-init to create one.",
          "warning"
        );
        return;
      }
      await ctx.ui.custom<void>((_tui, theme, _kb, done) => {
        return new ProgressView(r, theme, () => done());
      });
    },
  });

  // ── /pause ─────────────────────────────────────────────────────────────────
  pi.registerCommand("pause", {
    description: "Pause and save full session state — runs immediately, even mid-execution",
    handler: async (_args, ctx) => {
      ensurePiDir();

      const { status, changed } = gitInfo();
      const r = loadRoadmap();
      const active = r ? getActive(r) : undefined;

      const state: PauseState = {
        pausedAt: new Date().toISOString(),
        activeTask: active
          ? { id: active.id, title: active.title, phase: active.phase }
          : undefined,
        summary: active ? `Mid-task: ${active.title}` : "Paused mid-session",
        changedFiles: changed,
        gitStatus: status,
        xp: r?.xp ?? 0,
      };

      writeFileSync(pausePath(), JSON.stringify(state, null, 2));

      // Mark task paused in roadmap
      if (r && active) {
        for (const phase of r.phases) {
          const t = phase.tasks.find((t) => t.id === active.id);
          if (t) t.status = "paused";
        }
        saveRoadmap(r);
      }

      // Steer agent to stop if it's running
      if (!ctx.isIdle()) {
        pi.sendUserMessage(
          "The user has paused the session. Stop what you are doing. Acknowledge briefly and stop.",
          { deliverAs: "steer" }
        );
      }

      const at = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
      const th = ctx.ui.theme;
      ctx.ui.setStatus(
        "progress",
        th.fg("warning", `⏸ paused ${at}`) + th.fg("dim", "  /unpause to continue")
      );
      ctx.ui.notify(
        `⏸  Paused at ${at}\n\n` +
          (active ? `Task: ${active.title}\n` : "") +
          (changed.length > 0 ? `Changed: ${changed.slice(0, 6).join(", ")}\n` : "") +
          `\nType /unpause to pick up where you left off.`,
        "info"
      );
    },
  });

  // ── /unpause ───────────────────────────────────────────────────────────────
  pi.registerCommand("unpause", {
    description: "Resume from a paused session — sends full context to the agent",
    handler: async (_args, ctx) => {
      const state = loadPause();
      const r = loadRoadmap();

      if (!state) {
        if (r) {
          const allTasks = r.phases.flatMap((p) => p.tasks);
          const done = allTasks.filter((t) => t.status === "done").length;
          ctx.ui.notify(
            `No pause state found.\n\n${r.project}: ${done}/${allTasks.length} tasks · ${r.xp} XP\n\nUse /progress for the full roadmap.`,
            "info"
          );
        } else {
          ctx.ui.notify("No pause state found.", "warning");
        }
        return;
      }

      // Restore task to active
      if (r && state.activeTask) {
        for (const phase of r.phases) {
          const t = phase.tasks.find((t) => t.id === state.activeTask!.id);
          if (t && t.status === "paused") t.status = "active";
        }
        saveRoadmap(r);
      }

      const pausedAt = new Date(state.pausedAt).toLocaleString();
      const lines: string[] = [
        `## Resuming session from ${pausedAt}`,
        "",
      ];

      if (state.activeTask) {
        lines.push(`**Last active task:** ${state.activeTask.title} (phase: ${state.activeTask.phase})`);
        lines.push(`**Task id:** \`${state.activeTask.id}\``);
        lines.push("");
      }

      if (state.changedFiles.length > 0) {
        lines.push("**Files changed since last commit:**");
        state.changedFiles.forEach((f) => lines.push(`  - ${f}`));
        lines.push("");
      }

      if (state.gitStatus) {
        lines.push("**Git status:**");
        lines.push("```");
        lines.push(state.gitStatus);
        lines.push("```");
        lines.push("");
      }

      if (r) {
        const allTasks = r.phases.flatMap((p) => p.tasks);
        const done = allTasks.filter((t) => t.status === "done").length;
        lines.push(
          `**Project progress:** ${done}/${allTasks.length} tasks complete · ${r.xp} XP total`
        );
        lines.push("");
      }

      lines.push(
        "Please give me a concise summary of where we left off and what the next step is."
      );

      const brief = lines.join("\n");

      refreshStatus(ctx);
      ctx.ui.notify(`▶  Resuming from ${pausedAt}...`, "info");

      if (!ctx.isIdle()) {
        pi.sendUserMessage(brief, { deliverAs: "followUp" });
      } else {
        pi.sendUserMessage(brief);
      }
    },
  });

  // ── /task ──────────────────────────────────────────────────────────────────
  pi.registerCommand("task", {
    description: "Task management — /task list | /task start <id> | /task done",
    handler: async (args, ctx) => {
      const [action, ...rest] = args.trim().split(/\s+/);
      const r = loadRoadmap();
      const th = ctx.ui.theme;

      if (!r) {
        ctx.ui.notify(
          "No roadmap. Run /roadmap-init to scaffold one for this project.",
          "warning"
        );
        return;
      }

      const allTasks = r.phases.flatMap((p) => p.tasks);

      if (!action || action === "list") {
        let msg = `Tasks — ${r.project}  (${r.xp} XP)\n\n`;
        for (const phase of r.phases) {
          msg += `${phase.name}:\n`;
          for (const t of phase.tasks) {
            const icon =
              t.status === "done" ? "✅" : t.status === "active" ? "●" : t.status === "paused" ? "⏸" : "○";
            msg += `  ${icon} [${t.id}]  ${t.title}  +${t.xp}xp\n`;
          }
          msg += "\n";
        }
        ctx.ui.notify(msg, "info");
        return;
      }

      if (action === "start") {
        const query = rest.join(" ").trim();
        if (!query) {
          ctx.ui.notify("Usage: /task start <id or partial title>", "warning");
          return;
        }
        const match =
          allTasks.find((t) => t.id === query) ||
          allTasks.find((t) => t.title.toLowerCase().includes(query.toLowerCase()));
        if (!match) {
          ctx.ui.notify(`Task not found: "${query}"\nRun /task list to see all ids.`, "error");
          return;
        }
        // Deactivate any current active task
        allTasks.forEach((t) => {
          if (t.status === "active") t.status = "paused";
        });
        match.status = "active";
        match.startedAt = new Date().toISOString();
        saveRoadmap(r);
        ctx.ui.setStatus(
          "progress",
          th.fg("accent", "● ") + th.fg("dim", match.title) + th.fg("dim", `  ${r.xp}xp`)
        );
        ctx.ui.notify(`▶  Started: ${match.title}`, "success");
        return;
      }

      if (action === "done") {
        const active = getActive(r);
        if (!active) {
          ctx.ui.notify("No active task. Use /task start <id> first.", "warning");
          return;
        }
        active.status = "done";
        active.completedAt = new Date().toISOString();
        r.xp += active.xp;

        // Streak tracking
        const today = new Date().toDateString();
        const lastDay = r.lastWorkedAt ? new Date(r.lastWorkedAt).toDateString() : null;
        const yesterday = new Date(Date.now() - 86400000).toDateString();
        if (lastDay === yesterday) r.streak += 1;
        else if (lastDay !== today) r.streak = 1;
        r.lastWorkedAt = new Date().toISOString();

        saveRoadmap(r);

        const remaining = allTasks.filter((t) => t.status === "todo" || t.status === "paused");
        const streakMsg = r.streak > 1 ? `  🔥 ${r.streak}-day streak!` : "";
        ctx.ui.notify(
          `✅  +${active.xp} XP  ·  ${active.title}\n\n` +
            `Total: ${r.xp} XP${streakMsg}\n` +
            `Remaining: ${remaining.length} tasks\n\n` +
            (remaining.length > 0
              ? `Next up: ${remaining[0].title}  [${remaining[0].id}]`
              : "🎉  All tasks complete!"),
          "success"
        );
        refreshStatus(ctx);
        return;
      }

      ctx.ui.notify("Usage: /task list | /task start <id> | /task done", "warning");
    },
  });

  // ── /roadmap-init ──────────────────────────────────────────────────────────
  pi.registerCommand("roadmap-init", {
    description: "Scaffold a .pi/roadmap.json for this project via the agent",
    handler: async (_args, ctx) => {
      if (existsSync(roadmapPath())) {
        const ok = await ctx.ui.confirm("Roadmap exists", "Overwrite existing roadmap?");
        if (!ok) return;
      }

      const prompt = `Please scaffold a project roadmap for this project.

Read the codebase to understand what has been built and what remains.

Then create the file \`.pi/roadmap.json\` with this structure:
\`\`\`json
{
  "project": "<project name>",
  "xp": 0,
  "streak": 0,
  "phases": [
    {
      "name": "Phase name",
      "tasks": [
        {
          "id": "kebab-case-id",
          "title": "Task title",
          "status": "todo",
          "phase": "Phase name",
          "xp": 20
        }
      ]
    }
  ]
}
\`\`\`

Rules:
- XP per task: 10 (small) · 20 (medium) · 30 (large) · 50 (major)
- Mark already-built work as "done"
- Group tasks into logical phases (Setup, Core, Features, Polish, etc.)
- Ask me for the project name and goals before writing the file.`;

      if (!ctx.isIdle()) {
        pi.sendUserMessage(prompt, { deliverAs: "followUp" });
      } else {
        pi.sendUserMessage(prompt);
      }
    },
  });
}
