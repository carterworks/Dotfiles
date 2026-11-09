import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
SCRIPT = ROOT / "install-eltoro"


class InstallEltoroTests(unittest.TestCase):
    def run_script(self, args=(), env=None):
        with tempfile.TemporaryDirectory() as temp:
            bin_dir = Path(temp) / "bin"
            bin_dir.mkdir()
            (bin_dir / "nixos-rebuild").write_text('#!/bin/sh\nprintf \'%s\\n\' "$@"\n')
            (bin_dir / "nixos-rebuild").chmod(0o755)
            (bin_dir / "gh").write_text('#!/bin/sh\nexit 1\n')
            (bin_dir / "gh").chmod(0o755)
            script_env = {
                **os.environ,
                "PATH": f"{bin_dir}:{os.environ['PATH']}",
            }
            script_env.pop("ELTORO_HOST", None)
            script_env.update(env or {})
            return subprocess.run(
                ["bash", str(SCRIPT), *args],
                env=script_env,
                text=True,
                capture_output=True,
                timeout=10,
            )

    def test_defaults_to_switch_on_eltoro(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            ["--flake", f"{ROOT}#eltoro", "--target-host", "root@eltoro", "switch"],
        )

    def test_explicit_action_is_kept(self):
        result = self.run_script(["dry-run"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[-1], "dry-run")
        self.assertNotIn("switch", result.stdout.splitlines())

    def test_target_host_can_be_overridden(self):
        result = self.run_script(env={"ELTORO_HOST": "root@example"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("root@example", result.stdout.splitlines())


if __name__ == "__main__":
    unittest.main()
