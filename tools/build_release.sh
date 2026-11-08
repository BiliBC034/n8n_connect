#!/usr/bin/env bash
# Compila la APK de release en local y deja los artefactos en dist/:
#   dist/n8n-connect-vX.Y.Z.apk
#   dist/n8n-connect-vX.Y.Z.apk.sha256
#   dist/RELEASE_NOTES-vX.Y.Z.md
# Uso: tools/build_release.sh   (se puede ejecutar desde cualquier directorio)
# Guía completa: docs/RELEASING.md
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$raiz"

script_notas="$raiz/tools/changelog_section.sh"

# 1. Versión de pubspec.yaml sin el "+build".
version="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?[[:space:]]*$/\1/p' pubspec.yaml | head -n1)"
if [[ -z "$version" ]]; then
  echo "No se encuentra una línea 'version: X.Y.Z' en pubspec.yaml" >&2
  exit 1
fi
echo "Versión a compilar: $version"

# 2. Archivos locales necesarios para firmar y compilar con Firebase.
faltan=0
comprobar() {
  local ruta="$1" motivo="$2"
  if [[ ! -f "$ruta" ]]; then
    echo "FALTA: $ruta" >&2
    echo "       $motivo" >&2
    faltan=1
  fi
}
comprobar "android/key.properties" \
  "Clave de firma de release. Crea el keystore y el archivo siguiendo docs/RELEASING.md."
comprobar "lib/firebase_options.dart" \
  "Copia lib/firebase_options.example.dart o ejecuta 'flutterfire configure'. Ver docs/RELEASING.md."
comprobar "lib/firebase_web_client.dart" \
  "Copia lib/firebase_web_client.example.dart y pon el client ID web. Ver docs/RELEASING.md."
comprobar "android/app/google-services.json" \
  "Descárgalo de la consola de Firebase para me.bilibc.n8n_connect. Ver docs/RELEASING.md."
if (( faltan )); then
  echo "Faltan archivos locales. Consulta docs/RELEASING.md para crearlos." >&2
  exit 1
fi

# 3. Notas de la versión: el build se detiene si el CHANGELOG no tiene esa sección.
if ! notas="$("$script_notas" "$version")"; then
  echo "Falta la sección [$version] en CHANGELOG.md (o está vacía). Añádela antes de publicar." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "No se encuentra 'flutter' en el PATH" >&2
  exit 1
fi

# 4. Compilación de release.
echo "Compilando la APK de release..."
flutter build apk --release

apk_build="build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$apk_build" ]]; then
  echo "No se generó $apk_build" >&2
  exit 1
fi

# 5. Copia con el nombre de la release, checksum y notas.
nombre="n8n-connect-v${version}.apk"
mkdir -p dist
cp "$apk_build" "dist/$nombre"
(cd dist && sha256sum "$nombre" > "$nombre.sha256")
printf '%s\n' "$notas" > "dist/RELEASE_NOTES-v${version}.md"

# 6. Verificación de la firma: la APK no puede llevar la clave de depuración.
if ! "$raiz/tools/verify_apk_signature.sh" "dist/$nombre"; then
  rm -f "dist/$nombre" "dist/$nombre.sha256"
  exit 1
fi

# 7. Resumen.
echo
echo "Release v$version compilada y verificada:"
echo "  APK:           $raiz/dist/$nombre"
echo "  SHA-256 APK:   $raiz/dist/$nombre.sha256"
echo "  Notas:         $raiz/dist/RELEASE_NOTES-v${version}.md"
