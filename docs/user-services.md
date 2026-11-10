# User services

Programs that run in the owner's own session rather than as system services.

## T3 Code and OpenCode

`nix/modules/home/agent-daemons.nix` runs the `t3` and `opencode2` servers at
login on both workstations (a systemd user unit on scylla, a launchd agent on
the Mac). `opencode2` listens on port 49374 and stops any server a client
started (`opencode2 service stop`) before serving, so the managed one owns the
port.

Pair each client with each host whose `t3` service runs. Pairing is per host
and per client: two hosts and two clients make four links. T3 Connect is the
only route that gives one sign-in per device across all hosts. Sessions
survive restarts and downtime; pair again only after `~/.t3` is lost, the
origin or port changes, or a pairing is revoked.

- `t3pair --label phone`, then scan the QR code.
- `t3pair --label desktop`, then add the environment in Settings →
  Connections.
- `t3pair` uses Tailscale when its CLI is present and otherwise pairs locally.
  Without Tailscale, a remote client needs an SSH tunnel to the loopback-only
  server on port 3773.
- On a host that runs the `t3` service, first turn off the desktop app's
  **Local environment**, so it attaches to the service instead of starting a
  second backend or failing on the shared `~/.t3`.
- `opencode2`: once per host, `tailscale serve --bg --https=9444
  http://127.0.0.1:49374`, then pair with
  `opencode2 pair --url https://<host>.dropbear-tortoise.ts.net:9444`.

## Obsidian Sync

`nix/modules/home/obsidian-sync.nix` runs `ob sync --continuous` for
`~/Documents/Notes` on scylla (both ways) and prostagma (pull only). scylla's
`~/.config/obsidian-headless` was seeded from prostagma's login; if sync
starts failing with an expired session, run `ob login` on that host.

## Cua Driver

Cua Driver gives an agent background control of GUI apps.
`nix/packages/cua-driver.nix` packages the upstream x86_64-linux binary, scylla
runs `cua-driver serve` in its Hyprland session, and OpenCode reaches it
through the `cua-driver` MCP server. The Mac has no package yet, so OpenCode
reports that MCP server as failed there.

## Hex dictation

Hex replaces Handy. `nix/packages/hex.nix` pins Hex's prebuilt releases (the
macOS app and the Linux executable), and `./update` bumps both with the `hex`
flake input's tag. On scylla the `programs.hex` Home Manager module drives it;
the Mac installs the app system-wide with Hex's own updater off
(`DisableUpdates`).

The Mac has no `hex-model-install`: Hex's `model install` takes a model id and
drives the running app over its control socket, so a launchd job would race
the app. The app downloads its model during setup instead.
