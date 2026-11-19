#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.cargo/bin:/root/.cargo/bin:/usr/local/cargo/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BUMP_TYPE="patch"
EXPLICIT_VER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --major)
            BUMP_TYPE="major"
            shift
            ;;
        --minor)
            BUMP_TYPE="minor"
            shift
            ;;
        --patch)
            BUMP_TYPE="patch"
            shift
            ;;
        --sync)
            BUMP_TYPE="sync"
            shift
            ;;
        --set)
            BUMP_TYPE="set"
            EXPLICIT_VER="${2:-}"
            shift 2 || shift
            ;;
        *)
            shift
            ;;
    esac
done

CORE_CARGO="$ROOT_DIR/open_table_core/Cargo.toml"

if [ ! -f "$CORE_CARGO" ]; then
    echo "Error: $CORE_CARGO no fue encontrado." >&2
    exit 1
fi

CURRENT_VER=$(grep -m1 '^version = ' "$CORE_CARGO" | sed -E 's/version = "(.*)"/\1/')

if [ -z "$CURRENT_VER" ]; then
    echo "Error: No se pudo leer la versión de $CORE_CARGO" >&2
    exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VER"

case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        NEW_VER="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        NEW_VER="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    patch)
        PATCH=$((PATCH + 1))
        NEW_VER="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    sync)
        NEW_VER="$CURRENT_VER"
        ;;
    set)
        if [ -z "$EXPLICIT_VER" ]; then
            echo "Error: --set requiere especificar una versión (ej. --set 1.1.0)." >&2
            exit 1
        fi
        NEW_VER="$EXPLICIT_VER"
        ;;
esac

echo "Sincronizando versión de $CURRENT_VER a $NEW_VER ($BUMP_TYPE)..."

find "$ROOT_DIR" -name "Cargo.toml" -not -path "*/target/*" | while read -r cargo_file; do
    sed -i -E "s/^version = \"[0-9]+\.[0-9]+\.[0-9]+\"/version = \"$NEW_VER\"/" "$cargo_file"
    sed -i -E "/path = \"\.\.\//s/version = \"[0-9]+\.[0-9]+\.[0-9]+\"/version = \"$NEW_VER\"/g" "$cargo_file"
done

echo "Todos los archivos Cargo.toml ([package] y dependencias path internas) actualizados a versión $NEW_VER."

if command -v cargo >/dev/null 2>&1; then
    echo "Verificando el workspace con cargo check..."
    (cd "$ROOT_DIR" && cargo check --workspace)
else
    echo "Aviso: 'cargo' no está presente en el PATH de este shell; omitiendo 'cargo check'."
fi

echo "Sincronización de versión a $NEW_VER completada exitosamente."
