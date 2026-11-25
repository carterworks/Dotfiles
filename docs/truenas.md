# TrueNAS

The TrueNAS VM on Proxmox (tailnet name `truenas`, LAN `192.168.5.252`, the
HDDs passed through) is managed with OpenTofu from `infra/truenas/`, using the
official provider
[`truenas/truenas`](https://github.com/truenas/terraform-provider-truenas).
Prostagma mounts its NFS exports and scylla mounts its SMB shares. The IDs
and addresses both sides depend on live in `nix/lib/fleet.nix` (`lan` and
`nasIds`); prostagma imports them, and the wrapper passes them to OpenTofu as
`var.fleet`. A check warns if TrueNAS's builtin `apps` group stops having
prostagma's `apps` GID.

## Run it

From the checkout on scylla:

```bash
infra/truenas/tofu init      # once, and after a provider bump
infra/truenas/tofu plan
infra/truenas/tofu apply     # only after reading the whole plan
```

`./drift` also plans TrueNAS, read-only, and reports it as `in sync`,
`drifted` (with the plan's summary) or `plan failed`. It compares the server
with this checkout's configuration, not with `release`, because TrueNAS is
applied from scylla. Either of the last two makes `./drift` exit 1.
`TRUENAS_TOFU` overrides the wrapper's path, which the tests use.

The wrapper decrypts its secrets from fnox into its own environment and runs
OpenTofu from the flake's nixpkgs. Without `TRUENAS_TOFU_API_KEY` in the
store, it prompts for carter's TrueNAS password instead.

| fnox key (admin) | Used for |
|---|---|
| `TRUENAS_TOFU_STATE_PASSPHRASE` | Encrypting the state and plan files |
| `TRUENAS_CONNECTIVITY_CHECK_URL` | The healthchecks.io URL in the connectivity cron job |
| `TRUENAS_TOFU_API_KEY` | Logging in to TrueNAS: the API key `opentofu`, owned by carter |
| `HOME_ASSISTANT_TRUENAS_API_KEY` | Home Assistant's TrueNAS integration: the key `home-assistant-readonly`, owned by `homeassistant`, a read-only administrator |

The key is not managed by OpenTofu. To rotate it, in a shell set up as in
[Secrets, before any command](secrets.md#before-any-command) (which defines
`sfnox` and `pipefail`):

1. Note the current key's id:
   `ssh truenas 'midclt call api_key.query "[[\"name\",\"=\",\"opentofu\"]]" "{\"select\":[\"id\"]}"'`
2. Create a new key straight into fnox, and check its length (about 66 bytes):

   ```bash
   ssh truenas 'midclt call api_key.create "{\"name\":\"opentofu\",\"username\":\"carter\"}"' |
     jq -je .key | base64 -w0 | sfnox set TRUENAS_TOFU_API_KEY -p admin >/dev/null
   sfnox get TRUENAS_TOFU_API_KEY | base64 -d | wc -c
   ```

3. `infra/truenas/tofu plan` must log in and show no changes.
4. Only then revoke the old key: `ssh truenas 'midclt call api_key.delete <old id>'`.

The provider connects to `wss://truenas.<tailnet>/api/current` with TLS
verification off, because TrueNAS still serves its self-signed `localhost`
certificate, so it relies on Tailscale to authenticate the peer. Never point
the provider at the LAN address while `insecure = true`.

## Safety

- Run `plan` and `apply` only from scylla, never from CI: CI would need a key
  that can rewrite every share and ACL.
- Datasets, ACLs, shares, users, groups and every task have
  `prevent_destroy`. A plan that would delete or replace one is refused.
  Changing a dataset's `acltype` or a user's `uid` forces a replacement, and
  replacing a dataset destroys its data.
- `prevent_destroy` only protects resources whose block is still in the
  configuration. Deleting a whole `resource` block (or `acls.tf`) destroys
  everything it managed; for `truenas_filesystem_acl` that strips those paths'
  ACLs back to their mode bits. The `truenas-protected` flake check
  (`nix/tests/truenas-protected.py`) fails when a protected block disappears
  or loses `prevent_destroy`, and when a new `truenas_*` resource is in
  neither of its lists.
- Some in-place changes are destructive too: renaming a dataset moves its
  mountpoint out from under the NFS exports, and lowering a snapshot task's
  lifetime prunes existing snapshots on its next run.
- The provider refuses to destroy a dataset that still has children or
  snapshots unless `force_destroy` is set; never set it here.
- A user's `groups` lists only the groups configured for it, so membership
  added in the web interface is invisible to the plan. The
  `admin_group_members` check warns when `builtin_administrators` or `admins`
  gains a member.

## State

The state lives in `infra/truenas/terraform.tfstate` on scylla, untracked and
encrypted with `TRUENAS_TOFU_STATE_PASSPHRASE`. Every resource that existed
before OpenTofu has an `import` block, so after losing the state the next
`apply` imports everything again. That leaves TrueNAS untouched only while the
configuration matches the server; read the plan first.

A resource created by OpenTofu has no `import` block; before relying on a
rebuilt state, add one for it.

### A row recreated in the web interface

The import IDs are TrueNAS's row IDs. An `import` block is ignored once its
address is in the state, so after a share, user or task is deleted and
recreated by hand:

1. `infra/truenas/tofu state rm '<address>'`
2. Change its `id` in the configuration.
3. `infra/truenas/tofu plan` must show `import` for it, never `create`; a
   `create` would add a duplicate.

### Stop managing something

1. `infra/truenas/tofu state rm '<address>'`
2. Delete its entry (or its block) from the configuration, with no `plan` or
   `apply` in between.

The order matters. Deleting a whole block removes its `prevent_destroy` too,
so a plan run before `state rm` destroys the resource; for an ACL that strips
it. Removing only a `for_each` entry is refused by `prevent_destroy`, and
keeping the entry after `state rm` re-imports it.

## Backrest and the users export

Prostagma's Backrest backs up every home directory through the
`/mnt/reservoir/users` export, which maps every client to root, read-only, so
it ignores the homes' ACLs but cannot change anything. TrueNAS trusts any NFS
request from prostagma's address (reserved on the router) that comes from a
low port, so anything that holds that address can read every home. On
prostagma these keep everything but Backrest out
(`nix/hosts/prostagma/media-apps.nix`, `sso.nix`):

- The mount is at `/mnt/truenas/private/users`, inside a directory only root
  may enter; Backrest's container gets it as a read-only bind mount.
- Backrest runs as its own user (`backrest`, uid 970), so no host service
  running as `apps` can reach its mounts through `/proc/<pid>/root`.
- The firewall refuses NFS from every container and from every local user but
  root; the kernel's own NFS client is not affected.
- Backrest has no login of its own, so the firewall lets only Caddy and root
  connect to it, and Authelia lets only `admins` through Caddy. Caddy's admin
  API, which could route around Authelia, is limited to Caddy and root too.

To restore, open Backrest, browse a snapshot, restore the files into
Backrest's own storage and download them from the restore's entry; then copy
them into place, for example through the `users` share from scylla.

Backrest's plan lives in its own `config.json` on prostagma, not here. It
excludes `*.qcow2` in every path (in `users/proxmox`, a 50 GiB VM disk) and
the Proxmox ISOs: a running VM's disk copied file by file is not a usable
backup.

## ACLs on existing files

`acls.tf` sets the ACL of each listed path only. Inherited entries reach new
files, never ones that already exist, so removing or narrowing an inherited
entry also needs every file below rewritten. The rewrites on 2026-11-24 edited
just the one entry in each file's `system.nfs4_acl_xdr` attribute; the one for
`users/` first wrote each file's original attribute, base64 in the `acl`
field of a JSON line with its `path`, to
`~carter/.local/state/acl-backups/apps-users-2026-11-24.jsonl` on TrueNAS.
Restoring is `os.setxattr(path, "system.nfs4_acl_xdr", base64.b64decode(acl),
follow_symlinks=False)` for each line. TrueNAS's `nfs4xdr_setfacl -m`
rewrites far more than the named entry; do not use it for this.

## What is managed

Everything TrueNAS lets you configure that this NAS uses, file by file in
`infra/truenas/`:

- `pools.tf`: both pools and their topology. The provider refuses topology
  and name changes; do those in TrueNAS and reconcile with
  `tofu apply -refresh-only`.
- `datasets.tf`, `acls.tf`: datasets (except `.system` and `ix-apps`, which
  TrueNAS owns) and the ACLs at the top of each shared dataset and home
  directory.
- `shares.tf`, `access.tf`: NFS exports, SMB shares and share-level ACLs,
  both services' settings, the builtin privileges and the web certificate.
- `accounts.tf`: local users and groups, except email addresses and
  supplementary memberships of unmanaged groups.
- `tasks.tf`: snapshot, scrub and cron tasks (including the SMART tests 25.10
  moved to cron) and the init script.
- `services.tf`: which services start at boot (not whether one is running
  now), and the SSH, UPS, SNMP and FTP settings.
- `system.tf`, `network.tf`, `settings.tf`: general and advanced settings,
  NTP, the system dataset, network settings and the interface, and the
  Docker, catalog, audit, 2FA, TrueNAS Connect, TrueCommand, replication and
  resilver settings.
- `alerts.tf`: mail settings, alert services and the alert policy.
- `apps.tf`: the Tailscale app (version pinned) and the Docker Hub registry.

SSH offers only the `sntrup761x25519` post-quantum key exchange and no weak
ciphers, so a client needs OpenSSH 9.0 or later (or another client with
sntrup761). Members of `humans` may log in with a password; everyone else
needs a key. Password login is set in the `options` text, not with
`passwordauth`, because TrueNAS writes `options` after its own Match blocks
and sshd refuses `KexAlgorithms` there. Check a change before it reaches a
restart: `sshd -t` on a copy of `/etc/ssh/sshd_config` with a throwaway host
key (`-h`) runs without root.

Left on TrueNAS on purpose:

- Secrets the provider would otherwise store: the mail OAuth credentials, the
  from-address and name, the Tailscale auth key, the UPS monitor and SPICE
  passwords, and API keys (see the table above for the ones in fnox).
- TrueNAS's own: ACL templates, boot environments, and manual snapshots such
  as `pre-proxmox`.
- TrueNAS runs under Proxmox without nested virtualization, so it refuses
  every VM change, deletion included; it has no VMs.
- Nothing is configured for directory services, Kerberos, iSCSI, NVMe-oF,
  static routes, tunables, the keychain, cloud or rsync tasks, or reporting
  exporters; adopt them here if that changes.

Change TrueNAS here as reviewed commits, not in the web interface; `./drift`
shows anything changed there.
