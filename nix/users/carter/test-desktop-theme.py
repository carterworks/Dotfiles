import json
from pathlib import Path
import re
import sys
import tomllib


def read_json(path):
    return json.loads(Path(path).read_text())


def read_toml(path):
    return tomllib.loads(Path(path).read_text())


config = read_json(sys.argv[1])
mode = config["appearance"]
apps = config["apps"]
files = config["files"]

cli = read_json(files["opencode"])
assert cli == read_json(files["opencodeBase"]) | {"theme": {"name": apps["opencode"], "mode": mode}}
herdr = read_toml(files["herdr"])
assert herdr == read_toml(files["herdrBase"]) | {"theme": {"name": apps["herdr"], "auto_switch": False}}

helix = read_toml(files["helix"])
assert helix["theme"] == apps["helix"]
assert Path(files["helixBuiltin"]).is_file(), "Helix theme is not included in the pinned editor"
zellij = Path(files["zellijBuiltin"]).read_text()
assert apps["zellij"] in zellij, "Zellij theme is not included in the pinned multiplexer"

zed = read_json(files["zed"])
selected = next(t for t in zed["themes"] if t["name"] == apps["zed"]["name"])
assert selected["appearance"] == mode
for color in re.findall(r'"(#[^"]+)"', json.dumps(zed)):
    assert re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", color), f"Invalid Zed colour: {color}"

obsidian = read_json(files["obsidianSettings"])
assert obsidian["appearance"]["cssTheme"] == read_json(files["obsidianManifest"])["name"]
assert obsidian["appearance"]["theme"] == ("moonstone" if mode == "light" else "obsidian")
css = Path(files["obsidianCss"]).read_text()
assert ".theme-light" in css
for replacement in apps["obsidian"].get("cssReplacements", []):
    assert replacement["from"] not in css
    assert replacement["to"] in css
print("Desktop theme configuration checks passed")
