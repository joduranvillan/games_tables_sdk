# `open_table_qr` (`lib: open_table_qr`)

[![Crates.io](https://img.shields.io/crates/v/open_table_qr.svg)](https://crates.io/crates/open_table_qr)
[![Docs.rs](https://docs.rs/open_table_qr/badge.svg)](https://docs.rs/open_table_qr)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](../LICENSE)
[![Rust 1.82+](https://img.shields.io/badge/rust-1.82%2B-orange.svg)](https://www.rust-lang.org)

**Documentation Languages:** [English](../docs/i18n/en/README.md) · [Español](../docs/i18n/es/README.md) · [Português (BR)](../docs/i18n/pt-BR/README.md) · [Français](../docs/i18n/fr/README.md) · [Deutsch](../docs/i18n/de/README.md) · [简体中文](../docs/i18n/zh-CN/README.md) · [日本語](../docs/i18n/ja/README.md)

**Architectural Layer:** Transports, Relay & Discovery · **Package:** `open_table_qr` · **Library Name (`[lib]`):** `open_table_qr` · **Version:** `1.1.0` · **Edition:** `2021`

Compact session invitation payloads and SVG/terminal QR code generation for LAN, Relay room codes, and mobile P2P pairing.

> **Español:** Payloads compactos de invitación de sesión y generación de códigos QR en SVG/terminal para LAN, salas Relay y emparejamiento P2P móvil.

---

## Key Capabilities & Canonical Features

- Serializes host endpoint, room code, game identifier, and protocol version into compact QR URIs.
- Renders crisp SVG and UTF-8 matrix representations for Godot, CLI, and Web clients.
- Validates schema version and checksum before initiating socket handshakes.

## Primary Exported API

- **Public Symbols:** `QrInvitePayload`, `encode_invite_qr_svg`, `decode_invite_payload`

## Installation (`Cargo.toml`)

```toml
[dependencies]
open_table_qr = "1.1.0"
```

## Quick Start & Usage Example

```rust
use open_table_qr::QrInvitePayload;

let invite = QrInvitePayload::new_relay("AB12CD", "chess", "wss://relay.example.org");
let uri = invite.to_compact_string();
assert!(uri.contains("AB12CD"));
```

## v1.1.0 Engine & AI Telemetry Highlights

- **Configurable AI Randomness (`0–100%`)**: Supports Top-K score band perturbation via `AiDifficulty::select_top_k_with_noise` and difficulty-calibrated default noise (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`).
- **Transactional Undo/Redo & Determinism**: Integrates with `open_table_engine::Session` snapshot stacks (`undo_step`, `redo_step`) and 64-bit FNV-1a state checksums (`compute_state_checksum`, `get_state_checksum_hex`).
- **Cross-Platform Parity**: Verified across native Rust (`cargo test --workspace`), Godot 4 / Redot 4 (`open_table_godot`), and WebAssembly React (`open_table_wasm`).

## License

Licensed under the **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)**. See [`../LICENSE`](../LICENSE) for full details.
