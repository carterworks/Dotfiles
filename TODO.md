# TODO

## Rex

- [ ] Linux server support is removed until there is preview access (Discord `#alpha-registration`). Restore it from git history by reverting "rex: remove the gated Linux server module and package", "update: remove the private Rex server flake refresh" and "docs: trim the Rex guide to the macOS client".
- [ ] Deploy the macOS `rex-client` package with `./install` and verify Finder launch. `./update` reads the preview feed from the external private-source manifest; `./update --fetch rex-client` caches the hash-pinned installer without recording its URL in Git.

## Config file links

Home Manager now makes the links Dotbot made, into `~/.config/dotfiles`.

- [ ] Deploy to Scylla and the Mac and confirm no `*.hm-backup` files appeared and each link resolves through `home-manager-files`. On the Mac, activation stops at `dotfilesCheckout` if the checkout is not at `~/.config/dotfiles`.
- [ ] Delete the links Dotbot left that Home Manager does not own; nothing removes them: on the Mac the KDE, Hyprland, Quickshell and Vicinae links; on Scylla `~/.config/rex/init.lua` and the dangling `~/.local/bin` links to removed scripts; on prostagma all of them.
- [ ] Decide whether to stop tracking KDE files that hold application state rather than settings (`kconf_updaterc`, `KDE/UserFeedback.conf`, `kded6rc`, `kactivitymanagerdrc`, `kactivitymanagerd-statsrc`, `spectaclerc`, `arkrc`, `khelpcenterrc`, `dolphinrc`, `gwenviewrc`, `okularrc`, `kwinoutputconfig.json`).

## Temporary pins and workarounds

- [ ] Replace `nix/packages/fnox.nix` and its entry in `nix/packages/overlay.nix` with plain `pkgs.fnox` once nixpkgs declares `aws-lc` and `sqlcipher` in its build inputs and `cache.nixos.org` has it. Until then nixpkgs' build fails on Hydra (`aws-lc-sys` finds no system AWS-LC), so the repo installs upstream's prebuilt release.

