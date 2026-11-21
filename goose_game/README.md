# `open_table_goose_game` (`lib: goose_game`)

[![Crates.io](https://img.shields.io/crates/v/open_table_goose_game.svg)](https://crates.io/crates/open_table_goose_game)
[![Docs.rs](https://docs.rs/open_table_goose_game/badge.svg)](https://docs.rs/open_table_goose_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Package:** `open_table_goose_game` · **Library Name (`[lib]`):** `goose_game` · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 63-square spiral Game of the Goose (Juego de la Oca) engine with 13 Geese ('De oca a oca'), Bridges, Inn, Dice, Well, Labyrinth, Prison, Death Skull (58), and exact bounce.

> **Español:** Motor canónico de El Juego de la Oca en espiral de 63 casillas con 13 Ocas, Puentes, Posada, Dados, Pozo, Laberinto, Cárcel, Calavera (58) y rebote exacto.

---

## Key Capabilities & Canonical Features

- Complete 63-square spiral board with all canonical hazards and shortcuts: 13 Geese (`5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59`), Bridges (`6 <-> 12`), Dice (`26 <-> 53`).
- Penalty squares: Inn (`19`, 1 turn), Well (`31`, trapped until rescued or timeout), Labyrinth (`42 -> 30`), Prison (`52`, 2 turns), and Skull (`58 -> 1`).
- Exact arrival at square 63 with backward excess bounce and deterministic dice/reroll AI.

## Primary Exported API

- **Public Symbols:** `new_goose_session`, `RollDiceCommand`, `GooseLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
goose_game = { package = "open_table_goose_game", version = "1.1.0" }
```

## Quick Start & Usage Example

```rust
use goose_game::{new_goose_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_goose_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let cmd = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Medium, 25, 42);
assert!(cmd.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
