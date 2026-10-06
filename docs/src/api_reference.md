# Rust API Reference (`cargo doc`)

The full Rust API documentation for the workspace is generated automatically via `cargo doc --workspace --exclude open_table_godot --no-deps` and published under [`api/`](./api/open_table_core/index.html).

## Direct Crate Links

- **[`open_table_core` API Reference](api/open_table_core/index.html)** — Foundational traits (`Command`, `Event`, `Component`, `Resource`, `Transport`, `AiDifficulty`, `GameResult`).
- **[`open_table_engine` API Reference](api/open_table_engine/index.html)** — Authoritative `EngineSession`, `RuleEngine`, deterministic scheduler, and replay verification.
- **[`open_table_macros` API Reference](api/open_table_macros/index.html)** — Derive macros (`GameCommand`, `GameEvent`, `GameComponent`, `GameResource`).
- **[`open_table_relay` API Reference](api/open_table_relay/index.html)** — WebSocket matchmaking relay, SQLite ELO service, and tournament brackets.

## Embedded `open_table_core` Reference

<iframe
  src="api/open_table_core/index.html"
  title="open_table_core rustdoc API Reference"
  width="100%"
  height="720"
  style="border: 1px solid #444; border-radius: 6px;"
></iframe>
