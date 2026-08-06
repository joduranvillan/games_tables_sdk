#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.cargo/bin:/root/.cargo/bin:/usr/local/cargo/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "==> 1. Verificando que no haya cambios sin commitear..."
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: Hay cambios locales no commiteados. Commitea o guarda tus cambios antes de lanzar el release." >&2
    git status --short
    exit 1
fi

BUMP_ARG="${1:---patch}"
echo "==> 2. Incrementando versión ($BUMP_ARG)..."
"$SCRIPT_DIR/bump_version.sh" "$BUMP_ARG"

CORE_CARGO="$ROOT_DIR/open_table_core/Cargo.toml"
NEW_VER=$(grep -m1 '^version = ' "$CORE_CARGO" | sed -E 's/version = "(.*)"/\1/')

if [ -z "$NEW_VER" ]; then
    echo "Error: No se pudo determinar la nueva versión." >&2
    exit 1
fi

echo "==> 3. Ejecutando suite de pruebas del workspace..."
cargo test --workspace --exclude open_table_godot

echo "==> 4. Commiteando cambios de versión y creando tag de Git v${NEW_VER}..."
git commit -am "Release v${NEW_VER}"
git tag -a "v${NEW_VER}" -m "Release v${NEW_VER}"

echo ""
echo "=========================================================="
echo " Release v${NEW_VER} preparado exitosamente."
echo "=========================================================="
echo "IMPORTANTE: Este script NO realiza push ni publica en crates.io automáticamente."
echo ""
echo "Para completar la publicación de forma manual:"
echo "  1. Subir cambios y tags a GitHub:"
echo "     git push origin main --tags"
echo "  2. Publicar crate principal en Crates.io:"
echo "     cargo publish -p open_table_core"
echo "=========================================================="
