#!/usr/bin/env bash
# scripts/standards/sync.sh — merge the shared standards from one repository into another.
#
#   scripts/standards/sync.sh [--allow-delete] <from-repo> <to-repo>   merge, in either direction
#   scripts/standards/sync.sh --check <repo>        fail if a shared file names the project or a date
#
# The shared set is what .agents/standards-manifest.txt lists (one path or glob per line, `#`
# comments), read from both repositories. Exactly one of the two is the hub: it holds
# .agents/standards-hub. The other records, in .agents/standards-version, the hub commit it last
# synced with; that commit's copy of each file is the common ancestor of a three-way merge.
#
#   changed on one side only     → that side wins, deletions included
#   changed on both sides        → git merge-file; overlapping hunks get conflict markers
#   no ancestor (first sync, or a file new on both sides) and different → conflict markers
#
# A project opts out of shared files with .agents/standards-exclude (its own, never shared): one glob
# per line. An excluded path is never read, written or deleted on either side. A file the project
# lacks is never deleted from the hub unless --allow-delete is given: a missing file is not a decision.
#
# A shared file states rules, not history: --check also fails a dated line, a PR number or a sprint
# tag, which belong in the project's own records.
#
# Merging into the hub, every resulting file is first checked against the source's
# scripts/standards/project-terms.txt (one extended regex per line): a project name never reaches
# the hub. Nothing is written when the check fails.
#
# After a merge into a project, its standards-version moves to the hub's HEAD. After a merge into
# the hub, the hub's change lands through a PR; run the sync back from the hub once it is merged,
# which moves the project's marker to the merged commit.
#
# Exit: 0 merged cleanly; 1 conflicts left in the target (listed); 2 usage; 3 a project term would
# reach the hub; 4 the ancestor commit cannot be found in the hub.

set -euo pipefail
shopt -s globstar nullglob dotglob

MANIFEST=.agents/standards-manifest.txt
HUB_MARK=.agents/standards-hub
VERSION=.agents/standards-version
TERMS=scripts/standards/project-terms.txt
EXCLUDE=.agents/standards-exclude
HISTORY='\b20[0-9]{2}-[01][0-9]-[0-3][0-9]\b|(^|[^&[:alnum:]])#[0-9]{3,}\b|\bSprint [0-9]+|\bS[0-9]{2,3} T[0-9]+'

usage() { echo "usage: $0 [--allow-delete] <from-repo> <to-repo> | --check <repo>" >&2; exit 2; }
root() { git -C "$1" rev-parse --show-toplevel 2>/dev/null || { echo "not a git repository: $1" >&2; exit 2; }; }

# Prints the non-comment lines of file $1, trimmed.
globs() { [[ -f "$1" ]] || return 0; local l; while IFS= read -r l; do l="${l%%#*}"; l="${l//[[:space:]]/}"; [[ -n "$l" ]] && echo "$l"; done < "$1"; }

# Prints every file the manifest names in repo $1, one path per line, relative to its root.
expand() {
  local repo="$1" line
  while IFS= read -r line; do
    (cd "$repo" && for f in $line; do if [[ -f "$f" && ! -L "$f" ]]; then echo "$f"; fi; done)
  done < <(globs "$repo/$MANIFEST")
}

# Filters stdin, dropping each path that matches a glob in repo $1's exclude file.
included() {
  local -a ex; mapfile -t ex < <(globs "$1/$EXCLUDE")
  local p g
  while IFS= read -r p; do
    for g in "${ex[@]}"; do [[ "$p" == $g ]] && continue 2; done
    echo "$p"
  done
}

# Prints the lines of the files under $2 (relative paths on stdin) that match a term in $1.
term_hits() {
  local terms="$1" dir="$2" f
  [[ -s "$terms" ]] || return 0
  while IFS= read -r f; do
    [[ -f "$dir/$f" ]] && grep -inHE -f <(grep -vE '^\s*(#|$)' "$terms") "$dir/$f" | sed "s#^$dir/##" || true
  done
}

