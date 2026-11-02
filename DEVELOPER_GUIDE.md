# Guía del Desarrollador — Cómo Implementar un Juego Nuevo desde Cero (`DEVELOPER_GUIDE.md`)

Esta guía documenta paso a paso y con **código real compilable** cómo implementar e integrar un nuevo juego de tablero en grilla (**Tres en Línea / Conecta 4 — `tic_tac_toe_game`**) en **OpenTable SDK & Suite**, cubriendo desde el modelo de datos ECS en Rust hasta la integración completa en el puente nativo `OpenTableBridge`, la escena visual en Godot / Redot y los tests de certificación.

Todo el código del proyecto se distribuye bajo la licencia **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)** (ver [`LICENSE`](./LICENSE)).

---

## Visión General del Flujo de Punta a Punta

Cada jugada sigue un ciclo estrictamente unidireccional y determinista: **la vista en Godot nunca modifica ni decide las reglas por su cuenta**; envía un `Command` al motor Rust y solo actualiza lo que dibuja cuando recibe los `Event`s confirmados por la sesión autoritativa.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 1. VISTA GODOT / REDOT (godot_project/tic_tac_toe_board.gd)                  │
│    • Dibuja la grilla 3×3, captura el clic en (row, col) y llama a:          │
│      bridge.send_tic_tac_toe_move(current, row, col)                         │
│    • Integra TurnIndicator (con TurnTimerHud compacto) y GameAppMenu         │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ Llamada GDExtension (#[func])
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ 2. PUENTE NATIVO (open_table_godot/src/lib.rs -> OpenTableBridge)            │
│    • Construye PlaceMarkCommand { player, row, col }                         │
│    • Invoca session.process_command(p, Box::new(cmd))                        │
│    • Traduce MarkPlacedEvent / GameOverEvent a señales GDScript              │
│    • Si el siguiente turno es ai_player, ejecuta tic_tac_toe_ai_pick_move()  │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ Trait Command / Event (typetag)
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ 3. MOTOR DETERMINISTA EN RUST (tic_tac_toe_game)                             │
│    • board.rs       -> BoardResource (#[derive(GameResource)])               │
│    • commands.rs    -> PlaceMarkCommand, ResignCommand (#[derive(GameCommand)])│
│    • events.rs      -> MarkPlacedEvent, GameOverEvent (#[derive(GameEvent)]) │
│    • legal_moves.rs -> TicTacToeLegalMoveGenerator (impl LegalMoveGenerator) │
│    • rules.rs       -> build_tic_tac_toe_rules() -> RuleEngine               │
│    • ai.rs          -> tic_tac_toe_ai_pick_move(&Session, PlayerId)          │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Paso 1: Crear el Crate del Juego en el Workspace (`tic_tac_toe_game`)

### 1.1 Registrar el miembro en el `Cargo.toml` raíz
Añade `"tic_tac_toe_game"` al arreglo `members` del archivo `Cargo.toml` en la raíz del repositorio:

```toml
[workspace]
resolver = "2"
members = [
    "open_table_core",
    "open_table_engine",
    "open_table_macros",
    # ... los 13 juegos existentes ...
    "tic_tac_toe_game",
]
```

### 1.2 Crear `tic_tac_toe_game/Cargo.toml`
Usa exactamente las mismas versiones y dependencias internas que el resto de los juegos de la colección:

```toml
[package]
name = "tic_tac_toe_game"
version = "0.1.0"
edition = "2021"
rust-version = "1.82"
description = "Juego en grilla 3x3 de referencia para OpenTable SDK."
license = "GPL-3.0-or-later"
repository = "https://github.com/joduranvillan/games_tables_sdk"
keywords = ["game", "board-game", "tic-tac-toe", "rules"]
categories = ["game-engines", "games"]

[dependencies]
open_table_core = { path = "../open_table_core", version = "1.0.0" }
open_table_engine = { path = "../open_table_engine", version = "1.0.0" }
open_table_macros = { path = "../open_table_macros", version = "1.0.0" }
serde = { version = "1", features = ["derive"] }
typetag = "0.2"
bevy_ecs = "0.20"

[dev-dependencies]
serde_json = "1"
```

---

## Paso 2: Definir el Modelo de Datos en Rust (`board.rs`, `commands.rs`, `events.rs`)

### 2.1 Estado del Tablero (`tic_tac_toe_game/src/board.rs`)
El estado del juego se modela como uno o más structs derivados con `#[derive(GameResource)]`, que automáticamente los registra como recursos de `bevy_ecs::World`.

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};

pub const GRID_SIZE: usize = 3;

#[derive(GameResource, Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct BoardResource {
    pub cells: [[Option<PlayerId>; GRID_SIZE]; GRID_SIZE],
}

impl BoardResource {
    pub fn is_on_board(row: u8, col: u8) -> bool {
        (row as usize) < GRID_SIZE && (col as usize) < GRID_SIZE
    }

    pub fn get(&self, row: u8, col: u8) -> Option<PlayerId> {
        if !Self::is_on_board(row, col) {
            return None;
        }
        self.cells[row as usize][col as usize]
    }

    pub fn set(&mut self, row: u8, col: u8, owner: Option<PlayerId>) {
        if Self::is_on_board(row, col) {
            self.cells[row as usize][col as usize] = owner;
        }
    }

    /// Verifica si `player` ha completado 3 en línea (fila, columna o diagonal).
    pub fn has_won(&self, player: PlayerId) -> bool {
        let lines: [[(usize, usize); 3]; 8] = [
            // Filas
            [(0, 0), (0, 1), (0, 2)],
            [(1, 0), (1, 1), (1, 2)],
            [(2, 0), (2, 1), (2, 2)],
            // Columnas
            [(0, 0), (1, 0), (2, 0)],
            [(0, 1), (1, 1), (2, 1)],
            [(0, 2), (1, 2), (2, 2)],
            // Diagonales
            [(0, 0), (1, 1), (2, 2)],
            [(0, 2), (1, 1), (2, 0)],
        ];
        lines
            .iter()
            .any(|line| line.iter().all(|&(r, c)| self.cells[r][c] == Some(player)))
    }

    /// Devuelve `true` si todas las casillas están ocupadas.
    pub fn is_full(&self) -> bool {
        self.cells
            .iter()
            .all(|row| row.iter().all(|cell| cell.is_some()))
    }
}
```

> **Cómo escalarlo a Conecta 4 (6×7):** Basta con cambiar `GRID_SIZE` a `ROWS = 6, COLS = 7` y hacer que el comando reciba únicamente `col: u8`, calculando la fila libre más baja en `BoardResource::drop_in_column(col)`.

---

### 2.2 Comandos del Jugador (`tic_tac_toe_game/src/commands.rs`)
Cada comando representa la intención de un jugador. Se deriva con `#[derive(GameCommand)]` y debe marcar el campo del autor con `#[issuer]`: esto permite que `Session` verifique que ningún cliente en red suplante la identidad de otro `PlayerId`.

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;
use serde::{Deserialize, Serialize};

/// Colocar una marca (X u O) en la coordenada (row, col) de la grilla.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlaceMarkCommand {
    #[issuer]
    pub player: PlayerId,
    pub row: u8,
    pub col: u8,
}

/// Rendirse voluntariamente, otorgando la victoria al oponente.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
```

---

### 2.3 Eventos Emitidos por el Motor (`tic_tac_toe_game/src/events.rs`)
Los eventos notifican hechos consumados y validados a la vista y a los clientes remotos. Por defecto, `#[derive(GameEvent)]` asigna visibilidad pública (`Visibility::Public`).

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct MarkPlacedEvent {
    pub player: PlayerId,
    pub row: u8,
    pub col: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
    #[serde(default)]
    pub is_draw: bool,
}
```

---

## Paso 3: Generador de Jugadas Legales (`legal_moves.rs`) y Motor de Reglas (`rules.rs`)

### 3.1 Generador de Jugadas Legales (`tic_tac_toe_game/src/legal_moves.rs`)
Implementar el trait `LegalMoveGenerator` permite que la interfaz resalte las casillas válidas (`bridge.get_legal_moves_json()`) y que el motor o la IA consulten todas las jugadas posibles:

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use bevy_ecs::world::World as BevyWorld;
use open_table_core::prelude::*;
use open_table_engine::prelude::*;

use crate::board::{BoardResource, GRID_SIZE};
use crate::commands::PlaceMarkCommand;

pub struct TicTacToeLegalMoveGenerator;

impl LegalMoveGenerator for TicTacToeLegalMoveGenerator {
    fn generate(&self, world: &BevyWorld, player: PlayerId) -> Vec<Box<dyn Command>> {
        if world
            .get_resource::<GameOverResource>()
            .is_some_and(|go| go.0)
        {
            return vec![];
        }
        let Some(turn) = world.get_resource::<TurnResource>() else {
            return vec![];
        };
        if !turn.0.is_current(player) {
            return vec![];
        }
        let Some(board) = world.get_resource::<BoardResource>() else {
            return vec![];
        };

        let mut moves: Vec<Box<dyn Command>> = Vec::new();
        for r in 0..(GRID_SIZE as u8) {
            for c in 0..(GRID_SIZE as u8) {
                if board.get(r, c).is_none() {
                    moves.push(Box::new(PlaceMarkCommand {
                        player,
                        row: r,
                        col: c,
                    }));
                }
            }
        }
        moves
    }
}
```

---

### 3.2 Reglas Autoritativas (`tic_tac_toe_game/src/rules.rs`)
En `build_tic_tac_toe_rules()` registramos un closure validador por cada comando usando `rules.register::<Comando, _>(|cmd, world| { ... })`.
- Si una jugada viola una regla, retornamos `Err(EngineError::InvalidCommand { reason })`, lo cual deja el `World` intacto y emite `move_rejected` en Godot.
- Si es válida, mutamos `BoardResource`, actualizamos `GameOverResource` / `WinnerResource` si corresponde, o avanzamos el turno con `world.resource_mut::<TurnResource>().0.advance()`.

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use open_table_engine::prelude::*;

use crate::board::BoardResource;
use crate::commands::{PlaceMarkCommand, ResignCommand};
use crate::events::{GameOverEvent, MarkPlacedEvent};
use crate::legal_moves::TicTacToeLegalMoveGenerator;

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

pub fn build_tic_tac_toe_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.set_legal_move_generator(Box::new(TicTacToeLegalMoveGenerator));

    rules.register::<PlaceMarkCommand, _>(|cmd, world| {
        if !world.contains_resource::<BoardResource>() {
            world.insert_resource(BoardResource::default());
        }

        // 1. Verificar que la partida no haya terminado
        if world
            .get_resource::<GameOverResource>()
            .is_some_and(|go| go.0)
        {
            return Err(invalid("la partida ya ha finalizado"));
        }

        // 2. Verificar que sea el turno del jugador que envía el comando
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        // 3. Verificar coordenadas dentro de la grilla 3x3
        if !BoardResource::is_on_board(cmd.row, cmd.col) {
            return Err(invalid("la casilla está fuera del tablero (0..2)"));
        }

        // 4. Verificar que la casilla esté libre y colocar la marca
        let (won, draw) = {
            let mut board = world.resource_mut::<BoardResource>();
            if board.get(cmd.row, cmd.col).is_some() {
                return Err(invalid("la casilla ya está ocupada"));
            }
            board.set(cmd.row, cmd.col, Some(cmd.player));
            let won = board.has_won(cmd.player);
            let draw = !won && board.is_full();
            (won, draw)
        };

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(MarkPlacedEvent {
            player: cmd.player,
            row: cmd.row,
            col: cmd.col,
        })];

        // 5. Evaluar fin de partida o avanzar al siguiente turno
        if won {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(Some(cmd.player)));
            events.push(Box::new(GameOverEvent {
                winner: cmd.player,
                is_draw: false,
            }));
        } else if draw {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(None));
            events.push(Box::new(GameOverEvent {
                winner: PlayerId(0),
                is_draw: true,
            }));
        } else {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        if world
            .get_resource::<GameOverResource>()
            .is_some_and(|go| go.0)
        {
            return Err(invalid("la partida ya ha finalizado"));
        }
        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(invalid("no eres un jugador de esta partida"));
        }
        let opponent = players
            .into_iter()
            .find(|&p| p != cmd.player)
            .unwrap_or(cmd.player);

        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(opponent)));
        Ok(vec![Box::new(GameOverEvent {
            winner: opponent,
            is_draw: false,
        })])
    });

    rules
}
```

---

### 3.3 Punto de Entrada y Constructor de Sesión (`tic_tac_toe_game/src/lib.rs`)
Usar `session.set_initial_setup(setup)` es fundamental: le indica a `Session` cómo reconstruir el `World` desde cero cuando un jugador ejecuta **Deshacer (`undo`)**, **Rehacer (`redo`)** o reproduce un archivo de **Replay (`.otr`)**.

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod legal_moves;
pub mod rules;

pub use ai::tic_tac_toe_ai_pick_move;
pub use board::{BoardResource, GRID_SIZE};
pub use commands::{PlaceMarkCommand, ResignCommand};
pub use events::{GameOverEvent, MarkPlacedEvent};
pub use legal_moves::TicTacToeLegalMoveGenerator;
pub use rules::build_tic_tac_toe_rules;

use open_table_engine::prelude::*;

pub fn new_tic_tac_toe_session(
    session_id: SessionId,
    seed: u64,
    player_x: PlayerId,
    player_o: PlayerId,
) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "TicTacToe",
        seed,
        vec![player_x, player_o],
        build_tic_tac_toe_rules(),
    );
    let setup = move |world: &mut BevyWorld| {
        world.insert_resource(BoardResource::default());
        world.insert_resource(LegalMoveGeneratorResource(std::sync::Arc::new(
            TicTacToeLegalMoveGenerator,
        )));
    };
    setup(session.world_mut());
    session.set_initial_setup(setup);
    session
}
```

