import assert from "node:assert/strict";
import { test } from "node:test";
import { copilotCachePolicy } from "./copilot.js";

const model = { providerID: "github-copilot", id: "gpt-6.1-sol" };

test("models without a documented or configured TTL are skipped", () => {
  assert.equal(copilotCachePolicy(model), undefined);
  assert.equal(copilotCachePolicy({ ...model, id: "unknown" }), undefined);
});

test("an explicit fallback remains available as an opt-in", () => {
  assert.equal(copilotCachePolicy(model, { ttl: "30m" }), 1_800_000);
});

test("other providers, including Go, are not eligible", () => {
  for (const providerID of ["opencode-go", "opencode", "anthropic"]) {
    assert.equal(copilotCachePolicy({ ...model, providerID }), undefined);
  }
});

test("model TTL takes precedence over the fallback", () => {
  assert.equal(
    copilotCachePolicy({ ...model, settings: { cache: { ttl: "1h" } } }),
    3_600_000,
  );
});

test("plugin model overrides can set or disable an estimate", () => {
  assert.equal(
    copilotCachePolicy(model, { models: { [model.id]: "30m" } }),
    1_800_000,
  );
  assert.equal(
    copilotCachePolicy(model, { models: { [model.id]: false } }),
    undefined,
  );
  assert.equal(copilotCachePolicy(model, { ttl: false }), undefined);
});

test("invalid TTLs fail closed instead of silently using the fallback", () => {
  for (const ttl of ["0m", "forever", "-5m", "Infinityh", 300, null]) {
    assert.equal(copilotCachePolicy(model, { ttl }), undefined);
  }
});

test("native compaction is not assumed to reuse the prompt cache", () => {
  assert.equal(
    copilotCachePolicy({
      ...model,
      settings: { compaction: { type: "native" } },
    }),
    undefined,
  );
});
