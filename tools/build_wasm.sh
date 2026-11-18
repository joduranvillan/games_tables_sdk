#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Compilando open_table_wasm (14 Motores Rust -> WebAssembly) ==="

if command -v wasm-pack >/dev/null 2>&1; then
  wasm-pack build open_table_wasm \
    --target web \
    --release \
    --out-dir ../web_client/public/wasm_pkg
  echo "OK: Binario WebAssembly generado en web_client/public/wasm_pkg/"
elif command -v cargo >/dev/null 2>&1; then
  echo "wasm-pack no encontrado; compilando target wasm32-unknown-unknown con cargo..."
  cargo build --manifest-path open_table_wasm/Cargo.toml --target wasm32-unknown-unknown --release
  echo "OK: Binario wasm32-unknown-unknown compilado."
else
  echo "INFO: Toolchain Rust/wasm-pack no instalado en este entorno contenedor; web_client utilizará el validador canónico 1:1 en web_client/src/wasm_pkg/index.ts."
fi
