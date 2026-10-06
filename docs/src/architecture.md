# Architecture Overview

OpenTable SDK follows a strict, unidirectional layered architecture where inner layers have zero knowledge of outer layers or rendering engines:

```text
+-------------------------------------------------------------------------+
|                        Godot 4 / Redot Client                           |
|   Scenes (chess_board, go_board, leaderboard, tournament_lobby, ...)    |
|   Autoloads (GameManager, ThemeManager, AudioManager, TutorialManager)  |
+------------------------------------+------------------------------------+
                                     |
                           GDScript Signals & Calls
                                     v
+-------------------------------------------------------------------------+
|                    Bridge Layer (open_table_godot)                      |
|      GDExtension C-ABI FFI (`OpenTableBridge`) + JSON Serialization     |
+------------------------------------+------------------------------------+
                                     |
                      CommandEnvelope / EventEnvelope
                                     v
+-------------------------------------------------------------------------+
|          Game Modules (13 Crates: chess_game, go_game, ...)             |
|   Rules, Legal Move Generators, Parametric AI (Minimax / MCTS / Book)   |
+------------------------------------+------------------------------------+
                                     |
                     RuleRegistration & ECS Components
                                     v
+-------------------------------------------------------------------------+
|                  Engine Layer (open_table_engine)                       |
|    `bevy_ecs` World + Deterministic Scheduler + Replay + Snapshots      |
+------------------------------------+------------------------------------+
                                     |
                         Foundational Contracts
                                     v
+-------------------------------------------------------------------------+
|                   Core Layer (open_table_core)                          |
|   Traits (`Command`, `Event`, `Resource`, `Transport`), `AiDifficulty`  |
+-------------------------------------------------------------------------+
```

## Layer Responsibilities

1. **`open_table_core`**: Pure data contracts (`Command`, `Event`, `Component`, `Resource`, `Transport`, `Visibility`, `AiDifficulty`, `GameResult`) with no engine or I/O dependencies.
2. **`open_table_engine`**: Authoritative `EngineSession` powered by `bevy_ecs`, deterministic `RuleEngine`, replay recording/verification, and spectator state filtering.
3. **Game Crates (`*_game`)**: Self-contained rules, state machines, and AI engines for each of the 13 supported board games.
4. **Transports & Relay (`open_table_transport_*`, `open_table_relay`)**: TCP, WebSocket, and Native P2P transports plus matchmaking, persistent SQLite ELO ratings, and tournament brackets.
5. **Godot Bridge (`open_table_godot`)**: Exposes `OpenTableBridge` to GDScript so UI boards remain thin, reactive views driven by engine events.
