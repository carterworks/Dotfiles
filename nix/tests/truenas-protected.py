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
PREVENT = re.compile(r"\blifecycle\s*\{[^}]*\bprevent_destroy\s*=\s*true\b", re.DOTALL)


def blocks(text):
    for match in HEADER.finditer(text):
        depth, end = 0, match.end() - 1
        for end in range(match.end() - 1, len(text)):
            depth += {"{": 1, "}": -1}.get(text[end], 0)
            if depth == 0:
                break
        yield (match.group(1), match.group(2)), text[match.end():end]


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
        if not PREVENT.search(found[address]):
            errors.append(f"{'.'.join(address)} has no lifecycle {{ prevent_destroy = true }}")
    for address in sorted(found.keys() - PROTECTED - UNPROTECTED):
        if address[0].startswith("truenas_"):
            errors.append(f"{'.'.join(address)} is in neither list in {Path(__file__).name}")

    for error in errors:
        print(f"truenas-protected: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
