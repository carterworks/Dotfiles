import type { Plugin } from "@opencode/plugin"
import { summarizeRequest } from "./request.mjs"
import { ContextUsageRpc } from "./rpc.ts"
import { sessionReport, unwrap } from "./usage.mjs"

const key = (sessionID: string) => `snapshot/${sessionID}`

export default {
  id: "context-usage",
  setup: async (ctx) => {
    const snapshots = new Map<string, string>()
    const readSnapshot = async (sessionID: string) => {
      const cached = snapshots.get(sessionID)
      if (cached) return cached
      const stored = await ctx.storage.get(key(sessionID)).catch(() => undefined)
      return typeof stored === "string" ? stored : ""
    }

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
      snapshot: async ({ sessionID }) => readSnapshot(sessionID),
      breakdown: async ({ sessionID, compaction }) => {
        const [context, session, models, mcpServers, snapshot] = await Promise.all([
          ctx.session.context({ sessionID }),
          ctx.session.get({ sessionID }).catch(() => undefined),
          ctx.model.list().catch(() => undefined),
          ctx.mcp.list().catch(() => undefined),
          readSnapshot(sessionID),
        ])
        return JSON.stringify(
          sessionReport({
            messages: unwrap(context) ?? [],
            snapshot: snapshot ? JSON.parse(snapshot) : undefined,
            session: unwrap(session),
            models: unwrap(models) ?? [],
            mcpServers: unwrap(mcpServers) ?? [],
            compaction,
          }),
        )
      },
    })
  },
} satisfies Plugin.Plugin
