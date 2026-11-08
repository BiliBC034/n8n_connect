#!/usr/bin/env bash
# Imprime las notas de una versión de CHANGELOG.md, sin el encabezado "## [X.Y.Z] - fecha".
# Las notas son las líneas entre el encabezado de la versión y el siguiente "## [".
# Uso: tools/changelog_section.sh X.Y.Z
# Sale con código 1 si la sección no existe o está vacía.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Uso: $0 X.Y.Z" >&2
  exit 2
fi

version="$1"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versión no válida: '$version'. Formato esperado: X.Y.Z" >&2
  exit 2
fi

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
changelog="$raiz/CHANGELOG.md"

if [[ ! -f "$changelog" ]]; then
  echo "No existe $changelog" >&2
  exit 1
fi

# awk compara el prefijo como texto (sin expresiones regulares) para que los puntos
# de la versión no actúen como comodines. Recorta las líneas en blanco de ambos extremos.
if ! notas="$(awk -v prefijo="## [${version}]" '
  BEGIN { dentro = 0; encontrada = 0; n = 0 }
  {
    if (!dentro) {
      siguiente = substr($0, length(prefijo) + 1, 1)
      if (substr($0, 1, length(prefijo)) == prefijo && (siguiente == "" || siguiente == " ")) {
        dentro = 1
        encontrada = 1
      }
      next
    }
    if (substr($0, 1, 4) == "## [") {
      exit
    }
    n++
    linea[n] = $0
  }
  END {
    if (!encontrada) {
      exit 3
    }
    inicio = 1
    while (inicio <= n && linea[inicio] ~ /^[[:space:]]*$/) {
      inicio++
    }
    fin = n
    while (fin >= inicio && linea[fin] ~ /^[[:space:]]*$/) {
      fin--
    }
    for (i = inicio; i <= fin; i++) {
      print linea[i]
    }
  }
' "$changelog")"; then
  echo "No hay sección [$version] en CHANGELOG.md" >&2
  exit 1
fi

if [[ -z "${notas//[[:space:]]/}" ]]; then
  echo "La sección [$version] de CHANGELOG.md está vacía" >&2
  exit 1
fi

printf '%s\n' "$notas"
