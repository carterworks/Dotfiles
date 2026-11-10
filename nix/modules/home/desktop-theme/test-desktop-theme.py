import configparser
import json
from pathlib import Path
import sys
import tomllib
import zipfile


def read_json(path):
    return json.loads(Path(path).read_text())


def read_toml(path):
    return tomllib.loads(Path(path).read_text())


def contrast(foreground, background):
    def luminance(color):
        values = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values]
        return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))

    low, high = sorted((luminance(foreground), luminance(background)))
    return (high + 0.05) / (low + 0.05)


config = read_json(sys.argv[1])
mode = config["appearance"]
apps = config["apps"]
colors = config["colors"]
files = config["files"]

for palette in config["palettes"]:
    for foreground, background in (("text", "background"), ("muted", "surface"),
                                   ("muted", "background"), ("hoverText", "hover"),
                                   ("hoverText", "pressed"), ("selectedText", "selection")):
        assert contrast(palette[foreground], palette[background]) >= 4.5, (foreground, background)

kde = configparser.ConfigParser()
kde.read(files["kde"])
rgb = ",".join(str(int(colors["background"][i:i + 2], 16)) for i in (1, 3, 5))
assert kde["Colors:Window"]["BackgroundNormal"] == rgb
# KConfig nests groups with a literal "][", which INI escaping would break.
assert kde.has_section("Colors:Header][Inactive")

for file in ("gtk3", "gtk4"):
    assert f'@define-color theme_bg_color_breeze {colors["background"]};' in Path(files[file]).read_text()
assert "@import 'colors.css';" in Path(files["gtk4Css"]).read_text()

with zipfile.ZipFile(files["telegram"]) as archive:
    assert f'windowBg: {colors["background"]};' in archive.read("colors.tdesktop-theme").decode()

read_toml(files["herdr"])

vicinae = read_toml(files["vicinaeTheme"])["colors"]["list"]["item"]
assert vicinae["selection"]["background"] != vicinae["hover"]["background"], "Vicinae selection looks like hover"
assert contrast(colors["text"], vicinae["selection"]["background"]) >= 4.5, "Vicinae selection text has low contrast"

assert Path(files["helixBuiltin"]).is_file(), "Helix theme is not included in the pinned editor"
zellij = Path(files["zellij"]).read_text()
if "zellijTheme" in apps:
    for component in apps["zellijTheme"]:
        assert component in zellij
else:
    assert apps["zellij"] in Path(files["zellijBuiltin"]).read_text(), "Zellij theme is not included in the pinned multiplexer"

zed = read_json(files["zed"])
assert any(t["name"] == apps["zed"]["name"] and t["appearance"] == mode for t in zed["themes"])

obsidian = read_json(files["obsidianSettings"])
assert obsidian["appearance"]["cssTheme"] == read_json(files["obsidianManifest"])["name"]
assert ".theme-light" in Path(files["obsidianCss"]).read_text()
assert read_json(files["audit"])["vaults"] == obsidian["vaults"], "Audit resolves vaults against the working directory"
print("Desktop theme configuration checks passed")
