- Practice git commit best practices-make commits that are small, atomic, and frequent.
- Only report to me in ASD-STE100 msimplified Technical English.
- Practice red/green TDD when a test harness exists.
- Favor battle-tested libraries (aka "choose boring technology") over homebrew, especially for anything with edge cases.
- Verify, don't assert. Check claims against source or docs before stating them; if unsure, say so. Don't be confidently wrong.
- Gather context first, propose. Context may include local reproduction.
- One command per tool call — no chaining via `&&`, `;`, `||`, or newlines. Combine only when splitting breaks correctness (shared shell state like `cd`/`source`/`export`, or a failure-guard on a mutating step), never for convenience. Run independent commands as separate parallel calls. Piping is fine.
- When using Bash/Run tools, never use`echo` for headers or narration — separate calls already label output, and narration belongs in your reply. (Piping `echo` as data is fine.)
- Before editing any file, read it first. Before modifying a function, search for all callers. Research before you edit.
- Searching the codebase — prefer indexed tools when present, but never assume they exist (Scout and fff MCP are not in every agent or environment). Order of preference: (1) Scout MCP, if available and the repo is indexed — `investigate`, `keyword_search`, `go_to_definition`, `find_references` — and then skip shell `grep`/`find`/`ls -R` for that same job; (2) else the fff MCP — `grep` (default), `find_files`, `multi_grep`; (3) else Bash `rg`/`grep`/`find`. Degrade to the next tier when a preferred tool is unavailable; never block or fail because a preferred tool is missing.
- Comments explain *why* (rationale, gotchas, ordering constraints, workaround + link, ticket/bug refs), never *what* the code already says. Default to zero comments: if code needs a comment to be understood, make the code clearer (rename, extract a function, restructure) instead of explaining it. Never restate the next line/block or duplicate a function/test/variable name (e.g. a `// C2599 - adds only device context...` comment above a test already named that). No section-divider or narration headers. Leave license headers, JSDoc/public-API doc comments, and TODO/FIXME-with-context alone.

Your programming style creed: Simplicity. Readability. Minimalism.
Ask yourself:
* Does this need to exist? If not, skip it.
* Does the standard library do it? Use that.
* Does the native platform do it? Use that.
* Is there already an installed dependency? Use that.
* Does this utility/component/funciton already exist in the repo? Use that.
* Can it be one line? Make it one line.
* Only then write the minimum code that works.
