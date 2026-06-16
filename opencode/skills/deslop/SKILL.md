---
name: deslop
description: Remove AI-generated code slop and clean up code style
---

# Remove AI code slop

Check the diff against main and remove AI-generated slop introduced in the branch.

## Focus Areas

- Defensive checks or try/catch blocks that are abnormal for trusted code paths
- Casts to `any` used only to bypass type issues
- Deeply nested code that should be simplified with early returns
- Other patterns inconsistent with the file and surrounding codebase

## Comments

The default state of code is no comments. A comment earns its place only by explaining *why* — rationale, a non-obvious constraint, a gotcha, a workaround with a link, a ticket/bug ref. A comment that explains *what* the code does is a signal the code should be clearer, not annotated.

Remove a comment when it:

- Restates the next line or block in prose ("// loop over items", "// return the result")
- Duplicates a function/test/variable name (e.g. `// C2599 - adds only device context...` directly above a test already named that)
- Is a section divider or narration header ("// --- setup ---", "// Now configure alloy")
- Explains *what* code does where a rename or extracted function would remove the need for any comment — make that code change instead of keeping the comment

Keep — never strip:

- License/copyright headers
- JSDoc and public-API doc comments
- Why-comments: rationale, gotchas, ordering constraints, workaround + link
- TODO/FIXME that carry real context

## Guardrails

- Keep behavior unchanged unless fixing a clear bug.
- Prefer minimal, focused edits over broad rewrites.
- Keep the final summary concise (1-3 sentences).
