import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("apply-kde-config.py")


class ApplyKdeConfig(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.config = self.root / "config"
        self.config.mkdir()

    def source(self, name, text):
        path = self.repo / name
        path.write_text(text)
        return path

    def run_script(self, *args):
        result = subprocess.run([sys.executable, str(SCRIPT), *map(str, args)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def test_merge_creates_a_missing_file_with_private_permissions(self):
        source = self.source("kwinrc", "[Windows]\nFocusPolicy=FocusFollowsMouse\n")
        live = self.config / "kwinrc"
        self.run_script("merge", source, live)
        self.assertEqual(live.read_text(), "[Windows]\nFocusPolicy=FocusFollowsMouse\n")
        self.assertEqual(live.stat().st_mode & 0o777, 0o600)

    def test_merge_sets_listed_keys_and_keeps_everything_else(self):
        source = self.source(
            "dolphinrc",
            "# comment\n[MainWindow]\nMenuBar=Disabled\n\n[IconsMode]\nPreviewSize=256\n",
        )
        live = self.config / "dolphinrc"
        live.write_text(
            "[General]\nVersion=202\n\n[MainWindow]\nMenuBar=Enabled\nToolBarsMovable=Disabled\n\n"
            "[Recent Files]\nFile1[$e]=$HOME/a.pdf\n"
        )
        self.run_script("merge", source, live)
        self.assertEqual(
            live.read_text(),
            "[General]\nVersion=202\n\n[MainWindow]\nMenuBar=Disabled\nToolBarsMovable=Disabled\n\n"
            "[Recent Files]\nFile1[$e]=$HOME/a.pdf\n\n[IconsMode]\nPreviewSize=256\n",
        )

    def test_merge_adds_a_missing_key_to_an_existing_group(self):
        source = self.source("kwinrc", "[Windows]\nPlacement=Smart\n")
        live = self.config / "kwinrc"
        live.write_text("[Windows]\nFocusPolicy=ClickToFocus\n\n[Xwayland]\nScale=1\n")
        self.run_script("merge", source, live)
        self.assertEqual(
            live.read_text(),
            "[Windows]\nFocusPolicy=ClickToFocus\nPlacement=Smart\n\n[Xwayland]\nScale=1\n",
        )

    def test_merge_keeps_nested_groups_suffixed_keys_and_values_with_equals(self):
        source = self.source(
            "appletsrc",
            "[Containments][74][General]\nAppletOrder=92;78\n[Shortcuts]\nKeyBindings=Meta+Alt+,\n"
            "[kwin]\nKrohnkiteFocusPrev=Meta+\\\\,,none,Krohnkite: Focus Previous\nName[$e]=a=b\n",
        )
        live = self.config / "appletsrc"
        live.write_text("[Containments][74][General]\nAppletOrder=1\n[Containments][74]\nplugin=org.kde.panel\n")
        self.run_script("merge", source, live)
        self.assertEqual(
            live.read_text(),
            "[Containments][74][General]\nAppletOrder=92;78\n[Containments][74]\nplugin=org.kde.panel\n\n"
            "[Shortcuts]\nKeyBindings=Meta+Alt+,\n\n"
            "[kwin]\nKrohnkiteFocusPrev=Meta+\\\\,,none,Krohnkite: Focus Previous\nName[$e]=a=b\n",
        )

    def test_merge_leaves_an_unchanged_file_alone(self):
        source = self.source("kscreenlockerrc", "[Daemon]\nAutolock=false\n")
        live = self.config / "kscreenlockerrc"
        live.write_text("[Daemon]\nAutolock=false\nTimeout=0\n")
        os.chmod(live, 0o644)
        before = live.stat().st_mtime_ns
        self.run_script("merge", source, live)
        self.assertEqual(live.stat().st_mtime_ns, before)
        self.assertEqual(live.stat().st_mode & 0o777, 0o644)

    def test_merge_replaces_a_link_without_writing_through_it(self):
        checkout = self.root / "checkout-okularrc"
        checkout.write_text("[General]\nLockSidebar=false\n\n[Recent Files]\nFile1=a.pdf\n")
        source = self.source("okularrc", "[General]\nLockSidebar=true\n")
        live = self.config / "okularrc"
        live.symlink_to(checkout)
        self.run_script("merge", source, live)
        self.assertFalse(live.is_symlink())
        self.assertEqual(live.read_text(), "[General]\nLockSidebar=true\n\n[Recent Files]\nFile1=a.pdf\n")
        self.assertEqual(checkout.read_text(), "[General]\nLockSidebar=false\n\n[Recent Files]\nFile1=a.pdf\n")

    def test_merge_replaces_a_dangling_link(self):
        source = self.source("okularrc", "[General]\nLockSidebar=true\n")
        live = self.config / "okularrc"
        live.symlink_to(self.root / "missing")
        self.run_script("merge", source, live)
        self.assertFalse(live.is_symlink())
        self.assertEqual(live.read_text(), "[General]\nLockSidebar=true\n")
        self.assertFalse((self.root / "missing").exists())

    def test_seed_copies_only_when_missing(self):
        source = self.source("plasmashellrc", "[PlasmaViews][Panel 74]\nfloating=1\n")
        live = self.config / "plasmashellrc"
        self.run_script("seed", source, live)
        self.assertEqual(live.read_text(), source.read_text())
        self.assertEqual(live.stat().st_mode & 0o777, 0o600)
        live.write_text("[PlasmaViews][Panel 1]\nfloating=0\n")
        self.run_script("seed", source, live)
        self.assertEqual(live.read_text(), "[PlasmaViews][Panel 1]\nfloating=0\n")

    def test_seed_turns_a_link_into_a_copy_of_its_target(self):
        checkout = self.root / "checkout-places"
        checkout.write_text("<xbel>live</xbel>\n")
        source = self.source("user-places.xbel", "<xbel>repo</xbel>\n")
        live = self.config / "nested/user-places.xbel"
        live.parent.mkdir()
        live.symlink_to(checkout)
        self.run_script("seed", source, live)
        self.assertFalse(live.is_symlink())
        self.assertEqual(live.read_text(), "<xbel>live</xbel>\n")
        self.assertEqual(checkout.read_text(), "<xbel>live</xbel>\n")

    def test_seed_replaces_a_dangling_link_with_the_source(self):
        source = self.source("kactivitymanagerdrc", "[activities]\nid=Default\n")
        live = self.config / "kactivitymanagerdrc"
        live.symlink_to(self.root / "missing")
        self.run_script("seed", source, live)
        self.assertFalse(live.is_symlink())
        self.assertEqual(live.read_text(), source.read_text())

    def test_creates_parent_directories_and_handles_several_files(self):
        first = self.source("a", "[A]\nx=1\n")
        second = self.source("b", "[B]\ny=2\n")
        self.run_script("merge", first, self.config / "KDE/a", "seed", second, self.config / "b")
        self.assertEqual((self.config / "KDE/a").read_text(), "[A]\nx=1\n")
        self.assertEqual((self.config / "b").read_text(), "[B]\ny=2\n")

    def test_rejects_an_unknown_mode(self):
        source = self.source("a", "[A]\nx=1\n")
        result = subprocess.run([sys.executable, str(SCRIPT), "link", str(source), str(self.config / "a")],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.config / "a").exists())


if __name__ == "__main__":
    unittest.main()
