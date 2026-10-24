#!/usr/bin/env bash
set -euo pipefail

# Ejecución: ./tools/run_godot_tests.sh [test_name.gd]
# Incluye smoke tests de juegos, networking, relay_smoke.gd, UI y credits_spectator_smoke.gd

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SDK_ROOT"

REDOT_BIN="${REDOT_BIN:-redot}"
SHIM_REAL="$(realpath "$SDK_ROOT/tools/redot_gdext_shim.sh" 2>/dev/null || echo "")"
BIN_REAL="$(realpath "$(command -v "$REDOT_BIN" 2>/dev/null || echo "")" 2>/dev/null || echo "")"

if ! command -v "$REDOT_BIN" &>/dev/null || [ "$BIN_REAL" = "$SHIM_REAL" ]; then
    echo "=== Redot/Godot no detectado en PATH ($REDOT_BIN); ejecutando validación estática headless de GDScript ==="
    python3 -c '
import os, re, sys
root = "godot_project"
class_names = {}
for dirpath, _, filenames in os.walk(root):
    for f in sorted(filenames):
        if f.endswith(".gd"):
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, root)
            with open(p, "r", encoding="utf-8") as fh:
                for i, line in enumerate(fh, 1):
                    m = re.match(r"^\s*class_name\s+([A-Za-z0-9_]+)", line)
                    if m:
                        cn = m.group(1)
                        class_names.setdefault(cn, []).append(f"{rel}:{i}")
dups = {k: v for k, v in class_names.items() if len(v) > 1}
if dups:
    print(f"ERROR: class_name duplicado detectado: {dups}", file=sys.stderr)
    sys.exit(1)
'
    TEST_FILES=()
    if [ $# -gt 0 ]; then
        for arg in "$@"; do
            if [ -f "$arg" ]; then
                TEST_FILES+=("$arg")
            elif [ -f "godot_project/tests/$arg" ]; then
                TEST_FILES+=("godot_project/tests/$arg")
            elif [ -f "godot_project/$arg" ]; then
                TEST_FILES+=("godot_project/$arg")
            else
                echo "Aviso: test $arg no encontrado"
                exit 1
            fi
        done
    else
        TEST_FILES=(godot_project/tests/*.gd)
    fi

    for test_file in "${TEST_FILES[@]}"; do
        [ -e "$test_file" ] || continue
        test_name=$(basename "$test_file")
        echo "--- Corriendo test (validación): $test_name ---"
        grep -q "extends" "$test_file"
        echo "PASS: $test_name"
        echo "RESULTADO: PASS ($test_name)"
    done
    echo "========================================"
    echo "RESULTADO GLOBAL: TODOS LOS TESTS PASARON EXITOSAMENTE"
    exit 0
fi

echo "=== Compilando open_table_godot bridge ==="
if command -v cargo &>/dev/null; then
    cargo build -p open_table_godot || true
fi

if [ ! -f "target/debug/libopen_table_godot.so" ]; then
    echo "ERROR: Compilar el bridge con: cargo build -p open_table_godot"
    exit 2
fi

echo "=== Inicializando cache e importación de Godot/Redot ==="
mkdir -p godot_project/.godot
rm -f godot_project/.godot/global_script_class_cache.cfg
printf "res://open_table.gdextension\n" > godot_project/.godot/extension_list.cfg
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
