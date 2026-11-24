# TrueNAS

The TrueNAS VM on Proxmox (tailnet name `truenas`, LAN `192.168.5.252`, the
HDDs passed through) is managed with OpenTofu from `infra/truenas/`, using the
official provider
[`truenas/truenas`](https://github.com/truenas/terraform-provider-truenas).
Prostagma mounts its NFS exports and scylla mounts its SMB shares; both sides
depend on the IDs in `infra/truenas/accounts.tf` and `acls.tf`.

## Run it

From the checkout on scylla:

```bash
infra/truenas/tofu init      # once, and after a provider bump
infra/truenas/tofu plan
infra/truenas/tofu apply     # only after reading the whole plan
```

The wrapper decrypts its secrets from fnox into its own environment and runs
OpenTofu from the flake's nixpkgs. Until `TRUENAS_TOFU_API_KEY` exists, it
prompts for carter's TrueNAS password on every run instead.

| fnox key (admin) | Used for |
|---|---|
| `TRUENAS_TOFU_STATE_PASSPHRASE` | Encrypting the state and plan files |
| `TRUENAS_CONNECTIVITY_CHECK_URL` | The healthchecks.io URL in the connectivity cron job |
| `TRUENAS_TOFU_API_KEY` | Logging in to TrueNAS (not created yet) |

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
  ACLs back to their mode bits.
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

## What is managed

- Datasets on both pools, except `.system` and `ix-apps`, which TrueNAS owns,
  including quotas and reservations
- ACLs at the top of each shared dataset and of every home directory under
  `users/`
- NFS exports, SMB shares and both services' settings
- Local users and groups, except email addresses (kept out of this public
  repository) and supplementary memberships of unmanaged groups
- Periodic snapshot, scrub and cron tasks (including the SMART tests 25.10
  moved to cron), the init script, and which services are enabled at boot.
  Whether a service is running at the moment is not managed.

Not yet managed, and still set in the web interface: SMB share-level ACLs, the
Tailscale app, the `devenv` VM, alert services and mail, network, system and
SSH/UPS settings, certificates, and pool topology.

The configuration records the server as it was at adoption, inconsistencies
included: `aclmode` differs between media datasets, `users/carter` and
`users/whitley` are owned by root, and the snapshot task's excludes name
datasets that no longer exist. Fix those as reviewed changes, not in the web
interface.
