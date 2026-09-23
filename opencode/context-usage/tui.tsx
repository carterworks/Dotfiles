/** @jsxImportSource @opentui/solid */
import { Plugin, usePlugin } from "@opencode/plugin/tui"
import type { Context } from "@opencode/plugin/tui/context"
import type { ScrollBoxRenderable } from "@opentui/core"
import { useTerminalDimensions } from "@opentui/solid"
import { createEffect, createMemo, createResource, For, on, onCleanup, Show } from "solid-js"
import { ContextUsageRpc } from "./rpc.ts"
import { compact, gridCells, sessionReport, unwrap } from "./usage.mjs"

const DIALOG_WIDTH = 116
const COLUMNS = 20
const ROWS = 10
const DETAIL_ROWS = 8
const RESERVE_COLOR = "#6c7079"

type Location = { directory: string; workspaceID?: string }

async function load(ctx: Context, sessionID: string) {
  await ctx.data.session.sync(sessionID)
  const session = ctx.data.session.get(sessionID)
  if (!session) throw new Error("Session unavailable")
  const location = { directory: (session.location as Location).directory }
  const compaction = await loadCompaction(ctx, location)
  try {
    const text = await ctx.client.rpc(ContextUsageRpc).breakdown({ sessionID, compaction }, { location })
    return { ...JSON.parse(text), snapshotError: undefined as string | undefined }
  } catch (error: any) {
    if (error?.type !== "rpc.unavailable") throw error
  }
  // Without the server half there is no snapshot, so only history is itemized.
  const [context] = await Promise.all([
    ctx.client.session.context({ sessionID }),
    ctx.data.location.model.sync(location),
    ctx.data.location.mcp.server.sync(location).catch(() => undefined),
  ])
  const report = sessionReport({
    messages: unwrap(context) ?? [],
    session,
    models: ctx.data.location.model.list(location) ?? [],
    mcpServers: ctx.data.location.mcp.server.list(location) ?? [],
    compaction,
  })
  return { ...report, snapshotError: "server plugin not loaded" }
}

async function loadCompaction(ctx: Context, location: Location) {
  try {
    const entries: any[] = unwrap(await ctx.client.config.get({ location })) ?? []
    return entries.reduce((merged, entry) => (entry?.info?.compaction ? { ...merged, ...entry.info.compaction } : merged), {})
  } catch {
    return undefined
  }
}

