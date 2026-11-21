# Zsh

Terminals, editors and the agent daemons on the workstations start zsh, set up
to behave like Fish. No account's login shell changes: each program is told
which shell to start ([why](https://tim.siosm.fr/blog/2023/12/22/dont-change-defaut-login-shell/)).
Root on the servers keeps Fish.

| Starts zsh | Where |
| --- | --- |
| Ghostty | `programs.ghostty.settings.command` in `nix/modules/home/workstation.nix` |
| Zed's terminal | `programs.zed-editor.userSettings.terminal.shell` in the same file |
| Zellij | `programs.zellij.settings.default_shell` in the same file |
| Herdr | `default_shell` in `herdr/config.toml` |
| Rex (Mac) | `Workspace.terminalStartupCommand` in `nix/hosts/carters-macbook-pro/default.nix` |
| `opencode2` and `t3` LaunchAgents (Mac) | `mkLaunchdAgent` in `nix/modules/home/agent-daemons.nix`, as a login shell for `PATH` |

## How it is put together

- `zsh/zshrc.zsh` is the whole interactive setup. Home Manager sources it from
  the checkout (`programs.zsh.initContent` in `workstation.nix`), so an edit
  applies to the next shell without a rebuild. That block also sets the plugin
  paths and holds the zsh versions of `oc`, `ocpw` and `mkcd`.
- Inline suggestions come from history (zsh-autosuggestions). Atuin's history,
  including what Fish recorded, is exported to `~/.cache/zsh/atuin-history.zsh`
  by `zsh/sync-atuin-history` in the background and read with `fc -R`, so
  suggesting never starts a process.
- Tab opens fzf-tab, drawn over the command line and styled like Fish's pager.
  Completions come from zsh, then Carapace, then the hand-written files in
  `zsh/completions/`, then Fish itself (`fish --no-config` with your Fish
  completion path, ~0.15 s) when nothing else has an answer.
- Colors come from your Fish theme: `zsh/fish-env-to-zsh` reads the Fish color
  variables and completion path once and caches the result, keyed on the Fish
  config, so a theme change reaches zsh after the next Home Manager switch.
- Startup takes about 120–170 ms against Fish's 450 ms; plugins, Carapace and
  Atuin load right after the first prompt is drawn. Every generated init
  script (Carapace, Atuin, Starship, zoxide, direnv, fnox, brew) is cached in
  `~/.cache/zsh`, keyed on the resolved binary, so an upgrade regenerates it.

## Changing it

- Try changes without touching your shell: `zsh/try` starts zsh with
  `zsh/zshrc.zsh`, plugins from nixpkgs, and history and caches in `zsh/dev/`.
- Turn off parts with environment variables: `ZSH_USE_FZF_TAB=0` (plain zsh
  menu), `ZSH_FISH_FEEL_NO_FISH_BRIDGE=1` (never ask Fish for completions).
- A program nothing completes: add `zsh/completions/_<program>` with a
  `#compdef` line. Hand-written files take precedence over Carapace. A program
  that prints its own zsh completions goes in `_zff_self_completions`; one that
  should complete like another command line goes in `_zff_completes_as`, and a
  Fish script in `~/.local/bin` with `function name --wraps='…'` is picked up
  automatically.
- `rm -rf ~/.cache/zsh` clears every cache; the next shell rebuilds them.

## Tests

`nix/checks.nix` (`zsh`) checks in CI that every zsh file parses and that the
config loads with the real plugins and registers each hand-written completion.
The rest needs a terminal, Fish and Atuin, so it runs on a workstation:

- `uv run --with tui-test --with pytest pytest tests/zsh/test_shell_ergonomics.py`
  drives `zsh/try` through tui-test and compares it with Fish (suggestions,
  arrow keys, the picker, colors, completions).
- `uv run --with tui-test python tests/zsh/parity_scorecard.py` scores Fish
  parity; `uv run --with tui-test python tests/zsh/completion_coverage.py`
  counts the programs each shell completes. Both write HTML to
  `tests/zsh/artifacts/`, and keep Fish's and Atuin's history out of the run.
