#!/usr/bin/env bash
# scripts/ci/validate-archive.sh — fail if a CLOSED lifecycle artifact sits at
# the repo root instead of archive/.
#
# Recurring drift the recursive review flagged three times (§4.6): closed
# PLAN/TEST_PLAN/EPIC/QA_REPORT files left at root. The rule:
#   closed  → must live in archive/
#   in-flight → must be referenced by name in CLAUDE.md or AGENTS.md
#
# A root artifact is ALLOWED when either:
#   1. it is the single newest PLAN_recursive_review_*.md (skill convention —
#      the current review stays at root until the next one supersedes it), or
#   2. its filename is referenced in CLAUDE.md or AGENTS.md (active sprint PLAN,
#      active EPIC, etc.).
# Anything else matching the patterns at root fails the check.
#
# Exit code: 0 = clean; 1 = at least one stray closed artifact at root.

set -euo pipefail
shopt -s nullglob

PATTERNS=(PLAN_*.md TEST_PLAN_*.md EPIC_*.md QA_REPORT_*.md)
POINTER_FILES=(CLAUDE.md AGENTS.md)

# Newest recursive-review file by filename (ISO dates sort lexicographically).
newest_review=""
reviews=(PLAN_recursive_review_*.md)
if ((${#reviews[@]})); then
  newest_review="$(printf '%s\n' "${reviews[@]}" | LC_ALL=C sort | tail -1)"
fi

fail=0
for f in "${PATTERNS[@]}"; do
  [[ -e "$f" ]] || continue

  if [[ -n "$newest_review" && "$f" == "$newest_review" ]]; then
    echo "OK   — current review, stays at root: $f"
    continue
  fi

  # Two-step grep: prevent "archive/<f>" substrings from falsely licensing bare "<f>".
  # (grep -qF matches substrings; "archive/foo.md" in CLAUDE.md would match bare "foo.md".)
  if grep -F -- "$f" "${POINTER_FILES[@]}" 2>/dev/null | grep -qvF "archive/$f"; then
    echo "OK   — referenced as in-flight: $f"
    continue
  fi

  echo "FAIL — closed artifact at repo root: $f"
  echo "       → move it to archive/ (git mv $f archive/$f), or reference it in CLAUDE.md/AGENTS.md if still in-flight."
  fail=1
done

if ((fail)); then
  echo "──────────────────────────────────────────"
  echo "validate-archive: stray closed artifact(s) at repo root. See messages above."
  exit 1
fi

echo "validate-archive: repo root clean."
