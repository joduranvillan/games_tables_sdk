# `checkers_game`

[![Crates.io](https://img.shields.io/crates/v/checkers_game.svg)](https://crates.io/crates/checkers_game)
[![Docs.rs](https://docs.rs/checkers_game/badge.svg)](https://docs.rs/checkers_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 8x8 Draughts / Checkers engine with mandatory capture priority, chained multi-jump continuations, King crowning, 40-move draw clock, and minimax AI.

> **Español:** Motor canónico de Damas 8x8 con captura obligatoria prioritaria, saltos múltiples encadenados, coronación a Dama, reloj de tablas de 40 turnos e IA minimax.

---

## Key Capabilities & Canonical Features

- Enforces mandatory capture over simple diagonal advances whenever any jump exists.
- Chained multi-jump turn locking (`must_continue_from`) until the capturing sequence completes.
- King promotion on the back rank with 4-diagonal mobility and Top-K noise-enabled minimax AI.

## Primary Exported API

- **Public Symbols:** `new_checkers_session`, `MovePieceCommand`, `CheckersLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
checkers_game = "1.1.0"
```

## Quick Start & Usage Example

```rust
use checkers_game::{new_checkers_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_checkers_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Medium, 25, 42);
assert!(mv.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
