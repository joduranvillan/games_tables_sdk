# `open_table_mille_bornes_game` (`lib: mille_bornes_game`)

[![Crates.io](https://img.shields.io/crates/v/open_table_mille_bornes_game.svg)](https://crates.io/crates/open_table_mille_bornes_game)
[![Docs.rs](https://docs.rs/open_table_mille_bornes_game/badge.svg)](https://docs.rs/open_table_mille_bornes_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Package:** `open_table_mille_bornes_game` · **Library Name (`[lib]`):** `mille_bornes_game` · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 1000-km Mille Bornes card racing engine with Hazards, Remedies, Speed Limits, max two 200-km cards, 4 Safety shields, and Coup Fourré instant counter-play.

> **Español:** Motor canónico de cartas Mil Millas (1000 km) con Ataques, Defensas, Límites de Velocidad, máximo dos cartas de 200 km, 4 Escudos (Safeties) y respuesta ¡Coup Fourré!.

---

## Key Capabilities & Canonical Features

- Authentic deck of Distance (`25`, `50`, `75`, `100`, `200` km), Hazard, Remedy, and 4 unique Safety cards.
- Enforces exact 1000 km target, maximum two `200 km` cards per trip, and `Roll` (`Siga`) requirement.
- Supports instant `CoupFourreCommand` interruption (+300 bonus points & extra turn) when hit by a matching Hazard.

## Primary Exported API

- **Public Symbols:** `new_mille_bornes_session`, `PlayCardCommand`, `DiscardCardCommand`, `CoupFourreCommand`, `MilleBornesLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
mille_bornes_game = { package = "open_table_mille_bornes_game", version = "1.1.0" }
```

## Quick Start & Usage Example

```rust
use mille_bornes_game::{new_mille_bornes_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_mille_bornes_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let action = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(action.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
