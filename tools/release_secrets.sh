#!/usr/bin/env bash
# Prints the GitHub Actions secrets needed by the release workflow
# (.github/workflows/release.yml), built from the local signing and Firebase files.
#
# Usage:
#   tools/release_secrets.sh                    print each secret and its value
#   tools/release_secrets.sh --gh [OWNER/REPO] upload the secrets with 'gh secret set'
#
# Optional secret FIREBASE_APP_DISTRIBUTION_SA_BASE64: set
# FIREBASE_SA_JSON=/absolute/path/to/service-account.json to include it.
#
# The output contains secrets: do not share it or paste it into chats, issues or screenshots.
# Full guide: docs/RELEASING.md
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Optional App Distribution service account. It is resolved to an absolute path
# before the cd below, so a relative path is taken from the caller's directory.
distribution_sa_path=""
if [[ -n "${FIREBASE_SA_JSON:-}" ]]; then
  if [[ ! -f "$FIREBASE_SA_JSON" || ! -r "$FIREBASE_SA_JSON" ]]; then
    echo "FIREBASE_SA_JSON is set but is not a readable file. Check the path. Nothing was printed or uploaded." >&2
    exit 1
  fi
  distribution_sa_path="$(cd "$(dirname "$FIREBASE_SA_JSON")" && pwd)/$(basename "$FIREBASE_SA_JSON")"
fi

cd "$root"

# Exact names of the secrets in the release contract.
SECRETS=(
  ANDROID_KEYSTORE_BASE64
  ANDROID_KEYSTORE_PASSWORD
  ANDROID_KEY_ALIAS
  ANDROID_KEY_PASSWORD
  GOOGLE_SERVICES_JSON_BASE64
  FIREBASE_OPTIONS_DART_BASE64
  FIREBASE_WEB_CLIENT_DART_BASE64
)
# Optional secret: included only when FIREBASE_SA_JSON points to a file.
OPTIONAL_SECRET=FIREBASE_APP_DISTRIBUTION_SA_BASE64

usage() {
  echo "Usage:" >&2
  echo "  $0                      print the secrets" >&2
  echo "  $0 --gh [OWNER/REPO]    upload the secrets with 'gh secret set'" >&2
}

