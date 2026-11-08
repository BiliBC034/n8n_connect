#!/usr/bin/env bash
# Muestra los secretos de GitHub Actions que necesita el workflow de release
# (.github/workflows/release.yml), a partir de los archivos locales de firma y Firebase.
#
# Uso:
#   tools/release_secrets.sh                  imprime cada secreto y su valor
#   tools/release_secrets.sh --gh [OWNER/REPO] sube los secretos con 'gh secret set'
#
# La salida contiene secretos: no la compartas ni la pegues en chats, issues o capturas.
# Guía completa: docs/RELEASING.md
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$raiz"

# Nombres exactos de los secretos del contrato de release.
SECRETOS=(
  ANDROID_KEYSTORE_BASE64
  ANDROID_KEYSTORE_PASSWORD
  ANDROID_KEY_ALIAS
  ANDROID_KEY_PASSWORD
  GOOGLE_SERVICES_JSON_BASE64
  FIREBASE_OPTIONS_DART_BASE64
  FIREBASE_WEB_CLIENT_DART_BASE64
)

uso() {
  echo "Uso:" >&2
  echo "  $0                      imprime los secretos" >&2
  echo "  $0 --gh [OWNER/REPO]    sube los secretos con 'gh secret set'" >&2
}

# 1. Argumentos.
modo_gh=0
repo=""
case "${1:-}" in
  "")
    if [[ $# -gt 0 ]]; then uso; exit 2; fi
    ;;
  --gh)
    modo_gh=1
    repo="${2:-}"
    if [[ $# -gt 2 ]]; then uso; exit 2; fi
    ;;
  -h|--help)
    uso
    exit 0
    ;;
  *)
    echo "Opción no reconocida: $1" >&2
    uso
    exit 2
    ;;
esac

# 2. Archivos de origen. Si falta alguno, no se imprime nada.
ruta_props="android/key.properties"
ruta_firebase_opts="lib/firebase_options.dart"
ruta_firebase_web="lib/firebase_web_client.dart"
ruta_google_services="android/app/google-services.json"

faltan=0
for ruta in "$ruta_props" "$ruta_firebase_opts" "$ruta_firebase_web" "$ruta_google_services"; do
  if [[ ! -f "$ruta" ]]; then
    echo "FALTA: $ruta" >&2
    faltan=1
  fi
done
if (( faltan )); then
  echo "Faltan archivos locales de firma o Firebase. Consulta docs/RELEASING.md." >&2
  exit 1
fi

# 3. Parseo seguro de android/key.properties: línea a línea, sin 'source' ni eval.
#    Sigue la misma regla que java.util.Properties (que usa Gradle): la clave va antes del
#    primer '=', se quitan los espacios de alrededor de la clave y los iniciales del valor,
#    y el valor se copia tal cual (el workflow lo vuelve a escribir igual en key.properties).
STORE_FILE=""
STORE_PASSWORD=""
KEY_ALIAS=""
KEY_PASSWORD=""
linea_num=0
while IFS= read -r linea || [[ -n "$linea" ]]; do
  linea_num=$((linea_num + 1))
  linea="${linea%$'\r'}"
  # Líneas vacías y comentarios.
  if [[ "$linea" =~ ^[[:space:]]*$ || "$linea" =~ ^[[:space:]]*[#!] ]]; then
    continue
  fi
  if [[ "$linea" != *=* ]]; then
    echo "Línea $linea_num de $ruta_props sin '=': se ignora (no se muestra su contenido)" >&2
    continue
  fi
  clave="${linea%%=*}"
  valor="${linea#*=}"
  clave="${clave#"${clave%%[![:space:]]*}"}"
  clave="${clave%"${clave##*[![:space:]]}"}"
  valor="${valor#"${valor%%[![:space:]]*}"}"
  case "$clave" in
    storeFile) STORE_FILE="$valor" ;;
    storePassword) STORE_PASSWORD="$valor" ;;
    keyAlias) KEY_ALIAS="$valor" ;;
    keyPassword) KEY_PASSWORD="$valor" ;;
    *) ;;
  esac
done < "$ruta_props"

for clave_obligatoria in STORE_FILE STORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do
  if [[ -z "${!clave_obligatoria}" ]]; then
    echo "Falta una clave obligatoria en $ruta_props (storeFile, storePassword, keyAlias, keyPassword)" >&2
    exit 1
  fi
done

# storeFile puede ser relativo a android/app, como lo resuelve Gradle con file().
if [[ "$STORE_FILE" != /* ]]; then
  STORE_FILE="$raiz/android/app/$STORE_FILE"
fi
if [[ ! -f "$STORE_FILE" ]]; then
  echo "No existe el keystore indicado en storeFile: $STORE_FILE" >&2
  exit 1
fi

# 4. Valor de cada secreto.
valor_de() {
  case "$1" in
    ANDROID_KEYSTORE_BASE64) base64 -w0 < "$STORE_FILE" ;;
    ANDROID_KEYSTORE_PASSWORD) printf '%s' "$STORE_PASSWORD" ;;
    ANDROID_KEY_ALIAS) printf '%s' "$KEY_ALIAS" ;;
    ANDROID_KEY_PASSWORD) printf '%s' "$KEY_PASSWORD" ;;
    GOOGLE_SERVICES_JSON_BASE64) base64 -w0 < "$ruta_google_services" ;;
    FIREBASE_OPTIONS_DART_BASE64) base64 -w0 < "$ruta_firebase_opts" ;;
    FIREBASE_WEB_CLIENT_DART_BASE64) base64 -w0 < "$ruta_firebase_web" ;;
    *)
      echo "Secreto desconocido: $1" >&2
      return 1
      ;;
  esac
}

# 5. Modo impresión.
if (( ! modo_gh )); then
  echo "AVISO: la salida contiene SECRETOS. No la compartas ni la pegues en chats, issues o capturas." >&2
  echo >&2
  for nombre in "${SECRETOS[@]}"; do
    echo "$nombre"
    valor_de "$nombre"
    echo
    echo
  done
  exit 0
fi

# 6. Modo --gh: subida con gh. El valor viaja por stdin, nunca como argumento.
echo "AVISO: los secretos se suben al repositorio de GitHub. No muestro sus valores." >&2
if ! command -v gh >/dev/null 2>&1; then
  echo "No se encuentra 'gh'. Instálalo (https://cli.github.com) o usa el modo sin --gh." >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh no está autenticado. Ejecuta 'gh auth login' y vuelve a intentarlo." >&2
  exit 1
fi

argumentos_repo=()
if [[ -n "$repo" ]]; then
  argumentos_repo=(--repo "$repo")
fi

for nombre in "${SECRETOS[@]}"; do
  echo "Subiendo $nombre..."
  valor_de "$nombre" | gh secret set "$nombre" ${argumentos_repo[@]+"${argumentos_repo[@]}"}
done

echo "Secretos subidos: ${#SECRETOS[@]}"
