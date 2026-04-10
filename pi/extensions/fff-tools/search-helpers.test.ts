import { describe, expect, it } from "vitest";

import {
  appendUniqueTrimmedLines,
  buildBuiltinFallbackGrepInput,
  normalizePatterns,
} from "./search-helpers";

describe("buildBuiltinFallbackGrepInput", () => {
  it("forces literal matching for punctuation-heavy patterns", () => {
    expect(
      buildBuiltinFallbackGrepInput(
        { path: ".", glob: "**/*.ts" },
        "print(",
        7,
      ),
    ).toEqual({
      pattern: "print(",
      path: ".",
      glob: "**/*.ts",
      literal: true,
      limit: 7,
    });
  });
});

describe("appendUniqueTrimmedLines", () => {
  it("deduplicates lines and respects the overall max result limit", () => {
    const lines: string[] = [];
    const seen = new Set<string>();

    appendUniqueTrimmedLines(
      lines,
      seen,
      [
        "a.ts:1: print(",
        "a.ts:1: print(",
        "b.ts:2: print(",
        "c.ts:3: print(",
      ].join("\n"),
      2,
    );

    expect(lines).toEqual(["a.ts:1: print(", "b.ts:2: print("]);
  });

  it("drops per-pattern no-match sentinel lines from aggregated output", () => {
    const lines: string[] = [];
    const seen = new Set<string>();

    appendUniqueTrimmedLines(
      lines,
      seen,
      ["a.ts:1: fff-mcp", "No matches found", "No matches found."].join("\n"),
      10,
    );

    expect(lines).toEqual(["a.ts:1: fff-mcp"]);
  });
});

describe("normalizePatterns", () => {
  it("strips leading @ markers and empty patterns", () => {
    expect(normalizePatterns([" @foo ", "", "   ", "bar"])).toEqual([
      "foo",
      "bar",
    ]);
  });
});
