// Summarizes one model request as seen by the `session.context` hook. OpenCode
// joins instruction sources with blank lines and no delimiters, so sections are
// recovered from the fixed openings each source renders.
const SECTIONS = [
  { kind: "environment", label: "Environment", pattern: /^(Here is some useful information about the environment|The environment you are running in is now:)/ },
  { kind: "environment", label: "Date", pattern: /^Today's date/ },
  { kind: "codemode", label: "Code Mode", pattern: /^(# Code Mode\b|No Code Mode tools are currently available|The Code Mode tool catalog has changed)/ },
  { kind: "memory", pattern: /^Instructions from: / },
  { kind: "skills", label: "Skill listing", pattern: /^Skills provide specialized instructions/ },
  { kind: "references", label: "Project references", pattern: /^Project references provide/ },
  { kind: "mcp", label: "MCP instructions", pattern: /^<mcp_instructions>/ },
  { kind: "context", pattern: /^<context key="/ },
]

export function summarizeRequest(event, now = Date.now()) {
  const system = (event.system ?? []).flatMap((part, index) => splitSystemPart(part?.text ?? "", index))
  const tools = Object.entries(event.tools ?? {}).map(([name, definition]) => ({
    name,
    chars: JSON.stringify({ name, description: definition?.description ?? "", input_schema: definition?.input ?? {} }).length,
  }))
  return {
    version: 1,
    time: now,
    agent: event.agent,
    model: event.model ? { providerID: event.model.providerID, id: event.model.id } : undefined,
    system,
    tools,
  }
}

export function splitSystemPart(text, index = 0) {
  if (!text) return []
  const segments = []
  let current = { kind: "prompt", label: promptLabel(text, index), start: 0 }
  let offset = 0
  for (const block of text.split("\n\n")) {
    const section = SECTIONS.find((candidate) => candidate.pattern.test(block))
    if (section) {
      if (offset > 0) segments.push({ ...current, text: text.slice(current.start, offset - 2) })
      current = { kind: section.kind, label: section.label ?? sectionLabel(section.kind, block), start: offset }
    }
    offset += block.length + 2
  }
  segments.push({ ...current, text: text.slice(current.start) })
  return segments.flatMap((segment) => expand(segment))
}

function expand(segment) {
  if (segment.kind === "codemode") return codeModeItems(segment.text)
  if (segment.kind === "mcp") return mcpItems(segment.text)
  const item = { kind: segment.kind, label: segment.label, chars: segment.text.length }
  if (segment.kind === "skills") item.count = (segment.text.match(/<skill>/g) ?? []).length
  return item.chars > 0 ? [item] : []
}

// Catalog entries sit under a `- namespace (N tools…)` line and may span lines.
function codeModeItems(text) {
  const items = [{ kind: "codemode", label: "Code Mode guidance", chars: 0 }]
  for (const line of text.split("\n")) {
    const namespace = line.match(/^- (\S+) \((\d+) tools?/)
    if (namespace) items.push({ kind: "codemode", label: namespace[1], namespace: namespace[1], count: Number(namespace[2]), chars: 0 })
    items.at(-1).chars += line.length + 1
  }
  return items.filter((item) => item.chars > 0)
}

function mcpItems(text) {
  const items = [{ kind: "mcp", label: "MCP instructions", chars: 0 }]
  for (const line of text.split("\n")) {
    const server = line.match(/^ {2}<server name="([^"]+)">/)
    if (server) items.push({ kind: "mcp", label: server[1], server: server[1], chars: 0 })
    items.at(-1).chars += line.length + 1
  }
  // The wrapper tags are shared overhead; fold them into the first server.
  if (items.length > 1) items[1].chars += items.shift().chars
  return items.filter((item) => item.chars > 0)
}

function sectionLabel(kind, block) {
  if (kind === "memory") return block.slice("Instructions from: ".length).split("\n", 1)[0]
  if (kind === "context") return block.match(/^<context key="([^"]+)"/)?.[1] ?? "Session context"
  return kind
}

function promptLabel(text, index) {
  if (index === 0) return "Base prompt"
  const heading = text.split("\n").find((line) => line.trim().length > 0)?.replace(/^#+\s*/, "").trim() ?? ""
  return heading.length > 40 ? `${heading.slice(0, 39)}…` : heading || `System part ${index + 1}`
}
