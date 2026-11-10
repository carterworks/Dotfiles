# Monitoring

[Beszel](https://beszel.dev) 0.21.1: a hub on prostagma at
`https://beszel.dropbear-tortoise.ts.net`, and an agent on prostagma, scylla
and eltoro. The Mac gets nothing.

- **Hub:** `nix/hosts/prostagma/beszel.nix`, gated in
  `nix/hosts/prostagma/sso.nix`, published by the `tailscale-services` unit in
  `nix/hosts/prostagma/default.nix`.
- **Agents:** `nix/modules/nixos/beszel-agent.nix`, imported on every NixOS
  host by `common.nix`. Everything stays off while `dotfiles.beszel.hubKey` is
  `null`: no agents, and no systems in the hub.

Steps marked **Owner** need the owner's tailnet admin access, the admin age key
or a deploy; nothing in the repository does them.

## How it fits together

- **Login.** Caddy sends every request except the agents' path through
  Authelia's forward-auth and passes on the `Remote-Email` header Authelia
  returns. Beszel trusts that header (`TRUSTED_AUTH_HEADER`) and logs in the
  user with that address, so one Authelia login is the whole of it. Beszel's
  own password logins are off (`DISABLE_PASSWORD_AUTH`). Its first start
  creates the account `carter@carter.works`, the address of the Authelia user,
  and a PocketBase superuser of the same address, both with a random password
  that is never stored. Caddy strips any `Remote-*` header a client sends
  itself, on every gated site.
- **Agents dial the hub.** Each agent opens a WebSocket to the hub
  (`/api/beszel/agent-connect`, the one path the gate lets through), so with
  `DISABLE_SSH` no agent listens on any port, LAN or tailnet. A desktop that
  sleeps simply reconnects when it wakes. prostagma's own agent uses the hub's
  loopback port, because a host cannot reach a Tailscale Service it hosts.
- **Both sides authenticate.** The agent checks the hub's signature against
  the hub's public key (`dotfiles.beszel.hubKey`, public, committed in plain
  text). The hub checks the agent's token, and on its first connection pins
  the agent's fingerprint, so a second machine with the same token is refused.
  Each host has its own token, a secret in fnox (`BESZEL_TOKEN_<HOST>`),
  encrypted to the hub and that host only.
- **Systems are declared.** On every start the hub writes its `config.yml`
  from the host list in `beszel.nix` and the tokens, and Beszel syncs its
  systems to it. A system added in the web interface is deleted at the next
  restart; add hosts in the repository instead.

## First deployment

1. **Owner:** deploy prostagma. The hub starts with no systems.
2. **Owner:** in the Tailscale admin console, approve the `svc:beszel` Service
   and make sure the tailnet policy lets you, scylla and eltoro reach it on
   443. Serve's line for it is last in `tailscale-services`, so until then
   that unit fails without stranding the other routes; restart it after the
   approval: `ssh prostagma sudo systemctl restart tailscale-services`.
