# CI

GitHub-hosted runners build every machine, so none of the weak machines ever
builds software. Two workflows do it:

| Workflow | Triggers | Jobs | Token permissions |
|---|---|---|---|
| [Fleet](../.github/workflows/fleet.yml) | push to any branch, a dispatch, a call from Nightly | `build` (scylla, prostagma, eltoro, mac, checks-linux, checks-mac); `release` | `build`: `contents: read`; `release`: `contents: write` |
| [Nightly](../.github/workflows/nightly.yml) | daily at 07:17 UTC, a dispatch | `update`, `build` (calls Fleet), `promote`, `report` | `update`: `contents: read`; `promote`: `contents: write`; `report`: `actions: read` |

## From a push to a server

1. A push to any branch builds the three NixOS hosts, the Mac and the flake
   checks (VM tests included). On a branch other than `main` that is all.
2. On `main`, each NixOS host's job then joins the tailnet as an ephemeral
   `tag:ci` node and pushes its system's closure to the private cache
   ([binary-cache.md](binary-cache.md)) with the flake's own Attic client.
3. When every job passed and all three pushes succeeded, the `release` job
   fast-forwards the `release` branch to that commit, creating it the first
   time.
4. The servers upgrade from `github:carterworks/dotfiles/release` every night
   ([auto-upgrade.md](auto-upgrade.md)), so every path they need is already in
   the cache or upstream.

`release` only moves forward. A run for an older commit that finishes after a
newer one leaves it alone.

A cache push ends one of four ways:

| Result | Job | `release` |
|---|---|---|
| pushed | green | advances when all three hosts pushed |
| skipped: the `binary-cache` Environment has no secrets | green, with a notice | stays |
| unreachable: the tailnet join or the cache did not answer | green, with a warning | stays |
| failed: the push started and errored (an expired token, a full disk) | red | stays |

An unreachable cache does not make a build wrong, so the job stays green, but
nothing it built is in the cache, so `release` waits for the next green run
on `main`.

## The nightly loop

At 07:17 UTC, 00:17 in Denver in winter and 01:17 in summer, Nightly:

1. checks out `main` and runs `./update --apply`;
2. if nothing changed, ends green;
3. otherwise commits the change as `nix: update` with the script's summary as
   the body, by `github-actions[bot]`, and hands it to the next jobs as a Git
   bundle (no branch is pushed);
4. builds exactly that commit with Fleet, Mac and checks included, pushing the
   NixOS hosts' builds to the cache;
5. if everything is green, fast-forwards `main` to the commit and then
   advances `release` as above;
6. writes a summary of what it attempted and what happened, and fails the run
   if anything needs you.

When `./update` exits 1, the items that failed are left out, the rest are
built and merged as usual, and the run still ends red with the failed items
named, so GitHub's failure email tells you.

A push made with the workflow's own token starts no other workflow, so moving
`main` does not run Fleet again: Nightly has already built, pushed and
released that commit itself. No personal access token is involved.

The servers upgrade at 04:30 Denver time ([auto-upgrade.md](auto-upgrade.md)),
over three hours after Nightly is due in either season. That covers GitHub
starting it late, which can be most of an hour, and a nixpkgs update that takes
another hour to build.

GitHub turns off a public repository's schedules after 60 days without
activity. Nightly's own commits normally prevent that; if the Actions tab says
Nightly is disabled, turn it back on there.

### When `main` moves during a nightly

Nightly moves `main` only by fast-forward from the commit it updated. If you
pushed to `main` while it was building, that push fails, Nightly changes
nothing and ends red with "main moved". Your commit gets its own Fleet run, and
the next nightly updates on top of it; run Nightly by hand to do that now.

It does not rebase and rebuild: that would mean resolving `flake.lock`
conflicts unattended and another hour of building while holding write access,
to save at most a day.

## What you set up once

Follow [binary-cache.md](binary-cache.md) steps 1 to 4: deploy the cache, create
it, mint the push token, create the `binary-cache` Environment limited to
`main`, write the tailnet policy and create the OAuth client. Nothing in the
workflows changes afterwards; the next run on `main` pushes.

Until then, every run on `main` reports "Cache push skipped" and `release` does
not exist yet.

The first run on `main` after these workflows merge creates an empty
`binary-cache` Environment with no rules, because a job names it. Set its
branch rule to `main` before adding any secret to it.

## By hand

Run Nightly now (it always works on `main`):

```sh
gh workflow run nightly.yml --repo carterworks/dotfiles
gh run watch --repo carterworks/dotfiles "$(gh run list --repo carterworks/dotfiles --workflow nightly.yml -L 1 --json databaseId --jq '.[0].databaseId')"
```

Pause and resume it:

```sh
gh workflow disable nightly.yml --repo carterworks/dotfiles
gh workflow enable nightly.yml --repo carterworks/dotfiles
```

