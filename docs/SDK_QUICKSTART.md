# OpenTable SDK — Guía de Integración Rápida en 15 Minutos (`SDK_QUICKSTART.md`)

Esta guía muestra cómo implementar tu propio juego de mesa determinista desde cero usando los traits de `open_table_core`, registrarlo en una sesión autoritativa de `open_table_engine` y conectarlo con las señales de Godot / Redot en menos de 15 minutos.

---

## 1. Arquitectura en 30 segundos

Cada juego en OpenTable SDK se define mediante tres elementos puros en Rust:

1. **`State` (`Resource` ECS)**: El estado del tablero y el turno actual (`PlayerId`).
2. **`Action` / `Command` (`#[game_command]`)**: La intención serializable enviada por un jugador.
3. **`GameEngine` / Regla de validación**: Función pura que valida `(&mut World, PlayerId, &dyn Command)` y emite `Box<dyn Event>`.

---

## 2. Ejemplo completo: Tres en Línea (`Tic-Tac-Toe`) en < 100 líneas de Rust

```rust
use bevy_ecs::prelude::*;
use open_table_core::{Command, Event, GameError, PlayerId, RuleEngine};
use open_table_macros::{game_command, game_event};
use serde::{Deserialize, Serialize};

/// 1. Estado del juego (State) almacenado en el World ECS
#[derive(Resource, Debug, Clone, Serialize, Deserialize)]
pub struct TicTacToeState {
    pub grid: [[Option<PlayerId>; 3]; 3],
    pub current_turn: PlayerId,
    pub winner: Option<PlayerId>,
}

impl Default for TicTacToeState {
    fn default() -> Self {
        Self {
            grid: [[None; 3]; 3],
            current_turn: PlayerId(1),
            winner: None,
        }
    }
}

/// 2. Acción del jugador (Action / Command)
#[game_command]
pub struct PlaceMarkCommand {
    pub row: usize,
    pub col: usize,
}

/// 3. Evento resultante para notificar a la vista (Godot / Redot)
#[game_event]
pub struct MarkPlacedEvent {
    pub player: PlayerId,
    pub row: usize,
    pub col: usize,
    pub winner: Option<PlayerId>,
}

/// 4. Trait GameEngine para encapsular reglas y consulta de jugadas
pub trait GameEngine {
    type State;
    type Action;
    fn apply_action(state: &mut Self::State, player: PlayerId, action: &Self::Action) -> Result<Option<PlayerId>, GameError>;
}

pub struct TicTacToeEngine;

impl GameEngine for TicTacToeEngine {
    type State = TicTacToeState;
    type Action = PlaceMarkCommand;

    fn apply_action(state: &mut Self::State, player: PlayerId, action: &Self::Action) -> Result<Option<PlayerId>, GameError> {
        if state.winner.is_some() {
            return Err(GameError::InvalidAction("La partida ya terminó".into()));
        }
        if state.current_turn != player {
            return Err(GameError::NotYourTurn);
        }
        if action.row >= 3 || action.col >= 3 || state.grid[action.row][action.col].is_some() {
            return Err(GameError::InvalidMove("Casilla inválida u ocupada".into()));
        }
        state.grid[action.row][action.col] = Some(player);
        let lines = [
            [(0, 0), (0, 1), (0, 2)], [(1, 0), (1, 1), (1, 2)], [(2, 0), (2, 1), (2, 2)],
            [(0, 0), (1, 0), (2, 0)], [(0, 1), (1, 1), (2, 1)], [(0, 2), (1, 2), (2, 2)],
            [(0, 0), (1, 1), (2, 2)], [(0, 2), (1, 1), (2, 0)],
        ];
        if lines.iter().any(|l| l.iter().all(|&(r, c)| state.grid[r][c] == Some(player))) {
            state.winner = Some(player);
        } else {
            state.current_turn = if player == PlayerId(1) { PlayerId(2) } else { PlayerId(1) };
        }
        Ok(state.winner)
    }
}

/// 5. Registro en RuleEngine y open_table_engine::Session
pub fn register_tic_tac_toe(world: &mut World, rules: &mut RuleEngine) {
    world.insert_resource(TicTacToeState::default());
    rules.add_command_validator(|world, player, cmd| {
        let Some(action) = cmd.as_any().downcast_ref::<PlaceMarkCommand>() else {
            return Ok(vec![]);
        };
        let mut state = world.resource_mut::<TicTacToeState>();
        let winner = TicTacToeEngine::apply_action(&mut state, player, action)?;
        Ok(vec![Box::new(MarkPlacedEvent {
            player,
            row: action.row,
            col: action.col,
            winner,
        }) as Box<dyn Event>])
    });
}
```

---

## 3. Registro en `open_table_engine::Session`

Para crear una sesión local, contra IA o en red (TCP / WebSocket Relay) con historial de repetición (`ActionHistory`):

```rust
use bevy_ecs::world::World;
use open_table_core::{PlayerId, RuleEngine};
use open_table_engine::EngineSession;

fn start_session() -> EngineSession {
    let mut world = World::new();
    let mut rules = RuleEngine::new();
    register_tic_tac_toe(&mut world, &mut rules);
    EngineSession::new(world, rules)
}
```

---

## 4. Conexión con Godot / Redot vía Señales

En tu escena de Godot (`res://scenes/tic_tac_toe_board.gd`), instancia `OpenTableBridge` y conecta sus señales:

```gdscript
extends Node2D

var bridge: OpenTableBridge

func _ready() -> void:
    bridge = OpenTableBridge.new()
    add_child(bridge)
    bridge.board_updated.connect(_on_board_updated)
    bridge.game_over.connect(_on_game_over)
    bridge.move_rejected.connect(_on_move_rejected)

func enviar_jugada(player_id: int, fila: int, columna: int) -> void:
    var cmd := {
        "command_type": "PlaceMarkCommand",
        "row": fila,
        "col": columna
    }
    bridge.send_command_json(player_id, JSON.stringify(cmd))

func _on_board_updated(state_json: String) -> void:
    var state = JSON.parse_string(state_json)
    queue_redraw()

func _on_game_over(winner_id: int) -> void:
    print("¡Victoria del jugador %d!" % winner_id)

func _on_move_rejected(reason: String) -> void:
    print("Movimiento rechazado: ", reason)
```