- [ ] `t3code-cli`: revisit `dontStrip = true` once stripping can preserve the embedded Node SEA payload; verify `t3 --version` and `t3 serve` before removing it. Retested 2026-11-01 with nixpkgs patchelf 0.19.2: stripping still truncates the SEA `NOTE` segment and `t3 --version` aborts.
- [x] Verify Vicinae opens with hardware rendering on Scylla after the `QT_QUICK_BACKEND=software` override removal; restore the override if it regresses. nixpkgs 0.29.2 carries the upstream fix (vicinaehq/vicinae#2055). The remaining software fallback came from `[QtQuickRendererSettings] SceneGraphBackend=software` in `kde/kdeglobals`, which the KDE platform theme propagates to every Qt Quick app; the group is now removed and cleaned from the live file on activation.
- [ ] kubelogin: reassess the 0.1.9 pin when newer releases persist the Ethos device-code token instead of re-prompting on every invocation. Upstream still treats legacy `spn:` logins as unsupported and recommends pinning 0.1.9.

## Secrets

Prostagma's services read their secrets from fnox (`secrets/fnox.toml`, decrypted by `nix/modules/nixos/secrets.nix`); see `docs/secrets.md`.

- [ ] Deploy prostagma and follow "First deployment" in `docs/secrets.md`: confirm every `fnox-secret-*` unit, rename the ten old files and restart, then run the clean-up on prostagma and eltoro from the private list.
- [ ] Classify the unresolved files in the private clean-up list without opening them in a shared session; treat any old system backup in it as possibly holding an earlier SSH host key.
- [ ] Revoke at their source the credentials of services that are not in the Nix configuration, whether or not a hand-started container still uses them.
- [ ] Change the short account passwords to generated values if a person chose them (see "What the public repository reveals" in `docs/secrets.md`).
- [ ] After the clean-up, drop the `d /var/lib/secrets/bazarr` tmpfiles rule on prostagma; its files are now admin-only records in fnox.
- [ ] Move scylla's `truenas-smb` credential into fnox and back up scylla's SSH host keys admin-only (both need `sudo` on scylla).
- [ ] Each change to `secrets/fnox.toml`, even to an admin-only record, restarts every prostagma secret unit and the services that require them. If that becomes a nuisance, give each unit only its own entry of the store.

## Obsidian Sync

`nix/modules/home/obsidian-sync.nix` runs `ob sync --continuous` for `Documents/Notes` on Scylla (bidirectional) and Prostagma (pull-only). Scylla's `~/.config/obsidian-headless` was seeded from Prostagma's `auth_token`; if sync starts failing with an expired session, run `ob login` there.

- [ ] Verify both hosts resume syncing after a reboot and that Scylla appears in the vault's version history as device `scylla`.

## El Toro

- [x] Deploy the integrated `eltoro` host with `./install eltoro` and verify the Hermes gateway/dashboard, egress allowlist, and settings repair after the move from the standalone repo.
- [ ] Reassess the newer upstream `hermes-agent` packaging (reports `0.0.0`) before bumping the pinned rev. `flake.nix` names the rev in the input URL, so `./update` cannot move it; to bump, edit that rev and run `nix flake update hermes-agent`.
- [ ] After eltoro first switches to the chain-based egress firewall, delete the one-time migration block in `nix/hosts/eltoro/egress.nix` that strips the old generation's rules from `OUTPUT`. Remove or rewrite the egress test's "no rule survives from an earlier generation" and "a switch from the generation before the chain leaves only the chain" subtests in the same change; both exercise that block.
- [ ] Deploy the hardened egress fence and settings repair to eltoro following "Deploying fence changes" in `docs/eltoro.md` (snapshot, pre-flight `OUTPUT` check, then the post-deploy checks).
- [ ] Close DNS exfiltration from eltoro: hermes can send arbitrary names to the local resolver and MagicDNS, which forward them upstream as other users. Needs a filtering resolver.
- [ ] Stop the `hermes` CLI from being a root code-execution path: run as root with `HERMES_HOME` at the service home, it reads configuration hermes can write. Until fixed, admins must use `runuser --pty -u hermes -- hermes …` (see `docs/eltoro.md`).
- [ ] When deploying the KittenTTS removal, turn TTS off in eltoro's `/var/lib/hermes/.hermes/config.yaml`; its `tts.provider` still selects `kittentts`, which no longer exists.

## Claude Code

Claude Code is installed only on Scylla from `numtide/llm-agents.nix` and mirrors OpenCode's shared skills, MCP servers, and `agents/AGENTS.md`.

- [ ] Authenticate the `cloudflare` MCP server in Claude Code with `/mcp`; `claude mcp list` reports it needs authentication.

## Agent daemons

- [ ] Before re-enabling idle-compaction, restore and validate the user-selected timers in `opencode/opencode.jsonc` (54m for configured GPT-5.6+ models; 3m for Claude; 200k-token default with per-model overrides) and verify that a real Copilot session emits `session.compaction.ended` after admission and that the summary request reports cache reads. These are policies, not Copilot expiry guarantees; 54m exceeds OpenAI's documented 30m minimum.
- [ ] When re-enabling idle-compaction, temporarily set `options.logLevel` to `debug` to validate scheduling and skip reasons in T3's OpenCode server, then remove the override to restore its `info` default.
- [ ] Revisit idle-compaction background preparation when OpenCode exposes a plugin API to prepare/hold a summary without applying it. Current `session.compact()` can consume an existing built-in background summary, but cannot start one or defer applying it. Keep the global `experimental.background_compaction` flag unchanged so Go's behavior is untouched.
- [ ] Package the Cua Driver `darwin-universal` tarball for Carters-MacBook-Pro and install `CuaDriver.app` at `/Applications` so TCC can find it. Use the full tarball, not the `-binary` asset, which omits the app. `nix/packages/cua-driver.nix` currently ships only x86_64-linux, so OpenCode reports the shared `cua-driver` MCP entry as failed on hosts without the binary.
- [ ] Verify `opencode2`/`t3` survive a reboot on Scylla and deploy/verify them at login on Carters-MacBook-Pro. Scylla's manual `opencode2 serve --service` blocker is resolved.
- [x] Split macOS `./install` into a user-level build (OSC 7501 progress; root cannot open the user-owned Git checkout) and a root activation detached into its own process group, so restarting T3/OpenCode cannot kill an installer they host before Home Manager reloads them. Activation stays in the GUI login session because nix-darwin needs the terminal's App Management permission; a system launchd job fails its `/Applications` check. Output streams live and persists under `~/Library/Logs/dotfiles-install/`.
- [ ] Validate a full `./install` from a T3/OpenCode session (requires administrator authentication) and confirm both agents reload. Activation is now detached with bash job control (`set -m`, own process group, orphaned, HUP/INT/TERM ignored) instead of perl `setsid`; tests cover it only with a mocked `sudo`, so confirm on the Mac that it completes under real `sudo` when the hosting app restarts, that `~/Library/Logs/dotfiles-install/*/status` is `0`, and that the terminal is not left stopped or backgrounded.
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
- [ ] Decide what to do with Handy's history and recordings under `~/.local/share/com.pais.handy` (Scylla) and `~/Library/Application Support/com.pais.handy` (Mac); nothing removes them.
- [ ] On the Mac, delete Handy's speech models if they are still there: `~/.cache/huggingface/hub/models--handy-computer--*` and `~/Library/Application Support/com.pais.handy/models`. The activation step that cleared them is gone, and Scylla's are already removed.

macOS has no `hex-model-install` equivalent: its `model install` takes a model id
and drives the running app over its control socket, so a launchd job would race
the app. The app downloads its model during setup instead.

## Monitoring

- [ ] Add a Beszel hub and dashboard on prostagma, behind Authelia like the other dashboards, and Beszel agents on prostagma, Scylla and eltoro. Nothing on the Mac. On eltoro the agent may run as root; confirm the egress fence still restricts only Hermes and what acts for it. The prostagma agent should also record its Docker containers, systemd services, and whatever else Beszel can collect there, such as processes.
