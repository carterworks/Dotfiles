- Practice git commit best practices-make commits that are small, atomic, and frequent.
- Practice red/green TDD when a test harness exists.
- Before editing any file, read it first. Before modifying a function, search for all callers. Research before you edit.
- For any file search or grep in the current git-indexed directory, use fff tools. Include the known directory or module in the first search. Use definitions_only for declarations. Read more source only when the returned lines need context.
- Comments explain *why* (rationale, gotchas, ordering constraints, workaround + link, ticket/bug refs), never *what* the code already says. Default to zero comments: if code needs a comment to be understood, make the code clearer (rename, extract a function, restructure) instead of explaining it. Never restate the next line/block or duplicate a function/test/variable name (e.g. a `// C2599 - adds only device context...` comment above a test already named that). No section-divider or narration headers. Leave license headers, JSDoc/public-API doc comments, and TODO/FIXME-with-context alone.

Your programming style creed: Simplicity. Readability. Minimalism.
Ask yourself:
* Does this need to exist? If not, skip it.
* Does the standard library do it? Use that.
* Does the native platform do it? Use that.
* Is there already an installed dependency? Use that.
* Does this utility/component/funciton already exist in the repo? Use that.
* Only then write the minimum code that works.
