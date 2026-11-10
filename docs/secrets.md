# Secrets

**Rule:** secrets are managed and encrypted with fnox in this repository. No
secret is ever committed in plain text, placed by hand on a host, or written
into the Nix store. A service that needs a secret gets it through the shared
module, `nix/modules/nixos/secrets.nix`.

**Risks the owner has accepted:**

- The store, `secrets/fnox.toml`, is public. Its ciphertext stays in Git history
  forever, so whoever ever holds a key that one of its values was encrypted to
  can read that value.
- The admin age key also exists on prostagma, so root or the admin user there
  can read every value, including the admin-only ones.
- The admin-only records include eltoro's agent store (its age key, its own
  fnox store, `.env` and provider logins) and both servers' SSH host keys.

## How it works

- `secrets/fnox.toml` is the store, and every value in it is age ciphertext.
  The `secrets-encrypted` flake check
  (`nix/tests/secrets-encrypted.py`) parses every value's age header and fails
  on any of these:
  - a value that is not a well-formed age file, or whose recipients differ from
    its provider's;
  - a recipient that is not a public key;
  - any key fnox does not need, or a comment;
  - any other fnox store, age file or age secret key in the tree.
- Each `[providers.*]` entry is one set of recipients. `admin` is the admin age
  key alone, for records no host reads. `prostagma` is the admin key plus
  prostagma's SSH host key. A host can decrypt only the providers that list its
  key, so eltoro cannot read prostagma's secrets and prostagma's host key cannot
  read eltoro's.
- `default_provider = "admin"`, because without a provider fnox stores a value
  in plain text.
- Hosts decrypt with their existing SSH host key
  (`/etc/ssh/ssh_host_ed25519_key`), which age accepts as an identity, so a
  host needs no key of its own and no bootstrap step.
- A host declares each secret it uses:

  ```nix
  dotfiles.fnox.secrets.EXAMPLE_TOKEN = {
    path = "/run/secrets/example/token"; # must be under /run/secrets
    owner = "root"; # default
    group = "root"; # default
    mode = "0400"; # default
    requiredBy = [ "example.service" ];
  };
  ```

  and points the service at `config.dotfiles.fnox.secrets.EXAMPLE_TOKEN.path`.
  Each secret gets a `fnox-secret-<KEY>.service` oneshot that runs as root,
  before the units in `requiredBy`, which require it. The unit:
  - resets `/run/secrets` and every directory down to the file to 0700 root,
    even if they already exist;
  - writes the file atomically with its owner and mode;
  - removes the file when it stops.

  If the value is missing or undecryptable, that unit fails, and only the
  services that require it fail with it.
- Files live on `/run`, a tmpfs, so they are never written to a filesystem on
  disk, and every boot rebuilds them from the repository. A tmpfs can be
  swapped out, though: on a host with swap, a decrypted value can reach the swap
  device.
- The directories are root-only. A service reads its file if it runs as root,
  or if systemd hands the file to it (`LoadCredential`, `BindReadOnlyPaths`,
  `--env-file`). A service that opens the path itself as another user needs one
  of those mechanisms.
- Values are stored as base64 of the original bytes, because `fnox set` trims
  piped input and cannot hold binary. Always store with `base64 -w0 | fnox set`
  and read with `fnox get | base64 -d`; the file a service sees is then byte
  for byte what was imported.
- The units embed the store file's path. Any change to `secrets/fnox.toml`,
  even to an admin-only record, restarts every secret unit on prostagma and,
  through `Requires=`, the services that use them. Once prostagma upgrades
  itself, that happens overnight (see [Server auto-upgrade](auto-upgrade.md)).

## What the public repository reveals

Without any key, a reader of the repository learns:

- every secret's name, which host reads it, and which service uses it;
- each value's approximate length (the ciphertext is the base64 of the value
  plus a fixed overhead);
- the hosts' public keys;
- from Git history, when each value changed.

Short values of 16 to 21 bytes, such as copyparty's account passwords, the
Audiobookshelf root password and the OpenSubtitles password, should be changed
to generated values if a person chose them. Their length is public, which
narrows a guess.

## Before any command

The admin key is `~/.config/fnox/age.txt` on scylla. Run every command below
from the repository checkout on scylla, in a shell where you have run:

