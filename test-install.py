import os
import signal
import socket
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tests"))
from hermetic import hermetic_env, kill_session, run, start  # noqa: E402

FUNCTIONS = (ROOT / "install").read_text().split('\ncd "${BASEDIR}"\n')[0]
FUNCTIONS = 'set -euo pipefail\nBASEDIR="$HOME"\nNIX_ACCESS_TOKEN_ARGS=()\n' + FUNCTIONS.split(
    "NIX_ACCESS_TOKEN_ARGS=()", 1
)[1]
MOCK_SUDO = '''
sudo() {
  [[ "$1" == -H ]] || return 1
  shift
  "$@"
}
'''
NIX_ENV = '''#!/bin/sh
printf 'nix-env %s\\n' "$*"
'''


class HermeticTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name)
        self.bin_dir = self.home / "bin"
        self.bin_dir.mkdir()
        self.env = hermetic_env(self.home, self.bin_dir)
        self.marker = self.home / "script-ran"

    def test_stubs_stay_first_on_path_when_stdin_is_a_socket(self):
        stdin, _ = socket.socketpair()
        result = run(["bash", "-c", "command -v nixos-rebuild"], self.env, self.bin_dir, stdin=stdin)
        self.assertEqual(result.stdout.strip(), str(self.bin_dir / "nixos-rebuild"))

    def test_script_does_not_run_when_a_guarded_tool_is_not_a_stub(self):
        decoy = self.home / "decoy"
        decoy.mkdir()
        (decoy / "ssh").write_text("#!/bin/sh\n")
        (decoy / "ssh").chmod(0o755)
        script = self.home / "script"
        script.write_text(f'touch "{self.marker}"\n')
        env = {**self.env, "PATH": f"{decoy}:{self.env['PATH']}"}
        for args in (["bash", str(script)], ["bash", "-c", f'touch "{self.marker}"']):
            with self.subTest(args=args[:2]):
                with self.assertRaisesRegex(AssertionError, "ssh resolves to"):
                    run(args, env, self.bin_dir)
                self.assertFalse(self.marker.exists())

    @unittest.skipUnless(Path("/etc/set-environment").exists(), "needs NixOS's system bashrc")
    def test_script_does_not_run_when_the_system_bashrc_restores_path(self):
        env = {**self.env}
        del env["NOSYSBASHRC"]
        stdin, _ = socket.socketpair()
        with self.assertRaisesRegex(AssertionError, "resolves to"):
            run(["bash", "-c", f'touch "{self.marker}"'], env, self.bin_dir, stdin=stdin)
        self.assertFalse(self.marker.exists())

    def test_nothing_the_script_started_outlives_a_timeout(self):
        group, session = self.home / "group", self.home / "session"
        with self.assertRaises(subprocess.TimeoutExpired):
            run(["bash", "-c", f'(sleep 1; touch "{group}") & set -m; (sleep 1; touch "{session}") & sleep 30'],
                self.env, self.bin_dir, timeout=0.3)
        time.sleep(1.5)
        self.assertFalse(group.exists())
        if Path("/proc/self/stat").exists():
            self.assertFalse(session.exists())

    def test_nothing_the_script_started_outlives_it(self):
        run(["bash", "-c", f'(sleep 1; touch "{self.marker}") >/dev/null 2>&1 & exit 0'], self.env, self.bin_dir)
        time.sleep(1.5)
        self.assertFalse(self.marker.exists())


