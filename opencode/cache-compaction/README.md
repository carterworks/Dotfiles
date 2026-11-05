# Cache-expiry compaction

An OpenCode V2 server plugin that requests a summary while a large conversation's
prompt cache is likely still warm. It reduces the uncached input needed when you
return after a break; it does not preserve the old cache indefinitely.

Only `github-copilot` is supported. OpenCode Go and other providers are untouched.
Requires OpenCode 2.2.5 or later; the `experimental.idle` hook is experimental.
There are no runtime dependencies.

## Timing and safeguards

- The deadline is measured from the latest primary model request's start, not
  response completion. By default compaction is requested at four minutes:
  an **estimated five-minute TTL**, minus a one-minute safety margin.
- A successful response must report cache reads or writes and at least 32,000
  input tokens, including cached input. This size threshold is a heuristic, not
  a measurement of how much conversation a summary will remove. Raise it when
  using unusually large fixed instructions or `compaction.keep.tokens`.
- The session must reach normal idle with no background jobs. Subagents,
  interrupted/failed sessions, expired deadlines, and responses that finish too
  late to retain the safety margin are skipped.
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
the fallback TTL nor model metadata guarantees a hit: routing, eviction, changed
prefixes, and proxy behavior can cause earlier misses. The plugin does not change
provider cache retention settings or parse/store raw response bodies.

## Configuration

Dotbot links this directory to `~/.config/opencode/cache-compaction`, and the
global OpenCode config loads it explicitly. It is intentionally outside `plugins/`
so helper and test files cannot be discovered as plugins.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": [
    {
      "package": "./cache-compaction",
      "options": {
        "ttl": "5m",
        "marginMs": 60000,
        "minInputTokens": 32000,
        "models": {
          "gpt-6.1-sol": "5m",
          "some-model-with-unknown-policy": false,
        },
      },
    },
  ],
}
```

TTL precedence: plugin `models[modelID]` override, resolved model/variant
`settings.cache.ttl`, then plugin `ttl` (default `"5m"`). Durations use integer
`ms`, `s`, `m`, `h`, or `d` units. `false` disables a model override or the fallback;
invalid durations fail closed. Margin and size options must be positive integers.
Disable the entire plugin by removing its entry or adding
`"-dotfiles.cache-compaction"` after it.

The plugin logs admission, not completion, with the `[cache-compaction]` prefix.
Use OpenCode's `session.compaction.ended` / `session.compaction.failed` events to
verify the result. It never logs prompts, response bodies, or credentials.

## Architecture and tests

- `copilot.js` resolves Copilot-specific TTL policy without I/O.
- `scheduler.js` owns deadlines and one-shot admission, independent of providers
  and OpenCode. Its external dependencies are injected callbacks.
- `index.js` adapts OpenCode hooks/events to the scheduler and checks live state.

Add a future provider as a separate policy in `index.js`'s `policies` list with
its own tests. If a provider eventually exposes authoritative expiry, extend the
policy/scheduler boundary rather than embedding provider parsing in the timer.

Run the deterministic tests with Node 24 or later:

```sh
node --test opencode/cache-compaction/*.test.js
```

References: [server plugins](https://opencode.ai/v2/docs/build/plugins/server),
[compaction](https://opencode.ai/v2/docs/compaction).
