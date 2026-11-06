import assert from "node:assert/strict";
import { setImmediate } from "node:timers/promises";
import { test } from "node:test";
import { createScheduler } from "./scheduler.js";

const model = { providerID: "github-copilot", id: "gpt-6.1-sol" };
const tokens = {
  input: 5_000,
  output: 100,
  cache: { read: 195_000, write: 0 },
};

function fixture(t, options = {}) {
  t.mock.timers.enable({ apis: ["Date", "setTimeout"], now: 1_000_000 });
  const calls = [];
  const errors = [];
  const scheduler = createScheduler({
    compact: async (id) => calls.push(id),
    canCompact: async () => true,
    onError: (error) => errors.push(error),
    ...options,
  });
  t.after(() => scheduler.dispose());
  const tick = async (ms) => {
    t.mock.timers.tick(ms);
    await setImmediate();
  };
  const request = (id = "one") =>
    scheduler.begin(id, model, { afterMs: 240_000, minInputTokens: 200_000 });
  const finish = (id = "one", usage = tokens) => {
    scheduler.complete(id, usage);
    scheduler.idle(id);
  };
  return { scheduler, calls, errors, tick, request, finish };
}

test("compacts once at the direct deadline, anchored to request start", async (t) => {
  const f = fixture(t);
  f.request();
  await f.tick(30_000);
  f.finish();
  await f.tick(209_999);
  assert.deepEqual(f.calls, []);
  await f.tick(1);
  assert.deepEqual(f.calls, ["one"]);
  await f.tick(3_600_000);
  assert.deepEqual(f.calls, ["one"]);
});

test("new model activity replaces a pending timer", async (t) => {
  const f = fixture(t);
  f.request();
  f.finish();
  await f.tick(200_000);
  f.request();
  f.finish();
  await f.tick(40_000);
  assert.deepEqual(f.calls, []);
  await f.tick(200_000);
  assert.deepEqual(f.calls, ["one"]);
});

test("active sessions and sessions without cache evidence are skipped", async (t) => {
  const f = fixture(t);
  f.request("busy");
  f.scheduler.complete("busy", tokens);
  f.request("cold");
  f.finish("cold", { input: 250_000, cache: { read: 0, write: 0 } });
  f.request("small");
  f.finish("small", { input: 100, cache: { read: 100, write: 0 } });
  await f.tick(240_000);
  assert.deepEqual(f.calls, []);
});

test("cache writes also establish cache evidence", async (t) => {
  const f = fixture(t);
  f.request();
  f.finish("one", { input: 100, cache: { read: 0, write: 200_000 } });
  await f.tick(240_000);
  assert.deepEqual(f.calls, ["one"]);
});

test("cancel handles model switches, compaction, failure and deletion", async (t) => {
  const f = fixture(t);
  f.request();
  f.finish();
  f.scheduler.cancel("one");
  await f.tick(240_000);
  assert.deepEqual(f.calls, []);
});

test("a stale deadline is skipped after machine sleep or a long response", async (t) => {
  const f = fixture(t);
  f.request();
  f.finish();
  t.mock.timers.setTime(Date.now() + 400_000);
  await f.tick(1);
  f.request("slow");
  await f.tick(400_000);
  f.finish("slow");
  await f.tick(1);
  assert.deepEqual(f.calls, []);
});

test("a delayed timer inside the lateness tolerance still compacts", async (t) => {
  const f = fixture(t);
  f.request();
  f.finish();
  t.mock.timers.setTime(Date.now() + 250_000);
  await f.tick(1);
  assert.deepEqual(f.calls, ["one"]);
});

test("an eligibility check finishing past the lateness tolerance is skipped", async (t) => {
  let release;
  const f = fixture(t, {
    canCompact: () =>
      new Promise((resolve) => {
        release = resolve;
      }),
  });
  f.request();
  f.finish();
  await f.tick(240_000);
  t.mock.timers.setTime(Date.now() + 60_000);
  release(true);
  await f.tick(1);
  assert.deepEqual(f.calls, []);
});

test("invalid per-request policies cannot arm a timer", async (t) => {
  const f = fixture(t);
  for (const policy of [
    undefined,
    { afterMs: 0, minInputTokens: 200_000 },
    { afterMs: 240_000, minInputTokens: -1 },
  ]) {
    f.scheduler.begin("one", model, policy);
    f.finish();
    await f.tick(240_000);
  }
  assert.deepEqual(f.calls, []);
});

test("sessions have independent deadlines", async (t) => {
  const f = fixture(t);
  f.request("one");
  f.finish("one");
  await f.tick(60_000);
  f.request("two");
  f.finish("two");
  await f.tick(180_000);
  assert.deepEqual(f.calls, ["one"]);
  await f.tick(60_000);
  assert.deepEqual(f.calls, ["one", "two"]);
});

test("rechecks eligibility immediately before admission", async (t) => {
  const f = fixture(t, { canCompact: async () => false });
  f.request();
  f.finish();
  await f.tick(240_000);
  assert.deepEqual(f.calls, []);
});

test("new input during an asynchronous eligibility check invalidates admission", async (t) => {
  let release;
  const f = fixture(t, {
    canCompact: () =>
      new Promise((resolve) => {
        release = resolve;
      }),
  });
  f.request();
  f.finish();
  await f.tick(240_000);
  f.scheduler.cancel("one");
  release(true);
  await f.tick(1);
  assert.deepEqual(f.calls, []);
});

test("compaction failures are reported without retry loops", async (t) => {
  const error = new Error("unavailable");
  const f = fixture(t, {
    compact: async () => {
      throw error;
    },
  });
  f.request();
  f.finish();
  await f.tick(240_000);
  await f.tick(600_000);
  assert.deepEqual(f.errors, [error]);
});

test("unload cancels all timers and prevents late work from rearming", async (t) => {
  const f = fixture(t);
  f.request();
  f.finish();
  f.scheduler.dispose();
  f.request("late");
  f.finish("late");
  await f.tick(240_000);
  assert.deepEqual(f.calls, []);
});

test("idle hooks may arrive before the usage event", async (t) => {
  const f = fixture(t);
  f.request();
  f.scheduler.idle("one");
  f.scheduler.complete("one", tokens);
  await f.tick(240_000);
  assert.deepEqual(f.calls, ["one"]);
});

test("invalid lateness options are rejected", () => {
  for (const options of [
    { maxLatenessMs: 0 },
    { maxLatenessMs: NaN },
    { maxLatenessMs: -1 },
  ]) {
    assert.throws(() => createScheduler(options), /positive/);
  }
});

test("diagnostics distinguish invalid usage, missing cache evidence, and late deadlines", async (t) => {
  const logs = [];
  const f = fixture(t, {
    onDiagnostic: (event, details) => logs.push({ event, ...details }),
  });
  f.request("invalid");
  f.finish("invalid", { input: 250_000 });
  f.request("cold");
  f.finish("cold", { input: 250_000, cache: { read: 0, write: 0 } });
  f.request("late");
  f.finish("late");
  t.mock.timers.setTime(Date.now() + 400_000);
  await f.tick(1);
  f.request("slow");
  await f.tick(400_000);
  f.finish("slow");
  for (const [sessionID, reason] of [
    ["invalid", "invalid-token-usage"],
    ["cold", "no-cache-evidence"],
    ["late", "timer-too-late"],
    ["slow", "deadline-passed"],
  ]) {
    assert.ok(
      logs.some(
        (log) =>
          log.event === "skipped" &&
          log.sessionID === sessionID &&
          log.reason === reason,
      ),
    );
  }
  assert.deepEqual(f.calls, []);
});
