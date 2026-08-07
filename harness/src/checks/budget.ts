/**
 * Counts non-empty lines (the budget unit for preferences/anti-patterns/skills).
 *
 * @param props.text - File content.
 * @returns Number of lines with non-whitespace content.
 */
export function countLines(props: { text: string }): number {
  return props.text.split("\n").filter((l) => l.trim() !== "").length;
}
