"""Run a script under test so it cannot reach the owner's credentials or hosts.

A test once ran the real `./install eltoro` because the real tools came back on
PATH ahead of its stubs, and its timeout killed only the outer shell, so the
deploy finished in the background. Every run here checks first, through the
same shell invocation and stdin, that each guarded tool is one of the test's
stubs, and kills everything the script started when it ends.
"""

import os
from pathlib import Path
import shutil
import signal
import subprocess

# Tools that reach the network, a host or a credential. Each run gets a stub for
# every one; a test replaces the stubs it needs to observe.
GUARDED = ("nixos-rebuild", "nix", "ssh", "sudo", "gh", "nix-env", "curl")
TOOLS = ("base64", "bash", "cat", "date", "dirname", "env", "grep", "jq", "kill",
         "mkdir", "mkfifo", "mktemp", "mv", "rm", "sleep", "touch", "tr")
UNEXPECTED = '#!/bin/sh\necho "unexpected call: ${0##*/} $*" >&2\nexit 97\n'
PROBE = 'for tool in ' + " ".join(GUARDED) + '; do printf "%s=%s\\n" "$tool" "$(command -v "$tool")"; done\n'


def hermetic_env(home, bin_dir):
    tools = Path(home) / "tools"
    tools.mkdir()
    for name in TOOLS:
        if path := shutil.which(name):
            (tools / name).symlink_to(path)
    for name in GUARDED:
        stub = Path(bin_dir) / name
        if not stub.exists():
            stub.write_text(UNEXPECTED)
            stub.chmod(0o755)
    # A top-level `bash -c` whose stdin is a socket sources /etc/bashrc and
    # ~/.bashrc, as if started by sshd, and on NixOS and under the Nix installer
    # on macOS those put the real tools first on PATH. Bash does that only when
    # SHLVL is unset or 0, so 1 skips it on every platform.
    return {"HOME": str(home), "PATH": f"{bin_dir}:{tools}", "TMPDIR": str(home), "SHLVL": "1"}


def check_stubs(args, env, bin_dir, stdin):
    if args[:2] == ["bash", "-c"]:
        probe = ["bash", "-c", PROBE]
    else:
        probe_file = Path(env["HOME"]) / "probe-guarded-tools"
        probe_file.write_text(PROBE)
        probe = [args[0], str(probe_file)]
    result = subprocess.run(probe, env=env, stdin=stdin, text=True, capture_output=True, timeout=10)
    for line in result.stdout.splitlines():
        tool, _, path = line.partition("=")
        if Path(path).parent != Path(bin_dir):
            raise AssertionError(f"{tool} resolves to {path or 'nothing'}, not a stub in {bin_dir}")


def kill_session(session):
    # A script can move a job into its own group with `set -m`, as install's
    # macOS activation does, so on Linux sweep the whole session too.
    try:
        os.killpg(session, signal.SIGKILL)
    except ProcessLookupError:
        pass
    for stat in Path("/proc").glob("[0-9]*/stat"):
        try:
            fields = stat.read_text().rsplit(")", 1)[1].split()
            if int(fields[3]) == session:
                os.kill(int(stat.parent.name), signal.SIGKILL)
        except (OSError, IndexError, ValueError):
            pass


def start(args, env, bin_dir, stdin=subprocess.DEVNULL, **kwargs):
    check_stubs(args, env, bin_dir, stdin)
    return subprocess.Popen(args, env=env, stdin=stdin, start_new_session=True, text=True, **kwargs)


def run(args, env, bin_dir, stdin=subprocess.DEVNULL, timeout=10):
    process = start(args, env, bin_dir, stdin, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        kill_session(process.pid)
        process.communicate()
        raise
    kill_session(process.pid)
    return subprocess.CompletedProcess(args, process.returncode, stdout, stderr)
