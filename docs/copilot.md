# GitHub Copilot CLI

## Shared and local configuration

`~/.copilot/copilot-instructions.md` links to `agents/AGENTS.md`. Copilot also
discovers repository `AGENTS.md` files without additional configuration.

Both OpenCode and Copilot read `~/.agents/skills`. Home Manager sets
`COPILOT_SKILLS_DIRS` to include `~/.claude/skills/synced` (including nested
skills) and the legacy `~/.config/opencode/skills`. These remain local; no
skill copies or work-specific directories are committed here.

`copilot/mcp-config.json` holds the shared MCP servers. Home Manager merges
them into `~/.copilot/mcp-config.json`, a regular, owner-only file, instead of
linking it into the checkout. Other local servers and settings are preserved;
shared definitions win for matching server names. Shared MCP edits take effect
after the next Home Manager activation, not immediately through a symlink.

Add work-only servers with `copilot mcp add` or edit the local file. Keep
credentials in fnox and use `${VARIABLE_NAME}` in MCP headers or environment
values; do not resolve them to plaintext in the file. Copilot does not accept
OpenCode's `{env:VARIABLE_NAME}` syntax.

OAuth sign-ins belong to each client, not the shared config. If a remote
server needs authentication, use `/mcp auth SERVER-NAME` in Copilot; do not
copy OpenCode's token storage.

## Verify discovery

```sh
copilot instruction list
copilot skill list
copilot mcp list
```

For an existing session, use `/skills reload` after changing skill locations
and `/mcp` to check server connections. Start a new session to reload changed
custom instructions.

OpenCode's bundled `opencode` and `report` skills are not filesystem skills;
local exports were installed on the Mac with `copilot skill add`. They remain guides
for OpenCode, not Copilot. The bundled `browser` skill requires OpenCode's
desktop browser tools and cannot be ported to Copilot CLI. Use the shared
`agent-browser` skill instead.
