#!/usr/bin/env bash
# Comprueba la firma de una APK con apksigner (lee los esquemas v1, v2 y v3;
# keytool solo entiende v1 y Android 7+ firma con v2) y falla si la APK no
# verifica o está firmada con la clave de depuración.
# Uso: tools/verify_apk_signature.sh ruta/a/la.apk
# Imprime el DN y las huellas SHA-256 y SHA-1 del certificado.
set -euo pipefail

apk="${1:-}"
if [[ -z "$apk" || ! -f "$apk" ]]; then
  echo "Uso: $0 ruta/a/la.apk" >&2
  exit 2
fi

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# apksigner: del PATH o de la build-tools más reciente del Android SDK
# (ANDROID_HOME, ANDROID_SDK_ROOT o sdk.dir de android/local.properties).
buscar_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -z "$sdk" && -f "$raiz/android/local.properties" ]]; then
    sdk="$(sed -n 's/^sdk\.dir=//p' "$raiz/android/local.properties" | head -n1)"
  fi
  [[ -n "$sdk" && -d "$sdk/build-tools" ]] || return 1
  local candidato
  candidato="$(find "$sdk/build-tools" -mindepth 2 -maxdepth 2 -name apksigner -type f 2>/dev/null | sort -V | tail -n1)"
  [[ -n "$candidato" ]] || return 1
  printf '%s\n' "$candidato"
}

if ! apksigner="$(buscar_apksigner)"; then
  echo "No se encuentra apksigner. Instala las build-tools del Android SDK o define ANDROID_HOME." >&2
  exit 1
fi

if ! salida="$("$apksigner" verify --print-certs "$apk" 2>&1)"; then
  echo "ERROR: la firma de $apk no verifica:" >&2
  echo "$salida" >&2
  exit 1
fi

dn="$(sed -n 's/^Signer #1 certificate DN: //p' <<<"$salida")"
sha256="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$salida")"
sha1="$(sed -n 's/^Signer #1 certificate SHA-1 digest: //p' <<<"$salida")"

if [[ -z "$dn" || -z "$sha256" ]]; then
  echo "ERROR: no se pudo leer el certificado de $apk en la salida de apksigner:" >&2
  echo "$salida" >&2
  exit 1
fi

if [[ "$dn" == *"CN=Android Debug"* ]]; then
  echo "ERROR: $apk está firmada con la clave de DEPURACIÓN ($dn)." >&2
  echo "       Revisa android/key.properties y docs/RELEASING.md. No publiques esta APK." >&2
  exit 1
fi

echo "Firma correcta: $dn"
echo "  SHA-256 del certificado: $sha256"
echo "  SHA-1 del certificado:   $sha1"
