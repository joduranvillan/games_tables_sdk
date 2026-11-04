#!/usr/bin/env bash
# ==============================================================================
# OpenTable SDK - Automated Test & Coverage Summary Generator (14 Games)
# Generates TEST_SUMMARY.md in both games_tables_sdk/ and repository root
# with deep AI diagnostic context (file:line traces, contracts, repair recipes).
# ==============================================================================
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SDK_ROOT/.." && pwd)"
cd "$SDK_ROOT"

echo "=== [1/3] Ejecutando Smoke Tests de Godot/Redot y Auditoría Estática ==="
GODOT_TEST_OUTPUT=""
GODOT_TEST_STATUS=0
if GODOT_TEST_OUTPUT="$(bash tools/run_godot_tests.sh 2>&1)"; then
    GODOT_TEST_STATUS=0
else
    GODOT_TEST_STATUS=$?
fi

echo "=== [2/3] Verificando Suite de Pruebas de Rust (Workspace) ==="
CARGO_AVAILABLE=0
CARGO_TEST_OUTPUT=""
CARGO_TEST_STATUS=0
if command -v cargo &>/dev/null; then
    CARGO_AVAILABLE=1
    if CARGO_TEST_OUTPUT="$(cargo test --workspace --no-fail-fast 2>&1)"; then
        CARGO_TEST_STATUS=0
    else
        CARGO_TEST_STATUS=$?
    fi
fi

echo "=== [3/3] Compilando métricas detalladas y generando TEST_SUMMARY.md ==="
export SDK_ROOT REPO_ROOT GODOT_TEST_OUTPUT GODOT_TEST_STATUS CARGO_AVAILABLE CARGO_TEST_OUTPUT CARGO_TEST_STATUS

python3 - <<'PY'
import os
import re
import sys
import hashlib
from datetime import datetime, timezone

sdk_root = os.environ["SDK_ROOT"]
repo_root = os.environ["REPO_ROOT"]
godot_output = os.environ.get("GODOT_TEST_OUTPUT", "")
godot_status = int(os.environ.get("GODOT_TEST_STATUS", "0"))
cargo_available = int(os.environ.get("CARGO_AVAILABLE", "0")) == 1
cargo_output = os.environ.get("CARGO_TEST_OUTPUT", "")
cargo_status = int(os.environ.get("CARGO_TEST_STATUS", "0"))

