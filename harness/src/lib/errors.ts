/** Exit codes per master §2.9. */
export const EXIT = { OK: 0, FINDINGS: 1, USAGE: 2, FAILURE: 3 } as const;

/**
 * A user-facing harness failure with a stable machine code and optional fix hint.
 * Thrown by lib/commands; caught once in cli.ts and rendered by the Reporter.
 */
export class HarnessError extends Error {
  /** Stable kebab-case code, e.g. "manifest-invalid", "not-initialized". */
  readonly code: string;
  /** Optional "run this" remediation, e.g. "harness init". */
  readonly hint?: string;
  /** Exit code to use; defaults to EXIT.USAGE for validation-shaped errors. */
  readonly exitCode: number;
  constructor(code: string, message: string, opts?: { hint?: string; exitCode?: number }) {
    super(message);
    this.code = code;
    this.hint = opts?.hint;
    this.exitCode = opts?.exitCode ?? EXIT.USAGE;
  }
}