class DarwinRebuildTests(unittest.TestCase):
    def run_script(self, script, home, activate="echo activated", wait=True):
        bin_dir = Path(home) / "bin"
        bin_dir.mkdir()
        (bin_dir / "nix-env").write_text(NIX_ENV)
        (bin_dir / "nix-env").chmod(0o755)
        rebuild = Path(home) / "system with spaces/sw/bin/darwin-rebuild"
        rebuild.parent.mkdir(parents=True)
        rebuild.write_text(f'#!/bin/sh\ntest "$1" = activate || exit 8\n{activate}\n')
        rebuild.chmod(0o755)
        args = ["bash", "-c", "nix() { :; }\n" + FUNCTIONS + script]
        env = hermetic_env(home, bin_dir)
        if not wait:
            return start(args, env, bin_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return run(args, env, bin_dir)

    def test_darwin_builds_as_user_then_activates(self):
        with tempfile.TemporaryDirectory() as home:
            result = self.run_script('''
uname() { echo Darwin; }
current_machine_name() { echo Test-Mac; }
authenticate_sudo() { :; }
sudo() { echo "unexpected sudo $*"; }
run_with_nix_progress() { printf 'built:%s\\n' "$*" >&2; echo /nix/store/system; }
run_darwin_activation() { printf 'activate:%s\\n' "$*"; }
run_rebuild
''', home)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('built:Building system nix build', result.stderr)
            self.assertIn('darwinConfigurations."Test-Mac".system', result.stderr)
            self.assertEqual(result.stdout, "activate:/nix/store/system\n")

    def test_activation_sets_profile_activates_and_returns_status(self):
        with tempfile.TemporaryDirectory() as home:
            result = self.run_script(MOCK_SUDO + '''
run_darwin_activation "$HOME/system with spaces"
''', home, activate="echo activated; exit 7")
            self.assertEqual(result.returncode, 7, result.stderr)
            log = next(Path(home).glob("Library/Logs/dotfiles-install/*/activate.log"))
            self.assertEqual(
                log.read_text(),
                f"nix-env -p /nix/var/nix/profiles/system --set {home}/system with spaces\nactivated\n",
            )
            self.assertEqual((log.parent / "status").read_text(), "7\n")
            self.assertIn("activated", result.stdout)

    def test_output_arrives_before_activation_completes(self):
        with tempfile.TemporaryDirectory() as home:
            result = self.run_script(MOCK_SUDO + '''
run_darwin_activation "$HOME/system with spaces" | while IFS= read -r line; do
  if [[ "$line" == live-output ]]; then
    touch "$HOME/observed"
  fi
done
''', home, activate=f'''echo live-output
for attempt in 1 2 3 4 5; do
  test ! -f "{home}/observed" || exit 0
  sleep 1
done
exit 9''')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((Path(home) / "observed").exists())

    def test_log_follower_preserves_partial_and_final_lines(self):
        with tempfile.TemporaryDirectory() as home:
            result = self.run_script('''
touch "$HOME/log"
(
  printf hel >> "$HOME/log"
  sleep 0.2
  printf 'lo\\nlast' >> "$HOME/log"
  touch "$HOME/status"
) &
follow_rebuild_log "$HOME/log" "$HOME/status"
wait
''', home)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "hello\nlast\n")

    def test_sudo_failure_is_reported_without_waiting(self):
        with tempfile.TemporaryDirectory() as home:
            result = self.run_script('''
sudo() { return 9; }
run_darwin_activation "$HOME/system with spaces"
''', home)
            self.assertEqual(result.returncode, 9, result.stderr)

    def start_activation(self, home, activate):
        installer = self.run_script(
            MOCK_SUDO + 'run_darwin_activation "$HOME/system with spaces"\n',
            home, activate=activate, wait=False,
        )
        self.addCleanup(kill_session, installer.pid)
        log_dir = Path(home) / "Library/Logs/dotfiles-install"
        self.wait_until(lambda: any("started" in log.read_text() for log in log_dir.glob("*/activate.log")))
        return installer, next(log_dir.glob("*"))

    def wait_until(self, condition):
        deadline = time.monotonic() + 5
        while not condition():
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.05)

    def assert_activation_completes(self, state_dir):
        status = state_dir / "status"
        self.wait_until(status.exists)
        self.assertEqual(status.read_text(), "0\n")
        self.assertIn("finished", (state_dir / "activate.log").read_text())

    def test_activation_survives_installer_process_group_termination(self):
        for sig in (signal.SIGTERM, signal.SIGKILL):
            with self.subTest(signal=sig.name), tempfile.TemporaryDirectory() as home:
                installer, state_dir = self.start_activation(home, "echo started; sleep 1; echo finished")
                os.killpg(installer.pid, sig)
                installer.wait(timeout=5)
                self.assert_activation_completes(state_dir)

    def test_activation_ignores_hangup_interrupt_and_termination(self):
        with tempfile.TemporaryDirectory() as home:
            pid_file = Path(home) / "activation.pid"
            installer, state_dir = self.start_activation(
                home, f'echo $$ > "{pid_file}"; echo started; sleep 1; echo finished'
            )
            activation_group = os.getpgid(int(pid_file.read_text()))
            self.assertNotEqual(activation_group, installer.pid)
            for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
                os.killpg(activation_group, sig)
            self.assert_activation_completes(state_dir)
            self.assertEqual(installer.wait(timeout=5), 0)


