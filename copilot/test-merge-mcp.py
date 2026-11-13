import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("merge-mcp.py")


class MergeMcp(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.shared = self.root / "shared.json"
        self.local = self.root / "copilot" / "mcp-config.json"
        self.servers = {"fff": {"type": "stdio", "command": "fff-mcp", "tools": ["*"]}}
        self.shared.write_text(json.dumps({"mcpServers": self.servers}))

    def run_script(self):
        return subprocess.run([sys.executable, str(SCRIPT), str(self.shared), str(self.local)],
                              capture_output=True, text=True)

    def test_creates_private_local_config(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.local.read_text()), {"mcpServers": self.servers})
        self.assertEqual(self.local.stat().st_mode & 0o777, 0o600)

    def test_preserves_local_servers_and_other_settings(self):
        self.local.parent.mkdir()
        private = {"type": "http", "url": "https://work.example/mcp",
                   "headers": {"Authorization": "${WORK_TOKEN}"}, "tools": ["*"]}
        self.local.write_text(json.dumps({"mcpServers": {"work": private}, "extra": True}))
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.local.read_text()),
                         {"mcpServers": {"work": private} | self.servers, "extra": True})

    def test_shared_servers_are_updated(self):
        self.local.parent.mkdir()
        self.local.write_text(json.dumps({"mcpServers": {"fff": {"command": "old"}}}))
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(json.loads(self.local.read_text())["mcpServers"], self.servers)

    def test_replaces_symlink_without_writing_shared_file(self):
        self.local.parent.mkdir()
        self.local.symlink_to(self.shared)
        original = self.shared.read_bytes()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.local.is_symlink())
        self.assertEqual(self.shared.read_bytes(), original)
        self.assertEqual(json.loads(self.local.read_text()), {"mcpServers": self.servers})

    def test_unchanged_config_is_not_rewritten(self):
        self.assertEqual(self.run_script().returncode, 0)
        before = self.local.stat().st_mtime_ns
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.local.stat().st_mtime_ns, before)

    def test_unchanged_config_is_kept_private(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.local.chmod(0o644)
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.local.stat().st_mode & 0o777, 0o600)

    def test_rejects_invalid_local_config_without_overwriting(self):
        self.local.parent.mkdir()
        for content in ["not json", "[]", '{"mcpServers": []}']:
            with self.subTest(content=content):
                self.local.write_text(content)
                result = self.run_script()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.local.read_text(), content)

    def test_rejects_invalid_shared_config_without_overwriting_local(self):
        self.local.parent.mkdir()
        original = '{"mcpServers": {"work": {"type": "http"}}}'
        self.local.write_text(original)
        for content in ["not json", "[]", "{}", '{"mcpServers": []}']:
            with self.subTest(content=content):
                self.shared.write_text(content)
                result = self.run_script()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.local.read_text(), original)


if __name__ == "__main__":
    unittest.main()
