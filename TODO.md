# TODO

## Watch items

Temporary pins and workarounds, each with the condition for removing it.

- [ ] `infra/truenas/versions.tf`: drop `insecure = true` once TrueNAS serves a certificate for its tailnet name; until then TLS is unverified and the provider trusts whichever tailnet device answers as `truenas`.
- [ ] `nix/packages/fnox.nix` (and its entry in `nix/packages/overlay.nix`): replace with plain `pkgs.fnox` once nixpkgs declares `aws-lc` and `sqlcipher` as build inputs and `cache.nixos.org` has the build; until then nixpkgs' build fails (`aws-lc-sys` finds no system AWS-LC).
- [ ] `nix/packages/t3code-cli.nix`: drop `dontStrip = true` once stripping keeps the embedded Node SEA payload; check `t3 --version` and `t3 serve`. On 2026-11-01, patchelf 0.19.2 still truncated the SEA `NOTE` segment.
- [ ] `nix/hosts/carters-macbook-pro/default.nix`: lift the kubelogin 0.1.9 pin when a newer release keeps the Ethos device-code token instead of prompting on every run; upstream still recommends 0.1.9 for legacy `spn:` logins.
- [ ] `nix/packages/fnox.nix`: fnox is held (`held = true` in its `updateInfo`), so the nightly reports new releases without taking them. Bump it deliberately with `./update --apply --held` after reading the release notes; the hold stays while fnox runs as root from an unsigned binary.
- [ ] `ATTIC_TOKEN` in the `binary-cache` GitHub Environment expires 90 days after it is minted, and nothing reminds you; on expiry every cache push fails and `release` freezes. Rotate it before then ([docs/binary-cache.md, rotate the CI token](docs/binary-cache.md#rotate-the-ci-token)). Remove this item once something rotates it or reminds you automatically.
- [ ] `flake.nix`: the `hermes-agent` input is held at a fixed rev. Before bumping it, check that upstream's newer packaging no longer reports version `0.0.0`; then edit the rev and run `nix flake update hermes-agent`.
- [ ] `nix/packages/hex.nix`: remove the PipeWire client override (`module.rt = false`) once PipeWire's client `module-rt` stops setting a zero `RLIMIT_RTTIME`; with the stock config the kernel kills Hex (`status=9/KILL`) as soon as it records or plays a sound.
- [ ] Rex's Linux server: restore it once there is preview access (Discord `#alpha-registration`) by reverting "rex: remove the gated Linux server module and package", "update: remove the private Rex server flake refresh" and "docs: trim the Rex guide to the macOS client".
- [ ] `opencode/idle-compaction/`: revisit background summary preparation when OpenCode's plugin API can prepare and hold a summary without applying it; leave the global `experimental.background_compaction` flag unchanged.
- [ ] `nix/packages/ardia.nix`: move to stable (drop `channel` and `requiredAssets`) once a stable Ardia release ships the Linux AppImage. Until then both machines follow nightlies, and `./update` skips any nightly that lacks the Linux or Mac build.
- [ ] `nix/hosts/prostagma/default.nix`: Immich is temporarily bound to `0.0.0.0` and allowed through the firewall on `immichPort` for LAN access from the Mac; revert both (and this item) once the Mac is back on the tailnet, since Tailscale Serve should stay the sole ingress.
- [ ] `nix/hosts/carters-macbook-pro/default.nix`: remove the `chmod -R u+w` `postActivation` hook for `Ardia.app/Contents/Resources/Plugins` once upstream Ardia's `PluginPrograms.payloadDigest` stops depending on the owner write bit (`0o200`).

- [ ] `nix/modules/home/agent-skills.nix`: remove `home.activation.agentSkillsMigration` once scylla and the Mac have each run `./install` with the module, which removes the old skill-sync script's links from `~/.claude/skills`.

## Follow-up work

- [x] Stop tracking KDE application state: `kde/` keeps only the settings Hyprland's KDE applications read, which `nix/hosts/scylla/apply-kde-config.py` merges into the live files instead of linking them ([docs/kde.md](docs/kde.md)).
- [ ] Purge the KDE state from the public history: stage 0 of [docs/rollout.md](docs/rollout.md#0-purge-kde-state-from-the-public-history), then GitHub Support and re-cloning scylla and the Mac.
- [ ] Mac `~/.copilot/mcp-config.json`: finish local MCP OAuth sign-in in Copilot and verify header-authenticated work servers from a fnox-activated shell.
- [ ] Roll out the fleet: follow [docs/rollout.md](docs/rollout.md), which also lists the decisions still open for it.
- [ ] `nix/hosts/eltoro/egress.nix`: delete the one-time block in `removeRules` that strips the pre-chain generation's rules from `OUTPUT`, together with the egress test's "no rule survives from an earlier generation" and "a switch from the generation before the chain leaves only the chain" subtests, which exercise it. eltoro runs a chain-based generation, so this can be done now.
- [x] `nix/hosts/prostagma/default.nix`: drop the `d /var/lib/secrets/bazarr` tmpfiles rule after the old secrets are removed (stage 7 of [docs/rollout.md](docs/rollout.md)); those files are now admin-only records in fnox.
- [ ] prostagma: find out why the Beszel agent does not report the Intel GPU, which `nix/hosts/prostagma/beszel.nix` configures from sysfs; the cause is unknown ("What each agent collects" in [docs/monitoring.md](docs/monitoring.md#what-each-agent-collects)).
- [ ] Move scylla's `truenas-smb` credential into fnox and back up scylla's SSH host keys as admin-only records; both need `sudo` on scylla ("Still outside fnox" in `docs/secrets.md`).
- [ ] eltoro: close DNS exfiltration. `hermes` can send any name to the local resolver and MagicDNS, which forward it upstream as another user; this needs a filtering resolver.
- [ ] eltoro: stop the `hermes` CLI from being a way to run code as root. Run as root with `HERMES_HOME` at the service home, it reads configuration `hermes` can write; until then admins use `runuser --pty -u hermes -- hermes …`.
- [ ] Re-enable idle-compaction in `opencode/opencode.jsonc`: restore the chosen timers (54 minutes for configured GPT-5.6+ models, 3 for Claude, a 200k-token default with per-model overrides), set `options.logLevel` to `debug` while validating, and confirm a real Copilot session emits `session.compaction.ended` after admission and its summary request reports cache reads; then remove the log override.
- [ ] Authenticate the `cloudflare` MCP server in Claude Code on scylla with `/mcp`; `claude mcp list` says it needs authentication.
- [ ] `nix/modules/home/workstation.nix`: remove the `~/.lmstudio/bin` PATH entry left over from LM Studio, which scylla no longer installs.
- [ ] prostagma: report a Postgres collation mismatch before it breaks a deploy, for example in `./drift`. After a glibc bump the next new database fails `postgresql-setup` and takes Immich down ([docs/binary-cache.md](docs/binary-cache.md#postgres-refuses-to-create-the-database)); the VM tests start from a fresh cluster and cannot see it.
- [ ] `nix/hosts/prostagma/default.nix`: correct the `tailscale-services` comment that says the unit fails until `svc:beszel` is approved; it succeeds. The comment is inside the unit's script, so the edit restarts the unit; make it with the next change to that file.
- [ ] `zsh/zshrc.zsh`: close the Fish parity gaps the scorecard (`tests/zsh/parity_scorecard.py`) still shows: Alt+Right stopping before `/`, Ctrl+Right accepting a whole argument, Ctrl+W deleting a path component, and `!!` expanding as you type.
- [ ] `zsh/zshrc.zsh`: port what the Fish plugins in `workstation.nix` add: fzf-fish's key bindings (files, git log, git status, processes, variables) and `done`'s notification when a long command finishes.
- [ ] `zsh/completions/`: add `_obsidian` once Obsidian's command-line interface is documented; running the binary to find out opens the app.
- [x] `infra/truenas/`: create a TrueNAS API key for OpenTofu and store it as `TRUENAS_TOFU_API_KEY` in fnox ([docs/truenas.md](docs/truenas.md)).
- [x] `infra/truenas/`: take the IDs and addresses shared with prostagma from one Nix value (`fleet.nasIds`, `fleet.lan` in `nix/lib/fleet.nix`).
- [x] `infra/truenas/`: adopt the rest of TrueNAS (system, network, services, alerts, apps, VM, certificate, privileges, share ACLs, pools).
- [x] `infra/truenas/shares.tf`: restrict every NFS export to prostagma.
- [x] prostagma: pin its LAN address (`fleet.lan.prostagma`); the router reserves it.
- [x] `nix/checks.nix`: fail when a `prevent_destroy` resource block disappears from `infra/truenas/` (`truenas-protected`).
- [x] `infra/truenas/acls.tf`: `builtin_users` (every SMB user) only reads media and `users/`, and no longer inherits into home directories.
- [ ] TrueNAS: delete the `@pre-builtin-users-read` snapshots of `reservoir/media` and `reservoir/users` (13) and `reservoir/users@pre-apps-users-drop`, all taken 2026-11-24 before ACL rewrites, once nothing has turned up missing access, say after 2026-12-08; the rewrite of `users/` also left a restore file in carter's `~/.local/state/acl-backups` on TrueNAS.
- [x] `infra/truenas/datasets.tf`: make `aclmode` consistent (`PASSTHROUGH`) across the media datasets.
- [x] `infra/truenas/acls.tf`: give `users/carter` and `users/whitley` to their users instead of root.
- [ ] Home Assistant: switch its TrueNAS integration to the key in `HOME_ASSISTANT_TRUENAS_API_KEY` (read-only, owned by `homeassistant`), then revoke carter's `home-assistant` key (id 2) once the audit log shows `home-assistant-readonly` logging in from `192.168.6.110`.
- [ ] Home Assistant: fix its nightly backups to TrueNAS; the newest backup in `users/homeassistant` is from 2025-10-13.
- [ ] TrueNAS: rotate the credentials a verification subagent printed into a session transcript on 2026-11-24: the Gmail OAuth client secret and refresh token (mail), the UPS monitor password, the SSH host keys and the `truenas_default` certificate's key.
- [ ] Proxmox: back up VM 101 with `vzdump` into TrueNAS's `users/proxmox/dump`, which Backrest copies off-site; its disk `users/proxmox/images/101/vm-101-disk-0.qcow2` is excluded from Backrest because a running disk copied as a file is not consistent.
## Awaiting a decision

- [ ] Backrest: back up the Immich library? `/mnt/truenas/photos` holds only an empty `immich/`, because the library is its own dataset (`reservoir/media/photos/immich`, about 743 GB), which that mount does not cross into.
- [ ] Rewrite the remaining tailnet addresses out of history? PR #7 removed them from the tree, but older commits still hold several, among them the TrueNAS mount's in `nix/hosts/scylla/default.nix` and `nix/machines/scylla.nix`; the KDE rewrite leaves them ([docs/history-rewrite.md](docs/history-rewrite.md)).
- [ ] Keep or delete Handy's history and recordings (`~/.local/share/com.pais.handy` on scylla, `~/Library/Application Support/com.pais.handy` on the Mac)? Nothing removes them.
- [ ] Give each prostagma secret unit only its own store entry, so that a change to `secrets/fnox.toml` no longer restarts every secret unit and the services that require them?
- [ ] Put a read-only Docker socket proxy in front of prostagma's Beszel agent, whose Docker access is equivalent to root ("What each agent collects" in `docs/monitoring.md`)?
- [ ] Bind `opencode2` to loopback on the workstations (`--hostname 0.0.0.0` in `nix/modules/home/agent-daemons.nix`) and reach it only through Tailscale Serve? Today the LAN reaches it behind a pairing password on Scylla, whose firewall is off and which holds the keys to both servers; clients would then always need Tailscale (decision 4 in [docs/rollout.md](docs/rollout.md)).
- [ ] Remove eltoro's `hermes-settings-repair` timer and its test? It is a root process in the agent's directory every minute, repairing only what running `hermes` as root breaks, which the docs forbid; without it such a slip stays broken until fixed by hand (decision 5 in [docs/rollout.md](docs/rollout.md)).
- [ ] Pin the `copyparty` input to release tags? It tracks upstream's default branch, so a nightly can bring unreleased code to a service the internet reaches through the Cloudflare tunnel; pinning means waiting for releases and moving the tag by hand (decision 6 in [docs/rollout.md](docs/rollout.md)).
- [ ] Advance `release` with a credential only `main`'s runs hold (a deploy key or GitHub App in the `binary-cache` Environment) and make it the bypass of a ruleset that restricts creating and updating `release`? Today anything that can push, a person or a workflow on any branch, can fast-forward `release` (GitHub refuses GitHub Actions as a bypass on a personal repository; "Stop `release` being rewound or deleted" in [docs/ci.md](docs/ci.md#what-you-set-up-once)); whether a ruleset here takes a deploy key or an app as a bypass actor is untested, and the cost is one more secret to rotate.