class DeployTests(unittest.TestCase):
    def run_script(self, args=(), env=None):
        with tempfile.TemporaryDirectory() as temp:
            bin_dir = Path(temp) / "bin"
            bin_dir.mkdir()
            calls = Path(temp) / "calls"
            stubs = {
                "nixos-rebuild": f'printf "%s\\n" "$@" > "{calls}"',
                "nix": "exit 0",
                "hostname": "echo localhost",
                "uname": "echo Plan9",
            }
            for name, body in stubs.items():
                (bin_dir / name).write_text(f"#!/bin/sh\n{body}\n")
                (bin_dir / name).chmod(0o755)
            script_env = {**hermetic_env(temp, bin_dir), **(env or {})}
            result = run(["bash", str(ROOT / "install"), *args], script_env, bin_dir)
            result.rebuild = None
            if calls.exists():
                rebuild = calls.read_text().splitlines()
                # Progress reporting adds `--option json-log-path <fifo>` when jq is on PATH.
                if "json-log-path" in rebuild:
                    index = rebuild.index("json-log-path")
                    del rebuild[index - 1:index + 2]
                result.rebuild = rebuild
            return result

    def test_no_host_installs_the_local_machine(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn("Unsupported system: Plan9", result.stderr)
        self.assertIsNone(result.rebuild)

    def test_eltoro_switches_as_root(self):
        result = self.run_script(["eltoro"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.rebuild, [
            "--flake", f"{ROOT}#eltoro", "--target-host", "root@eltoro",
            "--use-substitutes", "switch",
        ])

    def test_prostagma_switches_as_carter_with_sudo(self):
        result = self.run_script(["prostagma"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.rebuild, [
            "--flake", f"{ROOT}#prostagma", "--target-host", "carter@prostagma",
            "--use-substitutes", "--sudo", "switch",
        ])

    def test_explicit_action_and_flags_are_passed_through(self):
        result = self.run_script(["eltoro", "dry-activate", "--show-trace"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.rebuild[-2:], ["dry-activate", "--show-trace"])
        self.assertNotIn("switch", result.rebuild)

    def test_flags_alone_still_switch(self):
        result = self.run_script(["eltoro", "--show-trace"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.rebuild[-2:], ["--show-trace", "switch"])

    def test_target_can_be_overridden_per_host(self):
        for host, variable in (("eltoro", "ELTORO_HOST"), ("prostagma", "PROSTAGMA_HOST")):
            with self.subTest(host=host):
                result = self.run_script([host], env={variable: "admin@example"})
                self.assertEqual(result.returncode, 0, result.stderr)
                target = result.rebuild.index("--target-host") + 1
                self.assertEqual(result.rebuild[target], "admin@example")

    def test_unknown_host_is_refused(self):
        result = self.run_script(["nowhere"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nowhere", result.stderr)
        self.assertIsNone(result.rebuild)


if __name__ == "__main__":
    unittest.main()
