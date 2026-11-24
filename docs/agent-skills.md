# Agent skills

Home Manager installs the same skills for Claude Code, OpenCode and Copilot CLI
on both workstations (`nix/modules/home/agent-skills.nix`).

## Where they go

- `~/.claude/skills/<name>`: Claude Code reads it, and so does OpenCode.
- `~/.copilot/skills/<name>`: Copilot CLI, which no longer reads `~/.claude`.

Nothing is installed in `~/.agents/skills` or `~/.config/opencode/skills`.
OpenCode reads both, so a skill there would be listed twice. Each skill is one
link, so whatever other tools put in these folders (claude.ai's `synced/`,
`ardia`, `imagegen`) stays put. Home Manager removes the links a previous
generation made.

## Sources

| Source | Pinned by | Installed from |
|---|---|---|
| `agents/skills/personal/` | the checkout | live links, so edits apply without `./install` |
| `agents/skills/generated/` | the tool packages; `./update` regenerates them | live links |
| [tstack](https://github.com/t3dotgg/tstack) | the `tstack` flake input, its default branch | `nix/packages/tstack-skills.nix` |
| [Matt Pocock's skills](https://github.com/mattpocock/skills) | the `mattpocock-skills` input, a release tag | `nix/packages/mattpocock-skills.nix` |
| [Modern Web Guidance](https://developer.chrome.com/docs/modern-web-guidance) | the npm version in `nix/packages/modern-web-guidance.nix` | that package |
| [animations.dev](https://animations.dev) | nothing; the account decides | `~/.local/state/agent-skills/animations-dev/current/` |

The nightly bumps all of them except animations.dev. Upstream skill text is
not committed, so an update shows up as a `flake.lock` or version change, not
as a diff of the text.

The package files list which upstream skills are installed. A name that differs
from upstream's folder renames the skill: its frontmatter `name` and the
references to it from the other skills in that package. Pocock's
`code-review`, `prototype` and `research` are installed as `mp-code-review`,
`mp-prototype` and `mp-research`, and animations.dev's `prototype` as
`ad-prototype`, because Claude Code's built-in `/code-review` and `/prototype`
and Copilot's `/research` would hide them. Two sources providing the same name
fail evaluation.

Modern Web Guidance's own skill tells the agent to run
`npx -y modern-web-guidance@latest`. The package rewrites it to call the
pinned, offline CLI, which has its telemetry turned off and refuses its own
`install`, `update` and `uninstall` commands. If upstream rewords the skill so
the rewrite no longer matches, the build fails.

## animations.dev

The skills are paid content and the repository is public, so they never go
into Git, the Nix store or the binary cache. Home Manager's activation syncs
them into `~/.local/state/agent-skills/animations-dev/current/` automatically
during `./install`.

Activation decrypts `ANIMATIONS_DEV_TOKEN` (fnox provider `workstations`) using
`~/.config/fnox/age.txt` on Linux or the macOS Keychain (`fnox` / `age-key`) on
macOS, and pipes it to `agents/animations-dev/sync.py` on stdin so it never
appears on the screen or in a command line. The fetcher calls
`https://animations.dev/api/install` and never follows a redirect. It rejects
skill and file names that are not plain names, and it writes atomically to the
state folder. If the machine is offline or has no key, activation warns and
keeps any existing copy.

It fails the sync if the account no longer provides a skill the module links,
and lists skills the account has that the module does not link. Add those to
`animationsDev.skills` in `nix/modules/home/agent-skills.nix`.

Upstream's installer, `npx @animationsdev/install --token=…`, sends the token
over plain http before the redirect to https, so do not use it.

## Add a skill

- Your own: add a folder with a `SKILL.md` under `agents/skills/personal/`.
  Its link appears after `./install` once Git tracks it.
- From tstack or Pocock: add its folder to the list in the package file.
- From another repository: add a flake input with `flake = false`, copy one of
  the package files, add the package to `nix/packages/overlay.nix` and to
  `sources` in the module.
