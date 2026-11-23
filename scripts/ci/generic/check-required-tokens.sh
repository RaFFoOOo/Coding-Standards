#!/usr/bin/env bash
# scripts/ci/generic/check-required-tokens.sh — fail when the app leaves undefined a custom property the shared
# UI libraries read.
#
# The libraries read tokens they never define: the tenant's colours, the chrome's heights, the layers of fixed
# bars. A token nobody defines makes every rule that reads it drop silently, with no build, lint or test error:
# a fixed bar loses its layer, a title its size. The token package ships the full list (`required-tokens.txt`);
# this checks that the app's own stylesheets define each one, so a default exists before the tenant's theme
# lands and in every test.
#
# Usage: check-required-tokens.sh <webapp-dir>   (after `npm ci`; reads the installed token package)
# Defined means a `--name:` declaration in a stylesheet under <webapp-dir>/src.
#
# Exit code: 0 = every token defined; 1 = at least one missing, or the list is not installed.

set -euo pipefail

app="${1:-}"
if [[ -z "$app" || ! -d "$app/src" ]]; then
  echo "::error::check-required-tokens: give the web app's directory (it must hold src/)" >&2
  exit 1
fi

list=$(ls "$app"/node_modules/@*/tokens-scss/required-tokens.txt 2>/dev/null | head -1 || true)
if [[ -z "$list" ]]; then
  echo "::error::check-required-tokens: no tokens-scss/required-tokens.txt under $app/node_modules; run npm ci, or update the token package (0.8.0 or later ships the list)" >&2
  exit 1
fi

defined=$(find "$app/src" -name '*.scss' -print0 \
  | xargs -0 sed -e 's://.*$::' \
  | grep -oE -- '--[a-z0-9-]+[[:space:]]*:' | tr -d ' \t:' | sort -u)

missing=$(comm -23 <(grep -v '^[[:space:]]*$' "$list" | sort -u) <(printf '%s\n' "$defined"))
if [[ -n "$missing" ]]; then
  while IFS= read -r token; do
    echo "::error::check-required-tokens: $token is read by the shared libraries and defined nowhere in $app/src; give it a default in the app's theme variables"
  done <<< "$missing"
  exit 1
fi
echo "check-required-tokens: all $(grep -cv '^[[:space:]]*$' "$list") tokens defined in $app/src"
