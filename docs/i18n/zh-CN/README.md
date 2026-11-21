# OpenTable SDK v1.1.0 — 确定性多棋牌游戏引擎 (Rust, Godot 4 与 WebAssembly)

[![CI](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml)
[![Crates.io](https://img.shields.io/crates/v/open_table_core.svg)](https://crates.io/crates/open_table_core)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../../../LICENSE)
[![Games: 14/14](https://img.shields.io/badge/games-14%2F14-brightgreen.svg)](#)

**Languages / Idiomas:** [English](../en/README.md) · [Español](../es/README.md) · [Português (BR)](../pt-BR/README.md) · [Français](../fr/README.md) · [Deutsch](../de/README.md) · [简体中文](../zh-CN/README.md) · [日本語](../ja/README.md) · [Root README](../../../README.md)

---

OpenTable SDK 是一个基于 Rust 编写的模块化、确定性回合制桌游引擎工作区（共 24 个 Crate），原生支持 **Godot 4 / Redot 4** (`open_table_godot`) 与 **React + TypeScript + WebAssembly** (`open_table_wasm`)。套件中的全部 **14 款标准桌面游戏** 均实现了官方锦标赛规则、合法着法生成器 (`LegalMoveGenerator`)、支持 **0–100% Top-K 决策随机度调节** 的 4 级本地 AI、**事务级撤销/重做 (Undo/Redo)**、**64 位 FNV-1a 状态校验和**，以及带 **AI 决策强度热力图 (Decision Intensity Heat-Map)** 的 **赛后战术复盘分析器**。

## v1.1.0 版本核心更新

- **AI 随机度 / 噪声因子 (`0–100%`)**：按难度自动校准默认值（简单 `45%`、中等 `25%`、困难 `12%`、大师 `5%`），支持 UI 滑块实时调节与全部 14 款游戏的 Top-K 分值带扰动。
- **事务级 Undo/Redo 与 64 位 FNV-1a 状态校验和**：支持完整快照回滚与重放 (`undo_step`, `redo_step`) 以及 16 位十六进制确定性状态签名 (`get_state_checksum_hex`)。
- **AI 决策强度热力图 (Decision Intensity Heat-Map)**：集成于赛后复盘分析器，支持在 **当前选中回合 (`#ply`)** 与 **整局累计分布 (`N 回合`)** 之间一键切换，并适配全部 14 款游戏的棋盘拓扑。

---

## 架构设计与 24 个工作区 Crate (`crates.io` 标准)

整个工作区划分为四个高内聚、低耦合的架构层级：

### 1. 核心与 ECS 运行时 (`open_table_core`, `open_table_engine`, `open_table_macros`)
纯领域类型、可序列化 `Command`/`Event` 契约、确定性种子 `ChaCha8Rng`、基于 `bevy_ecs` 的 `Session`、事务级 `undo_step`/`redo_step`、FIDE K=32 ELO 积分计算器及 64 位 FNV-1a 校验和。

### 2. 网络传输、二维码与中继 (`open_table_qr`, `open_table_transport_tcp`, `open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_relay`)
局域网长度前缀 TCP、带 6 位房间码的 WebSocket Relay 服务器、实时观战广播、基于 ELO 窗口的自动匹配队列、SVG 二维码邀请以及移动端 P2P `RawByteLink` 桥接。

### 3. 跨平台运行时桥接 (`open_table_godot`, `open_table_wasm`)
面向 Godot 4 / Redot 4 的 GDExtension C-ABI 节点 (`OpenTableBridge`) 以及面向 React + TypeScript + PWA 的 `#[wasm_bindgen]` 桥接器 (`WasmGameBridge`)。

### 4. 14 款标准棋牌游戏引擎 (`*_game`)
独立的 Rust Crate，涵盖国际象棋、西洋跳棋、围棋、日本将棋、中国象棋、中国跳棋、双陆棋、海战棋、飞行棋 (Ludo)、千里之行、大富翁、UNO、全球危机 (TEG/Risk) 与鹅棋。

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

## 快速开始 (Rust, WebAssembly 与 Godot 4)

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
