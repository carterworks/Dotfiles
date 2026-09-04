---
name: briefing
description: Reconstruct what you did on a day (default yesterday) from atuin history, Claude Code and opencode sessions, and Chrome history.
disable-model-invocation: true
---

## Gather

Run `gather.sh` in this skill's directory. Pass the target date as `YYYY-MM-DD`, or pass no date for yesterday.

```sh
bash gather.sh 2026-09-01
```

The script prints four labelled sections. Each section has one status: `complete`, `empty`, `unavailable`, `failed`, or `partial`. If a status gives a data-file path, read the complete file before synthesis.

Gathering is complete when all four statuses are accounted for and all referenced data files are read. Continue with available sources when one source is unavailable, failed, or partial. Preserve that limit in the final coverage report.

## Synthesize

Organize the briefing by project or theme. Connect records only when a shared project, path, branch, pull request, ticket, or clear topic supports the connection. Label a weaker connection as an inference.

Order themes by their first observed event. For each theme, give the observed time range, what happened, and the evidence trail. Include useful identifiers such as pull requests, branches, files, and tickets. Do not infer activity outside the observed time range.

Use this format:

```markdown
# YYYY-MM-DD: <one-line arc of the day>

## HH:MM-HH:MM — <theme>
<what happened>

Evidence: <sources and identifiers>
Confidence: high | medium | low

## Source coverage
- Atuin: <status>
- Claude Code: <status>
- OpenCode: <status>
- Chrome: <status>
```

Omit routine authentication pages and extension traffic from the narrative. Treat `[REDACTED]` as unavailable data and do not reconstruct it.
