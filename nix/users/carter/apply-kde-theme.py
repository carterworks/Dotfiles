import configparser
import os
from pathlib import Path
import shutil
import sys
import tempfile


def read_config(path):
    config = configparser.ConfigParser(interpolation=None)
    config.optionxform = str
    with Path(path).open() as file:
        config.read_file(file)
    return config


def apply(path, scheme, name, base):
    path = Path(path)
    current = read_config(path if path.exists() else base)
    before = {section: dict(current[section]) for section in current.sections()}
    palette = read_config(scheme)
    # Remove the escaped group written by the first theme preview.
    current.remove_section(r"Colors:Header\]\[Inactive")
    for section in palette.sections():
        if section != "General":
            current[section] = dict(palette[section])
    for section in ("General", "Icons", "KDE"):
        if not current.has_section(section):
            current.add_section(section)
    current["General"].pop("ColorSchemeHash", None)
    current["General"]["ColorScheme"] = name
    current["General"]["font"] = "Inter,10,-1,5,50,0,0,0,0,0"
    current["Icons"]["Theme"] = "Papirus"
    current["KDE"]["widgetStyle"] = "Breeze"
    after = {section: dict(current[section]) for section in current.sections()}
    if before == after and not path.is_symlink():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    backup = path.with_suffix(".before-desktop-theme")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            current.write(output)
            output.close()
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    apply(*sys.argv[1:])
