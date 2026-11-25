#!/usr/bin/env bash
# Moves a clone made before the 2026-11-25 history rewrite onto the rewritten
# history (docs/history-rewrite.md, "Other copies"). It reruns the same
# filter-repo callback on a copy of the clone; filter-repo is deterministic,
# so every commit GitHub also had comes out with GitHub's new hash, and local
# branches, worktrees and T3 Code's checkpoint refs keep their place. Only
# refs that still reach the old history are rewritten: filter-repo strips
# signatures, so rewriting a commit already on the new history, such as a
# merge GitHub signed, would give it a hash GitHub does not have. Only after
# checking the result, it updates the clone and prunes the old objects.
#
#   bash history-rewrite-move-clone.sh [path-to-clone]   (default ~/.config/dotfiles)
#
# Runs in bash 3.2 (macOS). Needs nix for git-filter-repo.
set -euo pipefail

repo=${1:-$HOME/.config/dotfiles}
first=0bd4bb9ec54dda84ebc60b50a870a53f0c86d23d
# What the rewrite on GitHub turned $first into.
first_new=8c071f876e3e89ab3810c73ffe383a560d56f835
say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

cd "$repo"
git rev-parse --git-dir >/dev/null 2>&1 || die "$repo is not a Git repository"
git remote get-url origin >/dev/null 2>&1 || die "this clone has no remote named origin; it should point at GitHub"
git worktree prune

git worktree list --porcelain | sed -n 's/^worktree //p' | while IFS= read -r wt; do
  [ -z "$(git -C "$wt" status --porcelain)" ] ||
    die "uncommitted changes in $wt; commit or stash them, then run this again"
done
# Stashes live in the reflog, which this script expires.
[ -z "$(git stash list)" ] || die "apply or drop your stashes first (git stash list)"

prune_old() {
  say "pruning the old objects"
  git reflog expire --expire=now --all
  git gc -q --prune=now
  if git rev-parse --verify -q "$first^{commit}" >/dev/null; then
    die "the old commit is still here; something still refers to it"
  fi
  if git log --all --oneline -1 -S'[Recent Files]' -- kde | grep -q .; then
    die "a recent-file list is still reachable"
  fi
  say "done: every branch is on the rewritten history and the old objects are gone"
}

old_refs=$(git for-each-ref --contains "$first" --format='%(refname)' 2>/dev/null || true)
old_heads=$(git worktree list --porcelain | sed -n 's/^HEAD //p' | while IFS= read -r sha; do
  if git merge-base --is-ancestor "$first" "$sha" 2>/dev/null; then printf '%s\n' "$sha"; fi
done)
if [ -z "$old_refs$old_heads" ]; then
  if git rev-parse --verify -q "$first^{commit}" >/dev/null; then
    # A run interrupted before pruning, or branches already reset by hand.
    say "only the reflog still holds the old history"
    prune_old
  else
    say "nothing here reaches the old history; done"
  fi
  exit 0
fi

others=$(printf '%s\n' "$old_refs" | grep -v -E '^refs/(heads|t3|remotes/origin)/' || true)
[ -z "$others" ] ||
  die "these refs reach the old history and this script does not move them; delete them, then run this again: $(printf '%s' "$others" | tr '\n' ' ')"
if git rev-parse --verify -q "$first_new^{commit}" >/dev/null; then
  mixed=$(printf '%s\n%s\n' "$old_refs" "$old_heads" | while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    if git merge-base --is-ancestor "$first_new" "$ref" 2>/dev/null; then printf '%s ' "$ref"; fi
  done)
  [ -z "$mixed" ] ||
    die "these merge the old history into the new one, as a git pull would: $mixed; reset each to its GitHub version, or put its own commits on it, then run this again"
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-rewrite.XXXXXX")
kept_log=${TMPDIR:-/tmp}/dotfiles-rewrite-filter-repo.log
drop_pins() {
  git for-each-ref --format='delete %(refname)' refs/history-rewrite refs/rewritten refs/rewritten-pins |
    git update-ref --stdin
}
trap 'drop_pins; rm -rf "$work"' EXIT

