"""Read-only audit of the activated theme, separate from build-time checks."""
import configparser
import json
from pathlib import Path
import sys


def audit(settings):
    failures = []
    for live, expected in settings["files"].items():
        path = Path(live)
        if not path.exists():
            failures.append(f"Missing or broken link: {live}")
        elif path.read_bytes() != Path(expected).read_bytes():
            failures.append(f"Not the generated theme configuration: {live}")
    kde = configparser.ConfigParser(interpolation=None)
    kde.read(settings["kde"])
    for section, values in settings["palette"].items():
        for key, expected in values.items():
            actual = kde.get(section, key, fallback=None)
            if isinstance(expected, bool):
                expected = str(expected).lower()
            if isinstance(expected, float):
                try:
                    matches = actual is not None and float(actual) == expected
                except ValueError:
                    matches = False
            else:
                matches = actual == str(expected)
            if not matches:
                failures.append(f"KDE palette differs: [{section}] {key}")
    for vault in settings["vaults"]:
        path = Path(vault) / ".obsidian/appearance.json"
        if path.parent.is_dir():
            current = json.loads(path.read_text()) if path.exists() else {}
            if any(current.get(key) != value for key, value in settings["appearance"].items()):
                failures.append(f"Obsidian theme differs: {path}")
    return failures


if __name__ == "__main__":
    failures = audit(json.loads(Path(sys.argv[1]).read_text()))
    print("\n".join(failures) if failures else "Activated desktop theme checks passed")
    sys.exit(bool(failures))
