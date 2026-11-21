# `ludo_game`

[![Crates.io](https://img.shields.io/crates/v/ludo_game.svg)](https://crates.io/crates/ludo_game)
[![Docs.rs](https://docs.rs/ludo_game/badge.svg)](https://docs.rs/ludo_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 52-track + 5-goal Ludo (Parcheesi) engine with 8 safe star squares, triple-six penalty, capture/goal bonus rolls, and threat-aware tactical AI.

> **Español:** Motor canónico de Ludo (Parchís) de 52 casillas + 5 de meta con 8 estrellas seguras, penalización por tres 6 seguidos, tirada extra por captura/meta e IA táctica.

---

## Key Capabilities & Canonical Features

- 4 tokens per player traversing a 52-square shared ring plus a 5-step private home stretch (`WIN_STEPS = 57`).
- 8 safe star squares, deployment on roll of 6, bonus rolls on 6/capture/goal, and turn forfeiture on three consecutive sixes.
- Tactical AI evaluating capture opportunities, safe-square departures, and 1..6 rear threat exposure.

## Primary Exported API

- **Public Symbols:** `new_ludo_session`, `RollDiceCommand`, `MoveTokenCommand`, `LudoLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
ludo_game = "1.1.0"
```

## Quick Start & Usage Example

```rust
use ludo_game::{new_ludo_session, RollDiceCommand};
use open_table_core::{PlayerId, SessionId};

let mut session = new_ludo_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
session.process_command(PlayerId(1), Box::new(RollDiceCommand { player: PlayerId(1) })).unwrap();
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
