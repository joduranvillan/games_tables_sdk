# `open_table_engine`

[![Crates.io](https://img.shields.io/crates/v/open_table_engine.svg)](https://crates.io/crates/open_table_engine)
[![Docs.rs](https://docs.rs/open_table_engine/badge.svg)](https://docs.rs/open_table_engine)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Core & Engine Foundation · **Version:** `1.1.0` · **Edition:** `2021`

ECS-backed deterministic turn-based session runtime (`Session`), transactional command pipeline, Undo/Redo stacks, FIDE ELO calculator, and state hashing.

> **Español:** Runtime determinista de sesiones por turnos sobre Bevy ECS (`Session`), pipeline transaccional de comandos, pilas Undo/Redo, calculadora ELO FIDE y hashing de estado.

---

## Key Capabilities & Canonical Features

- Deterministic `Session` wrapping `bevy_ecs::world::World` with strict turn & phase validation.
- Transactional command execution (`process_command`) with automatic event recording and tick progression.
- Snapshot-based `undo_step()` and `redo_step()` stacks plus 64-bit FNV-1a state checksums (`compute_state_checksum`).
- Official FIDE ELO rating delta engine (`elo::update_elo`) with configurable K-factors.
- Built-in command history and replay verification for deterministic audit logs.

## Primary Exported API

- **Public Symbols:** `Session`, `RuleEngine`, `LegalMoveGenerator`, `TurnResource`, `EloRating`, `update_elo`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_engine = "1.1.0"
```

## Quick Start & Usage Example

```rust
use open_table_engine::prelude::*;

let session = Session::new(
    SessionId(1),
    42,
    vec![PlayerId(1), PlayerId(2)],
    RuleEngine::new(),
);

// Deterministic 64-bit FNV-1a checksum of the session state ("0x" + 16 hex digits = 18 chars)
let checksum_hex = session.get_state_checksum_hex();
assert_eq!(checksum_hex.len(), 18);
assert!(session.verify_checksum(&checksum_hex));
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
