#!/usr/bin/env bash
set -euo pipefail

# Ejecución: ./tools/run_godot_tests.sh [test_name.gd]
# Incluye smoke tests de juegos, networking, UI y credits_spectator_smoke.gd

REDOT_BIN="${REDOT_BIN:-redot}"

echo "=== Compilando open_table_godot bridge ==="
if command -v cargo &>/dev/null; then
    cargo build -p open_table_godot || true
fi

if [ ! -f "target/debug/libopen_table_godot.so" ]; then
    echo "ERROR: Compilar el bridge con: cargo build -p open_table_godot"
    exit 2
fi

echo "=== Inicializando cache e importación de Godot/Redot ==="
"$REDOT_BIN" --headless --path godot_project --editor --quit &>/dev/null || true

echo ""
echo "=== Ejecutando tests headless de Godot ==="

PASSED_TESTS=()
FAILED_TESTS=()
OVERALL_FAILED=0

TEST_FILES=()
if [ $# -gt 0 ]; then
    for arg in "$@"; do
        if [ -f "$arg" ]; then
            TEST_FILES+=("$arg")
        elif [ -f "godot_project/tests/$arg" ]; then
            TEST_FILES+=("godot_project/tests/$arg")
        else
            echo "Aviso: test $arg no encontrado"
        fi
    done
else
    TEST_FILES=(godot_project/tests/*.gd)
fi

for test_file in "${TEST_FILES[@]}"; do
    [ -e "$test_file" ] || continue
    test_name=$(basename "$test_file")
    echo "--- Corriendo test: $test_name ---"
    
    TIMEOUT_CMD=""
    if command -v timeout &>/dev/null; then
        TIMEOUT_CMD="timeout 30s"
    fi

    if output=$($TIMEOUT_CMD "$REDOT_BIN" --headless --path godot_project --script "res://tests/$test_name" 2>&1); then
        echo "$output"
        if echo "$output" | grep -q "HAY FALLOS"; then
            echo "RESULTADO: FAIL ($test_name)"
            FAILED_TESTS+=("$test_name")
            OVERALL_FAILED=1
        else
            echo "RESULTADO: PASS ($test_name)"
            PASSED_TESTS+=("$test_name")
        fi
    else
        echo "$output"
        echo "RESULTADO: FAIL ($test_name)"
        FAILED_TESTS+=("$test_name")
        OVERALL_FAILED=1
    fi
    echo ""
done

echo "========================================"
echo "RESUMEN DE TESTS HEADLESS GODOT:"
echo "========================================"
for t in "${PASSED_TESTS[@]}"; do
    echo "  [PASS] $t"
done
for t in "${FAILED_TESTS[@]}"; do
    echo "  [FAIL] $t"
done
echo "========================================"

if [ $OVERALL_FAILED -ne 0 ]; then
    echo "RESULTADO GLOBAL: FALLO AL MENOS UN TEST"
    exit 1
else
    echo "RESULTADO GLOBAL: TODOS LOS TESTS PASARON EXITOSAMENTE"
    exit 0
fi
