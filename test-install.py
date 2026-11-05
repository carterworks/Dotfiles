import os
import signal
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parent
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
        env = {**os.environ, "HOME": home, "PATH": f"{bin_dir}:{os.environ['PATH']}"}
        if not wait:
            return subprocess.Popen(
                args, env=env, start_new_session=True,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        return subprocess.run(args, env=env, text=True, capture_output=True, timeout=10)

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

    def test_activation_survives_installer_process_group_termination(self):
        with tempfile.TemporaryDirectory() as home:
            installer = self.run_script(
                MOCK_SUDO + 'run_darwin_activation "$HOME/system with spaces"\n',
                home, activate="echo started; sleep 1; echo finished", wait=False,
            )
            log_dir = Path(home) / "Library/Logs/dotfiles-install"
            deadline = time.monotonic() + 5
            while not any("started" in log.read_text() for log in log_dir.glob("*/activate.log")):
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.05)
            os.killpg(installer.pid, signal.SIGTERM)
            installer.wait(timeout=5)
            status = next(log_dir.glob("*")) / "status"
            while not status.exists():
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.05)
            self.assertEqual(status.read_text(), "0\n")
            self.assertIn("finished", (status.parent / "activate.log").read_text())


if __name__ == "__main__":
    unittest.main()
