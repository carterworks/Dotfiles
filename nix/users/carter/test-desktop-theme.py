import json
from pathlib import Path
import re
import sys
import tomllib
import configparser
import zipfile


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
kde = configparser.ConfigParser()
kde.read(files["kde"])
rgb = lambda color: ",".join(str(int(color[i:i + 2], 16)) for i in (1, 3, 5))
assert kde["Colors:Window"]["BackgroundNormal"] == rgb(colors["background"])
assert kde["Colors:Header][Inactive"]["BackgroundNormal"] == rgb(colors["background"])
assert kde["Colors:Selection"]["ForegroundNormal"] == rgb(colors["text"])
for file in ("gtk3", "gtk4"):
    css = Path(files[file]).read_text()
    assert f'@define-color theme_bg_color_breeze {colors["background"]};' in css
    assert f'@define-color theme_selected_bg_color_breeze {colors["selection"]};' in css
assert "@import 'colors.css';" in Path(files["gtk4Css"]).read_text()
assert read_json(files["zedSettings"])["theme"]["light"] == apps["zed"]["name"]
assert read_toml(files["helix"])["theme"] == apps["helix"]
assert f'theme "{apps["zellij"]}"' in Path(files["zellij"]).read_text()
assert f'color_theme = "{apps["btop"]}"' in Path(files["btop"]).read_text()
if "btopTheme" in apps:
    btop_theme = Path(files["btopTheme"]).read_text()
    for role, color in apps["btopTheme"].items():
        assert f'theme[{role}]="{color}"' in btop_theme
fish = Path(files["fish"]).read_text()
assert f'set -g fish_color_comment {colors["muted"][1:]}' in fish
assert "set -gx FZF_DEFAULT_OPTS" in fish
assert "--layout=reverse" in config["fzfOptions"]
assert f'bg:{colors["background"]}' in config["fzfOptions"]
assert f'--background: {colors["background"]};' in Path(files["heroic"]).read_text()
with zipfile.ZipFile(files["telegram"]) as archive:
    palette = archive.read("colors.tdesktop-theme").decode()
    assert f'windowBg: {colors["background"]};' in palette
    assert f'msgOutBg: {colors["selection"]};' in palette


def luminance(color):
    values = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values]
    return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


for palette in config.get("palettes", [colors]):
    for foreground, background in (("text", "background"), ("muted", "surface"),
                                  ("muted", "background"), ("hoverText", "hover"),
                                  ("hoverText", "pressed"), ("selectedText", "selection")):
        low, high = sorted((luminance(palette[foreground]), luminance(palette[background])))
        assert (high + 0.05) / (low + 0.05) >= 4.5, (foreground, background)
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
if "zellijTheme" in apps:
    zellij = Path(files["zellij"]).read_text()
    assert apps["zellij"] in zellij
    for component, roles in apps["zellijTheme"].items():
        assert component in zellij
        for color in roles.values():
            assert color in zellij
else:
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
