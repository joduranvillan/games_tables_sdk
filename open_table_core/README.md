# `open_table_core`

[![Crates.io](https://img.shields.io/crates/v/open_table_core.svg)](https://crates.io/crates/open_table_core)
[![Docs.rs](https://docs.rs/open_table_core/badge.svg)](https://docs.rs/open_table_core)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Core & Engine Foundation · **Version:** `1.1.0` · **Edition:** `2021`

Foundational deterministic traits, serializable Commands/Events, seeded ChaCha8 RNG, and transport contracts for turn-based board game engines.

> **Español:** Traits fundacionales deterministas, comandos/eventos serializables, RNG ChaCha8 con semilla y contratos de transporte para motores de juegos de mesa por turnos.

---

## Key Capabilities & Canonical Features

- Zero engine/network coupling: pure domain types (`SessionId`, `PlayerId`, `Tick`, `EntityId`).
- Dynamic command & event serialization via `typetag::serde` (`Command`, `Event` trait objects).
- Deterministic cross-platform PRNG (`RandomService` backed by `ChaCha8Rng`) and `GameClock`.
- 4-tier `AiDifficulty` (`Easy`, `Medium`, `Hard`, `Expert`) with Top-K noise perturbation (`select_top_k_with_noise`, `default_randomness_pct`) and `AiMoveTelemetry`.
- 64-bit deterministic FNV-1a state checksum helpers (`deterministic_fnv1a_64`, `format_fnv1a_hex`).

## Primary Exported API

- **Public Symbols:** `SessionId`, `PlayerId`, `Tick`, `Command`, `Event`, `RandomService`, `AiDifficulty`, `AiMoveTelemetry`, `deterministic_fnv1a_64`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_core = "1.1.0"
```

## Quick Start & Usage Example

```rust
use open_table_core::{AiDifficulty, PlayerId, RandomService, deterministic_fnv1a_64, format_fnv1a_hex};

let mut rng = RandomService::from_seed(42);
let roll = rng.roll_die(6);
assert!((1..=6).contains(&roll));

// Top-K noise selection with 25% randomness factor
let candidate_scores = vec![120.0, 114.0, 95.0, 40.0];
let chosen_idx = AiDifficulty::select_top_k_with_noise(&candidate_scores, 25, 15.0, 42).unwrap();
assert!(chosen_idx <= 1);

// Deterministic 64-bit FNV-1a checksum
let hash = deterministic_fnv1a_64(b"canonical_board_state_v1");
assert_eq!(format_fnv1a_hex(hash).len(), 16);
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
