import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


def bash(script, *args, cwd=None, **env):
    return subprocess.run(
        ["bash", "-c", 'source "$UPDATE"\n' + script, "test-update", *args],
        env={**os.environ, "UPDATE": str(ROOT / "update"), **env},
        cwd=cwd, stdin=subprocess.DEVNULL, text=True, capture_output=True,
    )


class SparkleUpdateTests(unittest.TestCase):
    def discover(self, feed):
        return bash('''
curl() { printf '%s' "$FEED"; }
latest_version '{"source":"sparkle","url":"https://example.com/appcast.xml"}'
''', FEED=feed)

    def test_build_number_distinguishes_previews(self):
        result = self.discover('''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel><item><sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
<sparkle:version>1541</sparkle:version></item>
<item><sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
<sparkle:version>1497</sparkle:version></item></channel></rss>''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "0.1.0-1541")

    def test_rejects_missing_build(self):
        result = self.discover('''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel><item><sparkle:shortVersionString>0.1.0</sparkle:shortVersionString></item></channel></rss>''')
        self.assertNotEqual(result.returncode, 0)

    def test_rejects_empty_feed(self):
        self.assertNotEqual(self.discover("<rss><channel/></rss>").returncode, 0)


# A nix stand-in that evaluates package attributes from the files on disk, so
# the updater's post-rewrite check sees what it wrote.
FAKE_NIX = r'''
nix() {
  local attr="${*: -1}" path pkg field file
  case "$*" in
    "eval --impure --raw --expr builtins.currentSystem") echo x86_64-linux ;;
    *"--apply builtins.attrNames") echo '["x86_64-linux"]' ;;
    "flake update")
      printf '%s' "${NIX_CONFIG:-}" >nix-config
      jq '.nodes.nixpkgs.locked.rev = "bbbbbbbbbb"' flake.lock >flake.lock.new
      mv flake.lock.new flake.lock ;;
    *.generated.name)
      if [[ "$(jq -r .nodes.nixpkgs.locked.rev flake.lock)" == bbb* ]]; then
        echo herdr-skill-2.md
      else
        echo herdr-skill-1.md
      fi ;;
    build*) printf 'new skill\n' >generated-skill; echo "$PWD/generated-skill" ;;
    "store prefetch-file --json "*) echo "{\"hash\":\"sha256-new-${attr##*/}\"}" ;;
    eval*)
      path="${attr#.#packages.x86_64-linux.}"
      pkg="${path%%.*}"
      field="${path#*.}"
      file="nix/packages/${pkg}.nix"
      [[ -f "${file}" ]] || return 1
      case "${field}" in
        updateInfo.source) echo github-release ;;
        updateInfo) echo "{\"source\":\"github-release\",\"owner\":\"o\",\"repo\":\"${pkg}\"}" ;;
        version) sed -n 's/.*version = "\([^"]*\)".*/\1/p' "${file}" ;;
        src.url) echo "https://example.com/${pkg}-$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "${file}").tar.gz" ;;
        # broken's hash lives somewhere the rewrite cannot reach.
        src.outputHash)
          if [[ "${pkg}" == broken ]]; then
            echo sha256-elsewhere
          else
            sed -n 's/.*hash = "\([^"]*\)".*/\1/p' "${file}"
          fi ;;
        *) return 1 ;;
      esac ;;
    *) return 1 ;;
  esac
}
curl() { echo '[{"tag_name":"2.0","draft":false,"prerelease":false}]'; }
'''


class ApplyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        (self.root / "nix/packages").mkdir(parents=True)
        (self.root / "agents/skills/generated/herdr").mkdir(parents=True)
        (self.root / "agents/skills/generated/herdr/SKILL.md").write_text("old skill\n")
        (self.root / "flake.nix").write_text("{ }\n")
        (self.root / "flake.lock").write_text(json.dumps({
            "nodes": {
                "root": {"inputs": {"nixpkgs": "nixpkgs", "hermes-agent": "hermes-agent"}},
                "nixpkgs": {"locked": {"rev": "aaaaaaaaaa", "lastModified": 0}},
                "hermes-agent": {"locked": {"rev": "cccccccccc", "lastModified": 0}},
            },
            "root": "root", "version": 7,
        }))
        for name, version in (("alpha", "1.0"), ("broken", "1.0"), ("current", "2.0")):
            self.package(name).write_text(
                f'{{ pname = "{name}"; version = "{version}"; hash = "sha256-old-{name}"; }}\n')

    def tearDown(self):
        self.directory.cleanup()

    def package(self, name):
        return self.root / "nix/packages" / f"{name}.nix"

    def run_update(self, *args):
        return bash(FAKE_NIX + '''
