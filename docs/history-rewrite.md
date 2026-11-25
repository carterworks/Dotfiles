# History rewrite: KDE application state

From 2026-09-29 (commit `0bd4bb9`, "kde: add Plasma desktop settings files")
the public history held KDE application state: Okular's and Gwenview's
recently opened files, naming private documents on the NAS and in `~/Downloads`,
Spectacle's last screenshot path, Ark's last extraction folder, and device
identifiers (monitor EDIDs, the Bluetooth adapter's address, disk IDs, the
NAS's tailnet address and a LAN host). It got there because `kde/` was linked
into `~/.config` and KDE wrote through the links ([KDE](kde.md)). Every branch
and the refs of pull requests #2 to #32 reach it.

The branch `kde-minimal-config` stops the leak. This runbook removes the data
from every branch on GitHub. The ordered steps are stage 0 of
[Rollout](rollout.md#0-purge-kde-state-from-the-public-history).

## What the rewrite changes

[`git filter-repo`](https://github.com/newren/git-filter-repo) runs with
`--sensitive-data-removal` and the callback below, which:

- deletes from every commit the 27 `kde/` files that `kde-minimal-config`
  stops tracking, which held only state;
- removes the `[Recent Files]` group from every version of `kde/okularrc` and
  `kde/gwenviewrc`, `DirHistory` from `kde/arkrc`, and the device entries
  (`<separator>` blocks) from `kde/local-share/user-places.xbel`.

Nothing outside `kde/` changes. Tested on a mirror of GitHub on 2026-11-25,
with `kde-minimal-config` on top of `main` (`5f9857f`):

- 557 of 1,439 commits rewritten; no commit dropped, so every branch keeps its
  commit count; first changed commit `0bd4bb9ec54dda84ebc60b50a870a53f0c86d23d`;
  31 pull request heads changed.
- Every branch's tip differs from the original only in `kde/`, and
  `kde-minimal-config`'s tip tree is identical to the original.
- Pull requests #30, #31 and #12 keep the same commits and the same diff
  against `main`.
- prostagma's and eltoro's system closures from the rewritten `release` are
  the same store paths as from the original, so their nightly upgrade has
  nothing to build or switch.
- `git log --all -S` finds none of the document names, NAS paths, the
  screenshot name, `DirHistory`, `edidIdentifier`, the Bluetooth address or the
  LAN host. `[Recent Files]` remains only in the test fixtures of
  `nix/hosts/scylla/test-apply-kde-config.py`, and the tailnet address only in
  the TrueNAS mount that `nix/hosts/scylla/default.nix` used before PR #7.

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

2. **Freeze pushes.** Disable Nightly (`gh workflow disable Nightly`) and push
   nothing from any machine or agent until step 7. Record the open pull
   requests' commit counts to compare later:

   ```bash
   for n in $(gh pr list --state open --json number --jq '.[].number'); do
     echo "$n $(gh pr view "$n" --json commits --jq '.commits | length')"
   done | tee pr-commits-before.txt
   ```

3. **Lift the `release: no rewrite` ruleset**, which blocks the force push
   ([CI](ci.md#what-you-set-up-once) step 3):

   ```bash
   id=$(gh api repos/carterworks/dotfiles/rulesets --jq '.[] | select(.name == "release: no rewrite") | .id')
   gh api -X PUT "repos/carterworks/dotfiles/rulesets/$id" -f enforcement=disabled
   ```

   Or set its **Enforcement** to **Disabled** under **Settings → Rules →
   Rulesets**. Check there and under **Settings → Branches** for any other
   rule that blocks force pushes.

4. **Rewrite a fresh mirror.** Bring in `kde-minimal-config` from the checkout,
   which makes the mirror no longer fresh, hence `--force`:

   ```bash
   git clone --mirror git@github.com:carterworks/Dotfiles.git dotfiles.git
   cd dotfiles.git
   git fetch ~/.config/dotfiles kde-minimal-config:refs/heads/kde-minimal-config
   git merge-base --is-ancestor main kde-minimal-config || echo "rebase kde-minimal-config onto main first"
   nix shell nixpkgs#git-filter-repo --command \
     git filter-repo --sensitive-data-removal --force --file-info-callback ../kde-history.py \
     | tee ../filter-repo.log
   ```

   If `main` moved since `kde-minimal-config` was made, rebase the branch onto
   `origin/main` in the checkout, then start this step again.

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

6. **Put the fix on `main`**, once you have reviewed `kde-minimal-config`:

   ```bash
   git update-ref refs/heads/main refs/heads/kde-minimal-config
   git branch -D kde-minimal-config
   ```

   To review it as a pull request instead, skip this step, push the branch in
   step 7, open the pull request afterwards (its diff no longer shows the
   data), and do not run `./install` on scylla until it is merged: `main` would
   link `kde/` into `~/.config` again.

7. **Force-push every branch.** `--mirror` also deletes any branch on GitHub
   that the mirror lacks; nothing should, since the mirror was cloned in step
   4. GitHub refuses the `refs/pull/*` updates, which is expected:

   ```bash
   git push --force --mirror origin
   git ls-remote --heads origin | sort -k2 > ../remote.txt
   git for-each-ref --format='%(objectname)	%(refname)' refs/heads | sort -k2 | diff - ../remote.txt && echo "every branch pushed"
   ```

   The repository has no tags.

8. **Restore the ruleset and Nightly:**

   ```bash
   gh api -X PUT "repos/carterworks/dotfiles/rulesets/$id" -f enforcement=active
   gh workflow enable Nightly
   ```

   Pushing `main` starts Fleet, which pushes to the cache and fast-forwards
   `release` as usual.

9. **Check the open pull requests.** Each should show the same number of
   commits as in `pr-commits-before.txt`, and the same diff. PR #30
   (`truenas-opentofu`) had 41 commits on 2026-11-25. Review comments on lines
   of old commits may show as outdated.

10. **Ask GitHub Support to purge the cached data** at
    <https://support.github.com>, choosing the sensitive-data removal request.
    Send the repository (`carterworks/dotfiles`), the number of affected pull
    requests (`grep -c '^refs/pull/.*/head$' filter-repo/changed-refs` in the
    mirror; 31 in the test) and the first changed commit from
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
  must rebase onto the new history rather than merge. Then
  move the directory aside, `git clone git@github.com:carterworks/Dotfiles.git
  ~/.config/dotfiles`, copy the saved files back, and run `./install`. The
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
