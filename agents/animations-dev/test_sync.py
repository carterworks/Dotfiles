import http.server
import importlib.util
import io
import json
import pathlib
import sys
import tempfile
import threading
import unittest
from contextlib import redirect_stderr

spec = importlib.util.spec_from_file_location("sync", pathlib.Path(__file__).with_name("sync.py"))
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

TOKEN = "secret-token-value"


def skill(name, files=None):
    return {
        "id": name,
        "name": name,
        "files": files if files is not None else [{"name": "SKILL.md", "content": f"---\nname: {name}\n---\nBody\n"}],
    }


class Server:
    def __init__(self, status=200, body=None, location=None):
        outer = self
        self.requests = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                outer.requests.append(self.path)
                payload = json.dumps(body if body is not None else {}).encode()
                self.send_response(status)
                if location:
                    self.send_header("Location", location)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(payload)

            def log_message(self, *args):
                pass

        self.httpd = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.httpd.server_address[1]}"
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def close(self):
        self.httpd.shutdown()


class SyncTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dest = pathlib.Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def run_sync(self, server, *args, expected=("animate",)):
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            code = sync.main(
                ["--dest", str(self.dest), "--api", server.url, "--expected", ",".join(expected), *args],
                stdin=io.StringIO(TOKEN + "\n"),
                tty=None,
            )
        return code, stderr.getvalue()

    def test_installs_skills_into_current(self):
        server = Server(body={"skills": [skill("animate")], "unavailable": []})
        try:
            code, _ = self.run_sync(server)
        finally:
            server.close()
        self.assertEqual(code, 0)
        self.assertIn("name: animate", (self.dest / "current/animate/SKILL.md").read_text())
        self.assertIn("token=secret-token-value", server.requests[0])

    def test_rejects_file_names_that_leave_the_skill(self):
        for bad in ["../escape.md", "/etc/passwd", "sub/dir.md", ".hidden", "a\\b"]:
            body = {"skills": [skill("animate", [{"name": "SKILL.md", "content": "---\nname: animate\n---\n"}, {"name": bad, "content": "x"}])]}
            server = Server(body=body)
            try:
                code, err = self.run_sync(server)
            finally:
                server.close()
            self.assertNotEqual(code, 0, bad)
            self.assertFalse((self.dest / "current").exists(), bad)

    def test_rejects_unsafe_skill_names(self):
        server = Server(body={"skills": [skill("../animate")]})
        try:
            code, _ = self.run_sync(server, expected=("../animate",))
        finally:
            server.close()
        self.assertNotEqual(code, 0)

    def test_refuses_redirects(self):
        server = Server(status=308, location="http://example.invalid/")
        try:
            code, err = self.run_sync(server)
        finally:
            server.close()
        self.assertNotEqual(code, 0)
        self.assertNotIn(TOKEN, err)

    def test_error_reports_status_without_the_token(self):
        server = Server(status=401, body={"error": "Invalid or expired token"})
        try:
            code, err = self.run_sync(server)
        finally:
            server.close()
        self.assertNotEqual(code, 0)
        self.assertIn("401", err)
        self.assertIn("Invalid or expired token", err)
        self.assertNotIn(TOKEN, err)

    def test_missing_expected_skill_fails(self):
        server = Server(body={"skills": [skill("animate")]})
        try:
            code, err = self.run_sync(server, expected=("animate", "motion-react"))
        finally:
            server.close()
        self.assertNotEqual(code, 0)
        self.assertIn("motion-react", err)

    def test_changed_content_needs_confirmation(self):
        server = Server(body={"skills": [skill("animate")]})
        try:
            self.assertEqual(self.run_sync(server)[0], 0)
        finally:
            server.close()
        changed = skill("animate", [{"name": "SKILL.md", "content": "---\nname: animate\n---\nNew body\n"}])
        server = Server(body={"skills": [changed]})
        try:
            code, err = self.run_sync(server)
            self.assertNotEqual(code, 0)
            self.assertIn("Body", (self.dest / "current/animate/SKILL.md").read_text())
            self.assertNotIn("New body", (self.dest / "current/animate/SKILL.md").read_text())
            code, _ = self.run_sync(server, "--yes")
        finally:
            server.close()
        self.assertEqual(code, 0)
        self.assertIn("New body", (self.dest / "current/animate/SKILL.md").read_text())

    def test_rename_changes_folder_and_frontmatter(self):
        server = Server(body={"skills": [skill("prototype")]})
        try:
            code, _ = self.run_sync(server, "--rename", "prototype=ad-prototype", expected=("ad-prototype",))
        finally:
            server.close()
        self.assertEqual(code, 0)
        text = (self.dest / "current/ad-prototype/SKILL.md").read_text()
        self.assertIn("name: ad-prototype\n", text)
        self.assertFalse((self.dest / "current/prototype").exists())

    def test_empty_token_fails_before_any_request(self):
        server = Server(body={"skills": [skill("animate")]})
        try:
            with redirect_stderr(io.StringIO()):
                code = sync.main(["--dest", str(self.dest), "--api", server.url, "--expected", "animate"], stdin=io.StringIO(""), tty=None)
        finally:
            server.close()
        self.assertNotEqual(code, 0)
        self.assertEqual(server.requests, [])

    def test_plain_http_only_for_loopback(self):
        with redirect_stderr(io.StringIO()):
            code = sync.main(["--dest", str(self.dest), "--api", "http://animations.dev", "--expected", "animate"], stdin=io.StringIO(TOKEN), tty=None)
        self.assertNotEqual(code, 0)


if __name__ == "__main__":
    sys.exit(unittest.main())
