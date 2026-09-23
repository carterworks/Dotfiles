// Snapshots travel as JSON text so the RPC layer never reshapes them.
export const ContextUsageRpc = {
  id: "context-usage",
  methods: {
    snapshot: {
      input: {
        type: "object",
        properties: { sessionID: { type: "string" } },
        required: ["sessionID"],
      },
      output: { type: "string" },
    },
  },
  events: {},
} as const
