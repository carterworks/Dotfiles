import assert from "node:assert/strict"
import test from "node:test"
import { contextBreakdown, gridCells, reserveTokens, sessionReport, unwrap } from "./usage.mjs"

const text = (length) => "x".repeat(length)
const tokens = (input, output = 0, read = 0, write = 0) => ({ input, output, reasoning: 0, cache: { read, write } })
const model = { limit: { context: 1_000, output: 100 } }

const snapshot = {
  system: [
    { kind: "prompt", label: "Base prompt", chars: 400 },
    { kind: "memory", label: "/repo/AGENTS.md", chars: 200 },
    { kind: "skills", label: "Skill listing", count: 3, chars: 120 },
    { kind: "codemode", label: "context7", namespace: "context7", count: 2, chars: 80 },
    { kind: "codemode", label: "browser", namespace: "browser", count: 5, chars: 40 },
  ],
  tools: [
    { name: "read", chars: 160 },
    { name: "scout_search", chars: 80 },
  ],
}

const messages = [
  { type: "user", text: text(40), skills: [{ name: "tdd", text: text(80) }], time: { created: 1 } },
  {
    type: "assistant",
    time: { created: 2, completed: 3 },
    tokens: tokens(90, 10, 100, 10),
    content: [
      { type: "text", text: text(20) },
      { type: "tool", name: "read", state: { status: "completed", input: {}, content: [{ type: "text", text: text(38) }] } },
      { type: "tool", name: "skill", state: { status: "completed", input: { id: "x" }, metadata: { name: "grill" }, content: [{ type: "text", text: text(35) }] } },
    ],
  },
  { type: "synthetic", text: "Instructions from: /repo/sub/AGENTS.md\nnested", metadata: { instruction: { paths: ["/repo/sub/AGENTS.md"] } }, time: { created: 4 } },
  { type: "assistant", time: { created: 5 }, content: [{ type: "reasoning", text: text(400) }] },
]

test("itemizes sources and scales them to the last provider-reported prompt", () => {
  const result = contextBreakdown({ messages, snapshot, model, mcpNamespaces: ["context7", "scout"] })
  const category = (id) => result.categories.find((item) => item.id === id)
  // Estimated prompt before the completed request: 270 setup + 30 history = 300 tokens.
  assert.equal(result.ratio, 200 / 300)
  assert.deepEqual(category("mcp").details.map((item) => item.label), ["context7 · 2 tools via Code Mode", "scout · search"])
  assert.deepEqual(category("tools").details.map((item) => item.label), ["read", "browser · 5 Code Mode tools"])
  assert.deepEqual(category("memory").details.map((item) => item.label).sort(), ["/repo/AGENTS.md", "/repo/sub/AGENTS.md"])
  assert.deepEqual(category("skills").details.map((item) => item.label).sort(), ["Invoked: tdd", "Loaded: grill", "Skill listing (3 skills)"])
  assert.deepEqual(category("messages").details.map((item) => item.label), ["Reasoning", "Tool · read", "User prompts", "Assistant text"])
  assert.equal(result.used, result.categories.reduce((sum, item) => sum + item.tokens, 0))
  assert.equal(result.last.prompt, 200)
})

test("without a server snapshot, the unexplained prompt remainder is shown instead of invented detail", () => {
  const result = contextBreakdown({ messages, model })
  assert.equal(result.itemized, false)
  assert.equal(result.ratio, 1)
  assert.equal(result.categories[0].id, "unitemized")
  assert.equal(result.categories[0].tokens, 200 - 30)
})

test("empty sessions report free space without a last request", () => {
  const result = contextBreakdown({ messages: [], model })
  assert.deepEqual(result.categories, [])
  assert.equal(result.last, undefined)
  assert.equal(result.free, 1_000 - result.reserve)
})

test("a session report resolves the model the last request used and MCP namespaces", () => {
  const models = [
    { providerID: "p", id: "old", name: "Old", limit: { context: 10, output: 1 } },
    { providerID: "p", id: "m", name: "Model M", limit: model.limit },
  ]
  const history = messages.map((message) => (message.type === "assistant" ? { ...message, model: { providerID: "p", id: "m" } } : message))
  const report = sessionReport({
    messages: history,
    snapshot,
    session: { model: { providerID: "p", id: "old" } },
    models,
    mcpServers: [{ name: "context7" }, { name: "scout" }],
  })
  assert.deepEqual(report.model, { providerID: "p", id: "m", name: "Model M" })
  assert.equal(report.messages, messages.length)
  assert.equal(report.breakdown.limit, 1_000)
  assert.ok(report.breakdown.categories.find((item) => item.id === "mcp").details.some((item) => item.label === "scout · search"))
  assert.equal(sessionReport({ session: { model: { providerID: "p", id: "old" } }, models }).model.name, "Old")
})

test("unwrap accepts payloads with or without a data envelope", () => {
  assert.deepEqual(unwrap({ data: [1] }), [1])
  assert.deepEqual(unwrap({ location: {}, data: [2] }), [2])
  assert.deepEqual(unwrap([3]), [3])
  assert.equal(unwrap(undefined), undefined)
})

test("the compaction reserve mirrors OpenCode's automatic threshold", () => {
  assert.equal(reserveTokens({ context: 200_000, output: 64_000 }), 32_000)
  assert.equal(reserveTokens({ context: 200_000, output: 8_000 }), 20_000)
  assert.equal(reserveTokens({ context: 400_000, input: 272_000, output: 128_000 }), 148_000)
  assert.equal(reserveTokens({ context: 200_000, output: 8_000 }, { auto: false }), 0)
  assert.equal(reserveTokens({ context: 200_000, output: 8_000 }, { buffer: 5_000 }), 8_000)
})

test("grid cells follow category order, then free space, then the reserve", () => {
  const breakdown = {
    limit: 100,
    reserve: 20,
    used: 31,
    categories: [
      { id: "system", tokens: 30 },
      { id: "skills", tokens: 1 },
    ],
  }
  assert.deepEqual(gridCells(breakdown, 10), ["system", "system", "system", "skills", "free", "free", "free", "free", "reserve", "reserve"])
  assert.deepEqual(gridCells({ limit: 0, reserve: 0, used: 0, categories: [] }, 2), ["free", "free"])
})
