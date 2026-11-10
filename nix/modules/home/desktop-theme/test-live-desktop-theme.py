import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("audit", Path(__file__).with_name("audit-desktop-theme.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LiveTheme(unittest.TestCase):
    def test_detects_drift_and_broken_links_without_changing_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected = root / "generated"
            expected.write_text("Everforest")
            live = root / "live"
            live.write_text("Minimal")
            broken = root / "broken"
            broken.symlink_to(root / "absent")
            kde = root / "kdeglobals"
            kde.write_text("[Colors:Window]\nBackgroundNormal=255,255,255\n")
            settings = {"files": {str(live): str(expected), str(broken): str(expected)},
                        "kde": str(kde), "palette": {"Colors:Window": {"BackgroundNormal": "239,235,212"}},
                        "vaults": [], "appearance": {}}
            self.assertEqual(len(module.audit(settings)), 3)
            self.assertEqual(live.read_text(), "Minimal")
            self.assertTrue(broken.is_symlink())
            live.write_text("Everforest")
            broken.unlink()
            broken.symlink_to(expected)
            kde.write_text("[Colors:Window]\nBackgroundNormal=239,235,212\n")
            self.assertEqual(module.audit(settings), [])


if __name__ == "__main__":
    unittest.main()
