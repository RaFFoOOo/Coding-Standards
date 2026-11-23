#!/usr/bin/env bash
# scripts/ci/generic/check-backlog-taxonomy.sh — fail if a backlog entry has no category and priority, or
# uses a value outside the closed sets.
#
# The two fields are what lets a sprint be scoped from the backlog instead of from whichever entry
# read best. A free-text label, or an entry with no label at all,
# silently drops out of every ordering that uses them — and nothing else in the repository reads
# these files, so an omission would never surface.
#
# The placement rule is load-bearing, not cosmetic. A marker line wraps (`⏳ trigger: …` runs to a
# second line often enough), and an automated insertion can split one mid-sentence by writing the
# field between the halves. The field therefore goes LAST in the marker block, and this
# checks that the line before it is a marker, a blank, or the title's blank line — never prose.
#
# Vocabularies live in .agents/rules/backlog.md; keep them in step.
#
# Exit code: 0 = every entry carries one valid pair; 1 = at least one does not.

set -euo pipefail

CATEGORIES='bug|change-request|feature|debt|infra|process|decision'
PRIORITIES='critical|high|medium|low'
FIELD_RE="^\*\*Category:\*\* (${CATEGORIES}) · \*\*Priority:\*\* (${PRIORITIES})$"

shopt -s nullglob
files=(backlog/[a-z]*.md)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "::error::check-backlog-taxonomy: no backlog/[a-z]*.md files found" >&2
  exit 1
fi

failures=0
entries=0

for file in "${files[@]}"; do
  [[ "$(basename "$file")" == "README.md" ]] && continue
  title=''
  title_line=0
  found=0
  lineno=0
  # A section runs from its '## ' heading to the next one. Everything is decided per section, so the
  # loop carries the pending verdict and flushes it when the next heading (or EOF) arrives.
  while IFS= read -r line || [[ -n "$line" ]]; do
    (( ++lineno ))
    if [[ "$line" == '## '* ]]; then
      if [[ -n "$title" && $found -eq 0 ]]; then
        echo "::error file=${file},line=${title_line}::no Category/Priority line: ${title}" >&2
        (( ++failures ))
      fi
      title="${line:3}"
      title_line=$lineno
      found=0
      (( ++entries ))
      continue
    fi
    [[ -z "$title" ]] && continue
    if [[ "$line" == '**Category:**'* || "$line" == '**Priority:**'* ]]; then
      if [[ $found -eq 1 ]]; then
        echo "::error file=${file},line=${lineno}::a second Category/Priority line: ${title}" >&2
        (( ++failures ))
      elif ! [[ "$line" =~ $FIELD_RE ]]; then
        echo "::error file=${file},line=${lineno}::malformed or unknown value — expected" \
             "'**Category:** <${CATEGORIES}> · **Priority:** <${PRIORITIES}>', got: ${line}" >&2
        (( ++failures ))
      fi
      found=1
    fi
  done < "$file"

  if [[ -n "$title" && $found -eq 0 ]]; then
    echo "::error file=${file},line=${title_line}::no Category/Priority line: ${title}" >&2
    (( ++failures ))
  fi
done

# The field must not land inside a wrapped marker sentence: the line after it starts the body, so it
# is blank. awk sees the whole file, which is cheaper here than re-reading it in bash.
while IFS= read -r offender; do
  echo "::error::${offender}" >&2
  (( ++failures ))
done < <(awk '
  /^\*\*Category:\*\*/ { here = FILENAME ":" FNR; getline
    if ($0 != "") print here ": the Category/Priority line splits a wrapped marker — move it below the whole marker block" }
' "${files[@]}")

# A trigger that names a sprint fires when that sprint runs. Once its plan is archived the sprint has
# closed, so the entry either shipped (close it) or slipped (re-point it): left alone, the trigger
# reads as pending forever.
while IFS=: read -r tfile tline tnum; do
  if compgen -G "archive/PLAN_sprint_*${tnum}.md" > /dev/null \
     && grep -qE "/PLAN_sprint_0*${tnum}\.md$" <<<"$(ls archive/PLAN_sprint_*.md)"; then
    echo "::error file=${tfile},line=${tline}::trigger names Sprint ${tnum}, which has closed — close the entry or re-point its trigger" >&2
    (( ++failures ))
  fi
done < <(grep -nE '^⏳ trigger: Sprint [0-9]+\b' "${files[@]}" | sed -E 's/^([^:]+):([0-9]+):⏳ trigger: Sprint ([0-9]+).*/\1:\2:\3/')

if [[ $failures -gt 0 ]]; then
  echo "check-backlog-taxonomy: ${failures} problem(s) across ${entries} entries" >&2
  exit 1
fi

echo "check-backlog-taxonomy: ${entries} entries, all classified"