---

## Paso 4: Implementar el Oponente de IA Local (`tic_tac_toe_game/src/ai.rs`)

El módulo de IA inspecciona el `Session` actual y devuelve `Option<PlaceMarkCommand>` siguiendo una jerarquía táctica determinista:
1. Ganar inmediatamente si tiene 2 en línea.
2. Bloquear al rival si el rival amenaza con 2 en línea.
3. Tomar el centro `(1, 1)`.
4. Tomar una esquina disponible o la primera casilla libre.

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use open_table_engine::prelude::*;

use crate::board::{BoardResource, GRID_SIZE};
use crate::commands::PlaceMarkCommand;

pub fn tic_tac_toe_ai_pick_move(session: &Session, player: PlayerId) -> Option<PlaceMarkCommand> {
    if session
        .world()
        .get_resource::<GameOverResource>()
        .is_some_and(|r| r.0)
    {
        return None;
    }
    if session.current_player() != player {
        return None;
    }

    let board = session.world().get_resource::<BoardResource>()?;
    let players = session.world().resource::<TurnResource>().0.players();
    let opponent = players
        .iter()
        .copied()
        .find(|&p| p != player)
        .unwrap_or(PlayerId(1));

    // 1. Buscar jugada ganadora inmediata para `player`
    for r in 0..(GRID_SIZE as u8) {
        for c in 0..(GRID_SIZE as u8) {
            if board.get(r, c).is_none() {
                let mut sim = board.clone();
                sim.set(r, c, Some(player));
                if sim.has_won(player) {
                    return Some(PlaceMarkCommand {
                        player,
                        row: r,
                        col: c,
                    });
                }
            }
        }
    }

    // 2. Bloquear jugada ganadora inmediata del rival
    for r in 0..(GRID_SIZE as u8) {
        for c in 0..(GRID_SIZE as u8) {
            if board.get(r, c).is_none() {
                let mut sim = board.clone();
                sim.set(r, c, Some(opponent));
                if sim.has_won(opponent) {
                    return Some(PlaceMarkCommand {
                        player,
                        row: r,
                        col: c,
                    });
                }
            }
        }
    }

    // 3. Priorizar el centro (1, 1), luego esquinas y luego bordes
    let preferred_order: [(u8, u8); 9] = [
        (1, 1),
        (0, 0),
        (0, 2),
        (2, 0),
        (2, 2),
        (0, 1),
        (1, 0),
        (1, 2),
        (2, 1),
    ];
    for (r, c) in preferred_order {
        if board.get(r, c).is_none() {
            return Some(PlaceMarkCommand {
                player,
                row: r,
                col: c,
            });
        }
    }

    None
}
```

---

## Paso 5: Integrar el Juego en el Puente `OpenTableBridge` (`open_table_godot`)

> **Nota arquitectónica crítica de `gdext`:** Godot/Redot registra una única clase `#[derive(GodotClass)]` por biblioteca dinámica: **`OpenTableBridge`** (`open_table_godot/src/lib.rs`). Nunca crees un segundo `#[derive(GodotClass)]` separado; agrega los métodos `#[func]` directamente dentro de `impl OpenTableBridge`.