# filter-repo rewrites only what refs reach and drops a copy's remote-tracking
# refs, so pin every worktree's HEAD and every remote-tracking ref first.
git worktree list --porcelain | sed -n 's/^HEAD //p' | while IFS= read -r sha; do
  git update-ref "refs/history-rewrite/head/$sha" "$sha"
done
git for-each-ref --format='%(refname) %(objectname)' refs/remotes | while read -r ref sha; do
  git update-ref "refs/history-rewrite/${ref#refs/}" "$sha"
done

say "copying the clone"
git clone -q --mirror --no-local "$repo" "$work/clone.git"
git -C "$work/clone.git" for-each-ref --no-contains "$first" --format='delete %(refname)' |
  git -C "$work/clone.git" update-ref --stdin

say "fetching the rewritten history from GitHub"
git fetch -q --prune origin
git show "${HISTORY_REWRITE_DOC_REF:-origin/main}:docs/history-rewrite.md" |
  awk '/^```python$/{f=1; next} /^```$/{if (f) exit} f' >"$work/kde-history.py"
[ -s "$work/kde-history.py" ] || die "could not read the callback from docs/history-rewrite.md on GitHub's main"

say "rewriting the copy (a minute or two)"
(
  cd "$work/clone.git"
  nix shell nixpkgs#git-filter-repo --command \
    git filter-repo --sensitive-data-removal --force --file-info-callback "$work/kde-history.py" \
    >"$work/filter-repo.log" 2>&1
) || {
  cp "$work/filter-repo.log" "$kept_log"
  die "git filter-repo failed; see $kept_log"
}

lookup() { awk -v c="$1" '$1 == c {print $2; exit}' "$work/clone.git/filter-repo/commit-map"; }
say "checking the copy against GitHub"
[ "$(lookup "$first")" = "$first_new" ] ||
  die "the copy's rewrite differs from GitHub's ($first did not become $first_new); nothing was changed"
if git -C "$work/clone.git" log --all --oneline -1 -S'[Recent Files]' -- kde | grep -q .; then
  die "the copy still holds recent-file lists; nothing was changed"
fi

say "moving branches and refs onto the rewritten history"
git fetch -q --no-tags --no-prune "$work/clone.git" '+refs/heads/*:refs/rewritten/heads/*' '+refs/t3/*:refs/rewritten/t3/*' \
  '+refs/history-rewrite/*:refs/rewritten-pins/*'
checked_out=$(git worktree list --porcelain | sed -n 's|^branch ||p')
git for-each-ref --format='%(refname)' refs/rewritten | while IFS= read -r rewritten; do
  ref=refs/${rewritten#refs/rewritten/}
  new=$(git rev-parse "$rewritten")
  old=$(git rev-parse -q --verify "$ref" || true)
  [ "$new" = "$old" ] && continue
  if printf '%s\n' "$checked_out" | grep -qx "$ref"; then
    continue
  fi
  git update-ref "$ref" "$new" ${old:+"$old"}
done

git worktree list --porcelain | awk '
  /^worktree / {wt = substr($0, 10); head = ""; branch = ""}
  /^HEAD / {head = $2}
  /^branch / {branch = $2}
  /^$/ && wt != "" {print wt "\t" head "\t" branch; wt = ""}
  END {if (wt != "") print wt "\t" head "\t" branch}' |
  while IFS="$(printf '\t')" read -r wt head branch; do
    if [ -n "$branch" ]; then
      new=$(git rev-parse -q --verify "refs/rewritten/${branch#refs/}" || true)
    else
      new=$(lookup "$head")
    fi
    [ -n "$new" ] && [ "$new" != "$head" ] || continue
    outside=$(git diff --name-only "$head" "$new" | grep -v '^kde/' || true)
    if [ -n "$outside" ]; then
      die "$wt would change outside kde/; stopped before pruning, so running this again is safe"
    fi
    git -C "$wt" reset -q --hard "$new"
    if [ -n "$branch" ]; then what=${branch#refs/heads/}; else what="detached HEAD"; fi
    say "moved $what in $wt"
  done

drop_pins
prune_old
