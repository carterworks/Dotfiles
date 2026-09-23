import type { Plugin } from "@opencode/plugin"
import { summarizeRequest } from "./request.mjs"
import { ContextUsageRpc } from "./rpc.ts"

const key = (sessionID: string) => `snapshot/${sessionID}`

export default {
  id: "context-usage",
  setup: async (ctx) => {
    const snapshots = new Map<string, string>()

    await ctx.session.hook("context", (event) => {
      try {
        const snapshot = JSON.stringify(summarizeRequest(event))
        snapshots.set(event.sessionID, snapshot)
        // Persisted so /context can itemize a session before its next request after a restart.
        void ctx.storage.set(key(event.sessionID), snapshot).catch(() => {})
      } catch {
        // Observing the request must never block it.
      }
    })

    await ctx.rpc.register(ContextUsageRpc, {
      snapshot: async ({ sessionID }) => {
        const cached = snapshots.get(sessionID)
        if (cached) return cached
        const stored = await ctx.storage.get(key(sessionID)).catch(() => undefined)
        return typeof stored === "string" ? stored : ""
      },
    })
  },
} satisfies Plugin.Plugin