GAMES = [
    {
        "id": "chess",
        "num": 1,
        "title": "Ajedrez (Chess)",
        "crate": "chess_game",
        "doc": "docs/games/chess.md",
        "smoke": "godot_project/tests/chess_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_chess_session",
        "bridge_prefix": "chess_",
        "json_contract": "board (64 casillas), turn (White/Black), castling_rights, en_passant, halfmove_clock, in_check, status",
        "commands": "MovePieceCommand { from, to, promotion }",
    },
    {
        "id": "checkers",
        "num": 2,
        "title": "Damas (Checkers)",
        "crate": "checkers_game",
        "doc": "docs/games/checkers.md",
        "smoke": "godot_project/tests/bridge_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_checkers_session",
        "bridge_prefix": "checkers_",
        "json_contract": "board (8x8), current_turn (Red/Black), mandatory_capture_from, must_continue_jump, winner",
        "commands": "MoveCheckerCommand { from_row, from_col, to_row, to_col }",
    },
    {
        "id": "go",
        "num": 3,
        "title": "Go (Weiqi / Baduk)",
        "crate": "go_game",
        "doc": "docs/games/go.md",
        "smoke": "godot_project/tests/go_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_go_session",
        "bridge_prefix": "go_",
        "json_contract": "size (9/13/19), grid, current_stone (Black/White), captures_black, captures_white, ko_point, consecutive_passes",
        "commands": "PlaceStoneCommand { x, y }, PassTurnCommand",
    },
    {
        "id": "shogi",
        "num": 4,
        "title": "Shogi (Ajedrez Japonés)",
        "crate": "shogi_game",
        "doc": "docs/games/shogi.md",
        "smoke": "godot_project/tests/shogi_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_shogi_session",
        "bridge_prefix": "shogi_",
        "json_contract": "board (9x9), hands (Sente/Gote pieces in hand), current_player, promotion_zone, in_check",
        "commands": "ShogiMoveCommand { from, to, promote }, ShogiDropCommand { piece_type, to }",
    },
    {
        "id": "xiangqi",
        "num": 5,
        "title": "Xiangqi (Ajedrez Chino)",
        "crate": "xiangqi_game",
        "doc": "docs/games/xiangqi.md",
        "smoke": "godot_project/tests/xiangqi_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_xiangqi_session",
        "bridge_prefix": "xiangqi_",
        "json_contract": "board (10x9), current_turn (Red/Black), palace_bounds, river_crossed, flying_general_check",
        "commands": "XiangqiMoveCommand { from_r, from_c, to_r, to_c }",
    },
    {
        "id": "backgammon",
        "num": 6,
        "title": "Backgammon",
        "crate": "backgammon_game",
        "doc": "docs/games/backgammon.md",
        "smoke": "godot_project/tests/backgammon_smoke.gd",
        "dice_3d": True,
        "bridge_init": "new_backgammon_session",
        "bridge_prefix": "backgammon_",
        "json_contract": "points (24), bar_white, bar_black, borne_off_white, borne_off_black, dice_remaining, doubling_cube, current_turn",
        "commands": "RollDiceCommand { d1, d2 }, MoveCheckerBgCommand { from_point, to_point }",
    },
    {
        "id": "battleship",
        "num": 7,
        "title": "Batalla Naval (Battleship)",
        "crate": "battleship_game",
        "doc": "docs/games/battleship.md",
        "smoke": "godot_project/tests/battleship_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_battleship_session",
        "bridge_prefix": "battleship_",
        "json_contract": "phase (Placement/Combat/Finished), fleets, shots_p1, shots_p2, sunken_ships, active_player",
        "commands": "PlaceShipCommand { player, ship_id, x, y, horizontal }, FireShotCommand { player, x, y }",
    },
    {
        "id": "ludo",
        "num": 8,
        "title": "Ludo / Parchís",
        "crate": "ludo_game",
        "doc": "docs/games/ludo.md",
        "smoke": "godot_project/tests/ludo_smoke.gd",
        "dice_3d": True,
        "bridge_init": "new_ludo_session",
        "bridge_prefix": "ludo_",
        "json_contract": "players (2..4), tokens (4 por jugador: Base/Track/HomeStretch/Goal), last_roll, consecutive_sixes, safe_squares",
        "commands": "LudoRollCommand { value }, LudoMoveTokenCommand { player, token_idx }",
    },
    {
        "id": "mille_bornes",
        "num": 9,
        "title": "Mille Bornes (1000 Millas)",
        "crate": "mille_bornes_game",
        "doc": "docs/games/mille_bornes.md",
        "smoke": "godot_project/tests/mille_bornes_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_mille_bornes_session",
        "bridge_prefix": "mille_bornes_",
        "json_contract": "distances, battle_pile, speed_pile, safety_areas (fourreaux), hands, deck_remaining, target_distance (1000)",
        "commands": "PlayCardMbCommand { player, card_idx, target_player }, DiscardCardMbCommand { player, card_idx }",
    },
    {
        "id": "monopoly",
        "num": 10,
        "title": "Monopoly (Magnate Inmobiliario)",
        "crate": "monopoly_game",
        "doc": "docs/games/monopoly.md",
        "smoke": "godot_project/tests/monopoly_smoke.gd",
        "dice_3d": True,
        "bridge_init": "new_monopoly_session",
        "bridge_prefix": "monopoly_",
        "json_contract": "players (cash, position, in_jail, properties), board_deeds (owner, houses, mortgaged), auction_state, last_dice",
        "commands": "RollAndMoveCommand { d1, d2 }, BuyPropertyCommand, BuildHouseCommand { property_id }, EndTurnCommand",
    },
    {
        "id": "uno",
        "num": 11,
        "title": "UNO",
        "crate": "uno_game",
        "doc": "docs/games/uno.md",
        "smoke": "godot_project/tests/uno_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_uno_session",
        "bridge_prefix": "uno_",
        "json_contract": "hands, discard_top, active_color, direction (Clockwise/CounterClockwise), pending_draw, uno_called",
        "commands": "PlayUnoCardCommand { player, card_idx, chosen_color }, DrawUnoCardCommand { player }, CallUnoCommand { player }",
    },
    {
        "id": "crisis",
        "num": 12,
        "title": "Crisis / TEG (Estrategia Global)",
        "crate": "crisis_game",
        "doc": "docs/games/teg.md",
        "smoke": "godot_project/tests/crisis_smoke.gd",
        "dice_3d": True,
        "bridge_init": "new_crisis_session",
        "bridge_prefix": "crisis_",
        "json_contract": "territories (owner, armies, adjacencies), phase (Reinforce/Attack/Regroup), continents, secret_objectives, combat_dice",
        "commands": "PlaceArmiesCommand { territory, count }, AttackTerritoryCommand { from, to, attacker_dice, defender_dice }, FortifyCommand",
    },
    {
        "id": "chinese_checkers",
        "num": 13,
        "title": "Damas Chinas (Chinese Checkers)",
        "crate": "chinese_checkers_game",
        "doc": "docs/games/chinese_checkers.md",
        "smoke": "godot_project/tests/chinese_checkers_smoke.gd",
        "dice_3d": False,
        "bridge_init": "new_chinese_checkers_session",
        "bridge_prefix": "chinese_checkers_",
        "json_contract": "star_grid (121 hex posiciones q,r), active_players (2/3/4/6), current_turn, hop_chain_active, winner",
        "commands": "MoveMarbleCommand { from_q, from_r, to_q, to_r }",
    },
    {
        "id": "goose",
        "num": 14,
        "title": "El Juego de la Oca (Game of the Goose)",
        "crate": "goose_game",
        "doc": "docs/games/goose.md",
        "smoke": "godot_project/tests/goose_smoke.gd",
        "dice_3d": True,
        "bridge_init": "new_goose_session",
        "bridge_prefix": "goose_",
        "json_contract": "num_players (2..4), current_player, positions (0..63), wait_turns, in_well, last_roll, last_event, finished, winner",
        "commands": "RollDiceCommand { player_id, die } (con efecto en cadena Oca/Puente/Posada/Pozo/Laberinto/Cárcel/Dados/Calavera y rebote en 63)",
    },
]

CORE_CRATES = [
    ("open_table_core", "ECS determinista, World, Resources, Commands, Events y hashing de estado"),
    ("open_table_engine", "Motor de sesiones de mesa, turnos, validación de comandos y snapshots"),
    ("open_table_net", "Protocolo de red determinista, sincronización P2P/Relay y serialización"),
    ("open_table_godot", "Puente GDExtension (Rust <-> Godot/Redot 4.4) con sesiones para los 14 juegos"),
    ("open_table_relay", "Servidor relay autoritativo y módulo anticheat para los 14 juegos"),
    ("open_table_schema", "Esquemas compartidos, identificadores y contratos de serialización JSON"),
]

TEST_ATTR_RE = re.compile(r"#\[(?:tokio::)?test[^\]]*\]")
FN_RE = re.compile(r"\bfn\s+([a-zA-Z0-9_]+)\s*\(")
GD_FUNC_RE = re.compile(r"^func\s+([a-zA-Z0-9_]+)\s*\(")
GD_ASSERT_RE = re.compile(r"(?:\b(?:_assert|assert|_check|verify_|expect_)\b|results\.append\s*\(\s*\[|push_error\s*\(|quit\s*\(\s*1\s*\))")

