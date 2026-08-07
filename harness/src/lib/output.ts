/** One reportable line. level ordering: error > warn > info > ok. */
export interface ReportItem {
  level: "ok" | "info" | "warn" | "error";
  message: string;
  id?: string; // stable id (doctor check id etc.)
  hint?: string; // "→ Run: harness sync"
}

/**
 * Collects report items and renders them either as human lines (with emoji + optional hint
 * line) or as a JSON array when json mode is on. Colors are emoji-only, so NO_COLOR needs
 * no special handling.
 */
export class Reporter {
  readonly items: ReportItem[] = [];
  #json: boolean;
  #write: (s: string) => void;

  constructor(props: { json: boolean; write: (s: string) => void }) {
    this.#json = props.json;
    this.#write = props.write;
  }

  /** Adds an item. @param props.item - The report line to record. @returns Nothing. */
  add(props: { item: ReportItem }): void {
    this.items.push(props.item);
  }

  ok(message: string, id?: string): void {
    this.add({ item: { level: "ok", message, ...(id !== undefined ? { id } : {}) } });
  }
  info(message: string, id?: string, hint?: string): void {
    this.add({ item: { level: "info", message, ...(id !== undefined ? { id } : {}), ...(hint !== undefined ? { hint } : {}) } });
  }
  warn(message: string, id?: string, hint?: string): void {
    this.add({ item: { level: "warn", message, ...(id !== undefined ? { id } : {}), ...(hint !== undefined ? { hint } : {}) } });
  }
  error(message: string, id?: string, hint?: string): void {
    this.add({ item: { level: "error", message, ...(id !== undefined ? { id } : {}), ...(hint !== undefined ? { hint } : {}) } });
  }

  /** True if any item is level "error". @returns Whether errors were recorded. */
  hasErrors(): boolean {
    return this.items.some((i) => i.level === "error");
  }

  /**
   * Renders all items. Human mode: `🔴 ERROR  msg` / `⚠️  WARN   msg` / `ℹ️  INFO   msg` /
   * `✅ OK     msg`, each followed by `          → hint` when present. JSON mode: one
   * JSON.stringify of the items array.
   * @returns Nothing (writes via the sink).
   */
  flush(): void {
    if (this.#json) {
      this.#write(JSON.stringify(this.items, null, 2));
      return;
    }
    for (const i of this.items) {
      const tag = { ok: "✅ OK    ", info: "ℹ️  INFO  ", warn: "⚠️  WARN  ", error: "🔴 ERROR " }[i.level];
      this.#write(`${tag} ${i.message}`);
      if (i.hint) this.#write(`          → ${i.hint}`);
    }
  }
}
