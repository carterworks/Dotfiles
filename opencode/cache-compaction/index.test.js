import assert from "node:assert/strict";
import { setImmediate } from "node:timers/promises";
import { test } from "node:test";
import plugin from "./index.js";

const ref = { providerID: "github-copilot", id: "gpt-6.1-sol" };
const usage = { input: 5_000, cache: { read: 40_000, write: 0 } };

async function fixture(t, options = {}) {
  t.mock.timers.enable({ apis: ["Date", "setTimeout"], now: 1_000_000 });
  const hooks = new Map();
  const events = [];
  let wake;
  let stopped = false;
  const calls = [];
  const session = {
    id: "one",
    model: ref,
    location: { directory: "/project" },
    time: { busy: 1, idle: 2 },
  };
  const agent = {};
  const ctx = {
    options,
    location: { directory: "/project" },
    model: {
      list: async () => ({ data: [ref] }),
      default: async () => ({ data: ref }),
    },
    agent: { get: async () => ({ data: agent }) },
    session: {
      get: async () => session,
      compact: async (input) => {
        calls.push(input);
      },
      hook: async (name, callback) => {
        hooks.set(name, callback);
        return { dispose: async () => hooks.delete(name) };
      },
    },
    event: {
      async *subscribe({ signal }) {
        signal.addEventListener(
          "abort",
          () => {
            stopped = true;
            wake?.();
          },
          { once: true },
        );
        while (!stopped) {
          if (!events.length)
            await new Promise((resolve) => {
              wake = resolve;
            });
          while (events.length) yield events.shift();
        }
      },
    },
  };
  const cleanup = await plugin.setup(ctx);
  t.after(cleanup);
  async function emit(type, data = {}) {
    events.push({
      type,
      location: { directory: "/project" },
      data: { sessionID: "one", ...data },
    });
    wake?.();
    await setImmediate();
  }
  const dispatch = (kind = "primary", model = ref) =>
    hooks.get("model.request")({ sessionID: "one", kind, model });
  async function finish(background = []) {
    await emit("session.step.ended", { tokens: usage, finish: "stop" });
    await hooks.get("experimental.idle")({ sessionID: "one", background });
  }
  async function tick(ms = 240_000) {
    t.mock.timers.tick(ms);
    await setImmediate();
  }
  return {
    ctx,
    hooks,
    calls,
    session,
    agent,
    emit,
    dispatch,
    finish,
    tick,
    cleanup,
  };
}

test("the V2 plugin compacts using queue delivery and ignores its auxiliary requests", async (t) => {
  const f = await fixture(t);
  await f.dispatch();
  await f.finish();
  await f.dispatch("title");
  await f.dispatch("generate");
  await f.tick();
  assert.deepEqual(f.calls, [{ sessionID: "one", delivery: "queue" }]);
  await f.dispatch("compaction");
  await f.finish();
  await f.tick();
  assert.equal(f.calls.length, 1);
});

test("Go requests never schedule compaction", async (t) => {
  const f = await fixture(t);
  await f.dispatch("primary", { ...ref, providerID: "opencode-go" });
  await f.finish();
  await f.tick();
  assert.deepEqual(f.calls, []);
});

test("subagents and sessions with background work are skipped", async (t) => {
  const f = await fixture(t);
  f.session.parentID = "parent";
  await f.dispatch();
  await f.finish();
  await f.tick();
  delete f.session.parentID;
  await f.dispatch();
  await f.finish([{ kind: "shell" }]);
  await f.tick();
  assert.deepEqual(f.calls, []);
});

test("prompt admission cancels a deadline before the next model dispatch", async (t) => {
  const f = await fixture(t);
  await f.dispatch();
  await f.finish();
  await f.hooks.get("prompt")({ sessionID: "one" });
  await f.tick();
  assert.deepEqual(f.calls, []);
});

for (const type of [
  "session.model.selected",
  "session.agent.selected",
  "session.archived",
  "session.deleted",
  "session.moved",
  "session.execution.started",
  "session.execution.failed",
  "session.execution.interrupted",
  "session.step.failed",
  "session.compaction.started",
  "session.revert.staged",
  "session.inbox.enqueued",
]) {
  test(`${type} invalidates a pending compaction`, async (t) => {
    const f = await fixture(t);
    await f.dispatch();
    await f.finish();
    await f.emit(type);
    await f.tick();
    assert.deepEqual(f.calls, []);
  });
}

test("a different compaction model cannot use the session's cache", async (t) => {
  const f = await fixture(t);
  f.agent.model = { ...ref, id: "claude-haiku-5.5" };
  await f.dispatch();
  await f.finish();
  await f.tick();
  assert.deepEqual(f.calls, []);
});

test("eligibility rechecks live session state", async (t) => {
  const f = await fixture(t);
  for (const change of [
    () => {
      f.session.time.busy = 3;
    },
    () => {
      f.session.time.archived = 3;
    },
    () => {
      f.session.model = { ...ref, id: "other" };
    },
    () => {
      f.session.location.directory = "/elsewhere";
    },
  ]) {
    f.session.time = { busy: 1, idle: 2 };
    f.session.model = ref;
    f.session.location.directory = "/project";
    await f.dispatch();
    await f.finish();
    change();
    await f.tick();
  }
  assert.deepEqual(f.calls, []);
});

test("cleanup cancels timers and unregisters hooks", async (t) => {
  const f = await fixture(t);
  await f.dispatch();
  await f.finish();
  await f.cleanup();
  await f.tick();
  assert.deepEqual(f.calls, []);
  assert.equal(f.hooks.size, 0);
});

test("model catalog TTLs and variant settings control the deadline", async (t) => {
  const f = await fixture(t);
  const selected = { ...ref, variant: "extended" };
  f.session.model = selected;
  f.ctx.model.list = async () => ({
    data: [
      {
        ...ref,
        settings: { cache: { ttl: "5m" } },
        variants: [{ id: "extended", settings: { cache: { ttl: "1h" } } }],
      },
    ],
  });
  await f.dispatch("primary", selected);
  await f.finish();
  await f.tick(240_000);
  assert.deepEqual(f.calls, []);
  await f.tick(3_300_000);
  assert.equal(f.calls.length, 1);
});

test("a session inheriting the default model remains eligible", async (t) => {
  const f = await fixture(t);
  delete f.session.model;
  await f.dispatch();
  await f.finish();
  await f.tick();
  assert.equal(f.calls.length, 1);
});

test("lookup failures do not break model dispatch or reuse an earlier timer", async (t) => {
  const f = await fixture(t);
  t.mock.method(console, "warn", () => {});
  await f.dispatch();
  await f.finish();
  f.ctx.model.list = async () => {
    throw new Error("catalog unavailable");
  };
  await f.dispatch();
  await f.finish();
  await f.tick();
  assert.deepEqual(f.calls, []);
});
