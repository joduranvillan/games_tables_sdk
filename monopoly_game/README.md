# `open_table_monopoly_game` (`lib: monopoly_game`)

[![Crates.io](https://img.shields.io/crates/v/open_table_monopoly_game.svg)](https://crates.io/crates/open_table_monopoly_game)
[![Docs.rs](https://docs.rs/open_table_monopoly_game/badge.svg)](https://docs.rs/open_table_monopoly_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Package:** `open_table_monopoly_game` · **Library Name (`[lib]`):** `monopoly_game` · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 40-square Monopoly economic engine with property auctions, Chance/Community Chest decks, even house/hotel building, mortgages, jail, P2P trades, and ROI AI.

> **Español:** Motor económico canónico de Monopoly de 40 casillas con subastas, mazos de Suerte/Arca Comunal, construcción uniforme de casas/hoteles, hipotecas, cárcel, trueques e IA por ROI.

---

## Key Capabilities & Canonical Features

- Complete 40-space board: 8 color groups, 4 Railroads, 2 Utilities, Taxes, Jail (3-doubles, bail, or card), and deterministic Chance/Community Chest decks.
- Property refusal triggers live auctions (`PlaceBidCommand`, `PassAuctionCommand`); full mortgage/unmortgage (+10% interest) and player-to-player trade proposals.
- Even-build rule enforcement (`BuildHouseCommand` up to Hotel level 5) and cash-reserve ROI AI.

## Primary Exported API

- **Public Symbols:** `new_monopoly_session`, `RollDiceCommand`, `BuyPropertyCommand`, `BuildHouseCommand`, `PlaceBidCommand`, `MonopolyLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
monopoly_game = { package = "open_table_monopoly_game", version = "1.1.0" }
```

## Quick Start & Usage Example

```rust
use monopoly_game::{new_monopoly_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_monopoly_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Expert, 5, 42);
assert!(action.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
