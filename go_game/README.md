# `go_game`

[![Crates.io](https://img.shields.io/crates/v/go_game.svg)](https://crates.io/crates/go_game)
[![Docs.rs](https://docs.rs/go_game/badge.svg)](https://docs.rs/go_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Version:** `1.1.0` · **Edition:** `2021`

Canonical Go (Weiqi / Baduk) engine supporting 9x9, 13x13, and 19x19 boards, BFS liberty & chain capture, positional Superko, Hoshi handicap, and 6.5 Komi scoring.

> **Español:** Motor canónico de Go (Weiqi / Baduk) para tableros 9x9, 13x13 y 19x19, captura de cadenas por libertades BFS, Superko posicional, hándicap Hoshi y conteo Komi 6.5.

---

## Key Capabilities & Canonical Features

- Configurable 9x9, 13x13, and 19x19 intersections with canonical Hoshi handicap placement (2–9 stones).
- Breadth-first liberty flood-fill, suicide prohibition, and positional Superko hash history.
- Endgame dead-stone marking (`ToggleDeadStoneCommand`), mutual confirmation, and territory + captures + 6.5 Komi scoring.

## Primary Exported API

- **Public Symbols:** `new_go_session`, `PlaceStoneCommand`, `PassTurnCommand`, `ToggleDeadStoneCommand`, `GoLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
go_game = "1.1.0"
```

## Quick Start & Usage Example

```rust
use go_game::{new_go_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_go_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(action.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