### 5.1 Añadir la dependencia en `open_table_godot/Cargo.toml`
```toml
tic_tac_toe_game = { path = "../tic_tac_toe_game", version = "0.1.0" }
```

### 5.2 Exponer los métodos `#[func]` en `open_table_godot/src/lib.rs`
Dentro del bloque `#[godot_api] impl OpenTableBridge`, añade los métodos para iniciar partida (Hotseat o vs IA) y enviar jugadas:

```rust
use tic_tac_toe_game::{
    new_tic_tac_toe_session, tic_tac_toe_ai_pick_move, GameOverEvent as TttGameOverEvent,
    MarkPlacedEvent, PlaceMarkCommand,
};

#[godot_api]
impl OpenTableBridge {
    #[func]
    pub fn start_local_match_tic_tac_toe(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "tic_tac_toe".to_string();
        let session = new_tic_tac_toe_session(
            SessionId(1),
            1,
            PlayerId(p1 as u32),
            PlayerId(p2 as u32),
        );
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);
    }

    #[func]
    pub fn start_local_match_tic_tac_toe_vs_ai(
        &mut self,
        human_player: i64,
        ai_player: i64,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }
        self.current_game_type = "tic_tac_toe".to_string();
        let p_human = PlayerId(human_player as u32);
        let p_ai = PlayerId(ai_player as u32);
        let (p1, p2) = if human_player < ai_player {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_tic_tac_toe_session(SessionId(1), 1, p1, p2);
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: Some(p_ai),
        };
        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);
        self.process_ai_turn_if_needed();
        true
    }

    #[func]
    pub fn send_tic_tac_toe_move(&mut self, player: i64, row: i64, col: i64) -> bool {
        let p = PlayerId(player as u32);
        let cmd = PlaceMarkCommand {
            player: p,
            row: row as u8,
            col: col as u8,
        };

        let result = match &mut self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. } => session.process_command(p, Box::new(cmd)),
            _ => return false,
        };

        match result {
            Ok(events) => {
                for ev in &events {
                    if let Some(placed) = ev.as_any().downcast_ref::<MarkPlacedEvent>() {
                        let json = serde_json::json!({
                            "type": "MarkPlacedEvent",
                            "player": placed.player.0,
                            "row": placed.row,
                            "col": placed.col,
                        })
                        .to_string();
                        self.base_mut()
                            .emit_signal("event_json", &[Variant::from(json.as_str())]);
                    }
                    if let Some(over) = ev.as_any().downcast_ref::<TttGameOverEvent>() {
                        let winner_id = if over.is_draw { 0 } else { over.winner.0 as i64 };
                        self.base_mut()
                            .emit_signal("game_over", &[Variant::from(winner_id)]);
                    }
                }
                let next_p = self.current_player();
                self.base_mut()
                    .emit_signal("turn_changed", &[Variant::from(next_p)]);
                self.process_ai_turn_if_needed();
                true
            }
            Err(err) => {
                let reason = err.to_string();
                self.base_mut()
                    .emit_signal("move_rejected", &[Variant::from(reason.as_str())]);
                false
            }
        }
    }
}
```

