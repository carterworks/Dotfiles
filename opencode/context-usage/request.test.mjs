import assert from "node:assert/strict"
import test from "node:test"
import { splitSystemPart, summarizeRequest } from "./request.mjs"

const initial = [
  "Here is some useful information about the environment you are running in:\n<env>\n  Platform: darwin\n</env>",
  "Today's date: Wed Sep 23 2026",
  "# Code Mode\n\nUse the `execute` tool.\n\n## Available tools\n\n- browser (45 tools, 3 shown) // Desktop\n  - tools.browser.preview({\n  path: string,\n})\n- scout (18 tools, 2 shown)\n  - tools.scout.memory_read({})",
  "Instructions from: /home/me/AGENTS.md\n# Rules\n\n- be terse",
  "Instructions from: /repo/AGENTS.md\nRepo rules",
  "Skills provide specialized instructions and workflows for specific tasks.\n<available_skills>\n  <skill>\n    <id>a</id>\n  </skill>\n  <skill>\n    <id>b</id>\n  </skill>\n</available_skills>",
  "<mcp_instructions>\n  <server name=\"context7\">\n    Use docs.\n  </server>\n  <server name=\"scout\">\n    Search first.\n  </server>\n</mcp_instructions>",
  "<context key=\"ticket\">\nABC-1\n</context>",
].join("\n\n")

test("recovers each instruction source from the rendered system prompt", () => {
  const items = splitSystemPart(initial, 2)
  const byKind = (kind) => items.filter((item) => item.kind === kind)
  assert.deepEqual(byKind("environment").map((item) => item.label), ["Environment", "Date"])
  assert.deepEqual(byKind("memory").map((item) => item.label), ["/home/me/AGENTS.md", "/repo/AGENTS.md"])
  assert.equal(byKind("memory")[0].chars, "Instructions from: /home/me/AGENTS.md\n# Rules\n\n- be terse".length)
  assert.deepEqual(byKind("skills").map((item) => item.count), [2])
  assert.deepEqual(byKind("mcp").map((item) => item.server), ["context7", "scout"])
  assert.deepEqual(byKind("codemode").map((item) => [item.namespace, item.count]), [[undefined, undefined], ["browser", 45], ["scout", 18]])
  assert.deepEqual(byKind("context").map((item) => item.label), ["ticket"])
  const total = items.reduce((sum, item) => sum + item.chars, 0)
  assert.ok(Math.abs(total - initial.length) <= items.length * 2)
})

test("labels base prompt parts and measures tool definitions", () => {
  const snapshot = summarizeRequest(
    {
      agent: "build",
      model: { providerID: "p", id: "m", variant: "high" },
      system: [{ type: "text", text: "You are an agent." }, { type: "text", text: "# Your Model\n- Name: M" }],
      tools: { read: { description: "Read a file", input: { type: "object" } } },
    },
    5,
  )
  assert.deepEqual(snapshot.system.map((item) => [item.kind, item.label]), [["prompt", "Base prompt"], ["prompt", "Your Model"]])
  assert.deepEqual(snapshot.model, { providerID: "p", id: "m" })
  assert.equal(snapshot.tools[0].name, "read")
  assert.equal(snapshot.tools[0].chars, JSON.stringify({ name: "read", description: "Read a file", input_schema: { type: "object" } }).length)
})
