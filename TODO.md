# TODO

## Rex

- [ ] Obtain Linux testing access through Discord `#alpha-registration`, then follow `docs/rex.md` to configure private source locations and the token outside the repository, cache and lock the external preview flake, and enable `dotfiles.rex.enable` on the desired hosts. Validate the real upstream package and service once access is available, and inspect its transitive lock entries for private URLs before committing. `./update --apply` refreshes the external flake before updating its pin.
- [ ] Deploy the macOS `rex-client` package with `./install` and verify Finder launch. `./update` reads the preview feed from the external private-source manifest; `./update --fetch rex-client` caches the hash-pinned installer without recording its URL in Git.

## Temporary pins and workarounds

- [ ] Replace `nix/packages/fnox.nix` and its overlay in `nix/modules/nix.nix` with plain `pkgs.fnox` once nixpkgs declares `aws-lc` and `sqlcipher` in its build inputs and `cache.nixos.org` has it. Until then nixpkgs' build fails on Hydra (`aws-lc-sys` finds no system AWS-LC), so the repo installs upstream's prebuilt release.

- [ ] `t3code-cli`: revisit `dontStrip = true` once stripping can preserve the embedded Node SEA payload; verify `t3 --version` and `t3 serve` before removing it. Retested 2026-11-01 with nixpkgs patchelf 0.19.2: stripping still truncates the SEA `NOTE` segment and `t3 --version` aborts.
- [x] Verify Vicinae opens with hardware rendering on Scylla after the `QT_QUICK_BACKEND=software` override removal; restore the override if it regresses. nixpkgs 0.29.2 carries the upstream fix (vicinaehq/vicinae#2055). The remaining software fallback came from `[QtQuickRendererSettings] SceneGraphBackend=software` in `kde/kdeglobals`, which the KDE platform theme propagates to every Qt Quick app; the group is now removed and cleaned from the live file on activation.
- [ ] kubelogin: reassess the 0.1.9 pin when newer releases persist the Ethos device-code token instead of re-prompting on every invocation. Upstream still treats legacy `spn:` logins as unsupported and recommends pinning 0.1.9.

## Obsidian Sync

`nix/users/carter/obsidian-sync.nix` runs `ob sync --continuous` for `Documents/Notes` on Scylla (bidirectional) and Prostagma (pull-only). Scylla's `~/.config/obsidian-headless` was seeded from Prostagma's `auth_token`; if sync starts failing with an expired session, run `ob login` there.

- [ ] Verify both hosts resume syncing after a reboot and that Scylla appears in the vault's version history as device `scylla`.

## El Toro

- [x] Deploy the integrated `eltoro` host with `./install-eltoro` and verify the Hermes gateway/dashboard, egress allowlist, and settings repair after the move from the standalone repo.
- [ ] Reassess the newer upstream `hermes-agent` packaging (reports `0.0.0`) before `./update` bumps the pinned rev.

## Claude Code

Claude Code is installed only on Scylla from `numtide/llm-agents.nix` and mirrors OpenCode's shared skills, MCP servers, and `agents/AGENTS.md`.

- [ ] Authenticate the `cloudflare` MCP server in Claude Code with `/mcp`; `claude mcp list` reports it needs authentication.

## Agent daemons

- [ ] Before re-enabling idle-compaction, restore and validate the user-selected timers in `opencode/opencode.jsonc` (54m for configured GPT-5.6+ models; 3m for Claude; 200k-token default with per-model overrides) and verify that a real Copilot session emits `session.compaction.ended` after admission and that the summary request reports cache reads. These are policies, not Copilot expiry guarantees; 54m exceeds OpenAI's documented 30m minimum.
- [ ] When re-enabling idle-compaction, temporarily set `options.logLevel` to `debug` to validate scheduling and skip reasons in T3's OpenCode server, then remove the override to restore its `info` default.
- [ ] Revisit idle-compaction background preparation when OpenCode exposes a plugin API to prepare/hold a summary without applying it. Current `session.compact()` can consume an existing built-in background summary, but cannot start one or defer applying it. Keep the global `experimental.background_compaction` flag unchanged so Go's behavior is untouched.
- [ ] Package the Cua Driver `darwin-universal` tarball for Carters-MacBook-Pro and install `CuaDriver.app` at `/Applications` so TCC can find it. Use the full tarball, not the `-binary` asset, which omits the app. `nix/packages/cua-driver.nix` currently ships only x86_64-linux, so OpenCode reports the shared `cua-driver` MCP entry as failed on hosts without the binary.
- [ ] Verify `opencode2`/`t3` survive a reboot on Scylla and deploy/verify them at login on Carters-MacBook-Pro. Scylla's manual `opencode2 serve --service` blocker is resolved.
- [x] Split macOS `./install` into a user-level build (OSC 7501 progress; root cannot open the user-owned Git checkout) and a root activation detached into its own session, so restarting T3/OpenCode cannot kill an installer they host before Home Manager reloads them. Activation stays in the GUI login session because nix-darwin needs the terminal's App Management permission; a system launchd job fails its `/Applications` check. Output streams live and persists under `~/Library/Logs/dotfiles-install/`.
- [ ] Validate a full `./install` from a T3/OpenCode session (requires administrator authentication) and confirm both agents reload.
- [ ] After deploying, confirm the managed `opencode2` agent/unit owns port 49374 (`launchctl print gui/$(id -u)/org.nix-community.home.opencode2` shows `state = running`, not `spawn scheduled`). Since at least Oct 27 a client-started server held the port and `serve --service` exited 0 every ~10s; the service now runs `opencode2 service stop` before serving.
- [ ] Pair clients per host whenever that host's `t3` service is running. `t3pair` uses Tailscale when its CLI is present and otherwise pairs locally. Without Tailscale, remote clients need an SSH tunnel to the loopback-only server on port 3773. Existing sessions survive restarts and downtime; re-pair only after `~/.t3` state loss, an origin/port change, or explicit revocation:
  - `t3pair --label phone` (scan the QR code)
  - `t3pair --label desktop` (add the environment in Settings → Connections)
  - Direct pairing is per host and per client, so two hosts × two clients means four initial links. T3 Connect is the only route that gives one sign-in per device across all hosts.
  - On a host that runs the `t3` service, turn off the desktop app's **Local environment** first so it attaches to the service instead of starting a second backend or failing on the shared `~/.t3`.
  - `opencode2`: create `tailscale serve --bg --https=9444 http://127.0.0.1:49374` once, then pair with `opencode2 pair --url https://<host>.dropbear-tortoise.ts.net:9444`.

## Cua Driver

Cua Driver gives an agent background control of GUI apps.
`nix/packages/cua-driver.nix` packages the upstream x86_64-linux binary, Scylla
runs `cua-driver serve` inside its Hyprland session, and OpenCode reaches that
daemon over its socket through the `cua-driver` MCP server.

- [ ] Reassess the optional Hyprland input plugin (`cua-hyprland-plugin`) when Cua qualifies apps beyond native Wayland Calc (`libreoffice-fresh 26.2.5-3`) and Inkscape (`1.4.4-6`); upstream 0.38.0 still ships it experimental, off by default, and ABI-pinned, and Scylla does not install it.

## Hex dictation

Handy is replaced by Hex: `nix/packages/hex.nix` pins Hex's prebuilt GitHub
releases, the macOS app and the Linux executable. On Linux the `programs.hex`
Home Manager module from the `anomalyco/hex` flake input drives it; macOS
installs the app system-wide with Hex's own updater turned off
(`DisableUpdates`). `./update` bumps both releases and the flake input's tag
together.

- [ ] Remove the PipeWire client config override in `nix/packages/hex.nix` once PipeWire's client `module-rt` stops setting a zero `RLIMIT_RTTIME` here. With the stock config, the ALSA plugin promotes Hex's data loop to realtime and the kernel SIGKILLs Hex the moment it runs (`code=killed, status=9/KILL`), for both the default microphone and Hex's sounds. The wrapper loads the stock client config with `module.rt = false`, which keeps dictation working without realtime scheduling; the PipeWire server keeps its own RT.
- [ ] Decide what to do with Handy's history and recordings under `~/.local/share/com.pais.handy`; nothing removes them.

macOS has no `hex-model-install` equivalent: its `model install` takes a model id
and drives the running app over its control socket, so a launchd job would race
the app. The app downloads its model during setup instead.
