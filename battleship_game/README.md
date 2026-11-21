# `battleship_game`

[![Crates.io](https://img.shields.io/crates/v/battleship_game.svg)](https://crates.io/crates/battleship_game)
[![Docs.rs](https://docs.rs/battleship_game/badge.svg)](https://docs.rs/battleship_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 10x10 Naval Combat (Battleship) engine with 5-ship fleet deployment (`[5,4,3,3,2]`), optional `extra_turn_on_hit` salvo rule, rematch command, and Hunt/Target parity AI.

> **Español:** Motor canónico de Batalla Naval 10x10 con despliegue de flota de 5 barcos (`[5,4,3,3,2]`), variante `extra_turn_on_hit`, revancha y heurística IA de paridad Hunt/Target.

---

## Key Capabilities & Canonical Features

- Two-phase state machine: Fleet Setup (5 ships of lengths 5, 4, 3, 3, 2 with overlap & boundary checks) and Combat Salvo.
- Configurable `extra_turn_on_hit` rule and in-session `RematchCommand`.
- Checkerboard parity Hunt mode + directional axis Target mode AI with probability density heatmap.

## Primary Exported API

- **Public Symbols:** `new_battleship_session`, `PlaceShipCommand`, `FireShotCommand`, `RematchCommand`, `BattleshipLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
battleship_game = "1.1.0"
```

## Quick Start & Usage Example

```rust
use battleship_game::new_battleship_session;
use open_table_core::{PlayerId, SessionId};

let session = new_battleship_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
assert_eq!(session.current_player(), PlayerId(1));
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
