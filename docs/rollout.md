# Rollout

What is left of the owner's first rollout of the fleet configuration, in order.
Pull requests #3 and #4 are merged, all four hosts are deployed from `main`,
the cache `fleet` exists, and Nightly is active on `main` (2026-11-10), though
GitHub has not started it on its schedule yet (2026-11-11). Nothing updates the
servers until stage 5 is done: `release` does not exist, and their unattended
upgrade is off until the cache's public key is set. Each step
names what to do and links to the runbook section that has the commands. You
can stop safely at the end of any stage. **No return** marks a step that cannot
simply be undone.

## Decisions still open

1. **Backups of prostagma's `/srv/apps`.** The cache's signing key, the Beszel
   hub's key and every agent token live there. The runbooks assume "whatever
   backs up `/srv/apps`", and none says what that is or how it is protected.
2. **A branch rule on `main`.** Nothing reviews a push to `main`, and GitHub
   takes no bypass for GitHub Actions on a personal repository, so a rule
   would need Nightly to push with another credential
   ([CI, trust roots](ci.md#trust-roots)).
3. **Short account passwords.** Change them only if a person chose them
   ([Secrets](secrets.md#what-the-public-repository-reveals)).
4. **`opencode2` on the LAN.** On both workstations it listens on every
   interface (`--hostname 0.0.0.0` in `nix/modules/home/agent-daemons.nix`),
   and Scylla's firewall is off, so anything on the LAN reaches it behind only
   its pairing password, on the machine that holds the keys to both servers.
   Binding it to loopback and reaching it through Tailscale Serve, as
   [User services](user-services.md#t3-code-and-opencode) already describes,
   closes that; a client would then always need Tailscale.
5. **`hermes-settings-repair` on eltoro.** This timer is a root process working
   inside the agent's own directory every minute, and it only repairs what
   running the `hermes` CLI as root breaks, which the docs now say never to do.
   Removing it and its test takes a root process out of the agent's territory;
   a slip with the CLI as root would then stay broken until fixed by hand.
6. **`copyparty`'s input.** It tracks upstream's default branch, so any
   nightly can bring unreleased code to a service the internet reaches through
   the Cloudflare tunnel. Pinning it to release tags narrows that, at the cost
   of waiting for releases and moving the tag by hand.

## 1. Push access

These matter more now: anything that can push can create or fast-forward
`release`, and the servers run what it holds
([CI, trust roots](ci.md#trust-roots)). The repository's API shows Carter as
the only collaborator, with no deploy keys and no webhooks (2026-11-10); it
cannot show the two checks below.

1. Rotate the GitHub CLI's token on scylla: revoke it on GitHub, then
   `gh auth login`. It appeared in an agent's session transcript, and older
   versions of `./install` put it on `sudo`'s command line, which Scylla's
   journal recorded.
2. Check your personal access tokens, and the credential Hermes holds, for push
   access to the repository.

## 2. scylla

1. Reboot: a new kernel has been pending since before 2026-11-10. Then confirm
   `opencode2` and `t3` are running and Obsidian Sync resumed, with scylla in
   the vault's version history ([User services](user-services.md)).
2. Confirm `./install` left no new `*.hm-backup` files and every config link
   resolves through `home-manager-files`
   ([README, config files](../README.md#config-files)). The 31 `*.hm-backup`
   files from before 2026-11-10 come from earlier Home Manager runs and can be
   deleted. Delete the links Dotbot left that Home Manager does not own:
   `~/.config/rex/init.lua` and the dangling links in `~/.local/bin`,
   `~/.config`, `~/.claude` and `~/.agents`.

## 3. Monitoring

1. In the Tailscale admin console, approve the `svc:beszel` Service if it is
   not approved yet, and grant it to you, scylla and eltoro by name
   ([Monitoring](monitoring.md#first-deployment) step 2). Until then the
   dashboard does not answer and the scylla and eltoro agents cannot reach the
   hub.
2. Confirm the dashboard lists prostagma, scylla and eltoro as `up`.
3. On eltoro, confirm `hermes` is still blocked from the hub's address while
   root reaches it ([El Toro, post-deploy checks](eltoro.md#deploying-fence-changes)).
4. Back up the hub's private key; losing it means a new key and redeploying
   every agent ([Monitoring, data and backups](monitoring.md#data-and-backups),
   decision 1).

## 4. Servers

1. prostagma: log in to Authelia, copyparty, qBittorrent, Immich and
   Audiobookshelf. In Immich, check search and faces after the reindex
   ([Binary cache, Postgres](binary-cache.md#postgres-refuses-to-create-the-database)).
2. prostagma: delete every link Dotbot left in carter's home; Home Manager owns
   none of them.
3. eltoro: confirm the agent still answers on Discord.

## 5. Binary cache and `release`

Until step 1 is done, every Fleet run on `main` is red in its `release` job
("Not every host pushed"), and every Nightly that merges an update is red with
"a binary-cache Environment secret is unset" ([CI, when it goes
red](ci.md#when-it-goes-red)). On 2026-11-11 the Environment held only
`ATTIC_TOKEN`.

1. Add `tag:ci` to the tailnet policy with its tests, check the whole policy,
   and create the OAuth client with the `auth_keys` write scope and the tag
   `tag:ci` only. Store its ID and secret as `TS_OAUTH_CLIENT_ID` and
   `TS_OAUTH_SECRET` in the `binary-cache` Environment, next to `ATTIC_TOKEN`
   ([Tailscale policy](binary-cache.md#tailscale-policy-you)). Check by name
   only: `gh secret list --repo carterworks/dotfiles --env binary-cache` lists
   all three, and `gh secret list --repo carterworks/dotfiles` lists none of
   them ([Binary cache, step 0](binary-cache.md#0-github-environment-before-merging-the-ci-workflows-you)).
2. Put a reminder in your calendar for about 2027-01-30 to
   [rotate `ATTIC_TOKEN`](binary-cache.md#rotate-the-ci-token), which expires
   2027-02-08. After that every push fails and `release` stops moving.
3. Create `release`: run Fleet on `main`
   (`gh workflow run fleet.yml --repo carterworks/dotfiles --ref main`) and
   confirm that no host job warns "Cache push skipped" or "Cache unreachable",
   the `release` job is green, and
   `git ls-remote --heads https://github.com/carterworks/dotfiles release`
   prints `main`'s commit
   ([CI, from a push to a server](ci.md#from-a-push-to-a-server)). The
   `release: no rewrite` ruleset is already active (2026-11-11).
   **No return**: whatever reaches `main` now reaches `release`.
4. Confirm the nightly loop: the morning after, the latest scheduled Nightly
   run is from the last day, green, and reads "main and release are now
   `<commit>`." or "Nothing to update." If there is no scheduled run, follow
   [CI, when Nightly does not start](ci.md#when-nightly-does-not-start).
5. Set the cache's public key, `fleet:FxyZ66qA3l/VyllFphclDlUz1qULGhYdDaXjWHeg+MU=`
   (check it against `attic cache info prostagma:fleet`), as the default of
   `dotfiles.binaryCache.publicKey` in `nix/modules/nixos/binary-cache.nix`,
   commit it to `main`, and deploy scylla, prostagma and eltoro by hand
   ([Binary cache, turn the client on](binary-cache.md#turn-the-client-on)).
   eltoro reaches the cache under the current tailnet policy (checked
   2026-11-10); if the policy has changed since, check again first.
   **No return**: both servers now upgrade themselves to `release` every night
   ([Server auto-upgrade](auto-upgrade.md)). Check
   `systemctl list-timers nixos-upgrade.timer` on prostagma and eltoro shows
   the next run.

## 6. The Mac

1. Confirm Rex opens from Finder ([Rex](rex.md#macos-client)).
2. Run the same link checks as on scylla (stage 2, step 2). Delete Dotbot's
   leftover KDE, Hyprland, Quickshell and Vicinae links, and Handy's speech
   models (`~/.cache/huggingface/hub/models--handy-computer--*`,
   `~/Library/Application Support/com.pais.handy/models`).
3. Confirm the managed `opencode2` owns port 49374:
   `launchctl print gui/$(id -u)/org.nix-community.home.opencode2` shows
   `state = running`.
4. Check that `vault` 2.2.1 (up from 2.0.3) still works against the work Vault
   server.
5. Pair each client with each host ([User services](user-services.md#t3-code-and-opencode)).

## 7. Remove old secrets

Wait until the services have run on the new secrets through a reboot or an
unattended upgrade.

1. **No return:** delete the ten renamed files on prostagma
   ([Secrets, clean-up](secrets.md#clean-up-removing-the-old-plain-text-files)).
2. Classify the unresolved entries in the private clean-up list
   (`~/.config/dotfiles-private/secrets-cleanup.md`) without opening them in a
   shared session. Treat an old system backup as possibly holding an earlier
   SSH host key.
3. **No return:** run the private list's removals on prostagma and eltoro.
   Never touch `/var/lib/secrets/attic/`, the cache's own secret.
4. Revoke at their source the credentials of services that are not in the Nix
   configuration, whether or not a hand-started container still uses them.
5. Change the short passwords, if decision 3 says so
   ([Secrets, rotate a secret](secrets.md#rotate-a-secret)).
6. Two leftovers on prostagma are not secrets and can go any time:
   `/root/reindex`, and the unreferenced store paths, which a garbage
   collection removes.

## Confirm the end state

- From scylla, `./drift` lists scylla, prostagma and eltoro as `in sync` with
  `release`, with no `FAILED UNITS` on any line, and exits 0
  ([Server auto-upgrade, when it fails](auto-upgrade.md#when-it-fails)).
  The Mac is not checked; run `./install` there.
- The latest Nightly run is green and its summary reads "main and release are
  now `<commit>`." or "Nothing to update.", with no problems listed below it
  ([CI, when it goes red](ci.md#when-it-goes-red)).
- On prostagma and eltoro, the morning after: `systemctl --failed` is empty,
  `systemctl list-timers nixos-upgrade.timer` shows the next run, and
  `journalctl -u nixos-upgrade.service` shows a switch to `release` with
  nothing built locally.
- On every Linux host, `nix config show substituters` lists the fleet cache
  ([Binary cache, turn the client on](binary-cache.md#turn-the-client-on)).
- The Beszel dashboard lists prostagma, scylla and eltoro as `up`.
- On eltoro, the post-deploy fence checks still pass
  ([El Toro](eltoro.md#deploying-fence-changes)).
