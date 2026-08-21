export interface Frontmatter {
  /** Parsed keys. Values: string | boolean | number | string[]. Unknown keys preserved. */
  data: Record<string, unknown>;
  /** Document body after the closing --- (kept verbatim so raw + body === source). */
  body: string;
  /** The raw frontmatter block INCLUDING delimiters, byte-exact, for round-tripping. */
  raw: string;
}

/** Parses one scalar: booleans, integers, quoted/unquoted strings. */
function parseScalar(rawValue: string): unknown {
  const v = rawValue.trim();
  if (v === "true") return true;
  if (v === "false") return false;
  if (/^-?\d+$/.test(v)) return Number(v);
  if ((v.startsWith('"') && v.endsWith('"') && v.length >= 2) || (v.startsWith("'") && v.endsWith("'") && v.length >= 2)) {
    return v.slice(1, -1);
  }
  return v;
}

/** Splits an inline array body on top-level commas (no nesting in flat frontmatter). */
function parseInlineArray(inner: string): unknown[] {
  const trimmed = inner.trim();
  if (trimmed === "") return [];
  return trimmed.split(",").map((part) => parseScalar(part));
}

/**
 * Tolerant flat-YAML frontmatter parser (master §8). Handles: `key: value`, quoted strings,
 * booleans, numbers, inline arrays `[a, b]`, dash lists, and multi-line folded strings with
 * 2-space continuation (pi descriptions use these). Unknown keys are preserved verbatim.
 *
 * @param props.text - Full file content.
 * @returns Parsed frontmatter; when the file has no leading `---` line, data={}, raw="",
 *   body=text.
 * @throws Never — malformed lines land in data as raw strings; tolerance is the contract.
 */
export function parseFrontmatter(props: { text: string }): Frontmatter {
  const text = props.text;
  if (!text.startsWith("---\n") && !text.startsWith("---\r\n")) {
    return { data: {}, body: text, raw: "" };
  }

  // Walk lines, tracking byte offsets so `raw` stays byte-exact.
  const firstNl = text.indexOf("\n");
  let offset = firstNl + 1;
  let closeEnd = -1;
  const innerLines: string[] = [];
  while (offset <= text.length) {
    const nl = text.indexOf("\n", offset);
    const lineEnd = nl === -1 ? text.length : nl;
    const line = text.slice(offset, lineEnd).replace(/\r$/, "");
    if (line === "---") {
      closeEnd = nl === -1 ? text.length : nl + 1;
      break;
    }
    innerLines.push(line);
    if (nl === -1) break;
    offset = nl + 1;
  }
  if (closeEnd === -1) {
    // No closing delimiter — treat the whole file as body (tolerance contract).
    return { data: {}, body: text, raw: "" };
  }

  const data: Record<string, unknown> = {};
  let lastKey: string | null = null;
  for (const line of innerLines) {
    if (line.trim() === "") {
      lastKey = null;
      continue;
    }
    // Dash-list item under the previous `key:` line.
    const dash = line.match(/^\s*-\s+(.*)$/);
    if (dash !== null && lastKey !== null && (data[lastKey] === "" || Array.isArray(data[lastKey]))) {
      const arr = Array.isArray(data[lastKey]) ? (data[lastKey] as unknown[]) : [];
      arr.push(parseScalar(dash[1] as string));
      data[lastKey] = arr;
      continue;
    }
    // Folded continuation of a string value (2+ leading spaces).
    if (/^ {2,}\S/.test(line) && lastKey !== null && typeof data[lastKey] === "string") {
      data[lastKey] = `${data[lastKey] as string} ${line.trim()}`;
      continue;
    }
    const kv = line.match(/^([A-Za-z0-9_-]+):(.*)$/);
    if (kv === null) {
      // Malformed line — preserve it under its own text as a key with empty value.
      data[line.trim()] = "";
      lastKey = null;
      continue;
    }
    const key = kv[1] as string;
    const rest = (kv[2] as string).trim();
    if (rest === "") {
      data[key] = ""; // may become a dash list
      lastKey = key;
    } else if (rest.startsWith("[") && rest.endsWith("]")) {
      data[key] = parseInlineArray(rest.slice(1, -1));
      lastKey = null;
    } else {
      data[key] = parseScalar(rest);
      lastKey = key; // string values may fold across lines
    }
  }

  return { data, body: text.slice(closeEnd), raw: text.slice(0, closeEnd) };
}

/** Quotes a string value only when serialization would otherwise be ambiguous. */
function quoteIfNeeded(value: string): string {
  if (value.includes(": ") || value.includes("#") || value !== value.trim() || value === "") {
    return `"${value}"`;
  }
  return value;
}

function serializeValue(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map((v) => (typeof v === "string" ? quoteIfNeeded(v) : String(v))).join(", ")}]`;
  }
  if (typeof value === "string") return quoteIfNeeded(value);
  return String(value);
}

/** Deep equality for flat frontmatter values (scalars + arrays, insertion order significant). */
function dataEquals(a: Record<string, unknown>, b: Record<string, unknown>): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

/**
 * Serializes data + body back to a document. If props.raw is provided and props.data is
 * unchanged from its parse, emits raw verbatim (byte-exact round-trip guarantee).
 *
 * @param props.data - Frontmatter keys (insertion order preserved).
 * @param props.body - Document body.
 * @param props.raw - Optional original raw block for the unchanged fast path.
 * @returns Full document text.
 */
export function serializeFrontmatter(props: {
  data: Record<string, unknown>;
  body: string;
  raw?: string;
}): string {
  if (props.raw !== undefined && props.raw !== "") {
    const reparsed = parseFrontmatter({ text: props.raw });
    if (dataEquals(reparsed.data, props.data)) return props.raw + props.body;
  }
  if (Object.keys(props.data).length === 0) return props.body;
  const lines = Object.entries(props.data).map(([k, v]) => `${k}: ${serializeValue(v)}`);
  return `---\n${lines.join("\n")}\n---\n\n${props.body}`;
}
