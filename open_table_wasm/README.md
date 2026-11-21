# `open_table_wasm`

[![Crates.io](https://img.shields.io/crates/v/open_table_wasm.svg)](https://crates.io/crates/open_table_wasm)
[![Docs.rs](https://docs.rs/open_table_wasm/badge.svg)](https://docs.rs/open_table_wasm)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Runtime Bridges (Godot & WebAssembly) · **Version:** `1.1.0` · **Edition:** `2021`

WebAssembly (`wasm-bindgen`) bridge compiling all 14 canonical Rust board game engines, AI levels, Undo/Redo, FNV-1a checksums, and telemetry for the React Web client.

> **Español:** Puente WebAssembly (`wasm-bindgen`) que compila los 14 motores de juego en Rust, niveles de IA, Undo/Redo, checksums FNV-1a y telemetría para el cliente Web React.

---

## Key Capabilities & Canonical Features

- Exposes `WasmGameBridge` to JavaScript/TypeScript via `#[wasm_bindgen]`.
- Unified JSON state snapshot, legal move enumeration, and deterministic replay log import/export across all 14 games.
- Full support for AI randomness (`set_ai_randomness_pct`), transactional `undo_step`/`redo_step`, `get_state_checksum_hex`, and `get_last_ai_telemetry_json`.

## Primary Exported API

- **Public Symbols:** `WasmGameBridge`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_wasm = "1.1.0"
```

## Quick Start & Usage Example

```rust
use open_table_wasm::WasmGameBridge;

let mut bridge = WasmGameBridge::new();
bridge.start_ai_match("chess", 1, 2, 2);
assert_eq!(bridge.get_ai_randomness_pct(), 12);
assert_eq!(bridge.get_state_checksum_hex().len(), 18);
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
