import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import plugin, { defaultBoxPath } from "./index.js";

function makeTempDir(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "complaints-box-test-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

async function setupPlugin({
  options = {},
  location = { directory: "/repo/wt", project: { canonical: "/repo" } },
  sessionModel = { providerID: "github-copilot", id: "claude-opus-5.5" },
} = {}) {
  const tools = new Map();
  const commands = new Map();
  const hooks = new Map();
  const prompts = [];

  const dispose = await plugin.setup({
    options,
    location,
    session: {
      get: async ({ sessionID }) => ({ id: sessionID, model: sessionModel }),
      prompt: async (input) => prompts.push(input),
      hook: async (name, cb) => {
        hooks.set(name, cb);
        return { dispose: async () => hooks.delete(name) };
      },
    },
    tool: {
      transform: async (cb) => {
        cb({ add: (def) => tools.set(def.name, def) });
        return { dispose: async () => tools.clear() };
      },
    },
    command: {
      transform: async (cb) => {
        cb({ add: (def) => commands.set(def.name, def) });
        return { dispose: async () => commands.clear() };
      },
    },
  });

  return { tools, commands, hooks, prompts, dispose };
}

test("defaultBoxPath points inside OpenCode state folder", () => {
  const prev = process.env.XDG_STATE_HOME;
  try {
    process.env.XDG_STATE_HOME = "/tmp/state-home";
    assert.equal(defaultBoxPath(), "/tmp/state-home/opencode/complaints-box.jsonl");
  } finally {
    if (prev === undefined) delete process.env.XDG_STATE_HOME;
    else process.env.XDG_STATE_HOME = prev;
  }
});

test("complaints_box appends signed harness and codebase entries to one file", async (t) => {
  const tmp = makeTempDir(t);
  const boxPath = path.join(tmp, "complaints-box.jsonl");
  const { tools, dispose } = await setupPlugin({
    options: { path: boxPath },
    location: { directory: "/repo/wt", project: { canonical: "/repo" } },
    sessionModel: { providerID: "github-copilot", id: "claude-opus-5.5", variant: "high" },
  });

  const tool = tools.get("complaints_box");
  assert.equal(tool.options.codemode, false);

  await tool.execute(
    { scope: "harness", summary: "Stale flag", details: "Expected --quick", category: "skill" },
    { sessionID: "ses_1", agent: "build" },
  );
  await tool.execute(
    { scope: "codebase", summary: "Dup helper", details: "Copied in 3 files" },
    { sessionID: "ses_1", agent: "build" },
  );

  const entries = fs
    .readFileSync(boxPath, "utf8")
    .trim()
    .split("\n")
    .map((l) => JSON.parse(l));

  assert.equal(entries.length, 2);
  assert.equal(entries[0].scope, "harness");
  assert.equal(entries[0].category, "skill");
  assert.equal(entries[0].model, "github-copilot/claude-opus-5.5#high");
  assert.equal(entries[1].scope, "codebase");
  assert.equal(entries[1].category, "other");
  assert.equal(entries[1].project, "/repo");

  await dispose();
});

test("context hook adds system prompt and recency reminder on tool turns until logged", async (t) => {
  const tmp = makeTempDir(t);
  const { tools, hooks, dispose } = await setupPlugin({
    options: { path: path.join(tmp, "complaints-box.jsonl") },
  });
  const onContext = hooks.get("context");

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

  await dispose();
});

test("complaints-triage command points to the single complaints-box file", async (t) => {
  const tmp = makeTempDir(t);
  const boxPath = path.join(tmp, "complaints-box.jsonl");
  const { commands, prompts, dispose } = await setupPlugin({ options: { path: boxPath } });

  await commands.get("complaints-triage").execute({
    sessionID: "ses_3",
    prompt: { text: "all projects" },
    delivery: "steer",
  });

  assert.equal(prompts.length, 1);
  assert.match(prompts[0].text, new RegExp(boxPath.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(prompts[0].text, /all projects/);

  await dispose();
});
