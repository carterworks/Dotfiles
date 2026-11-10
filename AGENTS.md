# Repository instructions

## Task tracking

- Read `TODO.md` before starting work to understand pending repository tasks.
- Keep `TODO.md` current when working on a listed task: add relevant follow-up work and mark completed items with `[x]` after validation.
- Treat TODO entries as a backlog, not authorization to perform unrelated work. Follow the user's requested scope.
- `TODO.md` holds tasks only, one or two lines each, under three headings: watch items (temporary pins and workarounds, each naming its file and its removal condition), follow-up work, and suggestions awaiting a decision. Steps the owner must perform in order belong in `docs/rollout.md`, and explanations belong in the runbooks under `docs/`.

## Secrets

- Secrets are managed and encrypted with fnox in this repository (`secrets/fnox.toml`).
- No secret is ever committed in plain text, placed by hand on a host, or written into the Nix store.
- A service that needs a secret gets it through the shared module, `nix/modules/nixos/secrets.nix`.
- See `docs/secrets.md` for adding, rotating and deploying secrets, and the commands that never put a value on screen.