```bash
cd ~/.config/dotfiles
export FNOX_CONFIG_DIR=/var/empty FNOX_AGE_KEY_FILE="$HOME/.config/fnox/age.txt"
sfnox() { fnox --no-daemon -c ./secrets/fnox.toml "$@"; }
set -o pipefail
```

`FNOX_CONFIG_DIR=/var/empty` keeps your personal global fnox config (and its
`default_provider`) out of the repository's store. None of these variables holds
a secret.

Never run `sfnox get` or `sfnox list --values` without a pipe: always end it in
`base64 -d | sha256sum`, `base64 -d | ssh …`, or `wc -c`. `sfnox list` (without
`--values`) only shows names and truncated ciphertext. `sfnox check` does not
decrypt anything: it reports a healthy config even with a key that opens
nothing, so never use it to prove a key works.

`set -o pipefail` only makes a failed pipeline report the failure: `sfnox set`
at its end still runs and stores whatever reached it, an empty value if the
first command failed. Check a new value's length with `sfnox get KEY_NAME |
base64 -d | wc -c`.

**Hashes:** several commands below print a SHA-256 of a secret. Compare it on
screen and never paste it anywhere public. A hash of a short password can be
guessed against offline.

## Add or change a secret

Pick the provider: the host that reads it (`prostagma`), or `admin` for a record
no host reads.

From a file already on a host (piped straight through, never on screen):

```bash
ssh prostagma 'sudo cat /path/on/host' | base64 -w0 | sfnox set KEY_NAME -p prostagma >/dev/null
```

A new random value:

```bash
nix run nixpkgs#openssl -- rand -hex 32 | tr -d '\n' | base64 -w0 | sfnox set KEY_NAME -p prostagma >/dev/null
```

`openssl` is not on scylla's PATH, hence `nix run`.

A value you type (hidden input; the variable dies with the subshell, and
nothing reaches shell history):

```bash
(IFS= read -rs v; printf %s "$v") | base64 -w0 | sfnox set KEY_NAME -p prostagma >/dev/null
```

Then check it without seeing it, by comparing hashes (do not share the
output):

```bash
sfnox get KEY_NAME | base64 -d | sha256sum
ssh prostagma 'sudo sha256sum /path/on/host'
```

Declare it in the host's Nix config (see above), run `nix flake check
--no-build`, commit, and deploy. On macOS, `base64` does not wrap and has no
`-w0`; drop the flag.

## Rotate a secret

1. Create the new value at its source if it has one (a Cloudflare tunnel
   credential, an OIDC client secret registered in an app, a VPN password).
2. Store it as in [Add or change a secret](#add-or-change-a-secret), commit,
   and deploy. The secret's unit restarts, rewrites the file, and restarts the
   services that require it.
3. If the old value leaked, revoke it at its source.

### After a key leaks

Adding or removing a recipient, or re-encrypting, never hides ciphertext that
is already published. Whoever holds a leaked key can decrypt every value in the
history that was encrypted to it. The only remedy is to change the values
themselves:

- **The admin key leaked:** change every value in the store at its source.
  That includes each credential inside eltoro's agent store (log the providers
  out and back in, and rotate every API key and token in its `.env` and fnox
  store), the operator records, and both servers' SSH host keys. Then
  [rotate the admin key](#rotate-the-admin-key).
- **A host's key leaked:** change every value addressed to that host (every
  secret with that host's provider), then give the host a new SSH host key and
  [enrol it again](#enrol-a-new-or-rebuilt-host).

## Enrol a new or rebuilt host

1. Read the host's public key, and confirm its fingerprint on the host's own
   console (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`):

   ```bash
   ssh-keyscan -t ed25519 newhost
   ```

2. Add a provider for a new host, or replace the old key of a rebuilt host
   whose SSH host key changed, in `secrets/fnox.toml`:

   ```toml
   [providers.newhost]
   type = "age"
   recipients = [
       "age175w5ysy6tncyaelddud60w59hqa2s9ht7p2cezd28pgyy595jp8q2wt0aw",
       "ssh-ed25519 AAAA… root@newhost",
   ]
   ```

3. Re-encrypt that provider's existing values to the new recipients (the admin
   key decrypts them):

   ```bash
   sfnox reencrypt -p newhost --dry-run
   sfnox reencrypt -p newhost -f
   ```

4. Import the host's module in its `default.nix`, declare its secrets, commit,
   and deploy.

### Rebuilding a host with its old identity

