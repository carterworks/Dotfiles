import json
import os
from pathlib import Path
import shutil
import sys
import tempfile


def apply(vault, appearance):
    directory = Path(vault) / ".obsidian"
    if not directory.is_dir():
        return
    path = directory / "appearance.json"
    current = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(current, dict):
        raise ValueError(f"{path}: expected a JSON object")
    updated = current | appearance
    if updated == current:
        return
    backup = path.with_suffix(".json.before-desktop-theme")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)
    with tempfile.NamedTemporaryFile(mode="w", dir=directory, delete=False) as output:
        temporary = Path(output.name)
        try:
            json.dump(updated, output, indent=2)
            output.write("\n")
            output.close()
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    settings = json.loads(Path(sys.argv[1]).read_text())
    for vault in settings["vaults"]:
        apply(vault, settings["appearance"])
