import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
FUNCTIONS = (ROOT / "update").read_text().split('while [[ $# -gt 0 ]]')[0]
FUNCTIONS = "set -euo pipefail\nAPPLY=false\n" + FUNCTIONS.split("APPLY=false", 1)[1]


class SparkleUpdateTests(unittest.TestCase):
    def discover(self, feed):
        script = FUNCTIONS + '''
curl() { printf '%s' "$FEED"; }
latest_update '{"source":"sparkle","url":"https://example.com/appcast.xml"}'
'''
        return subprocess.run(
            ["bash", "-c", script],
            env={**os.environ, "FEED": feed},
            text=True,
            capture_output=True,
        )

    def test_build_number_distinguishes_previews(self):
        result = self.discover('''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel><item><sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
<sparkle:version>1541</sparkle:version></item>
<item><sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
<sparkle:version>1497</sparkle:version></item></channel></rss>''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {
            "version": "0.1.0-1541", "revision": "0.1.0-1541"
        })

    def test_rejects_missing_build(self):
        result = self.discover("<rss><channel><item/></channel></rss>")
        self.assertNotEqual(result.returncode, 0)

    def test_rejects_empty_feed(self):
        self.assertNotEqual(self.discover("<rss><channel/></rss>").returncode, 0)

    def test_apply_updates_version_url_and_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "rex-client.nix"
            package.write_text('version = "0.1.0-1497"; hash = "oldhash";')
            script = FUNCTIONS + '''
NIX_ACCESS_TOKEN_ARGS=()
package_systems() { echo aarch64-darwin; }
nix() {
  case "$*" in
    *src.url) echo https://example.com/Rex-0.1.0-1497.dmg ;;
    *src.outputHash) echo oldhash ;;
    *prefetch-file*)
      [[ "${*: -1}" == https://example.com/Rex-0.1.0-1541.dmg ]] || return 1
      echo '{"hash":"newhash"}' ;;
    *) return 1 ;;
  esac
}
apply_update rex-client "$1" 0.1.0-1497 0.1.0-1541 '{"source":"sparkle"}'
'''
            result = subprocess.run(
                ["bash", "-c", script, "test-update", str(package)],
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(package.read_text(),
                             'version = "0.1.0-1541"; hash = "newhash";\n')


class PrivateSourceTests(unittest.TestCase):
    def run_script(self, script, *args, **env):
        return subprocess.run(
            ["bash", "-c", FUNCTIONS + script, "test-update", *args],
            env={**os.environ, **env}, text=True, capture_output=True,
        )

    def test_reads_url_from_external_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "sources.json"
            manifest.write_text(json.dumps({"rex": {
                "clientFeedUrl": "https://example.invalid/feed.xml"
            }}))
            result = self.run_script(
                '\nprivate_source rex.clientFeedUrl\n',
                DOTFILES_PRIVATE_SOURCES_FILE=str(manifest),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "https://example.invalid/feed.xml")

    def test_sparkle_discovery_resolves_private_key(self):
        result = self.run_script('''
private_source() {
  [[ "$1" == rex.clientFeedUrl ]] || return 1
  echo https://example.invalid/feed.xml
}
curl() {
  [[ "${@: -1}" == https://example.invalid/feed.xml ]] || return 1
  echo '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:shortVersionString>1.0</sparkle:shortVersionString><sparkle:version>2</sparkle:version></item></channel></rss>'
}
latest_update '{"source":"sparkle","privateUrlKey":"rex.clientFeedUrl"}'
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["version"], "1.0-2")

    def test_missing_manifest_fails_without_exposing_urls(self):
        result = self.run_script(
            '\nprivate_source rex.clientFeedUrl\n',
            DOTFILES_PRIVATE_SOURCES_FILE="/nonexistent/dotfiles-private/sources.json",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("https://", result.stdout + result.stderr)

    def test_private_update_only_writes_version_and_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "package.nix"
            package.write_text('version = "old"; hash = "oldhash";')
            result = self.run_script('''
NIX_ACCESS_TOKEN_ARGS=()
nix() { echo oldhash; }
cache_private_release() { echo newhash; }
apply_private_update rex-client "$1" old new aarch64-darwin '{}'
''', str(package))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(package.read_text(), 'version = "new"; hash = "newhash";\n')

    def test_failed_download_leaves_package_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "package.nix"
            original = 'version = "old"; hash = "oldhash";'
            package.write_text(original)
            result = self.run_script('''
NIX_ACCESS_TOKEN_ARGS=()
nix() { echo oldhash; }
cache_private_release() { return 1; }
apply_private_update rex-client "$1" old new aarch64-darwin '{}'
''', str(package))
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(package.read_text(), original)

    def test_hash_mismatch_does_not_import_download(self):
        result = self.run_script('''
NIX_ACCESS_TOKEN_ARGS=()
private_source() { echo 'https://example.invalid/Rex-{version}.dmg'; }
curl() { printf 'fixture' > "${@: -1}"; }
nix() {
  if [[ "$1" == hash ]]; then
    echo wronghash
  else
    echo unexpected-import
  fi
}
cache_private_release '{"privateUrlTemplateKey":"rex.clientUrlTemplate","fileName":"Rex-{version}.dmg"}' 1.0 expectedhash
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("unexpected-import", result.stdout)

    def test_import_uses_filename_not_url(self):
        result = self.run_script('''
NIX_ACCESS_TOKEN_ARGS=()
private_source() { echo 'https://example.invalid/Rex-{version}.dmg'; }
curl() { printf 'fixture' > "${@: -1}"; }
nix() {
  case "$1" in
    hash) echo expectedhash ;;
    store)
      [[ "$2" == add-file && "$3" == --name && "$4" == Rex-1.0.dmg ]] || return 1
      [[ "$*" != *https://* ]] || return 1 ;;
    *) return 1 ;;
  esac
}
cache_private_release '{"privateUrlTemplateKey":"rex.clientUrlTemplate","fileName":"Rex-{version}.dmg"}' 1.0 expectedhash
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "expectedhash")

    def test_server_flake_uses_external_gc_root_without_writing_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_script('''
NIX_ACCESS_TOKEN_ARGS=()
expected_destination="$1"
private_source() { echo https://example.invalid/server.tar.gz; }
nix() {
  [[ "$*" == *--no-write-lock-file* && "$*" == *--refresh* ]] || return 1
  echo '{"path":"/nix/store/test-rex-source"}'
}
nix-store() {
  [[ "$1" == --realise && "$2" == /nix/store/test-rex-source && "$3" == --add-root && "$4" == "$expected_destination" && "$5" == --indirect ]]
}
refresh_private_rex_flake "$1"
''', str(Path(directory) / "rex-flake"))
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_server_flake_refuses_to_replace_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_script(
                '\nrefresh_private_rex_flake "$1"\n', directory,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("refusing to replace", result.stderr)


if __name__ == "__main__":
    unittest.main()
