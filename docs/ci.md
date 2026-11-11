# CI

GitHub-hosted runners build every machine, so none of the weak machines ever
builds software. Two workflows do it:

| Workflow | Triggers | Jobs | Token permissions |
|---|---|---|---|
| [Fleet](../.github/workflows/fleet.yml) | push to any branch, a dispatch, a call from Nightly | `build` (scylla, prostagma, eltoro, mac, checks-linux, checks-mac); `release` | `build`: `contents: read`; `release`: `contents: write` |
| [Nightly](../.github/workflows/nightly.yml) | daily at 07:17 UTC, a dispatch | `update`, `build` (calls Fleet), `promote`, `report` | `update`: `contents: read`; `promote`: `contents: write`; `report`: `actions: read`, `contents: read` |

## Trust roots

- **Whatever can push to this repository can reach `main`**, and whatever
  reaches `release` runs as root on prostagma and eltoro within hours. Nothing
  reviews a push to `main`; Nightly pushes there itself.
- **The `binary-cache` Environment's branch rule is defence in depth, not the
  boundary.** It keeps the cache secrets from runs on other branches, but anyone
  who can push can push to `main`.
- **Audit who and what holds push access**: your SSH keys and personal access
  tokens, the repository's deploy keys, GitHub Apps and collaborators, and any
  automation or AI agent that can push. Each one can put code on the servers.
- Protecting `main` with a branch rule would also stop Nightly's own push, and
  GitHub does not take GitHub Actions as a bypass on a personal repository
  (see `release` below), so Nightly would need to push with another credential.
