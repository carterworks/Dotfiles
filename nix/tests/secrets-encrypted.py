"""Fail unless secrets/fnox.toml holds only age ciphertext and is the only store.

Usage: secrets-encrypted.py SOURCE_TREE

Checks the file's raw text (no comments, which could carry anything), its
structure (only the keys fnox needs), each recipient (a well-formed public key),
and each value: a base64 age file whose recipient stanzas are exactly the ones
its provider's recipients produce. Then it fails on any other fnox store, age
file or age secret key anywhere in the tree.
"""

import base64
import binascii
import hashlib
import os
import re
import sys
import tomllib

STORE = "secrets/fnox.toml"
AGE_HEADER = b"age-encryption.org/v1\n"
BATCH = "fnox-age-batch-v1:"
# Spelled in pieces so this file does not match its own scan.
AGE_FILE_B64 = "YWdlLWVuY3J5" + "cHRpb24ub3JnL3Yx"
SECRET_KEY = "AGE-SECRET" + "-KEY-"
ARMOR = "-----BEGIN AGE " + "ENCRYPTED FILE-----"
FNOX_NAME = re.compile(r"\.?fnox(\.[^/]+)?\.toml")
BECH32 = re.compile(r"age1[02-9ac-hj-np-z]{58}")
B64 = re.compile(r"[A-Za-z0-9+/]+={0,2}")
B64_NOPAD = re.compile(r"[A-Za-z0-9+/]+")

errors = []


def fail(message):
    errors.append(message)


def b64decode(text, padded=True):
    pattern = B64 if padded else B64_NOPAD
    if not pattern.fullmatch(text):
        raise ValueError("not base64")
    if not padded:
        text += "=" * (-len(text) % 4)
    try:
        return base64.b64decode(text, validate=True)
    except binascii.Error as error:
        raise ValueError(str(error)) from error


def ssh_ed25519_tag(recipient):
    """The stanza tag age writes for an ssh-ed25519 recipient, or None."""
    parts = recipient.split(" ")
    if len(parts) not in (2, 3) or parts[0] != "ssh-ed25519":
        return None
    try:
        blob = b64decode(parts[1])
    except ValueError:
        return None
    name = b"ssh-ed25519"
    expected = len(name).to_bytes(4, "big") + name + (32).to_bytes(4, "big")
    if len(blob) != len(expected) + 32 or not blob.startswith(expected):
        return None
    return base64.b64encode(hashlib.sha256(blob).digest()[:4]).decode().rstrip("=")


def expected_stanzas(name, provider):
    stanzas = []
    for recipient in provider.get("recipients", []):
        if not isinstance(recipient, str):
            fail(f"provider {name}: recipient is not a string")
        elif BECH32.fullmatch(recipient):
            stanzas.append("X25519")
        elif (tag := ssh_ed25519_tag(recipient)) is not None:
            stanzas.append(f"ssh-ed25519 {tag}")
        else:
            fail(f"provider {name}: recipient is not an age1 or ssh-ed25519 public key")
    return sorted(stanzas)


def age_stanzas(data):
    """Recipient stanzas of a well-formed binary age file; raises otherwise."""
    if not data.startswith(AGE_HEADER):
        raise ValueError("no age header")
    end = data.find(b"\n--- ")
    if end < 0:
        raise ValueError("no header MAC")
    mac_end = data.index(b"\n", end + 1)
    b64decode(data[end + 5 : mac_end].decode(), padded=False)
    payload = data[mac_end + 1 :]
    # 16-byte nonce, then at least one chunk with its 16-byte tag.
    if len(payload) < 32:
        raise ValueError("payload too short")
    stanzas, grease = [], 0
    lines = data[len(AGE_HEADER) : end].decode().split("\n")
    for line in lines:
        if line.startswith("-> "):
            args = line[3:].split(" ")
            if args[0] == "X25519" and len(args) == 2:
                stanzas.append("X25519")
            elif args[0] == "ssh-ed25519" and len(args) == 3:
                stanzas.append(f"ssh-ed25519 {args[1]}")
            elif args[0].endswith("-grease"):
                grease += 1
            else:
                raise ValueError(f"unexpected stanza type {args[0]!r}")
        elif line:
            b64decode(line, padded=False)
    if grease > 1:
        raise ValueError("more than one grease stanza")
    return sorted(stanzas)


def check_store(path):
    with open(path, "rb") as file:
        raw = file.read()
    if b"#" in raw:
        fail(f"{STORE}: has a comment (or a '#'); explain it in docs/secrets.md instead")
    config = tomllib.loads(raw.decode())
    if set(config) - {"default_provider", "providers", "secrets"}:
        fail(f"{STORE}: unexpected top-level keys {sorted(set(config) - {'default_provider', 'providers', 'secrets'})}")
    if config.get("default_provider") != "admin":
        fail(f"{STORE}: default_provider must stay admin")
    providers = config.get("providers", {})
    expected = {}
    for name, provider in providers.items():
        if not isinstance(provider, dict) or set(provider) != {"type", "recipients"} or provider["type"] != "age":
            fail(f"provider {name}: must be an age provider with only type and recipients")
            continue
        if not isinstance(provider["recipients"], list) or not provider["recipients"]:
            fail(f"provider {name}: recipients must be a non-empty list")
            continue
        expected[name] = expected_stanzas(name, provider)
    for name, secret in config.get("secrets", {}).items():
        if not isinstance(secret, dict) or set(secret) != {"provider", "value"} or not isinstance(secret["value"], str):
            fail(f"secret {name}: must have only a provider and a value")
            continue
        if secret["provider"] not in expected:
            fail(f"secret {name}: unknown or invalid provider {secret['provider']!r}")
            continue
        value = secret["value"]
        try:
            if value.startswith(BATCH):
                header, ciphertext = value[len(BATCH) :].split(":")
                b64decode(ciphertext)
                stanzas = age_stanzas(b64decode(header))
            else:
                stanzas = age_stanzas(b64decode(value))
        except ValueError as error:
            fail(f"secret {name}: not a well-formed age value ({error})")
            continue
        if stanzas != expected[secret["provider"]]:
            fail(f"secret {name}: recipients do not match provider {secret['provider']}")


def check_tree(root):
    for directory, subdirectories, files in os.walk(root):
        subdirectories[:] = [d for d in subdirectories if d != ".git"]
        for file in files:
            path = os.path.join(directory, file)
            relative = os.path.relpath(path, root)
            if relative == STORE:
                continue
            if FNOX_NAME.fullmatch(file):
                fail(f"{relative}: a second fnox store; only {STORE} may exist")
            if os.path.islink(path):
                continue
            with open(path, "rb") as handle:
                text = handle.read().decode(errors="replace")
            for needle, what in (
                (AGE_FILE_B64, "age ciphertext"),
                (ARMOR, "an armored age file"),
                (SECRET_KEY, "an age secret key"),
            ):
                if needle in text:
                    fail(f"{relative}: contains {what} outside {STORE}")
            if file.endswith(".toml") and re.search(r"^\s*\[providers\.", text, re.M):
                fail(f"{relative}: looks like a fnox store outside {STORE}")


root = sys.argv[1]
check_store(os.path.join(root, STORE))
check_tree(root)
for message in errors:
    print(message, file=sys.stderr)
sys.exit(1 if errors else 0)
