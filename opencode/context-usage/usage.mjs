// Breaks the model-visible context into categories. Server snapshots itemize
// the system prompt and tool definitions; session history supplies the rest.
// Counts are character estimates, rescaled to the provider-reported prompt size
// of the most recent completed request when one is available.
export const CATEGORIES = [
  { id: "unitemized", name: "System prompt & tools", color: "#8a8f98" },
  { id: "system", name: "System prompt", color: "#a3a8b0" },
  { id: "tools", name: "System tools", color: "#7c8594" },
  { id: "mcp", name: "MCP tools", color: "#5fb3c9" },
  { id: "memory", name: "Memory files", color: "#e0a458" },
  { id: "skills", name: "Skills", color: "#d9c46a" },
  { id: "messages", name: "Messages", color: "#b48ead" },
]

const CHARS_PER_TOKEN = 4
const IMAGE_TOKENS = 1_600
const DEFAULT_COMPACTION_BUFFER = 20_000
const COMPACTION_OUTPUT_MAX = 32_000

export const tokens = (chars) => Math.ceil(chars / CHARS_PER_TOKEN)

export function contextBreakdown({ messages = [], snapshot, model, compaction, mcpNamespaces = [] }) {
  const limit = model?.limit?.context ?? 0
  const reserve = reserveTokens(model?.limit, compaction)
  const setup = snapshot ? snapshotItems(snapshot, new Set(mcpNamespaces)) : []
  const history = messages.flatMap((message, index) => messageItems(message).map((item) => ({ ...item, index })))

  const lastIndex = messages.findLastIndex((message) => message.type === "assistant" && message.tokens && message.time?.completed)
  const last = lastIndex < 0 ? undefined : usage(messages[lastIndex].tokens)
  let ratio = 1
  const items = [...setup, ...history]
  if (last?.prompt > 0) {
    const before = sum(setup) + sum(history.filter((item) => item.index < lastIndex))
    if (!snapshot) {
      const unitemized = last.prompt - before
      if (unitemized > 0) items.unshift({ category: "unitemized", label: "Not itemized yet", tokens: unitemized })
    } else if (before > 0) {
      ratio = clamp(last.prompt / before, 0.5, 3)
    }
  }

  const byCategory = new Map()
  for (const item of items) {
    const value = item.tokens * ratio
    if (value <= 0) continue
    const entry = byCategory.get(item.category) ?? { tokens: 0, labels: new Map() }
    entry.tokens += value
    entry.labels.set(item.label, (entry.labels.get(item.label) ?? 0) + value)
    byCategory.set(item.category, entry)
  }
  const categories = CATEGORIES.flatMap((category) => {
    const entry = byCategory.get(category.id)
    if (!entry) return []
    const details = [...entry.labels].map(([label, value]) => ({ label, tokens: Math.round(value) }))
    return [{ ...category, tokens: Math.round(entry.tokens), details: details.sort((a, b) => b.tokens - a.tokens) }]
  })
  const used = categories.reduce((total, category) => total + category.tokens, 0)
  return {
    limit,
    reserve,
    used,
    free: Math.max(0, limit - reserve - used),
    ratio,
    last,
    itemized: Boolean(snapshot),
    categories,
  }
}

// Mirrors OpenCode's automatic compaction trigger (session/compaction.ts).
export function reserveTokens(limit, compaction) {
  if (!limit?.context || compaction?.auto === false) return 0
  const buffer = compaction?.buffer ?? DEFAULT_COMPACTION_BUFFER
  const output = Math.min(limit.output ?? 0, COMPACTION_OUTPUT_MAX)
  const ceiling = Math.min(limit.input === undefined ? Infinity : limit.input - buffer, limit.context - Math.max(output, buffer))
  return clamp(limit.context - ceiling, 0, limit.context)
}

function snapshotItems(snapshot, mcpNamespaces) {
  const system = (snapshot.system ?? []).map((item) => {
    const value = tokens(item.chars)
    if (item.kind === "memory") return { category: "memory", label: item.label, tokens: value }
    if (item.kind === "skills") return { category: "skills", label: `Skill listing (${item.count ?? 0} skills)`, tokens: value }
    if (item.kind === "mcp") return { category: "mcp", label: item.server ? `${item.server} · instructions` : "MCP instructions", tokens: value }
    if (item.kind === "codemode") {
      if (item.namespace && mcpNamespaces.has(item.namespace))
        return { category: "mcp", label: `${item.namespace} · ${item.count} tools via Code Mode`, tokens: value }
      return { category: "tools", label: item.namespace ? `${item.namespace} · ${item.count} Code Mode tools` : item.label, tokens: value }
    }
    return { category: "system", label: item.label, tokens: value }
  })
  const tools = (snapshot.tools ?? []).map((tool) => {
    const namespace = [...mcpNamespaces].find((prefix) => tool.name.startsWith(`${prefix}_`))
    return namespace
      ? { category: "mcp", label: `${namespace} · ${tool.name.slice(namespace.length + 1)}`, tokens: tokens(tool.chars) }
      : { category: "tools", label: tool.name, tokens: tokens(tool.chars) }
  })
  return [...system, ...tools]
}

