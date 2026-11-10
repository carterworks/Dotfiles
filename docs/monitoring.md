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

- **Login.** On every gated site Caddy first deletes any `Remote-*` header the
  client sent, then sends the request, except on the agents' path, through
  Authelia's forward-auth, and passes on the `Remote-*` headers Authelia
  returns. Beszel trusts `Remote-Email` (`TRUSTED_AUTH_HEADER`) and logs in the
  user with that address, so one Authelia login is the whole of it. Beszel's
  own password logins are off (`DISABLE_PASSWORD_AUTH`). Its first start
  creates the account `carter@carter.works`, the address of the Authelia user,
  and a PocketBase superuser of the same address, both with a random password
  that is never stored.
- **The account is read-only.** Every start sets its role to `readonly`. It
  sees every dashboard and sets its own alerts and notifications; it cannot
  read the agents' tokens back, make universal tokens, add network probes,
  pause systems or send notifications to internal addresses. Systems are
  declared in the repository, so nothing else is lost.
- **Agents dial the hub.** Each agent opens a WebSocket to the hub
  (`/api/beszel/agent-connect`, the one path the gate lets through), so with
  `DISABLE_SSH` no agent listens on any port, LAN or tailnet. A desktop that
  sleeps simply reconnects when it wakes. prostagma's own agent uses the hub's
  loopback port, because a host cannot reach a Tailscale Service it hosts.
- **Both sides authenticate.** The agent checks the hub's signature against
  the hub's public key (`dotfiles.beszel.hubKey`, public, committed in plain
  text). The hub checks the agent's token, and on its first connection pins
  the agent's fingerprint, so a second machine with the same token is refused.
  The fingerprint is a hash of the machine ID, which any user on that host can
  read, so the token is the only credential an agent holds.
  Each host has its own token, a secret in fnox (`BESZEL_TOKEN_<HOST>`),
  encrypted to the hub and that host only.
- **Systems are declared.** On every start the hub writes its `config.yml`
  from the host list in `beszel.nix` and the tokens, and Beszel syncs its
  systems to it. A system added in the web interface is deleted at the next
  restart; add hosts in the repository instead.

## First deployment

1. **Owner:** deploy prostagma. With the hub key in the repository, the hub
   starts with all three systems configured.
