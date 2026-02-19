Create or update a PR from the current branch into `main` using the `gh` cli. If a PR template exists, fill every section; if a section is not applicable, leave it blank. Use a terse, narrative style to introduce the changes and direct reviewers.


## `gh pr create --help`
!`gh pr create --help`

## `git status -sb`
!`git status -sb`

## `git branch --show-current`
!`git branch --show-current`

## `git -P diff main...HEAD`
!`git -P diff --stat main...HEAD`
!`sh -lc 'git -P diff main...HEAD | sed -n "1,300p"'`

## `git -P log --oneline main...HEAD`
!`git -P log --oneline main...HEAD`

## First template content (if found)
!`sh -lc 'f=$(for x in pull_request_template.md docs/pull_request_template.md .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md .github/PULL_REQUEST_TEMPLATE/*.md PULL_REQUEST_TEMPLATE/*.md docs/PULL_REQUEST_TEMPLATE/*.md; do [ -f "$x" ] && echo "$x"; done | head -n1); [ -n "$f" ] && { echo "===== $f ====="; sed -n "1,220p" "$f"; } || echo "(none)"'`