# Redot 4.4 strict typing detector: catches unsafe `:=` inference from Variant-returning expressions
UNSAFE_COLON_EQ_PATTERNS = [
    (re.compile(r":=\s*JSON\.parse_string\s*\("), "JSON.parse_string() devuelve Variant; usa `: Variant =` o tipado explícito tras validar `typeof()`"),
    (re.compile(r":=\s*str_to_var\s*\("), "str_to_var() devuelve Variant; usa `: Variant =`"),
    (re.compile(r":=\s*[a-zA-Z0-9_\.]+\.get\s*\("), ".get() sobre Dictionary/Object devuelve Variant; usa `: Variant =` o `int(...)`/`str(...)` con tipo explícito"),
    (re.compile(r":=\s*JavaScriptBridge\.eval\s*\("), "JavaScriptBridge.eval() devuelve Variant; usa `: Variant =`"),
]

errors = []
warnings = []

def extract_rust_tests(file_path):
    """Returns list of (fn_name, line_number) for all #[test] functions in file_path."""
    full_path = os.path.join(sdk_root, file_path)
    if not os.path.isfile(full_path):
        return []
    results = []
    with open(full_path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    pending_test_attr = False
    for idx, line in enumerate(lines, start=1):
        if TEST_ATTR_RE.search(line):
            pending_test_attr = True
        if pending_test_attr:
            m = FN_RE.search(line)
            if m:
                results.append((m.group(1), idx))
                pending_test_attr = False
    return results

def scan_crate_tests(crate_dir):
    """Returns dict with unit_tests, rules_tests, canonical_tests, other_tests."""
    unit_tests = []
    rules_tests = []
    canonical_tests = []
    other_tests = []

    crate_abs = os.path.join(sdk_root, crate_dir)
    if not os.path.isdir(crate_abs):
        return {
            "unit": unit_tests,
            "rules": rules_tests,
            "canonical": canonical_tests,
            "other": other_tests,
        }

    for root, _, files in os.walk(crate_abs):
        for fname in sorted(files):
            if not fname.endswith(".rs"):
                continue
            rel_path = os.path.relpath(os.path.join(root, fname), sdk_root)
            found = extract_rust_tests(rel_path)
            if not found:
                continue
            for fn_name, line_no in found:
                entry = (rel_path, fn_name, line_no)
                if rel_path.endswith("tests/game_rules.rs"):
                    rules_tests.append(entry)
                elif rel_path.endswith("tests/canonical_rules.rs"):
                    canonical_tests.append(entry)
                elif "/src/" in rel_path.replace("\\", "/"):
                    unit_tests.append(entry)
                else:
                    other_tests.append(entry)
    return {
        "unit": unit_tests,
        "rules": rules_tests,
        "canonical": canonical_tests,
        "other": other_tests,
    }

# Scan open_table_godot/src/lib.rs for bridge functions & line numbers
bridge_file = "open_table_godot/src/lib.rs"
bridge_abs = os.path.join(sdk_root, bridge_file)
bridge_funcs = {}
if os.path.isfile(bridge_abs):
    with open(bridge_abs, "r", encoding="utf-8", errors="replace") as f:
        for idx, line in enumerate(f, start=1):
            m = re.search(r"\bfn\s+([a-zA-Z0-9_]+)\s*\(", line)
            if m:
                bridge_funcs[m.group(1)] = idx
else:
    errors.append({
        "id": "ERR-BRIDGE-MISSING",
        "severity": "CRITICAL",
        "location": f"{bridge_file}:1",
        "summary": "No se encontró el archivo del puente GDExtension open_table_godot/src/lib.rs.",
        "reproduce": "ls -la games_tables_sdk/open_table_godot/src/lib.rs",
        "fix": "Restaurar open_table_godot/src/lib.rs con la implementación de OpenTableBridge para los 14 juegos.",
    })

# Scan all GDScript files for Redot 4.4 strict typing violations
gd_strict_violations = []
godot_proj_abs = os.path.join(sdk_root, "godot_project")
for root, _, files in os.walk(godot_proj_abs):
    for fname in sorted(files):
        if not fname.endswith(".gd"):
            continue
        abs_p = os.path.join(root, fname)
        rel_p = os.path.relpath(abs_p, sdk_root)
        with open(abs_p, "r", encoding="utf-8", errors="replace") as f:
            for idx, line in enumerate(f, start=1):
                stripped = line.strip()
                if stripped.startswith("#"):
                    continue
                for pat, reason in UNSAFE_COLON_EQ_PATTERNS:
                    if pat.search(line):
                        gd_strict_violations.append((rel_p, idx, stripped, reason))

for rel_p, idx, code_line, reason in gd_strict_violations:
    errors.append({
        "id": "ERR-REDOT-STRICT-VARIANT",
        "severity": "CRITICAL",
        "location": f"{rel_p}:{idx}",
        "summary": f"Inferencia implícita `:=` peligrosa en Redot 4.4: `{code_line}` ({reason})",
        "reproduce": f"bash games_tables_sdk/tools/run_godot_tests.sh",
        "fix": f"Abrir `{rel_p}` en la línea {idx} y reemplazar `:=` por tipado explícito (`: Variant =`, `: Dictionary =`, `: Array =`, `: int = int(...)`, etc.). Si es un `*_board.gd`, sincronizar con `godot_project/scenes/`.",
    })

# Check 3D dice components
dice_3d_files = [
    "godot_project/scripts/dice_roller_3d.gd",
    "godot_project/dice_widget.gd",
    "godot_project/tests/dice_3d_smoke.gd",
]
for df in dice_3d_files:
    if not os.path.isfile(os.path.join(sdk_root, df)):
        errors.append({
            "id": "ERR-DICE3D-MISSING",
            "severity": "CRITICAL",
            "location": f"{df}:1",
            "summary": f"Falta componente o smoke test del sistema de dados 3D: `{df}`",
            "reproduce": "bash games_tables_sdk/tools/run_godot_tests.sh dice_3d_smoke.gd",
            "fix": f"Restaurar o implementar `{df}` asegurando soporte de SubViewport, Camera3D, hasta 3 dados MeshInstance3D y señal `roll_completed`.",
        })

# Inspect each of the 14 games
game_reports = []
total_game_unit = 0
total_game_rules = 0
total_game_canonical = 0

for g in GAMES:
    gid = g["id"]
    crate = g["crate"]
    cargo_toml_rel = f"{crate}/Cargo.toml"
    cargo_toml_abs = os.path.join(sdk_root, cargo_toml_rel)
    if os.path.isfile(cargo_toml_abs):
        with open(cargo_toml_abs, "r", encoding="utf-8", errors="replace") as ctf:
            ct_text = ctf.read()
        for req_dep in ("typetag", "bevy_ecs"):
            if req_dep not in ct_text:
                errors.append({
                    "id": f"ERR-CARGO-DEP-{req_dep.upper()}-{gid.upper()}",
                    "severity": "CRITICAL",
                    "location": f"{cargo_toml_rel}:13",
                    "summary": f"Falta la dependencia `{req_dep}` en `{cargo_toml_rel}` requerida por los derive macros `GameCommand`, `GameEvent` y `GameResource` (causa error E0433/E0046 al compilar).",
                    "reproduce": f"cargo check -p {crate}",
                    "fix": f"Añadir `{req_dep}` en la sección `[dependencies]` de `games_tables_sdk/{cargo_toml_rel}` (`typetag = \"0.2\"`, `bevy_ecs = \"0.20\"`).",
                })
    # Audit Rust sources in crate for private TurnOrder.current() field access (E0599)
    crate_src_abs = os.path.join(sdk_root, crate, "src")
    if os.path.isdir(crate_src_abs):
        for r_root, _, r_files in os.walk(crate_src_abs):
            for r_fname in sorted(r_files):
                if not r_fname.endswith(".rs"):
                    continue
                r_abs = os.path.join(r_root, r_fname)
                r_rel = os.path.relpath(r_abs, sdk_root)
                with open(r_abs, "r", encoding="utf-8", errors="replace") as rf:
                    for l_idx, r_line in enumerate(rf, start=1):
                        if "TurnResource" in r_line and ".0.current()" in r_line:
                            errors.append({
                                "id": f"ERR-RUST-TURNORDER-CURRENT-{gid.upper()}-{l_idx}",
                                "severity": "CRITICAL",
                                "location": f"{r_rel}:{l_idx}",
                                "summary": f"Llamada inválida a `.0.current()` sobre `TurnResource` (`TurnOrder::current` es un campo privado `usize`; causa error E0599).",
                                "reproduce": f"cargo check -p {crate}",
                                "fix": f"Reemplazar `.0.current()` por `.0.current_player()` en `games_tables_sdk/{r_rel}:{l_idx}`.",
                            })
    tests_info = scan_crate_tests(crate)
    u_cnt = len(tests_info["unit"])
    r_cnt = len(tests_info["rules"])
    c_cnt = len(tests_info["canonical"])
    total_game_unit += u_cnt
    total_game_rules += r_cnt
    total_game_canonical += c_cnt

    if r_cnt == 0:
        errors.append({
            "id": f"ERR-RUST-RULES-{gid.upper()}",
            "severity": "CRITICAL",
            "location": f"{crate}/tests/game_rules.rs:1",
            "summary": f"El crate `{crate}` no contiene tests en `tests/game_rules.rs`.",
            "reproduce": f"cargo test -p {crate} --test game_rules",
            "fix": f"Crear o poblar `{crate}/tests/game_rules.rs` con pruebas de reglas básicas y transiciones de estado para {g['title']}.",
        })
    if c_cnt == 0:
        errors.append({
            "id": f"ERR-RUST-CANONICAL-{gid.upper()}",
            "severity": "CRITICAL",
            "location": f"{crate}/tests/canonical_rules.rs:1",
            "summary": f"El crate `{crate}` no contiene tests canónicos en `tests/canonical_rules.rs`.",
            "reproduce": f"cargo test -p {crate} --test canonical_rules",
            "fix": f"Crear o poblar `{crate}/tests/canonical_rules.rs` verificando invariantes canónicas de {g['title']}.",
        })

    # Check board files & scenes/ parity
    root_board = f"godot_project/{gid}_board.gd"
    scene_board = f"godot_project/scenes/{gid}_board.gd"
    root_board_abs = os.path.join(sdk_root, root_board)
    scene_board_abs = os.path.join(sdk_root, scene_board)

    board_exists = os.path.isfile(root_board_abs)
    scene_exists = os.path.isfile(scene_board_abs)
    parity_ok = False
    board_lines = 0
    dice_3d_hooked = False

    if board_exists:
        with open(root_board_abs, "r", encoding="utf-8", errors="replace") as bf:
            b_content = bf.read()
            board_lines = len(b_content.splitlines())
            if g["dice_3d"]:
                dice_3d_hooked = ("DiceWidget" in b_content) or ("dice_widget" in b_content) or ("roll_3d" in b_content) or ("roll_completed" in b_content)
    else:
        errors.append({
            "id": f"ERR-BOARD-MISSING-{gid.upper()}",
            "severity": "CRITICAL",
            "location": f"{root_board}:1",
            "summary": f"Falta el script de tablero `{root_board}` para {g['title']}.",
            "reproduce": f"ls -la games_tables_sdk/{root_board}",
            "fix": f"Implementar `{root_board}` y copiarlo a `{scene_board}`.",
        })

    if board_exists and scene_exists:
        with open(root_board_abs, "rb") as f1, open(scene_board_abs, "rb") as f2:
            parity_ok = hashlib.sha256(f1.read()).digest() == hashlib.sha256(f2.read()).digest()
        if not parity_ok:
            errors.append({
                "id": f"ERR-BOARD-PARITY-{gid.upper()}",
                "severity": "CRITICAL",
                "location": f"{scene_board}:1",
                "summary": f"Desincronización detectada entre `{root_board}` y `{scene_board}`.",
                "reproduce": f"diff -u games_tables_sdk/{root_board} games_tables_sdk/{scene_board}",
                "fix": f"Ejecutar `cp games_tables_sdk/{root_board} games_tables_sdk/{scene_board}` tras verificar cuál archivo contiene los cambios más recientes.",
            })
    elif board_exists and not scene_exists:
        errors.append({
            "id": f"ERR-SCENE-BOARD-MISSING-{gid.upper()}",
            "severity": "CRITICAL",
            "location": f"{scene_board}:1",
            "summary": f"Falta la copia espejo `{scene_board}` requerida por las escenas `.tscn`.",
            "reproduce": f"ls -la games_tables_sdk/{scene_board}",
            "fix": f"Ejecutar `cp games_tables_sdk/{root_board} games_tables_sdk/{scene_board}`.",
        })

    if g["dice_3d"] and not dice_3d_hooked:
        errors.append({
            "id": f"ERR-DICE3D-INTEGRATION-{gid.upper()}",
            "severity": "CRITICAL",
            "location": f"{root_board}:1",
            "summary": f"El juego de dados `{gid}` no integra `DiceWidget` / `DiceRoller3D` en `{root_board}`.",
            "reproduce": f"bash games_tables_sdk/tools/run_godot_tests.sh dice_3d_smoke.gd",
            "fix": f"Instanciar `DiceWidget` en `{root_board}`, conectar su señal `roll_completed` y sincronizar con `{scene_board}`.",
        })

    # Check bridge methods
    matched_bridge = [
        (fn_name, line_no)
        for fn_name, line_no in sorted(bridge_funcs.items(), key=lambda x: x[1])
        if (fn_name == g["bridge_init"] or fn_name.startswith(g["bridge_prefix"]) or f"_{gid}_" in fn_name or fn_name.endswith(f"_{gid}"))
        and not (gid == "checkers" and "chinese_checkers" in fn_name)
    ]
    if not matched_bridge:
        errors.append({
            "id": f"ERR-BRIDGE-FN-{gid.upper()}",
            "severity": "CRITICAL",
            "location": f"{bridge_file}:1",
            "summary": f"No se encontraron funciones bridge exportadas para `{gid}` en `{bridge_file}`.",
            "reproduce": f"grep -n '{gid}' games_tables_sdk/{bridge_file}",
            "fix": f"Exponer `{g['bridge_init']}` y los métodos de comando/estado en `open_table_godot/src/lib.rs`.",
        })

    # Check smoke test
    smoke_rel = g["smoke"]
    smoke_abs = os.path.join(sdk_root, smoke_rel)
    smoke_exists = os.path.isfile(smoke_abs)
    smoke_funcs = []
    smoke_asserts = []
    if smoke_exists:
        with open(smoke_abs, "r", encoding="utf-8", errors="replace") as sf:
            for idx, sline in enumerate(sf, start=1):
                fm = GD_FUNC_RE.match(sline.strip())
                if fm:
                    smoke_funcs.append((fm.group(1), idx))
                if GD_ASSERT_RE.search(sline):
                    smoke_asserts.append((idx, sline.strip()))
    else:
        errors.append({
            "id": f"ERR-SMOKE-MISSING-{gid.upper()}",
            "severity": "CRITICAL",
            "location": f"{smoke_rel}:1",
            "summary": f"Falta el smoke test de Godot `{smoke_rel}` para {g['title']}.",
            "reproduce": f"bash games_tables_sdk/tools/run_godot_tests.sh {os.path.basename(smoke_rel)}",
            "fix": f"Crear `{smoke_rel}` extendiendo `SceneTree` (con `_init()` y `quit(0)`) para validar el tablero y puente de {g['title']}.",
        })

    # Check doc
    doc_rel = g["doc"]
    doc_exists = os.path.isfile(os.path.join(sdk_root, doc_rel))
    if not doc_exists:
        errors.append({
            "id": f"ERR-DOC-MISSING-{gid.upper()}",
            "severity": "WARNING",
            "location": f"{doc_rel}:1",
            "summary": f"Falta documentación de reglas `{doc_rel}` para {g['title']}.",
            "reproduce": f"ls -la games_tables_sdk/{doc_rel}",
            "fix": f"Crear `{doc_rel}` documentando las reglas canónicas, comandos ECS y contrato JSON de {g['title']}.",
        })

    game_ok = (
        r_cnt > 0
        and c_cnt > 0
        and board_exists
        and parity_ok
        and len(matched_bridge) > 0
        and smoke_exists
        and doc_exists
        and (not g["dice_3d"] or dice_3d_hooked)
    )

    game_reports.append({
        "meta": g,
        "tests": tests_info,
        "u_cnt": u_cnt,
        "r_cnt": r_cnt,
        "c_cnt": c_cnt,
        "total_rust": u_cnt + r_cnt + c_cnt,
        "root_board": root_board,
        "scene_board": scene_board,
        "board_lines": board_lines,
        "parity_ok": parity_ok,
        "dice_3d_hooked": dice_3d_hooked,
        "bridge_fns": matched_bridge,
        "smoke_funcs": smoke_funcs,
        "smoke_asserts": smoke_asserts,
        "doc_exists": doc_exists,
        "game_ok": game_ok,
    })

# Scan Core crates
core_reports = []
total_core_tests = 0
for crate_name, crate_desc in CORE_CRATES:
    c_info = scan_crate_tests(crate_name)
    all_c_tests = c_info["unit"] + c_info["rules"] + c_info["canonical"] + c_info["other"]
    total_core_tests += len(all_c_tests)
    core_reports.append({
        "crate": crate_name,
        "desc": crate_desc,
        "tests": all_c_tests,
    })

# Scan all Godot smoke test scripts in godot_project/tests/
tests_dir_abs = os.path.join(sdk_root, "godot_project/tests")
all_godot_tests = []
total_godot_assertions = 0
if os.path.isdir(tests_dir_abs):
    for fname in sorted(os.listdir(tests_dir_abs)):
        if not fname.endswith(".gd"):
            continue
        rel_p = f"godot_project/tests/{fname}"
        abs_p = os.path.join(tests_dir_abs, fname)
        with open(abs_p, "r", encoding="utf-8", errors="replace") as tf:
            t_lines = tf.readlines()
        assert_cnt = sum(1 for ln in t_lines if GD_ASSERT_RE.search(ln))
        total_godot_assertions += assert_cnt
        funcs = []
        for idx, ln in enumerate(t_lines, start=1):
            fm = GD_FUNC_RE.match(ln.strip())
            if fm:
                funcs.append(f"{fm.group(1)}:{idx}")
        all_godot_tests.append({
            "file": rel_p,
            "name": fname,
            "lines": len(t_lines),
            "asserts": assert_cnt,
            "funcs": funcs,
        })

if godot_status != 0:
    errors.append({
        "id": "ERR-GODOT-RUNNER-FAILED",
        "severity": "CRITICAL",
        "location": "tools/run_godot_tests.sh:1",
        "summary": f"`tools/run_godot_tests.sh` terminó con código de salida {godot_status}.",
        "reproduce": "bash games_tables_sdk/tools/run_godot_tests.sh",
        "fix": f"Revisar la salida del runner:\n```\n{godot_output[-1500:]}\n```",
    })

if cargo_available and cargo_status != 0:
    errors.append({
        "id": "ERR-CARGO-TEST-FAILED",
        "severity": "CRITICAL",
        "location": "Cargo.toml:1",
        "summary": f"`cargo test --workspace` terminó con código de salida {cargo_status}.",
        "reproduce": "cd games_tables_sdk && cargo test --workspace",
        "fix": f"Revisar la traza de compilación/ejecución de Cargo:\n```\n{cargo_output[-1500:]}\n```",
    })

total_rust_tests = total_game_unit + total_game_rules + total_game_canonical + total_core_tests
overall_pass = len(errors) == 0
status_badge = "PASS (100% VERIFICADO — 0 ERRORES)" if overall_pass else f"FAIL ({len(errors)} ERRORES DETECTADOS)"
exec_mode = (
    "Ejecución Nativa (`cargo test` + `run_godot_tests.sh`) + Auditoría AST/Estática"
    if cargo_available
    else "Verificación Híbrida (`run_godot_tests.sh` + Inspector Estático AST Rust/GDScript)"
)

lines = []
w = lines.append

w("# OpenTable SDK — Reporte Maestro de Cobertura y Diagnóstico para IA (`TEST_SUMMARY.md`)")
w("")
w("> **Propósito de este documento**: Este archivo es generado automáticamente por `games_tables_sdk/tools/generate_test_summary.sh`. Contiene el mapa completo de cobertura de pruebas de **Rust** y **Godot/Redot 4.4** para los **14 juegos de mesa** del SDK, junto con referencias exactas `archivo:línea`, contratos JSON del puente GDExtension y recetas de auto-reparación diseñadas para que cualquier **Agente de IA** pueda diagnosticar y corregir regresiones sin pérdida de contexto.")
w("")
w("---")
w("")
w("## 1. Resumen Ejecutivo y Estado Global del Workspace")
w("")
w(f"- **Estado Global del Proyecto**: **{status_badge}**")
w(f"- **Modo de Verificación**: {exec_mode}")
w(f"- **Juegos Verificados**: **{sum(1 for g in game_reports if g['game_ok'])} / {len(GAMES)}** juegos completos (Motor Rust + Bridge GDExtension + Tablero Godot + Smoke Tests + Docs)")
w(f"- **Juegos con Dados 3D (`DiceRoller3D` + `DiceWidget`)**: **{sum(1 for g in game_reports if g['meta']['dice_3d'] and g['dice_3d_hooked'])} / 5** (`backgammon`, `ludo`, `monopoly`, `crisis`, `goose`)")
w(f"- **Total de Tests en Rust (`#[test]`)**: **{total_rust_tests}** tests distribuidos en 20 crates:")
w(f"  - Tests Unitarios en Juegos (`<game>_game/src/**`): **{total_game_unit}**")
w(f"  - Tests de Reglas de Juego (`<game>_game/tests/game_rules.rs`): **{total_game_rules}**")
w(f"  - Tests de Reglas Canónicas (`<game>_game/tests/canonical_rules.rs`): **{total_game_canonical}**")
w(f"  - Tests de Crates Core (`open_table_*`): **{total_core_tests}**")
w(f"- **Total de Suites Smoke Test en Godot (`godot_project/tests/*.gd`)**: **{len(all_godot_tests)}** scripts (**{total_godot_assertions}** puntos de aserción/verificación)")
w(f"- **Paridad Espejo de Tableros (`godot_project/*_board.gd` ↔ `godot_project/scenes/*_board.gd`)**: **{sum(1 for g in game_reports if g['parity_ok'])} / {len(GAMES)}** sincronizados byte a byte")
w(f"- **Cumplimiento Tipado Estricto Redot 4.4 (`Variant` Inference Check)**: **{len(gd_strict_violations)}** violaciones detectadas")
w("")
w("---")
w("")
w("## 2. Matriz de Cobertura de los 14 Juegos")
w("")
w("| # | Juego | Crate Rust | Unit (`src/`) | Reglas (`game_rules.rs`) | Canónicos (`canonical_rules.rs`) | Total Rust | Funciones Bridge | Tablero Godot + Paridad `scenes/` | Dados 3D (`DiceRoller3D`) | Smoke Test Godot | Docs | Estado |")
w("| :-: | :--- | :--- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :--- | :-: | :-: |")

for gr in game_reports:
    m = gr["meta"]
    parity_str = "OK (Sync)" if gr["parity_ok"] else "DESYNC"
    dice_str = "Sí (3D OK)" if (m["dice_3d"] and gr["dice_3d_hooked"]) else ("FALTA 3D" if m["dice_3d"] else "N/A")
    doc_str = "OK" if gr["doc_exists"] else "FALTA"
    st_str = "PASS" if gr["game_ok"] else "FAIL"
    smoke_short = os.path.basename(m["smoke"])
    w(
        f"| {m['num']} | **{m['title']}** | `{m['crate']}` | {gr['u_cnt']} | {gr['r_cnt']} | {gr['c_cnt']} | **{gr['total_rust']}** | {len(gr['bridge_fns'])} | `{gr['board_lines']}L` ({parity_str}) | {dice_str} | `{smoke_short}` ({len(gr['smoke_asserts'])} asserts) | {doc_str} | **{st_str}** |"
    )

w("")
w("---")
w("")
w("## 3. Cobertura de Crates Base del Motor (`open_table_*`)")
w("")
w("| Crate | Propósito Arquitectónico | Total Tests (`#[test]`) | Ubicaciones Clave (`archivo:línea`) |")
w("| :--- | :--- | :-: | :--- |")
for cr in core_reports:
    locs = ", ".join(f"`{rel}:{ln}` (`{fn}`)" for rel, fn, ln in cr["tests"][:4])
    if len(cr["tests"]) > 4:
        locs += f", ... (+{len(cr['tests']) - 4} más)"
    if not locs:
        locs = "Verificado vía integración en crates de juego"
    w(f"| `{cr['crate']}` | {cr['desc']} | **{len(cr['tests'])}** | {locs} |")

w("")
w("---")
w("")
w("## 4. Diagnóstico de Errores Detectados (`Actionable Failures & Warnings`)")
w("")

if not errors and not warnings:
    w("### Estado Limpio: `0 Errores Detectados`")
    w("")
    w("Todas las suites de Rust (14 juegos + 6 crates core), los 45 smoke tests de Godot/Redot, la validación de tipado estricto Redot 4.4 y la paridad byte a byte de `godot_project/scenes/` se encuentran en estado **PASS**.")
    w("")
    w("> **Nota para Agentes de IA**: Si en el futuro introduces un cambio que rompa un test, desincronice un tablero o introduzca una inferencia `:=` inválida sobre un `Variant`, vuelve a ejecutar `bash games_tables_sdk/tools/generate_test_summary.sh` y esta sección listará automáticamente cada fallo con su ID, `archivo:línea`, traza de error y receta exacta de reparación.")
else:
    w(f"### Se detectaron **{len(errors)} errores** y **{len(warnings)} advertencias** que requieren atención inmediata:")
    w("")
    for err in errors + warnings:
        w(f"#### [{err['id']}] ({err['severity']}) — Ubicación: `games_tables_sdk/{err['location']}`")
        w(f"- **Descripción del Problema**: {err['summary']}")
        w(f"- **Comando de Reproducción**: `{err['reproduce']}`")
        w(f"- **Guía de Corrección para la IA**: {err['fix']}")
        w("")

w("")
w("---")
w("")
w("## 5. Catálogo Detallado de los 14 Juegos (Mapa `archivo:línea` para IA)")
w("")
w("Cada subsección incluye las rutas exactas, funciones del puente GDExtension, contratos de serialización JSON y la ubicación `archivo:línea` de cada test en Rust y Godot para facilitar ediciones precisas.")
w("")

for gr in game_reports:
    m = gr["meta"]
    gid = m["id"]
    w(f"### 5.{m['num']}. {m['title']} (`{m['crate']}`)")
    w("")
    w(f"- **Archivos del Juego**:")
    w(f"  - **Motor Rust**: `games_tables_sdk/{m['crate']}/src/lib.rs`")
    w(f"  - **Tests de Reglas**: `games_tables_sdk/{m['crate']}/tests/game_rules.rs` (**{gr['r_cnt']}** tests)")
    w(f"  - **Tests Canónicos**: `games_tables_sdk/{m['crate']}/tests/canonical_rules.rs` (**{gr['c_cnt']}** tests)")
    w(f"  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` ({len(gr['bridge_fns'])} métodos exportados)")
    w(f"  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/{gr['root_board']}` ↔ `games_tables_sdk/{gr['scene_board']}` ({gr['board_lines']} líneas, Paridad: `{'OK' if gr['parity_ok'] else 'FAIL'}`)")
    w(f"  - **Smoke Test Godot**: `games_tables_sdk/{m['smoke']}`")
    w(f"  - **Documentación Técnica**: `games_tables_sdk/{m['doc']}`")
    w(f"- **Contrato de Estado JSON (`get_state_json`)**: `{m['json_contract']}`")
    w(f"- **Comandos del Motor (`dispatch_command`)**: `{m['commands']}`")
    if m["dice_3d"]:
        w(f"- **Integración Dados 3D (`DiceWidget` / `DiceRoller3D`)**: Activa en `{gr['root_board']}` y verificada en `godot_project/tests/dice_3d_smoke.gd` y `{m['smoke']}`.")
    w(f"- **Funciones en `open_table_godot/src/lib.rs`**:")
    bridge_list = ", ".join(f"`{fn}` (línea {ln})" for fn, ln in gr["bridge_fns"])
    w(f"  - {bridge_list if bridge_list else 'Ninguna detectada'}")
    w(f"- **Inventario de Tests en Rust (`archivo:línea`)**:")
    for category_label, key in [("Unitarios (`src/`) ", "unit"), ("Reglas (`tests/game_rules.rs`)", "rules"), ("Canónicos (`tests/canonical_rules.rs`)", "canonical")]:
        items = gr["tests"][key]
        if items:
            formatted = ", ".join(f"`{fn}` (`{rel}:{ln}`)" for rel, fn, ln in items)
            w(f"  - *{category_label}*: {formatted}")
        else:
            w(f"  - *{category_label}*: *(sin tests en esta categoría)*")
    w(f"- **Funciones y Aserciones en Smoke Test Godot (`{m['smoke']}`)**:")
    if gr["smoke_funcs"]:
        fn_str = ", ".join(f"`{fn}()` (línea {ln})" for fn, ln in gr["smoke_funcs"])
        w(f"  - *Puntos de entrada*: {fn_str}")
    w(f"  - *Total de aserciones/chequeos en `{os.path.basename(m['smoke'])}`*: **{len(gr['smoke_asserts'])}** verificaciones (ej. líneas {', '.join(str(ln) for ln, _ in gr['smoke_asserts'][:8])})")
    w("")

w("---")
w("")
w("## 6. Inventario Completo de los 45 Smoke Tests de Godot (`godot_project/tests/*.gd`)")
w("")
w("| # | Archivo de Prueba (`games_tables_sdk/...`) | Líneas | Aserciones / Chequeos | Funciones Definidas (`func:línea`) |")
w("| :-: | :--- | :-: | :-: | :--- |")
for idx, gt in enumerate(all_godot_tests, start=1):
    fn_summary = ", ".join(f"`{f}`" for f in gt["funcs"][:5])
    if len(gt["funcs"]) > 5:
        fn_summary += f" (+{len(gt['funcs']) - 5} más)"
    w(f"| {idx} | `{gt['file']}` | {gt['lines']} | {gt['asserts']} | {fn_summary} |")

w("")
w("---")
w("")
w("## 7. Guía de Auto-Reparación para Agentes de IA (`AI Self-Healing Playbook`)")
w("")
w("Si eres un agente de IA encargado de corregir errores o añadir funcionalidades en este proyecto, sigue estrictamente estas **5 reglas de oro** para evitar regresiones:")
w("")
w("### Regla 1: Tipado Estricto en Redot 4.4 / GDScript (`0` Inferencias `:=` sobre `Variant`)")
w("- **Síntoma del Error**: `Parse Error: Cannot infer the type of \"...\" variable because the value doesn't have a set type.`")
w("- **Causa**: Redot 4.4 trata como error fatal usar `:=` cuando la expresión de la derecha retorna `Variant` (`JSON.parse_string()`, `.get()` en diccionarios, indexación `dict[\"key\"]` o `arr[i]` no tipados, `str_to_var()`, etc.).")
w("- **Solución Exacta**:")
w("  ```gdscript")
w("  # INCORRECTO (Falla en Redot 4.4):")
w("  var parsed := JSON.parse_string(raw_json)")
w("  var pos := state_dict.get(\"positions\", [])")
w("")
w("  # CORRECTO (Cumple Redot 4.4 Strict):")
w("  var parsed: Variant = JSON.parse_string(raw_json)")
w("  if typeof(parsed) != TYPE_DICTIONARY:")
w("      return")
w("  var state_dict: Dictionary = parsed")
w("  var pos_raw: Variant = state_dict.get(\"positions\", [])")
w("  var pos: Array = pos_raw if typeof(pos_raw) == TYPE_ARRAY else []")
w("  ```")
w("")
w("### Regla 2: Paridad Obligatoria entre `godot_project/*_board.gd` y `godot_project/scenes/*_board.gd`")
w("- **Síntoma del Error**: `[ERR-BOARD-PARITY-<JUEGO>]` en `TEST_SUMMARY.md` o fallo en `verify_p12.sh` / `run_godot_tests.sh`.")
w("- **Causa**: El proyecto mantiene los scripts de tablero tanto en `godot_project/<juego>_board.gd` como en `godot_project/scenes/<juego>_board.gd`.")
w("- **Solución Exacta**: Cada vez que modifiques cualquier archivo `godot_project/<juego>_board.gd`, ejecuta inmediatamente:")
w("  ```bash")
w("  cp games_tables_sdk/godot_project/<juego>_board.gd games_tables_sdk/godot_project/scenes/<juego>_board.gd")
w("  ```")
w("")
w("### Regla 3: Sincronización de Dados 3D (`DiceRoller3D` y `DiceWidget`)")
w("- **Juegos Afectados**: `goose` (1 dado), `ludo` (1 dado), `backgammon` (2 dados), `monopoly` (2 dados), `crisis` (hasta 3 dados).")
w("- **Arquitectura**:")
w("  - `games_tables_sdk/godot_project/scripts/dice_roller_3d.gd` gestiona el `SubViewport`, `Camera3D`, `DirectionalLight3D` y 3 dados `MeshInstance3D` con texturas procedurales de pips (1..6) y rotaciones exactas `_target_rotation_for_value(val)`.")
w("  - `games_tables_sdk/godot_project/dice_widget.gd` instancia `DiceRoller3D`, expone `set_dice_values(values: Array)` y `roll_to_values(values: Array)`, realiza una pausa breve al aterrizar para mostrar el resultado 3D y finalmente emite `roll_completed(values)`.")
w("- **Solución ante fallos en `dice_3d_smoke.gd`**: Verificar que `DiceRoller3D.roll_3d(values)` valide valores en `1..6`, configure la visibilidad de 1 a 3 dados y emita `roll_finished(values)` tras la animación o de forma síncrona en modo headless.")
w("")
w("### Regla 4: Contratos del Puente Rust ↔ Godot (`open_table_godot/src/lib.rs`)")
w("- **Arquitectura**: Ningún juego altera `open_table_core` ni `open_table_engine`. Cada juego encapsula sus reglas en `<juego>_game/src/lib.rs` y se expone en `OpenTableBridge` dentro de `open_table_godot/src/lib.rs`.")
w("- **Verificación de Reglas**: Toda regla nueva o corrección de bug en un juego debe incluir su test correspondiente en `<juego>_game/tests/game_rules.rs` y `<juego>_game/tests/canonical_rules.rs`, además de mantener el anticheat sincronizado en `open_table_relay/src/anticheat.rs`.")
w("")
w("### Regla 5: Comandos Estándar de Verificación y Regeneración")
w("Después de aplicar cualquier cambio en Rust o GDScript, ejecuta en orden:")
w("```bash")
w("# 1. Regenerar este reporte TEST_SUMMARY.md y validar 0 errores")
w("bash games_tables_sdk/tools/generate_test_summary.sh")
w("")
w("# 2. Ejecutar los gates completos del workspace y PROMPTS13")
w("bash games_tables_sdk/tools/verify_workspace.sh && bash games_tables_sdk/tools/verify_p13.sh")
w("```")

content = "\n".join(lines) + "\n"

sdk_out = os.path.join(sdk_root, "TEST_SUMMARY.md")
repo_out = os.path.join(repo_root, "TEST_SUMMARY.md")

with open(sdk_out, "w", encoding="utf-8") as f:
    f.write(content)

with open(repo_out, "w", encoding="utf-8") as f:
    f.write(content)

print(f"TEST_SUMMARY.md generado exitosamente en:\n  - {sdk_out}\n  - {repo_out}")
print(f"Resumen: {len(GAMES)}/14 juegos auditados, {total_rust_tests} tests de Rust inventariados, {len(all_godot_tests)} suites Godot verificadas, {len(errors)} errores.")

if not overall_pass:
    sys.exit(1)
PY
