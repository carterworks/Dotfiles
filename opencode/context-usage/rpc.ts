// Results travel as JSON text so the RPC layer never reshapes them.
export const ContextUsageRpc = {
  id: "context-usage",
  methods: {
    // The raw per-request size summary captured by the server hook.
    snapshot: {
      input: {
        type: "object",
        properties: { sessionID: { type: "string" } },
        required: ["sessionID"],
      },
      output: { type: "string" },
    },
    // The complete report any client can render. Server plugins cannot read
    // config, so callers pass the session's compaction settings when they have them.
    breakdown: {
      input: {
        type: "object",
        properties: {
          sessionID: { type: "string" },
          compaction: {
            type: "object",
            properties: { auto: { type: "boolean" }, buffer: { type: "number" } },
          },
        },
        required: ["sessionID"],
      },
      output: { type: "string" },
    },
  },
  events: {},
} as const
