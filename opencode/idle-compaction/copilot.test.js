import assert from "node:assert/strict";
import { test } from "node:test";
import { copilotIdlePolicy } from "./copilot.js";

const model = { providerID: "github-copilot", id: "gpt-6.1-sol" };

test("configured GPT families default to a direct fifty-four-minute timer and 200k tokens", () => {
  for (const id of [
    "gpt-5.6-sol",
    "gpt-6-luna",
    "gpt-6.1-sol",
    "gpt-6.1-terra",
  ]) {
    assert.deepEqual(copilotIdlePolicy({ ...model, id }), {
      afterMs: 3_240_000,
      minInputTokens: 200_000,
    });
  }
});

test("Claude models default to a direct three-minute timer", () => {
  for (const id of [
    "claude-opus-5.5",
    "claude-sonnet-5.5",
    "claude-haiku-4.5",
  ]) {
    assert.deepEqual(copilotIdlePolicy({ ...model, id }), {
      afterMs: 180_000,
      minInputTokens: 200_000,
    });
  }
});

test("other providers, including Go, are not eligible", () => {
  for (const providerID of ["opencode-go", "opencode", "anthropic"]) {
    assert.equal(copilotIdlePolicy({ ...model, providerID }), undefined);
  }
});

test("unknown models are skipped unless an explicit timer opts them in", () => {
  const unknown = { ...model, id: "unknown" };
  assert.equal(copilotIdlePolicy(unknown), undefined);
  assert.deepEqual(
    copilotIdlePolicy(unknown, { models: { unknown: { after: "10m" } } }),
    {
      afterMs: 600_000,
      minInputTokens: 200_000,
    },
  );
});

test("per-model timers and sizes override global settings independently", () => {
  const options = {
    after: "20m",
    minInputTokens: 300_000,
    models: {
      [model.id]: { after: "54m", minInputTokens: 250_000 },
      "claude-opus-5.5": { minInputTokens: 400_000 },
    },
  };
  assert.deepEqual(copilotIdlePolicy(model, options), {
    afterMs: 3_240_000,
    minInputTokens: 250_000,
  });
  assert.deepEqual(
    copilotIdlePolicy({ ...model, id: "claude-opus-5.5" }, options),
    {
      afterMs: 1_200_000,
      minInputTokens: 400_000,
    },
  );
  assert.deepEqual(
    copilotIdlePolicy(model, {
      models: { [model.id]: { minInputTokens: 100_000 } },
    }),
    {
      afterMs: 3_240_000,
      minInputTokens: 100_000,
    },
  );
});

test("model overrides can disable scheduling", () => {
  assert.equal(
    copilotIdlePolicy(model, { models: { [model.id]: false } }),
    undefined,
  );
});

test("invalid timers and thresholds fail closed", () => {
  for (const after of [
    "0m",
    "forever",
    "-5m",
    "Infinityh",
    "9999999999999999d",
    300,
    null,
    false,
  ]) {
    assert.equal(
      copilotIdlePolicy(model, { models: { [model.id]: { after } } }),
      undefined,
    );
  }
  for (const minInputTokens of [0, -1, NaN, 1.5, "200000"]) {
    assert.equal(copilotIdlePolicy(model, { minInputTokens }), undefined);
  }
});

test("catalog TTLs do not silently change the requested timer", () => {
  assert.deepEqual(
    copilotIdlePolicy({ ...model, settings: { cache: { ttl: "30m" } } }),
    {
      afterMs: 3_240_000,
      minInputTokens: 200_000,
    },
  );
});

test("native compaction is not assumed to reuse the prompt cache", () => {
  assert.equal(
    copilotIdlePolicy({
      ...model,
      settings: { compaction: { type: "native" } },
    }),
    undefined,
  );
});
