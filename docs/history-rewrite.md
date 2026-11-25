# History rewrite: KDE application state

From 2026-09-29 (commit `0bd4bb9`, "kde: add Plasma desktop settings files")
the public history held KDE application state: Okular's and Gwenview's
recently opened files, naming private documents on the NAS and in `~/Downloads`,
Spectacle's last screenshot path, Ark's last extraction folder, and device
identifiers (monitor EDIDs, the Bluetooth adapter's address, disk IDs, the
NAS's tailnet address and a LAN host). It got there because `kde/` was linked
into `~/.config` and KDE wrote through the links ([KDE](kde.md)). Every branch
and the refs of pull requests #2 to #33 reach it.

The branch `kde-minimal-config` stops the leak. This runbook removes the data
from every branch on GitHub. The ordered steps are stage 0 of
[Rollout](rollout.md#0-purge-kde-state-from-the-public-history).

## What the rewrite changes

[`git filter-repo`](https://github.com/newren/git-filter-repo) runs with
`--sensitive-data-removal` and the callback below, which:

- deletes from every commit the 27 `kde/` files that held only state or
  device identifiers (`kde-minimal-config` also stops tracking the Plasma
  session's settings, whose history holds nothing private and stays);
- removes the `[Recent Files]` group from every version of `kde/okularrc` and
  `kde/gwenviewrc`, `DirHistory` from `kde/arkrc`, and the device entries
  (`<separator>` blocks) from `kde/local-share/user-places.xbel`.

Nothing outside `kde/` changes. Tested on a mirror of GitHub on 2026-11-25,
with `kde-minimal-config` on `main` (`c25cee2`) and two unpushed branches
stacked on it:

- 571 of 1,453 commits rewritten (the counts grow as branches move); no
  commit dropped, so every branch keeps its commit count; first changed
  commit `0bd4bb9ec54dda84ebc60b50a870a53f0c86d23d`; 32 pull request heads
  changed.
- Every branch's tip differs from the original only in `kde/`, and
  `kde-minimal-config`'s tip tree is identical to the original.
- Pull requests #31 and #12 keep the same diff against `main`. The KDE
  branch's diff against `main` deletes 16 lines that hold the data before the
  rewrite and none after it, so its pull request is safe to open then.
- The stacked branches keep their tip trees and stay stacked on the rewritten
  `kde-minimal-config`; the bundle from step 6 restores them in a fresh clone.
- prostagma's and eltoro's system closures from the rewritten `release` are
  the same store paths as from the original, so their nightly upgrade has
  nothing to build or switch.
- `git log --all -S` finds none of the document names, NAS paths, the
  screenshot name, `DirHistory`, `edidIdentifier`, the Bluetooth address or the
  LAN host. `[Recent Files]` remains only in the test fixtures of
  `nix/hosts/scylla/test-apply-kde-config.py`, and the tailnet address only in
  the TrueNAS mount that `nix/hosts/scylla/default.nix` used before PR #7.
- Older versions of `kde/kwinrc` keep their `[Tiling]` groups, keyed by
  output and desktop UUIDs that KWin generated; they identify nothing outside
  that profile.

## The callback

Save it as `kde-history.py` next to the mirror (step 4 below):

```python
import re

dropped = {
    b"kde/KDE/UserFeedback.conf", b"kde/baloofilerc", b"kde/bluedevilglobalrc",
    b"kde/drkonqirc", b"kde/kactivitymanagerd-statsrc", b"kde/kconf_updaterc",
    b"kde/kded6rc", b"kde/kdedefaults/kcminputrc", b"kde/kdedefaults/kdeglobals",
    b"kde/kdedefaults/ksplashrc", b"kde/kdedefaults/kwinrc", b"kde/kdedefaults/package",
    b"kde/kdedefaults/plasmarc", b"kde/khelpcenterrc", b"kde/kio_fishrc", b"kde/kiorc",
    b"kde/ksmserverrc", b"kde/ktimezonedrc", b"kde/kwinoutputconfig.json",
    b"kde/kwinrulesrc", b"kde/plasmanotifyrc", b"kde/plasmaparc", b"kde/plasmarc",
    b"kde/powermanagementprofilesrc", b"kde/spectaclerc", b"kde/systemmonitorrc",
    b"kde/trashrc",
}
if filename in dropped:
    return (None, mode, blob_id)
if filename in (b"kde/okularrc", b"kde/gwenviewrc", b"kde/arkrc", b"kde/local-share/user-places.xbel"):
    data = value.get_contents_by_identifier(blob_id)
    if filename.endswith(b".xbel"):
        clean = re.sub(rb" *<separator>\n.*?</separator>\n", b"", data, flags=re.S)
    else:
        clean = re.sub(rb"(?m)^\[Recent Files\]\n(?:[^\[\n][^\n]*(?:\n|\Z)|\n)*", b"", data)
        clean = re.sub(rb"(?m)^DirHistory[^=\n]*=[^\n]*(?:\n|\Z)", b"", clean)
    if clean != data:
        blob_id = value.insert_file_with_contents(clean)
return (filename, mode, blob_id)
```

## Steps

Run these on scylla, in bash, in a new empty directory such as
`~/history-rewrite`, never in `~/.config/dotfiles` or a worktree.

1. **Turn scylla's KDE links into local files** before anything changes the
   checkout. Until `./install` runs with `kde-minimal-config`, `~/.config` links
   into `~/.config/dotfiles/kde/`, so a pull or reset would empty or delete
   what scylla's KDE reads, and KDE would write through the dangling links
   into the checkout again:

   ```bash
   kde="$HOME/.config/dotfiles/kde/"
   find "$HOME/.config" "$HOME/.local/share" -maxdepth 2 -type l -print0 |
     while IFS= read -r -d '' link; do
       target=$(readlink -f -- "$link") || continue
       case $target in
         "${kde}local-share/color-schemes/"*) ;;
         "$kde"*) [ -f "$target" ] && cp --remove-destination -- "$target" "$link" && echo "copied $link" ;;
       esac
     done
   ```

   It copies each linked file's current content over its link, so scylla
   keeps its display layout, migration markers and the rest of its state, now
   outside Git.

   From here on, run `./install` on scylla only from a branch that contains
   `kde-minimal-config`. Every other branch, including `main`, which
   `~/.config/dotfiles` has checked out, still links `kde/` into `~/.config`:
   Home Manager would rename the copies to `*.hm-backup`, link the files again, and KDE would write recent files into the checkout
   for the next `git add -A` to commit. Rebase such a branch onto the new
   `main` first.

2. **Freeze pushes.** Disable both workflows, then wait for or cancel any run
   still going, and push nothing from any machine or agent until step 7.
   Without this, the force push of about 35 branches starts as many Fleet
   runs. Record the open pull requests' commit counts to compare later:

   ```bash
   gh workflow disable Nightly
   gh workflow disable Fleet
   gh run list --status in_progress
   for n in $(gh pr list --state open --json number --jq '.[].number'); do
     echo "$n $(gh pr view "$n" --json commits --jq '.commits | length')"
   done | tee pr-commits-before.txt
   ```

3. **Lift the `release: no rewrite` ruleset**, which blocks the force push
   ([CI](ci.md#what-you-set-up-once) step 3):

   ```bash
   id=$(gh api repos/carterworks/dotfiles/rulesets --jq '.[] | select(.name == "release: no rewrite") | .id')
   gh api -X PUT "repos/carterworks/dotfiles/rulesets/$id" -f enforcement=disabled
   gh api "repos/carterworks/dotfiles/rulesets/$id" --jq '.enforcement, [.rules[].type]'
   ```

   The last command must print `disabled` and the two rules
   (`deletion`, `non_fast_forward`).

   Or set its **Enforcement** to **Disabled** under **Settings → Rules →
   Rulesets**. Check there and under **Settings → Branches** for any other
   rule that blocks force pushes.

4. **Rewrite a fresh mirror.** First stop every agent session that works on
   `kde-minimal-config` or a branch stacked on it, so nothing moves them
   during the rewrite. Then, in `~/.config/dotfiles`, make sure every
   unpushed branch you want to keep sits on the current history:
   `kde-minimal-config` on `origin/main`, and each branch stacked on it on
   `kde-minimal-config`'s current tip. On 2026-11-25 the stack was
   `immich-backup` with `qbittorrent-mount-binding` on top, both checked out in
   worktrees and both made from an older tip, `63e1f11`, before
   `kde-minimal-config` moved onto `main`. List any branch stacked since in
   `stacked` below.

   One rebase of the top branch moves both, run in its own worktree, with the
   other branch's worktree detached: `--update-refs` skips a branch checked
   out in another worktree. Each worktree must have no uncommitted changes.
   First check that only the stack's own three commits sit above `63e1f11`:

   ```bash
   cd ~/.config/dotfiles
   wt() { git worktree list --porcelain | awk -v b="branch refs/heads/$1" '/^worktree /{w=substr($0, 10)} $0 == b {print w}'; }
   immich=$(wt immich-backup) qbit=$(wt qbittorrent-mount-binding)
   git log --oneline 63e1f11..qbittorrent-mount-binding
   git -C "$immich" switch --detach
   git -C "$qbit" rebase --update-refs --onto kde-minimal-config 63e1f11 qbittorrent-mount-binding
   git -C "$immich" switch immich-backup
   git merge-base --is-ancestor kde-minimal-config immich-backup && echo "stack rebased"
   ```

   Rebase once. If you repeat this step, skip the rebase while that last
   check still prints `stack rebased`; `63e1f11` is the wrong base from then
   on. If `kde-minimal-config` gains a commit afterwards, rebase the stack
   from its previous tip instead (`git reflog kde-minimal-config` lists it):
   `git -C "$qbit" rebase --update-refs --onto kde-minimal-config <previous-tip> qbittorrent-mount-binding`.
   `git merge-base` does not find that tip once `kde-minimal-config` has been
   rebased: it finds the older commit both started from, and the rebase would
   replay the KDE commits too and conflict.

   Then bring them into the mirror, which makes it no longer fresh, hence
   `--force`. The rewrite carries every branch in the mirror over to the new
   history, so the stack stays a stack:

   ```bash
   git clone --mirror git@github.com:carterworks/Dotfiles.git dotfiles.git
   cd dotfiles.git
   stacked="immich-backup qbittorrent-mount-binding"
   for b in kde-minimal-config $stacked; do
     git fetch ~/.config/dotfiles "$b:refs/heads/$b"
   done
   git merge-base --is-ancestor main kde-minimal-config || echo "rebase kde-minimal-config onto main first"
   for b in $stacked; do
     git merge-base --is-ancestor kde-minimal-config "$b" || echo "rebase $b onto kde-minimal-config first"
     git ls-remote --exit-code --heads origin "$b" >/dev/null && echo "$b is on GitHub: take it out of stacked"
   done
   nix shell nixpkgs#git-filter-repo --command \
     git filter-repo --sensitive-data-removal --force --file-info-callback ../kde-history.py \
     | tee ../filter-repo.log
   ```

   If any check prints, fix that branch in the checkout and start this step
   again. A stacked branch already on GitHub must not be in `stacked`: the
   rewrite carries it and step 7 force-pushes it like any other branch,
   whereas step 6 would delete it from the mirror and step 7 then from
   GitHub.

5. **Verify.** Each search must print nothing. Use the names of the private
   documents, the NAS folder they sit in, and the screenshot's name, which you
   know, in place of the placeholders:

   ```bash
   for s in '<a document name>' '<the NAS folder>' '<the screenshot name>'; do
     git log --all --oneline -S"$s"
   done
   for s in '[Recent Files]' DirHistory edidIdentifier '<separator>'; do
     git log --all --oneline -S"$s" -- kde
   done
   git log --all --oneline -- kde/kwinoutputconfig.json kde/spectaclerc kde/bluedevilglobalrc
   ```

6. **Leave the fix as its own branch, and set the stacked branches aside.**
   Step 7 pushes `kde-minimal-config` with every other branch, and step 9
   opens its pull request against `main`. Its pull request must not exist
   before the rewrite: its diff would show the deleted lines that hold the
   data. Until it is merged, do not run `./install` on scylla from `main`.

   The branches stacked on it stay unpushed: save them, rewritten, in a
   bundle and take them out of the mirror, since step 7 pushes every branch
   the mirror holds. [Other copies](#other-copies) brings them back:

   ```bash
   git bundle create ../stacked.bundle $stacked
   git branch -D $stacked
   ```

7. **Force-push every branch.** `--mirror` also deletes any branch on GitHub
   that the mirror lacks; nothing should, since the mirror was cloned in step
   4. GitHub refuses the `refs/pull/*` updates, which is expected:

   ```bash
   git push --force --mirror origin
   git ls-remote --heads origin | tr '\t' ' ' | sort -k2 > ../remote.txt
   git for-each-ref --format='%(objectname) %(refname)' refs/heads | sort -k2 | diff - ../remote.txt && echo "every branch pushed"
   ```

   The repository has no tags.

8. **Restore the ruleset and the workflows**, then run Fleet on `main`, which
   pushes to the cache and fast-forwards `release` as usual:

   ```bash
   id=$(gh api repos/carterworks/dotfiles/rulesets --jq '.[] | select(.name == "release: no rewrite") | .id')
   gh api -X PUT "repos/carterworks/dotfiles/rulesets/$id" -f enforcement=active
   gh api "repos/carterworks/dotfiles/rulesets/$id" --jq '.enforcement, [.rules[].type]'
   gh workflow enable Fleet
   gh workflow enable Nightly
   gh workflow run Fleet --ref main
   ```

   The ruleset must print `active` and both rules again; if a rule is
   missing, re-create it with the command in [CI](ci.md#what-you-set-up-once)
   step 3.

9. **Check the open pull requests, then open the fix's.** Each open pull
   request should show the same number of commits as in
   `pr-commits-before.txt`, and the same diff; review comments on lines of old
   commits may show as outdated. Then open the KDE pull request on the same
   base as in step 4, and check that its diff holds none of the data:

   ```bash
   gh pr create --base main --head kde-minimal-config --fill-first
   gh pr diff kde-minimal-config | grep -c -E '^-.*(Recent Files\]|DirHistory|edidIdentifier|File[0-9]+\[)'
   ```

   The count of deleted lines holding any of these must be `0`.

10. **Ask GitHub Support to purge the cached data** at
    <https://support.github.com>, choosing the sensitive-data removal request.
    Send the repository (`carterworks/dotfiles`), the number of affected pull
    requests (`grep -c '^refs/pull/.*/head$' filter-repo/changed-refs` in the
    mirror; 32 in the test) and the first changed commit from
    `filter-repo.log` (`0bd4bb9ec54dda84ebc60b50a870a53f0c86d23d` in the test).
    Say that the data is personal: names of private financial and legal
    documents, not a credential that rotating would fix. Ask them to remove
    cached views, **dereference** (not delete) the affected pull requests so
    their conversations survive, and garbage-collect the orphaned commits.
    Until they do, the old commits stay reachable on GitHub by hash and
    through closed pull requests' diffs.

11. **Reset every other copy** ([below](#other-copies)).

## Other copies

Every clone made before the rewrite holds the data, and a plain `git pull`
followed by a push would publish the old history again. GitHub's advice is to
discard and re-clone.

- **scylla, `~/.config/dotfiles`.** Home Manager links into this path, so
  re-clone in place. First save what Git does not track there: uncommitted
  changes, `infra/truenas/terraform.tfstate*` and `infra/truenas/.terraform/`
  (ignored but needed by OpenTofu), and any branch you still need, which you
  must rebase onto the new history rather than merge. Save each worktree's
  uncommitted work too (`git worktree list`, then `git -C <worktree> diff
  HEAD > <file>` and its untracked files), and stop any agent session working
  in one: moving the checkout breaks every worktree. Then
  move the directory aside, `git clone git@github.com:carterworks/Dotfiles.git
  ~/.config/dotfiles`, copy the saved files back, bring back the stacked
  branches with `git fetch --no-prune ~/history-rewrite/stacked.bundle
  immich-backup:immich-backup
  qbittorrent-mount-binding:qbittorrent-mount-binding` (name each branch:
  with `fetch.prune` set, as in your Git config, a `refs/heads/*` refspec
  deletes `main`), re-create the worktrees you need, and run `./install` from
  `kde-minimal-config`, or from `main` once the KDE pull request is merged. The
  first run warns `does not link into a Home Manager generation` for each KDE
  file that step 1 copied; that is expected. Delete the old directory when
  done. It also held the worktrees under `~/Projects/code/worktrees/dotfiles/`
  (remove them with the old checkout, and re-create the ones you need), many
  local branches that GitHub never had, and T3 Code's checkpoint refs
  (`refs/t3/`), all on the old history.
- **The Mac, `~/.config/dotfiles`.** The same: save untracked files, re-clone,
  `./install`.
- **prostagma and eltoro** deploy from `github:carterworks/dotfiles/release`
  and hold no clone. Their Nix stores hold copies of old `release` sources,
  which `nix-gc` removes once no generation refers to them; nothing there is
  public.
- **Forks and other clones.** GitHub listed no forks on 2026-11-25. Its traffic
  page counted 1,698 clones by 354 unique cloners in the 14 days before, most
  of them probably CI runners, but any of them may hold the old history, and
  neither GitHub nor this repository can reach them. Archives that copy public
  repositories (for example Software Heritage) may hold it too; each has its
  own takedown process.
