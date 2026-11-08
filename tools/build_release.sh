#!/usr/bin/env bash
# Builds the release APK locally and leaves the artifacts in dist/:
#   dist/n8n-connect-vX.Y.Z.apk
#   dist/n8n-connect-vX.Y.Z.apk.sha256
#   dist/RELEASE_NOTES-vX.Y.Z.md
# Usage: tools/build_release.sh   (can be run from any directory)
# SKIP_NOTES_CHECK=1 (test builds only): if CHANGELOG.md has no section for the version,
# the build continues and the notes are "Test build <git short sha>" instead of stopping.
# Full guide: docs/RELEASING.md
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

notes_script="$root/tools/changelog_section.sh"

# 1. Version from pubspec.yaml without the "+build" part.
version="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?[[:space:]]*$/\1/p' pubspec.yaml | head -n1)"
if [[ -z "$version" ]]; then
  echo "No 'version: X.Y.Z' line found in pubspec.yaml" >&2
  exit 1
fi
echo "Version to build: $version"

# 2. Local files needed to sign and build with Firebase.
missing=0
check() {
  local path="$1" reason="$2"
  if [[ ! -f "$path" ]]; then
    echo "MISSING: $path" >&2
    echo "         $reason" >&2
    missing=1
  fi
}
check "android/key.properties" \
  "Release signing key. Create the keystore and the file following docs/RELEASING.md."
check "lib/firebase_options.dart" \
  "Copy lib/firebase_options.example.dart or run 'flutterfire configure'. See docs/RELEASING.md."
check "lib/firebase_web_client.dart" \
  "Copy lib/firebase_web_client.example.dart and set the web client ID. See docs/RELEASING.md."
check "android/app/google-services.json" \
  "Download it from the Firebase console for me.bilibc.n8n_connect. See docs/RELEASING.md."
if (( missing )); then
  echo "Local files are missing. See docs/RELEASING.md to create them." >&2
  exit 1
fi

# 3. Release notes: the build stops if the CHANGELOG has no section for this version,
#    unless SKIP_NOTES_CHECK=1 (test builds): then the notes are "Test build <git short sha>".
if ! notes="$("$notes_script" "$version")"; then
  if [[ "${SKIP_NOTES_CHECK:-}" != "1" ]]; then
    echo "The [$version] section is missing from CHANGELOG.md (or is empty). Add it before publishing." >&2
    exit 1
  fi
  sha=""
  if command -v git >/dev/null 2>&1; then
    sha="$(git rev-parse --short HEAD 2>/dev/null || true)"
  fi
  notes="Test build${sha:+ $sha}"
  echo "SKIP_NOTES_CHECK=1: no [$version] section in CHANGELOG.md. Using the notes: $notes" >&2
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "'flutter' not found in PATH" >&2
  exit 1
fi

# 4. Release build.
echo "Building the release APK..."
flutter build apk --release

apk_build="build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$apk_build" ]]; then
  echo "$apk_build was not generated" >&2
  exit 1
fi

# 5. Copy with the release name, checksum and notes.
name="n8n-connect-v${version}.apk"
mkdir -p dist
cp "$apk_build" "dist/$name"
(cd dist && sha256sum "$name" > "$name.sha256")
printf '%s\n' "$notes" > "dist/RELEASE_NOTES-v${version}.md"

# 6. Signature check: the APK must not carry the debug key.
if ! "$root/tools/verify_apk_signature.sh" "dist/$name"; then
  rm -f "dist/$name" "dist/$name.sha256"
  exit 1
fi

# 7. Summary.
echo
echo "Release v$version built and verified:"
echo "  APK:           $root/dist/$name"
echo "  APK SHA-256:   $root/dist/$name.sha256"
echo "  Notes:         $root/dist/RELEASE_NOTES-v${version}.md"