3. Open `https://beszel.dropbear-tortoise.ts.net`: Authelia's login, then an
   empty Beszel dashboard. Beszel's own login form means the header did not
   arrive (see [A host shows as down](#a-host-shows-as-down)).
4. **Owner:** read the hub's public key (also shown in the "Add system"
   dialog):

   ```bash
   ssh prostagma sudo ssh-keygen -y -f /srv/apps/beszel-hub/beszel_data/id_ed25519
   ```

5. **Owner:** enrol scylla and eltoro in fnox, if they are not already. Read
   each host key, confirm its fingerprint on the host's own console ("Enrol a
   new or rebuilt host" in [Secrets](secrets.md)), and add one provider per host
   with the admin key, prostagma's key and that host's key, since the hub reads
   every token:

   ```toml
   [providers.beszel-scylla]
   type = "age"
   recipients = [
       "age175w5ysy6tncyaelddud60w59hqa2s9ht7p2cezd28pgyy595jp8q2wt0aw",
       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA+r8NT1FG/Ysn5jehgihrE1KT5r8A+TeZ8bTbovRMTR root@prostagma",
       "ssh-ed25519 AAAA… root@scylla",
   ]
   ```

   and the same for `beszel-eltoro`.
6. **Owner:** make the tokens, in the shell from "Before any command" in
   [Secrets](secrets.md). A token is at most 64 characters:

   ```bash
   token() { openssl rand -hex 24 | tr -d '\n' | base64 -w0 | sfnox set "$1" -p "$2" >/dev/null; }
   token BESZEL_TOKEN_PROSTAGMA prostagma
   token BESZEL_TOKEN_SCYLLA beszel-scylla
   token BESZEL_TOKEN_ELTORO beszel-eltoro
   ```

7. **Owner:** set the key, the one-line change: in
   `nix/modules/nixos/beszel-agent.nix`, replace `default = null;` with
   `default = "ssh-ed25519 AAAA…";`. Run `nix flake check --no-build`, commit,
   and deploy prostagma first, then scylla (`./install`) and eltoro. Once the
   binary cache is on, the servers take it in their nightly upgrade. eltoro's
   fence does not change, but if its first switch to the chain-based fence is
   still pending, this deploy carries it: follow "Deploying fence changes" in
   [El Toro](eltoro.md).
8. The dashboard lists prostagma, scylla and eltoro, each `up` within a minute
   of its agent starting.

## Add a host later

1. Add its name to `agents` in `nix/hosts/prostagma/beszel.nix`. Its
   `networking.hostName` must match, and it must import `common.nix` (every
   NixOS host does).
2. **Owner:** add a `beszel-<host>` provider and its token as in steps 5 and 6.
3. Commit and deploy prostagma, then the host.

To retire a host, remove it from `agents` and its token from the store. To
rotate a token, set it again and redeploy prostagma and the host; the
fingerprint stays pinned.

## What each agent collects

| | prostagma | scylla | eltoro |
|---|---|---|---|
| CPU, memory, swap, load, network, root filesystem and disk I/O, temperatures the host exposes | yes | yes | yes |
| Docker containers: CPU, memory, network, health, image updates, logs and details (without environment variables) | yes | no | no |
| systemd service status and their journal | yes | no | no |
| Other filesystems | `/srv/apps` | no | no |
| GPU | Intel, from sysfs | AMD, from sysfs | no |
| ZFS pools | no | yes, the module adds `/dev/zfs` | no |

Every agent runs as a dynamic, unprivileged `beszel-agent` user in the module's
sandbox (no capabilities, read-only system and home directories), outside eltoro's egress
fence. What each host adds:

- **prostagma:** the `docker` group, for the Docker socket. **Access to that
  socket is equivalent to root on prostagma**: the agent only reads from it,
  but a compromised agent could start a privileged container. Service status
  adds a D-Bus policy allowing `ListUnits` and the `systemd-journal` group,
  which reads every unit's journal.
- **scylla:** `/dev/zfs`, through the module's own ZFS support.
- **eltoro:** nothing beyond the base.

Left off, and why:

- **TrueNAS NFS mounts:** they are hard mounts and the agent's `statfs` has no
  timeout, so an outage of TrueNAS would hang its collection.
- **S.M.A.R.T.:** needs `CAP_SYS_RAWIO`, `CAP_SYS_ADMIN` and the raw disks,
  which the containers do not see; on scylla it was not asked for.
- **`intel_gpu_top`:** needs `CAP_PERFMON`, `perf_event_open` and the host's
  user namespace; the sysfs collector needs none of them.
- **Processes:** 0.21.1 has no per-process collector; containers and services
  are the finest grain.
- **Service status on scylla and eltoro:** read access to the whole journal.
  On eltoro it would carry Hermes' logs to the hub.
- **SSH mode (the hub dialling the agents):** it would need a listening port on
  every host, and scylla's firewall is off.

## eltoro and the fence

The fence (`nix/hosts/eltoro/egress.nix`) restricts uid `hermes` and group
`nixbld`; the first rule of `hermes-egress` accepts every other owner. The agent
runs as neither, so it reaches the hub through `tailscale0`, which the fence
would refuse to Hermes. Hermes gains nothing from it: the agent listens on no
port and no socket, reads no file Hermes can write, and runs only programs from
the Nix store. What it sends is the metrics in the table above.

Whoever can use the hub can make agents run network probes (ping, TCP, HTTP,
DNS) from their hosts; on eltoro those come from outside the fence. Only the
Authelia user can use the hub.

## A host shows as down

1. On the host: `systemctl status beszel-agent fnox-secret-BESZEL_TOKEN_<HOST>`
   and `journalctl -u beszel-agent`.
   - `invalid signature - check KEY value`: `dotfiles.beszel.hubKey` is not the
     hub's key (the hub's data was lost and it made a new one; redo steps 4 and
     7).
   - A failed `fnox-secret-…` unit: the token is missing from the store or not
     encrypted to this host.
   - Connection errors: the host cannot reach the Service. From the host,
     `curl -sI https://beszel.dropbear-tortoise.ts.net/` should answer (with a
     redirect to Authelia). Check `tailscale status`, the Service approval and
     the tailnet policy.
2. On prostagma: `journalctl -u beszel-hub` (`fingerprint mismatch` means a
   rebuilt host kept its token: delete the system's fingerprint, or set a new
   token).
3. scylla is down whenever it sleeps.

If the dashboard shows Beszel's own login form, the `Remote-Email` header is
missing: check that the request went through Caddy (`tailscale serve status`)
and that Authelia's user has the address the hub's account was made with.

## Data and backups

Everything is in `/srv/apps/beszel-hub/beszel_data` on prostagma:

- `id_ed25519`, the hub's private key. Worth backing up: a new hub key means
  committing it again and redeploying every agent.
- `data.db`, `auxiliary.db`: metrics history, alert settings and the
  fingerprints. Losing them costs history only; the systems come back from
  `config.yml` and re-pin on their next connection.
- `config.yml`: written on every start, holds the tokens; nothing to back up.

The PocketBase admin interface (`/_/`) is behind the gate, but its superuser's
password was never kept. To use it, set a throwaway one on prostagma (it
passes through the command line), then change it in the interface:
`sudo -u beszel-hub env -C /srv/apps/beszel-hub <beszel-hub> superuser upsert carter@carter.works <password>`,
with the binary from the unit's `ExecStart`.