- **`release` is what the servers trust, completely.** Anything that can push
  to this repository can create or fast-forward it: your keys and tokens, and
  any workflow on any branch, which can grant itself `contents: write` and push
  `release` directly, past `main` and CI. Such a commit is on both servers at
  their next nightly upgrade, running as root. No rule limits who may do it:
  GitHub refused GitHub Actions as a ruleset bypass actor on this personal
  repository (2026-11-10), so a ruleset cannot reserve `release` for the
  `release` job. The ruleset in [item 3](#what-you-set-up-once) only forbids
  deleting or force-pushing `release`, so nothing can rewind or delete it, you
  included, until you lift it. The read-only default in
  [item 4](#what-you-set-up-once) does not help either, since a workflow may ask
  for `contents: write` itself. Push access is the boundary.
- **The generated skill files are an upstream path to the servers.**
  `./update --apply` regenerates `agents/skills/generated/` from upstream
  tools' own output. The coding agents on Scylla read those files as
  instructions, and Scylla holds your SSH agent and the admin age key, so a
  compromised upstream could write instructions that reach both servers
  through an agent. Nothing checks their content; each nightly commit's diff
  shows any change to them, and reading that diff is the control.

## From a push to a server

1. A push to any branch builds the three NixOS hosts, the Mac and the flake
   checks (VM tests included). On a branch other than `main` that is all.
2. On `main`, each NixOS host's job then joins the tailnet as an ephemeral
   `tag:ci` node and pushes its system's closure to the private cache
   ([binary-cache.md](binary-cache.md)) with the flake's own Attic client.
3. When every job passed and all three pushes succeeded, the `release` job
   fast-forwards the `release` branch to that commit, creating it the first
   time. When every job passed but a host did not push, the `release` job
   fails with "Not every host pushed", so the run is red rather than green
   with `release` silently left behind.
4. The servers upgrade from `github:carterworks/dotfiles/release` every night
   ([auto-upgrade.md](auto-upgrade.md)), so every path they need is already in
   the cache or upstream.

`release` only moves forward. A run for an older commit that finishes after a
newer one leaves it alone.

A cache push ends one of four ways:

| Result | Host job | `release` job | `release` |
|---|---|---|---|
| pushed | green | green | advances when all three hosts pushed |
| skipped: a `binary-cache` Environment secret is unset | green, with a warning naming the unset secrets | red | stays |
| unreachable: the tailnet join or the cache did not answer | green, with a warning | red | stays |
| failed: the push started and errored (an expired token, a full disk) | red | skipped | stays |

A skipped or unreachable push does not make a build wrong, so the host job
stays green, but nothing it built is in the cache, so `release` waits for the
next run on `main` in which all three push, and the `release` job is red until
then.

### When `release` does not move

GitHub refuses the workflow token some pushes that touch
`.github/workflows/`. A trial (2026-11-10) showed it accepts fast-forwarding a
branch across existing commits that change workflow files, and creating one on
such a history, so this should not happen; if it does, the `release` job or
Nightly's promote job fails with "release did not move" and the push output
says why. Move it yourself after checking that the commit's Fleet run pushed
all three hosts. Your own fast-forward is not refused:

```sh
git push git@github.com:carterworks/dotfiles.git <commit>:refs/heads/release
```

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
   if anything needs you. On a night with nothing else to report, that
   includes a `release` that does not exist or is behind `main`, so a
   `release` left behind by a Fleet run, or never created, does not hide
   behind "Nothing to update."

When `./update` exits 3, some items failed: they are left out, the rest are
built and merged as usual, and the run still ends red with the failed items
named, so GitHub's failure email tells you. Any other failure means the updater
itself broke; nothing is built or merged.

A push made with the workflow's own token starts no other workflow, so moving
`main` does not run Fleet again: Nightly has already built, pushed and
released that commit itself. No personal access token is involved.

The servers upgrade at 04:30 Denver time ([auto-upgrade.md](auto-upgrade.md)),
over three hours after Nightly is due in either season, enough for a late
start of up to two hours and a nixpkgs update that takes another hour to build.
GitHub can start it much later: the first scheduled run (2026-11-11) started at
15:15 UTC, eight hours after its 07:17 slot and after both servers' upgrade
time. A run that late is not lost, only a day behind: the servers take its
commit at their next nightly upgrade.

### When Nightly does not start

Nothing reports a schedule that never fires: no run means no red run and no
email. Check that the latest scheduled run is from the last day, and the
workflow's state:

```sh
gh run list --repo carterworks/dotfiles --workflow nightly.yml --event schedule -L 3
gh api repos/carterworks/dotfiles/actions/workflows/nightly.yml --jq .state
```

- **`disabled_inactivity`**: GitHub turns off a public repository's schedules
  after 60 days without activity. Turn it back on with
  `gh workflow enable nightly.yml --repo carterworks/dotfiles`.
- **`disabled_manually`**: someone paused it ([By hand](#by-hand)); turn it on
  the same way.
- **`active`, but no scheduled run for over a day**: GitHub documents that it
  delays scheduled runs under load and may drop them, and nothing in the
  repository can make it start one. Allow for a late start before acting: the
  first scheduled run (2026-11-11) started eight hours after its slot. GitHub
  reads a workflow's schedule again when a push to the default branch changes
  the file; disabling and enabling the workflow is reported to do the same
  (unverified here). Do either, then run Nightly by hand ([By hand](#by-hand)) so that
  night's update is not lost.

### What the gate catches

`release` moves only when every host evaluates and builds and every check
passes, including the VM tests such as eltoro's egress fence. It does not
catch:

- an upstream that is backdoored but still builds and passes;
- behaviour no check exercises;
- a data migration within a major version (a database schema an app upgrades
  on start);
- **container images at all.** CI never pulls or runs them: an image update is
  only a new string in the configuration. Images tagged `latest` get a new
  digest nearly every night.

### When `main` moves during a nightly

Nightly moves `main` only by fast-forward from the commit it updated. If you
pushed to `main` while it was building, that push fails, Nightly changes
nothing and ends red with "main moved". Your commit gets its own Fleet run, and
the next nightly updates on top of it; run Nightly by hand to do that now.

It does not rebase and rebuild: that would mean resolving `flake.lock`
conflicts unattended and another hour of building while holding write access,
to save at most a day.

## What you set up once

1. **Before merging these workflows**, create the `binary-cache` Environment
   limited to `main`: step 0 of [binary-cache.md](binary-cache.md). Until it
   exists, the first Fleet run on `main` would create it empty and without a
   branch rule.
2. Under **Settings → Actions → General → Approval for running fork pull
   request workflows from contributors**, choose **Require approval for all
   external contributors**. With `gh`:

   ```sh
   gh api -X PUT repos/carterworks/dotfiles/actions/permissions/fork-pr-contributor-approval \
     -f approval_policy=all_external_contributors
   gh api repos/carterworks/dotfiles/actions/permissions/fork-pr-contributor-approval
   ```
3. **Stop `release` being rewound or deleted** with a branch ruleset, under
   **Settings → Rules → Rulesets → New ruleset → New branch ruleset**, named
   `release: no rewrite`, targeting the branch name `release`, enforcement
   **Active**, with **Restrict deletions** and **Block force pushes** and no
   bypass. It does not stop anyone creating or fast-forwarding `release`: a
   ruleset that did would need GitHub Actions as its bypass, which GitHub
   refuses on a personal repository (HTTP 422, 2026-11-10). With `gh`:

   ```sh
   gh api -X POST repos/carterworks/dotfiles/rulesets --input - <<'EOF'
   {"name": "release: no rewrite", "target": "branch", "enforcement": "active",
    "conditions": {"ref_name": {"include": ["refs/heads/release"], "exclude": []}},
    "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}]}
   EOF
   gh api repos/carterworks/dotfiles/rulesets --jq '.[] | "\(.id) \(.name) \(.enforcement)"'
   ```

   On a stand-in branch (2026-11-10) the `release` job's token created and
   fast-forwarded it, and both it and an admin's SSH push were refused a
   rewind and a delete. Rewinding `release` needs the ruleset lifted:
   [Moving `release` back](#moving-release-back).
4. **Make the workflow token read-only by default**: **Settings → Actions →
   General → Workflow permissions → Read repository contents and packages
   permissions**, and clear **Allow GitHub Actions to create and approve pull
   requests**. Every job here that writes asks for `contents: write` itself,
   so nothing else changes. With `gh` (the read-back lags the call by a few
   seconds):

   ```sh
   gh api -X PUT repos/carterworks/dotfiles/actions/permissions/workflow \
     -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
   gh api repos/carterworks/dotfiles/actions/permissions/workflow
   ```
5. Follow [binary-cache.md](binary-cache.md) steps 1 to 4: deploy the cache,
   create it, mint the push token, write the tailnet policy and create the
   OAuth client. Nothing in the workflows changes afterwards; the next run on
   `main` pushes.

Until then, every run on `main` warns "Cache push skipped" with the unset
secrets' names, its `release` job fails with "Not every host pushed", and
`release` does not exist yet.

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

Pausing stops updates, not `release`: every green Fleet run for your own
pushes to `main` still advances it.

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
- **./update --apply failed**: the updater broke; nothing was built or merged.
  Its log is in the update job.
- **main did not move**: see "When `main` moves during a nightly".
- **main moved but release could not be moved**: see "When `release` does not
  move".
- **The binary cache was unreachable**: `main` moved, `release` did not. Check
  atticd on prostagma ([binary-cache.md](binary-cache.md), "Size cap" and
  "Behaviour when the cache is down"), then run Fleet on `main` by hand
  (`gh workflow run fleet.yml --repo carterworks/dotfiles --ref main`) to push
  and release.
- **A binary-cache Environment secret is unset**: `main` moved, `release` did
  not, and the build jobs' "Cache push skipped" warning names the unset
  secrets. Set them ([binary-cache.md](binary-cache.md) steps 3 and 4), then
  run Fleet on `main` by hand as above.
- **release is behind main** or **could not compare release with main**:
  nothing else went wrong tonight, but `release` is older than `main` or does
  not exist. Open the latest Fleet run on `main`; a push to `main` still
  building when the report ran also shows this, and clears with that run.
- **A host's push failed**: usually an expired `ATTIC_TOKEN`; rotate it
  ([binary-cache.md](binary-cache.md) step 3) and re-run the failed jobs.
- **Not every host pushed** (Fleet's `release` job): every build passed but
  `release` did not move. The host jobs' "Cache push skipped" warning names
  each unset `binary-cache` Environment secret; set it
  ([binary-cache.md](binary-cache.md) steps 3 and 4). A "Cache unreachable"
  warning is the unreachable cache above. Then run Fleet on `main` by hand.

## Moving `release` back

The fastest brake is on the servers: `sudo systemctl stop nixos-upgrade.timer`
on prostagma and eltoro stops tonight's upgrade whatever `release` says.

To move `release` itself back, in this order, because disabling a workflow
does not cancel a run already going, and any Fleet run or re-run on `main`
fast-forwards `release` straight back to `main`:

```sh
gh workflow disable nightly.yml --repo carterworks/dotfiles
gh run list --repo carterworks/dotfiles --status in_progress --json databaseId --jq '.[].databaseId' \
  | xargs -r -n1 gh run cancel --repo carterworks/dotfiles
gh run list --repo carterworks/dotfiles --status queued --json databaseId --jq '.[].databaseId' \
  | xargs -r -n1 gh run cancel --repo carterworks/dotfiles
gh api -X PUT repos/carterworks/dotfiles/rulesets/<no-rewrite-id> -f enforcement=disabled
git push --force git@github.com:carterworks/dotfiles.git <good-commit>:refs/heads/release
gh api -X PUT repos/carterworks/dotfiles/rulesets/<no-rewrite-id> -f enforcement=active
```

The force push needs the ruleset lifted, because it refuses any rewind. Turn
it back on straight after; with Nightly disabled and its runs cancelled,
nothing else should push meanwhile. The same switch is
under **Settings → Rules → Rulesets**, as **Enforcement status**. (Unverified:
that a `PUT` with only `enforcement` leaves the rest of a ruleset as it was.)

Then revert the bad change on `main`. The revert's green run fast-forwards
`release` past it, since `<good-commit>` is its ancestor; then enable Nightly
again.

- Switching a server back can break a service whose data the newer version
  already migrated; check before forcing an old commit on prostagma.
- The cache keeps a path 14 days after it was last fetched, so a server going
  back further than that may build.
- Do not force-push `main` while a run is going: a run that started before it
  can still move `release` to a commit that is no longer in `main`.

## Safety

The repository is public, so the design assumes anyone can read every
workflow and open pull requests. The trust roots above come first.

- **Which runs reach the cache secrets.** Only the scylla, prostagma and eltoro
  build jobs, and only in a run for `main`: a push to `main`, a dispatch of
  Fleet on `main`, or Nightly, which always runs on `main`. Those jobs alone
  name the `binary-cache` Environment, and GitHub hands its secrets only to
  jobs running for `main`, so a workflow edited on any other branch that names
  it is refused. The Mac, the checks, `release`, `promote`, `update` and
  `report` never see them.
- **Who holds the push token.** Inside a host job, only the Tailscale step and
  the push step receive secret values; the step before them sees only whether
  they are set. The push step writes the token to Attic's config file with a
  shell builtin, so it is in no process's arguments. The Tailscale action
  passes the OAuth secret to `tailscale up` on its command line; that is the
  action's code, outside this repository. In a nightly, the Attic client is
  built from the update's new lock, so freshly updated upstream code that no
  check has gated handles the token, while the checks and the Mac job may still
  be running. Each host also pushes before the gate, so a nightly that later
  fails leaves signed but unreferenced paths in the cache until they expire.
- **Which runs cannot.** Pushes to other branches, dispatches on other
  branches, and every pull request.
- **No `pull_request_target` and no `workflow_run`.** This repository's
  workflows have no pull-request trigger.
- **A pull request from a fork** can add its own workflow with
  `on: pull_request`, and GitHub runs it, after your approval for a first-time
  contributor (for every outside contributor once set-up item 2 is done). Such
  a run gets a read-only token and no secrets, cannot name the Environment,
  cannot reach the cache or the tailnet, and cannot write to `main`'s Actions
  cache (what it saves is scoped to the pull request). Its code
  reaches `main` only if you merge it, and then it runs like any other commit
  on `main`. Review the workflows, `.github/ci.nix`, `.github/advance-release`
  and `./update` in particular, since a merged change to them runs with the
  cache token and with write access.
- **A compromised action.** Every action is pinned by full commit SHA, so a
  moved tag or a new release changes nothing until the pin is edited. The
  pinned code itself runs with the job's token and, in the three NixOS jobs on
  `main`, alongside the push token and tailnet credentials, which any step of
  that job could read from the runner. The worst it could do: steal the push
  token (root on every Linux host at their next upgrade, see
  [binary-cache.md](binary-cache.md) step 3); join the tailnet as `tag:ci`,
  which reaches only `prostagma:8199`; and read the repository. The Tailscale
  action's binary cache is off, so a job without secrets cannot plant the
  `tailscale` binaries a job with secrets installs as root. Only the `release`
  and `promote` jobs can write to the repository, and they run
  `actions/checkout`, `actions/download-artifact` and Git.
- **The nightly runs only code from `main`.** A schedule always runs the
  default branch's file, and `update` refuses to run for any other ref, so a
  copy of Nightly on another branch does nothing. The job that writes
  (`promote`) runs only Git; the code `./update` brings in runs in `update`
  (read-only token) and in the build jobs (read-only token, Nix sandbox, no
  secrets until the build has finished).
- **What it trusts.** Merging updates unattended means a compromised upstream
  (nixpkgs, a flake input, a pinned release or image) reaches the servers
  without a human reading it, exactly as if you ran `./update --apply` and
  deployed. Pausing Nightly stops that, but not your own pushes.

### Accepted limits

- The Mac jobs gate the servers' updates: a Mac-only breakage holds `release`.
- If one host's push fails, `release` waits for the next nightly with changes,
  your next push, or a Fleet run started by hand.
- Re-running an old Fleet run weeks later can reuse its earlier "pushed"
  results after the cache has expired those paths, and move `release` to a
  commit a server would partly build.
