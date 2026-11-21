# `open_table_chess_game` (`lib: chess_game`)

[![Crates.io](https://img.shields.io/crates/v/open_table_chess_game.svg)](https://crates.io/crates/open_table_chess_game)
[![Docs.rs](https://docs.rs/open_table_chess_game/badge.svg)](https://docs.rs/open_table_chess_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Package:** `open_table_chess_game` · **Library Name (`[lib]`):** `chess_game` · **Version:** `1.1.0` · **Edition:** `2021`

Canonical FIDE Chess engine with castling, en passant, 4-piece promotion, 50-move/threefold repetition draws, Zobrist hashing, ECO opening book, and alpha-beta AI.

> **Español:** Motor canónico de Ajedrez FIDE con enroque, captura al paso, promoción a 4 piezas, tablas por 50 movimientos/triple repetición, Zobrist hashing, libro ECO e IA alfa-beta.

---

## Key Capabilities & Canonical Features

- Complete FIDE move validation: pin detection, check/checkmate/stalemate, kingside/queenside castling, en passant, and underpromotion (`Q`, `R`, `B`, `N`).
- Automatic draw detection by 50-move rule, threefold Zobrist repetition, insufficient material, and mutual agreement (`OfferDrawCommand` / `AcceptDrawCommand`).
- 64-bit Zobrist hashing, ECO opening book with randomness rotation (`lookup_session_with_randomness`), and alpha-beta + quiescence search AI.

## Primary Exported API

- **Public Symbols:** `new_chess_session`, `MovePieceCommand`, `OfferDrawCommand`, `AcceptDrawCommand`, `ChessLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
chess_game = { package = "open_table_chess_game", version = "1.1.0" }
```

## Quick Start & Usage Example

```rust
use chess_game::{new_chess_session, ai::best_move_with_randomness, Position};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_chess_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(mv.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
