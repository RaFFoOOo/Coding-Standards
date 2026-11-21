#!/usr/bin/env bash
# scripts/standards/sync-projects.sh — sync the hub into every project and open one PR per project that changed.
#
#   scripts/standards/sync-projects.sh [--dry-run] [project-dir ...]
#
# Run from the hub after a change to the shared standards is merged. With no directories it reads
# scripts/standards/projects.local: one local checkout per line, `#` comments. That file is git-ignored on
# purpose: the hub is public and the list names private repositories.
#
# For each project:
#   skipped  — not clean, not on its default branch, behind its remote, or a sync PR is already open;
#   unchanged — sync.sh found nothing to merge: the branch is deleted;
#   PR       — a clean merge: committed on chore/sync-standards-<hub sha7>, pushed, one PR opened;
#   conflict — merge markers left: the branch is kept for a person (sync-templates step 5).
# SYNC_TRAILER, when set, is appended to each commit message and PR body.
#
# Exit code: 0 = every project synced or unchanged; 1 = a project was skipped or has conflicts.
set -euo pipefail

dry_run=false
if [[ "${1:-}" == "--dry-run" ]]; then dry_run=true; shift; fi

hub=$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)
list="$hub/scripts/standards/projects.local"
if [[ $# -gt 0 ]]; then
  projects=("$@")
elif [[ -f "$list" ]]; then
  mapfile -t projects < <(grep -vE '^\s*(#|$)' "$list")
else
  echo "sync-projects: no project given and no $list" >&2; exit 2
fi

git -C "$hub" fetch -q origin
if ! $dry_run && [[ -n "$(git -C "$hub" status --porcelain)" || "$(git -C "$hub" rev-parse HEAD)" != "$(git -C "$hub" rev-parse origin/HEAD)" ]]; then
  echo "sync-projects: the hub must be clean and at its remote default branch" >&2; exit 2
fi
sha=$(git -C "$hub" rev-parse --short=7 HEAD)
branch="chore/sync-standards-$sha"
needs_person=0

for p in "${projects[@]}"; do
  p=${p/#\~/$HOME}
  name=$(basename "$p")
  skip() { echo "skipped  $name — $1"; needs_person=1; }
  [[ -d "$p/.git" ]] || { skip "not a git checkout"; continue; }
  git -C "$p" fetch -q origin
  default=$(git -C "$p" symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##')
  [[ -z "$(git -C "$p" status --porcelain)" ]] || { skip "uncommitted changes"; continue; }
  [[ "$(git -C "$p" branch --show-current)" == "$default" ]] || { skip "not on $default"; continue; }
  [[ "$(git -C "$p" rev-parse HEAD)" == "$(git -C "$p" rev-parse "origin/$default")" ]] || { skip "$default is not at origin/$default"; continue; }
  open=$(cd "$p" && gh pr list --state open --search "head:chore/sync-standards-" --json number -q 'map(.number)|join(",")')
  [[ -z "$open" ]] || { skip "sync PR already open (#$open)"; continue; }
  if $dry_run; then echo "ready    $name — would sync from the hub at $sha"; continue; fi

  git -C "$p" checkout -q -b "$branch"
  set +e; out=$("$hub/scripts/standards/sync.sh" "$hub" "$p" 2>&1); rc=$?; set -e
  if [[ $rc -ne 0 && $rc -ne 1 ]]; then
    echo "$out" | tail -3; git -C "$p" checkout -q -- . 2>/dev/null || true; git -C "$p" checkout -q "$default"; git -C "$p" branch -q -D "$branch"
    skip "sync.sh exited $rc"; continue
  fi
  if [[ -z "$(git -C "$p" status --porcelain)" ]]; then
    git -C "$p" checkout -q "$default"; git -C "$p" branch -q -D "$branch"; echo "unchanged $name"; continue
  fi
  if [[ $rc -eq 1 ]]; then
    echo "conflict $name — resolve on $branch, then commit and open the PR:"; echo "$out" | grep '^conflict' | sed 's/^/           /'
    needs_person=1; continue
  fi
  files=$(echo "$out" | grep -E '^(updated|added|deleted|merged) ' | sed 's/^/- /')
  git -C "$p" add -A
  git -C "$p" commit -q -m "chore(standards): sync from the hub at $sha${SYNC_TRAILER:+

$SYNC_TRAILER}"
  git -C "$p" push -q -u origin "$branch" 2>/dev/null
  url=$(cd "$p" && gh pr create --base "$default" --head "$branch" --title "chore(standards): sync from the hub at $sha" --body "The shared standards at hub commit \`$sha\`, merged by \`sync-projects.sh\` without conflict:

$files

Read each change against this project's own instructions before merging; a rule that does not fit is opted out in \`.agents/standards-exclude\`.${SYNC_TRAILER:+

$SYNC_TRAILER}")
  git -C "$p" checkout -q "$default"
  echo "PR       $name — $url"
done

exit $needs_person
