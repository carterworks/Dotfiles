# El Toro

A pet NixOS LXC on the Proxmox host **herodotus** (CT 102) running its own
[Hermes agent](https://github.com/NousResearch/hermes-agent). It is a normal
host in this flake: `nix/machines/eltoro.nix` holds the configuration and
`hermes-agent` is a flake input.

## What's in the box

- fish (root shell)
- tailscale
- hermes-agent gateway + dashboard (`:9119`), gated on
  `/var/lib/hermes/.hermes/config.yaml` existing — nothing starts until the
  agent is onboarded
- key-only SSH for root (deploy target)
- KittenTTS: local TTS for hermes (see below)
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
./install-eltoro              # build locally on scylla, activate on the container
./install-eltoro dry-run      # any nixos-rebuild action works, e.g. dry-run, boot, repl
```

`install-eltoro` builds the `eltoro` configuration on the current machine and
copies it to the target over SSH. Override the target with `ELTORO_HOST` if
needed.

(`eltoro` is on the tailnet as `eltoro.dropbear-tortoise.ts.net`; LAN IP
`192.168.4.34` is DHCP from vmbr0, so prefer the tailnet name.)

Garbage collection runs weekly, deleting store paths older than 7 days.

## First-run agent onboarding

Run onboarding as the `hermes` user so it writes the service's
`/var/lib/hermes/.hermes/config.yaml`:

```sh
ssh root@eltoro   # resolves via the tailnet (the LAN IP is firewalled off)
su hermes -c 'hermes auth login'   # or however the agent wants to authenticate
su hermes -c 'hermes'              # interactive onboarding
systemctl start hermes-gateway hermes-dashboard
```

No LiteLLM/MCP servers are configured — authenticate when needed.

Running `hermes` as root can create root-owned settings under `/root/.hermes`
or, if `HERMES_HOME` points at the service home, under
`/var/lib/hermes/.hermes`; prefer `su hermes -c 'hermes'` for admin (see
[Changing settings](#changing-settings)).

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
within a minute. Prefer `su hermes -c '...'` for admin, and if the gateway goes
quiet, check `journalctl -u hermes-gateway | grep 'Permission denied'`.

Allowlists in `config.yaml` are editable settings, not a containment boundary.
The system-level network, privilege, and resource restrictions still apply.

Approval prompts are deliberately off — `approvals.mode: off` in
`config.yaml` and `HERMES_YOLO_MODE=1` on the gateway — because the agent runs
unattended and the real fence is the host-side Proxmox firewall plus the egress
ipset (see [LAN isolation](#lan-isolation-host-enforced)). Hardline command
blocks still apply even in yolo mode.

Check settings permissions without modifying them:

```sh
bash tests/hermes-settings-writable
```

## Secrets and environment

The systemd units declare their non-secret environment directly in
`nix/machines/eltoro.nix`: `HOME`, `HERMES_HOME`, `MESSAGING_CWD`, `PATH`,
`PYTHONPATH`, and `HERMES_YOLO_MODE`.

Secrets come from `fnox`, not from Nix or Git. Both units run through
`fnox -c /var/lib/hermes/.hermes/fnox.toml exec --`, which decrypts the
age-encrypted `fnox.toml` and injects its values into the child process
environment at start. The age key lives at
`/var/lib/hermes/.config/fnox/age.txt`. `fnox.toml`, `.env`, and `auth.json`
are read-only inside the service namespace.

If onboarding or a wizard writes a new secret into the plaintext `.env`,
re-import it and restart the services:

```sh
su hermes -c 'cd /var/lib/hermes/.hermes && fnox import -i .env --provider age --force'
systemctl restart hermes-gateway hermes-dashboard
```

## Local TTS (KittenTTS)

Hermes's Nix python env is read-only, so `hermes setup tts` can't pip-install
into it. Instead the host builds a small `kittentts-site` overlay (pinned
0.8.1 wheel + `phonemizer`/`soundfile`, espeak-ng paths baked in, dead
`misaki` import patched out so torch/spacy never get pulled in) and puts it on
`PYTHONPATH` for the gateway, dashboard, and login shells. The overlay skips
dists hermes's env already ships (numpy, cffi, attrs, …) so it never shadows
hermes's pinned versions.

The provider is already selected in `/root/.hermes/config.yaml`
(`tts.provider: kittentts`, model `KittenML/kitten-tts-nano-0.8-int8`, voice
`Jasper`). The ~25MB model downloads from Hugging Face on first use. Voices:
Jasper, Bella, Luna, Bruno, Rosie, Hugo, Kiki, Leo.

## Host-side notes

- Container was created from the NixOS LXC template on herodotus:
  `pct create 102 local:vztmpl/nixos-image-lxc-proxmox-26.05pre-git-x86_64-linux.tar.xz --hostname eltoro --ostype nixos --unprivileged 1 --memory 3072 --swap 512 --cores 2 --rootfs local-lvm:32 --features nesting=1 --net0 name=eth0,bridge=vmbr0,ip=dhcp --onboot 1 --startup order=3`
- `/dev/net/tun` must be passed through in `/etc/pve/lxc/102.conf` on herodotus
  for tailscale (same as prostagma).
- Snapshot before risky agent experiments: `pct snapshot 102 <name>` on
  herodotus.

## LAN isolation (host-enforced)

Hermes runs as root inside the CT, so the guest's own NixOS firewall isn't a
real containment boundary — the agent could flush it. The real fence is the
Proxmox firewall, enforced by the host kernel from outside the container. Both
directions between eltoro and the LAN (`192.168.4.0/22`) are blocked:

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
