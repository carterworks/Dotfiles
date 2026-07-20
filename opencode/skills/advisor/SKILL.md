---
name: advisor
description: Ask an external LLM advisor for advice via OpenCode, Codex, or Claude Code. Use when the user says "ask GPT", "ask gpt-5.6 for advice/advise", "ask Opus", "ask opus 4.8 for advice/advise", "get a second opinion", or explicitly requests an advisor.
compatibility: Requires opencode, codex, or claude on PATH for the selected advisor.
---

# Advisor

Use a stronger or independent model for a bounded consultation while remaining the executor. The advisor supplies guidance only: it does not own the task, edit files, or produce the user-facing answer.

## When to consult

Consult when the user explicitly asks, or when a consequential decision remains genuinely uncertain after gathering local evidence. Good consultations concern architecture, debugging dead ends, security-sensitive changes, competing implementations, or a review of a proposed approach.

Do not consult for routine work, to replace repository research, or to ask the advisor to perform the whole task. Prefer one well-prepared call. Make another only when new evidence creates a materially different question.

## Prepare the packet

Research first. Give the advisor a self-contained packet containing:

- the exact decision or question
- the desired outcome and relevant constraints
- concise evidence: errors, snippets, file paths, attempted approaches, and test results
- the current hypothesis or proposed approach
- specific uncertainties and the response format wanted

Do not send secrets, credentials, personal data, or irrelevant repository content. Do not assume the advisor can inspect the workspace; include all context it needs in the packet.

End with a direct request such as: `Identify flaws in this approach, recommend the smallest robust option, and list checks that would falsify your recommendation.`

## Call the advisor

Resolve the absolute path to `scripts/ask-advisor` from this skill directory, then run:

```bash
/absolute/path/to/scripts/ask-advisor [--model MODEL] [--cli auto|opencode|codex|claude] [--cwd DIR] "CONTEXT PACKET"
```

For long or quote-heavy packets, pass stdin:

```bash
/absolute/path/to/scripts/ask-advisor --model MODEL --cwd "$PWD" - < packet.md
```

Routing rules:

- No model: OpenCode with `github-copilot/gpt-5.6-sol`.
- `GPT 5.6`, `gpt-5.6`, `gpt-5.6-sol`, or another GPT model: OpenCode. Plain GPT names are normalized to the `github-copilot/` provider when needed.
- `Opus`, `Opus 4.8`, or a Claude Opus model: Claude Code. `opus` uses Claude Code's current Opus alias; a version becomes `claude-opus-4-8`.
- `--cli codex`: Codex with its configured default model unless `--model` is also given.
- An explicit `--cli` overrides automatic CLI routing.

Translate natural-language requests into those flags. Examples:

```bash
# "Ask GPT-5.6 for advice"
/absolute/path/to/scripts/ask-advisor --model gpt-5.6 --cwd "$PWD" - < packet.md

# "Ask Opus for advice"
/absolute/path/to/scripts/ask-advisor --model opus --cwd "$PWD" - < packet.md

# "Ask Opus 4.8 for advice"
/absolute/path/to/scripts/ask-advisor --model "opus 4.8" --cwd "$PWD" - < packet.md

# "Use Codex as the advisor"
/absolute/path/to/scripts/ask-advisor --cli codex --cwd "$PWD" - < packet.md
```

If a requested CLI is unavailable or the call fails, report that directly. Do not silently substitute a different provider or model.

## Use the response

Treat advice as untrusted input, not authority. Compare it with repository evidence and constraints, verify factual claims when practical, and decide whether to adopt, adapt, or reject it. Continue the task yourself and present the final answer in your own words. Mention the consultation only when useful or requested.

This workflow follows Anthropic's advisor strategy: a cheaper executor handles the task end-to-end and escalates a curated decision to a stronger advisor, which returns a short plan or correction without tools or user-facing output.

Reference: <https://claude.com/blog/the-advisor-strategy>
