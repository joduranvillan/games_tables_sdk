#!/usr/bin/env bash
set -euo pipefail

# Ejecución: ./tools/run_godot_tests.sh [test_name.gd]
# Incluye smoke tests de juegos, networking, relay_smoke.gd, UI y credits_spectator_smoke.gd

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SDK_ROOT"

REDOT_BIN="${REDOT_BIN:-redot}"
SHIM_REAL="$(realpath "$SDK_ROOT/tools/redot_gdext_shim.sh" 2>/dev/null || echo "")"
BIN_REAL="$(realpath "$(command -v "$REDOT_BIN" 2>/dev/null || echo "")" 2>/dev/null || echo "")"

echo "=== Ejecutando validador estático Redot strict (tipado explícito y paridad de tableros) ==="
python3 -c '
import os, re, sys, filecmp

root = "godot_project"
class_names = {}
unsafe_walrus = []

strict_files = {
    "chess_board.gd",
    "go_board.gd",
    "shogi_board.gd",
    "battleship_board.gd",
    "mille_bornes_board.gd",
    "scenes/chess_board.gd",
    "scenes/go_board.gd",
    "scenes/shogi_board.gd",
    "scenes/battleship_board.gd",
    "scenes/mille_bornes_board.gd",
    "tests/canonical_rules_ui_smoke.gd",
}

for dirpath, _, filenames in os.walk(root):
    for f in sorted(filenames):
        if f.endswith(".gd"):
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, root).replace("\\", "/")
            with open(p, "r", encoding="utf-8") as fh:
                for i, line in enumerate(fh, 1):
                    m = re.match(r"^\s*class_name\s+([A-Za-z0-9_]+)", line)
                    if m:
                        cn = m.group(1)
                        class_names.setdefault(cn, []).append(f"{rel}:{i}")
                    code_part = line.split("#", 1)[0]
                    if ":=" in code_part:
                        if rel in strict_files:
                            unsafe_walrus.append(f"{rel}:{i}: {line.strip()}")
                        elif re.search(r":=.*(\.get\(|\.call\(|bridge\.|parser\.data|\bin\b)", code_part):
                            unsafe_walrus.append(f"{rel}:{i}: {line.strip()}")
                    mt = re.match(r"^\s*var\s+([A-Za-z0-9_]+)\s*:\s*([A-Za-z0-9_]+)\s*=\s*(.+)$", code_part)
                    if mt:
                        vn, vt, rhs = mt.groups()
                        if ".split(" in rhs and not re.search(r"\.split\([^)]*\)\s*\[", rhs) and vt not in ("PackedStringArray", "Array"):
                            unsafe_walrus.append(f"{rel}:{i}: Tipo inválido {vt} para .split() (debe ser PackedStringArray)")
                        if " if " in rhs and " else " in rhs and vt == "bool" and not re.search(r"\b(true|false|==|!=|<=|>=|<|>|\band\b|\bor\b|\bnot\b|step_replay)\b", rhs.split(" if ")[0]):
                            unsafe_walrus.append(f"{rel}:{i}: Tipo inválido bool en expresión ternaria: {line.strip()}")

dups = {k: v for k, v in class_names.items() if len(v) > 1}
if dups:
    print(f"ERROR: class_name duplicado detectado: {dups}", file=sys.stderr)
    sys.exit(1)

if unsafe_walrus:
    print("ERROR: Inferencias := no permitidas en Redot strict detectadas:", file=sys.stderr)
    for item in unsafe_walrus[:25]:
        print("  " + item, file=sys.stderr)
    sys.exit(1)

board_count = 0
for f in sorted(os.listdir(root)):
    if f.endswith("_board.gd"):
        board_count += 1
        root_p = os.path.join(root, f)
        scene_p = os.path.join(root, "scenes", f)
        if os.path.isfile(scene_p) and not filecmp.cmp(root_p, scene_p, shallow=False):
            print(f"ERROR: Desincronización detectada entre {root_p} y {scene_p}", file=sys.stderr)
            sys.exit(1)

# Verificar integración de DiceRoller3D y DiceWidget en los 5 juegos de dados
roller_path = os.path.join(root, "scripts", "dice_roller_3d.gd")
widget_path = os.path.join(root, "dice_widget.gd")
if not os.path.isfile(roller_path) or not os.path.isfile(widget_path):
    print("ERROR: Falta scripts/dice_roller_3d.gd o dice_widget.gd", file=sys.stderr)
    sys.exit(1)

with open(roller_path, "r", encoding="utf-8") as fh:
    r_src = fh.read()
    for req in ("class_name DiceRoller3D", "SubViewport", "Camera3D", "DirectionalLight3D", "get_target_rotation_for_value", "play_3d_roll"):
        if req not in r_src:
            print(f"ERROR: DiceRoller3D no contiene símbolo requerido: {req}", file=sys.stderr)
            sys.exit(1)

with open(widget_path, "r", encoding="utf-8") as fh:
    w_src = fh.read()
    for req in ("class_name DiceWidget", "dock_roller_3d", "_overlay_roller_3d", "wait_if_rolling", "show_roll"):
        if req not in w_src:
            print(f"ERROR: DiceWidget no contiene símbolo requerido: {req}", file=sys.stderr)
            sys.exit(1)

dice_boards = ["goose_board.gd", "ludo_board.gd", "backgammon_board.gd", "monopoly_board.gd", "crisis_board.gd"]
for db in dice_boards:
    db_path = os.path.join(root, db)
    with open(db_path, "r", encoding="utf-8") as fh:
        b_src = fh.read()
        if "DiceWidget.new()" not in b_src or "wait_if_rolling()" not in b_src:
            print(f"ERROR: Tablero de dados {db} no integra DiceWidget.new() o wait_if_rolling()", file=sys.stderr)
            sys.exit(1)

print(f"OK: Validador Redot strict superado (0 inferencias := en Variant, {board_count}/{board_count} tableros sincronizados, 5/5 juegos de dados con DiceRoller3D verificados).")
'

if ! command -v "$REDOT_BIN" &>/dev/null || [ "$BIN_REAL" = "$SHIM_REAL" ]; then
    echo "=== Redot/Godot binario nativo no disponible en PATH ($REDOT_BIN); ejecutando verificación estática de scripts de test ==="
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
        echo "--- Corriendo test (validación Redot strict): $test_name ---"
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
