#!/usr/bin/env python3
"""
Generates production-grade English README.md files for all 24 crates (crates.io & docs.rs standard),
updates the root README.md with a 7-language switcher bar + English/Spanish sections,
and generates native multilingual documentation hubs in docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md.
"""

from pathlib import Path

SDK_ROOT = Path(__file__).resolve().parent.parent

LANG_BAR_ROOT = (
    "**Languages / Idiomas:** "
    "[English](./docs/i18n/en/README.md) · "
    "[Español](./docs/i18n/es/README.md) · "
    "[Português (BR)](./docs/i18n/pt-BR/README.md) · "
    "[Français](./docs/i18n/fr/README.md) · "
    "[Deutsch](./docs/i18n/de/README.md) · "
    "[简体中文](./docs/i18n/zh-CN/README.md) · "
    "[日本語](./docs/i18n/ja/README.md)"
)

LANG_BAR_CRATE = (
    "**Documentation Languages:** "
    "[English](../docs/i18n/en/README.md) · "
    "[Español](../docs/i18n/es/README.md) · "
    "[Português (BR)](../docs/i18n/pt-BR/README.md) · "
    "[Français](../docs/i18n/fr/README.md) · "
    "[Deutsch](../docs/i18n/de/README.md) · "
    "[简体中文](../docs/i18n/zh-CN/README.md) · "
    "[日本語](../docs/i18n/ja/README.md)"
)

