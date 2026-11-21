# `open_table_transport_websocket`

[![Crates.io](https://img.shields.io/crates/v/open_table_transport_websocket.svg)](https://crates.io/crates/open_table_transport_websocket)
[![Docs.rs](https://docs.rs/open_table_transport_websocket/badge.svg)](https://docs.rs/open_table_transport_websocket)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Transports, Relay & Discovery · **Version:** `1.1.0` · **Edition:** `2021`

WebSocket client transport connecting desktop, mobile, and WebAssembly peers through `open_table_relay` rooms.

> **Español:** Transporte cliente WebSocket que conecta clientes de escritorio, móvil y WebAssembly a través de salas de `open_table_relay`.

---

## Key Capabilities & Canonical Features

- Seamless JSON & binary envelope framing compatible with `open_table_relay`.
- Supports room creation (`create`), room joining (`join`), spectator mode (`spectate`), and ELO matchmaking (`queue`).
- Thread-safe non-blocking receive queue for deterministic session stepping.

## Primary Exported API

- **Public Symbols:** `WebSocketTransport`, `RelayClientConfig`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_transport_websocket = "1.1.0"
```

## Quick Start & Usage Example

```rust
use open_table_transport_websocket::RelayClientConfig;

let cfg = RelayClientConfig::new("ws://127.0.0.1:8080", "AB12CD");
assert_eq!(cfg.room_code(), "AB12CD");
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
