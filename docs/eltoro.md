# El Toro

A pet NixOS LXC on the Proxmox host **herodotus** (CT 102) running its own
[Hermes agent](https://github.com/NousResearch/hermes-agent). It is a normal
host in this flake: `nix/hosts/eltoro/default.nix` holds the configuration,
`nix/hosts/eltoro/egress.nix` holds the agent's network restrictions, and
`hermes-agent` is a flake input.

## What's in the box

- fish (root shell)
- tailscale
- hermes-agent gateway + dashboard (`:9119`, tailnet only), gated on
  `/var/lib/hermes/.hermes/config.yaml` existing — nothing starts until the
  agent is onboarded
- key-only SSH for root (deploy target)
- Node.js, pnpm, Git, ripgrep, and fd for application development

## Application workspace

Discord sessions work from `/var/lib/hermes/workspace`, a mutable Git repository
kept separate from Hermes's credentials and runtime state. Its own Nix flake pins
the development toolchain, and its `AGENTS.md` tells Hermes to use pnpm, Git,
ripgrep, and fd and to validate, commit, and push completed work. Application
projects live under `apps/`.

The repository remote and its write-enabled GitHub deploy key are configured
out of band. The system firewall allows GitHub and the npm registry.

## Deploy from Scylla

```sh
./install eltoro              # build locally on scylla, activate on the container
./install eltoro dry-activate # any nixos-rebuild action works, e.g. dry-run, boot, repl
```

`./install eltoro` builds the `eltoro` configuration on the current machine,
logs in as `root@eltoro`, and has the container fetch from its binary caches
whatever they hold (`--use-substitutes`); scylla sends only the rest. Override
the target with `ELTORO_HOST` if needed.

(`eltoro` is on the tailnet as `eltoro.dropbear-tortoise.ts.net`; LAN IP
`192.168.4.34` is DHCP from vmbr0, so prefer the tailnet name.)

Once the binary cache is on, eltoro also upgrades itself every night to the
`release` branch; see [Server auto-upgrade](auto-upgrade.md).

Garbage collection runs nightly at 03:15, deleting store paths older than 3
days (the other hosts keep 7; eltoro's disk is 32 GB). The store
deduplicates new paths as they are added; to deduplicate what was there
before, run `nix-store --optimise` once as root.

## First-run agent onboarding

Run onboarding as the `hermes` user so it writes the service's
`/var/lib/hermes/.hermes/config.yaml`:

```sh
ssh root@eltoro   # resolves via the tailnet (the LAN IP is firewalled off)
runuser --pty -u hermes -- hermes auth login   # or however the agent wants to authenticate
runuser --pty -u hermes -- hermes              # interactive onboarding
systemctl start hermes-gateway hermes-dashboard
```

No LiteLLM/MCP servers are configured — authenticate when needed.

Never run `hermes` as root. With `HERMES_HOME` pointed at the service home it
reads configuration that the agent can write (see [Known gaps](#known-gaps)),
and it leaves root-owned settings the gateway cannot read (see
[Changing settings](#changing-settings)). Always use `runuser --pty -u hermes -- hermes …`.
`--pty` gives the command its own terminal: sharing root's, a process running
as hermes could inject keystrokes into root's shell on kernels that allow it
(TIOCSTI).

## Changing settings

Hermes runs as the `hermes` user, with settings in
`/var/lib/hermes/.hermes/config.yaml`. The file is user-owned and writable from
the CLI, gateway, and dashboard; NixOS repairs its ownership on deployment, on
boot, and once a minute without overwriting its contents. Credentials
(`fnox.toml`, `.env`, and `auth.json`) remain read-only inside the services.

The periodic repair matters: running `hermes` **as root** with `HERMES_HOME`
pointed at the service home (for example `hermes model` or an interactive TUI)
rewrites those settings as `0600 root:hermes`, which the unprivileged gateway
cannot read. It then silently
falls back to a default config and fails every turn with `No LLM provider
configured`, so Discord stops replying. The gateway does not exit when this
happens, so it used to stay broken until the next deploy; it now self-heals
within a minute. Run admin commands as `runuser --pty -u hermes -- …`, and if the
gateway goes quiet, check `journalctl -u hermes-gateway | grep 'Permission denied'`.

The repair runs as root inside a directory the agent owns, so it refuses unless
`/var/lib/hermes/.hermes` is a real directory owned by `hermes`; otherwise a
symlink there could aim its `chown` anywhere. Inside it, it only touches a
settings file that is a regular file with a single link, checked and changed
through one open descriptor, so a symlink or a hard link to a file elsewhere is
left alone.

The agent can make the repair refuse whenever it likes, so a refusal is not a
failed deploy. During activation it prints a warning and the switch carries on;
the system has switched, so do not roll back, and inspect
`/var/lib/hermes/.hermes` instead. The once-a-minute
`hermes-settings-repair.service` does fail on a refusal, so it shows in
`systemctl --failed`.

Allowlists in `config.yaml` are editable settings, not a containment boundary.
The system-level network, privilege, and resource restrictions still apply.

Approval prompts are deliberately off — `approvals.mode: off` in
`config.yaml` and `HERMES_YOLO_MODE=1` on the gateway — because the agent runs
unattended and the real fence is the network: the container's egress firewall
plus the host-side Proxmox firewall (see [Egress firewall](#egress-firewall)
and [LAN isolation](#lan-isolation-host-enforced)). Hardline command blocks
still apply even in yolo mode.

Check settings permissions without modifying them:

```sh
bash tests/hermes-settings-writable
```

## Secrets and environment

The systemd units declare their non-secret environment directly in
`nix/hosts/eltoro/default.nix`: `HOME`, `HERMES_HOME`, `MESSAGING_CWD`, `PATH`, and
`HERMES_YOLO_MODE`.

Secrets come from `fnox`, not from Nix or Git. Both units run through
`fnox -c /var/lib/hermes/.hermes/fnox.toml exec --`, which decrypts the
age-encrypted `fnox.toml` and injects its values into the child process
environment at start. The age key lives at
`/var/lib/hermes/.config/fnox/age.txt`. `fnox.toml`, `.env`, and `auth.json`
are read-only inside the service namespace.

If onboarding or a wizard writes a new secret into the plaintext `.env`,
re-import it and restart the services:

```sh
runuser --pty -u hermes -- sh -c 'cd /var/lib/hermes/.hermes && fnox import -i .env --provider age --force'
systemctl restart hermes-gateway hermes-dashboard
```

## Host-side notes

- Container was created from the NixOS LXC template on herodotus:
  `pct create 102 local:vztmpl/nixos-image-lxc-proxmox-26.05pre-git-x86_64-linux.tar.xz --hostname eltoro --ostype nixos --unprivileged 1 --memory 3072 --swap 512 --cores 2 --rootfs local-lvm:32 --features nesting=1 --net0 name=eth0,bridge=vmbr0,ip=dhcp --onboot 1 --startup order=3`
- `/dev/net/tun` must be passed through in `/etc/pve/lxc/102.conf` on herodotus
  for tailscale (same as prostagma).
- Snapshot before risky agent experiments: `pct snapshot 102 <name>` on
  herodotus.

## Egress firewall

`nix/hosts/eltoro/egress.nix` fences what the agent can reach, with iptables
rules in a `hermes-egress` chain jumped to from `OUTPUT`, in both address
families. It applies to the `hermes` user and to Nix build users (group
`nixbld`); root and every other user are unrestricted.

For those two, the chain is an allowlist. Everything it does not accept is
rejected, on every interface except loopback:

- Replies on established and related connections, so inbound sessions (SSH,
  the dashboard) keep working.
- On `eth0`, IPv4 addresses in the `egress-allowed` ipset, which
  `egress-allowlist.timer` fills from the domain and CIDR lists. IPv6 egress is
  rejected.
- On `tailscale0`, MagicDNS (`100.100.100.100:53`) only: no new connection into
  the tailnet, and nothing routed through it, such as a subnet route or an exit
  node.

Nix builds are fenced because any user may ask the daemon for one, and
fixed-output builds run as a build user with the host's network: unfenced, the
agent could fetch any address from a derivation and read the reply in the build
log. Substitution is done by the daemon as root and is unaffected. Builds that
root starts on eltoro are fenced too; build on Scylla, as `./install eltoro` does.

The fence fails closed. Whenever the chain is down (the firewall stopped, a
failed reload, or the moment inside every reload) a catch-all
`hermes-egress-closed` chain rejects every new connection from the fenced
users, while established sessions carry on. Start builds the chain, hooks it,
and only then removes the catch-all.

The Hermes units require `firewall.service`, and before starting they check as
root that `OUTPUT` jumps to `hermes-egress` in both address families; otherwise
they refuse to start, which covers a firewall unit that was skipped or failed
before building the fence. Once running, the agent does not follow every change
to the fence:

- A failed reload leaves the agent running behind the catch-all: its existing
  sessions survive, and new connections fail until a reload succeeds.
- `systemctl restart firewall` restarts the agent.
- `systemctl stop firewall` stops the agent. Starting the firewall again does
  not bring it back; run `systemctl start hermes-gateway hermes-dashboard`.

Each rule is written once. Start, reload and stop all remove the chain and
start rebuilds it, so a rule cannot outlive the generation that wrote it.

```sh
nix build .#checks.x86_64-linux.eltoro-egress           # exercises the fence in VMs
nix build .#checks.x86_64-linux.hermes-settings-repair  # and the settings repair
```

### Deploying fence changes

Once the binary cache is on, a fence change reaches eltoro unattended, in the
nightly upgrade (see [Server auto-upgrade](auto-upgrade.md)). Three things
stand between such a change and an open fence:

- **The VM test.** CI runs `eltoro-egress` on every push, and `release` only
  moves to a commit whose checks passed.
- **Failing closed.** The switch reloads the firewall; during the reload, and
  after a failed one, the catch-all rejects every new connection from the
  fenced users.
- **The start interlock.** The Hermes units refuse to start unless `OUTPUT`
  jumps to `hermes-egress` in both address families.

None of them sees state outside the repository: rules added to `OUTPUT` by
hand, or the Proxmox firewall. Deploy by hand with the checklist below:

- The first switch to the chain-based fence, from the generation before it. Its
  one-time migration needs the pre-flight `OUTPUT` check. Do it before the cache
  key is set, because setting the key turns on unattended upgrades. eltoro made
  this switch on 2026-11-10 without the checklist, by accident; whether it
  keeps that generation is an open decision in [Rollout](rollout.md).
- Any fence change you want to watch land, with a snapshot to return to.

After an unattended fence change, the post-deploy checks below still confirm it
on the real host.

Before deploying:

- Take a Proxmox snapshot of the container (`pct snapshot 102 <name>` on
  herodotus). If SSH is lost, the Proxmox console is the way back in.
- On eltoro, run `iptables -S OUTPUT; ip6tables -S OUTPUT` and confirm nothing
  is there except rules this repo wrote. The one-time migration in `egress.nix`
  removes only rules naming the uplink or `tailscale0`; anything else stays.
- Keep a second SSH session open while you deploy.

After deploying, as root on eltoro:

```sh
iptables -S OUTPUT; ip6tables -S OUTPUT          # only: -P OUTPUT ACCEPT and -A OUTPUT -j hermes-egress
iptables -S hermes-egress-closed 2>&1 | head -1   # an error means the catch-all is gone, as intended
ipset list egress-allowed | sed -n '1,8p'
systemctl is-active firewall hermes-gateway hermes-dashboard egress-allowlist.timer
t(){ timeout 5 runuser -u "$1" -- bash -c "</dev/tcp/$2/$3" && echo "$1 $2:$3 OPEN" || echo "$1 $2:$3 blocked"; }
t hermes 140.82.112.3 443     # OPEN: allowlisted
t hermes 1.1.1.1 443          # blocked
t hermes 100.100.100.100 53   # OPEN: MagicDNS
t nixbld1 1.1.1.1 443         # blocked
t root 1.1.1.1 443            # OPEN
peer=$(tailscale ip -4 scylla)  # any tailnet peer with SSH listening
t hermes "$peer" 22           # blocked
t root "$peer" 22             # OPEN
cat /proc/sys/fs/protected_hardlinks   # expect 1
```

Then, from another machine, open a fresh SSH login to eltoro and load the
dashboard over the tailnet (`http://eltoro:9119`).

Rolling back to a generation from before the catch-all existed while a reload
has failed leaves `hermes-egress-closed` hooked, since that generation never
removes it. Remove it by hand:

```sh
iptables -D OUTPUT -j hermes-egress-closed; ip6tables -D OUTPUT -j hermes-egress-closed
```

### Known gaps

- DNS exfiltration: hermes can send arbitrary names to the local resolver and
  MagicDNS, which forward them upstream as other users. Closing it needs a
  filtering resolver; not done.
- Running the `hermes` CLI as root with `HERMES_HOME` pointed at the service
  home reads configuration that hermes can write, which may let the agent run
  code as root. Run it as `runuser --pty -u hermes -- hermes …` instead.
- Shared CDN addresses in the allowlist (Cloudflare, Fastly) also reach other
  tenants on those addresses.
- Allowlisted addresses are open on every port and protocol, not only 443.
- Loopback is unrestricted, including the machine's own addresses: hermes can
  reach every local service.
- Every port Hermes listens on is reachable from the whole tailnet, because
  `tailscale0` is trusted for inbound traffic; the dashboard is one of them.
- The fence finds Nix builds by their `nixbld` group. An evaluation assertion
  keeps `build-users-group` and `auto-allocate-uids` from changing that, but
  the fence depends on build users keeping the group.

## LAN isolation (host-enforced)

Hermes runs as the unprivileged `hermes` user, so it cannot change the
container's own firewall. That firewall still sits inside the container, so it
falls if root there is compromised. The Proxmox firewall, enforced by the host
kernel from outside the container, holds even then. Both directions between
eltoro and the LAN (`192.168.4.0/22`) are blocked:

- herodotus: `pct set 102 -net0 ...,firewall=1` plus `/etc/pve/firewall/102.fw`
  (per-CT rules) and `/etc/pve/firewall/cluster.fw` (enables the datacenter
  firewall; `policy_in/out: ACCEPT` so only CT 102 is fenced).
- Internet egress still works: internet-bound packets are addressed to public
  IPs — the gateway (`192.168.4.1`) is only the next-hop MAC, so the LAN-dest
  drop rule never sees them. DNS goes to off-LAN AdGuard (`94.140.14.14/15`,
  inherited from DHCP); no LAN DNS dependency.
- Tailscale is unaffected: it's a userspace tunnel via `/dev/net/tun` inside
  the CT, so its packets never traverse eth0. UDP `41641` is allowed inbound
  from the LAN so tailnet peers keep direct connections (that port only ever
  terminates in tailscaled/WireGuard); otherwise peers fall back to DERP
  relays, which also work.
- Two PVE firewall gotchas (both hit during setup): per-CT rules are only
  compiled when the **datacenter** firewall is enabled, and a leading `|` in
  `102.fw` means the rule is *disabled*, not a pipe.
- If the CT is ever rebuilt, re-apply: the `firewall=1` net0 flag, `102.fw`,
  and `cluster.fw` above. Verify with
  `ssh herodotus -- iptables-save | grep veth102i0` (rules should reference
  `192.168.4.0/22`) and a failing `ssh eltoro -- ping -c1 192.168.4.1`.
