#!/usr/bin/env bash
# ==============================================================================
# OpenTable SDK — Web Client (React + TypeScript + WASM) Functional Verification
# Certifica:
#   1. Documentación de Uso y Desarrollo Web (Markdown + mdBook)
#   2. Chequeo estático de tipos TypeScript (tsc --noEmit)
#   3. Suites de pruebas automatizadas en Vitest (14 juegos + Fases 1-5 + Diagnóstico E2E)
#   4. Build de producción del bundle PWA (vite build + Service Worker + Manifest)
# ==============================================================================
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$SDK_ROOT/web_client"

echo "=== [1/4] Verificando documentación de uso y desarrollo Web (React + WASM) ==="
test -f "$SDK_ROOT/docs/WEB_USER_GUIDE.md"
test -f "$SDK_ROOT/docs/WEB_REACT_DEVELOPER_GUIDE.md"
test -f "$SDK_ROOT/docs/src/web_user_guide.md"
test -f "$SDK_ROOT/docs/src/web_react_developer_guide.md"
test -f "$WEB_DIR/README.md"
grep -q "web_user_guide.md" "$SDK_ROOT/docs/src/SUMMARY.md"
grep -q "web_react_developer_guide.md" "$SDK_ROOT/docs/src/SUMMARY.md"
echo "OK: Documentación de uso y desarrollo verificada."

echo "=== [2/4] Verificando tipado estático TypeScript (tsc --noEmit) ==="
cd "$WEB_DIR"
npx tsc --noEmit
echo "OK: 0 errores de tipos en TypeScript."

echo "=== [3/4] Ejecutando las suites de pruebas Vitest (14 Juegos + Fases 1-5 + Autodiagnóstico E2E) ==="
npm test
echo "OK: Todas las suites de pruebas pasaron al 100%."

echo "=== [4/4] Compilando y verificando el bundle PWA de producción (Vite) ==="
npm run build
test -f "$WEB_DIR/dist/index.html"
test -f "$WEB_DIR/dist/manifest.webmanifest"
test -f "$WEB_DIR/dist/sw.js"
echo "OK: Bundle PWA de producción generado y verificado en web_client/dist/."

echo "=============================================================================="
echo "ALL WEB CLIENT (REACT + WASM 14 GAMES) CHECKS PASSED — 100% FUNCTIONAL!"
echo "=============================================================================="
