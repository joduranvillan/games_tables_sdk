# OpenTable SDK v1.1.0 — Moteur Déterministe Multi-Jeux (Rust, Godot 4 et WebAssembly)

[![CI](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml)
[![Crates.io](https://img.shields.io/crates/v/open_table_core.svg)](https://crates.io/crates/open_table_core)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../../../LICENSE)
[![Games: 14/14](https://img.shields.io/badge/games-14%2F14-brightgreen.svg)](#)

**Languages / Idiomas:** [English](../en/README.md) · [Español](../es/README.md) · [Português (BR)](../pt-BR/README.md) · [Français](../fr/README.md) · [Deutsch](../de/README.md) · [简体中文](../zh-CN/README.md) · [日本語](../ja/README.md) · [Root README](../../../README.md)

---

OpenTable SDK est un workspace modulaire et déterministe de jeux de société au tour par tour écrit en Rust (24 crates), avec prise en charge native de **Godot 4 / Redot 4** (`open_table_godot`) et **React + TypeScript + WebAssembly** (`open_table_wasm`). Chacun des **14 jeux de société canoniques** implémente les règles officielles de tournoi, un générateur de coups légaux (`LegalMoveGenerator`), une IA locale à 4 niveaux avec **facteur d'aléatoire Top-K configurable (0–100 %)**, **Undo/Redo transactionnel**, **sommes de contrôle FNV-1a 64 bits** et un **Analyseur Tactique d'Après-Partie** doté d'une **Carte Thermique d'Intensité de Décision**.

## Nouveautés de la Version v1.1.0

- **Facteur d'Aléatoire / Bruit IA (`0–100 %`)** : Calibré automatiquement selon la difficulté (`Facile=45 %`, `Moyen=25 %`, `Difficile=12 %`, `Expert=5 %`) avec curseur interactif et perturbation Top-K sur les 14 jeux.
- **Undo/Redo Transactionnel et Sommes de Contrôle FNV-1a 64 Bits** : Annulation/rétablissement d'état (`undo_step`, `redo_step`) et empreinte hexadécimale déterministe (`get_state_checksum_hex`).
- **Carte Thermique d'Intensité de Décision IA** : Superposition dans l'Analyseur d'Après-Partie commutable entre **Tour Sélectionné (`#ply`)** et **Partie Cumulée (`N tours`)**, adaptée à la topologie des 14 jeux.

---

## Architecture et les 24 Crates du Workspace (`crates.io`)

Le workspace est structuré en quatre couches architecturales découplées :

### 1. Noyau et Moteur ECS (`open_table_core`, `open_table_engine`, `open_table_macros`)
Types fondamentaux, contrats sérialisables `Command`/`Event`, PRNG déterministe `ChaCha8Rng`, `Session` basée sur `bevy_ecs`, piles `undo_step`/`redo_step`, calcul ELO FIDE K=32 et hachage FNV-1a 64 bits.

### 2. Transports Réseau, QR et Relais (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)
TCP LAN, serveur Relais WebSocket avec codes de salle à 6 caractères, mode spectateur, file de matchmaking automatique par fenêtre ELO, invitations QR SVG et pont mobile P2P `RawByteLink`.

### 3. Ponts d'Exécution (`open_table_godot`, `open_table_wasm`)
Nœud GDExtension C-ABI (`OpenTableBridge`) pour Godot 4 / Redot 4 et pont `#[wasm_bindgen]` (`WasmGameBridge`) pour React + TypeScript + PWA.

### 4. 14 Moteurs de Jeux de Société Canoniques (`*_game`)
Crates Rust autonomes pour Échecs, Dames, Go, Shogi, Xiangqi, Dames Chinoises, Backgammon, Bataille Navale, Ludo, Mille Bornes, Monopoly, UNO, Crisis/Risk et Jeu de l'Oie.

### Complete Crates.io Workspace Directory (24 Crates)

| Crate | Architectural Layer | Description (crates.io) | Links |
|---|---|---|---|
| `open_table_core` | Core & Engine Foundation | Foundational deterministic traits, serializable Commands/Events, seeded ChaCha8 RNG, and transport contracts for turn-based board game engines. | [`crates.io`](https://crates.io/crates/open_table_core) · [`README`](../../../open_table_core/README.md) |
| `open_table_engine` | Core & Engine Foundation | ECS-backed deterministic turn-based session runtime (`Session`), transactional command pipeline, Undo/Redo stacks, FIDE ELO calculator, and state hashing. | [`crates.io`](https://crates.io/crates/open_table_engine) · [`README`](../../../open_table_engine/README.md) |
| `open_table_macros` | Core & Engine Foundation | Procedural derive macros (`#[derive(Component)]`, `#[derive(Resource)]`, `#[game_command]`, `#[game_event]`) reducing boilerplate for OpenTable game crates. | [`crates.io`](https://crates.io/crates/open_table_macros) · [`README`](../../../open_table_macros/README.md) |
| `open_table_qr` | Transports, Relay & Discovery | Compact session invitation payloads and SVG/terminal QR code generation for LAN, Relay room codes, and mobile P2P pairing. | [`crates.io`](https://crates.io/crates/open_table_qr) · [`README`](../../../open_table_qr/README.md) |
| `open_table_transport_tcp` | Transports, Relay & Discovery | Length-prefixed TCP host/client transport implementation of `open_table_core::Transport` for low-latency LAN multiplayer. | [`crates.io`](https://crates.io/crates/open_table_transport_tcp) · [`README`](../../../open_table_transport_tcp/README.md) |
| `open_table_transport_websocket` | Transports, Relay & Discovery | WebSocket client transport connecting desktop, mobile, and WebAssembly peers through `open_table_relay` rooms. | [`crates.io`](https://crates.io/crates/open_table_transport_websocket) · [`README`](../../../open_table_transport_websocket/README.md) |
| `open_table_transport_native_bridge` | Transports, Relay & Discovery | Zero-socket `RawByteLink` bridge adapting Android Nearby Connections, iOS MultipeerConnectivity, and WebRTC DataChannels into `Transport`. | [`crates.io`](https://crates.io/crates/open_table_transport_native_bridge) · [`README`](../../../open_table_transport_native_bridge/README.md) |
| `open_table_relay` | Transports, Relay & Discovery | Asynchronous WebSocket Relay server with 6-character room codes, spectator broadcasting, and automated ELO-window matchmaking queues. | [`crates.io`](https://crates.io/crates/open_table_relay) · [`README`](../../../open_table_relay/README.md) |
| `open_table_godot` | Runtime Bridges (Godot & WebAssembly) | GDExtension C-ABI bridge exposing all 14 canonical board games, 4-level AI with 0-100% randomness, ELO rating, and networking to Godot 4 / Redot 4. | [`crates.io`](https://crates.io/crates/open_table_godot) · [`README`](../../../open_table_godot/README.md) |
| `open_table_wasm` | Runtime Bridges (Godot & WebAssembly) | WebAssembly (`wasm-bindgen`) bridge compiling all 14 canonical Rust board game engines, AI levels, Undo/Redo, FNV-1a checksums, and telemetry for the React Web client. | [`crates.io`](https://crates.io/crates/open_table_wasm) · [`README`](../../../open_table_wasm/README.md) |
| `chess_game` | 14 Canonical Board Game Engines | Canonical FIDE Chess engine with castling, en passant, 4-piece promotion, 50-move/threefold repetition draws, Zobrist hashing, ECO opening book, and alpha-beta AI. | [`crates.io`](https://crates.io/crates/chess_game) · [`README`](../../../chess_game/README.md) |
| `checkers_game` | 14 Canonical Board Game Engines | Canonical 8x8 Draughts / Checkers engine with mandatory capture priority, chained multi-jump continuations, King crowning, 40-move draw clock, and minimax AI. | [`crates.io`](https://crates.io/crates/checkers_game) · [`README`](../../../checkers_game/README.md) |
| `go_game` | 14 Canonical Board Game Engines | Canonical Go (Weiqi / Baduk) engine supporting 9x9, 13x13, and 19x19 boards, BFS liberty & chain capture, positional Superko, Hoshi handicap, and 6.5 Komi scoring. | [`crates.io`](https://crates.io/crates/go_game) · [`README`](../../../go_game/README.md) |
| `shogi_game` | 14 Canonical Board Game Engines | Canonical 9x9 Japanese Shogi engine with Komadai capture trays, piece drops, Nifu (double pawn) and Uchifuzume bans, FESA promotion zones, and Sennichite x4 detection. | [`crates.io`](https://crates.io/crates/shogi_game) · [`README`](../../../shogi_game/README.md) |
| `xiangqi_game` | 14 Canonical Board Game Engines | Canonical 9x10 Chinese Chess (Xiangqi) engine with 3x3 Palaces, River boundary, Horse/Elephant leg blocking, Cannon screen jumping, and Flying General prohibition. | [`crates.io`](https://crates.io/crates/xiangqi_game) · [`README`](../../../xiangqi_game/README.md) |
| `chinese_checkers_game` | 14 Canonical Board Game Engines | Canonical 121-node hexagram Chinese Checkers engine supporting 2, 3, 4, and 6 players, BFS chained multi-hop paths, anti-camping rules, and axial distance heuristics. | [`crates.io`](https://crates.io/crates/chinese_checkers_game) · [`README`](../../../chinese_checkers_game/README.md) |
| `backgammon_game` | 14 Canonical Board Game Engines | Canonical 24-point Backgammon engine with doubles (4 moves), mandatory bar re-entry, exact/highest bear-off, Doubling Cube (2..64), and Crawford rule. | [`crates.io`](https://crates.io/crates/backgammon_game) · [`README`](../../../backgammon_game/README.md) |
| `battleship_game` | 14 Canonical Board Game Engines | Canonical 10x10 Naval Combat (Battleship) engine with 5-ship fleet deployment (`[5,4,3,3,2]`), optional `extra_turn_on_hit` salvo rule, rematch command, and Hunt/Target parity AI. | [`crates.io`](https://crates.io/crates/battleship_game) · [`README`](../../../battleship_game/README.md) |
| `ludo_game` | 14 Canonical Board Game Engines | Canonical 52-track + 5-goal Ludo (Parcheesi) engine with 8 safe star squares, triple-six penalty, capture/goal bonus rolls, and threat-aware tactical AI. | [`crates.io`](https://crates.io/crates/ludo_game) · [`README`](../../../ludo_game/README.md) |
| `mille_bornes_game` | 14 Canonical Board Game Engines | Canonical 1000-km Mille Bornes card racing engine with Hazards, Remedies, Speed Limits, max two 200-km cards, 4 Safety shields, and Coup Fourré instant counter-play. | [`crates.io`](https://crates.io/crates/mille_bornes_game) · [`README`](../../../mille_bornes_game/README.md) |
| `monopoly_game` | 14 Canonical Board Game Engines | Canonical 40-square Monopoly economic engine with property auctions, Chance/Community Chest decks, even house/hotel building, mortgages, jail, P2P trades, and ROI AI. | [`crates.io`](https://crates.io/crates/monopoly_game) · [`README`](../../../monopoly_game/README.md) |
| `uno_game` | 14 Canonical Board Game Engines | Canonical 108-card UNO engine with Skip, Reverse, Draw Two, Wild, Wild Draw Four challenge verification, mandatory UNO! call/penalty, and Jump-In interception. | [`crates.io`](https://crates.io/crates/uno_game) · [`README`](../../../uno_game/README.md) |
| `crisis_game` | 14 Canonical Board Game Engines | Canonical 30-territory, 6-continent global strategy engine (TEG / Risk) with secret objectives, continent bonuses, 3v3 sorted dice combat, 3-card trades, and multi-phase AI. | [`crates.io`](https://crates.io/crates/crisis_game) · [`README`](../../../crisis_game/README.md) |
| `goose_game` | 14 Canonical Board Game Engines | Canonical 63-square spiral Game of the Goose (Juego de la Oca) engine with 13 Geese ('De oca a oca'), Bridges, Inn, Dice, Well, Labyrinth, Prison, Death Skull (58), and exact bounce. | [`crates.io`](https://crates.io/crates/goose_game) · [`README`](../../../goose_game/README.md) |

---

## Démarrage Rapide (Rust, WebAssembly et Godot 4)

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
use chess_game::{new_chess_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

fn main() {
    let mut session = new_chess_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
    // Pick best move for White (Player 1) on Hard difficulty with 12% Top-K noise
    if let Some(cmd) = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42) {
        session.process_command(PlayerId(1), Box::new(cmd)).unwrap();
    }
    println!("State FNV-1a Checksum: {}", session.get_state_checksum_hex(b"chess_turn_1"));
}
```

### 3. React + TypeScript + WebAssembly Client (`web_client`)

```bash
# Verify TypeScript types, Vitest test suites (14 games + i18n + diagnostics), and production PWA build
bash tools/verify_web_client.sh
```
