---
name: commit
description: Create a git commit
---

Create a git commit. Analyze the actual diff to determine appropriate scope, message, and summary. Match the verbosity, tone, and style of commits on this branch and repo, with frecency bias.. Commits are "stealth mode" aka only attributed to the author and only the author (not yourself, the coding agent). Run format, lint, and relevant tests have been run if they have not bene run between the last edit and now. NEVER commit with `--no-verify`.
