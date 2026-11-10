# Rollout

The owner's steps from "pull request #3 is ready" to "the fleet runs
unattended", in order. Each step names what to do and links to the runbook
section that has the commands; this page has none of its own. You can stop
safely at the end of any stage. **No return** marks a step that cannot simply be
undone.

## Decisions still open

1. **eltoro's current generation.** On 2026-11-10 a test switched eltoro to
   this branch's configuration, chain-based fence included, without the
   [fence checklist](eltoro.md#deploying-fence-changes). Its state was checked
   read-only afterwards and looked right. Keep it (then step 1.5 is short), or
   roll back to the generation before it and make the first switch with the
   checklist in step 3.2.
2. **eltoro and the cache.** If the tailnet policy should not let eltoro reach
   `prostagma:8199`, its cache client stays off, and with it eltoro's
   unattended upgrades ([Binary cache, step 2](binary-cache.md#2-create-the-cache-and-read-its-public-key-you)).
3. **Backups of prostagma's `/srv/apps`.** The cache's signing key, the Beszel
   hub's key and every agent token live there. The runbooks assume "whatever
   backs up `/srv/apps`", and none says what that is or how it is protected.
4. **A branch rule on `main`.** Nothing reviews a push to `main`; a rule would
   need a bypass for Nightly's own push ([CI, trust roots](ci.md#trust-roots)).
5. **Short account passwords.** Change them only if a person chose them
   ([Secrets](secrets.md#what-the-public-repository-reveals)).
6. **`opencode2` on the LAN.** On both workstations it listens on every
   interface (`--hostname 0.0.0.0` in `nix/modules/home/agent-daemons.nix`),
   and Scylla's firewall is off, so anything on the LAN reaches it behind only
   its pairing password, on the machine that holds the keys to both servers.
   Binding it to loopback and reaching it through Tailscale Serve, as
   [User services](user-services.md#t3-code-and-opencode) already describes,
   closes that; a client would then always need Tailscale.
7. **`hermes-settings-repair` on eltoro.** This timer is a root process working
   inside the agent's own directory every minute, and it only repairs what
   running the `hermes` CLI as root breaks, which the docs now say never to do.
   Removing it and its test takes a root process out of the agent's territory;
   a slip with the CLI as root would then stay broken until fixed by hand.
8. **`copyparty`'s input.** It tracks upstream's default branch, so any
   nightly can bring unreleased code to a service the internet reaches through
   the Cloudflare tunnel. Pinning it to release tags narrows that, at the cost
   of waiting for releases and moving the tag by hand.

## 1. Before merging

Nothing here deploys anything.

1. Audit everything that can push to the repository: it can reach `main`, and
   later the servers ([CI, trust roots](ci.md#trust-roots)).
2. Create the `binary-cache` GitHub Environment limited to `main`, and check
   that no repository secret has one of its secrets' names
   ([Binary cache, step 0](binary-cache.md#0-github-environment-before-merging-the-ci-workflows-you)).
   It must exist before the merge: the first run on `main` would otherwise
   create it empty and without the branch rule.
3. Require approval for all outside contributors' workflow runs
   ([CI, item 2](ci.md#what-you-set-up-once)).
4. Rotate the GitHub CLI's token on scylla: revoke it on GitHub, then
   `gh auth login`. It appeared in an agent's session transcript, and older
   versions of `./install` put it on `sudo`'s command line, which Scylla's
   journal recorded.
5. Settle decision 1. If eltoro keeps its generation, rerun the post-deploy
   checks ([El Toro](eltoro.md#deploying-fence-changes)) and remove, or reboot
   away, the one leftover `-A OUTPUT -o lo -j ACCEPT` rule from the old
   generation in both address families.
6. On eltoro, turn TTS off in `/var/lib/hermes/.hermes/config.yaml`, as
   `hermes` ([El Toro, changing settings](eltoro.md#changing-settings)). Its
   `tts.provider` still names KittenTTS, which the running generation no
   longer has.

## 2. Merge

1. Approve and merge pull request #3. **No return** in one sense: from now on
   Nightly updates `main` and merges the result on its own every night
   ([CI, the nightly loop](ci.md#the-nightly-loop)). No server changes yet:
   without the cache's secrets, runs report "Cache push skipped" and `release`
   does not exist.

## 3. Deploy the servers by hand

1. Deploy prostagma from scylla. This one deploy moves its services to secrets
   from fnox, starts the cache server and starts the Beszel hub with no
   systems. Run all three runbooks' checks:
   [Secrets, prostagma](secrets.md#prostagma) steps 1 to 5 (which also rename
   the ten old files, still reversibly),
   [Binary cache, step 1](binary-cache.md#1-first-deployment-you) and
   [Monitoring](monitoring.md#first-deployment) step 1.
2. Deploy eltoro from scylla. If you rolled it back (decision 1), follow the
   whole [fence checklist](eltoro.md#deploying-fence-changes); this must happen
   before the cache key is set in stage 4, because the key turns on unattended
   upgrades.
3. Run `./install` on scylla ([README](../README.md#deploy-by-hand)).
4. Approve the `svc:beszel` Service and grant it in the tailnet policy, then
   open the dashboard ([Monitoring](monitoring.md#first-deployment) steps 2
   and 3).

## 4. Binary cache and `release`

The order below creates `release` before the key turns on upgrades, so no
server fails a night for lack of it. Setting the key first is also safe; see
[Binary cache, turn the client on](binary-cache.md#turn-the-client-on).

1. Create the cache and check that eltoro can reach it
   ([Binary cache, step 2](binary-cache.md#2-create-the-cache-and-read-its-public-key-you),
   up to "Turn the client on"; decision 2).
2. Mint the push token into the Environment
   ([step 3](binary-cache.md#3-tokens-you)).
3. Add `tag:ci` to the tailnet policy, check the whole policy, and create the
   OAuth client ([Tailscale policy](binary-cache.md#tailscale-policy-you)).
4. Run Fleet on `main` and confirm that all three hosts pushed and `release`
   was created ([CI, from a push to a server](ci.md#from-a-push-to-a-server)).
   **No return**: whatever reaches `main` now reaches `release`.
5. Set the cache's public key, commit it to `main`, and deploy scylla,
   prostagma and eltoro by hand
   ([Binary cache, turn the client on](binary-cache.md#turn-the-client-on)).
   **No return**: both servers now upgrade themselves to `release` every night
   ([Server auto-upgrade](auto-upgrade.md)). Precondition: stage 3.2.

## 5. Monitoring

Independent of stage 4; it needs only stage 3.

1. Enrol scylla and eltoro in fnox, confirming each host key's fingerprint on
   that host's own console
   ([Monitoring](monitoring.md#first-deployment) step 5).
2. Make all three agent tokens (step 6). The hub reads every token at start, so
   with one missing it does not start.
3. Read the hub's key and set it, in the same commit as steps 1 and 2, then
   deploy (steps 4 and 7). Confirm all three hosts are `up` (step 8).
4. On prostagma, check whether the container exposes temperatures and Intel GPU
   data; neither can be tested in a VM.
5. Back up the hub's private key; losing it means a new key and redeploying
   every agent ([Monitoring, data and backups](monitoring.md#data-and-backups),
   decision 3).

## 6. Workstations

1. scylla: confirm `./install` left no `*.hm-backup` files and every config
   link resolves through `home-manager-files`
   ([README, config files](../README.md#config-files)). Delete the links Dotbot
   left that Home Manager does not own: `~/.config/rex/init.lua` and the
   dangling links in `~/.local/bin`.
2. scylla: reboot, then confirm `opencode2` and `t3` are running and Obsidian
   Sync resumed, with scylla in the vault's version history
   ([User services](user-services.md)).
3. Mac: cache the Rex installer and run `./install` from inside a T3 Code or
   OpenCode session ([Rex](rex.md#macos-client)). Confirm activation finished
   though the hosting app restarted: the newest
   `~/Library/Logs/dotfiles-install/*/status` is `0`, both apps reloaded, and
   the terminal is not left stopped. Confirm Rex opens from Finder.
4. Mac: the same link checks as on scylla. Delete Dotbot's leftover KDE,
   Hyprland, Quickshell and Vicinae links, and Handy's speech models
   (`~/.cache/huggingface/hub/models--handy-computer--*`,
   `~/Library/Application Support/com.pais.handy/models`).
5. Mac: confirm the managed `opencode2` owns port 49374:
   `launchctl print gui/$(id -u)/org.nix-community.home.opencode2` shows
   `state = running`.
6. Mac: check that `vault` 2.2.1 (up from 2.0.3) still works against the work
   Vault server.
7. Pair each client with each host ([User services](user-services.md#t3-code-and-opencode)).
8. prostagma: delete every link Dotbot left in carter's home; Home Manager owns
   none of them.

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
5. Change the short passwords, if decision 5 says so
   ([Secrets, rotate a secret](secrets.md#rotate-a-secret)).

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
  ([Binary cache, step 2](binary-cache.md#2-create-the-cache-and-read-its-public-key-you)).
- The Beszel dashboard lists prostagma, scylla and eltoro as `up`.
- On eltoro, the post-deploy fence checks still pass
  ([El Toro](eltoro.md#deploying-fence-changes)).
