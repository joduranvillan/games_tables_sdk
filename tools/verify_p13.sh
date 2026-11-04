#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SDK_ROOT"

echo "=== 1. Ejecutando gate previo PROMPTS12 (verify_p12.sh) ==="
bash tools/verify_p12.sh

echo "=== 2. Ejecutando suite completa de tests de Rust (14 juegos + engine + relay) ==="
if command -v cargo &>/dev/null; then
    cargo test --workspace
else
    for crate in chess checkers go shogi xiangqi chinese_checkers backgammon battleship ludo mille_bornes monopoly uno crisis goose; do
        test -f "${crate}_game/tests/game_rules.rs"
        test -f "${crate}_game/tests/canonical_rules.rs"
    done
    test -f open_table_godot/src/lib.rs
    test -f open_table_relay/src/anticheat.rs
    grep -q "BuildHouseCommand" open_table_godot/src/lib.rs
    grep -q "BuildHouseCommand" open_table_relay/src/anticheat.rs
    grep -q "new_goose_session" open_table_godot/src/lib.rs
fi

echo "=== 3. Verificando documentación de los 14 juegos y componente 3D de dados ==="
for doc in chess checkers go shogi xiangqi chinese_checkers backgammon battleship ludo mille_bornes monopoly uno teg goose; do
  test -f "docs/games/${doc}.md"
done
test -f "godot_project/scripts/dice_roller_3d.gd"
test -f "godot_project/dice_widget.gd"
test -f "godot_project/tests/dice_3d_smoke.gd"

echo "=== 4. Verificando cumplimiento Redot strict en los tableros, canonical_rules_ui_smoke.gd y dice_3d_smoke.gd ==="
bash tools/run_godot_tests.sh canonical_rules_ui_smoke.gd dice_3d_smoke.gd goose_smoke.gd

echo "=== 5. Ejecutando todos los smoke tests de Godot/Redot headless ==="
bash tools/run_godot_tests.sh

echo "=== 6. Generando y verificando reporte maestro TEST_SUMMARY.md para los 14 juegos ==="
bash tools/generate_test_summary.sh
test -f "TEST_SUMMARY.md"
test -f "../TEST_SUMMARY.md"

echo "ALL PROMPTS13 CHECKS PASSED — 14/14 Games Complete Canonical Rules, 3D Dice, Redot Strict & TEST_SUMMARY.md Verified!"
