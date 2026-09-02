# mattpocock skills

The skills in `mattpocock/` are vendored from Matt Pocock's skills collection.

- Source: https://github.com/mattpocock/skills
- License: MIT (see `mattpocock-LICENSE`)
- Vendored: 2026-09-02

## Local changes

These are not verbatim copies. The following changes were made:

- Kept only the shippable skills (Matt's `engineering` and `productivity`
  buckets). The `in-progress`, `misc`, and `deprecated` buckets were not
  vendored.
- Removed each skill's `agents/openai.yaml` (Codex UI metadata). Its
  `allow_implicit_invocation` flag is already mirrored by
  `disable-model-invocation` in the `SKILL.md` frontmatter.
- Inlined cross-skill dependencies so each skill is self-contained, because
  skill-to-skill invocation is not guaranteed in every harness. Skills that
  originally said "Call the Skill tool with ..." now embed the referenced
  content directly.
- Dropped `ask-matt` (a pure router with no content of its own once its
  dispatch targets are inlined).
