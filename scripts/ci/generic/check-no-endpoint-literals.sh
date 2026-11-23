#!/usr/bin/env bash
# scripts/ci/generic/check-no-endpoint-literals.sh — fail on an address written into the app's code
# or its committed configuration.
#
# Every address the app talks to (the API, the sign-in authority, a storage account) belongs to a
# deployment, so it comes from that deployment's environment variables at deploy time. One written
# into a source file binds every deployment to it: moving the resource then takes a commit and a
# rebuild instead of a changed variable.
#
# Usage: check-no-endpoint-literals.sh <path>...   (directories are scanned recursively)
# Scanned: .ts and .json files, except specs and *.testing.ts. Third-party content the browser loads
# from fixed hosts (fonts in index.html, mock data) is outside the paths a project passes.
#
# Exit code: 0 = no literal; 1 = at least one, or no path given.

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "::error::check-no-endpoint-literals: no path given" >&2
  exit 1
fi

PATTERN='[a-z][a-z0-9+.-]*://[A-Za-z0-9]'

hits=$(grep -rnE "$PATTERN" "$@" --include='*.ts' --include='*.json' \
  --exclude='*.spec.ts' --exclude='*.testing.ts' || true)

if [[ -n "$hits" ]]; then
  while IFS= read -r hit; do
    file=${hit%%:*}; rest=${hit#*:}; line=${rest%%:*}
    echo "::error file=$file,line=$line::An address is written into the code; take it from the deployment's configuration (config.json) instead" >&2
  done <<<"$hits"
  echo "$hits" >&2
  exit 1
fi
echo "check-no-endpoint-literals: no address literal in $*"
