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
colors = config["colors"]
custom = apps["herdrColors"] | {
    "accent": colors["accent"],
    "panel_bg": colors["background"],
    "sidebar_bg": colors["background"],
    "active_row_bg": colors["selection"],
    "selection_bg": colors["hover"],
    "surface0": colors["surface"],
    "surface1": colors["hover"],
    "surface_dim": colors["border"],
    "overlay0": colors["border"],
    "overlay1": colors["muted"],
    "text": colors["text"],
    "subtext0": colors["muted"],
}
assert herdr == read_toml(files["herdrBase"]) | {
    "theme": {"name": apps["herdr"], "auto_switch": False, "custom": custom}
}
vicinae = read_json(files["vicinae"])
assert vicinae["theme"]["light"]["name"] == vicinae["theme"]["dark"]["name"]
vicinae_theme = read_toml(files["vicinaeTheme"])
assert vicinae_theme["meta"]["variant"] == mode
assert isinstance(vicinae_theme["meta"]["description"], str)
assert vicinae_theme["colors"]["core"]["background"] == colors["background"]
assert vicinae_theme["colors"]["core"]["foreground"] == colors["text"]
assert vicinae_theme["colors"]["list"]["item"]["selection"]["background"] == colors["selection"]

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