BASEDIR="$PWD"
STATUS_TTY=/dev/null
SKILLS=(herdr-skill:herdr)
main "$@"
''', *args, cwd=self.root, GH_TOKEN="test-token", TMPDIR=str(self.root))

    def test_apply_continues_past_a_failure_and_reports_old_and_new(self):
        before = self.package("broken").read_text()
        result = self.run_update("--apply")

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "nixpkgs aaaaaaa (1970-01-01) -> bbbbbbb (1970-01-01)",
            "agents/skills/generated/herdr/SKILL.md 1 -> 2",
            "alpha 1.0 -> 2.0",
        ])
        self.assertIn("broken: could not update to 2.0; left at 1.0", result.stderr)
        self.assertEqual(
            self.package("alpha").read_text(),
            '{ pname = "alpha"; version = "2.0"; hash = "sha256-new-alpha-2.0.tar.gz"; }\n')
        self.assertEqual(self.package("broken").read_text(), before)
        self.assertEqual(
            (self.root / "agents/skills/generated/herdr/SKILL.md").read_text(), "new skill\n")

    def test_token_reaches_nix_through_the_environment(self):
        self.run_update("--apply")
        self.assertIn("access-tokens = github.com=test-token",
                      (self.root / "nix-config").read_text())

    def test_clean_run_exits_zero(self):
        self.package("broken").unlink()
        result = self.run_update("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("alpha 1.0 -> 2.0", result.stdout)

    def test_dry_run_reports_without_changing_anything(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(),
                         ["alpha 1.0 -> 2.0", "broken 1.0 -> 2.0"])
        self.assertIn('version = "1.0"', self.package("alpha").read_text())
        self.assertNotIn("bbbbbbbbbb", (self.root / "flake.lock").read_text())


class GitHubTokenTests(unittest.TestCase):
    def test_environment_token_is_used_when_gh_is_missing(self):
        result = bash('''
command() { [[ "$*" != "-v gh" ]] && builtin command "$@"; }
github_token
''', GH_TOKEN="", GITHUB_TOKEN="from-actions")
        self.assertEqual(result.stdout, "from-actions")

    def test_token_is_sent_on_stdin_not_argv(self):
        result = bash('''
curl() { printf '%s\\n' "$@" >&2; cat; }
GITHUB_TOKEN_VALUE=secret-token
github_api repos/o/r/releases
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("secret-token", result.stderr)
        self.assertEqual(result.stdout.strip(), "Authorization: Bearer secret-token")


