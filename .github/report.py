import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


def github_api(path, *, raw=False, paginate=False):
    args = ["gh", "api", path]
    if raw:
        args.append("--allow-escape-sequences")
    if paginate:
        args.extend(["--paginate", "--slurp"])
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise RuntimeError(str(error)) from error
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    if raw:
        return result.stdout
    try:
        return json.loads(result.stdout)
    except ValueError as error:
        raise RuntimeError(f"Invalid API response for {path}: {error}") from error


def fenced(text):
    fence = "`" * max(3, max((len(run) + 1 for run in re.findall(r"`+", text)), default=0))
    return f"{fence}\n{text.rstrip()}\n{fence}"


def clean_log(log):
    log = re.sub(r"\x1b\].*?(?:\x07|\x1b\\)", "", log, flags=re.DOTALL)
    log = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", log)
    log = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", log)
    return re.sub(r"(?m)^\d{4}-\d\d-\d\dT[\d:.]+Z ", "", log)


def excerpt(log):
    lines = log.splitlines()
    errors = [index for index, line in enumerate(lines)
              if not line.startswith("warning:") and re.search(r"(?i)\berror:|\bfatal:|^Failed:", line)]
    selected = set()
    for index in errors[:8]:
        selected.update(range(max(0, index - 3), min(len(lines), index + 9)))
    if not selected:
        selected.update(range(max(0, len(lines) - 40), len(lines)))
    return "\n".join(lines[index] for index in sorted(selected)[:80])[:12000]


def category(job, steps, log, notes):
    if not job.get("runner_name") and not job.get("steps"):
        if any("not acquired by Runner" in note for note in notes):
            return "Runner allocation failure"
        return f"Job never started ({job['conclusion']})"
    if job["conclusion"] != "failure":
        return f"Job interrupted ({job['conclusion']})"
    if job["name"] == "update" and "Update" in steps:
        return "Updater failure"
    if job["name"] == "promote":
        return "Promotion failure"
    if "Push to the binary cache" in steps:
        return "Cache push failure"
    if any(step in ("Build", "Checks") for step in steps):
        if re.search(r"(?im)^error:.*(?:unable to download|failed to download|some substitutes.*failed)", log):
            if re.search(r"builder.*failed with exit code", log):
                return "Build/check and download failures"
            return "Download/network failure"
        return "Build/check failure" if log else "Build/check command failed (diagnostics unavailable)"
    return "CI setup/service failure"


def reproduce(job, steps):
    name = job["name"].split(" / ")[-1]
    commands = []
    if "Build" in steps:
        if name in ("scylla", "prostagma", "eltoro"):
            commands.append(f"nix build -L .#nixosConfigurations.{name}.config.system.build.toplevel")
        elif name == "mac":
            commands.append("nix build -L --impure -f .github/ci.nix mac")
        elif name in ("checks-linux", "checks-mac"):
            commands.append("nix build -L --impure -f .github/ci.nix checks")
    if "Checks" in steps:
        commands.append("nix build -L --impure -f .github/ci.nix checks")
    return commands


