"""Fetch the animations.dev skills this account owns into a local state folder.

Replaces `npx @animationsdev/install`, which sends the token over plain http,
takes it on the command line, and writes whatever file names the server sends.
The token arrives on stdin and is never printed. The skills are paid content,
so they stay out of the repository and the Nix store.
"""

import argparse
import difflib
import json
import pathlib
import re
import shutil
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_API = "https://animations.dev"
SKILL_NAME = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
FILE_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
MAX_BYTES = 16 * 1024 * 1024


class SyncError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise SyncError(f"animations.dev answered {code} with a redirect; refusing to follow it")


def fetch(api, token):
    parsed = urllib.parse.urlsplit(api)
    if parsed.scheme != "https" and parsed.hostname not in ("127.0.0.1", "localhost"):
        raise SyncError(f"refusing a non-https API: {parsed.scheme}://{parsed.hostname}")
    url = urllib.parse.urljoin(api, "/api/install") + "?" + urllib.parse.urlencode({"token": token})
    opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(url, timeout=30) as response:
            body = response.read(MAX_BYTES + 1)
    except urllib.error.HTTPError as error:
        message = ""
        try:
            message = json.loads(error.read(65536)).get("error", "")
        except (ValueError, AttributeError):
            pass
        raise SyncError(f"animations.dev answered {error.code}: {message}".rstrip(": ")) from None
    except urllib.error.URLError as error:
        raise SyncError(f"could not reach animations.dev: {error.reason}") from None
    if len(body) > MAX_BYTES:
        raise SyncError("the response is larger than expected")
    try:
        return json.loads(body)
    except ValueError:
        raise SyncError("the response is not JSON") from None


def parse(manifest):
    if not isinstance(manifest, dict) or not isinstance(manifest.get("skills"), list):
        raise SyncError("the response has no skill list")
    skills = {}
    for entry in manifest["skills"]:
        name = entry.get("name") if isinstance(entry, dict) else None
        if not isinstance(name, str) or not SKILL_NAME.fullmatch(name):
            raise SyncError(f"unsafe skill name {name!r}")
        files = entry.get("files")
        if not isinstance(files, list):
            raise SyncError(f"{name} has no file list")
        contents = {}
        for file in files:
            file_name = file.get("name") if isinstance(file, dict) else None
            content = file.get("content") if isinstance(file, dict) else None
            if not isinstance(file_name, str) or not FILE_NAME.fullmatch(file_name):
                raise SyncError(f"{name}: unsafe file name {file_name!r}")
            if not isinstance(content, str):
                raise SyncError(f"{name}/{file_name} has no text content")
            contents[file_name] = content
        if "SKILL.md" not in contents:
            raise SyncError(f"{name} has no SKILL.md")
        skills[name] = contents
    unavailable = [
        f"{item.get('id')}: {item.get('reason')}"
        for item in manifest.get("unavailable") or []
        if isinstance(item, dict)
    ]
    return skills, unavailable


def rename(skills, renames):
    for pair in renames:
        old, sep, new = pair.partition("=")
        if not sep or not SKILL_NAME.fullmatch(new):
            raise SyncError(f"bad --rename {pair!r}; expected old=new")
        if old not in skills:
            continue
        files = skills.pop(old)
        text, count = re.subn(rf"(?m)^name: {re.escape(old)}$", f"name: {new}", files["SKILL.md"], count=1)
        if count != 1:
            raise SyncError(f"{old}/SKILL.md does not declare name: {old}")
        files["SKILL.md"] = text
        skills[new] = files
    return skills


def read_tree(root):
    if not root.is_dir():
        return {}
    return {
        skill.name: {file.name: file.read_text() for file in sorted(skill.iterdir()) if file.is_file()}
        for skill in sorted(root.iterdir())
        if skill.is_dir()
    }


def diff(old, new):
    lines = []
    for name in sorted(old.keys() | new.keys()):
        for file in sorted(old.get(name, {}).keys() | new.get(name, {}).keys()):
            before = old.get(name, {}).get(file, "").splitlines(keepends=True)
            after = new.get(name, {}).get(file, "").splitlines(keepends=True)
            lines += difflib.unified_diff(before, after, f"current/{name}/{file}", f"new/{name}/{file}")
    return "".join(lines)


def confirm(tty, text):
    if tty is None:
        return False
    tty.write(text)
    tty.write("\nReplace the installed animations.dev skills with this? [y/N] ")
    tty.flush()
    return tty.readline().strip().lower() in ("y", "yes")


def install(dest, skills):
    dest.mkdir(mode=0o700, parents=True, exist_ok=True)
    staging = pathlib.Path(tempfile.mkdtemp(prefix=".new-", dir=dest))
    for name, files in skills.items():
        (staging / name).mkdir(mode=0o700)
        for file_name, content in files.items():
            (staging / name / file_name).write_text(content)
    current = dest / "current"
    previous = dest / ".previous"
    shutil.rmtree(previous, ignore_errors=True)
    if current.exists():
        current.rename(previous)
    staging.rename(current)
    shutil.rmtree(previous, ignore_errors=True)


def main(argv, stdin=sys.stdin, tty=None):
    parser = argparse.ArgumentParser(prog="animations-dev-sync", description=__doc__.splitlines()[0])
    parser.add_argument("--dest", required=True, type=pathlib.Path)
    parser.add_argument("--expected", required=True, help="comma-separated skill names Home Manager links")
    parser.add_argument("--api", default=DEFAULT_API)
    parser.add_argument("--rename", action="append", default=[], metavar="OLD=NEW", help="install a skill under another name")
    parser.add_argument("--yes", action="store_true", help="replace changed skills without asking")
    args = parser.parse_args(argv)
    expected = {name for name in args.expected.split(",") if name}

    try:
        token = stdin.read().strip()
        if not token:
            raise SyncError("no token on stdin; pipe it in from fnox")
        skills, unavailable = parse(fetch(args.api, token))
        del token
        skills = rename(skills, args.rename)
        for line in unavailable:
            print(f"animations-dev-sync: unavailable: {line}", file=sys.stderr)
        missing = sorted(expected - skills.keys())
        if missing:
            raise SyncError(f"the account does not provide: {', '.join(missing)}")
        extra = sorted(skills.keys() - expected)
        if extra:
            print(
                f"animations-dev-sync: also available, not linked by Home Manager: {', '.join(extra)}",
                file=sys.stderr,
            )
        current = read_tree(args.dest / "current")
        if current == skills:
            print("animations-dev-sync: already up to date", file=sys.stderr)
            return 0
        if current and not args.yes and not confirm(tty, diff(current, skills)):
            raise SyncError("the skills changed upstream; review the diff in a terminal or pass --yes")
        install(args.dest, skills)
        print(f"animations-dev-sync: installed {', '.join(sorted(skills))}", file=sys.stderr)
        return 0
    except SyncError as error:
        print(f"animations-dev-sync: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    try:
        terminal = open("/dev/tty", "r+")
    except OSError:
        terminal = None
    sys.exit(main(sys.argv[1:], tty=terminal))
