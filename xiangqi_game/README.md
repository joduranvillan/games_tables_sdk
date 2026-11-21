# `xiangqi_game`

[![Crates.io](https://img.shields.io/crates/v/xiangqi_game.svg)](https://crates.io/crates/xiangqi_game)
[![Docs.rs](https://docs.rs/xiangqi_game/badge.svg)](https://docs.rs/xiangqi_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 9x10 Chinese Chess (Xiangqi) engine with 3x3 Palaces, River boundary, Horse/Elephant leg blocking, Cannon screen jumping, and Flying General prohibition.

> **Español:** Motor canónico de Ajedrez Chino (Xiangqi) 9x10 con Palacios 3x3, Río central, bloqueo de Caballo/Elefante, salto de Cañón con pantalla y regla del General Volador.

---

## Key Capabilities & Canonical Features

- Authentic 9x10 intersection grid with 3x3 diagonal Palaces for General and Advisors.
- Orthogonal leg-blocking for Horse (`Ma`) and diagonal eye-blocking + river restriction for Elephant (`Xiang`).
- Cannon (`Pao`) single-screen jump capture and strict Flying General face-to-face prohibition on open files.

## Primary Exported API

- **Public Symbols:** `new_xiangqi_session`, `MoveXiangqiPieceCommand`, `XiangqiLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
xiangqi_game = "1.1.0"
```

## Quick Start & Usage Example

```rust
use xiangqi_game::{new_xiangqi_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_xiangqi_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(mv.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
