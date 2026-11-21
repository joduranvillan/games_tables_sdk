# `open_table_relay` (`lib: open_table_relay`)

[![Crates.io](https://img.shields.io/crates/v/open_table_relay.svg)](https://crates.io/crates/open_table_relay)
[![Docs.rs](https://docs.rs/open_table_relay/badge.svg)](https://docs.rs/open_table_relay)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Transports, Relay & Discovery · **Package:** `open_table_relay` · **Library Name (`[lib]`):** `open_table_relay` · **Version:** `1.1.0` · **Edition:** `2021`

Asynchronous WebSocket Relay server with 6-character room codes, spectator broadcasting, and automated ELO-window matchmaking queues.

> **Español:** Servidor Relay WebSocket asíncrono con códigos de sala de 6 caracteres, retransmisión a espectadores y colas de matchmaking automático por ventana ELO.

---

## Key Capabilities & Canonical Features

- 6-character alphanumeric room allocation with automatic TTL cleanup.
- Symmetric ELO matchmaking queue (`|ELO_A - ELO_B| <= min(delta_A, delta_B)`) per game type.
- Read-only spectator multiplexing and rate-limited room chat forwarding.

## Primary Exported API

- **Public Symbols:** `RelayServer`, `MatchmakingQueue`, `RoomRegistry`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_relay = "1.1.0"
```

## Quick Start & Usage Example

```rust
// Matchmaking symmetry verification:
// Player A (1250 ELO, ±150) matches Player B (1340 ELO, ±200) because |1250 - 1340| = 90 <= min(150, 200)
let delta = (1250_i32 - 1340_i32).abs();
assert!(delta <= 150.min(200));
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
