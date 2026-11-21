# `open_table_macros` (`lib: open_table_macros`)

[![Crates.io](https://img.shields.io/crates/v/open_table_macros.svg)](https://crates.io/crates/open_table_macros)
[![Docs.rs](https://docs.rs/open_table_macros/badge.svg)](https://docs.rs/open_table_macros)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Core & Engine Foundation · **Package:** `open_table_macros` · **Library Name (`[lib]`):** `open_table_macros` · **Version:** `1.1.0` · **Edition:** `2021`

Procedural derive macros (`#[derive(Component)]`, `#[derive(Resource)]`, `#[game_command]`, `#[game_event]`) reducing boilerplate for OpenTable game crates.

> **Español:** Macros procedurales (`#[derive(Component)]`, `#[derive(Resource)]`, `#[game_command]`, `#[game_event]`) para reducir código repetitivo en crates de juegos.

---

## Key Capabilities & Canonical Features

- Automatic registration of `open_table_core::Component` and `open_table_core::Resource` traits.
- Ergonomic attribute macros for serializable `Command` and `Event` types.
- Compile-time diagnostics ensuring `Send + Sync + 'static` bounds for ECS storage.

## Primary Exported API

- **Public Symbols:** `Component`, `Resource`, `game_command`, `game_event`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_macros = "1.1.0"
```

## Quick Start & Usage Example

```rust
use open_table_macros::{Component, Resource};

#[derive(Debug, Clone, Component)]
pub struct PiecePosition {
    pub x: u8,
    pub y: u8,
}

#[derive(Debug, Default, Resource)]
pub struct TurnCounter(pub u32);
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
