#!/usr/bin/env bash
# Sends the release APK to Firebase App Distribution from this PC, for the testers.
# It builds the APK first with tools/build_release.sh, unless --no-build is given.
#
# Usage: tools/distribute.sh [--groups testers,qa] [--notes "text" | --notes-file file] [--no-build]
#   --groups       Tester groups, comma-separated (default: $FIREBASE_TESTER_GROUPS or "testers")
#   --notes        Release notes as text
#   --notes-file   Release notes from a file
#                  (default: the CHANGELOG.md section of the version, or "Test build <git short sha>")
#   --no-build     Do not build: use the existing dist/n8n-connect-vX.Y.Z.apk
#
# Requires the firebase CLI (npm install -g firebase-tools) and either 'firebase login'
# or GOOGLE_APPLICATION_CREDENTIALS pointing to a service-account JSON file.
# Full guide: docs/RELEASING.md#h-distributing-to-testers-firebase-app-distribution
set -euo pipefail

usage() {
  echo "Usage: $0 [--groups testers,qa] [--notes \"text\" | --notes-file file] [--no-build]" >&2
}

# 1. Arguments. Relative paths are resolved here, before the cd to the repository root.
groups="${FIREBASE_TESTER_GROUPS:-testers}"
notes_text=""
notes_file=""
has_notes_text=0
has_notes_file=0
build=1
while (( $# > 0 )); do
  case "$1" in
    --groups)
      if [[ $# -lt 2 ]]; then echo "--groups needs a value" >&2; usage; exit 2; fi
      groups="$2"
      shift 2
      ;;
    --notes)
      if [[ $# -lt 2 ]]; then echo "--notes needs a text" >&2; usage; exit 2; fi
      notes_text="$2"
      has_notes_text=1
      shift 2
      ;;
    --notes-file)
      if [[ $# -lt 2 ]]; then echo "--notes-file needs a path" >&2; usage; exit 2; fi
      notes_file="$2"
      has_notes_file=1
      shift 2
      ;;
    --no-build)
      build=0
      shift
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
done

if [[ -z "$groups" ]]; then
  echo "The tester groups are empty. Use --groups or set FIREBASE_TESTER_GROUPS." >&2
  exit 2
fi
if (( has_notes_text && has_notes_file )); then
  echo "Use either --notes or --notes-file, not both." >&2
  exit 2
fi
if (( has_notes_text )) && [[ -z "$notes_text" ]]; then
  echo "--notes cannot be empty." >&2
  exit 2
fi
if (( has_notes_file )); then
  if [[ "$notes_file" != /* ]]; then
    notes_file="$PWD/$notes_file"
  fi
  if [[ ! -f "$notes_file" ]]; then
    echo "The notes file does not exist: $notes_file" >&2
    exit 1
  fi
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# 2. Firebase CLI and credentials.
if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase CLI not found in PATH. Install it with: npm install -g firebase-tools" >&2
  exit 1
fi
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  if [[ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
    echo "GOOGLE_APPLICATION_CREDENTIALS does not point to a file." >&2
    exit 1
  fi
else
  echo "GOOGLE_APPLICATION_CREDENTIALS is not set: using the account from 'firebase login' (run it first if you are not logged in)." >&2
fi

# 3. App id of the Android app, from google-services.json.
google_services="android/app/google-services.json"
if [[ ! -f "$google_services" ]]; then
  echo "MISSING: $google_services" >&2
  echo "         Download it from the Firebase console for me.bilibc.n8n_connect. See docs/RELEASING.md." >&2
  exit 1
fi

read_app_id_py='
import json
import sys

PACKAGE = "me.bilibc.n8n_connect"
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
except (OSError, ValueError):
    sys.exit(1)
if not isinstance(data, dict):
    sys.exit(1)
for client in data.get("client", []):
    info = client.get("client_info", {})
    if info.get("android_client_info", {}).get("package_name") == PACKAGE:
        print(info.get("mobilesdk_app_id", ""))
        break
'
if ! app_id="$(python3 -I -c "$read_app_id_py" "$google_services")"; then
  echo "Could not read $google_services" >&2
  exit 1
fi
if [[ -z "$app_id" ]]; then
  echo "No Android app for me.bilibc.n8n_connect in $google_services. Download it again from the Firebase console." >&2
  exit 1
fi

# 4. Version from pubspec.yaml without the "+build" part.
version="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?[[:space:]]*$/\1/p' pubspec.yaml | head -n1)"
if [[ -z "$version" ]]; then
  echo "No 'version: X.Y.Z' line found in pubspec.yaml" >&2
  exit 1
fi
apk="dist/n8n-connect-v${version}.apk"

# 5. Build, or reuse the APK in dist/. build_release.sh checks the signature itself.
if (( build )); then
  # Test builds may be of a version that is not in the CHANGELOG yet (see build_release.sh).
  SKIP_NOTES_CHECK=1 "$root/tools/build_release.sh"
else
  if [[ ! -f "$apk" ]]; then
    echo "APK not found: $apk. Build it without --no-build, or run tools/build_release.sh first." >&2
    exit 1
  fi
  "$root/tools/verify_apk_signature.sh" "$apk"
fi

# 6. Release notes: the file or text given, or else the CHANGELOG section of this version.
notes_tmp=""
if (( has_notes_file )); then
  notes_path="$notes_file"
else
  notes_tmp="$(mktemp)"
  trap 'rm -f "$notes_tmp"' EXIT
  notes_path="$notes_tmp"
  if (( has_notes_text )); then
    printf '%s\n' "$notes_text" > "$notes_path"
  elif ! "$root/tools/changelog_section.sh" "$version" > "$notes_path"; then
    echo "No usable [$version] section in CHANGELOG.md. Using the fallback release notes." >&2
    printf 'Test build %s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)" > "$notes_path"
  fi
fi

# 7. Upload.
echo "Sending $apk to Firebase App Distribution (app $app_id, groups: $groups)..."
firebase appdistribution:distribute "$apk" --app "$app_id" --groups "$groups" --release-notes-file "$notes_path"
echo "Release v$version sent to the groups: $groups"