# 1. Arguments.
gh_mode=0
repo=""
case "${1:-}" in
  "")
    if [[ $# -gt 0 ]]; then usage; exit 2; fi
    ;;
  --gh)
    gh_mode=1
    repo="${2:-}"
    if [[ $# -gt 2 ]]; then usage; exit 2; fi
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unrecognized option: $1" >&2
    usage
    exit 2
    ;;
esac

# 2. Source files. If any of them is missing, nothing is printed.
props_path="android/key.properties"
firebase_opts_path="lib/firebase_options.dart"
firebase_web_path="lib/firebase_web_client.dart"
google_services_path="android/app/google-services.json"

missing=0
for path in "$props_path" "$firebase_opts_path" "$firebase_web_path" "$google_services_path"; do
  if [[ ! -f "$path" ]]; then
    echo "MISSING: $path" >&2
    missing=1
  fi
done
if (( missing )); then
  echo "Local signing or Firebase files are missing. See docs/RELEASING.md." >&2
  exit 1
fi

# 3. Safe parsing of android/key.properties: line by line, without 'source' or eval.
#    It follows the same rule as java.util.Properties (used by Gradle): the key is
#    everything before the first '=', spaces around the key and leading spaces of the
#    value are removed, and the value is copied as is (the workflow writes it back
#    unchanged into key.properties).
STORE_FILE=""
STORE_PASSWORD=""
KEY_ALIAS=""
KEY_PASSWORD=""
line_num=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_num=$((line_num + 1))
  line="${line%$'\r'}"
  # Blank lines and comments.
  if [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*[#!] ]]; then
    continue
  fi
  if [[ "$line" != *=* ]]; then
    echo "Line $line_num of $props_path has no '=': ignored (its content is not shown)" >&2
    continue
  fi
  key="${line%%=*}"
  value="${line#*=}"
  key="${key#"${key%%[![:space:]]*}"}"
  key="${key%"${key##*[![:space:]]}"}"
  value="${value#"${value%%[![:space:]]*}"}"
  case "$key" in
    storeFile) STORE_FILE="$value" ;;
    storePassword) STORE_PASSWORD="$value" ;;
    keyAlias) KEY_ALIAS="$value" ;;
    keyPassword) KEY_PASSWORD="$value" ;;
    *) ;;
  esac
done < "$props_path"

for required_key in STORE_FILE STORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do
  if [[ -z "${!required_key}" ]]; then
    echo "Missing a required key in $props_path (storeFile, storePassword, keyAlias, keyPassword)" >&2
    exit 1
  fi
done

# storeFile can be relative to android/app, as Gradle resolves it with file().
if [[ "$STORE_FILE" != /* ]]; then
  STORE_FILE="$root/android/app/$STORE_FILE"
fi
if [[ ! -f "$STORE_FILE" ]]; then
  echo "The keystore given in storeFile does not exist: $STORE_FILE" >&2
  exit 1
fi

# 4. Secrets to print or upload, and the value of each one.
secrets=("${SECRETS[@]}")
if [[ -n "$distribution_sa_path" ]]; then
  secrets+=("$OPTIONAL_SECRET")
else
  echo "NOTE: $OPTIONAL_SECRET is optional and was not included: FIREBASE_SA_JSON is not set." >&2
  echo "      It is needed only to upload to App Distribution from GitHub Actions. To include it, run:" >&2
  echo "      FIREBASE_SA_JSON=/absolute/path/to/service-account.json tools/release_secrets.sh" >&2
fi

value_of() {
  case "$1" in
    ANDROID_KEYSTORE_BASE64) base64 -w0 < "$STORE_FILE" ;;
    ANDROID_KEYSTORE_PASSWORD) printf '%s' "$STORE_PASSWORD" ;;
    ANDROID_KEY_ALIAS) printf '%s' "$KEY_ALIAS" ;;
    ANDROID_KEY_PASSWORD) printf '%s' "$KEY_PASSWORD" ;;
    GOOGLE_SERVICES_JSON_BASE64) base64 -w0 < "$google_services_path" ;;
    FIREBASE_OPTIONS_DART_BASE64) base64 -w0 < "$firebase_opts_path" ;;
    FIREBASE_WEB_CLIENT_DART_BASE64) base64 -w0 < "$firebase_web_path" ;;
    FIREBASE_APP_DISTRIBUTION_SA_BASE64) base64 -w0 < "$distribution_sa_path" ;;
    *)
      echo "Unknown secret: $1" >&2
      return 1
      ;;
  esac
}

# 5. Print mode.
if (( ! gh_mode )); then
  echo "WARNING: the output contains SECRETS. Do not share it or paste it into chats, issues or screenshots." >&2
  echo >&2
  for name in "${secrets[@]}"; do
    echo "$name"
    value_of "$name"
    echo
    echo
  done
  exit 0
fi

# 6. --gh mode: upload with gh. The value goes through stdin, never as an argument.
echo "WARNING: the secrets are uploaded to the GitHub repository. Their values are not shown." >&2
if ! command -v gh >/dev/null 2>&1; then
  echo "'gh' not found. Install it (https://cli.github.com) or use the mode without --gh." >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated. Run 'gh auth login' and try again." >&2
  exit 1
fi

repo_args=()
if [[ -n "$repo" ]]; then
  repo_args=(--repo "$repo")
fi

for name in "${secrets[@]}"; do
  echo "Uploading $name..."
  value_of "$name" | gh secret set "$name" ${repo_args[@]+"${repo_args[@]}"}
done

echo "Secrets uploaded: ${#secrets[@]}"
