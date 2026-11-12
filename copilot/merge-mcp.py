import json
from pathlib import Path
import sys
import tempfile


def merge_mcp(shared_path, local_path):
    shared = json.loads(shared_path.read_text())
    local = json.loads(local_path.read_text()) if local_path.exists() else {}
    if not isinstance(shared, dict) or not isinstance(shared.get("mcpServers"), dict):
        raise ValueError("Shared MCP configuration must contain a mcpServers object")
    if not isinstance(local, dict) or not isinstance(local.get("mcpServers", {}), dict):
        raise ValueError("Local MCP configuration must be an object with a mcpServers object")

    merged = local | {"mcpServers": local.get("mcpServers", {}) | shared["mcpServers"]}
    if merged == local and not local_path.is_symlink():
        local_path.chmod(0o600)
        return

    local_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=local_path.parent, delete=False) as file:
        temporary = Path(file.name)
        try:
            json.dump(merged, file, indent=2)
            file.write("\n")
            file.close()
            temporary.replace(local_path)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    merge_mcp(Path(sys.argv[1]), Path(sys.argv[2]))
