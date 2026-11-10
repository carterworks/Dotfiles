from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tests"))
from hermetic import hermetic_env, run  # noqa: E402

REVISION = "0123456789abcdef0123456789abcdef01234567"
SSH = '''#!/bin/sh
printf '%s\\n' "$*" >> "$STATE/ssh.log"
for target; do
  if [ -f "$STATE/running-$target" ]; then
    cat "$STATE/running-$target"
    exit 0
  fi
done
echo "ssh: connect to host: Connection timed out" >&2
exit 255
'''
NIX = '''#!/bin/sh
printf '%s\\n' "$*" >> "$STATE/nix.log"
case "$*" in
  *metadata*) printf '{"revision":"%s"}\\n' "$REVISION" ;;
  *eval*)
    for arg; do
      case "$arg" in
        *'#nixosConfigurations.'*)
          host=${arg#*#nixosConfigurations.}
          host=${host%%.*}
          [ -f "$STATE/expected-$host" ] || { echo "error: eval failed" >&2; exit 1; }
          printf '%s' "$(cat "$STATE/expected-$host")"
          ;;
      esac
    done
    ;;
  *) exit 2 ;;
esac
'''


class DriftTests(unittest.TestCase):
    def run_drift(self, args=(), running=None, expected=None, env=None):
        with tempfile.TemporaryDirectory() as state:
            state = Path(state)
            bin_dir = state / "bin"
            bin_dir.mkdir()
            for name, body in (("ssh", SSH), ("nix", NIX)):
                (bin_dir / name).write_text(body)
                (bin_dir / name).chmod(0o755)
            for target, (path, activated, *failed) in (running or {}).items():
                (state / f"running-{target}").write_text(f"{path}\n{activated}\n{failed[0] if failed else 0}\n")
            for host, path in (expected or {}).items():
                (state / f"expected-{host}").write_text(path)
            script_env = {
                **hermetic_env(state, bin_dir),
                "STATE": str(state),
                "REVISION": REVISION,
                "TZ": "UTC",
                **(env or {}),
            }
            result = run(["bash", str(ROOT / "drift"), *args], script_env, bin_dir)
            result.nix = (state / "nix.log").read_text().splitlines()
            ssh_log = state / "ssh.log"
            result.ssh = ssh_log.read_text().splitlines() if ssh_log.exists() else []
            return result

    def line(self, result, host):
        return next(line for line in result.stdout.splitlines() if line.split()[:1] == [host])

    def test_reports_each_host_and_keeps_going_past_an_unreachable_one(self):
        result = self.run_drift(
            running={
                "scylla": ("/nix/store/aaa-scylla", 1794266337),
                "carter@prostagma": ("/nix/store/old-prostagma", 1794000000),
            },
            expected={
                "scylla": "/nix/store/aaa-scylla",
                "prostagma": "/nix/store/new-prostagma",
                "eltoro": "/nix/store/new-eltoro",
            },
        )
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("in sync", self.line(result, "scylla"))
        self.assertIn("2026-11-09 23:18", self.line(result, "scylla"))
        self.assertIn("behind", self.line(result, "prostagma"))
        self.assertIn("2026-11-06 21:20", self.line(result, "prostagma"))
        self.assertIn("unreachable", self.line(result, "eltoro"))
        self.assertIn("not checked", self.line(result, "mac"))

    def test_all_in_sync_exits_zero(self):
        result = self.run_drift(
            running={
                "scylla": ("/nix/store/a", 1),
                "carter@prostagma": ("/nix/store/b", 1),
                "root@eltoro": ("/nix/store/c", 1),
            },
            expected={"scylla": "/nix/store/a", "prostagma": "/nix/store/b", "eltoro": "/nix/store/c"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        for host in ("scylla", "prostagma", "eltoro"):
            self.assertIn("in sync", self.line(result, host))

    def test_failed_units_are_shown_and_fail_the_run(self):
        result = self.run_drift(
            running={
                "scylla": ("/nix/store/a", 1, 0),
                "carter@prostagma": ("/nix/store/b", 1, 2),
                "root@eltoro": ("/nix/store/old-c", 1, 1),
            },
            expected={"scylla": "/nix/store/a", "prostagma": "/nix/store/b", "eltoro": "/nix/store/c"},
        )
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotIn("FAILED", self.line(result, "scylla"))
        self.assertIn("in sync", self.line(result, "prostagma"))
        self.assertIn("FAILED UNITS: 2", self.line(result, "prostagma"))
        self.assertIn("behind", self.line(result, "eltoro"))
        self.assertIn("FAILED UNITS: 1", self.line(result, "eltoro"))

    def test_an_unreachable_host_shows_no_unit_count(self):
        result = self.run_drift(
            running={"scylla": ("/nix/store/a", 1, 0), "carter@prostagma": ("/nix/store/b", 1, 0)},
            expected={"scylla": "/nix/store/a", "prostagma": "/nix/store/b", "eltoro": "/nix/store/c"},
        )
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("unreachable", self.line(result, "eltoro"))
        self.assertNotIn("FAILED", self.line(result, "eltoro"))

    def test_compares_every_host_with_one_revision_of_the_ref(self):
        result = self.run_drift(["main"])
        self.assertIn("github:carterworks/dotfiles/main", result.nix[0])
        self.assertIn(REVISION[:12], result.stdout)
        evals = result.nix[1:]
        self.assertEqual(len(evals), 3)
        for host, call in zip(("scylla", "prostagma", "eltoro"), evals):
            self.assertIn(f"github:carterworks/dotfiles/{REVISION}#nixosConfigurations.{host}.", call)

    def test_defaults_to_release(self):
        result = self.run_drift()
        self.assertIn("github:carterworks/dotfiles/release", result.nix[0])

    def test_evaluation_failure_is_reported_per_host(self):
        result = self.run_drift(
            running={"scylla": ("/nix/store/a", 1), "root@eltoro": ("/nix/store/c", 1)},
            expected={"scylla": "/nix/store/a", "eltoro": "/nix/store/c"},
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("evaluation failed", self.line(result, "prostagma"))
        self.assertIn("in sync", self.line(result, "eltoro"))

    def test_ssh_targets_can_be_overridden(self):
        result = self.run_drift(
            expected={"scylla": "/a", "prostagma": "/b", "eltoro": "/c"},
            env={"PROSTAGMA_HOST": "admin@p", "ELTORO_HOST": "admin@e"},
        )
        self.assertEqual(len(result.ssh), 3)
        for target, call in zip(("scylla", "admin@p", "admin@e"), result.ssh):
            self.assertIn(f" {target} ", call)
            self.assertTrue(call.endswith(
                "readlink /run/current-system; stat -c %Y /run/current-system; systemctl --failed --no-legend | wc -l"
            ), call)


if __name__ == "__main__":
    unittest.main()
