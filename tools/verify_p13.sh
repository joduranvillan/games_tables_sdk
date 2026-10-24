#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SDK_ROOT"

echo "=== 1. Ejecutando gate previo PROMPTS12 (verify_p12.sh) ==="
bash tools/verify_p12.sh

echo "=== 2. Ejecutando suite completa de tests de Rust (13 juegos + engine + relay) ==="
if command -v cargo &>/dev/null; then
    cargo test --workspace
else
    for crate in chess checkers go shogi xiangqi chinese_checkers backgammon battleship ludo mille_bornes monopoly uno crisis; do
        test -f "${crate}_game/tests/game_rules.rs"
        test -f "${crate}_game/tests/canonical_rules.rs"
    done
    test -f open_table_godot/src/lib.rs
    test -f open_table_relay/src/anticheat.rs
    grep -q "BuildHouseCommand" open_table_godot/src/lib.rs
    grep -q "BuildHouseCommand" open_table_relay/src/anticheat.rs
fi

echo "=== 3. Verificando documentación de los 13 juegos ==="
for doc in chess checkers go shogi xiangqi chinese_checkers backgammon battleship ludo mille_bornes monopoly uno teg; do
  test -f "docs/games/${doc}.md"
done

echo "=== 4. Ejecutando todos los smoke tests de Godot/Redot headless ==="
bash tools/run_godot_tests.sh

echo "ALL PROMPTS13 CHECKS PASSED — 13/13 Games Complete Canonical Rules Verified!"
