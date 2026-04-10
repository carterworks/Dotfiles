# fff-tools pi extension

Scaffold for a pi extension that:

- overrides built-in `find`
- overrides built-in `grep`
- adds `multi_grep`
- uses `~/.local/bin/fff-mcp` as a long-lived MCP subprocess
- falls back to pi's built-in `find` / `grep` if `fff-mcp` fails

## Files

- `index.ts` — extension entrypoint

## Current behavior

- lazy-starts `fff-mcp` on first search tool call
- restarts automatically when `ctx.cwd` changes
- shuts down on `session_shutdown`
- exposes `/fff-restart` for manual restart

## Notes

- The mapping from pi tool args to `fff-mcp` args is intentionally conservative.
- `find` maps to the MCP `find_files` tool.
- `grep` maps to the MCP `grep` tool.
- `multi_grep` maps to the MCP `multi_grep` tool.
- If the MCP request shape is slightly off for your installed `fff-mcp`, this scaffold should still degrade safely via built-in fallback.

## Review / test locally

```bash
pi -e /Users/cmcbride/.config/dotfiles/pi/extensions/fff-tools/index.ts
```

Then try prompts that trigger:

- `find`
- `grep`
- `multi_grep`

## Wired into dotfiles install

This extension **is** linked by `install.conf.yaml` to:

- `~/.config/pi/agent/extensions/fff-tools/`

So after `./install` (or by using the repo directly from that linked location), it is available to pi's normal extension discovery and `/reload` flow.