Y dentro de `process_ai_turn_if_needed(&mut self)` en `open_table_godot/src/lib.rs`, añade la rama para `"tic_tac_toe"`:

```rust
if self.current_game_type == "tic_tac_toe" {
    if let BridgeMode::Local {
        session,
        ai_player: Some(ai_p),
    } = &self.mode
    {
        if session.current_player() == *ai_p {
            if let Some(ai_cmd) = tic_tac_toe_ai_pick_move(session, *ai_p) {
                let _ = self.send_tic_tac_toe_move(
                    ai_p.0 as i64,
                    ai_cmd.row as i64,
                    ai_cmd.col as i64,
                );
            }
        }
    }
}
```

---

## Paso 6: Crear la Escena y el Tablero en Godot / Redot (`godot_project/tic_tac_toe_board.gd`)

### Convenciones Obligatorias para Tableros en `godot_project`
1. **Tipado explícito Redot strict**: Nunca uses `:=` cuando la expresión de la derecha retorne `Variant` (`JSON.parse_string()`, `dict.get()`, `arr[i]`, `.call()`). Escribe siempre el tipo explícito (`var parsed: Variant = ...`, `var ev: Dictionary = ...`).
2. **HUD Superior Compacto**: Instancia `TurnIndicator` (`res://turn_indicator.gd`). Automáticamente provee el indicador de color del jugador, el texto `"Turno: Jugador X"`, el badge regresivo `TurnTimerHud` (`00:30`) y adjunta `GameAppMenu` (`☰ Opciones ▾`) en la esquina superior derecha.
3. **Sin texto de turno duplicado**: El nodo `Status` debe mantenerse vacío (`status.text = ""`) durante el desarrollo normal del turno para no superponerse con `TurnIndicator`, usándose solo para errores (`move_rejected`) o mensaje de victoria/empate.
4. **Paridad de archivos**: Guarda exactamente el mismo script en `godot_project/tic_tac_toe_board.gd` y en `godot_project/scenes/tic_tac_toe_board.gd`.