The store holds admin-only backups of prostagma's and eltoro's private SSH host
keys: `<HOST>_SSH_HOST_ED25519_KEY`, `<HOST>_SSH_HOST_RSA_KEY` and
`<HOST>_SSH_HOST_MLDSA44_ED25519_KEY`. Prostagma's ed25519 key is also its fnox
identity, so restoring it lets a rebuilt prostagma read its secrets again with
no re-enrolment. Clients' `known_hosts` keep matching too.

Restore the keys onto the new container before its first deploy from this
repository (before `./install prostagma` or `./install eltoro`). Each key
goes straight from fnox into its file, 0600 root, and the public key is
re-derived on the host:

```bash
host=prostagma; HOST=PROSTAGMA   # or: host=eltoro; HOST=ELTORO (use root@eltoro below)
for kind in ed25519 rsa mldsa44_ed25519; do
  key=$(printf '%s' "${HOST}_SSH_HOST_${kind}_KEY" | tr '[:lower:]' '[:upper:]')
  sfnox get "$key" | base64 -d |
    ssh "$host" "sudo install -m 0600 -o root -g root /dev/stdin /etc/ssh/ssh_host_${kind}_key &&
      sudo sh -c 'ssh-keygen -y -f /etc/ssh/ssh_host_${kind}_key > /etc/ssh/ssh_host_${kind}_key.pub'"
done
ssh "$host" 'sudo systemctl restart sshd'
```

The fresh container answers with its template's host key until `sshd`
restarts, so the first connection may need its `known_hosts` entry removed
(`ssh-keygen -R <host>`). Afterwards `ssh-keyscan -t ed25519 <host> |
ssh-keygen -lf -` must show the fingerprint the host had before. On eltoro,
root's login shell is fish, which runs the same double-quoted command; there is
no `sudo`, so drop it.

A rebuilt host with a fresh key instead fails every `fnox-secret-*` unit, and
only the services that require them, until it is enrolled as above.

## Rotate the admin key

The old key stays in place until a deploy with the new one has succeeded.

1. Make the new key, and record every value's hash with the **old** key (do not
   share the output):

   ```bash
   age-keygen -o ~/.config/fnox/age.new.txt
   new=$(age-keygen -y ~/.config/fnox/age.new.txt)
   hashes() { for k in $(sfnox list | awk 'NR > 1 && $1 ~ /^[A-Z0-9_]+$/ { print $1 }'); do
     printf '%s %s\n' "$k" "$(sfnox get "$k" | base64 -d | sha256sum | cut -d' ' -f1)"; done; }
   hashes > ~/.config/fnox/hashes.old
   providers=$(sed -n 's/^\[providers\.\(.*\)\]$/\1/p' secrets/fnox.toml)
   ```

2. **Add** the new public key (`$new`) to every provider's `recipients` in
   `secrets/fnox.toml`, beside the old one, and re-encrypt while the old key is
   the identity:

   ```bash
   for p in $providers; do sfnox reencrypt -p "$p" -f; done
   ```

3. Prove that the new key opens every value, by hash:

   ```bash
   FNOX_AGE_KEY_FILE="$HOME/.config/fnox/age.new.txt" hashes | diff ~/.config/fnox/hashes.old - && echo "new key opens every value"
   ```

   Stop if `diff` prints anything.
4. Remove the old public key from every provider, re-encrypt with the new key
   as the identity, and check again:

   ```bash
   export FNOX_AGE_KEY_FILE="$HOME/.config/fnox/age.new.txt"
   for p in $providers; do sfnox reencrypt -p "$p" -f; done
   hashes | diff ~/.config/fnox/hashes.old - && echo "still every value"
   ```