export function messageItems(message) {
  const item = (category, label, chars) => ({ category, label, tokens: tokens(chars) })
  switch (message.type) {
    case "user":
      return [
        item("messages", "User prompts", message.text?.length ?? 0),
        ...(message.skills ?? []).flatMap((skill) => (skill.text ? [item("skills", `Invoked: ${skill.name}`, skill.text.length)] : [])),
        ...(message.files ?? []).map((file) => ({ category: "messages", label: "Attachments", tokens: attachmentTokens(file) })),
      ]
    case "synthetic":
      return message.metadata?.instruction ? instructionItems(message.text) : [item("messages", "Synthetic context", message.text.length)]
    case "system":
      return [item("messages", "Instruction updates", message.text.length)]
    case "skill":
      return [item("skills", `Loaded: ${message.name}`, message.text.length)]
    case "shell":
      return [item("messages", "Shell commands", message.command.length + (message.output?.output?.length ?? 0) + 80)]
    case "location-switched":
      return [item("messages", "User prompts", message.location.directory.length + 45)]
    case "compaction":
      return message.status === "completed"
        ? [item("messages", "Compaction summary", message.summary.length + message.recent.length + 200)]
        : []
    case "assistant":
      return message.content.map((part) => {
        if (part.type === "text") return item("messages", "Assistant text", part.text.length)
        if (part.type === "reasoning") return item("messages", "Reasoning", part.text.length)
        const input = part.state.status === "streaming" ? part.state.input : JSON.stringify(part.state.input ?? {})
        const result = toolResultTokens(part.state)
        const value = tokens(part.name.length + input.length) + result
        if (part.name === "skill")
          return { category: "skills", label: `Loaded: ${part.state.metadata?.name ?? part.state.input?.id ?? "skill"}`, tokens: value }
        return { category: "messages", label: `Tool · ${part.name}`, tokens: value }
      })
    default:
      return []
  }
}

function instructionItems(text) {
  return text
    .split(/(?=^Instructions from: )/m)
    .filter((block) => block.trim())
    .map((block) => ({
      category: "memory",
      label: block.startsWith("Instructions from: ") ? block.slice(19).split("\n", 1)[0] : "Instructions",
      tokens: tokens(block.length),
    }))
}

function toolResultTokens(state) {
  const content = state.content ?? []
  const error = state.status === "error" ? JSON.stringify(state.error ?? "").length : 0
  return tokens(error) + content.reduce((total, part) => {
    if (part.type === "text") return total + tokens(part.text.length)
    if (part.mime?.startsWith("image/")) return total + IMAGE_TOKENS
    return total + tokens(part.uri?.length ?? 0)
  }, 0)
}

function attachmentTokens(file) {
  if (file.mime?.startsWith("image/")) return IMAGE_TOKENS
  return tokens(Math.ceil((file.data?.length ?? 0) * 0.75) + (file.name?.length ?? 0) + 20)
}

function usage(value) {
  const prompt = value.input + value.cache.read + value.cache.write
  return { input: value.input, cacheRead: value.cache.read, cacheWrite: value.cache.write, output: value.output, reasoning: value.reasoning ?? 0, prompt }
}

// Categories fill cells in order, free space follows, and the compaction
// reserve takes the final cells, like Claude Code's autocompact buffer.
export function gridCells(breakdown, count) {
  const { limit, reserve, categories } = breakdown
  if (!limit) return Array(count).fill("free")
  const scale = count / Math.max(limit, breakdown.used + reserve)
  const reserveCells = reserve > 0 ? Math.max(1, Math.round(reserve * scale)) : 0
  const cells = []
  let cumulative = 0
  for (const category of categories) {
    cumulative += category.tokens
    const end = Math.min(count - reserveCells, Math.max(cells.length + 1, Math.round(cumulative * scale)))
    while (cells.length < end) cells.push(category.id)
  }
  while (cells.length < count - reserveCells) cells.push("free")
  while (cells.length < count) cells.push("reserve")
  return cells
}

export function compact(value) {
  if (value >= 1_000_000) return `${Number((value / 1_000_000).toFixed(1))}m`
  if (value >= 1_000) return `${Number((value / 1_000).toFixed(1))}k`
  return String(Math.round(value))
}

const sum = (items) => items.reduce((total, item) => total + item.tokens, 0)
const clamp = (value, min, max) => Math.min(max, Math.max(min, value))