```gdscript
extends Node2D

const GRID := 3
const CELL := 160.0
const P1 := 1
const P2 := 2

var bridge: OpenTableBridge
var board: Array = [] # board[row][col] = 0 | 1 | 2
var current: int = P1
var winner: int = -1
var is_draw: bool = false

var turn_indicator: TurnIndicator
var mode_option_button: OptionButton
var rules_popup: RulesPopup
@onready var status: Label = get_node_or_null("Status")

func _ready() -> void:
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	status.position = Vector2(12, 500)

	_init_board()
	_setup_ui()

	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	bridge.connect("event_json", _on_event_json)
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)

	bridge.start_local_match_tic_tac_toe(P1, P2)
	current = bridge.current_player()
	_on_layout_changed(0)
	_update_status()
	queue_redraw()

func _init_board() -> void:
	board.clear()
	for r in range(GRID):
		var row_arr: Array = [0, 0, 0]
		board.append(row_arr)

func _setup_ui() -> void:
	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.visible = false
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano J1 - X)")
	mode_option_button.add_item("vs IA (Humano J2 - O, IA inicia)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(12, -52)
	add_child(turn_indicator)

func _on_mode_selected(index: int) -> void:
	_init_board()
	winner = -1
	is_draw = false
	if index == 1:
		bridge.start_local_match_tic_tac_toe_vs_ai(P1, P2)
	elif index == 2:
		bridge.start_local_match_tic_tac_toe_vs_ai(P2, P1)
	else:
		bridge.start_local_match_tic_tac_toe(P1, P2)
	current = bridge.current_player()
	_update_status()
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var vis: Vector2 = get_viewport().get_visible_rect().size
		if vis.x > 0.0 and vis.y > 0.0:
			vp_size = vis
	var design_w: float = float(GRID) * CELL
	var design_h: float = 560.0
	var s: float = clampf(minf((vp_size.x - 40.0) / design_w, (vp_size.y - 24.0) / design_h), 0.4, 1.0)
	scale = Vector2(s, s)
	position = Vector2((vp_size.x - design_w * s) * 0.5, (vp_size.y - design_h * s) * 0.5 + 36.0 * s)

func _input(event: InputEvent) -> void:
	if winner != -1 or is_draw:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos: Vector2 = get_local_mouse_position()
		var col: int = int(floor(local_pos.x / CELL))
		var row: int = int(floor(local_pos.y / CELL))
		if row >= 0 and row < GRID and col >= 0 and col < GRID:
			bridge.send_tic_tac_toe_move(current, row, col)

func _on_event_json(raw_json: String) -> void:
	var parsed: Variant = JSON.parse_string(raw_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ev: Dictionary = parsed as Dictionary
	var ev_type: String = String(ev.get("type", ""))
	if ev_type == "MarkPlacedEvent":
		var r: int = int(ev.get("row", 0))
		var c: int = int(ev.get("col", 0))
		var p: int = int(ev.get("player", P1))
		board[r][c] = p
		current = bridge.current_player()
		_update_status()
		queue_redraw()

func _on_game_over(win_id: int) -> void:
	if win_id == 0:
		is_draw = true
		winner = 0
	else:
		winner = win_id
	_update_status()
	queue_redraw()

func _on_move_rejected(reason: String) -> void:
	if status != null:
		status.text = "Movimiento inválido: %s" % reason

func _update_status() -> void:
	if status == null:
		return
	if is_draw:
		status.text = "¡Empate! Tablero completo."
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	elif winner > 0:
		status.text = "¡Ganó el Jugador %d!" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		status.text = ""
		var who: String = "Jugador 1 (X)" if current == P1 else "Jugador 2 (O)"
		var col: Color = Color(0.90, 0.22, 0.22) if current == P1 else Color(0.22, 0.55, 0.95)
		if turn_indicator != null:
			turn_indicator.set_turn(current, who, col)
			turn_indicator.set_active(true)

func _draw() -> void:
	var span: float = float(GRID) * CELL
	draw_rect(Rect2(0, 0, span, span), Color(0.14, 0.16, 0.22, 0.96))
	draw_rect(Rect2(0, 0, span, span), Color(0.35, 0.45, 0.65), false, 3.0)

	for i in range(1, GRID):
		var offset: float = float(i) * CELL
		draw_line(Vector2(offset, 12.0), Vector2(offset, span - 12.0), Color(0.45, 0.55, 0.75), 4.0)
		draw_line(Vector2(12.0, offset), Vector2(span - 12.0, offset), Color(0.45, 0.55, 0.75), 4.0)

	for r in range(GRID):
		for c in range(GRID):
			var cell_owner: int = int(board[r][c])
			var center: Vector2 = Vector2(float(c) * CELL + CELL * 0.5, float(r) * CELL + CELL * 0.5)
			if cell_owner == P1:
				var d: float = CELL * 0.28
				draw_line(center + Vector2(-d, -d), center + Vector2(d, d), Color(0.95, 0.28, 0.28), 8.0)
				draw_line(center + Vector2(d, -d), center + Vector2(-d, d), Color(0.95, 0.28, 0.28), 8.0)
			elif cell_owner == P2:
				draw_arc(center, CELL * 0.30, 0.0, TAU, 36, Color(0.28, 0.65, 1.0), 8.0)
```

