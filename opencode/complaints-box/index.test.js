import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import plugin from "./index.js";
import { resolveBoxPath, readEntries } from "./store.js";

function makeTempDir(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "complaints-box-test-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

async function setupPlugin({
  options = {},
  location = { directory: "/repo/wt", project: { canonical: "/repo" } },
  sessionModel = { providerID: "github-copilot", id: "claude-opus-5.5" },
  appVersion = "2.3.2",
} = {}) {
  const tools = new Map();
  const commands = new Map();
  const hooks = new Map();
  const prompts = [];

  const ctx = {
    options,
    app: { version: appVersion },
    location,
    session: {
      get: async ({ sessionID }) => ({
        id: sessionID,
        model: sessionModel,
        location,
      }),
      prompt: async (input) => {
        prompts.push(input);
      },
      hook: async (name, cb) => {
        hooks.set(name, cb);
        return { dispose: async () => hooks.delete(name) };
      },
    },
    tool: {
      transform: async (cb) => {
        cb({
          add(def) {
            tools.set(def.name, def);
          },
        });
        return { dispose: async () => tools.clear() };
      },
    },
    command: {
      transform: async (cb) => {
        cb({
          add(def) {
            commands.set(def.name, def);
          },
        });
        return { dispose: async () => commands.clear() };
      },
    },
  };

  const dispose = await plugin.setup(ctx);
  return { tools, commands, hooks, prompts, dispose };
}

test("resolveBoxPath routes harness to config dir and codebase to canonical project .opencode", () => {
  const harness = resolveBoxPath({
    scope: "harness",
    projectDir: "/work/private-repo",
    harnessPath: "/home/me/.config/opencode/complaints-box.jsonl",
  });
  assert.equal(harness, "/home/me/.config/opencode/complaints-box.jsonl");

  const codebase = resolveBoxPath({
    scope: "codebase",
    projectDir: "/work/private-repo",
    harnessPath: "/home/me/.config/opencode/complaints-box.jsonl",
  });
  assert.equal(codebase, "/work/private-repo/.opencode/complaints-box.jsonl");
});

test("complaints_box tool signs entries with model metadata and routes by scope", async (t) => {
  const tmp = makeTempDir(t);
  const harnessPath = path.join(tmp, "config", "opencode", "complaints-box.jsonl");
  const repoDir = path.join(tmp, "my-repo");
  fs.mkdirSync(repoDir, { recursive: true });

  const { tools, dispose } = await setupPlugin({
    options: { harnessPath },
    location: { directory: repoDir, project: { canonical: repoDir } },
    sessionModel: { providerID: "github-copilot", id: "claude-opus-5.5", variant: "high" },
  });

  const tool = tools.get("complaints_box");
  assert.ok(tool);
  assert.equal(tool.options.codemode, false);

  const res1 = await tool.execute(
    {
      scope: "harness",
      summary: "Stale flag in skill",
      details: "Skill told me to pass --fast but CLI expects --quick.",
      category: "skill",
      workaround: "Used --quick",
    },
    { sessionID: "ses_1", agent: "build" },
  );
  assert.match(res1.content, /complaints box/i);

  const res2 = await tool.execute(
    {
      scope: "codebase",
      summary: "Copy-pasted currency formatter",
      details: "formatCurrency is duplicated in 3 files.",
    },
    { sessionID: "ses_1", agent: "build" },
  );
  assert.match(res2.content, /complaints box/i);

  const harnessEntries = readEntries(harnessPath);
  assert.equal(harnessEntries.length, 1);
  assert.equal(harnessEntries[0].scope, "harness");
  assert.equal(harnessEntries[0].category, "skill");
  assert.equal(harnessEntries[0].model, "github-copilot/claude-opus-5.5#high");
  assert.equal(harnessEntries[0].agent, "build");
  assert.equal(harnessEntries[0].sessionID, "ses_1");
  assert.equal(harnessEntries[0].opencodeVersion, "2.3.2");
  assert.ok(harnessEntries[0].id);
  assert.ok(harnessEntries[0].timestamp);

  const codebaseEntries = readEntries(path.join(repoDir, ".opencode", "complaints-box.jsonl"));
  assert.equal(codebaseEntries.length, 1);
  assert.equal(codebaseEntries[0].scope, "codebase");
  assert.equal(codebaseEntries[0].category, "other");
  assert.equal(codebaseEntries[0].model, "github-copilot/claude-opus-5.5#high");

  await dispose();
});

test("context hook adds static system prompt and ephemeral recency reminder on tool turns until logged", async (t) => {
  const tmp = makeTempDir(t);
  const harnessPath = path.join(tmp, "harness.jsonl");
  const { tools, hooks, dispose } = await setupPlugin({
    options: { harnessPath },
    location: { directory: tmp, project: { canonical: tmp } },
  });

  const onContext = hooks.get("context");
  assert.ok(onContext);

  const firstTurn = {
    sessionID: "ses_2",
    system: [],
    messages: [{ role: "user", content: [{ type: "text", text: "hi" }] }],
  };
  onContext(firstTurn);
  assert.equal(firstTurn.system.length, 1);
  assert.equal(firstTurn.messages.length, 1);

  const toolTurn = {
    sessionID: "ses_2",
    system: [],
    messages: [
      { role: "user", content: [{ type: "text", text: "run tests" }] },
      { role: "assistant", content: [{ type: "tool-call" }] },
      { role: "tool", content: [{ type: "tool-result" }] },
    ],
  };
  onContext(toolTurn);
  assert.equal(toolTurn.system.length, 1);
  assert.equal(toolTurn.messages.length, 4);
  assert.equal(toolTurn.messages[3].role, "user");
  assert.match(toolTurn.messages[3].content[0].text, /<system-reminder>/);

  await tools.get("complaints_box").execute(
    { scope: "harness", summary: "Bump", details: "Details" },
    { sessionID: "ses_2", agent: "build" },
  );

  const afterLog = {
    sessionID: "ses_2",
    system: [],
    messages: [
      { role: "user", content: [{ type: "text", text: "run tests" }] },
      { role: "assistant", content: [{ type: "tool-call" }] },
      { role: "tool", content: [{ type: "tool-result" }] },
    ],
  };
  onContext(afterLog);
  assert.equal(afterLog.messages.length, 3);

  const nextUserTurn = {
    sessionID: "ses_2",
    system: [],
    messages: [
      { role: "user", content: [{ type: "text", text: "run tests" }] },
      { role: "assistant", content: [{ type: "text", text: "done" }] },
      { role: "user", content: [{ type: "text", text: "now check lint" }] },
      { role: "assistant", content: [{ type: "tool-call" }] },
      { role: "tool", content: [{ type: "tool-result" }] },
    ],
  };
  onContext(nextUserTurn);
  assert.equal(nextUserTurn.messages.length, 6);

  await dispose();
});

test("complaints-triage command prompts session with both harness and codebase box paths", async (t) => {
  const tmp = makeTempDir(t);
  const harnessPath = path.join(tmp, "harness.jsonl");
  const { commands, prompts, dispose } = await setupPlugin({
    options: { harnessPath },
    location: { directory: tmp, project: { canonical: tmp } },
  });

  const cmd = commands.get("complaints-triage");
  assert.ok(cmd);

  await cmd.execute({
    sessionID: "ses_3",
    prompt: { text: "focus on opus entries" },
    delivery: "steer",
  });

  assert.equal(prompts.length, 1);
  assert.equal(prompts[0].sessionID, "ses_3");
  assert.match(prompts[0].text, new RegExp(harnessPath.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(prompts[0].text, /\.opencode\/complaints-box\.jsonl/);
  assert.match(prompts[0].text, /focus on opus entries/);

  await dispose();
});