## When it goes red

Open the run; its summary lists the update and, for each failed job, which
kind of failure it was.

- **Failed before or outside the build**: a job failed in a step other than
  Build, such as "Install Nix" or a download, or in setting up the runner.
  That is the runner or its network, not the update, and nothing moved. Rerun
  the failed jobs; the rerun builds the same commit and, if green, merges it:

  ```sh
  gh run rerun <run-id> --failed --repo carterworks/dotfiles
  ```

  Or **Re-run failed jobs** on the run's page, within a week (the update
  commit is kept as an artifact for seven days; after that, run Nightly
  again). Fleet runs recover the same way.
  Installing Nix already tries twice; Nix retries each download itself.
- **The update does not build**: a host or check failed in its Build step, and
  nothing moved. The step's log shows what broke on the new inputs. A Build
  step can also fail on a download that Nix's own retries did not get past; if
  its log ends in a download or TLS error rather than a build error, rerun as
  above.
  Reproduce with `./update --apply` and a `nix build` of the failed host (see
  the README), fix on `main`, and run Nightly again.
- **These updates failed**: `./update` could not update the items named; the
  rest were merged. Run `./update` locally to see why, fix or hold the item.
- **main did not move**: see "When `main` moves during a nightly".
- **The binary cache was unreachable**: `main` moved, `release` did not. Check
  atticd on prostagma ([binary-cache.md](binary-cache.md), "Size cap" and
  "Behaviour when the cache is down"), then run Fleet on `main` by hand
  (`gh workflow run fleet.yml --repo carterworks/dotfiles --ref main`) to push
  and release.
- **A host's push failed**: usually an expired `ATTIC_TOKEN`; rotate it
  ([binary-cache.md](binary-cache.md) step 3) and re-run the failed jobs.

## Moving `release` back

Workflows only fast-forward `release`. In an emergency, move it back by hand to
a commit the servers ran before:

```sh
gh workflow disable nightly.yml --repo carterworks/dotfiles
git push --force git@github.com:carterworks/dotfiles.git <good-commit>:refs/heads/release
```

Then revert the bad change on `main`. The revert's green run fast-forwards
`release` past it, since `<good-commit>` is its ancestor; then enable Nightly
again. The cache keeps a path 14 days after it was last fetched, so a server
going back further than that may build.

## Safety

The repository is public, so the design assumes anyone can read every
workflow and open pull requests.

- **Which runs reach the cache secrets.** Only the scylla, prostagma and eltoro
  build jobs, and only in a run for `main`: a push to `main`, a dispatch of
  Fleet on `main`, or Nightly, which always runs on `main`. Those jobs alone
  name the `binary-cache` Environment, and GitHub hands its secrets only to
  jobs running for `main`, so a workflow edited on any other branch that names
  it is refused. The Mac, the checks, `release`, `promote`, `update` and
  `report` never see them. Inside a job, only the Tailscale step and the push
  step receive them, both after the build.
- **Which runs cannot.** Pushes to other branches, dispatches on other
  branches, and every pull request.
- **No `pull_request_target`, no `workflow_run`, no `pull_request`.** No
  workflow runs on pull requests at all.
- **A malicious pull request from a fork** runs nothing here, so it can neither
  read a secret nor write to the repository nor reach the tailnet. Its code
  reaches `main` only if you merge it, and then it runs like any other commit
  on `main`. Review the workflows, `.github/ci.nix` and `./update` in particular,
  since a merged change to them runs with the cache token and with write
  access.
- **A compromised action.** Every action is pinned by full commit SHA, so a
  moved tag or a new release changes nothing until the pin is edited. The
  pinned code itself runs with the job's token and, in the three NixOS jobs on
  `main`, alongside the push token and tailnet credentials, which any step of
  that job could read from the runner. The worst it could do: steal the push
  token (root on every Linux host at their next upgrade, see
  [binary-cache.md](binary-cache.md) step 3); join the tailnet as `tag:ci`,
  which reaches only `prostagma:8199`; and read the repository. Only the
  `release` and `promote` jobs can write to the repository, and they run
  `actions/checkout` and `actions/download-artifact` and nothing else.
- **The nightly runs only code from `main`.** A schedule always runs the
  default branch's file, and `update` refuses to run for any other ref, so a
  copy of Nightly on another branch does nothing. The job that writes
  (`promote`) runs only Git; the code `./update` brings in runs in `update`
  (read-only token) and in the build jobs (read-only token, Nix sandbox, no
  secrets until the build has finished).
- **What it trusts.** Merging updates unattended means a compromised upstream
  (nixpkgs, a flake input, a pinned release or image) reaches the servers
  without a human reading it, exactly as if you ran `./update --apply` and
  deployed. Pausing Nightly is the switch for that.
