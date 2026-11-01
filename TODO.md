# TODO

## Rex

- [ ] Obtain Linux testing access through Discord `#alpha-registration`, then follow `docs/rex.md` to configure private source locations and the token outside the repository, cache and lock the external preview flake, and enable `dotfiles.rex.enable` on the desired hosts. Validate the real upstream package and service once access is available, and inspect its transitive lock entries for private URLs before committing. `./update --apply` refreshes the external flake before updating its pin.
- [ ] Deploy the macOS `rex-client` package with `./install` and verify Finder launch. `./update` reads the preview feed from the external private-source manifest; `./update --fetch rex-client` caches the hash-pinned installer without recording its URL in Git.

## Temporary pins and workarounds

- [ ] `t3code-cli`: revisit `dontStrip = true` once stripping can preserve the embedded Node SEA payload; verify `t3 --version` and `t3 serve` before removing it. Retested 2026-11-01 with nixpkgs patchelf 0.19.2: stripping still truncates the SEA `NOTE` segment and `t3 --version` aborts.
- [ ] Verify Vicinae opens with hardware rendering on Scylla after the `QT_QUICK_BACKEND=software` override removal; restore the override if it regresses. nixpkgs 0.29.2 carries the upstream fix (vicinaehq/vicinae#2055).
- [ ] kubelogin: reassess the 0.1.9 pin when newer releases persist the Ethos device-code token instead of re-prompting on every invocation. Upstream still treats legacy `spn:` logins as unsupported and recommends pinning 0.1.9.

## Agent daemons

- [ ] Package the Cua Driver `darwin-universal` tarball for Carters-MacBook-Pro and install `CuaDriver.app` at `/Applications` so TCC can find it. Use the full tarball, not the `-binary` asset, which omits the app. `nix/packages/cua-driver.nix` currently ships only x86_64-linux, so OpenCode reports the shared `cua-driver` MCP entry as failed on hosts without the binary.
- [ ] Verify `opencode2`/`t3` survive a reboot on Scylla and Prostagma (both units are enabled, active, and lingering) and deploy/verify them at login on Carters-MacBook-Pro. Scylla's manual `opencode2 serve --service` blocker is resolved.
- [ ] Pair clients per host whenever that host's `t3` service is running. `t3pair` uses Tailscale when its CLI is present and otherwise pairs locally. Without Tailscale, remote clients need an SSH tunnel to the loopback-only server on port 3773. Existing sessions survive restarts and downtime; re-pair only after `~/.t3` state loss, an origin/port change, or explicit revocation:
  - `t3pair --label phone` (scan the QR code)
  - `t3pair --label desktop` (add the environment in Settings → Connections)
  - Direct pairing is per host and per client, so three hosts × two clients means six initial links. T3 Connect is the only route that gives one sign-in per device across all hosts.
  - On a host that runs the `t3` service, turn off the desktop app's **Local environment** first so it attaches to the service instead of starting a second backend or failing on the shared `~/.t3`.
  - `opencode2`: create `tailscale serve --bg --https=9444 http://127.0.0.1:49374` once, then pair with `opencode2 pair --url https://<host>.dropbear-tortoise.ts.net:9444`.

## Cua Driver

Cua Driver gives an agent background control of GUI apps.
`nix/packages/cua-driver.nix` packages the upstream x86_64-linux binary, Scylla
runs `cua-driver serve` inside its Hyprland session, and OpenCode reaches that
daemon over its socket through the `cua-driver` MCP server.

- [ ] Reassess the optional Hyprland input plugin (`cua-hyprland-plugin`) when Cua qualifies apps beyond native Wayland Calc (`libreoffice-fresh 26.2.5-3`) and Inkscape (`1.4.4-6`); upstream 0.38.0 still ships it experimental, off by default, and ABI-pinned, and Scylla does not install it.

## Hex dictation

Handy is replaced by Hex: the `anomalyco/tap/hex` cask on macOS and a pinned
prebuilt Linux executable in `nix/packages/hex.nix`, driven by the
`programs.hex` Home Manager module from the `anomalyco/hex` flake input. The
executable, the flake input, and the cask all follow Hex's stable channel;
`./update` does not bump the executable, so update the version, URL, and hash
by hand together with the flake input's tag.

- [ ] Remove the PipeWire client config override in `nix/packages/hex.nix` once PipeWire's client `module-rt` stops setting a zero `RLIMIT_RTTIME` here. With the stock config, the ALSA plugin promotes Hex's data loop to realtime and the kernel SIGKILLs Hex the moment it runs (`code=killed, status=9/KILL`), for both the default microphone and Hex's sounds. The wrapper loads the stock client config with `module.rt = false`, which keeps dictation working without realtime scheduling; the PipeWire server keeps its own RT.
- [ ] Remove `home.activation.clearHandyModelCache` from `nix/users/carter/home-manager.nix` once every host has switched. It deletes Handy's `models--handy-computer--*` Hugging Face cache. Handy's history and recordings under `~/.local/share/com.pais.handy` are untouched and still need a manual decision.

macOS has no `hex-model-install` equivalent: its `model install` takes a model id
and drives the running app over its control socket, so a launchd job would race
the app. The cask app downloads its model during setup instead.
