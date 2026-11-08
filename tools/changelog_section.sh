#!/usr/bin/env bash
# Prints the notes of one version from CHANGELOG.md, without the "## [X.Y.Z] - date" heading.
# The notes are the lines between the version heading and the next "## [".
# Usage: tools/changelog_section.sh X.Y.Z
# Exits with code 1 if the section does not exist or is empty.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 X.Y.Z" >&2
  exit 2
fi

version="$1"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version: '$version'. Expected format: X.Y.Z" >&2
  exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
changelog="$root/CHANGELOG.md"

if [[ ! -f "$changelog" ]]; then
  echo "$changelog does not exist" >&2
  exit 1
fi

# awk compares the prefix as plain text (no regular expressions) so that the dots
# in the version do not act as wildcards. It trims blank lines at both ends.
if ! notes="$(awk -v prefix="## [${version}]" '
  BEGIN { inside = 0; found = 0; n = 0 }
  {
    if (!inside) {
      following = substr($0, length(prefix) + 1, 1)
      if (substr($0, 1, length(prefix)) == prefix && (following == "" || following == " ")) {
        inside = 1
        found = 1
      }
      next
    }
    if (substr($0, 1, 4) == "## [") {
      exit
    }
    n++
    line[n] = $0
  }
  END {
    if (!found) {
      exit 3
    }
    start = 1
    while (start <= n && line[start] ~ /^[[:space:]]*$/) {
      start++
    }
    last = n
    while (last >= start && line[last] ~ /^[[:space:]]*$/) {
      last--
    }
    for (i = start; i <= last; i++) {
      print line[i]
    }
  }
' "$changelog")"; then
  echo "There is no [$version] section in CHANGELOG.md" >&2
  exit 1
fi

if [[ -z "${notes//[[:space:]]/}" ]]; then
  echo "The [$version] section in CHANGELOG.md is empty" >&2
  exit 1
fi

printf '%s\n' "$notes"
