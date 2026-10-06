#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OpenTable — Publicación automática en Itch.io mediante butler CLI
# Uso: ./store/itch/update_page.sh [version]
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
ITCH_PROJECT="${ITCH_PROJECT:-joduranvillan/opentable}"
VERSION="${1:-1.0.0}"

if ! command -v butler >/dev/null 2>&1; then
    echo "Aviso: 'butler' CLI no está instalado en PATH."
    echo "Comandos que se ejecutarán al desplegar:"
    echo "  butler push ${DIST_DIR}/opentable-linux-x86_64/ ${ITCH_PROJECT}:linux-x86_64 --userversion ${VERSION}"
    echo "  butler push ${DIST_DIR}/opentable-windows-x86_64/ ${ITCH_PROJECT}:windows-x86_64 --userversion ${VERSION}"
    echo "  butler push ${DIST_DIR}/opentable-macos-universal/ ${ITCH_PROJECT}:macos-universal --userversion ${VERSION}"
    exit 0
fi

if [[ -d "${DIST_DIR}/opentable-linux-x86_64" ]]; then
    butler push "${DIST_DIR}/opentable-linux-x86_64/" "${ITCH_PROJECT}:linux-x86_64" --userversion "${VERSION}"
fi

if [[ -d "${DIST_DIR}/opentable-windows-x86_64" ]]; then
    butler push "${DIST_DIR}/opentable-windows-x86_64/" "${ITCH_PROJECT}:windows-x86_64" --userversion "${VERSION}"
fi

if [[ -d "${DIST_DIR}/opentable-macos-universal" ]]; then
    butler push "${DIST_DIR}/opentable-macos-universal/" "${ITCH_PROJECT}:macos-universal" --userversion "${VERSION}"
fi

echo "Publicación en Itch.io (${ITCH_PROJECT} v${VERSION}) completada."
