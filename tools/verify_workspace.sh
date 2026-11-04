#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== VERIFICANDO CONSISTENCIA DEL WORKSPACE ==="

FAILED=0

# (a) Verifica que todos los miembros del workspace de Cargo.toml existen
echo "[1/4] Verificando existencia de directorios de workspace.members..."
MEMBERS=$(sed -n '/members = \[/,/\]/p' Cargo.toml | grep -v 'members = \[' | grep -v '\]' | tr -d '", ' | grep -v '^$')

for member in $MEMBERS; do
    if [ ! -d "$member" ]; then
        echo "ERROR: El directorio '$member' listado en Cargo.toml no existe."
        FAILED=1
    else
        echo "  [OK] Directory $member"
    fi
done

# Lista de juegos del SDK
GAMES=(
    "checkers_game"
    "battleship_game"
    "ludo_game"
    "mille_bornes_game"
    "backgammon_game"
    "chinese_checkers_game"
    "monopoly_game"
    "chess_game"
    "shogi_game"
    "xiangqi_game"
    "go_game"
    "uno_game"
    "crisis_game"
    "goose_game"
)

# (b) Verifica que los juegos exportan new_{game}_session y se referencian en open_table_godot/src/lib.rs
echo "[2/4] Verificando exports new_{game}_session y referencias en open_table_godot/src/lib.rs..."
LIB_RS="open_table_godot/src/lib.rs"

for game in "${GAMES[@]}"; do
    clean_name="${game%_game}"
    func_name="new_${clean_name}_session"
    
    # Verificar en el propio crate
    if ! grep -rq "$func_name" "$game/src"; then
        echo "ERROR: $game no exporta $func_name en src/"
        FAILED=1
    else
        echo "  [OK] Function $func_name found in $game"
    fi

    # Verificar en open_table_godot/src/lib.rs
    if ! grep -q "$func_name" "$LIB_RS"; then
        echo "ERROR: $func_name no está referenciada en $LIB_RS"
        FAILED=1
    else
        echo "  [OK] Reference $func_name found in $LIB_RS"
    fi
done

# (c) Verifica que cada juego tiene tests/game_rules.rs o tests/
echo "[3/4] Verificando archivos de tests en cada juego..."
for game in "${GAMES[@]}"; do
    if [ ! -f "$game/tests/game_rules.rs" ] && [ ! -d "$game/tests" ]; then
        echo "ERROR: $game no tiene tests/game_rules.rs ni directorio tests/"
        FAILED=1
    else
        echo "  [OK] Test structure present for $game"
    fi
done

# (d) Verifica que NEXT_STEPS.md menciona todos los juegos
echo "[4/4] Verificando mención de todos los juegos en NEXT_STEPS.md..."
NEXT_STEPS="NEXT_STEPS.md"
for game in "${GAMES[@]}"; do
    if ! grep -q "$game" "$NEXT_STEPS"; then
        echo "ERROR: $game no está mencionado en $NEXT_STEPS"
        FAILED=1
    else
        echo "  [OK] $game mentioned in $NEXT_STEPS"
    fi
done

if [ "$FAILED" -ne 0 ]; then
    echo "=== VERIFICACION DE WORKSPACE: FALLIDA ==="
    exit 1
else
    echo "=== VERIFICACION DE WORKSPACE: EXITOSA ==="
    exit 0
fi
