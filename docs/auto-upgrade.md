# Server auto-upgrade

prostagma and eltoro switch themselves to the `release` branch every night
(`system.autoUpgrade` in `nix/modules/nixos/server.nix`). Scylla and the Mac
never do; run `./install` there.

## When it is on

Only once the private binary cache is configured
(`dotfiles.binaryCache.publicKey`, step 2 of [Binary cache](binary-cache.md)).
Until then the timer does not exist. `release` moves only to a commit that CI
built and pushed to that cache, so with the cache a server fetches everything
and builds nothing. Without it, a server would have to build whatever the
public caches lack, and on eltoro the egress fence blocks build users from the
network.

Deploying the commit that sets the key (`./install prostagma`,
`./install eltoro`) is what turns it on.

## Schedule

Every night at 04:30 America/Denver, plus a random delay of up to 30 minutes.
If the host was down then, it runs at the next boot. That keeps it clear of
Nix garbage collection (03:15), carter's profile prune on prostagma (02:45)
and the weekly Docker prune and fstrim (Monday 00:00).

The service runs, as root:

```sh
nixos-rebuild switch --refresh --flake github:carterworks/dotfiles/release#<host>
```

It evaluates on the host (eltoro peaks at about 0.9 GB of its 3 GB), fetches
from the caches, activates, and sets the boot default. It never reboots.

## What an unattended switch restarts

Activation restarts every unit whose unit file changed, reloads those marked
for reload, starts new units and stops removed ones, as `./install` does. The
upgrade unit itself is never restarted mid-run. What that means here:

- **prostagma**
  - A `docker-*` container restarts when its unit changes: a new image digest
    from `./update`, or a changed option or environment. If the Docker package
    changes, `docker.service` restarts, and with live restore off every
    container restarts with it.
  - Any change to `secrets/fnox.toml`, even to an admin-only record, restarts
    all ten `fnox-secret-*` units and every service that requires them (see
    [Secrets](secrets.md)).
  - Caddy, Authelia, Immich, atticd and the rest restart when their package or
    configuration changes. While atticd restarts, a host upgrading at the same
    moment falls back to the public caches.
  - Restarting `tailscaled` drops the tailnet for a few seconds; a restarted
    `sshd` keeps existing sessions.
- **eltoro**
  - `hermes-gateway` and `hermes-dashboard` restart when Hermes or their units
    change, which drops open Discord sessions.
  - Egress fence changes arrive this way too. `firewall.service` is reloaded,
    not restarted, so the agent keeps running behind the catch-all while the
    chain is rebuilt. See "Deploying fence changes" in [El Toro](eltoro.md).

## When it fails

- **Fetch, evaluation or build fails**: nothing is activated. The host keeps
  running its current generation, which stays the boot default.
- **Activation fails** (a unit does not start): the new generation is already
  the system profile and the boot default. Activation carries on with the other
  units, and the host runs the new generation with those units failed. NixOS
  does not roll back by itself.

Either way `nixos-upgrade.service` fails. Nothing sends a notification; it
shows only where you look. On the host:

```sh
systemctl --failed
journalctl -u nixos-upgrade.service -n 50 --no-pager
systemctl list-timers nixos-upgrade.timer
```

From scylla, `./drift` lists each host as `in sync` or `behind` against
`release`, with when its running generation was activated. A failed fetch or
build leaves the server `behind`. A failed activation does not: the host runs
`release`, and only `systemctl --failed` shows the unit that failed.

To go back: `sudo nixos-rebuild switch --rollback` on the host, or fix the
problem on `main`. The next night tries again with whatever `release` then
holds.