---

## Paso 7: Tests de Certificación en Rust y Smoke Test en Godot

### 7.1 Tests de Reglas Canónicas en Rust (`tic_tac_toe_game/tests/canonical_rules.rs`)
Crea `tic_tac_toe_game/tests/canonical_rules.rs` y ejecútalo con `cargo test -p tic_tac_toe_game`:

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use open_table_engine::prelude::*;
use tic_tac_toe_game::{
    new_tic_tac_toe_session, tic_tac_toe_ai_pick_move, GameOverEvent, PlaceMarkCommand,
    ResignCommand,
};

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn mark(player: PlayerId, row: u8, col: u8) -> Box<dyn Command> {
    Box::new(PlaceMarkCommand { player, row, col })
}

#[test]
fn canonical_victoria_tres_en_linea_y_bloqueo_post_partida() {
    let mut session = new_tic_tac_toe_session(SessionId(1), 42, P1, P2);

    session.process_command(P1, mark(P1, 0, 0)).unwrap();
    session.process_command(P2, mark(P2, 1, 0)).unwrap();
    session.process_command(P1, mark(P1, 0, 1)).unwrap();
    session.process_command(P2, mark(P2, 1, 1)).unwrap();

    // P1 completa la fila superior (0,0), (0,1), (0,2)
    let events = session
        .process_command(P1, mark(P1, 0, 2))
        .expect("jugada ganadora debe ser válida");

    let over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debe emitir GameOverEvent");

    assert_eq!(over.winner, P1);
    assert!(!over.is_draw);

    // Cualquier jugada posterior debe ser rechazada
    assert!(session.process_command(P2, mark(P2, 2, 2)).is_err());
}