def report(env, api=github_api):
    repo = env["GITHUB_REPOSITORY"]
    run = env["GITHUB_RUN_ID"]
    attempt = env["GITHUB_RUN_ATTEMPT"]
    url = f"{env.get('GITHUB_SERVER_URL', 'https://github.com')}/{repo}/actions/runs/{run}"
    commit = env.get("COMMIT", "")
    main = env.get("MAIN", "")
    release = env.get("RELEASE", "")
    cache = env.get("CACHE", "")
    problems = []
    details = []

    try:
        jobs = [job for page in api(
            f"repos/{repo}/actions/runs/{run}/attempts/{attempt}/jobs", paginate=True,
        ) for job in page["jobs"]]
    except (RuntimeError, ValueError) as error:
        jobs = []
        problems.append(f"Could not read jobs: {error}")

    for job in jobs:
        if job["name"] == "report":
            continue
        incomplete_update = job["name"] == "update" and env.get("STATUS") == "3"
        failed = (job["status"] == "completed"
                  and job["conclusion"] not in ("success", "skipped", "neutral"))
        if not failed and not incomplete_update:
            continue
        steps = [step["name"] for step in job.get("steps", []) if step["conclusion"] == "failure"]
        notes = []
        log = ""
        if job.get("runner_name"):
            try:
                log = clean_log(api(f"repos/{repo}/actions/jobs/{job['id']}/logs", raw=True))
            except RuntimeError as error:
                notes.append(f"Could not read job logs: {error}")
        if failed and job.get("check_run_url"):
            check = job["check_run_url"].rsplit("/", 1)[-1]
            try:
                annotations = [item["message"] for page in api(
                    f"repos/{repo}/check-runs/{check}/annotations", paginate=True,
                ) for item in page]
                notes.extend(annotations)
            except RuntimeError as error:
                notes.append(f"Could not read job annotations: {error}")
        kind = "Update incomplete" if incomplete_update and not failed else category(job, steps, log, notes)
        problem = f"{kind}: {job['name']}"
        if steps:
            problem += f" ({', '.join(steps)})"
        problems.append(problem)
        job_url = job.get("html_url") or f"{url}/job/{job['id']}"
        lines = [f"### {problem}", "", f"[Job logs]({job_url}) · conclusion: `{job['conclusion']}`",
                 f"Runner: `{job.get('runner_name') or 'not allocated'}`; labels: `{', '.join(job.get('labels', []))}`."]
        for step in job.get("steps", []):
            if step["conclusion"] == "failure":
                lines.append(f"- [{step['name']}]({job_url}#step:{step['number']}:1)")
        if kind == "Runner allocation failure":
            lines.extend(["", "No build ran on this job; the update is not validated. Rerun the affected job manually."])
        if notes:
            lines.extend(["", fenced(clean_log("\n".join(notes))[:12000])])
        if log:
            lines.extend(["", "Error context:", "", fenced(excerpt(log))])
            log_flag = "--log-failed" if steps else "--log"
            lines.extend(["", "Full logs after the run completes:", "",
                          fenced(f"gh run view {run} --repo {repo} --attempt {attempt} --job {job['id']} {log_flag}")])
        commands = reproduce(job, steps)
        if commands:
            lines.extend(["", "Reproduce at the tested commit, on the same OS/architecture:", "", fenced("\n".join(commands))])
            derivations = re.findall(r"error: (?:builder for|Cannot build) ['\"](/nix/store/[A-Za-z0-9+._?=-]+\.drv)", log)
            if derivations:
                lines.extend(["", "After reproducing, inspect the failing derivation:", "",
                               fenced(f"nix log {shlex.quote(derivations[0])}")])
        details.append("\n".join(lines))

    if not problems:
        for label in ("UPDATE", "BUILD", "MAIN", "RELEASE"):
            result = env.get(label, "")
            if result not in ("", "success", "skipped"):
                problems.append(f"{label.lower()} finished with {result}; see the run's jobs")
    if env.get("STATUS") == "3":
        problems.append(f"These updates failed and were left out: {env.get('FAILED') or 'see the update job'}")
    if main == "success" and release not in ("success", "failure"):
        reason = "not every host reported a successful cache push"
        if "unreachable" in cache:
            reason = "the binary cache was unreachable"
        elif "skipped" in cache:
            reason = "a binary-cache Environment secret is unset"
        problems.append(f"main moved but release did not: {reason} ({cache})")
    # A successful push already verified release; comparing immediately can read stale API data.
    if not problems and release != "success":
        try:
            behind = api(f"repos/{repo}/compare/release...main")["ahead_by"]
            if behind:
                problems.append(f"release is {behind} commits behind main; see the latest Fleet run on main")
        except (RuntimeError, ValueError, KeyError) as error:
            problems.append(f"Could not compare release with main: {error}")

    if not commit and env.get("UPDATE") != "success":
        outcome = "Update did not complete; main and release are unchanged."
    elif not commit and env.get("STATUS") == "3":
        outcome = "Some updates failed and no update commit was produced; main and release are unchanged."
    elif not commit:
        outcome = "Nothing to update."
    elif main != "success":
        outcome = "Not merged: main and release are unchanged."
    elif release == "success":
        outcome = f"main and release are now `{commit}`."
    else:
        outcome = f"main is now `{commit}`; release did not move ({cache})."
    tested = commit or env.get("BASE") or env.get("GITHUB_SHA", "unknown")
    lines = ["## Nightly update", "", outcome, "", f"[Run {run}, attempt {attempt}]({url}/attempts/{attempt})",
             f"Tested commit: `{tested}`; base: `{env.get('BASE', 'unknown')}`."]
    if problems:
        lines.extend(["", *(f"- **{problem}**" for problem in problems)])
    if commit and main != "success":
        lines.extend(["", "The unmerged commit is in the `update` artifact for seven days. In a clean checkout:", "",
                      fenced(f"gh run download {run} --repo {repo} --name update --dir /path/to/nightly-update\n"
                             f"git fetch /path/to/nightly-update/update.bundle\ngit checkout --detach {commit}")])
    lines.extend(["", *details])
    if env.get("SUMMARY"):
        lines.extend(["", "### Attempted updates", "", fenced(env["SUMMARY"])])
    return "\n".join(lines) + "\n", problems


def main():
    text, problems = report(os.environ)
    with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as summary:
        summary.write(text)
    for problem in problems:
        escaped = problem.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::error::{escaped}")
    return bool(problems)


if __name__ == "__main__":
    sys.exit(main())
