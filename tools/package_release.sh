#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OpenTable SDK — Script de Empaquetado de Distribuciones (v1.0.0)
# Compila los binarios release de Rust, exporta el proyecto Godot/Redot y
# genera paquetes .tar.gz / .zip junto con SHA256SUMS.txt en dist/.
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
LINUX_PKG_DIR="${DIST_DIR}/opentable-linux-x86_64"
WINDOWS_PKG_DIR="${DIST_DIR}/opentable-windows-x86_64"
REDOT_BIN="${REDOT_BIN:-redot}"

echo "=== [1/5] Preparando directorios de distribución en ${DIST_DIR} ==="
rm -rf "${LINUX_PKG_DIR}" "${WINDOWS_PKG_DIR}"
mkdir -p "${LINUX_PKG_DIR}/bin" "${LINUX_PKG_DIR}/addons" "${LINUX_PKG_DIR}/assets"
mkdir -p "${WINDOWS_PKG_DIR}/bin" "${WINDOWS_PKG_DIR}/addons" "${WINDOWS_PKG_DIR}/assets"

echo "=== [2/5] Compilando binarios release de Rust (open_table_godot & open_table_relay) ==="
cd "${ROOT_DIR}"
if [[ -f "${ROOT_DIR}/extension_api.json" ]]; then
    export GODOT4_GDEXTENSION_JSON="${ROOT_DIR}/extension_api.json"
fi
cargo build --release -p open_table_godot
cargo build --release -p open_table_relay

# Compilación cruzada opcional para Windows si el target está instalado
if rustup target list --installed 2>/dev/null | grep -q "x86_64-pc-windows-gnu"; then
    echo "Compilando binario Windows (x86_64-pc-windows-gnu)..."
    cargo build --release --target x86_64-pc-windows-gnu -p open_table_godot || true
fi

echo "=== [3/5] Copiando librerías nativas (.so / .dll), addon y assets ==="
if [[ -f "${ROOT_DIR}/target/release/libopen_table_godot.so" ]]; then
    cp -f "${ROOT_DIR}/target/release/libopen_table_godot.so" "${LINUX_PKG_DIR}/bin/"
fi
if [[ -f "${ROOT_DIR}/target/release/open_table_relay" ]]; then
    cp -f "${ROOT_DIR}/target/release/open_table_relay" "${LINUX_PKG_DIR}/bin/"
fi

if [[ -f "${ROOT_DIR}/target/x86_64-pc-windows-gnu/release/open_table_godot.dll" ]]; then
    cp -f "${ROOT_DIR}/target/x86_64-pc-windows-gnu/release/open_table_godot.dll" "${WINDOWS_PKG_DIR}/bin/"
elif [[ -f "${ROOT_DIR}/target/x86_64-pc-windows-msvc/release/open_table_godot.dll" ]]; then
    cp -f "${ROOT_DIR}/target/x86_64-pc-windows-msvc/release/open_table_godot.dll" "${WINDOWS_PKG_DIR}/bin/"
fi

if [[ -d "${ROOT_DIR}/godot_project/addons/open_table" ]]; then
    cp -r "${ROOT_DIR}/godot_project/addons/open_table" "${LINUX_PKG_DIR}/addons/"
    cp -r "${ROOT_DIR}/godot_project/addons/open_table" "${WINDOWS_PKG_DIR}/addons/"
fi

if [[ -d "${ROOT_DIR}/godot_project/assets" ]]; then
    cp -r "${ROOT_DIR}/godot_project/assets/." "${LINUX_PKG_DIR}/assets/"
    cp -r "${ROOT_DIR}/godot_project/assets/." "${WINDOWS_PKG_DIR}/assets/"
fi

cp -f "${ROOT_DIR}/README.md" "${ROOT_DIR}/LICENSE" "${ROOT_DIR}/THIRD_PARTY_LICENSES.md" "${LINUX_PKG_DIR}/"
cp -f "${ROOT_DIR}/README.md" "${ROOT_DIR}/LICENSE" "${ROOT_DIR}/THIRD_PARTY_LICENSES.md" "${WINDOWS_PKG_DIR}/"

echo "=== [4/5] Exportando proyecto Godot/Redot (si el binario está disponible) ==="
if command -v "${REDOT_BIN}" >/dev/null 2>&1; then
    "${REDOT_BIN}" --headless --path "${ROOT_DIR}/godot_project" --export-release "Linux/X11" "${LINUX_PKG_DIR}/opentable.x86_64" || \
        echo "Aviso: plantilla de exportación Linux/X11 omitida en entorno actual."
    "${REDOT_BIN}" --headless --path "${ROOT_DIR}/godot_project" --export-release "Windows Desktop" "${WINDOWS_PKG_DIR}/opentable.exe" || \
        echo "Aviso: plantilla de exportación Windows Desktop omitida en entorno actual."
else
    echo "Aviso: ${REDOT_BIN} no encontrado en PATH; empaquetando librerías, addon y assets."
fi

echo "=== [5/5] Empaquetando archivos (.tar.gz / .zip) y generando SHA256SUMS.txt ==="
cd "${DIST_DIR}"
tar -czf "opentable-linux-x86_64.tar.gz" "opentable-linux-x86_64"

if command -v zip >/dev/null 2>&1; then
    zip -rq "opentable-windows-x86_64.zip" "opentable-windows-x86_64"
else
    tar -czf "opentable-windows-x86_64.zip" "opentable-windows-x86_64"
fi

sha256sum opentable-linux-x86_64.tar.gz opentable-windows-x86_64.zip > "${DIST_DIR}/SHA256SUMS.txt"
echo "Sumas de verificación generadas en ${DIST_DIR}/SHA256SUMS.txt:"
cat "${DIST_DIR}/SHA256SUMS.txt"
echo "=== Empaquetado finalizado exitosamente ==="