#[test]
fn canonical_rechaza_casilla_ocupada_y_turno_incorrecto() {
    let mut session = new_tic_tac_toe_session(SessionId(2), 42, P1, P2);

    // P2 no puede jugar en el turno de P1
    assert!(session.process_command(P2, mark(P2, 0, 0)).is_err());

    session.process_command(P1, mark(P1, 1, 1)).unwrap();

    // P2 no puede jugar sobre la casilla (1, 1) ya ocupada por P1
    assert!(session.process_command(P2, mark(P2, 1, 1)).is_err());
}

#[test]
fn canonical_empate_en_tablero_lleno_y_bloqueo_ia() {
    let mut session = new_tic_tac_toe_session(SessionId(3), 42, P1, P2);
    // P1 tiene (0,0) y (0,1); en el turno de P2 la IA debe bloquear en (0,2)
    session.process_command(P1, mark(P1, 0, 0)).unwrap();
    session.process_command(P2, mark(P2, 1, 1)).unwrap();
    session.process_command(P1, mark(P1, 0, 1)).unwrap();

    let ai_move = tic_tac_toe_ai_pick_move(&session, P2).expect("IA debe encontrar jugada");
    assert_eq!((ai_move.row, ai_move.col), (0, 2));

    // Rendición adjudica la victoria al rival
    let events = session
        .process_command(P2, Box::new(ResignCommand { player: P2 }))
        .unwrap();
    let over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .unwrap();
    assert_eq!(over.winner, P1);
}
```

---

### 7.2 Smoke Test Headless en Godot (`godot_project/tests/tic_tac_toe_smoke.gd`)
Crea `godot_project/tests/tic_tac_toe_smoke.gd` para certificar la integración E2E entre el script de Godot y `OpenTableBridge`:

```gdscript
extends SceneTree

