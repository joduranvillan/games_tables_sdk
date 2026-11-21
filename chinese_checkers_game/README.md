# `chinese_checkers_game`

[![Crates.io](https://img.shields.io/crates/v/chinese_checkers_game.svg)](https://crates.io/crates/chinese_checkers_game)
[![Docs.rs](https://docs.rs/chinese_checkers_game/badge.svg)](https://docs.rs/chinese_checkers_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 121-node hexagram Chinese Checkers engine supporting 2, 3, 4, and 6 players, BFS chained multi-hop paths, anti-camping rules, and axial distance heuristics.

> **Español:** Motor canónico de Damas Chinas sobre estrella hexagonal de 121 casillas para 2, 3, 4 y 6 jugadores, saltos encadenados BFS, regla anti-bloqueo y heurística axial.

---

## Key Capabilities & Canonical Features

- 121-coordinate axial star topology supporting 2, 3, 4, or 6 symmetric player triangles.
- BFS reachability solver for arbitrary-length chained single-marble hops.
- Anti-spoiling / anti-blocking validation and directional progress heuristic AI with Top-K noise.

## Primary Exported API

- **Public Symbols:** `new_chinese_checkers_session`, `MoveMarbleCommand`, `ChineseCheckersLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
chinese_checkers_game = "1.1.0"
```

## Quick Start & Usage Example

```rust
use chinese_checkers_game::{new_chinese_checkers_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_chinese_checkers_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Medium, 25, 42);
assert!(mv.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
