# Idle compaction

An OpenCode V2 server plugin that compacts large idle conversations on a per-model
schedule. The goal is to summarize while the prompt cache is still warm, reducing
uncached input when you return; it does not preserve the old cache indefinitely.

Only `github-copilot` is supported. OpenCode Go and other providers are untouched.
Requires OpenCode 2.2.5 or later; the `experimental.idle` hook is experimental.
There are no external runtime dependencies.

## Timing and safeguards

- The deadline is measured from the latest primary model request's start, not
  response completion. GPT-5.6/6/6.1 Sol, Luna, and Terra models default to **54
  minutes**; Claude models default to **three minutes**. These are direct timers:
  no additional safety margin is subtracted. Other models require an explicit timer.
- A successful response must report cache reads or writes and at least **200,000
  input tokens**, including cached input. Each model can override the threshold.
  This size threshold is a heuristic, not
  a measurement of how much conversation a summary will remove. Raise it when
  using unusually large fixed instructions or `compaction.keep.tokens`.
- The session must reach normal idle with no background jobs. Subagents,
  interrupted/failed sessions, and responses that finish after the deadline are
  skipped. Timers a minute or more late (for example after sleep) are skipped;
  `maxLatenessMs` controls that tolerance, not cache expiry.
- New prompts, model requests, model/agent switches, compaction, pending inbox
  items, archival, deletion, moves, and staged reverts invalidate the old timer.
- Immediately before admission, the plugin rechecks the session's location,
  idle status, model, and compaction agent. A different summary model or native
  compaction is skipped because it cannot be assumed to reuse that cache.
- Compaction uses queue delivery so a racing prompt is not steered aside. There
  is at most one attempt per eligible primary request. Title generation, warming,
  and compaction requests never rearm it, so an abandoned session is not compacted
  repeatedly. Failures are not retried.
- Timers are in memory, cleared on unload, and never restored after a restart.
  Losing the event subscription disables scheduling until plugin reload.

Copilot inference responses do **not** have a verified expiry contract here.
Cache usage proves a previous cache hit/write, not future availability. Neither
configured timers nor model metadata guarantees a hit: routing, eviction, changed
prefixes, and proxy behavior can cause earlier misses. The plugin does not change
provider cache retention settings or parse/store raw response bodies.

## Configuration

Home Manager links this directory to `~/.config/opencode/idle-compaction`, and the
global OpenCode config loads it explicitly. It is intentionally outside `plugins/`
so helper and test files cannot be discovered as plugins.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": [
    {
      "package": "./idle-compaction",
      "options": {
        "logLevel": "info",
        "minInputTokens": 200000,
        "models": {
          // User-selected policy inspired by Claude Code's 54m/1h schedule, not a Copilot TTL.
          // https://code.claude.com/docs/en/changelog#2-1-299
          "gpt-6.1-sol": { "after": "54m", "minInputTokens": 250000 },
          // Three minutes leaves 2m within Anthropic's default 5m cache; Copilot is unverified.
          // https://platform.claude.com/docs/en/build-with-claude/prompt-caching
          "claude-opus-5.5": { "after": "3m" },
          "some-model-with-unknown-policy": false,
        },
      },
    },
  ],
}
```

Timer precedence: `models[modelID].after`, plugin `after`, then the family default.
Size precedence: `models[modelID].minInputTokens`, plugin `minInputTokens`, then
200,000. A partial model override inherits the remaining defaults. `false` disables
a model. Durations use integer `ms`, `s`, `m`, `h`, or `d` units. Invalid policies
fail closed; thresholds and lateness must be positive safe integers.

Add a source/rationale comment whenever changing a model timer. The 54m GPT policy
is user-selected, inspired by Claude Code's one-hour cache schedule; it **exceeds
OpenAI's documented 30m minimum** and does not establish that Copilot stays warm
that long. The 3m Claude policy leaves two minutes within Anthropic's default 5m
lifetime, whose applicability through Copilot is also unverified. Catalog cache
TTLs do not override these timers or configure provider retention. The old `ttl`,
`marginMs`, and string-valued model options have been replaced by direct timers.

Disable the entire plugin by removing its entry or adding
`"-dotfiles.idle-compaction"` after it.

### Logging

Set `options.logLevel` to control logs with the `[idle-compaction]` prefix:

- `error`: operation failures only.
- `info` (default): admissions and operation failures.
- `debug`: also logs plugin readiness/shutdown, request tracking, scheduled
  deadlines, cancellations, and skip reasons. Your global config currently uses
  this level for diagnosis; switch it back to `info` when finished.

Invalid levels fall back to `info`. Each line contains a JSON event with a session
ID when available. Size rejections include the response's input-plus-cache count
and configured minimum, not cumulative session usage. Other reasons identify
missing cache evidence, invalid usage/policy, unsupported or disabled models,
native compaction, background work, invalidating events, overdue timers, and
live session/model/location checks.

Logs are written to `~/.local/share/opencode/log/idle-compaction.log` (or
`$XDG_DATA_HOME/opencode/log/idle-compaction.log`) as well as the console. T3
discards its child server's console output after startup, so use the file when
diagnosing T3 sessions. New files are owner-readable/writable only. File failures
fall back to console output and do not stop scheduling. The file is append-only;
no automatic rotation is performed.

Diagnostic events use the console's info output; the plugin option controls their
verbosity independently of OpenCode's server log level. For example:

```text
[idle-compaction] {"event":"skipped","sessionID":"ses_…","reason":"below-token-threshold","inputTokens":103663,"minInputTokens":200000}
```

Admission is not completion. Use OpenCode's `session.compaction.ended` /
`session.compaction.failed` events to verify the result. Logs never include
prompts, response bodies, credentials, or error messages/stacks.

## Background compaction and prefix reuse

OpenCode's normal summary request keeps the system instructions, tool definitions,
and conversation prefix, then appends the summary instruction. That allows cache
reuse when the provider supports it; oversized-request fallback, other plugins,
and provider behavior can still break the match. Keeping the same summary model
is necessary but not proof of a hit. Validate real summary cache-read counts.

OpenCode's experimental background engine uses the same summary path, holding the
result until compaction is due. A queued `session.compact()` can consume a valid
held summary, avoiding another model request. However, the public API exposes no
prepare/hold/apply methods: this plugin cannot start background preparation at an
idle deadline or wait until a cold-cache return to apply the result. Without a
held summary it requests ordinary compaction, which applies once completed.

We leave `experimental.background_compaction` unchanged: enabling that global flag
would also affect Go and other providers. If enabled separately, OpenCode can
prepare summaries near its context threshold and the plugin's queued request can
reuse them. This is not guaranteed for conversations far below that threshold.

## Architecture and tests

- `copilot.js` resolves Copilot-specific timer and size policy without I/O.
- `scheduler.js` owns deadlines and one-shot admission, independent of providers
  and OpenCode. Its external dependencies are injected callbacks.
- `logger.js` filters and persists privacy-safe diagnostic events.
- `index.js` adapts OpenCode hooks/events to the scheduler and checks live state.

Add a future provider as a separate policy in `index.js`'s `policies` list with
its own tests. If a provider eventually exposes authoritative expiry, extend the
policy/scheduler boundary rather than embedding provider parsing in the timer.

Run the deterministic tests with Node 24 or later:

```sh
node --test opencode/idle-compaction/*.test.js
```

References: [server plugins](https://opencode.ai/v2/docs/build/plugins/server),
[compaction](https://opencode.ai/v2/docs/compaction).