func _initialize() -> void:
	var board_script: Script = load("res://tic_tac_toe_board.gd") as Script
	assert(board_script != null, "tic_tac_toe_board.gd debe cargar sin errores")

	var board_node: Node2D = board_script.new() as Node2D
	get_root().add_child(board_node)
	if board_node.get("turn_indicator") == null and board_node.has_method("_ready"):
		board_node._ready()

	var ti: Control = board_node.get("turn_indicator") as Control
	assert(ti != null, "TurnIndicator debe instanciarse en la barra superior")
	var app_menu: Node = board_node.get_node_or_null("GameAppMenu")
	assert(app_menu != null, "GameAppMenu debe adjuntarse automáticamente al tablero")

	var bridge_ref: Object = board_node.get("bridge") as Object
	assert(bridge_ref != null, "OpenTableBridge debe estar activo")

	# Jugada válida de J1 en (0, 0)
	var ok_move: bool = bool(bridge_ref.call("send_tic_tac_toe_move", 1, 0, 0))
	assert(ok_move == true, "Jugada inicial en (0, 0) debe ser aceptada")

	# Intentar jugar en la misma casilla (0, 0) con J2 debe ser rechazado
	var bad_move: bool = bool(bridge_ref.call("send_tic_tac_toe_move", 2, 0, 0))
	assert(bad_move == false, "Jugada en casilla ocupada debe emitir move_rejected")

	get_root().remove_child(board_node)
	board_node.free()
	print("RESULTADO: PASS (tic_tac_toe_smoke.gd)")
	quit(0)
```

---

## Paso 8: Comandos de Verificación Final del Proyecto

Una vez completados los pasos anteriores, ejecuta desde la raíz del repositorio:

```bash
# 1. Compilar y correr todos los tests de Rust (incluyendo el nuevo juego)
cargo test --workspace

# 2. Compilar la biblioteca nativa GDExtension para Godot / Redot
cargo build -p open_table_godot

# 3. Ejecutar el validador estático Redot strict y todos los smoke tests de Godot
./tools/run_godot_tests.sh
```
