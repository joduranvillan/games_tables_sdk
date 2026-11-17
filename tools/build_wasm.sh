#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WASM_CRATE="$SDK_ROOT/open_table_wasm"
OUT_DIR="$SDK_ROOT/web_client/src/wasm_pkg"

mkdir -p "$OUT_DIR"

echo "=== Compilando open_table_wasm a WebAssembly ==="
if command -v wasm-pack &>/dev/null; then
  wasm-pack build "$WASM_CRATE" --target web --out-dir "$OUT_DIR" --out-name open_table_wasm
  echo "✅ Binario WebAssembly generado en $OUT_DIR con wasm-pack"
elif command -v cargo &>/dev/null && rustup target list --installed 2>/dev/null | grep -q "wasm32-unknown-unknown"; then
  cargo build --manifest-path "$WASM_CRATE/Cargo.toml" --target wasm32-unknown-unknown --release
  if command -v wasm-bindgen &>/dev/null; then
    wasm-bindgen "$WASM_CRATE/target/wasm32-unknown-unknown/release/open_table_wasm.wasm" \
      --out-dir "$OUT_DIR" --target web --out-name open_table_wasm
    echo "✅ Binario WebAssembly y bindings generados en $OUT_DIR con wasm-bindgen"
  else
    cp -f "$WASM_CRATE/target/wasm32-unknown-unknown/release/open_table_wasm.wasm" "$OUT_DIR/open_table_wasm_bg.wasm"
    echo "✅ Binario WebAssembly copiado a $OUT_DIR/open_table_wasm_bg.wasm"
  fi
else
  echo "ℹ️ Toolchain wasm32-unknown-unknown no detectada en este entorno; web_client utilizará el puente determinista compatible en $OUT_DIR/index.ts"
fi
