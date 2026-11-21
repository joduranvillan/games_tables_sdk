# `open_table_shogi_game` (`lib: shogi_game`)

[![Crates.io](https://img.shields.io/crates/v/open_table_shogi_game.svg)](https://crates.io/crates/open_table_shogi_game)
[![Docs.rs](https://docs.rs/open_table_shogi_game/badge.svg)](https://docs.rs/open_table_shogi_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Package:** `open_table_shogi_game` · **Library Name (`[lib]`):** `shogi_game` · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 9x9 Japanese Shogi engine with Komadai capture trays, piece drops, Nifu (double pawn) and Uchifuzume bans, FESA promotion zones, and Sennichite x4 detection.

> **Español:** Motor canónico de Shogi japonés 9x9 con bandejas Komadai, reingreso de piezas (Drops), prohibición Nifu y Uchifuzume, promoción FESA y repetición Sennichite x4.

---

## Key Capabilities & Canonical Features

- Full 9x9 board with demoted capture transfers to each player's `Komadai` hand stand.
- Strict drop validation: forbids double unpromoted pawns on the same file (`Nifu`), pieces with no future moves, and pawn-drop checkmate (`Uchifuzume`).
- Optional and mandatory FESA promotion across the enemy 3-rank zone and 4-fold `Sennichite` draw detection.

## Primary Exported API

- **Public Symbols:** `new_shogi_session`, `MoveShogiPieceCommand`, `DropPieceCommand`, `ShogiLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
shogi_game = { package = "open_table_shogi_game", version = "1.1.0" }
```

## Quick Start & Usage Example

```rust
use shogi_game::{new_shogi_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_shogi_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(action.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
