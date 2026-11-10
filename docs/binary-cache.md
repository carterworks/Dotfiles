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

On prostagma, in `bash` (start it first if your shell is fish), make a one-hour
admin token and log the Attic client in with it:

```sh
export ADMIN_TOKEN="$(sudo atticd-atticadm make-token --sub admin --validity 1h --create-cache fleet --configure-cache fleet --configure-cache-retention fleet --destroy-cache fleet --pull fleet --push fleet)"
nix shell nixpkgs#attic-client
attic login prostagma http://prostagma.dropbear-tortoise.ts.net:8199 "$ADMIN_TOKEN"
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
`fallback = true` in `nix.conf`); the MacBook's must not.

Check on any Linux host:

```sh
nix config show substituters      # lists the fleet URL
nix store info --store http://prostagma.dropbear-tortoise.ts.net:8199/fleet
```

## 3. Tokens (**You**)

Hosts pull without a token, so no pull token is needed.

CI needs a push token. On prostagma:

```sh
sudo atticd-atticadm make-token --sub github-actions --validity 1y --pull fleet --push fleet
```

Store it as a repository secret from a machine where `gh` is logged in. `gh`
prompts for the value:

```sh
gh secret set ATTIC_TOKEN --repo carterworks/dotfiles
```

Attic tokens are signed JWTs with no revocation list. To revoke every token at
once, delete the signing secret and restart; a new one is generated:

```sh
sudo rm /var/lib/secrets/attic/environment
sudo systemctl restart atticd.service
```

## 4. What the CI job needs

The workflow itself lives elsewhere. It needs:

- **URL**: `http://prostagma.dropbear-tortoise.ts.net:8199`, cache `fleet`.
- **Token**: secret `ATTIC_TOKEN` (step 3). The repository is public, so only
  push from workflows that pull requests from forks cannot trigger (pushes to
  `main`, schedules). GitHub withholds secrets from fork pull requests.
- **Tailnet access**: secrets `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_SECRET`, and
  the tag `tag:ci`, described below.

Workflow steps, for whoever writes the workflow:

```yaml
- uses: tailscale/github-action@v4
  with:
    oauth-client-id: ${{ secrets.TS_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TS_OAUTH_SECRET }}
    tags: tag:ci
    ping: prostagma.dropbear-tortoise.ts.net
- run: |
    nix run nixpkgs#attic-client -- login prostagma http://prostagma.dropbear-tortoise.ts.net:8199 "$ATTIC_TOKEN"
    nix run nixpkgs#attic-client -- push prostagma:fleet ./result
  env:
    ATTIC_TOKEN: ${{ secrets.ATTIC_TOKEN }}
```

`attic push` pushes the whole closure of `./result` minus anything signed by an
upstream key. Paths CI downloaded keep the upstream signature, so only unfree
repacks and local builds go up.

### Tailscale policy (**You**)

In the admin console, under **Access controls**, add the following to the
tailnet policy file. Get prostagma's address with `tailscale ip -4` on
prostagma.

```jsonc
"tagOwners": {
  "tag:ci": ["autogroup:admin"],
},
"hosts": {
  "prostagma": "<prostagma's 100.x address>",
},
"grants": [
  // CI runners may reach the cache port on prostagma and nothing else.
  {"src": ["tag:ci"], "dst": ["prostagma"], "ip": ["tcp:8199"]},
],
"tests": [
  {"src": "tag:ci", "accept": ["prostagma:8199"], "deny": ["prostagma:22", "prostagma:443"]},
],
```

Merge these into your existing sections rather than adding second copies. Any
existing rule whose `src` is `"*"` also matches tagged nodes, which would
give CI the whole tailnet. Narrow such rules to `autogroup:member` (or the
tags that need them). The `tests` block makes the console reject a policy that
lets `tag:ci` reach anything else on prostagma.

Then, under **Settings → OAuth clients**, create a client with the `auth_keys`
write scope and the tag `tag:ci`, and store its ID and secret:

```sh
gh secret set TS_OAUTH_CLIENT_ID --repo carterworks/dotfiles
gh secret set TS_OAUTH_SECRET --repo carterworks/dotfiles
```

The action joins each runner as an ephemeral node, so it disappears from the
tailnet when the job ends.

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
per-cache value set with `attic` overrides the default until it is reset (admin
token from step 2):

```sh
attic cache configure prostagma:fleet --retention-period '7 days'
attic cache configure prostagma:fleet --reset-retention-period
```

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

## 6. Wipe and rebuild

Use this if the cache is ever corrupted. It deletes everything and gives the
cache a new signing key. On prostagma:

```sh
sudo systemctl stop atticd.service
sudo -u postgres dropdb atticd
sudo -u postgres createdb -O atticd atticd
sudo find /srv/apps/attic -mindepth 1 -delete
sudo systemctl start atticd.service
```

Then repeat step 2: create the cache, put its new public key in
`nix/modules/binary-cache.nix`, and deploy every Linux host. Until they are
deployed, hosts reject the new cache's signatures and fall back to other caches
or to building. The CI token keeps working, because tokens depend only on the
signing secret, not on the database.

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
