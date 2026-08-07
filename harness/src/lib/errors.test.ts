import { describe, expect, test } from "bun:test";
import { EXIT, HarnessError } from "./errors.ts";

describe("HarnessError", () => {
  test("carries code, hint, and explicit exit code", () => {
    const e = new HarnessError("manifest-invalid", "bad", { hint: "harness init", exitCode: EXIT.FAILURE });
    expect(e.code).toBe("manifest-invalid");
    expect(e.hint).toBe("harness init");
    expect(e.exitCode).toBe(3);
    expect(e.message).toBe("bad");
  });
  test("default exit code is USAGE (2)", () => {
    expect(new HarnessError("usage", "x").exitCode).toBe(2);
  });
});