function ContextDialog(props: { sessionID: string }) {
  const ctx = usePlugin()
  const dimensions = useTerminalDimensions()
  const width = () => Math.min(DIALOG_WIDTH, dimensions().width - 2) - 4
  const [resource, { refetch }] = createResource(
    () => props.sessionID,
    (sessionID) => load(ctx, sessionID).catch((error) => ({ error: String(error?.message ?? error) })),
  )
  const data = createMemo(() => {
    const value = resource.latest
    return value && !("error" in value) ? value : undefined
  })
  const failure = () => {
    const value = resource.latest
    return value && "error" in value ? value.error : undefined
  }

  // Follow the session live: refresh as messages arrive and when a run settles.
  let timer: ReturnType<typeof setTimeout> | undefined
  const schedule = () => {
    clearTimeout(timer)
    timer = setTimeout(() => void refetch(), 400)
  }
  createEffect(
    on(
      [
        () => ctx.data.session.status(props.sessionID),
        () => ctx.data.session.message.list(props.sessionID).length,
      ],
      schedule,
      { defer: true },
    ),
  )
  onCleanup(() => clearTimeout(timer))

  let scroll: ScrollBoxRenderable | undefined
  // Dialogs push the "modal" input mode; the dialog host handles escape.
  ctx.keymap.layer(() => ({
    mode: "modal",
    commands: [
      { id: "context-usage.refresh", title: "Refresh", bind: "r", run: () => void refetch() },
      { title: "Close", bind: "q", run: () => ctx.ui.dialog.clear() },
      { title: "Scroll up", bind: "up", run: () => scroll?.scrollBy(-1) },
      { title: "Scroll up", bind: "k", run: () => scroll?.scrollBy(-1) },
      { title: "Scroll down", bind: "down", run: () => scroll?.scrollBy(1) },
      { title: "Scroll down", bind: "j", run: () => scroll?.scrollBy(1) },
      { title: "Page up", bind: "pageup", run: () => scroll?.scrollBy(-10) },
      { title: "Page down", bind: "pagedown", run: () => scroll?.scrollBy(10) },
    ],
  }))

  const base = () => ctx.theme.text.base
  const muted = () => ctx.theme.text.muted
  const breakdown = () => data()!.breakdown
  const cells = createMemo(() => (data() ? gridCells(breakdown(), COLUMNS * ROWS) : []))
  const colors = createMemo(() => new Map(data()?.breakdown.categories.map((category) => [category.id, category.color])))
  const percent = (value: number) => {
    const limit = breakdown().limit
    return limit ? ` (${((value / limit) * 100).toFixed(1)}%)` : ""
  }
  const labelWidth = () => Math.max(16, Math.min(56, width() - 16))
  const fit = (label: string) => (label.length > labelWidth() ? `${label.slice(0, labelWidth() - 1)}…` : label.padEnd(labelWidth()))
  const display = (label: string) => (label.startsWith("/") ? ctx.ui.format.path(label) : label)

  const chart = () => (
    <box flexDirection="column" flexShrink={0}>
      <For each={Array.from({ length: ROWS }, (_, row) => row)}>
        {(row) => (
          <box flexDirection="row">
            <For each={cells().slice(row * COLUMNS, (row + 1) * COLUMNS)}>
              {(cell) => (
                <text fg={cell === "free" ? muted() : cell === "reserve" ? RESERVE_COLOR : colors().get(cell)}>
                  {cell === "free" ? "○ " : cell === "reserve" ? "◌ " : "● "}
                </text>
              )}
            </For>
          </box>
        )}
      </For>
    </box>
  )

  const legend = () => (
    <box flexDirection="column" flexShrink={0}>
      <text fg={base()}>{data()!.model?.name ?? data()!.model?.id ?? "Model unknown"}</text>
      <text fg={muted()}>
        {data()!.model ? `${data()!.model.providerID}/${data()!.model.id}` : "No model selected"}
      </text>
      <text fg={base()}>
        {breakdown().limit
          ? `${compact(breakdown().used)} / ${compact(breakdown().limit)} tokens${percent(breakdown().used)}`
          : `${compact(breakdown().used)} tokens (context limit unknown)`}
      </text>
      <text> </text>
      <For each={breakdown().categories}>
        {(category) => (
          <text fg={category.color}>
            ● {category.name.padEnd(22)} {compact(category.tokens).padStart(6)}{percent(category.tokens)}
          </text>
        )}
      </For>
      <Show when={breakdown().limit}>
        <text fg={muted()}>
          ○ {"Free space".padEnd(22)} {compact(breakdown().free).padStart(6)}{percent(breakdown().free)}
        </text>
      </Show>
      <Show when={breakdown().reserve}>
        <text fg={RESERVE_COLOR}>
          ◌ {"Autocompact buffer".padEnd(22)} {compact(breakdown().reserve).padStart(6)}{percent(breakdown().reserve)}
        </text>
      </Show>
      <Show when={breakdown().limit && breakdown().used + breakdown().reserve > breakdown().limit}>
        <text fg={ctx.theme.text.feedback.error.base}>Past the automatic compaction threshold · /compact</text>
      </Show>
    </box>
  )

  const details = () => (
    <For each={breakdown().categories}>
      {(category) => (
        <box flexDirection="column" paddingTop={1}>
          <text fg={category.color}>
            {category.name} · {compact(category.tokens)} tokens
          </text>
          <For each={category.details.slice(0, DETAIL_ROWS)}>
            {(item) => (
              <text fg={base()}>
                <span style={{ fg: muted() }}>└ </span>
                {fit(display(item.label))} <span style={{ fg: muted() }}>{compact(item.tokens).padStart(6)}</span>
              </text>
            )}
          </For>
          <Show when={category.details.length > DETAIL_ROWS}>
            <text fg={muted()}>
              {"  "}… {category.details.length - DETAIL_ROWS} more ·{" "}
              {compact(category.details.slice(DETAIL_ROWS).reduce((total, item) => total + item.tokens, 0))} tokens
            </text>
          </Show>
        </box>
      )}
    </For>
  )

  const notes = () => {
    const value = breakdown()
    const last = value.last
    const lines = [] as string[]
    if (last)
      lines.push(
        `Last request: ${compact(last.prompt)} prompt tokens (${compact(last.cacheRead)} cache read, ${compact(last.cacheWrite)} cache write) · ${compact(last.output)} output`,
      )
    else lines.push("No completed model request yet; counts are character estimates.")
    if (last && value.itemized) lines.push(`Categories are character estimates scaled ×${value.ratio.toFixed(2)} to match the last request.`)
    if (!value.itemized)
      lines.push(
        data()!.snapshotError
          ? `System prompt and tools are not itemized (${data()!.snapshotError}).`
          : "System prompt and tools itemize after the next model request.",
      )
    lines.push(`${data()!.messages} messages since the last compaction.`)
    return lines
  }

  return (
    <box flexDirection="column" height={Math.max(12, Math.floor(dimensions().height * 0.85))} paddingLeft={2} paddingRight={2}>
      <box flexDirection="row" flexShrink={0} gap={2}>
        <text fg={base()}>Context Usage</text>
        <Show when={resource.loading}>
          <text fg={muted()}>refreshing…</text>
        </Show>
      </box>
      <Show when={failure()}>
        <text fg={ctx.theme.text.feedback.error.base}>Unable to load context: {failure()}</text>
      </Show>
      <Show when={!failure() && !data()}>
        <text fg={muted()}>Loading context…</text>
      </Show>
      <Show when={data()}>
        <scrollbox
          ref={(value: ScrollBoxRenderable) => (scroll = value)}
          flexGrow={1}
          minHeight={0}
          horizontalScrollbarOptions={{ visible: false }}
        >
          <box flexDirection="column" flexShrink={0} paddingTop={1} paddingRight={1} paddingBottom={1}>
            <Show
              when={width() >= 96}
              fallback={
                <box flexDirection="column" gap={1}>
                  {chart()}
                  {legend()}
                </box>
              }
            >
              <box flexDirection="row" gap={4}>
                {chart()}
                {legend()}
              </box>
            </Show>
            {details()}
            <box flexDirection="column" paddingTop={1}>
              <For each={notes()}>{(line) => <text fg={muted()}>{line}</text>}</For>
              <text fg={muted()}>r refresh · ↑↓ scroll · esc close</text>
            </box>
          </box>
        </scrollbox>
      </Show>
    </box>
  )
}

export default Plugin.define({
  id: "context-usage.cli",
  setup(ctx) {
    const open = () => {
      const route = ctx.ui.router.current()
      if (route.type !== "session")
        return ctx.ui.toast.show({ message: "Open a session to see its context usage", variant: "info" })
      ctx.ui.dialog.show(() => <ContextDialog sessionID={route.sessionID} />)
      ctx.ui.dialog.set({ size: "xlarge", centered: true })
    }
    ctx.ui.slot({
      append: "app",
      render: () => {
        ctx.keymap.layer(() => ({
          mode: "global",
          commands: [
            {
              id: "context-usage.open",
              title: "Show context usage",
              group: "Session",
              slash: { name: "context" },
              palette: true,
              run: open,
            },
          ],
        }))
        return null
      },
    })
  },
})
