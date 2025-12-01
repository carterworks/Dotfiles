# osgrep Integration Complete

## Summary

Successfully integrated osgrep semantic code search into OpenCode via a native plugin.

## Files

- `~/.dotfiles/opencode/plugin/osgrep.js` - Main plugin (4.5 KB)
- `~/.dotfiles/opencode/plugin/README.md` - Documentation

## How It Works

### Auto-start (session.created)
When OpenCode starts in a directory, the plugin:
1. Spawns `osgrep serve` as a detached background process
2. Server writes auth token to `.osgrep/server.json`
3. Server performs initial indexing if needed
4. Server watches for file changes and incrementally updates index

### Custom Tool (osgrep)
OpenCode has access to the `osgrep` tool with these arguments:
- `query` (required): Natural language search query
- `maxResults` (optional): Max results (default: 25)
- `perFile` (optional): Max matches per file (default: 1)
- `showScores` (optional): Show relevance scores
- `compact` (optional): File paths only

Example usage by OpenCode:
- "Search for authentication logic"
- "Find error handling code"  
- "Where is the database connection pooled?"

### Auto-stop (session.deleted)
When OpenCode exits:
1. Reads PID from `.osgrep/server.json`
2. Sends SIGTERM to the process
3. Cleans up lock file
4. Falls back to `pkill -f "osgrep serve"` if needed

## Key Technical Details

### Why Not Claude Code CLI Hooks?
The osgrep repo includes Claude Code CLI hooks, but:
- Different hook system (hook.json vs ES6 modules)
- OpenCode plugins more powerful (typed tool args, better integration)
- Native OpenCode integration preferred

### Import Fixes
Changed from:
```javascript
import { spawn } from "child_process";
import { readFileSync, existsSync, unlinkSync } from "fs";
import { join } from "path";
```

To:
```javascript
import { spawn } from "node:child_process";
import { readFileSync, existsSync, unlinkSync } from "node:fs";
import { join } from "node:path";
```

The `node:` prefix is required for OpenCode plugins to load properly.

## Verification

Check if working:
```bash
# After starting OpenCode in a directory

# Should see osgrep serve process
ps aux | grep "osgrep serve"

# Should see server lock
cat .osgrep/server.json

# Should see indexed data
ls ~/.osgrep/data/
```

## Testing

Ask OpenCode to use semantic search:
- "Search for 'authentication logic'"
- "Find all error handling code"
- "Where do we initialize the embedding models?"

OpenCode will automatically prefer `osgrep` over `grep` for concept-based searches.

## Troubleshooting

**Server not starting:**
- Check logs: `tail -f /tmp/osgrep.log`
- Verify osgrep installed: `which osgrep && osgrep --version`
- Test manually: `osgrep serve` in project dir

**Tool not available:**
- Restart OpenCode (plugins load on startup)
- Check plugin syntax: `node --check ~/.dotfiles/opencode/plugin/osgrep.js`

**Port conflicts:**
- Default port: 4444
- Kill existing: `lsof -i :4444` then `kill -TERM <PID>`
- Or set OSGREP_PORT env var

## Next Steps

The integration is complete! Just use OpenCode normally and it will automatically:
- Start osgrep server when you begin working
- Use semantic search when appropriate  
- Stop server when you exit

No manual intervention needed.
