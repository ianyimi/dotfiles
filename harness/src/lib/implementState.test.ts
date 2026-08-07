import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { mkTmpProject, rmProject } from "../../test/helpers.ts";
import { seedDemoSpec } from "../../test/specFixture.ts";
import { IMPLEMENT_STATE_FILE, loadImplementState, saveImplementState } from "./implementState.ts";

describe("implementState", () => {
  test("defaults on absent file", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const specDir = seedDemoSpec({ dir });
    expect(loadImplementState({ specDir, slug: "demo-feature" })).toEqual({
      version: 1,
      slug: "demo-feature",
      updated: "",
      groups: {},
    });
    rmProject({ dir });
  });

  test("round-trips with lexicographically sorted group keys, byte-stable", () => {
    const dir = mkTmpProject({ fixture: "initialized" });
    const specDir = seedDemoSpec({ dir });
    saveImplementState({
      specDir,
      state: {
        version: 1,
        slug: "demo-feature",
        updated: "2026-08-07T10:00:00Z",
        groups: {
          T2: { attempts: 1, last_result: "pass", last_exit_code: 0, last_output_tail: [] },
          T10: { attempts: 0, last_result: null, last_exit_code: null, last_output_tail: [] },
          T1: { attempts: 2, last_result: "fail", last_exit_code: 1, last_output_tail: ["boom"] },
        },
      },
    });
    const raw = readFileSync(join(specDir, IMPLEMENT_STATE_FILE), "utf8");
    expect(Object.keys(JSON.parse(raw).groups)).toEqual(["T1", "T10", "T2"]);
    const loaded = loadImplementState({ specDir, slug: "demo-feature" });
    saveImplementState({ specDir, state: loaded });
    expect(readFileSync(join(specDir, IMPLEMENT_STATE_FILE), "utf8")).toBe(raw);
    rmProject({ dir });
  });
});
