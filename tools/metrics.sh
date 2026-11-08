#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== INICIANDO METRICAS DE CALIDAD DEL CODIGO ==="

FAILED=0

echo "[1/5] Verificando clippy warnings en el workspace..."
if command -v cargo &>/dev/null; then
    CLIPPY_WARNINGS=$(cargo clippy --workspace --exclude open_table_godot 2>&1 | grep "warning:" | wc -l || true)
    echo "Clippy warnings encontrados: $CLIPPY_WARNINGS"
    if [ "$CLIPPY_WARNINGS" -gt 0 ]; then
        echo "ERROR: Se encontraron $CLIPPY_WARNINGS warnings de Clippy."
        FAILED=1
    fi

    echo "[2/5] Verificando formato de código con cargo fmt..."
    if ! cargo fmt --all --check; then
        echo "ERROR: Falló la verificación de formato cargo fmt."
        FAILED=1
    fi

    echo "[3/5] Verificando warnings de documentación en cargo doc..."
    DOC_WARNINGS=$(cargo doc --workspace --no-deps --exclude open_table_godot 2>&1 | grep "warning:" | wc -l || true)
    echo "Cargo doc warnings encontrados: $DOC_WARNINGS"
    if [ "$DOC_WARNINGS" -gt 0 ]; then
        echo "ERROR: Se encontraron $DOC_WARNINGS warnings de documentación."
        FAILED=1
    fi
else
    echo "Aviso: cargo no detectado en PATH; omitiendo checks [1/5]-[3/5] de compilador Rust en este entorno."
fi

echo "[4/5] Conteo de // TODO: en el código fuente..."
TODO_COUNT=$(grep -r "// TODO:" --include="*.rs" --include="*.gd" . | wc -l || true)
echo "Total de // TODO: encontrados: $TODO_COUNT"

echo "[5/5] Verificando tipado explícito Redot strict y paridad de tableros GDScript..."
if ! bash "$SCRIPT_DIR/run_godot_tests.sh" canonical_rules_ui_smoke.gd; then
    echo "ERROR: Falló la validación Redot strict / canonical_rules_ui_smoke.gd."
    FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
    echo "=== METRICAS DE CALIDAD: FALLIDO ==="
    exit 1
else
    echo "=== METRICAS DE CALIDAD: COMPLETADO EXITOSAMENTE ==="
    exit 0
fi
