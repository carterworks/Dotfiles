---
name: commit
description: Create a properly formatted git commit for this repo. Use whenever a commit is requested or authorized instead of running `git commit` yourself.
---

Create a git commit. Keep commits small and atomic. Analyze the actual diff to determine appropriate scope, message, and summary. Match the verbosity, tone, and style of commits on this branch and repo, with frecency bias. Omit agent-generated co-author or attribution trailers. Ensure format, lint, and relevant tests have been run since the last edit. NEVER commit with `--no-verify`.
