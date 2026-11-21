# `open_table_crisis_game` (`lib: crisis_game`)

[![Crates.io](https://img.shields.io/crates/v/open_table_crisis_game.svg)](https://crates.io/crates/open_table_crisis_game)
[![Docs.rs](https://docs.rs/open_table_crisis_game/badge.svg)](https://docs.rs/open_table_crisis_game)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** 14 Canonical Board Game Engines · **Package:** `open_table_crisis_game` · **Library Name (`[lib]`):** `crisis_game` · **Version:** `1.1.0` · **Edition:** `2021`

Canonical 30-territory, 6-continent global strategy engine (TEG / Risk) with secret objectives, continent bonuses, 3v3 sorted dice combat, 3-card trades, and multi-phase AI.

> **Español:** Motor de estrategia global canónico de 30 territorios y 6 continentes (Crisis / TEG / Risk) con objetivos secretos, bonos continentales, combate 3v3, canje de tarjetas e IA multifase.

---

## Key Capabilities & Canonical Features

- 30 territories grouped into 6 continents with continent-control army bonuses and secret victory objectives.
- Three-phase turn pipeline (`Reinforce`, `Attack` with up to 3v3 sorted dice comparisons, and `Fortify` across adjacent borders).
- Country card capture on conquest, escalating 3-card symbol trades (+2 territory ownership bonus), and multi-step planner AI.

## Primary Exported API

- **Public Symbols:** `new_crisis_session`, `PlaceArmiesCommand`, `AttackTerritoryCommand`, `FortifyTerritoryCommand`, `TradeCardsCommand`, `CrisisLegalMoveGenerator`, `best_move_with_randomness`

## Installation (`Cargo.toml`)

```toml
[dependencies]
crisis_game = { package = "open_table_crisis_game", version = "1.1.0" }
```

## Quick Start & Usage Example

```rust
use crisis_game::{new_crisis_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_crisis_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let cmd = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);
assert!(cmd.is_some());
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
