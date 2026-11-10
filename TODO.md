# TODO

- [ ] Roll out the fleet: follow [docs/rollout.md](docs/rollout.md), which also lists the decisions still open for it.

## Watch items

Temporary pins and workarounds, each with the condition for removing it.

- [ ] `nix/packages/fnox.nix` (and its entry in `nix/packages/overlay.nix`): replace with plain `pkgs.fnox` once nixpkgs declares `aws-lc` and `sqlcipher` as build inputs and `cache.nixos.org` has the build; until then nixpkgs' build fails (`aws-lc-sys` finds no system AWS-LC).
- [ ] `nix/packages/t3code-cli.nix`: drop `dontStrip = true` once stripping keeps the embedded Node SEA payload; check `t3 --version` and `t3 serve`. On 2026-11-01, patchelf 0.19.2 still truncated the SEA `NOTE` segment.
- [ ] `nix/hosts/carters-macbook-pro/default.nix`: lift the kubelogin 0.1.9 pin when a newer release keeps the Ethos device-code token instead of prompting on every run; upstream still recommends 0.1.9 for legacy `spn:` logins.
- [ ] `nix/packages/fnox.nix`: fnox is held (`held = true` in its `updateInfo`), so the nightly reports new releases without taking them. Bump it deliberately with `./update --apply --held` after reading the release notes; the hold stays while fnox runs as root from an unsigned binary.
- [ ] `ATTIC_TOKEN` in the `binary-cache` GitHub Environment expires 90 days after it is minted, and nothing reminds you; on expiry every cache push fails and `release` freezes. Rotate it before then ([docs/binary-cache.md, rotate the CI token](docs/binary-cache.md#rotate-the-ci-token)). Remove this item once something rotates it or reminds you automatically.
- [ ] `flake.nix`: the `hermes-agent` input is held at a fixed rev. Before bumping it, check that upstream's newer packaging no longer reports version `0.0.0`; then edit the rev and run `nix flake update hermes-agent`.
- [ ] `nix/packages/hex.nix`: remove the PipeWire client override (`module.rt = false`) once PipeWire's client `module-rt` stops setting a zero `RLIMIT_RTTIME`; with the stock config the kernel kills Hex (`status=9/KILL`) as soon as it records or plays a sound.
- [ ] Cua's Hyprland input plugin (`cua-hyprland-plugin`): reconsider installing it on scylla once Cua qualifies apps beyond Calc and Inkscape; 0.38.0 still ships it experimental, off by default and ABI-pinned.
- [ ] Rex's Linux server: restore it once there is preview access (Discord `#alpha-registration`) by reverting "rex: remove the gated Linux server module and package", "update: remove the private Rex server flake refresh" and "docs: trim the Rex guide to the macOS client".
- [ ] `opencode/idle-compaction/`: revisit background summary preparation when OpenCode's plugin API can prepare and hold a summary without applying it; leave the global `experimental.background_compaction` flag unchanged.

## Follow-up work

- [ ] `nix/hosts/eltoro/egress.nix`: delete the one-time block in `removeRules` that strips the pre-chain generation's rules from `OUTPUT`, together with the egress test's "no rule survives from an earlier generation" and "a switch from the generation before the chain leaves only the chain" subtests, which exercise it. Do it once eltoro is settled on a chain-based generation (decision 1 in [docs/rollout.md](docs/rollout.md)).
- [ ] `nix/hosts/prostagma/default.nix`: drop the `d /var/lib/secrets/bazarr` tmpfiles rule after the old secrets are removed (rollout stage 7); those files are now admin-only records in fnox.
- [ ] Move scylla's `truenas-smb` credential into fnox and back up scylla's SSH host keys as admin-only records; both need `sudo` on scylla ("Still outside fnox" in `docs/secrets.md`).
- [ ] eltoro: close DNS exfiltration. `hermes` can send any name to the local resolver and MagicDNS, which forward it upstream as another user; this needs a filtering resolver.
- [ ] eltoro: stop the `hermes` CLI from being a way to run code as root. Run as root with `HERMES_HOME` at the service home, it reads configuration `hermes` can write; until then admins use `runuser --pty -u hermes -- hermes …`.
- [ ] Package Cua Driver's `darwin-universal` tarball (not the `-binary` asset, which lacks the app) for the Mac and install `CuaDriver.app` in `/Applications`, so TCC can find it; `nix/packages/cua-driver.nix` is x86_64-linux only.
- [ ] Re-enable idle-compaction in `opencode/opencode.jsonc`: restore the chosen timers (54 minutes for configured GPT-5.6+ models, 3 for Claude, a 200k-token default with per-model overrides), set `options.logLevel` to `debug` while validating, and confirm a real Copilot session emits `session.compaction.ended` after admission and its summary request reports cache reads; then remove the log override.
- [ ] Authenticate the `cloudflare` MCP server in Claude Code on scylla with `/mcp`; `claude mcp list` says it needs authentication.
- [ ] `nix/modules/home/workstation.nix`: remove the `~/.lmstudio/bin` PATH entry left over from LM Studio, which scylla no longer installs.

## Awaiting a decision

- [ ] Stop tracking KDE files that hold application state rather than settings (`kconf_updaterc`, `KDE/UserFeedback.conf`, `kded6rc`, `kactivitymanagerdrc`, `kactivitymanagerd-statsrc`, `spectaclerc`, `arkrc`, `khelpcenterrc`, `dolphinrc`, `gwenviewrc`, `okularrc`, `kwinoutputconfig.json`)?
- [ ] Keep or delete Handy's history and recordings (`~/.local/share/com.pais.handy` on scylla, `~/Library/Application Support/com.pais.handy` on the Mac)? Nothing removes them.
- [ ] Give each prostagma secret unit only its own store entry, so that a change to `secrets/fnox.toml` no longer restarts every secret unit and the services that require them?
- [ ] Put a read-only Docker socket proxy in front of prostagma's Beszel agent, whose Docker access is equivalent to root ("What each agent collects" in `docs/monitoring.md`)?
- [ ] Bind `opencode2` to loopback on the workstations (`--hostname 0.0.0.0` in `nix/modules/home/agent-daemons.nix`) and reach it only through Tailscale Serve? Today the LAN reaches it behind a pairing password on Scylla, whose firewall is off and which holds the keys to both servers; clients would then always need Tailscale (decision 6 in [docs/rollout.md](docs/rollout.md)).
- [ ] Remove eltoro's `hermes-settings-repair` timer and its test? It is a root process in the agent's directory every minute, repairing only what running `hermes` as root breaks, which the docs forbid; without it such a slip stays broken until fixed by hand (decision 7).
- [ ] Pin the `copyparty` input to release tags? It tracks upstream's default branch, so a nightly can bring unreleased code to a service the internet reaches through the Cloudflare tunnel; pinning means waiting for releases and moving the tag by hand (decision 8).
- [ ] Advance `release` with a credential only `main`'s runs hold (a deploy key or GitHub App in the `binary-cache` Environment) and make it the rulesets' only bypass? Today any workflow pushed to any branch runs as GitHub Actions and can fast-forward `release` ("Protect `release`" in [docs/ci.md](docs/ci.md#what-you-set-up-once)); the cost is one more secret to rotate.
