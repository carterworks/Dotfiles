import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("apply-obsidian-theme.py")


class ObsidianTheme(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.vault = self.root / "Notes"
        self.settings = self.vault / ".obsidian" / "appearance.json"
        self.settings.parent.mkdir(parents=True)
        self.original = {"cssTheme": "Minimal", "interfaceFontFamily": "Inter",
                         "enabledCssSnippets": ["custom"], "theme": "obsidian"}
        self.settings.write_text(json.dumps(self.original))
        self.config = self.root / "config.json"
        self.config.write_text(json.dumps({"vaults": [str(self.vault)],
                                          "appearance": {"cssTheme": "Everforest", "theme": "moonstone"}}))

    def run_script(self):
        return subprocess.run([sys.executable, str(SCRIPT), str(self.config)],
                              capture_output=True, text=True)

    def test_preserves_other_settings_and_keeps_backup(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.settings.read_text()),
                         self.original | {"cssTheme": "Everforest", "theme": "moonstone"})
        backup = self.settings.with_suffix(".json.before-desktop-theme")
        self.assertEqual(json.loads(backup.read_text()), self.original)
        before = self.settings.stat().st_mtime_ns
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.settings.stat().st_mtime_ns, before)
        self.assertEqual(json.loads(backup.read_text()), self.original)

    def test_does_not_create_missing_vault(self):
        missing = self.root / "Missing"
        self.config.write_text(json.dumps({"vaults": [str(missing)], "appearance": {"cssTheme": "Everforest"}}))
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(missing.exists())

    def test_rejects_bad_settings_without_overwriting(self):
        for content in ["not json", "[]"]:
            with self.subTest(content=content):
                self.settings.write_text(content)
                result = self.run_script()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.settings.read_text(), content)

    def test_new_selection_does_not_replace_backup(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.config.write_text(json.dumps({"vaults": [str(self.vault)],
                                          "appearance": {"cssTheme": "Another Theme", "theme": "moonstone"}}))
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.settings.read_text())["cssTheme"], "Another Theme")
        self.assertEqual(json.loads(self.settings.with_suffix(".json.before-desktop-theme").read_text()), self.original)


if __name__ == "__main__":
    unittest.main()