CRATES_METADATA = [
    # Core & Engine (3)
    {
        "name": "open_table_core",
        "layer": "Core & Engine Foundation",
        "summary_en": "Foundational deterministic traits, serializable Commands/Events, seeded ChaCha8 RNG, and transport contracts for turn-based board game engines.",
        "summary_es": "Traits fundacionales deterministas, comandos/eventos serializables, RNG ChaCha8 con semilla y contratos de transporte para motores de juegos de mesa por turnos.",
        "features": [
            "Zero engine/network coupling: pure domain types (`SessionId`, `PlayerId`, `Tick`, `EntityId`).",
            "Dynamic command & event serialization via `typetag::serde` (`Command`, `Event` trait objects).",
            "Deterministic cross-platform PRNG (`RandomService` backed by `ChaCha8Rng`) and `GameClock`.",
            "4-tier `AiDifficulty` (`Easy`, `Medium`, `Hard`, `Expert`) with Top-K noise perturbation (`select_top_k_with_noise`, `default_randomness_pct`) and `AiMoveTelemetry`.",
            "64-bit deterministic FNV-1a state checksum helpers (`deterministic_fnv1a_64`, `format_fnv1a_hex`).",
        ],
        "exports": ["SessionId", "PlayerId", "Tick", "Command", "Event", "RandomService", "AiDifficulty", "AiMoveTelemetry", "deterministic_fnv1a_64"],
        "example": '''use open_table_core::{AiDifficulty, PlayerId, RandomService, deterministic_fnv1a_64, format_fnv1a_hex};

let mut rng = RandomService::from_seed(42);
let roll = rng.roll_die(6);
assert!((1..=6).contains(&roll));
assert_eq!(PlayerId(1).0, 1);

// Top-K noise selection with 25% randomness factor
let candidate_scores = vec![120.0, 114.0, 95.0, 40.0];
let chosen_idx = AiDifficulty::select_top_k_with_noise(&candidate_scores, 25, 15.0, 42).unwrap();
assert!(chosen_idx <= 1);

// Deterministic 64-bit FNV-1a checksum ("0x" + 16 hex digits = 18 chars)
let hash = deterministic_fnv1a_64(b"canonical_board_state_v1");
assert_eq!(format_fnv1a_hex(hash).len(), 18);''',
    },
    {
        "name": "open_table_engine",
        "layer": "Core & Engine Foundation",
        "summary_en": "ECS-backed deterministic turn-based session runtime (`Session`), transactional command pipeline, Undo/Redo stacks, FIDE ELO calculator, and state hashing.",
        "summary_es": "Runtime determinista de sesiones por turnos sobre Bevy ECS (`Session`), pipeline transaccional de comandos, pilas Undo/Redo, calculadora ELO FIDE y hashing de estado.",
        "features": [
            "Deterministic `Session` wrapping `bevy_ecs::world::World` with strict turn & phase validation.",
            "Transactional command execution (`process_command`) with automatic event recording and tick progression.",
            "Snapshot-based `undo_step()` and `redo_step()` stacks plus 64-bit FNV-1a state checksums (`compute_state_checksum`).",
            "Official FIDE ELO rating delta engine (`elo::update_elo`) with configurable K-factors.",
            "Built-in command history and replay verification for deterministic audit logs.",
        ],
        "exports": ["Session", "RuleEngine", "LegalMoveGenerator", "TurnResource", "EloRating", "update_elo"],
        "example": '''use open_table_engine::prelude::*;

let session = Session::new(
    SessionId(1),
    42,
    vec![PlayerId(1), PlayerId(2)],
    RuleEngine::new(),
);

// Deterministic 64-bit FNV-1a checksum of the session state ("0x" + 16 hex digits = 18 chars)
let checksum_hex = session.get_state_checksum_hex();
assert_eq!(checksum_hex.len(), 18);
assert!(session.verify_checksum(&checksum_hex));''',
    },
    {
        "name": "open_table_macros",
        "layer": "Core & Engine Foundation",
        "summary_en": "Procedural derive macros (`#[derive(Component)]`, `#[derive(Resource)]`, `#[game_command]`, `#[game_event]`) reducing boilerplate for OpenTable game crates.",
        "summary_es": "Macros procedurales (`#[derive(Component)]`, `#[derive(Resource)]`, `#[game_command]`, `#[game_event]`) para reducir código repetitivo en crates de juegos.",
        "features": [
            "Automatic registration of `open_table_core::Component` and `open_table_core::Resource` traits.",
            "Ergonomic attribute macros for serializable `Command` and `Event` types.",
            "Compile-time diagnostics ensuring `Send + Sync + 'static` bounds for ECS storage.",
        ],
        "exports": ["Component", "Resource", "game_command", "game_event"],
        "example": '''use open_table_macros::{Component, Resource};

#[derive(Debug, Clone, Component)]
pub struct PiecePosition {
    pub x: u8,
    pub y: u8,
}

#[derive(Debug, Default, Resource)]
pub struct TurnCounter(pub u32);''',
    },
    # Network & Transports (5)
    {
        "name": "open_table_qr",
        "layer": "Transports, Relay & Discovery",
        "summary_en": "Compact session invitation payloads and SVG/terminal QR code generation for LAN, Relay room codes, and mobile P2P pairing.",
        "summary_es": "Payloads compactos de invitación de sesión y generación de códigos QR en SVG/terminal para LAN, salas Relay y emparejamiento P2P móvil.",
        "features": [
            "Serializes host endpoint, room code, game identifier, and protocol version into compact QR URIs.",
            "Renders crisp SVG and UTF-8 matrix representations for Godot, CLI, and Web clients.",
            "Validates schema version and checksum before initiating socket handshakes.",
        ],
        "exports": ["QrInvitePayload", "encode_invite_qr_svg", "decode_invite_payload"],
        "example": '''use open_table_qr::QrInvitePayload;

let invite = QrInvitePayload::new_relay("AB12CD", "chess", "wss://relay.example.org");
let uri = invite.to_compact_string();
assert!(uri.contains("AB12CD"));''',
    },
    {
        "name": "open_table_transport_tcp",
        "layer": "Transports, Relay & Discovery",
        "summary_en": "Length-prefixed TCP host/client transport implementation of `open_table_core::Transport` for low-latency LAN multiplayer.",
        "summary_es": "Implementación de transporte TCP host/cliente con prefijo de longitud de `open_table_core::Transport` para multijugador LAN de baja latencia.",
        "features": [
            "Framing with 32-bit big-endian payload length prefix and maximum frame guard.",
            "Non-blocking poll loop suitable for 60 FPS game ticks in Godot and desktop runners.",
            "Automatic peer disconnect detection and clean socket shutdown.",
        ],
        "exports": ["TcpHostTransport", "TcpClientTransport"],
        "example": '''// Bind a LAN host on an ephemeral local port
use open_table_transport_tcp::TcpHostTransport;

let host = TcpHostTransport::bind("127.0.0.1:0").expect("bind ephemeral port");
let local_addr = host.local_addr().unwrap();
println!("Listening for LAN peer on {}", local_addr);''',
    },
    {
        "name": "open_table_transport_websocket",
        "layer": "Transports, Relay & Discovery",
        "summary_en": "WebSocket client transport connecting desktop, mobile, and WebAssembly peers through `open_table_relay` rooms.",
        "summary_es": "Transporte cliente WebSocket que conecta clientes de escritorio, móvil y WebAssembly a través de salas de `open_table_relay`.",
        "features": [
            "Seamless JSON & binary envelope framing compatible with `open_table_relay`.",
            "Supports room creation (`create`), room joining (`join`), spectator mode (`spectate`), and ELO matchmaking (`queue`).",
            "Thread-safe non-blocking receive queue for deterministic session stepping.",
        ],
        "exports": ["WebSocketTransport", "RelayClientConfig"],
        "example": '''use open_table_transport_websocket::RelayClientConfig;

let cfg = RelayClientConfig::new("ws://127.0.0.1:8080", "AB12CD");
assert_eq!(cfg.room_code(), "AB12CD");''',
    },
    {
        "name": "open_table_transport_native_bridge",
        "layer": "Transports, Relay & Discovery",
        "summary_en": "Zero-socket `RawByteLink` bridge adapting Android Nearby Connections, iOS MultipeerConnectivity, and WebRTC DataChannels into `Transport`.",
        "summary_es": "Puente `RawByteLink` sin sockets que adapta Android Nearby Connections, iOS MultipeerConnectivity y WebRTC DataChannels al trait `Transport`.",
        "features": [
            "Decouples platform-specific Bluetooth/Wi-Fi Direct SDK callbacks from the Rust engine.",
            "In-memory ring buffer queues (`push_incoming_bytes`, `drain_outgoing_bytes`) safe across FFI boundaries.",
            "Deterministic packet ordering and peer lifecycle notifications.",
        ],
        "exports": ["NativeBridgeTransport", "RawByteLink"],
        "example": '''use open_table_transport_native_bridge::NativeBridgeTransport;

let mut bridge = NativeBridgeTransport::new();
bridge.push_incoming_frame(b"{\\"cmd\\":\\"MovePiece\\"}".to_vec());
assert_eq!(bridge.pending_incoming_count(), 1);''',
    },
    {
        "name": "open_table_relay",
        "layer": "Transports, Relay & Discovery",
        "summary_en": "Asynchronous WebSocket Relay server with 6-character room codes, spectator broadcasting, and automated ELO-window matchmaking queues.",
        "summary_es": "Servidor Relay WebSocket asíncrono con códigos de sala de 6 caracteres, retransmisión a espectadores y colas de matchmaking automático por ventana ELO.",
        "features": [
            "6-character alphanumeric room allocation with automatic TTL cleanup.",
            "Symmetric ELO matchmaking queue (`|ELO_A - ELO_B| <= min(delta_A, delta_B)`) per game type.",
            "Read-only spectator multiplexing and rate-limited room chat forwarding.",
        ],
        "exports": ["RelayServer", "MatchmakingQueue", "RoomRegistry"],
        "example": '''// Matchmaking symmetry verification:
// Player A (1250 ELO, ±150) matches Player B (1340 ELO, ±200) because |1250 - 1340| = 90 <= min(150, 200)
let delta = (1250_i32 - 1340_i32).abs();
assert!(delta <= 150.min(200));''',
    },
    # Runtime Bridges (2)
    {
        "name": "open_table_godot",
        "layer": "Runtime Bridges (Godot & WebAssembly)",
        "summary_en": "GDExtension C-ABI bridge exposing all 14 canonical board games, 4-level AI with 0-100% randomness, ELO rating, and networking to Godot 4 / Redot 4.",
        "summary_es": "Puente GDExtension C-ABI que expone los 14 juegos canónicos, IA de 4 niveles con aleatoriedad 0-100%, rating ELO y red a Godot 4 / Redot 4.",
        "features": [
            "Single `OpenTableBridge` Godot node managing any of the 14 canonical games.",
            "Configurable AI difficulty (`0..=3`) and randomness percentage (`0..=100%`) with auto-scaling defaults.",
            "Transactional `undo_step()`, `redo_step()`, 64-bit FNV-1a checksum (`get_state_checksum_hex`), and `get_last_ai_telemetry_json()`.",
            "Built-in TCP LAN, WebSocket Relay, and mobile P2P transport bindings for GDScript.",
        ],
        "exports": ["OpenTableBridge"],
        "example": '''# GDScript usage inside Godot 4 / Redot 4:
var bridge = OpenTableBridge.new()
bridge.start_ai_match("chess", 1, 2, 2) # Human P1 vs Hard AI P2 (12% default noise)
bridge.set_ai_randomness_pct(20)        # Custom 20% Top-K decision noise
var checksum: String = bridge.get_state_checksum_hex()''',
    },
    {
        "name": "open_table_wasm",
        "layer": "Runtime Bridges (Godot & WebAssembly)",
        "summary_en": "WebAssembly (`wasm-bindgen`) bridge compiling all 14 canonical Rust board game engines, AI levels, Undo/Redo, FNV-1a checksums, and telemetry for the React Web client.",
        "summary_es": "Puente WebAssembly (`wasm-bindgen`) que compila los 14 motores de juego en Rust, niveles de IA, Undo/Redo, checksums FNV-1a y telemetría para el cliente Web React.",
        "features": [
            "Exposes `WasmGameBridge` to JavaScript/TypeScript via `#[wasm_bindgen]`.",
            "Unified JSON state snapshot, legal move enumeration, and deterministic replay log import/export across all 14 games.",
            "Full support for AI randomness (`set_ai_randomness_pct`), transactional `undo_step`/`redo_step`, `get_state_checksum_hex`, and `get_last_ai_telemetry_json`.",
        ],
        "exports": ["WasmGameBridge"],
        "example": '''use open_table_wasm::WasmGameBridge;

let mut bridge = WasmGameBridge::new();
bridge.start_ai_match("chess", 1, 2, 2);
assert_eq!(bridge.get_ai_randomness_pct(), 12);
assert_eq!(bridge.get_state_checksum_hex().len(), 18);''',
    },
    # 14 Canonical Game Crates
    {
        "name": "chess_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical FIDE Chess engine with castling, en passant, 4-piece promotion, 50-move/threefold repetition draws, Zobrist hashing, ECO opening book, and alpha-beta AI.",
        "summary_es": "Motor canónico de Ajedrez FIDE con enroque, captura al paso, promoción a 4 piezas, tablas por 50 movimientos/triple repetición, Zobrist hashing, libro ECO e IA alfa-beta.",
        "features": [
            "Complete FIDE move validation: pin detection, check/checkmate/stalemate, kingside/queenside castling, en passant, and underpromotion (`Q`, `R`, `B`, `N`).",
            "Automatic draw detection by 50-move rule, threefold Zobrist repetition, insufficient material, and mutual agreement (`OfferDrawCommand` / `AcceptDrawCommand`).",
            "64-bit Zobrist hashing, ECO opening book with randomness rotation (`lookup_session_with_randomness`), and alpha-beta + quiescence search AI.",
        ],
        "exports": ["new_chess_session", "MovePieceCommand", "OfferDrawCommand", "AcceptDrawCommand", "ChessLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use chess_game::{new_chess_session, ai::best_move_with_randomness, Position};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_chess_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(mv.is_some());''',
    },
    {
        "name": "checkers_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 8x8 Draughts / Checkers engine with mandatory capture priority, chained multi-jump continuations, King crowning, 40-move draw clock, and minimax AI.",
        "summary_es": "Motor canónico de Damas 8x8 con captura obligatoria prioritaria, saltos múltiples encadenados, coronación a Dama, reloj de tablas de 40 turnos e IA minimax.",
        "features": [
            "Enforces mandatory capture over simple diagonal advances whenever any jump exists.",
            "Chained multi-jump turn locking (`must_continue_from`) until the capturing sequence completes.",
            "King promotion on the back rank with 4-diagonal mobility and Top-K noise-enabled minimax AI.",
        ],
        "exports": ["new_checkers_session", "MovePieceCommand", "CheckersLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use checkers_game::{new_checkers_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_checkers_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Medium, 25, 42);
assert!(mv.is_some());''',
    },
    {
        "name": "go_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical Go (Weiqi / Baduk) engine supporting 9x9, 13x13, and 19x19 boards, BFS liberty & chain capture, positional Superko, Hoshi handicap, and 6.5 Komi scoring.",
        "summary_es": "Motor canónico de Go (Weiqi / Baduk) para tableros 9x9, 13x13 y 19x19, captura de cadenas por libertades BFS, Superko posicional, hándicap Hoshi y conteo Komi 6.5.",
        "features": [
            "Configurable 9x9, 13x13, and 19x19 intersections with canonical Hoshi handicap placement (2–9 stones).",
            "Breadth-first liberty flood-fill, suicide prohibition, and positional Superko hash history.",
            "Endgame dead-stone marking (`ToggleDeadStoneCommand`), mutual confirmation, and territory + captures + 6.5 Komi scoring.",
        ],
        "exports": ["new_go_session", "PlaceStoneCommand", "PassTurnCommand", "ToggleDeadStoneCommand", "GoLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use go_game::{new_go_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_go_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(action.is_some());''',
    },
    {
        "name": "shogi_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 9x9 Japanese Shogi engine with Komadai capture trays, piece drops, Nifu (double pawn) and Uchifuzume bans, FESA promotion zones, and Sennichite x4 detection.",
        "summary_es": "Motor canónico de Shogi japonés 9x9 con bandejas Komadai, reingreso de piezas (Drops), prohibición Nifu y Uchifuzume, promoción FESA y repetición Sennichite x4.",
        "features": [
            "Full 9x9 board with demoted capture transfers to each player's `Komadai` hand stand.",
            "Strict drop validation: forbids double unpromoted pawns on the same file (`Nifu`), pieces with no future moves, and pawn-drop checkmate (`Uchifuzume`).",
            "Optional and mandatory FESA promotion across the enemy 3-rank zone and 4-fold `Sennichite` draw detection.",
        ],
        "exports": ["new_shogi_session", "MoveShogiPieceCommand", "DropPieceCommand", "ShogiLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use shogi_game::{new_shogi_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_shogi_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(action.is_some());''',
    },
    {
        "name": "xiangqi_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 9x10 Chinese Chess (Xiangqi) engine with 3x3 Palaces, River boundary, Horse/Elephant leg blocking, Cannon screen jumping, and Flying General prohibition.",
        "summary_es": "Motor canónico de Ajedrez Chino (Xiangqi) 9x10 con Palacios 3x3, Río central, bloqueo de Caballo/Elefante, salto de Cañón con pantalla y regla del General Volador.",
        "features": [
            "Authentic 9x10 intersection grid with 3x3 diagonal Palaces for General and Advisors.",
            "Orthogonal leg-blocking for Horse (`Ma`) and diagonal eye-blocking + river restriction for Elephant (`Xiang`).",
            "Cannon (`Pao`) single-screen jump capture and strict Flying General face-to-face prohibition on open files.",
        ],
        "exports": ["new_xiangqi_session", "MoveXiangqiPieceCommand", "XiangqiLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use xiangqi_game::{new_xiangqi_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_xiangqi_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(mv.is_some());''',
    },
    {
        "name": "chinese_checkers_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 121-node hexagram Chinese Checkers engine supporting 2, 3, 4, and 6 players, BFS chained multi-hop paths, anti-camping rules, and axial distance heuristics.",
        "summary_es": "Motor canónico de Damas Chinas sobre estrella hexagonal de 121 casillas para 2, 3, 4 y 6 jugadores, saltos encadenados BFS, regla anti-bloqueo y heurística axial.",
        "features": [
            "121-coordinate axial star topology supporting 2, 3, 4, or 6 symmetric player triangles.",
            "BFS reachability solver for arbitrary-length chained single-marble hops.",
            "Anti-spoiling / anti-blocking validation and directional progress heuristic AI with Top-K noise.",
        ],
        "exports": ["new_chinese_checkers_session", "MoveMarbleCommand", "ChineseCheckersLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use chinese_checkers_game::{new_chinese_checkers_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_chinese_checkers_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Medium, 25, 42);
assert!(mv.is_some());''',
    },
    {
        "name": "backgammon_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 24-point Backgammon engine with doubles (4 moves), mandatory bar re-entry, exact/highest bear-off, Doubling Cube (2..64), and Crawford rule.",
        "summary_es": "Motor canónico de Backgammon de 24 picos con dobles (4 movimientos), reingreso obligatorio desde la barra, Bear-Off, Cubo de Doblaje (2..64) y regla Crawford.",
        "features": [
            "24 points, Center Bar hit/re-entry priority, and home-quadrant Bear-Off validation.",
            "Enforces obligation to play both dice (or the higher die when only one can be legally played) and 4 moves on doubles.",
            "Full Doubling Cube lifecycle (`OfferDoubleCommand`, `AcceptDoubleCommand`, `RejectDoubleCommand`), Gammon/Backgammon multipliers, and 2-ply expectiminimax AI.",
        ],
        "exports": ["new_backgammon_session", "RollDiceCommand", "MoveCheckerCommand", "OfferDoubleCommand", "BackgammonLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use backgammon_game::{new_backgammon_session, RollDiceCommand};
use open_table_core::{PlayerId, SessionId};

let mut session = new_backgammon_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
session.process_command(PlayerId(1), Box::new(RollDiceCommand { player: PlayerId(1) })).unwrap();''',
    },
    {
        "name": "battleship_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 10x10 Naval Combat (Battleship) engine with 5-ship fleet deployment (`[5,4,3,3,2]`), optional `extra_turn_on_hit` salvo rule, rematch command, and Hunt/Target parity AI.",
        "summary_es": "Motor canónico de Batalla Naval 10x10 con despliegue de flota de 5 barcos (`[5,4,3,3,2]`), variante `extra_turn_on_hit`, revancha y heurística IA de paridad Hunt/Target.",
        "features": [
            "Two-phase state machine: Fleet Setup (5 ships of lengths 5, 4, 3, 3, 2 with overlap & boundary checks) and Combat Salvo.",
            "Configurable `extra_turn_on_hit` rule and in-session `RematchCommand`.",
            "Checkerboard parity Hunt mode + directional axis Target mode AI with probability density heatmap.",
        ],
        "exports": ["new_battleship_session", "PlaceShipCommand", "FireShotCommand", "RematchCommand", "BattleshipLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use battleship_game::new_battleship_session;
use open_table_core::{PlayerId, SessionId};

let session = new_battleship_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
assert_eq!(session.current_player(), PlayerId(1));''',
    },
    {
        "name": "ludo_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 52-track + 5-goal Ludo (Parcheesi) engine with 8 safe star squares, triple-six penalty, capture/goal bonus rolls, and threat-aware tactical AI.",
        "summary_es": "Motor canónico de Ludo (Parchís) de 52 casillas + 5 de meta con 8 estrellas seguras, penalización por tres 6 seguidos, tirada extra por captura/meta e IA táctica.",
        "features": [
            "4 tokens per player traversing a 52-square shared ring plus a 5-step private home stretch (`WIN_STEPS = 57`).",
            "8 safe star squares, deployment on roll of 6, bonus rolls on 6/capture/goal, and turn forfeiture on three consecutive sixes.",
            "Tactical AI evaluating capture opportunities, safe-square departures, and 1..6 rear threat exposure.",
        ],
        "exports": ["new_ludo_session", "RollDiceCommand", "MoveTokenCommand", "LudoLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use ludo_game::{new_ludo_session, RollDiceCommand};
use open_table_core::{PlayerId, SessionId};

let mut session = new_ludo_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
session.process_command(PlayerId(1), Box::new(RollDiceCommand { player: PlayerId(1) })).unwrap();''',
    },
    {
        "name": "mille_bornes_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 1000-km Mille Bornes card racing engine with Hazards, Remedies, Speed Limits, max two 200-km cards, 4 Safety shields, and Coup Fourré instant counter-play.",
        "summary_es": "Motor canónico de cartas Mil Millas (1000 km) con Ataques, Defensas, Límites de Velocidad, máximo dos cartas de 200 km, 4 Escudos (Safeties) y respuesta ¡Coup Fourré!.",
        "features": [
            "Authentic deck of Distance (`25`, `50`, `75`, `100`, `200` km), Hazard, Remedy, and 4 unique Safety cards.",
            "Enforces exact 1000 km target, maximum two `200 km` cards per trip, and `Roll` (`Siga`) requirement.",
            "Supports instant `CoupFourreCommand` interruption (+300 bonus points & extra turn) when hit by a matching Hazard.",
        ],
        "exports": ["new_mille_bornes_session", "PlayCardCommand", "DiscardCardCommand", "CoupFourreCommand", "MilleBornesLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use mille_bornes_game::{new_mille_bornes_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_mille_bornes_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(action.is_some());''',
    },
    {
        "name": "monopoly_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 40-square Monopoly economic engine with property auctions, Chance/Community Chest decks, even house/hotel building, mortgages, jail, P2P trades, and ROI AI.",
        "summary_es": "Motor económico canónico de Monopoly de 40 casillas con subastas, mazos de Suerte/Arca Comunal, construcción uniforme de casas/hoteles, hipotecas, cárcel, trueques e IA por ROI.",
        "features": [
            "Complete 40-space board: 8 color groups, 4 Railroads, 2 Utilities, Taxes, Jail (3-doubles, bail, or card), and deterministic Chance/Community Chest decks.",
            "Property refusal triggers live auctions (`PlaceBidCommand`, `PassAuctionCommand`); full mortgage/unmortgage (+10% interest) and player-to-player trade proposals.",
            "Even-build rule enforcement (`BuildHouseCommand` up to Hotel level 5) and cash-reserve ROI AI.",
        ],
        "exports": ["new_monopoly_session", "RollDiceCommand", "BuyPropertyCommand", "BuildHouseCommand", "PlaceBidCommand", "MonopolyLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use monopoly_game::{new_monopoly_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_monopoly_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Expert, 5, 42);
assert!(action.is_some());''',
    },
    {
        "name": "uno_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 108-card UNO engine with Skip, Reverse, Draw Two, Wild, Wild Draw Four challenge verification, mandatory UNO! call/penalty, and Jump-In interception.",
        "summary_es": "Motor canónico de UNO de 108 cartas con Salto, Reversa, +2, Comodín, desafío legal de Wild +4, grito/penalización ¡UNO! e intercepción Jump-In.",
        "features": [
            "Official 108-card distribution across 4 colors (`Red`, `Yellow`, `Green`, `Blue`) plus `Wild` and `WildDrawFour`.",
            "Legal `ChallengeWildDrawFourCommand` inspection (+4 to offender if illegal, +6 to challenger if legal).",
            "Mandatory `CallUnoCommand` / `CatchUnoFailureCommand` (+2 penalty) and identical-card `JumpInCommand` variant.",
        ],
        "exports": ["new_uno_session", "PlayCardCommand", "DrawCardCommand", "CallUnoCommand", "ChallengeWildDrawFourCommand", "UnoLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use uno_game::{new_uno_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_uno_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(action.is_some());''',
    },
    {
        "name": "crisis_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 30-territory, 6-continent global strategy engine (TEG / Risk) with secret objectives, continent bonuses, 3v3 sorted dice combat, 3-card trades, and multi-phase AI.",
        "summary_es": "Motor de estrategia global canónico de 30 territorios y 6 continentes (Crisis / TEG / Risk) con objetivos secretos, bonos continentales, combate 3v3, canje de tarjetas e IA multifase.",
        "features": [
            "30 territories grouped into 6 continents with continent-control army bonuses and secret victory objectives.",
            "Three-phase turn pipeline (`Reinforce`, `Attack` with up to 3v3 sorted dice comparisons, and `Fortify` across adjacent borders).",
            "Country card capture on conquest, escalating 3-card symbol trades (+2 territory ownership bonus), and multi-step planner AI.",
        ],
        "exports": ["new_crisis_session", "PlaceArmiesCommand", "AttackTerritoryCommand", "FortifyTerritoryCommand", "TradeCardsCommand", "CrisisLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use crisis_game::{new_crisis_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_crisis_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let cmd = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(cmd.is_some());''',
    },
    {
        "name": "goose_game",
        "layer": "14 Canonical Board Game Engines",
        "summary_en": "Canonical 63-square spiral Game of the Goose (Juego de la Oca) engine with 13 Geese ('De oca a oca'), Bridges, Inn, Dice, Well, Labyrinth, Prison, Death Skull (58), and exact bounce.",
        "summary_es": "Motor canónico de El Juego de la Oca en espiral de 63 casillas con 13 Ocas, Puentes, Posada, Dados, Pozo, Laberinto, Cárcel, Calavera (58) y rebote exacto.",
        "features": [
            "Complete 63-square spiral board with all canonical hazards and shortcuts: 13 Geese (`5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59`), Bridges (`6 <-> 12`), Dice (`26 <-> 53`).",
            "Penalty squares: Inn (`19`, 1 turn), Well (`31`, trapped until rescued or timeout), Labyrinth (`42 -> 30`), Prison (`52`, 2 turns), and Skull (`58 -> 1`).",
            "Exact arrival at square 63 with backward excess bounce and deterministic dice/reroll AI.",
        ],
        "exports": ["new_goose_session", "RollDiceCommand", "GooseLegalMoveGenerator", "best_move_with_randomness"],
        "example": '''use goose_game::{new_goose_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_goose_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let cmd = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Medium, 25, 42);
assert!(cmd.is_some());''',
    },
]


def generate_crate_readme(crate: dict) -> str:
    name = crate["name"]
    layer = crate["layer"]
    summary_en = crate["summary_en"]
    summary_es = crate["summary_es"]
    features_md = "\n".join(f"- {f}" for f in crate["features"])
    exports_md = ", ".join(f"`{e}`" for e in crate["exports"])
    example_code = crate["example"]
    code_lang = "gdscript" if name == "open_table_godot" else "rust"

    return f"""# `{name}`

[![Crates.io](https://img.shields.io/crates/v/{name}.svg)](https://crates.io/crates/{name})
[![Docs.rs](https://docs.rs/{name}/badge.svg)](https://docs.rs/{name})
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

{LANG_BAR_CRATE}

**Architectural Layer:** {layer} · **Version:** `1.1.0` · **Edition:** `2021`

{summary_en}

> **Español:** {summary_es}

---

## Key Capabilities & Canonical Features

{features_md}

## Primary Exported API

- **Public Symbols:** {exports_md}

## Installation (`Cargo.toml`)

```toml
[dependencies]
{name} = "1.1.0"
```

## Quick Start & Usage Example

```{code_lang}
{example_code}
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
"""


I18N_DOCS = {
    "en": {
        "lang_name": "English",
        "title": "OpenTable SDK v1.1.0 — Deterministic Multi-Game Engine (Rust, Godot 4 & WebAssembly)",
        "intro": (
            "OpenTable SDK is a deterministic, modular turn-based board game workspace written in Rust (24 crates) "
            "with native runtimes for **Godot 4 / Redot 4** (`open_table_godot`) and **React + TypeScript + WebAssembly** (`open_table_wasm`). "
            "Every one of the **14 canonical board games** implements official tournament rules, a legal move generator (`LegalMoveGenerator`), "
            "a 4-level local AI opponent with configurable **0–100% Top-K decision randomness**, transactional **Undo/Redo**, **64-bit FNV-1a state checksums**, "
            "and a **Post-Match Tactical Analyzer** with an interactive **Decision Intensity Heat-Map**."
        ),
        "arch_heading": "## Architecture & The 24 Workspace Crates (`crates.io` Ready)",
        "arch_intro": "The workspace is organized into four clean, decoupled architectural layers:",
        "layers": [
            ("1. Core & ECS Runtime (`open_table_core`, `open_table_engine`, `open_table_macros`)",
             "Pure domain types, serializable `Command`/`Event` contracts, seeded `ChaCha8Rng`, `bevy_ecs`-backed `Session`, transactional `undo_step`/`redo_step`, FIDE K=32 ELO engine, and 64-bit FNV-1a checksums."),
            ("2. Network Transports, QR & Relay (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)",
             "Length-prefixed LAN TCP, WebSocket Relay with 6-character room codes, spectator broadcasting, automated ELO-window matchmaking queues, SVG QR invites, and mobile P2P `RawByteLink`."),
            ("3. Runtime Bridges (`open_table_godot`, `open_table_wasm`)",
             "GDExtension C-ABI node (`OpenTableBridge`) for Godot 4 / Redot 4 and `#[wasm_bindgen]` bridge (`WasmGameBridge`) for React + TypeScript + PWA."),
            ("4. 14 Canonical Board Game Engines (`*_game`)",
             "Self-contained Rust crates for Chess, Checkers, Go, Shogi, Xiangqi, Chinese Checkers, Backgammon, Battleship, Ludo, Mille Bornes, Monopoly, UNO, Crisis/Risk, and Game of the Goose."),
        ],
        "games_heading": "## 14 Canonical Board Games Matrix",
        "whats_new_heading": "## What's New in v1.1.0",
        "whats_new_items": [
            "**AI Randomness / Noise Factor (`0–100%`)**: Auto-scaled by difficulty (`Easy=45%`, `Medium=25%`, `Hard=12%`, `Expert=5%`) with live UI slider and Top-K score band perturbation across all 14 games.",
            "**Transactional Undo/Redo & 64-Bit FNV-1a Checksums**: Full snapshot rollback/re-apply (`undo_step`, `redo_step`) and deterministic state checksums (`get_state_checksum_hex`) to verify zero desynchronization.",
            "**AI Decision Intensity Heat-Map**: Post-Match Analyzer overlay with live toggle between **Selected Turn (`#ply`)** and **Cumulative Match (`N turns`)**, adapted to the topology of all 14 games.",
        ],
        "quickstart_heading": "## Quick Start (Rust, WebAssembly & Godot 4)",
    },
    "es": {
        "lang_name": "Español",
        "title": "OpenTable SDK v1.1.0 — Motor Determinista Multijuego (Rust, Godot 4 y WebAssembly)",
        "intro": (
            "OpenTable SDK es un workspace modular y determinista de juegos de mesa por turnos escrito en Rust (24 crates) "
            "con soporte nativo para **Godot 4 / Redot 4** (`open_table_godot`) y **React + TypeScript + WebAssembly** (`open_table_wasm`). "
            "Cada uno de los **14 juegos de mesa canónicos** implementa reglas oficiales de torneo, generador de jugadas legales (`LegalMoveGenerator`), "
            "oponente de IA local de 4 niveles con **factor de aleatoriedad Top-K configurable (0–100%)**, **Undo/Redo transaccional**, **checksums FNV-1a de 64 bits** "
            "y un **Analizador Táctico Post-Partida** con **Mapa de Calor de Intensidad de Decisión**."
        ),
        "arch_heading": "## Arquitectura y los 24 Crates del Workspace (`crates.io`)",
        "arch_intro": "El workspace está organizado en cuatro capas arquitectónicas desacopladas:",
        "layers": [
            ("1. Núcleo y Motor ECS (`open_table_core`, `open_table_engine`, `open_table_macros`)",
             "Tipos de dominio puros, contratos serializables `Command`/`Event`, PRNG determinista `ChaCha8Rng`, `Session` sobre `bevy_ecs`, pilas `undo_step`/`redo_step`, cálculo ELO FIDE K=32 y checksums FNV-1a de 64 bits."),
            ("2. Transportes de Red, QR y Relay (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)",
             "TCP LAN con prefijo de longitud, servidor Relay WebSocket con códigos de 6 caracteres, modo espectador, cola de matchmaking automático por ventana ELO, invitaciones QR SVG y puente móvil P2P `RawByteLink`."),
            ("3. Puentes de Ejecución (`open_table_godot`, `open_table_wasm`)",
             "Nodo GDExtension C-ABI (`OpenTableBridge`) para Godot 4 / Redot 4 y puente `#[wasm_bindgen]` (`WasmGameBridge`) para React + TypeScript + PWA."),
            ("4. 14 Motores de Juegos de Mesa Canónicos (`*_game`)",
             "Crates independientes en Rust para Ajedrez, Damas, Go, Shogi, Xiangqi, Damas Chinas, Backgammon, Batalla Naval, Ludo, Mil Millas, Monopoly, UNO, Crisis/TEG y El Juego de la Oca."),
        ],
        "games_heading": "## Matriz de los 14 Juegos de Mesa Canónicos",
        "whats_new_heading": "## Novedades de la Versión v1.1.0",
        "whats_new_items": [
            "**Factor de Aleatoriedad / Ruido IA (`0–100%`)**: Auto-escalado por dificultad (`Fácil=45%`, `Media=25%`, `Difícil=12%`, `Maestra=5%`) con control deslizante en vivo y perturbación Top-K en los 14 juegos.",
            "**Undo/Redo Transaccional y Checksums FNV-1a de 64 Bits**: Retroceso y avance transaccional (`undo_step`, `redo_step`) y firma determinista hexadecimal de 16 caracteres (`get_state_checksum_hex`).",
            "**Mapa de Calor de Intensidad de Decisión IA**: Superposición en el Analizador Post-Partida con alcance conmutable entre **Turno Seleccionado (`#ply`)** y **Partida Acumulada (`N turnos`)**, adaptada a la topología de los 14 juegos.",
        ],
        "quickstart_heading": "## Inicio Rápido (Rust, WebAssembly y Godot 4)",
    },
    "pt-BR": {
        "lang_name": "Português (Brasil)",
        "title": "OpenTable SDK v1.1.0 — Motor Determinístico Multijogo (Rust, Godot 4 e WebAssembly)",
        "intro": (
            "O OpenTable SDK é um workspace modular e determinístico de jogos de tabuleiro por turnos escrito em Rust (24 crates) "
            "com suporte nativo para **Godot 4 / Redot 4** (`open_table_godot`) e **React + TypeScript + WebAssembly** (`open_table_wasm`). "
            "Cada um dos **14 jogos de tabuleiro canônicos** implementa regras oficiais de torneio, gerador de jogadas legais (`LegalMoveGenerator`), "
            "oponente de IA local de 4 níveis com **fator de aleatoriedade Top-K configurável (0–100%)**, **Undo/Redo transacional**, **checksums FNV-1a de 64 bits** "
            "e um **Analisador Tático Pós-Partida** com **Mapa de Calor de Intensidade de Decisão**."
        ),
        "arch_heading": "## Arquitetura e os 24 Crates do Workspace (`crates.io`)",
        "arch_intro": "O workspace é dividido em quatro camadas arquiteturais desacopladas:",
        "layers": [
            ("1. Núcleo e Motor ECS (`open_table_core`, `open_table_engine`, `open_table_macros`)",
             "Tipos de domínio puros, contratos serializáveis `Command`/`Event`, PRNG determinístico `ChaCha8Rng`, `Session` sobre `bevy_ecs`, pilhas `undo_step`/`redo_step`, cálculo ELO FIDE K=32 e checksums FNV-1a de 64 bits."),
            ("2. Transportes de Rede, QR e Relay (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)",
             "TCP LAN, servidor Relay WebSocket com salas de 6 caracteres, modo espectador, fila de matchmaking automático por faixa ELO, convites QR em SVG e ponte móvel P2P `RawByteLink`."),
            ("3. Pontes de Execução (`open_table_godot`, `open_table_wasm`)",
             "Nó GDExtension C-ABI (`OpenTableBridge`) para Godot 4 / Redot 4 e ponte `#[wasm_bindgen]` (`WasmGameBridge`) para React + TypeScript + PWA."),
            ("4. 14 Motores de Jogos de Tabuleiro Canônicos (`*_game`)",
             "Crates independentes em Rust para Xadrez, Damas, Go, Shogi, Xiangqi, Damas Chinesas, Gamão (Backgammon), Batalha Naval, Ludo, Mil Milhas, Monopoly, UNO, Crisis/Risk e Jogo da Gansa."),
        ],
        "games_heading": "## Matriz dos 14 Jogos de Tabuleiro Canônicos",
        "whats_new_heading": "## Novidades da Versão v1.1.0",
        "whats_new_items": [
            "**Fator de Aleatoriedade / Ruído da IA (`0–100%`)**: Escalonado automaticamente por dificuldade (`Fácil=45%`, `Médio=25%`, `Difícil=12%`, `Mestre=5%`) com controle deslizante e perturbação Top-K nos 14 jogos.",
            "**Undo/Redo Transacional e Checksums FNV-1a de 64 Bits**: Reversão e reaplicação de estados (`undo_step`, `redo_step`) e assinatura hexadecimal determinística (`get_state_checksum_hex`).",
            "**Mapa de Calor de Intensidade de Decisão da IA**: Sobreposição no Analisador Pós-Partida alternável entre **Turno Selecionado (`#ply`)** e **Partida Acumulada (`N turnos`)**, adaptada à topologia dos 14 jogos.",
        ],
        "quickstart_heading": "## Início Rápido (Rust, WebAssembly e Godot 4)",
    },
    "fr": {
        "lang_name": "Français",
        "title": "OpenTable SDK v1.1.0 — Moteur Déterministe Multi-Jeux (Rust, Godot 4 et WebAssembly)",
        "intro": (
            "OpenTable SDK est un workspace modulaire et déterministe de jeux de société au tour par tour écrit en Rust (24 crates), "
            "avec prise en charge native de **Godot 4 / Redot 4** (`open_table_godot`) et **React + TypeScript + WebAssembly** (`open_table_wasm`). "
            "Chacun des **14 jeux de société canoniques** implémente les règles officielles de tournoi, un générateur de coups légaux (`LegalMoveGenerator`), "
            "une IA locale à 4 niveaux avec **facteur d'aléatoire Top-K configurable (0–100 %)**, **Undo/Redo transactionnel**, **sommes de contrôle FNV-1a 64 bits** "
            "et un **Analyseur Tactique d'Après-Partie** doté d'une **Carte Thermique d'Intensité de Décision**."
        ),
        "arch_heading": "## Architecture et les 24 Crates du Workspace (`crates.io`)",
        "arch_intro": "Le workspace est structuré en quatre couches architecturales découplées :",
        "layers": [
            ("1. Noyau et Moteur ECS (`open_table_core`, `open_table_engine`, `open_table_macros`)",
             "Types fondamentaux, contrats sérialisables `Command`/`Event`, PRNG déterministe `ChaCha8Rng`, `Session` basée sur `bevy_ecs`, piles `undo_step`/`redo_step`, calcul ELO FIDE K=32 et hachage FNV-1a 64 bits."),
            ("2. Transports Réseau, QR et Relais (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)",
             "TCP LAN, serveur Relais WebSocket avec codes de salle à 6 caractères, mode spectateur, file de matchmaking automatique par fenêtre ELO, invitations QR SVG et pont mobile P2P `RawByteLink`."),
            ("3. Ponts d'Exécution (`open_table_godot`, `open_table_wasm`)",
             "Nœud GDExtension C-ABI (`OpenTableBridge`) pour Godot 4 / Redot 4 et pont `#[wasm_bindgen]` (`WasmGameBridge`) pour React + TypeScript + PWA."),
            ("4. 14 Moteurs de Jeux de Société Canoniques (`*_game`)",
             "Crates Rust autonomes pour Échecs, Dames, Go, Shogi, Xiangqi, Dames Chinoises, Backgammon, Bataille Navale, Ludo, Mille Bornes, Monopoly, UNO, Crisis/Risk et Jeu de l'Oie."),
        ],
        "games_heading": "## Matrice des 14 Jeux de Société Canoniques",
        "whats_new_heading": "## Nouveautés de la Version v1.1.0",
        "whats_new_items": [
            "**Facteur d'Aléatoire / Bruit IA (`0–100 %`)** : Calibré automatiquement selon la difficulté (`Facile=45 %`, `Moyen=25 %`, `Difficile=12 %`, `Expert=5 %`) avec curseur interactif et perturbation Top-K sur les 14 jeux.",
            "**Undo/Redo Transactionnel et Sommes de Contrôle FNV-1a 64 Bits** : Annulation/rétablissement d'état (`undo_step`, `redo_step`) et empreinte hexadécimale déterministe (`get_state_checksum_hex`).",
            "**Carte Thermique d'Intensité de Décision IA** : Superposition dans l'Analyseur d'Après-Partie commutable entre **Tour Sélectionné (`#ply`)** et **Partie Cumulée (`N tours`)**, adaptée à la topologie des 14 jeux.",
        ],
        "quickstart_heading": "## Démarrage Rapide (Rust, WebAssembly et Godot 4)",
    },
    "de": {
        "lang_name": "Deutsch",
        "title": "OpenTable SDK v1.1.0 — Deterministische Multi-Spiel-Engine (Rust, Godot 4 & WebAssembly)",
        "intro": (
            "Das OpenTable SDK ist ein modularer, deterministischer Rundenstrategie- und Brettspiel-Workspace in Rust (24 Crates) "
            "mit nativer Unterstützung für **Godot 4 / Redot 4** (`open_table_godot`) und **React + TypeScript + WebAssembly** (`open_table_wasm`). "
            "Jedes der **14 kanonischen Brettspiele** implementiert offizielle Turnierregeln, einen Generator für legale Züge (`LegalMoveGenerator`), "
            "eine 4-stufige lokale KI mit **konfigurierbarem Top-K-Zufallsfaktor (0–100 %)**, **transaktionales Undo/Redo**, **deterministische 64-Bit-FNV-1a-Prüfsummen** "
            "sowie einen **Post-Match-Taktikanalysator** mit interaktiver **Entscheidungsintensitäts-Heatmap**."
        ),
        "arch_heading": "## Architektur & Die 24 Workspace-Crates (`crates.io`)",
        "arch_intro": "Der Workspace gliedert sich in vier sauber entkoppelte Architekturschichten:",
        "layers": [
            ("1. Kern & ECS-Laufzeit (`open_table_core`, `open_table_engine`, `open_table_macros`)",
             "Reine Domänentypen, serialisierbare `Command`/`Event`-Verträge, deterministischer `ChaCha8Rng`, `bevy_ecs`-gestützte `Session`, `undo_step`/`redo_step`, FIDE K=32 ELO-Berechnung und 64-Bit-FNV-1a-Prüfsummen."),
            ("2. Netzwerktransporte, QR & Relay (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)",
             "LAN-TCP, WebSocket-Relay-Server mit 6-stelligen Raumcodes, Zuschauermodus, automatische ELO-Matchmaking-Warteschlange, SVG-QR-Einladungen und mobile P2P-`RawByteLink`-Brücke."),
            ("3. Laufzeit-Brücken (`open_table_godot`, `open_table_wasm`)",
             "GDExtension C-ABI-Knoten (`OpenTableBridge`) für Godot 4 / Redot 4 und `#[wasm_bindgen]`-Brücke (`WasmGameBridge`) für React + TypeScript + PWA."),
            ("4. 14 Kanonische Brettspiel-Engines (`*_game`)",
             "Eigenständige Rust-Crates für Schach, Dame, Go, Shogi, Xiangqi, Sternhalma (Chinesische Dame), Backgammon, Schiffe Versenken, Ludo, Mille Bornes, Monopoly, UNO, Crisis/Risiko und Gänsespiel."),
        ],
        "games_heading": "## Matrix der 14 Kanonischen Brettspiele",
        "whats_new_heading": "## Neuigkeiten in Version v1.1.0",
        "whats_new_items": [
            "**KI-Zufallsfaktor / Entscheidungsrauschen (`0–100 %`)**: Automatisch nach Schwierigkeitsgrad skaliert (`Leicht=45 %`, `Mittel=25 %`, `Schwer=12 %`, `Experte=5 %`) mit Live-Schieberegler und Top-K-Bandstörung in allen 14 Spielen.",
            "**Transaktionales Undo/Redo & 64-Bit-FNV-1a-Prüfsummen**: Vollständiges Zurücksetzen/Wiederherstellen (`undo_step`, `redo_step`) und deterministische 16-stellige Hex-Prüfsummen (`get_state_checksum_hex`).",
            "**KI-Entscheidungsintensitäts-Heatmap**: Überlagerung im Post-Match-Analysator, umschaltbar zwischen **Ausgewähltem Zug (`#ply`)** und **Kumulierter Partie (`N Züge`)**, angepasst an die Topologie aller 14 Spiele.",
        ],
        "quickstart_heading": "## Schnellstart (Rust, WebAssembly & Godot 4)",
    },
    "zh-CN": {
        "lang_name": "简体中文",
        "title": "OpenTable SDK v1.1.0 — 确定性多棋牌游戏引擎 (Rust, Godot 4 与 WebAssembly)",
        "intro": (
            "OpenTable SDK 是一个基于 Rust 编写的模块化、确定性回合制桌游引擎工作区（共 24 个 Crate），"
            "原生支持 **Godot 4 / Redot 4** (`open_table_godot`) 与 **React + TypeScript + WebAssembly** (`open_table_wasm`)。"
            "套件中的全部 **14 款标准桌面游戏** 均实现了官方锦标赛规则、合法着法生成器 (`LegalMoveGenerator`)、"
            "支持 **0–100% Top-K 决策随机度调节** 的 4 级本地 AI、**事务级撤销/重做 (Undo/Redo)**、**64 位 FNV-1a 状态校验和**，"
            "以及带 **AI 决策强度热力图 (Decision Intensity Heat-Map)** 的 **赛后战术复盘分析器**。"
        ),
        "arch_heading": "## 架构设计与 24 个工作区 Crate (`crates.io` 标准)",
        "arch_intro": "整个工作区划分为四个高内聚、低耦合的架构层级：",
        "layers": [
            ("1. 核心与 ECS 运行时 (`open_table_core`, `open_table_engine`, `open_table_macros`)",
             "纯领域类型、可序列化 `Command`/`Event` 契约、确定性种子 `ChaCha8Rng`、基于 `bevy_ecs` 的 `Session`、事务级 `undo_step`/`redo_step`、FIDE K=32 ELO 积分计算器及 64 位 FNV-1a 校验和。"),
            ("2. 网络传输、二维码与中继 (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)",
             "局域网长度前缀 TCP、带 6 位房间码的 WebSocket Relay 服务器、实时观战广播、基于 ELO 窗口的自动匹配队列、SVG 二维码邀请以及移动端 P2P `RawByteLink` 桥接。"),
            ("3. 跨平台运行时桥接 (`open_table_godot`, `open_table_wasm`)",
             "面向 Godot 4 / Redot 4 的 GDExtension C-ABI 节点 (`OpenTableBridge`) 以及面向 React + TypeScript + PWA 的 `#[wasm_bindgen]` 桥接器 (`WasmGameBridge`)。"),
            ("4. 14 款标准棋牌游戏引擎 (`*_game`)",
             "独立的 Rust Crate，涵盖国际象棋、西洋跳棋、围棋、日本将棋、中国象棋、中国跳棋、双陆棋、海战棋、飞行棋 (Ludo)、千里之行、大富翁、UNO、全球危机 (TEG/Risk) 与鹅棋。"),
        ],
        "games_heading": "## 14 款标准桌面游戏矩阵",
        "whats_new_heading": "## v1.1.0 版本核心更新",
        "whats_new_items": [
            "**AI 随机度 / 噪声因子 (`0–100%`)**：按难度自动校准默认值（简单 `45%`、中等 `25%`、困难 `12%`、大师 `5%`），支持 UI 滑块实时调节与全部 14 款游戏的 Top-K 分值带扰动。",
            "**事务级 Undo/Redo 与 64 位 FNV-1a 状态校验和**：支持完整快照回滚与重放 (`undo_step`, `redo_step`) 以及 16 位十六进制确定性状态签名 (`get_state_checksum_hex`)。",
            "**AI 决策强度热力图 (Decision Intensity Heat-Map)**：集成于赛后复盘分析器，支持在 **当前选中回合 (`#ply`)** 与 **整局累计分布 (`N 回合`)** 之间一键切换，并适配全部 14 款游戏的棋盘拓扑。",
        ],
        "quickstart_heading": "## 快速开始 (Rust, WebAssembly 与 Godot 4)",
    },
    "ja": {
        "lang_name": "日本語",
        "title": "OpenTable SDK v1.1.0 — 決定論的マルチボードゲームエンジン (Rust, Godot 4 & WebAssembly)",
        "intro": (
            "OpenTable SDK は、Rust で記述されたモジュラーかつ決定論的なターン制ボードゲームエンジン・ワークスペース（全 24 クレート）であり、"
            "**Godot 4 / Redot 4** (`open_table_godot`) および **React + TypeScript + WebAssembly** (`open_table_wasm`) のネイティブ実行環境を備えています。"
            "収録されている **全 14 種類の公式ボードゲーム** すべてに、公式トーナメントルール、合法手ジェネレーター (`LegalMoveGenerator`)、"
            "**0〜100% の Top-K 意思決定ランダム性（ノイズ）** を調整可能な 4 段階のローカル AI、**トランザクション対応 Undo/Redo**、**64 ビット FNV-1a 状態チェックサム**、"
            "そして **AI 意思決定強度ヒートマップ** を搭載した **対局後戦術アナライザー** が実装されています。"
        ),
        "arch_heading": "## アーキテクチャと全 24 クレート構成 (`crates.io` 対応)",
        "arch_intro": "ワークスペースは疎結合な 4 つのアーキテクチャ層で構成されています：",
        "layers": [
            ("1. コア＆ECS ランタイム (`open_table_core`, `open_table_engine`, `open_table_macros`)",
             "純粋なドメイン型、シリアライズ可能な `Command`/`Event` 契約、シード付き決定論的 `ChaCha8Rng`、`bevy_ecs` ベースの `Session`、`undo_step`/`redo_step`、FIDE K=32 ELO 計算機、および 64 ビット FNV-1a チェックサム。"),
            ("2. ネットワーク通信・QR・リレー (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)",
             "LAN TCP 通信、6 桁ルームコード付き WebSocket リレーサーバー、観戦ブロードキャスト、ELO 範囲自動マッチメイキングキュー、SVG QR 招待生成、およびモバイル P2P `RawByteLink` ブリッジ。"),
            ("3. ランタイムブリッジ (`open_table_godot`, `open_table_wasm`)",
             "Godot 4 / Redot 4 向け GDExtension C-ABI ノード (`OpenTableBridge`) と React + TypeScript + PWA 向け `#[wasm_bindgen]` ブリッジ (`WasmGameBridge`)。"),
            ("4. 全 14 公式ボードゲームエンジン (`*_game`)",
             "チェス、チェッカー、囲碁、将棋、シャンチー（中国象棋）、チャイニーズチェッカー、バックギャモン、バトルシップ（海戦ゲーム）、ルドー、ミルボーン、モノポリー、UNO、Crisis/リスク、鵞鳥のゲームの独立クレート群。"),
        ],
        "games_heading": "## 全 14 公式ボードゲーム一覧",
        "whats_new_heading": "## v1.1.0 の主な新機能",
        "whats_new_items": [
            "**AI ランダム性 / ノイズ係数 (`0〜100%`)**：難易度に応じて自動設定（初級 `45%`、中級 `25%`、上級 `12%`、マスター `5%`）され、UI スライダーと Top-K スコア帯摂動により全 14 ゲームで自然な多様性を実現。",
            "**トランザクション対応 Undo/Redo ＆ 64 ビット FNV-1a チェックサム**：スナップショットによる完全なロールバック／再適用 (`undo_step`, `redo_step`) と 16 桁 16 進数の決定論的状態ハッシュ (`get_state_checksum_hex`)。",
            "**AI 意思決定強度ヒートマップ**：対局後アナライザーに搭載され、**選択中の手番 (`#ply`)** と **対局全体の累積 (`N 手`)** をワンクリックで切り替え可能。全 14 ゲームの盤面トポロジーに完全対応。",
        ],
        "quickstart_heading": "## クイックスタート (Rust, WebAssembly & Godot 4)",
    },
}


def build_i18n_hub_markdown(lang_code: str, spec: dict) -> str:
    lang_links = (
        "**Languages / Idiomas:** "
        "[English](../en/README.md) · "
        "[Español](../es/README.md) · "
        "[Português (BR)](../pt-BR/README.md) · "
        "[Français](../fr/README.md) · "
        "[Deutsch](../de/README.md) · "
        "[简体中文](../zh-CN/README.md) · "
        "[日本語](../ja/README.md) · "
        "[Root README](../../../README.md)"
    )

    layers_md = "\n\n".join(f"### {title}\n{desc}" for title, desc in spec["layers"])
    whats_new_md = "\n".join(f"- {item}" for item in spec["whats_new_items"])

    crates_rows = "\n".join(
        f"| `{c['name']}` | {c['layer']} | {c['summary_en']} | [`crates.io`](https://crates.io/crates/{c['name']}) · [`README`](../../../{c['name']}/README.md) |"
        for c in CRATES_METADATA
    )

    return f"""# {spec['title']}

[![CI](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml)
[![Crates.io](https://img.shields.io/crates/v/open_table_core.svg)](https://crates.io/crates/open_table_core)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../../../LICENSE)
[![Games: 14/14](https://img.shields.io/badge/games-14%2F14-brightgreen.svg)](#)

{lang_links}

---

{spec['intro']}

{spec['whats_new_heading']}

{whats_new_md}

---

{spec['arch_heading']}

{spec['arch_intro']}

{layers_md}

### Complete Crates.io Workspace Directory (24 Crates)

| Crate | Architectural Layer | Description (crates.io) | Links |
|---|---|---|---|
{crates_rows}

---

{spec['quickstart_heading']}

### 1. Rust Workspace & Unit Tests

```bash
# Run all 458+ deterministic unit and canonical rules tests across all 24 crates
cargo test --workspace

# Generate rustdoc HTML documentation for crates.io / docs.rs verification
cargo doc --workspace --no-deps
```

### 2. Using a Game Engine Crate Directly in Rust (`Cargo.toml`)

```toml
[dependencies]
open_table_core = "1.1.0"
open_table_engine = "1.1.0"
chess_game = "1.1.0"
```

```rust
use chess_game::{{new_chess_session, ai::best_move_with_randomness}};
use open_table_core::{{AiDifficulty, PlayerId, SessionId}};

fn main() {{
    let mut session = new_chess_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
    // Pick best move for White (Player 1) on Hard difficulty with 12% Top-K noise
    if let Some(cmd) = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42) {{
        session.process_command(PlayerId(1), Box::new(cmd)).unwrap();
    }}
    println!("State FNV-1a Checksum: {{}}", session.get_state_checksum_hex(b"chess_turn_1"));
}}
```

### 3. React + TypeScript + WebAssembly Client (`web_client`)

```bash
# Verify TypeScript types, Vitest test suites (14 games + i18n + diagnostics), and production PWA build
bash tools/verify_web_client.sh
```
"""


def update_root_readme():
    root_readme_path = SDK_ROOT / "README.md"
    existing_es = root_readme_path.read_text(encoding="utf-8")

    # Strip previous English top section if re-running idempotently
    marker = "<!-- SPANISH_CANONICAL_REFERENCE_START -->"
    if marker in existing_es:
        existing_es = existing_es.split(marker, 1)[1].lstrip()

    en_spec = I18N_DOCS["en"]
    crates_rows = "\n".join(
        f"| [`{c['name']}`](./{c['name']}/README.md) | {c['layer']} | `1.1.0` | {c['summary_en']} |"
        for c in CRATES_METADATA
    )

    english_header = f"""# OpenTable SDK v1.1.0 — Deterministic Board Game Engine Suite (Rust, Godot 4 & WebAssembly)

[![CI](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/joduranvillan/games_tables_sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/joduranvillan/games_tables_sdk)
[![Crates.io](https://img.shields.io/crates/v/open_table_core.svg)](https://crates.io/crates/open_table_core)
[![Docs.rs](https://docs.rs/open_table_core/badge.svg)](https://docs.rs/open_table_core)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3_or_later-blue.svg)](./LICENSE)
[![Games Implemented](https://img.shields.io/badge/games-14%2F14-brightgreen.svg)](#14-canonical-board-games-suite)

{LANG_BAR_ROOT}

---

{en_spec['intro']}

## Highlights & What's New in `v1.1.0`

- **AI Randomness / Decision Noise (`0–100%`)**: Auto-scaled by difficulty (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`) with live UI slider control and Top-K score band perturbation (`AiDifficulty::select_top_k_with_noise`) across all 14 games.
- **Transactional Undo/Redo & 64-Bit FNV-1a Checksums**: Snapshot rollback/re-apply (`undo_step`, `redo_step`) and deterministic 64-bit FNV-1a state signatures (`get_state_checksum_hex`) across Rust, Godot, and WebAssembly.
- **AI Decision Intensity Heat-Map Overlay**: Integrated into the Post-Match Tactical Analyzer (`PostMatchAnalyzerPanel.tsx`) with a live toggle between **Selected Turn (`#ply`)** and **Cumulative Match (`N turns`)**, adapted to the board topology of all 14 games.
- **Multilingual Native Documentation (7 Languages) & Crates.io Ready**: Every one of the 24 crates includes an English `README.md` for `crates.io` / `docs.rs`, paired with full native guides in **English, Español, Português (BR), Français, Deutsch, 简体中文, and 日本語** under [`docs/i18n/`](./docs/i18n/).

## Complete Workspace Directory — 24 Crates (`crates.io` & `docs.rs`)

| Crate | Layer | Version | Description |
|---|---|:---:|---|
{crates_rows}

## Quick Verification Commands

```bash
# 1. Run all 458+ Rust workspace tests and canonical rule suites
cargo test --workspace

# 2. Verify workspace structure, Godot smoke suites, and generate TEST_SUMMARY.md
bash tools/verify_workspace.sh && bash tools/generate_test_summary.sh

# 3. Verify React + TypeScript + WebAssembly Web Client (Vitest + PWA build)
bash tools/verify_web_client.sh
```

---

{marker}
"""
    root_readme_path.write_text(english_header + existing_es, encoding="utf-8")


def main():
    # 1. Generate English README.md for each of the 24 crates
    for crate in CRATES_METADATA:
        crate_dir = SDK_ROOT / crate["name"]
        crate_dir.mkdir(parents=True, exist_ok=True)
        readme_path = crate_dir / "README.md"
        readme_path.write_text(generate_crate_readme(crate), encoding="utf-8")

    # 2. Generate 7-language documentation hubs in docs/i18n/<lang>/README.md
    i18n_root = SDK_ROOT / "docs" / "i18n"
    for lang_code, spec in I18N_DOCS.items():
        lang_dir = i18n_root / lang_code
        lang_dir.mkdir(parents=True, exist_ok=True)
        (lang_dir / "README.md").write_text(
            build_i18n_hub_markdown(lang_code, spec), encoding="utf-8"
        )

    # 3. Create docs/i18n/README.md index and CRATES_IO_PUBLISHING_GUIDE.md
    i18n_index = f"""# OpenTable SDK — Multilingual Documentation Hub (7 Native Languages)

{LANG_BAR_ROOT.replace('./docs/i18n/', './')}

## Available Native Languages

| Code | Language (Native) | Documentation Entry Point | Status |
|:---:|---|---|---|
| `en` | **English** (Default for `crates.io` & `docs.rs`) | [`docs/i18n/en/README.md`](./en/README.md) | 100% Complete (24/24 Crates) |
| `es` | **Español** | [`docs/i18n/es/README.md`](./es/README.md) | 100% Complete (24/24 Crates) |
| `pt-BR` | **Português (Brasil)** | [`docs/i18n/pt-BR/README.md`](./pt-BR/README.md) | 100% Complete (24/24 Crates) |
| `fr` | **Français** | [`docs/i18n/fr/README.md`](./fr/README.md) | 100% Complete (24/24 Crates) |
| `de` | **Deutsch** | [`docs/i18n/de/README.md`](./de/README.md) | 100% Complete (24/24 Crates) |
| `zh-CN` | **简体中文** | [`docs/i18n/zh-CN/README.md`](./zh-CN/README.md) | 100% Complete (24/24 Crates) |
| `ja` | **日本語** | [`docs/i18n/ja/README.md`](./ja/README.md) | 100% Complete (24/24 Crates) |
"""
    (i18n_root / "README.md").write_text(i18n_index, encoding="utf-8")

    # 4. Update root README.md with 7-language bar + English crates.io overview + Spanish canonical reference
    update_root_readme()
    print("Successfully generated 24 crate English READMEs and 7-language documentation hubs.")


if __name__ == "__main__":
    main()
