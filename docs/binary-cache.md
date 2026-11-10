# Binary cache

Prostagma runs [Attic](https://github.com/zhaofengli/attic) as a private Nix
binary cache for the Linux hosts. It holds only what the public caches lack:
`attic push` skips any path signed by an upstream cache's key, and anything not
fetched for 14 days is garbage-collected.

| | |
|---|---|
| Server | `nix/machines/prostagma/binary-cache.nix` |
| Client (scylla, prostagma, eltoro) | `nix/modules/binary-cache.nix`, off until its public key is set |
| VM test | `nix build .#checks.x86_64-linux.binary-cache` (`nix/tests/binary-cache.nix`) |
| URL | `http://prostagma.dropbear-tortoise.ts.net:8199/fleet` |
| Storage | `/srv/apps/attic` (chunks), Postgres database `atticd` |
| Token signing secret | `/var/lib/secrets/attic/environment`, generated on first start |

The MacBook never uses this cache: `nix/lib/mksystem.nix` adds the client
module only to NixOS hosts.

Only the tailnet can reach the cache. atticd listens on port 8199 on every
interface, and the firewall opens that port on `tailscale0` alone. The cache is
an Attic "public" cache, so tailnet clients pull without a token; pushing needs
one. Nix checks every path against the cache's signing key, so plain HTTP is
fine inside the tailnet.

Steps marked **You** need your accounts or a deploy, so only you can do them.
Run the rest wherever the step says.

## 1. First deployment (**You**)

On prostagma, in the dotfiles checkout, on a branch that contains this change:

```sh
./install
```

Check the result on prostagma:

```sh
systemctl status atticd.service atticd-secret.service --no-pager
sudo stat -c '%a %U %G' /var/lib/secrets/attic/environment   # 600 root root
curl -sS http://prostagma.dropbear-tortoise.ts.net:8199/       # any HTTP reply
```

## 2. Create the cache and read its public key (**You**)

The cache's signing key is created with the cache and kept in its database.

On prostagma, in the dotfiles checkout, open a shell with the Attic client this
flake pins, so that client and server versions match:

```sh
nix shell --inputs-from . nixpkgs#attic-client
```

Log in with a one-hour token that may only create and read the cache. The token
goes straight into `~/.config/attic/config.toml`, never onto the screen or into
shell history:

```sh
attic login prostagma http://prostagma.dropbear-tortoise.ts.net:8199 "$(sudo atticd-atticadm make-token --sub admin --validity 1h --create-cache fleet --pull fleet)"
```

Create the cache. Name every upstream cache that every Linux host also
substitutes from (see `nix/modules/nix.nix`), so that pushes skip their paths:

```sh
attic cache create prostagma:fleet --public --upstream-cache-key-name cache.nixos.org-1 --upstream-cache-key-name niks3.numtide.com-1 --upstream-cache-key-name vicinae.cachix.org-1 --upstream-cache-key-name nix-community.cachix.org-1
attic cache info prostagma:fleet
```

`attic cache info` prints a line `Public Key: fleet:…`. In
`nix/modules/binary-cache.nix`, replace `default = null;` with that key in
quotes:

```nix
    default = "fleet:…";
```

Commit, then deploy every Linux host: `./install` on scylla and on prostagma,
and `./install-eltoro` from scylla. Every host's system derivation changes
(new `substituters`, `trusted-public-keys`, `connect-timeout = 5`,
`stalled-download-timeout = 30`, `fallback = true` in `nix.conf`); the
MacBook's must not.

Check on any Linux host:

```sh
nix config show substituters      # lists the fleet URL
nix store info --store http://prostagma.dropbear-tortoise.ts.net:8199/fleet
```

## 3. Tokens (**You**)

Hosts pull without a token, so no pull token is needed.

CI needs a push token. Treat it like root on every Linux host: the cache signs
whatever is pushed with the key every host trusts, so whoever holds the token
can put any binary on scylla, prostagma and eltoro at their next rebuild. It is
valid for 90 days.

Create the `binary-cache` GitHub Environment first (step 4). Then, from a
machine where `gh` is logged in and `ssh prostagma` works, mint the token and
store it there in one pipe, so it never reaches the screen:

```sh
ssh prostagma sudo atticd-atticadm make-token --sub github-actions --validity 90d --pull fleet --push fleet \
  | gh secret set ATTIC_TOKEN --repo carterworks/dotfiles --env binary-cache
```

`gh` reads the value from standard input and drops the trailing newline.

### Rotate the CI token

Before the 90 days are up, run the same pipe again; `gh` replaces the secret.
`gh secret list --repo carterworks/dotfiles --env binary-cache` shows when it
was last set. Attic cannot revoke a single token, so the old one stays valid
until it expires. If it may have leaked, revoke every token instead.

### Revoke every token

Attic tokens are signed JWTs with no revocation list. To revoke them all, delete
the token signing secret and restart; a new one is generated. On prostagma:

```sh
sudo rm /var/lib/secrets/attic/environment
sudo systemctl restart atticd.service
```

This also invalidates `ATTIC_TOKEN`, so CI pushes fail until you mint a new one
with the pipe at the start of this step.

## 4. CI workflow requirements

The push workflow is not written yet. A leaked push token or tailnet
credential is the main risk this cache adds (step 3), so whoever writes it must
meet all of these:

- **Secrets in a GitHub Environment limited to `main`.** `ATTIC_TOKEN`,
  `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_SECRET` live in an Environment named
  `binary-cache`, not in repository secrets, and the push job declares
  `environment: binary-cache`. A workflow edited on another branch then cannot
  read them.
- **Only trusted triggers.** Push to the cache only on `push` to `main` or on
  `schedule`. Never use `pull_request_target`, and never `workflow_run` on a
  run that built pull-request code.
- **Pinned and minimal.** Every action is pinned by full commit SHA. Attic is
  the flake-pinned client (`nix run --inputs-from . nixpkgs#attic-client --`).
  The workflow sets `permissions: contents: read`, and only a job that needs
  more gets more. The Nix sandbox stays on.
- **Tailnet access limited to `tag:ci`.** The Tailscale OAuth client may only
  create keys for `tag:ci`, and those keys are ephemeral and preauthorised (the
  action's defaults; do not override them), so each runner leaves the tailnet
  when its job ends.

### GitHub Environment (**You**)

In the repository's **Settings → Environments**, create `binary-cache`. Under
**Deployment branches and tags**, choose **Selected branches and tags** and add
`main` only. Step 3 and the Tailscale policy below store the secrets there.

### Workflow steps

For whoever writes the workflow; replace each `<SHA>` with the commit of the
release you reviewed:

```yaml
permissions:
  contents: read
jobs:
  push-cache:
    if: github.ref == 'refs/heads/main'
    environment: binary-cache
    runs-on: ubuntu-latest
    steps:
      # checkout and Nix install steps, also pinned by SHA
      - uses: tailscale/github-action@<SHA> # v4
        with:
          oauth-client-id: ${{ secrets.TS_OAUTH_CLIENT_ID }}
          oauth-secret: ${{ secrets.TS_OAUTH_SECRET }}
          tags: tag:ci
          ping: prostagma.dropbear-tortoise.ts.net
      - run: |
          nix run --inputs-from . nixpkgs#attic-client -- login prostagma http://prostagma.dropbear-tortoise.ts.net:8199 "$ATTIC_TOKEN"
          nix run --inputs-from . nixpkgs#attic-client -- push prostagma:fleet ./result
        env:
          ATTIC_TOKEN: ${{ secrets.ATTIC_TOKEN }}
```

`attic push` pushes the whole closure of `./result` minus anything signed by an
upstream key. Paths CI downloaded keep the upstream signature, so only unfree
repacks and local builds go up.

### Tailscale policy (**You**)

In the admin console, under **Access controls**, add the following to the
tailnet policy file. Get each address with `tailscale ip -4 <host>` from any
machine on the tailnet, and the routes prostagma advertises with
`tailscale debug prefs | jq .AdvertiseRoutes` on prostagma.

```jsonc
"tagOwners": {
  "tag:ci": ["autogroup:admin"],
},
"hosts": {
  "prostagma": "<prostagma's 100.x address>",
  "scylla": "<scylla's 100.x address>",
  "eltoro": "<eltoro's 100.x address>",
},
"grants": [
  // CI runners may reach the cache port on prostagma and nothing else.
  {"src": ["tag:ci"], "dst": ["prostagma"], "ip": ["tcp:8199"]},
],
"tests": [
  {
    "src": "tag:ci",
    "accept": ["prostagma:8199"],
    "deny": [
      "prostagma:22", "prostagma:443",
      "scylla:22", "eltoro:22",
      "<an address inside a route prostagma advertises>:443",
      "1.1.1.1:443",
    ],
  },
],
```

Merge these into your existing sections rather than adding second copies. The
console rejects a policy that breaks a test, but a test checks only the
destinations it lists: here prostagma's SSH and HTTPS ports, SSH on scylla and
eltoro, one LAN address and one internet address. Add a `deny` entry for any
other device you care about.

Before the first CI runner joins, also read the whole policy and confirm:

- No rule or grant has `src: "*"`. Tagged nodes match `*`, so such a rule
  applies to CI. Narrow it to `autogroup:member` or the tags that need it.
- No rule or grant that applies to `tag:ci` reaches `*`, `autogroup:internet`
  (exit nodes), or a LAN range (prostagma advertises subnet routes).
- No grant to a Tailscale Service (`svc:…`) applies to `tag:ci`. Services have
  their own addresses, which the tests above cannot see.
- No `ssh` rule applies to `tag:ci`; the tests do not cover Tailscale SSH.

Then, under **Settings → OAuth clients**, create a client with the `auth_keys`
write scope and the tag `tag:ci` only, and store its ID and secret in the
Environment. `gh` prompts for each value without echoing it:

```sh
gh secret set TS_OAUTH_CLIENT_ID --repo carterworks/dotfiles --env binary-cache
gh secret set TS_OAUTH_SECRET --repo carterworks/dotfiles --env binary-cache
```

## 5. Size and retention

On prostagma:

```sh
sudo du -sh /srv/apps/attic
df -h /srv/apps
sudo -u postgres psql atticd -c "select pg_size_pretty(pg_database_size('atticd'))"
sudo -u postgres psql atticd -c "select count(*) as paths, pg_size_pretty(sum(nar_size)) as uncompressed from nar"
sudo -u postgres psql atticd -c "select pg_size_pretty(sum(file_size)) as stored from chunk"
```

A path is removed once it has been neither pushed nor fetched for the retention
period. Garbage collection runs when atticd starts and every 12 hours after.

To change the retention for every cache, edit
`garbage-collection.default-retention-period` in
`nix/machines/prostagma/binary-cache.nix` and deploy prostagma. A
per-cache value set with `attic` overrides the default until it is reset. The
token from step 2 has expired and could not configure anyway, so log in with a
fresh one-hour token that may only configure the cache. On prostagma, in the
dotfiles checkout:

```sh
nix shell --inputs-from . nixpkgs#attic-client
attic login prostagma http://prostagma.dropbear-tortoise.ts.net:8199 "$(sudo atticd-atticadm make-token --sub admin --validity 1h --configure-cache fleet --configure-cache-retention fleet)"
attic cache configure prostagma:fleet --retention-period '7 days'
attic cache configure prostagma:fleet --reset-retention-period
```

Every `attic cache configure` without `--retention-period` also resets the
cache's retention to the default, so any configure token needs
`--configure-cache-retention` as well as `--configure-cache`.

To collect now rather than waiting for the next run:

```sh
sudo systemctl restart atticd.service
```

To estimate how much a host adds per generation, sum the paths in its closure
that no upstream cache signed. On a machine that has built the host's system:

```sh
nix path-info -r --json "$(nix build --no-link --print-out-paths .#nixosConfigurations.scylla.config.system.build.toplevel)" | jq '[.[] | select(all(.signatures[]?; test("^(cache.nixos.org-1|niks3.numtide.com-1|vicinae.cachix.org-1|nix-community.cachix.org-1):") | not)) | .narSize] | add / 1073741824'
```

That is uncompressed NAR size in GiB. zstd and chunk deduplication across
versions shrink what is stored.

### Size cap

Attic has no size limit, and `/srv/apps` also holds Postgres (Immich) and
Docker. Every 5 minutes `atticd-size-guard.timer` measures `/srv/apps/attic`;
over the cap (`sizeCapGiB` in `nix/machines/prostagma/binary-cache.nix`,
30 GiB) it stops atticd and fails. You see it in `systemctl --failed` on
prostagma, and the reason in its journal:

```sh
journalctl -u atticd-size-guard.service -n 5 --no-pager
```

While atticd is stopped, hosts fall back to other caches (see "Behaviour when
the cache is down") and CI pushes fail. To recover (**You**), on prostagma,
pick one:

- **Collect with the current retention.** Garbage collection runs when atticd
  starts, so `sudo systemctl start atticd.service`. If the cache is still over
  the cap, the guard stops it again within 5 minutes.
- **Shorten the retention**, as above, deploy prostagma, then
  `sudo systemctl start atticd.service`.
- **Raise the cap.** Check `df -h /srv/apps` first, change `sizeCapGiB`, deploy
  prostagma, then `sudo systemctl start atticd.service`.

Then clear the failed state: `sudo systemctl start atticd-size-guard.service`.

## 6. New signing key (**You**)

If the cache's signing key may have leaked (it is in the `atticd` database,
under `/srv/apps/postgresql`), give the cache a new key pair. The paths stay:
Attic signs each narinfo as it serves it, so everything is served under the new
key at once. On prostagma, in the dotfiles checkout:

```sh
nix shell --inputs-from . nixpkgs#attic-client
attic login prostagma http://prostagma.dropbear-tortoise.ts.net:8199 "$(sudo atticd-atticadm make-token --sub admin --validity 1h --configure-cache fleet --configure-cache-retention fleet --pull fleet)"
attic cache configure prostagma:fleet --regenerate-keypair
attic cache info prostagma:fleet
```

Like any `attic cache configure`, this resets a per-cache retention (step 5).
As in step 2, put the new `Public Key` in `nix/modules/binary-cache.nix`,
commit, and deploy every Linux host. Until a host is deployed it rejects the
cache's paths and falls back to other caches or to building.

Each host's Nix daemon also keeps the narinfo of every path it has looked up,
old signature included, for up to 30 days (`narinfo-cache-positive-ttl`), and
rejects those paths until the entry expires. After deploying, clear it on each
Linux host:

```sh
sudo sh -c 'rm -f /root/.cache/nix/binary-cache-v*.sqlite*' && sudo systemctl restart nix-daemon.service
```

If the token signing secret may have leaked too, also revoke every token
(step 3).

## 7. Wipe and rebuild (**You**)

Use this if the cache is ever corrupted. It deletes everything and gives the
cache a new signing key. For a leaked signing key alone, step 6 is enough. On
prostagma:

```sh
sudo systemctl stop atticd.service
sudo -u postgres dropdb atticd
sudo -u postgres createdb -O atticd atticd
sudo find /srv/apps/attic -mindepth 1 -delete
sudo systemctl start atticd.service
```

Then repeat step 2: create the cache, put its new public key in
`nix/modules/binary-cache.nix`, deploy every Linux host, and clear each host's
narinfo cache as in step 6. Until then, hosts reject the new cache's signatures
and fall back to other caches or to building. The CI token keeps working,
because tokens depend only on the signing secret, not on the database.

## Behaviour when the cache is down

Hosts keep working. With the tailnet or prostagma unreachable, the first
lookup costs about 30 seconds (five 5-second connection attempts with backoff).
Nix then disables the cache for 60 seconds and uses the other caches or builds.

A host that looks up a path before CI has pushed it remembers the miss for an
hour (Nix's `narinfo-cache-negative-ttl`), so it may build or download that
path elsewhere during that hour.

## El Toro

eltoro's firewall (`nix/machines/eltoro.nix`) lets the Nix daemon, which runs
as root, reach the cache over IPv4: the `tailscale0` OUTPUT rules accept any
packet not owned by `hermes`. The `hermes` user gets no new connections into
`100.64.0.0/10`. Its packets reach only the DNS and established-connection
rules, then hit the REJECT. IPv6 to the tailnet is rejected for every user,
root included, so the daemon's lookup falls back to prostagma's IPv4 record
straight away.