2. **Owner:** in the Tailscale admin console, approve the `svc:beszel` Service
   and make sure the tailnet policy lets you, scylla and eltoro reach it on
   443. Grant it to them by name, not to `*`: tagged nodes match `*`, so such
   a grant would also reach CI's `tag:ci` runners ("Tailscale policy" in
   [Binary cache](binary-cache.md#tailscale-policy-you)). Until then
   `tailscale-services` still succeeds and `tailscale serve status` lists the
   route; Serve only prints that the Service awaits an admin's approval. If
   the dashboard does not answer after the approval, restart the unit:
   `ssh prostagma sudo systemctl restart tailscale-services`.
3. Open `https://beszel.dropbear-tortoise.ts.net`: Authelia's login, then the
   Beszel dashboard with prostagma, scylla and eltoro listed. Beszel's own
   login form means the header did not arrive (see
   [A host shows as down](#a-host-shows-as-down)).

   Steps 4 to 7 set the hub key, the providers and the tokens, which are
   committed, so a rebuild with the hub's data restored skips them. A hub
   without its data makes a new key: redo steps 4 and 7.
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
   token() { nix run nixpkgs#openssl -- rand -hex 24 | tr -d '\n' | base64 -w0 | sfnox set "$1" -p "$2" >/dev/null; }
   token BESZEL_TOKEN_PROSTAGMA prostagma
   token BESZEL_TOKEN_SCYLLA beszel-scylla
   token BESZEL_TOKEN_ELTORO beszel-eltoro
   for k in BESZEL_TOKEN_PROSTAGMA BESZEL_TOKEN_SCYLLA BESZEL_TOKEN_ELTORO; do
     printf '%s ' "$k"; sfnox get "$k" | base64 -d | wc -c
   done
   ```

   Each token must be 48 bytes; a 0 means the first command failed and an
   empty token was stored, so make that one again.

7. **Owner:** set the key, the one-line change: in
   `nix/modules/nixos/beszel-agent.nix`, replace `default = null;` with
   `default = "ssh-ed25519 AAAA…";`. Run `nix flake check --no-build`, commit,
   and deploy prostagma first, then scylla (`./install`) and eltoro. Once the
   binary cache is on, the servers take it in their nightly upgrade. Put the
   providers, the tokens and the key in one commit: every change to the store
   restarts all of prostagma's secret units and their services (see
   [Secrets](secrets.md#how-it-works)). eltoro's fence does not change; if
   eltoro still runs a generation from before the chain-based fence, this
   deploy carries the first switch to it, so follow "Deploying fence changes"
   in [El Toro](eltoro.md#deploying-fence-changes).
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
| Docker containers: CPU, memory, network, health, image updates | yes | no | no |
| systemd service status | yes | no | no |
| Other filesystems | `/srv/apps` | no | no |
| GPU | Intel, from sysfs (not reported) | AMD, from sysfs | no |
| ZFS pools | no | yes | no |

prostagma's Intel GPU is configured but not reported (2026-11-10); the cause is
unknown.

Every agent runs as an unprivileged `beszel-agent` user in the module's
sandbox (no capabilities, read-only system and home directories, its own user
namespace), outside eltoro's egress fence. The user is dynamic, except on
prostagma, where the nixpkgs module makes it a system user for the D-Bus
policy to name. What each host adds:

- **prostagma:** the `docker` group, for the Docker socket. **Access to that
  socket is equivalent to root on prostagma**: the agent only reads from it,
  but a compromised agent could start a privileged container. A read-only
  socket proxy in front of Docker would end that, at the cost of one more
  service. Service status adds a D-Bus policy allowing `ListUnits`.
- **scylla:** `/dev/zfs`, and the host's user namespace, which the ZFS tools
  need.
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
- **Logs:** the agent could read service logs from the journal and container
  logs from Docker, which would give the hub Authelia's, Caddy's and every
  container's output. The agent has no journal access (`SKIP_SYSTEMD_LOGS`),
  and the hub has no container logs or details API (`CONTAINER_DETAILS`).
- **Service status on scylla and eltoro:** not asked for; it adds a D-Bus
  policy, and drops the agent's user namespace in the nixpkgs module.
- **SSH mode (the hub dialling the agents):** it would need a listening port on
  every host, and scylla's firewall is off.

## What hub access is worth

Beszel 0.21.1 has no command execution, terminal or container control: the hub
can only ask an agent for metrics and for the details listed above. From
prostagma that is container statistics and service status. From every agent,
a hub admin or superuser can also configure network probes (ping, TCP, HTTP,
DNS); on eltoro those leave from outside the egress fence. The owner's
read-only account cannot add them.

**The loopback risk.** The hub listens on `127.0.0.1:8091` and believes any
`Remote-Email` header sent there, so any local process on prostagma that can
make an HTTP request to that port with a custom header is logged in as the
owner. Only the bindings keep everything else out: the hub and Caddy listen on
loopback only, and no container on prostagma uses the host's network, so
containers cannot reach that port. A host-network container would change
that. The VM test states it as a property ("on prostagma, the header alone
logs in at the hub's own port").

## eltoro and the fence

The fence (`nix/hosts/eltoro/egress.nix`) restricts uid `hermes` and group
`nixbld`; the first rule of `hermes-egress` accepts every other owner. The agent
runs as neither, so it reaches the hub through `tailscale0`, which the fence
would refuse to Hermes. Hermes gains nothing from it: the agent listens on no
port and no socket, reads no file Hermes can write, and runs only programs from
the Nix store. What it sends is the metrics in the table above.

A hub superuser can make it run network probes from outside the fence (see
[What hub access is worth](#what-hub-access-is-worth)).

## A host shows as down

1. On the host: `systemctl status beszel-agent fnox-secret-BESZEL_TOKEN_<HOST>`
   and `journalctl -u beszel-agent`.
   - `invalid signature - check KEY value`: `dotfiles.beszel.hubKey` is not the
     hub's key (the hub's data was lost and it made a new one; redo steps 4 and
     7).
   - A failed `fnox-secret-…` unit: the token is missing from the store or not
     encrypted to this host.
   - Connection errors: the host cannot reach the Service. Until the Service
     is granted to the host, its agent dials the hub's address through the
     default route instead of the tailnet (observed on eltoro, 2026-11-10).
     From the host,
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

Everything is in `/srv/apps/beszel-hub/beszel_data` on prostagma, and lands in
whatever backs up `/srv/apps`:

- `id_ed25519`, the hub's private key. Worth backing up: a new hub key means
  committing it again and redeploying every agent.
- `data.db`, `auxiliary.db`: metrics history, alert settings and the
  fingerprints, which hold the tokens too. Losing them costs history only; the
  systems come back from `config.yml` and re-pin on their next connection.
- `config.yml`: written on every start from fnox, and holds every agent's
  token. A backup of `/srv/apps` holds them too, so protect it like the store's
  admin key; rotate the tokens if one leaks.

Agent tokens are kept out of Caddy's logs: a log filter deletes `X-Token` from
the Beszel site's access log and from the error log in the journal.

### The superuser

The PocketBase admin interface (`/_/`) is behind the gate, but its superuser's
password was never kept. Beszel's `superuser` commands take the password as an
argument, where the process table and `sudo`'s journal entry would show it, so
**Owner:** set its bcrypt hash directly instead. `mkpasswd` asks for the
password without echo, and the SQL reaches `sqlite3` through a pipe:

```bash
ssh -t prostagma
sudo systemctl stop beszel-hub
hash=$(nix run nixpkgs#mkpasswd -- -m bcrypt -R 12)
printf "UPDATE _superusers SET password = '%s' WHERE email = 'carter@carter.works';\n" "$hash" |
  sudo -u beszel-hub "$(nix build --no-link --print-out-paths nixpkgs#sqlite.bin)/bin/sqlite3" \
    /srv/apps/beszel-hub/beszel_data/data.db
unset hash
sudo systemctl start beszel-hub
```

Then log in at `https://beszel.dropbear-tortoise.ts.net/_/`. The VM test runs
the same pipeline, with the password on standard input (`mkpasswd -s`).
