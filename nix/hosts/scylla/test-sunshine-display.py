import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("sunshine-kscreen-doctor.sh")
HYPRLAND = [{
    "id": 0, "name": "DP-2", "width": 3440, "height": 1440,
    "refreshRate": 99.982, "x": -3440, "y": 0, "scale": 1.25,
    "transform": 0, "disabled": False,
    "availableModes": ["3440x1440@99.98Hz", "3440x1440@59.97Hz", "1920x1080@59.94Hz", "1920x1080@60.00Hz"],
}]
KDE = {"outputs": [{
    "id": 1, "name": "DP-2", "connected": True, "enabled": True,
    "priority": 1, "currentModeId": "native",
    "modes": [
        {"id": "native", "size": {"width": 3440, "height": 1440}, "refreshRate": 99.982},
        {"id": "1080p", "size": {"width": 1920, "height": 1080}, "refreshRate": 60},
    ],
}]}


class DisplayCommands(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                        XDG_STATE_HOME=str(self.root / "state"),
                        XDG_CURRENT_DESKTOP="Hyprland", HYPRLAND_INSTANCE_SIGNATURE="test",
                        SUNSHINE_CLIENT_WIDTH="1920", SUNSHINE_CLIENT_HEIGHT="1080",
                        SUNSHINE_CLIENT_FPS="60", DISPLAY_TEST_ROOT=str(self.root))
        (self.root / "hyprland.json").write_text(json.dumps(HYPRLAND))
        (self.root / "kde.json").write_text(json.dumps(KDE))
        hyprctl = self.root / "hyprctl"
        hyprctl.write_text(f"#!{sys.executable}\n" + '''
import json
import os
from pathlib import Path
import re
import sys

root = Path(os.environ["DISPLAY_TEST_ROOT"])
state_file = root / "hyprland.json"
if sys.argv[1] == "-j":
    print(state_file.read_text())
else:
    with (root / "applied").open("a") as log:
        log.write(" ".join(sys.argv[1:]) + "\\n")
    output = re.search(r'output = "([^"]+)"', sys.argv[2]).group(1)
    mode = re.search(r'mode = "([0-9]+)x([0-9]+)@([0-9.]+)"', sys.argv[2])
    state = json.loads(state_file.read_text())
    for monitor in state:
        if monitor["name"] == output:
            monitor.update(width=int(mode[1]), height=int(mode[2]), refreshRate=float(mode[3]))
    state_file.write_text(json.dumps(state))
    print("ok")
''')
        hyprctl.chmod(0o755)
        self.tool("kscreen-doctor", "echo 'KScreen must not run under Hyprland' >&2; exit 1")

    def tool(self, name, body):
        path = self.root / name
        path.write_text(f"#!{shutil.which('bash')}\nset -euo pipefail\n" + body)
        path.chmod(0o755)

    def run_script(self, *args):
        return subprocess.run(["bash", str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True, timeout=15)

    def test_hyprland_resolves_closest_supported_refresh(self):
        result = self.run_script("resolve", "0", "1920", "1080", "60")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(float(result.stdout.strip()), 60)

    def test_hyprland_switches_and_restores_without_changing_geometry(self):
        pushed = self.run_script("push-client")
        self.assertEqual(pushed.returncode, 0, pushed.stderr)
        popped = self.run_script("pop")
        self.assertEqual(popped.returncode, 0, popped.stderr)
        self.assertEqual((self.root / "applied").read_text().splitlines(), [
            'eval hl.monitor({ output = "DP-2", mode = "1920x1080@60.00", position = "-3440x0", scale = 1.25, transform = 0 })',
            'eval hl.monitor({ output = "DP-2", mode = "3440x1440@99.98", position = "-3440x0", scale = 1.25, transform = 0 })',
        ])
        self.assertEqual((self.root / "state/sunshine-kscreen-doctor/hyprland/DP-2.stack").read_text(), "")

    def test_nested_pushes_restore_each_previous_mode(self):
        self.assertEqual(self.run_script("push-client").returncode, 0)
        self.env.update(SUNSHINE_CLIENT_WIDTH="3440", SUNSHINE_CLIENT_HEIGHT="1440")
        self.assertEqual(self.run_script("push-client").returncode, 0)
        self.assertEqual(self.run_script("pop").returncode, 0)
        state = json.loads((self.root / "hyprland.json").read_text())[0]
        self.assertEqual((state["width"], state["height"], state["refreshRate"]), (1920, 1080, 60))
        self.assertEqual(self.run_script("pop").returncode, 0)
        state = json.loads((self.root / "hyprland.json").read_text())[0]
        self.assertEqual((state["width"], state["height"], state["refreshRate"]), (3440, 1440, 99.98))

    def test_kde_uses_kscreen_even_with_a_stale_hyprland_signature(self):
        self.env["XDG_CURRENT_DESKTOP"] = "KDE"
        self.tool("hyprctl", "echo 'Hyprland must not run under KDE' >&2; exit 1")
        self.tool("kscreen-doctor", '''
if [ "$1" = "--json" ]; then
    cat "$DISPLAY_TEST_ROOT/kde.json"
else
    printf '%s\\n' "$*" >> "$DISPLAY_TEST_ROOT/applied"
fi
''')
        for command in ("push-client", "pop"):
            result = self.run_script(command)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "applied").read_text().splitlines(), [
            "output.DP-2.mode.1080p", "output.DP-2.mode.native",
        ])
        self.assertEqual((self.root / "state/sunshine-kscreen-doctor/DP-2.stack").read_text(), "")

    def test_hyprland_does_not_consume_kde_restore_stack(self):
        stack = self.root / "state/sunshine-kscreen-doctor/DP-2.stack"
        stack.parent.mkdir(parents=True)
        stack.write_text("1920 1080 60\n")
        result = self.run_script("pop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(stack.read_text(), "1920 1080 60\n")
        self.assertFalse((self.root / "applied").exists())

    def test_missing_desktop_falls_back_to_hyprland_signature(self):
        self.env.pop("XDG_CURRENT_DESKTOP")
        result = self.run_script("resolve", "DP-2", "1920", "1080", "60")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unsupported_desktop_fails_without_using_kscreen(self):
        self.env["XDG_CURRENT_DESKTOP"] = "GNOME"
        result = self.run_script("push-client")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported desktop", result.stderr)

    def test_failed_restore_retains_saved_mode(self):
        result = self.run_script("push-client")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.tool("hyprctl", '''
if [ "$1" = "-j" ]; then
    cat "$DISPLAY_TEST_ROOT/hyprland.json"
else
    exit 1
fi
''')
        result = self.run_script("pop")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / "state/sunshine-kscreen-doctor/hyprland/DP-2.stack").read_text(),
                         "3440 1440 99.982\n")

    def test_display_query_is_bounded(self):
        self.tool("hyprctl", "sleep 30")
        result = self.run_script("push-client")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("could not auto-detect", result.stderr)

    def test_unsupported_resolution_does_not_apply_a_mode(self):
        result = self.run_script("mode", "DP-2", "9999", "9999", "60")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no supported mode", result.stderr)
        self.assertFalse((self.root / "applied").exists())


if __name__ == "__main__":
    unittest.main()