if [[ "${1:-}" == "--check" ]]; then
  [[ $# -eq 2 ]] || usage
  repo="$(root "$2")"
  files="$(expand "$repo" | included "$repo")"
  hits="$(term_hits "$repo/$TERMS" "$repo" <<< "$files")"
  if [[ -n "$hits" ]]; then
    echo "$hits"
    echo "::error::a shared file names this project — use a placeholder (CLAUDE.md, Placeholders)" >&2
    exit 1
  fi
  hist="$(cd "$repo" && while IFS= read -r f; do [[ -n "$f" ]] && grep -nHE "$HISTORY" "$f"; done <<< "$files" || true)"
  if [[ -n "$hist" ]]; then
    echo "$hist"
    echo "::error::a shared file carries history (a date, PR number or sprint tag) — state the rule; the incident belongs in the project's own records" >&2
    exit 1
  fi
  echo "check-shared-standards: $(grep -c . <<< "$files") shared files, no project term, no history"
  exit 0
fi

ALLOW_DELETE=false
if [[ "${1:-}" == "--allow-delete" ]]; then ALLOW_DELETE=true; shift; fi
[[ $# -eq 2 ]] || usage
SRC="$(root "$1")"; DST="$(root "$2")"
[[ "$SRC" != "$DST" ]] || usage
if [[ -f "$SRC/$HUB_MARK" && ! -f "$DST/$HUB_MARK" ]]; then HUB="$SRC"; PROJECT="$DST"
elif [[ -f "$DST/$HUB_MARK" && ! -f "$SRC/$HUB_MARK" ]]; then HUB="$DST"; PROJECT="$SRC"
else echo "exactly one repository must hold $HUB_MARK" >&2; exit 2; fi
# Conflict labels name the role, never the repository: a directory name can be a project term.
if [[ "$DST" == "$HUB" ]]; then DST_ROLE=hub; SRC_ROLE=project; else DST_ROLE=project; SRC_ROLE=hub; fi

BASE=""
if [[ -f "$PROJECT/$VERSION" ]]; then
  BASE="$(tr -d '[:space:]' < "$PROJECT/$VERSION")"
  if ! git -C "$HUB" cat-file -e "$BASE^{commit}" 2>/dev/null; then
    git -C "$HUB" fetch -q origin "$BASE" 2>/dev/null || true
    git -C "$HUB" cat-file -e "$BASE^{commit}" 2>/dev/null \
      || { echo "ancestor $BASE is not in the hub's history — fetch it, never guess it" >&2; exit 4; }
  fi
else
  echo "first sync: no $VERSION in $PROJECT, so every difference is a conflict to resolve by hand"
fi

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mapfile -t PATHS < <({ expand "$SRC"; expand "$DST"; } | sort -u | included "$PROJECT")
conflicts=(); changed=(); kept=()

# True when both files are missing, or both exist with the same bytes.
same() { if [[ -f "$1" && -f "$2" ]]; then cmp -s "$1" "$2"; else [[ ! -f "$1" && ! -f "$2" ]]; fi; }

for p in "${PATHS[@]}"; do
  s="$SRC/$p"; t="$DST/$p"; b="$WORK/base"; out="$WORK/out/$p"
  rm -f "$b"
  if [[ -n "$BASE" ]]; then git -C "$HUB" show "$BASE:$p" > "$b" 2>/dev/null || rm -f "$b"; fi
  same "$s" "$t" && continue
  same "$s" "$b" && continue                                      # only the target changed
  mkdir -p "$(dirname "$out")"
  if same "$t" "$b"; then                                         # only the source changed
    if [[ -f "$s" ]]; then cp "$s" "$out"
    elif [[ "$DST" == "$HUB" && "$ALLOW_DELETE" != true ]]; then kept+=("$p"); continue
    else : > "$out.deleted"; fi
  else                                                            # both changed, or no ancestor
    [[ -f "$b" ]] || : > "$b"
    theirs="$s"; [[ -f "$s" ]] || { theirs="$WORK/empty"; : > "$theirs"; }
    if [[ -f "$t" ]]; then cp "$t" "$out"; else : > "$out"; fi
    git merge-file -L "$DST_ROLE" -L "ancestor" -L "$SRC_ROLE" \
      "$out" "$b" "$theirs" || conflicts+=("$p")
  fi
  changed+=("$p")
done

if [[ "$DST" == "$HUB" ]] && (( ${#changed[@]} )); then
  hits="$(printf '%s\n' "${changed[@]}" | term_hits "$SRC/$TERMS" "$WORK/out")"
  if [[ -n "$hits" ]]; then
    echo "$hits"
    echo "refused: these lines would bring a project term into the hub; nothing was written" >&2
    exit 3
  fi
fi

for p in "${changed[@]}"; do
  if [[ -f "$WORK/out/$p.deleted" ]]; then rm -f "$DST/$p"; echo "deleted  $p"
  else mkdir -p "$(dirname "$DST/$p")"; cp "$WORK/out/$p" "$DST/$p"; echo "updated  $p"; fi
done

for d in rules skills; do
  link="$DST/.claude/$d"
  if [[ ! -e "$link" && ! -L "$link" ]]; then mkdir -p "$DST/.claude"; ln -s "../.agents/$d" "$link"; echo "linked   .claude/$d"
  elif [[ ! -L "$link" ]]; then echo "warning: .claude/$d is a real directory, not a link to ../.agents/$d" >&2; fi
done

if [[ "$DST" == "$PROJECT" ]]; then
  git -C "$HUB" rev-parse HEAD > "$PROJECT/$VERSION"
  echo "marker   $VERSION = $(cat "$PROJECT/$VERSION")"
else
  echo "merged into the hub: once its PR is merged, sync back from the hub to move the project's marker"
fi

if (( ${#kept[@]} )); then
  printf 'kept     %s (absent in the project: exclude it there, or rerun with --allow-delete)\n' "${kept[@]}"
fi

if (( ${#conflicts[@]} )); then
  printf 'conflict %s\n' "${conflicts[@]}"
  exit 1
fi
echo "sync: ${#changed[@]} file(s) changed, no conflict"
