"""Fail when a TrueNAS resource that holds data, permissions or monitoring
loses its prevent_destroy.

prevent_destroy cannot stop a plan that deletes the whole resource block, so
the protected blocks are listed here: removing one means editing this list
too. A new truenas_* resource must be added to one of the two sets.

Usage: truenas-protected.py <repository root>
"""

import re
import sys
from pathlib import Path

PROTECTED = {
    ("truenas_dataset", "this"),
    ("truenas_filesystem_acl", "nfs4"),
    ("truenas_filesystem_acl", "vm_data"),
    ("truenas_nfs_share", "this"),
    ("truenas_smb_share", "this"),
    ("truenas_group", "this"),
    ("truenas_user", "this"),
    ("truenas_periodic_snapshot_task", "this"),
    ("truenas_scrub_task", "this"),
    ("truenas_cronjob", "this"),
    ("truenas_init_shutdown_script", "enable_linger_carter"),
}

# Destroying these only forgets them in the state.
UNPROTECTED = {
    ("truenas_service", "this"),
    ("truenas_nfs_config", "this"),
    ("truenas_smb_config", "this"),
}

HEADER = re.compile(r'^resource\s+"([^"]+)"\s+"([^"]+)"\s*\{', re.MULTILINE)
PREVENT = re.compile(r"\bprevent_destroy\s*=\s*true\b")
LIFECYCLE = re.compile(r"\blifecycle\s*\{")


def blank(text):
    """Replace comments and string contents with spaces, keeping offsets and
    newlines, so braces or prevent_destroy inside them are not code."""
    out, i, n = list(text), 0, len(text)

    def erase(start, end):
        for k in range(start, end):
            if out[k] != "\n":
                out[k] = " "

    def string(i):
        # i is just past the opening quote; returns the index past the closing one.
        start = i
        while i < n and text[i] != '"':
            if text[i] == "\\":
                i += 2
                continue
            if text.startswith("${", i):
                erase(start, i)
                i = code(i + 2, closing="}")
                start = i
                continue
            i += 1
        erase(start, i)
        return i + 1

    def code(i, closing=None):
        depth = 0
        while i < n:
            c = text[i]
            if c == "#" or text.startswith("//", i):
                end = text.find("\n", i)
                end = n if end < 0 else end
                erase(i, end)
                i = end
            elif text.startswith("/*", i):
                end = text.find("*/", i + 2)
                end = n if end < 0 else end + 2
                erase(i, end)
                i = end
            elif c == '"':
                i = string(i + 1)
            elif closing and c == "{":
                depth += 1
                i += 1
            elif closing and c == "}":
                if depth == 0:
                    return i + 1
                depth -= 1
                i += 1
            else:
                i += 1
        return i

    code(0)
    return "".join(out)


def matching(text, open_brace):
    depth = 0
    for end in range(open_brace, len(text)):
        depth += {"{": 1, "}": -1}.get(text[end], 0)
        if depth == 0:
            return end
    return len(text)


def blocks(text):
    # Headers are matched in the original, because blanking empties their
    # quoted names; one inside a comment is blanked and skipped.
    code = blank(text)
    for match in HEADER.finditer(text):
        if not code.startswith("resource", match.start()):
            continue
        end = matching(code, match.end() - 1)
        yield (match.group(1), match.group(2)), code[match.end():end]


def protected(body):
    for match in LIFECYCLE.finditer(body):
        inner = body[match.end():matching(body, match.end() - 1)]
        if PREVENT.search(inner):
            return True
    return False


def main(root):
    found, errors = {}, []
    for path in sorted((Path(root) / "infra" / "truenas").glob("*.tf")):
        for address, body in blocks(path.read_text()):
            if address in found:
                errors.append(f"{'.'.join(address)} is declared twice")
            found[address] = body

    for address in sorted(PROTECTED - found.keys()):
        errors.append(f"{'.'.join(address)} is missing; deleting its block destroys what it manages")
    for address in sorted(PROTECTED & found.keys()):
        if not protected(found[address]):
            errors.append(f"{'.'.join(address)} has no lifecycle {{ prevent_destroy = true }}")
    for address in sorted(found.keys() - PROTECTED - UNPROTECTED):
        if address[0].startswith("truenas_"):
            errors.append(f"{'.'.join(address)} is in neither list in {Path(__file__).name}")

    for error in errors:
        print(f"truenas-protected: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
