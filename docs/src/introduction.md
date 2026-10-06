# OpenTable SDK v1.0.0 — Introduction

**OpenTable SDK** is a deterministic, cross-platform board-game engine and toolkit written in **Rust** (`open_table_core`, `open_table_engine`, `open_table_godot`) with a complete visual client in **Godot 4 / Redot**.

## Key Capabilities

- **13 Complete Deterministic Board Games**: Chess, Checkers, Go, Shogi, Xiangqi, Backgammon, Ludo, Uno, Monopoly, Crisis, Mille Bornes, Chinese Checkers, and Battleship.
- **Deterministic ECS & Rule Engine**: Seeded ChaCha8 RNG, cryptographic state hashing, full command/event replay, and hidden-information sanitization for cards/fog-of-war.
- **Parametric AI Suite**: Minimax with Alpha-Beta pruning, ECO compact opening book (Chess), and Monte Carlo Tree Search (Go), configurable across `Easy`, `Medium`, `Hard`, and `Expert`.
- **Multiplayer & Competitive Stack**: Local Hotseat, LAN TCP, Native P2P (Wi-Fi Direct / BLE), and WebSocket Relay with persistent SQLite ELO rankings (`GET /rankings/:game_id`) and single-elimination tournaments (`4/8/16` players).
- **Godot 4 / Redot Addon (`addons/open_table/`)**: Drop-in GDExtension bridge (`OpenTableBridge`), interactive step-by-step tutorials (`TutorialManager`), themes, colorblind mode, and procedural audio.

## Quick Links

- [15-Minute SDK Quickstart](./quickstart.md)
- [Layered Architecture](./architecture.md)
- [Game Reference](./games/README.md)
- [Rust API Reference (`rustdoc`)](./api/open_table_core/index.html)
