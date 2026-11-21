# `open_table_transport_tcp`

[![Crates.io](https://img.shields.io/crates/v/open_table_transport_tcp.svg)](https://crates.io/crates/open_table_transport_tcp)
[![Docs.rs](https://docs.rs/open_table_transport_tcp/badge.svg)](https://docs.rs/open_table_transport_tcp)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Transports, Relay & Discovery · **Version:** `1.1.0` · **Edition:** `2021`

Length-prefixed TCP host/client transport implementation of `open_table_core::Transport` for low-latency LAN multiplayer.

> **Español:** Implementación de transporte TCP host/cliente con prefijo de longitud de `open_table_core::Transport` para multijugador LAN de baja latencia.

---

## Key Capabilities & Canonical Features

- Framing with 32-bit big-endian payload length prefix and maximum frame guard.
- Non-blocking poll loop suitable for 60 FPS game ticks in Godot and desktop runners.
- Automatic peer disconnect detection and clean socket shutdown.

## Primary Exported API

- **Public Symbols:** `TcpHostTransport`, `TcpClientTransport`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_transport_tcp = "1.1.0"
```

## Quick Start & Usage Example

```rust
// Bind a LAN host on an ephemeral local port
use open_table_transport_tcp::TcpHostTransport;

let host = TcpHostTransport::bind("127.0.0.1:0").expect("bind ephemeral port");
let local_addr = host.local_addr().unwrap();
println!("Listening for LAN peer on {}", local_addr);
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
