# `open_table_godot` (`lib: open_table_godot`)

[![Crates.io](https://img.shields.io/crates/v/open_table_godot.svg)](https://crates.io/crates/open_table_godot)
[![Docs.rs](https://docs.rs/open_table_godot/badge.svg)](https://docs.rs/open_table_godot)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Runtime Bridges (Godot & WebAssembly) · **Package:** `open_table_godot` · **Library Name (`[lib]`):** `open_table_godot` · **Version:** `1.1.0` · **Edition:** `2021`

GDExtension C-ABI bridge exposing all 14 canonical board games, 4-level AI with 0-100% randomness, ELO rating, and networking to Godot 4 / Redot 4.

> **Español:** Puente GDExtension C-ABI que expone los 14 juegos canónicos, IA de 4 niveles con aleatoriedad 0-100%, rating ELO y red a Godot 4 / Redot 4.

---

## Key Capabilities & Canonical Features

- Single `OpenTableBridge` Godot node managing any of the 14 canonical games.
- Configurable AI difficulty (`0..=3`) and randomness percentage (`0..=100%`) with auto-scaling defaults.
- Transactional `undo_step()`, `redo_step()`, 64-bit FNV-1a checksum (`get_state_checksum_hex`), and `get_last_ai_telemetry_json()`.
- Built-in TCP LAN, WebSocket Relay, and mobile P2P transport bindings for GDScript.

## Primary Exported API

- **Public Symbols:** `OpenTableBridge`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_godot = "1.1.0"
```

## Quick Start & Usage Example

```gdscript
# GDScript usage inside Godot 4 / Redot 4:
var bridge = OpenTableBridge.new()
bridge.start_ai_match("chess", 1, 2, 2) # Human P1 vs Hard AI P2 (12% default noise)
bridge.set_ai_randomness_pct(20)        # Custom 20% Top-K decision noise
var checksum: String = bridge.get_state_checksum_hex()
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
