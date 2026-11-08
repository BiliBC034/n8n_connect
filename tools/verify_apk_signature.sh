#!/usr/bin/env bash
# Checks the signature of an APK with apksigner (it reads the v1, v2 and v3 schemes;
# keytool only understands v1, and Android 7+ signs with v2) and fails if the APK does
# not verify or is signed with the debug key.
# Usage: tools/verify_apk_signature.sh path/to/the.apk
# Prints the DN and the SHA-256 and SHA-1 digests of the certificate.
set -euo pipefail

apk="${1:-}"
if [[ -z "$apk" || ! -f "$apk" ]]; then
  echo "Usage: $0 path/to/the.apk" >&2
  exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# apksigner: from PATH or from the newest build-tools of the Android SDK
# (ANDROID_HOME, ANDROID_SDK_ROOT or sdk.dir in android/local.properties).
find_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -z "$sdk" && -f "$root/android/local.properties" ]]; then
    sdk="$(sed -n 's/^sdk\.dir=//p' "$root/android/local.properties" | head -n1)"
  fi
  [[ -n "$sdk" && -d "$sdk/build-tools" ]] || return 1
  local candidate
  candidate="$(find "$sdk/build-tools" -mindepth 2 -maxdepth 2 -name apksigner -type f 2>/dev/null | sort -V | tail -n1)"
  [[ -n "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}

if ! apksigner="$(find_apksigner)"; then
  echo "apksigner not found. Install the Android SDK build-tools or set ANDROID_HOME." >&2
  exit 1
fi

if ! output="$("$apksigner" verify --print-certs "$apk" 2>&1)"; then
  echo "ERROR: the signature of $apk does not verify:" >&2
  echo "$output" >&2
  exit 1
fi

# apksigner up to build-tools 36 prints "Signer #1 certificate DN: …"; build-tools 37
# prints "V2 Signer: certificate DN: …" (one block per scheme). Accept both and look
# at every signer line, so a debug certificate is caught whatever the format.
field() {
  sed -nE "s/^(Signer #[0-9]+|V[0-9]+(\\.[0-9]+)? Signer:) certificate $1: //p" <<<"$output"
}
dns="$(field 'DN' | sort -u)"
dn="$(head -n1 <<<"$dns")"
sha256="$(field 'SHA-256 digest' | head -n1)"
sha1="$(field 'SHA-1 digest' | head -n1)"

if [[ -z "$dn" || -z "$sha256" ]]; then
  echo "ERROR: could not read the certificate of $apk from the apksigner output:" >&2
  echo "$output" >&2
  exit 1
fi

if grep -q 'CN=Android Debug' <<<"$dns"; then
  echo "ERROR: $apk is signed with the DEBUG key ($dns)." >&2
  echo "       Check android/key.properties and docs/RELEASING.md. Do not publish this APK." >&2
  exit 1
fi

if (( $(wc -l <<<"$dns") > 1 )); then
  echo "ERROR: $apk has more than one signing certificate:" >&2
  echo "$dns" >&2
  exit 1
fi

echo "Valid signature: $dn"
echo "  SHA-256 certificate digest: $sha256"
echo "  SHA-1 certificate digest:   $sha1"