5. Run `nix flake check --no-build`, commit, and deploy prostagma. Confirm its
   `fnox-secret-*` units succeed (see [First deployment](#prostagma)).
6. Only then retire the old key: `mv ~/.config/fnox/age.new.txt
   ~/.config/fnox/age.txt`. Remove `~/.config/fnox/hashes.old` and every other
   copy of the old key, including prostagma's. It still opens the old
   ciphertext in Git history, so [change the values](#after-a-key-leaks) it
   must no longer open.

## First deployment

Nothing reads the new files until a host is deployed. The old hand-placed files
stay until the steps below confirm the services use the new ones.

### prostagma

Deploy from scylla, then run the remaining steps in one shell on prostagma
(`ssh prostagma`), since later steps reuse the `files` list from step 3. Their
output shows names, owners and modes only.

1. From scylla: `./install prostagma`.
2. Every secret unit succeeded, and nothing failed:

   ```bash
   systemctl list-units 'fnox-secret-*' --all --no-legend
   systemctl --failed --no-legend
   ```

3. Each new file is identical to the old one, with the same owner and mode.
   `cmp -s` prints nothing; only the verdict is shown:

   ```bash
   files='qbittorrent-vpn.env cloudflared/56e33628-8005-4027-ae33-b55e7f0bd78b.json authelia/jwt_secret authelia/session_secret authelia/storage_encryption_key authelia/oidc_hmac_secret authelia/oidc_issuer_private.pem copyparty/alex_password copyparty/carter_password copyparty/haley_password'
   sudo bash -c "for f in $files; do
     cmp -s /run/secrets/\$f /var/lib/secrets/\$f && same=same || same=DIFFERENT
     echo \"\$same \$(stat -c '%U:%G %a' /run/secrets/\$f) \$(stat -c '%U:%G %a' /var/lib/secrets/\$f) \$f\"
   done"
   ```

4. The services point at the new paths:

   ```bash
   systemctl cat authelia-main cloudflared-tunnel-56e33628-8005-4027-ae33-b55e7f0bd78b | grep '^LoadCredential='
   systemctl show -p BindReadOnlyPaths copyparty
   grep -o -- '--env-file [^ ]*' "$(systemctl show -p ExecStart --value docker-qbittorrent-vpn | grep -o 'path=[^ ;]*' | head -1 | cut -d= -f2)"
   ```

   `systemctl show -p LoadCredential` prints `[unprintable]`, and the
   container's `--env-file` flag is in its start script, not in the unit.

5. Prove that nothing reads the old files. Rename only those ten files, restart
   the services, and check that they come back. Nothing else under
   `/var/lib/secrets` moves (the binary cache's generated secret, if present,
   stays where it is). Then log in to Authelia, copyparty and qBittorrent, and
   confirm the tunnel serves `files.cartermcbri.de`. qBittorrent's page takes
   a few minutes to answer, until its VPN has connected:

   ```bash
   sudo bash -c "for f in $files; do mv -n /var/lib/secrets/\$f /var/lib/secrets/\$f.pre-fnox; done"
   sudo systemctl restart authelia-main cloudflared-tunnel-56e33628-8005-4027-ae33-b55e7f0bd78b copyparty docker-qbittorrent-vpn
   systemctl is-active authelia-main cloudflared-tunnel-56e33628-8005-4027-ae33-b55e7f0bd78b copyparty docker-qbittorrent-vpn
   ```

6. Clean up (below) once you are satisfied.

**Rolling back:** put the files back, then return to the previous generation,
which reads the old paths:

```bash
sudo bash -c "for f in $files; do mv -n /var/lib/secrets/\$f.pre-fnox /var/lib/secrets/\$f; done"
sudo nixos-rebuild switch --rollback
```

`/run/secrets` is tmpfs and goes away at the next boot.

### eltoro

Nothing moves on eltoro: the agent keeps its own fnox store, and the
repository only holds an admin-only backup of what a rebuild would lose (see
below). The only secret eltoro reads from this store is its Beszel agent's
token, once [Monitoring](monitoring.md#first-deployment) enrols it.

### Clean-up: removing the old plain-text files

This is the owner's step, after the checks above.

prostagma: the ten files the services read, now in fnox and renamed in step 5:

```bash
sudo bash -c "for f in $files; do rm -v -- /var/lib/secrets/\$f.pre-fnox; done"
```

Plain text left on the hosts besides those, removed by the same rule:

- **Operator records under `/var/lib/secrets`** that no service reads (OIDC
  client secrets, an Authelia user password, app credentials). Each is now an
  admin-only record in fnox, so the host copies can go. Leave
  `/var/lib/secrets/attic/` alone: atticd generated that secret on the host,
  it is not in fnox, and deleting it revokes every cache token (see
  [Binary cache](binary-cache.md#revoke-every-token)).
- **Stray copies and backups** of values that fnox now manages, on both hosts.
- **Leftovers of services that are not in the Nix configuration.** A
  hand-started container could still use them, so check before deleting.
  Revoke their credentials at the source regardless.
- **A stale copy of eltoro's agent state** under root's home.

The exact paths and removal commands for each host are kept privately, outside
this repository, so that this public file is not a map of where plain text
sits. Review that list before running it.

## eltoro's agent store

The agent's own fnox store stays where it is. `/var/lib/hermes/.hermes/fnox.toml`
is encrypted to the agent's key at `/var/lib/hermes/.config/fnox/age.txt`, both
owned by `hermes`, and the agent's workflow (`fnox import` after a wizard)
writes to it. Moving it here would make root write into a directory the agent
controls, which is the symlink hazard `hermes-settings-repair` guards against.
It would also make every re-import a commit.

What a rebuild would lose is backed up as **admin-only** records, so neither
host's key can read them and the agent gains nothing it cannot read today:
`ELTORO_HERMES_AGE_KEY`, `ELTORO_HERMES_FNOX_TOML`, `ELTORO_HERMES_ENV` and
`ELTORO_HERMES_AUTH_JSON` (provider logins; they refresh, so a restored copy may
need a fresh login).

Every read and write of these files runs **as `hermes`**, never as root. The
agent can replace any of its files with a symlink. Read as root, a symlink to a
root-only file would pull that file into the backup, and a later restore would
hand it to the agent. Read as `hermes`, it can only return what the agent can
already read. The backup holds whatever the agent left in those files, and
restoring it as `hermes` gives the agent nothing beyond its own.

Refresh the backup after the agent's store changes. Root's login shell on
eltoro is fish, which runs `runuser … cat …` as a plain command:

```bash
for pair in ELTORO_HERMES_AGE_KEY:/var/lib/hermes/.config/fnox/age.txt \
            ELTORO_HERMES_FNOX_TOML:/var/lib/hermes/.hermes/fnox.toml \
            ELTORO_HERMES_ENV:/var/lib/hermes/.hermes/.env \
            ELTORO_HERMES_AUTH_JSON:/var/lib/hermes/.hermes/auth.json; do
  ssh -n root@eltoro runuser -u hermes -- cat "${pair#*:}" | base64 -w0 | sfnox set "${pair%%:*}" -p admin >/dev/null
done
```

Restore onto a rebuilt eltoro before starting the services, again as `hermes`.
The remote command is a single-quoted `sh -c` that fish and sh read the same
way. The tmpfiles rules then set `.env` back to `root:hermes 0640`:

```bash
for pair in ELTORO_HERMES_AGE_KEY:/var/lib/hermes/.config/fnox/age.txt \
            ELTORO_HERMES_FNOX_TOML:/var/lib/hermes/.hermes/fnox.toml \
            ELTORO_HERMES_ENV:/var/lib/hermes/.hermes/.env \
            ELTORO_HERMES_AUTH_JSON:/var/lib/hermes/.hermes/auth.json; do
  sfnox get "${pair%%:*}" | base64 -d |
    ssh root@eltoro runuser -u hermes -- sh -c \
      "'umask 077; mkdir -p \"\$(dirname \"\$1\")\" && cat > \"\$1\"'" _ "${pair#*:}"
done
ssh root@eltoro 'systemd-tmpfiles --create && systemctl restart hermes-gateway hermes-dashboard'
```

## Still outside fnox

- **scylla's SMB credential**, `/etc/credstore.encrypted/truenas-smb.creds`.
  It is a systemd credential sealed to the machine, so it already lives encrypted
  and cannot be read without `sudo`. To move it into fnox, re-create it from the
  TrueNAS account on scylla, and give scylla a provider and the module.
- **scylla's SSH host keys.** They need `sudo` to read; back them up like the
  servers' (admin-only) when that is available.
- **Tailscale authentication.** By the owner's choice no auth key is stored;
  each host is logged in by hand with `sudo tailscale up`.
- **The binary cache's token-signing secret**, `/var/lib/secrets/attic/environment`.
  It is generated on the host on first start by design (see
  [Binary cache](binary-cache.md)).
- **State applications generate and rewrite themselves**: databases, session
  stores, keys an app created in its own config directory, Tailscale's
  certificates. fnox cannot manage files an application rewrites; they belong
  to the application and its backups.
- **The admin's own keys and personal stores on prostagma**: the admin age key,
  a personal fnox config, and an admin SSH key. They are not deployment inputs.
  The age key's presence there is an accepted risk (see the top of this page).
