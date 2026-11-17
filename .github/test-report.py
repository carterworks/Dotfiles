import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location("report", Path(__file__).with_name("report.py"))
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)

ENV = {
    "GITHUB_REPOSITORY": "owner/repo",
    "GITHUB_RUN_ID": "42",
    "GITHUB_RUN_ATTEMPT": "2",
    "GITHUB_SERVER_URL": "https://github.com",
    "BASE": "a" * 40,
    "COMMIT": "b" * 40,
    "UPDATE": "success",
    "STATUS": "0",
    "BUILD": "success",
    "MAIN": "success",
    "RELEASE": "success",
    "CACHE": "scylla=pushed prostagma=pushed eltoro=pushed",
}


def job(name="build / mac", conclusion="failure", step="Build", runner="mac-1"):
    return {
        "id": 7,
        "name": name,
        "status": "completed",
        "conclusion": conclusion,
        "runner_name": runner,
        "labels": ["macos-latest"],
        "steps": [{"name": step, "number": 5, "conclusion": "failure"}] if step else [],
        "check_run_url": "https://api.github.com/repos/owner/repo/check-runs/8",
        "html_url": "https://github.com/owner/repo/actions/runs/42/job/7",
    }


class ReportTests(unittest.TestCase):
    def render(self, jobs=(), log="", annotations=(), env=None, behind=0, fail=None):
        self.calls = []

        def api(path, *, raw=False, paginate=False):
            self.calls.append(path)
            if fail and fail in path:
                raise RuntimeError("GitHub API unavailable")
            if path.endswith("/jobs"):
                self.assertIn("/attempts/2/", path)
                self.assertTrue(paginate)
                return [{"jobs": list(jobs)}]
            if path.endswith("/logs"):
                self.assertTrue(raw)
                return log
            if path.endswith("/annotations"):
                return [list(annotations)]
            if "/compare/" in path:
                return {"ahead_by": behind}
            self.fail(f"Unexpected API call: {path}")

        return REPORT.report({**ENV, **(env or {})}, api)

    def test_success_reports_the_tested_commit_and_attempt(self):
        text, problems = self.render()
        self.assertEqual(problems, [])
        self.assertIn(ENV["COMMIT"], text)
        self.assertIn("/runs/42/attempts/2", text)
        self.assertIn("main and release", text)

    def test_unallocated_cancelled_job_is_not_missed_or_called_a_build_failure(self):
        text, problems = self.render(
            [job(conclusion="cancelled", runner="", step=None)],
            annotations=[{"message": "The job was not acquired by Runner of type hosted"}],
            env={"BUILD": "abandoned", "MAIN": "", "RELEASE": ""},
        )
        self.assertTrue(problems)
        self.assertIn("Runner allocation failure", text)
        self.assertIn("macos-latest", text)
        self.assertIn("The job was not acquired", text)
        self.assertIn("not validated", text)
        self.assertNotIn("the update does not build", text)
        self.assertFalse(any(path.endswith("/logs") for path in self.calls))

    def test_network_failure_in_build_is_distinguished_from_a_broken_derivation(self):
        text, problems = self.render(
            [job()],
            log="error: unable to download 'https://cache.example/nar': HTTP error 206\n"
                "error: some substitutes for the outputs failed (usually happens due to networking issues)",
            env={"BUILD": "failure", "MAIN": "", "RELEASE": ""},
        )
        self.assertTrue(problems)
        self.assertIn("Download/network failure", text)
        self.assertIn("HTTP error 206", text)
        self.assertNotIn("the update does not build", text)

    def test_build_failure_includes_root_error_log_link_and_reproduction(self):
        text, problems = self.render(
            [job()],
            log="warning: unable to download something; retrying\n"
                "hex> error: missing header\n"
                "error: builder for '/nix/store/abc-hex.drv' failed with exit code 1\n"
                "error: Cannot build '/nix/store/def-system.drv'. Reason: 1 dependency failed.",
            env={"BUILD": "failure", "MAIN": "", "RELEASE": ""},
        )
        self.assertTrue(problems)
        self.assertIn("Build/check failure", text)
        self.assertIn("hex> error: missing header", text)
        self.assertIn("job/7#step:5:1", text)
        self.assertIn("nix build -L --impure -f .github/ci.nix mac", text)
        self.assertIn("nix log /nix/store/abc-hex.drv", text)
        self.assertIn("gh run download 42", text)
        self.assertIn("git fetch", text)
        self.assertIn(ENV["COMMIT"], text)

    def test_mac_checks_have_their_own_reproduction_command(self):
        text, _ = self.render([job(step="Checks")], log="error: check failed")
        self.assertIn("nix build -L --impure -f .github/ci.nix checks", text)

    def test_linux_host_has_its_own_reproduction_command(self):
        text, _ = self.render([job(name="build / prostagma")], log="error: evaluation failed")
        self.assertIn("nix build -L .#nixosConfigurations.prostagma.config.system.build.toplevel", text)

    def test_setup_failure_does_not_claim_the_update_is_broken(self):
        text, _ = self.render([job(step="Install Nix, second attempt")], log="curl: connection reset")
        self.assertIn("CI setup/service failure", text)
        self.assertNotIn("Build/check failure", text)

    def test_cancelled_and_timed_out_jobs_are_not_called_build_failures(self):
        for conclusion in ("cancelled", "timed_out", "abandoned"):
            with self.subTest(conclusion=conclusion):
                text, problems = self.render([job(conclusion=conclusion, step=None)])
                self.assertTrue(problems)
                self.assertIn(conclusion, text)
                self.assertNotIn("Build/check failure", text)

    def test_partial_update_includes_updater_errors_even_though_update_job_succeeded(self):
        text, problems = self.render(
            [job(name="update", conclusion="success", step=None)],
            log="t3code-nightly: error: release asset missing\nFailed: t3code-nightly",
            env={"STATUS": "3", "FAILED": "t3code-nightly"},
        )
        self.assertTrue(problems)
        self.assertIn("Update incomplete", text)
        self.assertIn("release asset missing", text)
        self.assertIn("main and release", text)
        self.assertNotIn("Not merged", text)

    def test_failed_update_does_not_say_nothing_to_update(self):
        text, problems = self.render(
            [job(name="update", step="Update")],
            log="error: updater crashed",
            env={"UPDATE": "failure", "STATUS": "1", "COMMIT": "", "MAIN": "", "RELEASE": ""},
        )
        self.assertTrue(problems)
        self.assertIn("Updater failure", text)
        self.assertNotIn("Nothing to update", text)

    def test_api_failure_cannot_silently_report_success(self):
        text, problems = self.render(fail="/jobs")
        self.assertTrue(problems)
        self.assertIn("Could not read jobs", text)

    def test_unavailable_logs_preserve_the_original_job_failure(self):
        text, problems = self.render([job()], fail="/logs")
        self.assertTrue(problems)
        self.assertIn("build / mac", text)
        self.assertIn("Could not read job logs", text)

    def test_unexpected_unsuccessful_build_result_is_not_silently_green(self):
        text, problems = self.render(env={"BUILD": "abandoned", "MAIN": "", "RELEASE": ""})
        self.assertTrue(problems)
        self.assertIn("abandoned", text)

    def test_unreachable_and_missing_cache_credentials_are_not_build_failures(self):
        for cache in ("scylla=unreachable", "scylla=skipped"):
            with self.subTest(cache=cache):
                text, problems = self.render(env={"CACHE": cache, "RELEASE": ""})
                self.assertTrue(problems)
                self.assertIn(cache, text)
                self.assertNotIn("Build/check failure", text)

    def test_a_night_without_updates_still_checks_release_lag(self):
        text, problems = self.render(
            env={"COMMIT": "", "BUILD": "skipped", "MAIN": "", "RELEASE": ""}, behind=2,
        )
        self.assertTrue(problems)
        self.assertIn("release is 2 commits behind main", text)

    def test_summary_cannot_be_broken_out_of_by_upstream_backticks(self):
        text, _ = self.render(env={"SUMMARY": "upstream\n```\n# not a heading"})
        self.assertIn("````\nupstream\n```\n# not a heading\n````", text)

    def test_log_excerpt_is_bounded_and_removes_terminal_control_sequences(self):
        text, _ = self.render(
            [job()],
            log="\n".join(["copying a cached path"] * 5000)
                + "\n2026-11-17T17:12:03.2587010Z \x1b[31merror: actual failure\x1b[0m\n",
        )
        self.assertLess(len(text), 15000)
        self.assertIn("error: actual failure", text)
        self.assertNotIn("\x1b", text)

    def test_retry_warnings_cannot_crowd_the_fatal_error_out_of_the_excerpt(self):
        text, _ = self.render(
            [job()],
            log="\n".join(["warning: download: OpenSSL error: retrying"] * 100)
                + "\nerror: unable to download 'https://cache.example/fatal': HTTP error 206\n",
        )
        self.assertIn("https://cache.example/fatal", text)

    def test_nix_log_targets_the_failed_derivation_not_a_nearby_successful_build(self):
        text, _ = self.render(
            [job()],
            log="building '/nix/store/unrelated.drv'...\n"
                "error: builder for '/nix/store/failed.drv' failed with exit code 1\n",
        )
        self.assertIn("nix log /nix/store/failed.drv", text)
        self.assertNotIn("nix log /nix/store/unrelated.drv", text)

    def test_partial_update_log_command_does_not_filter_out_its_successful_step(self):
        text, _ = self.render(
            [job(name="update", conclusion="success", step=None)],
            log="error: release asset missing",
            env={"STATUS": "3", "FAILED": "t3code-nightly"},
        )
        self.assertIn("--job 7 --log\n", text)
        self.assertNotIn("--log-failed", text)

    def test_partial_update_without_a_commit_does_not_claim_nothing_needed_updating(self):
        text, problems = self.render(env={
            "STATUS": "3", "FAILED": "t3code-nightly", "COMMIT": "", "MAIN": "", "RELEASE": "",
        })
        self.assertTrue(problems)
        self.assertNotIn("Nothing to update", text)

    def test_successful_promotion_is_not_second_guessed_by_the_comparison_api(self):
        _, problems = self.render(behind=1)
        self.assertEqual(problems, [])
        self.assertFalse(any("/compare/" in path for path in self.calls))

    def test_cancellation_before_allocation_does_not_invent_a_capacity_failure(self):
        text, problems = self.render([job(conclusion="cancelled", runner="", step=None)])
        self.assertTrue(problems)
        self.assertIn("Job never started", text)
        self.assertNotIn("Runner allocation failure", text)

    def test_download_errors_do_not_hide_an_independent_builder_failure(self):
        text, _ = self.render(
            [job()],
            log="error: unable to download 'https://cache.example/nar': HTTP error 206\n"
                "error: builder for '/nix/store/failed.drv' failed with exit code 1\n",
        )
        self.assertIn("Build/check and download failures", text)


if __name__ == "__main__":
    unittest.main()
