# OpenCode Plugins

This directory contains custom plugins for OpenCode.

## osgrep Plugin

The `osgrep.js` plugin integrates [osgrep](https://github.com/ryandonofrio/osgrep) semantic code search into OpenCode.

### Features

- **Auto-start**: Automatically starts `osgrep serve` when an OpenCode session begins
- **Auto-stop**: Automatically stops `osgrep serve` when the session ends
- **Custom Tool**: Adds `osgrep` as a custom tool that OpenCode can use for semantic code searches

### Prerequisites

Install osgrep globally:

```bash
npm install -g osgrep
# or
pnpm install -g osgrep
# or
bun install -g osgrep
```

Run setup to download embedding models:

```bash
osgrep setup
```

### Usage

Once installed, OpenCode will automatically have access to the `osgrep` tool. OpenCode can use it like:

```
Search for "authentication logic" in the codebase
```

OpenCode will prefer `osgrep` over `grep` for concept-based searches since it provides semantic understanding of code.

### How it Works

1. **Session Start**: When you start OpenCode, the plugin spawns `osgrep serve` as a detached background process
2. **Search**: OpenCode can call the `osgrep` tool with natural language queries
3. **Session End**: When you exit OpenCode, the plugin gracefully shuts down the osgrep server

### Tool Arguments

The `osgrep` tool accepts:

- `query` (required): Natural language description of what to search for
- `maxResults` (optional): Maximum number of results (default: 25)
- `perFile` (optional): Maximum matches per file (default: 1)
- `showScores` (optional): Show relevance scores (default: false)
- `compact` (optional): Show file paths only (default: false)

### Troubleshooting

If osgrep isn't working:

1. Verify osgrep is installed: `which osgrep`
2. Check if the server is running: `cat .osgrep/server.json`
3. View osgrep logs: `tail -f /tmp/osgrep.log`
4. Run osgrep doctor: `osgrep doctor`
