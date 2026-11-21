# `open_table_transport_native_bridge` (`lib: open_table_transport_native_bridge`)

[![Crates.io](https://img.shields.io/crates/v/open_table_transport_native_bridge.svg)](https://crates.io/crates/open_table_transport_native_bridge)
[![Docs.rs](https://docs.rs/open_table_transport_native_bridge/badge.svg)](https://docs.rs/open_table_transport_native_bridge)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Transports, Relay & Discovery · **Package:** `open_table_transport_native_bridge` · **Library Name (`[lib]`):** `open_table_transport_native_bridge` · **Version:** `1.1.0` · **Edition:** `2021`

Zero-socket `RawByteLink` bridge adapting Android Nearby Connections, iOS MultipeerConnectivity, and WebRTC DataChannels into `Transport`.

> **Español:** Puente `RawByteLink` sin sockets que adapta Android Nearby Connections, iOS MultipeerConnectivity y WebRTC DataChannels al trait `Transport`.

---

## Key Capabilities & Canonical Features

- Decouples platform-specific Bluetooth/Wi-Fi Direct SDK callbacks from the Rust engine.
- In-memory ring buffer queues (`push_incoming_bytes`, `drain_outgoing_bytes`) safe across FFI boundaries.
- Deterministic packet ordering and peer lifecycle notifications.

## Primary Exported API

- **Public Symbols:** `NativeBridgeTransport`, `RawByteLink`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_transport_native_bridge = "1.1.0"
```

## Quick Start & Usage Example

```rust
use open_table_transport_native_bridge::NativeBridgeTransport;

let mut bridge = NativeBridgeTransport::new();
bridge.push_incoming_frame(b"{\"cmd\":\"MovePiece\"}".to_vec());
assert_eq!(bridge.pending_incoming_count(), 1);
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