class BambuStudioUpdateTests(unittest.TestCase):
    def asset_url(self, names):
        package = (ROOT / "nix/packages/bambu-studio.nix").read_text()
        pattern = json.loads(package.split("assetPattern = ", 1)[1].split(";", 1)[0])
        release = {"assets": [
            {"name": name, "browser_download_url": f"https://example.com/{name}"}
            for name in names
        ]}
        info = {
            "owner": "bambulab", "repo": "BambuStudio", "tagPrefix": "v",
            "assetPattern": pattern,
        }
        return bash('''
github_api() {
  [[ "$1" == repos/bambulab/BambuStudio/releases/tags/v02.09.01.70 ]] || return 1
  printf '%s' "$RELEASE"
}
release_asset_url "$UPDATE_INFO" 02.09.01.70
''', RELEASE=json.dumps(release), UPDATE_INFO=json.dumps(info))

    def test_selects_ubuntu_24_appimage_across_filename_formats(self):
        for name in (
            "BambuStudio_ubuntu24.04-v02.08.02.61-20260820225108.AppImage",
            "BambuStudio_ubuntu-24.04-v02.08.02.61-20260820225108.AppImage",
            "BambuStudio_ubu24-v02.09.01.70-20261103183404.AppImage",
        ):
            with self.subTest(name=name):
                result = self.asset_url([
                    "BambuStudio_ubu22_v02.09.01.70-20261103183404.AppImage",
                    "Bambu_Studio_mac-v02.09.01.70-20261103183404.dmg",
                    "Bambu_Studio_win-v02.09.01.70-20261103183404.exe",
                    "Bambu_Studio_win-v02.09.01.70-20261103183404.zip",
                    name,
                ])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), f"https://example.com/{name}")

    def test_rejects_missing_ubuntu_24_appimage(self):
        result = self.asset_url([
            "BambuStudio_ubu22_v02.09.01.70-20261103183404.AppImage",
        ])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected exactly one matching release asset", result.stderr)

    def test_rejects_ambiguous_ubuntu_24_appimages(self):
        result = self.asset_url([
            "BambuStudio_ubu24-v02.09.01.70-first.AppImage",
            "BambuStudio_ubu24-v02.09.01.70-second.AppImage",
        ])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected exactly one matching release asset", result.stderr)

    def test_apply_renames_the_asset_and_rewrites_the_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "bambu-studio.nix"
            package.write_text(
                'version = "1"; asset = "Bambu-1-20260101.AppImage"; hash = "oldhash";')
            result = bash('''
release_asset_url() { echo https://example.com/Bambu-2-20261103.AppImage; }
nix() {
  case "$*" in
    *src.url) echo https://example.com/Bambu-1-20260101.AppImage ;;
    *prefetch-file*)
      [[ "${*: -1}" == https://example.com/Bambu-2-20261103.AppImage ]] || return 1
      echo '{"hash":"newhash"}' ;;
    *src.outputHash) sed -n 's/.*hash = "\\([^"]*\\)".*/\\1/p' "$PACKAGE" ;;
    *version) sed -n 's/.*version = "\\([^"]*\\)".*/\\1/p' "$PACKAGE" ;;
    *) return 1 ;;
  esac
}
apply_update bambu-studio "$PACKAGE" 1 2 '{"assetPattern":"x"}' x86_64-linux
''', PACKAGE=str(package))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                package.read_text(),
                'version = "2"; asset = "Bambu-2-20261103.AppImage"; hash = "newhash";\n')


class PrivateSourceTests(unittest.TestCase):
    def test_reads_url_from_external_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "sources.json"
            manifest.write_text(json.dumps({"rex": {
                "clientFeedUrl": "https://example.invalid/feed.xml"
            }}))
            result = bash('private_source rex.clientFeedUrl',
                          DOTFILES_PRIVATE_SOURCES_FILE=str(manifest))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "https://example.invalid/feed.xml")

    def test_sparkle_discovery_resolves_private_key(self):
        result = bash('''
private_source() {
  [[ "$1" == rex.clientFeedUrl ]] || return 1
  echo https://example.invalid/feed.xml
}
curl() {
  [[ "${@: -1}" == https://example.invalid/feed.xml ]] || return 1
  echo '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:shortVersionString>1.0</sparkle:shortVersionString><sparkle:version>2</sparkle:version></item></channel></rss>'
}
latest_version '{"source":"sparkle","privateUrlKey":"rex.clientFeedUrl"}'
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "1.0-2")

    def test_missing_manifest_fails_without_exposing_urls(self):
        result = bash('private_source rex.clientFeedUrl',
                      DOTFILES_PRIVATE_SOURCES_FILE="/nonexistent/dotfiles-private/sources.json")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("https://", result.stdout + result.stderr)

    def test_private_update_writes_only_version_and_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "package.nix"
            package.write_text('version = "old"; hash = "oldhash";')
            result = bash('''
nix() {
  case "$*" in
    *src.outputHash) sed -n 's/.*hash = "\\([^"]*\\)".*/\\1/p' "$PACKAGE" ;;
    *version) sed -n 's/.*version = "\\([^"]*\\)".*/\\1/p' "$PACKAGE" ;;
    *) return 1 ;;
  esac
}
cache_private_release() { echo newhash; }
apply_update rex-client "$PACKAGE" old new '{"strategy":"require-file"}' aarch64-darwin
''', PACKAGE=str(package))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(package.read_text(), 'version = "new"; hash = "newhash";\n')

    def test_hash_mismatch_does_not_import_download(self):
        result = bash('''
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
        result = bash('''
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


class HeldInputTests(unittest.TestCase):
    def test_hermes_agent_rev_survives_updating_all_inputs(self):
        lock = json.loads((ROOT / "flake.lock").read_text())
        node = lock["nodes"][lock["nodes"]["root"]["inputs"]["hermes-agent"]]
        self.assertEqual(node["original"].get("rev"), node["locked"]["rev"])


if __name__ == "__main__":
    unittest.main()
