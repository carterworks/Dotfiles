import os
import re
from pathlib import Path
import sys
import tempfile


def key_of(line):
    # [$e], [$i] and [$d] are option flags on the same key; [de] is a locale and a key of its own.
    return re.sub(r"\[\$[a-z]+\]", "", line.split("=", 1)[0]).strip()


def read_groups(text):
    groups = {}
    order = []
    group = None
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("["):
            group = stripped
            continue
        if "=" not in stripped:
            continue
        if group is None:
            raise ValueError(f"key outside a group: {stripped}")
        key = key_of(stripped)
        if group not in groups:
            groups[group] = {}
            order.append(group)
        groups[group][key] = stripped
    return order, groups


def merge_text(current, source):
    order, wanted = read_groups(source)
    lines = current.splitlines()
    seen = set()
    starts = {}
    group = None
    last_key = {}
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("["):
            group = stripped
            starts.setdefault(group, index)
            continue
        if "=" not in stripped or stripped.startswith("#"):
            continue
        last_key[group] = index
        key = key_of(stripped)
        if key in wanted.get(group, {}):
            lines[index] = wanted[group][key]
            seen.add((group, key))
    insertions = {}
    appended = []
    for group in order:
        missing = [line for key, line in wanted[group].items() if (group, key) not in seen]
        if not missing:
            continue
        if group in starts:
            insertions[last_key.get(group, starts.get(group))] = missing
        else:
            appended.append([group, *missing])
    for index in sorted(insertions, reverse=True):
        lines[index + 1:index + 1] = insertions[index]
    for block in appended:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend(block)
    return "\n".join(lines) + "\n" if lines else ""


def read_live(path):
    try:
        return path.read_text()
    except FileNotFoundError:
        return None


def write(path, text, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, prefix=f".{path.name}.", delete=False) as output:
        temporary = Path(output.name)
        try:
            output.write(text)
            output.close()
            os.chmod(temporary, mode)
            # os.replace swaps the link itself, so KDE's state never reaches the checkout a link pointed at.
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def live_mode(path):
    if path.is_symlink() or not path.exists():
        return 0o600
    return path.stat().st_mode & 0o777


def merge(source, path):
    current = read_live(path)
    merged = merge_text(current or "", source.read_text())
    if current == merged and not path.is_symlink():
        return
    write(path, merged, live_mode(path))


def seed(source, path):
    if path.is_symlink():
        current = read_live(path)
        write(path, source.read_text() if current is None else current, 0o600)
    elif not path.exists():
        write(path, source.read_text(), 0o600)


MODES = {"merge": merge, "seed": seed}


def main(arguments):
    if len(arguments) % 3:
        raise SystemExit("usage: apply-kde-config.py (merge|seed) SOURCE TARGET ...")
    jobs = [arguments[index:index + 3] for index in range(0, len(arguments), 3)]
    for mode, _, _ in jobs:
        if mode not in MODES:
            raise SystemExit(f"apply-kde-config: unknown mode {mode!r}")
    for mode, source, target in jobs:
        MODES[mode](Path(source), Path(target))


if __name__ == "__main__":
    main(sys.argv[1:])
