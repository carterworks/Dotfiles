import configparser
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("apply-kde-theme.py")


class KdeTheme(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.original = "[KFileDialog Settings]\nShow hidden files=true\n[General]\nColorSchemeHash=stale\n[Colors:Window]\nBackgroundNormal=239,240,241\n"
        self.base = self.root / "base"
        self.base.write_text(self.original)
        self.live = self.root / "config/kdeglobals"
        self.live.parent.mkdir()
        self.live.symlink_to(self.base)
        self.scheme = self.root / "everforest.colors"
        self.scheme.write_text("[General]\nName=Everforest\n[Colors:Window]\nBackgroundNormal=239,235,212\nForegroundNormal=92,106,114\n")

    def run_script(self):
        return subprocess.run([sys.executable, str(SCRIPT), str(self.live), str(self.scheme),
                               "everforest-light-medium", str(self.base)], capture_output=True, text=True)

    def test_applies_palette_without_editing_source_or_other_settings(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        config = configparser.ConfigParser()
        config.read(self.live)
        self.assertEqual(config["Colors:Window"]["BackgroundNormal"], "239,235,212")
        self.assertEqual(config["General"]["ColorScheme"], "everforest-light-medium")
        self.assertNotIn("ColorSchemeHash", config["General"])
        self.assertEqual(config["KFileDialog Settings"]["Show hidden files"], "true")
        self.assertEqual(config["Icons"]["Theme"], "Papirus")
        self.assertEqual(self.base.read_text(), self.original)
        self.assertFalse(self.live.is_symlink())
        self.assertEqual(self.live.with_suffix(".before-desktop-theme").read_text(), self.original)
        before = self.live.stat().st_mtime_ns
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.live.stat().st_mtime_ns, before)

    def test_missing_config_uses_base(self):
        self.live.unlink()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertIn("Show hidden files = true", self.live.read_text())

    def test_invalid_config_is_not_overwritten(self):
        self.live.unlink()
        self.live.write_text("not an INI file")
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.live.read_text(), "not an INI file")


if __name__ == "__main__":
    unittest.main()
