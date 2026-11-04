# El Juego de la Oca (`goose_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Tablero tradicional en espiral de 63 casillas (`GARDEN_SQUARE = 63`)**, con casilla de salida (`0`) y soporte de **2 a 6 jugadores** (por defecto 2 a 4 en la UI local/IA).
- **Casillas de Oca (`GOOSE_SQUARES = [5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59]`)**:
  - *«De oca a oca y tiro porque me toca»*: al aterrizar en una Oca, la ficha salta automáticamente a la siguiente casilla de Oca y el jugador conserva el turno (`bonus_turn = true`). Si cae en la Oca `59`, avanza directamente al **Jardín de la Oca (`63`)** y gana la partida.
- **Casillas Especiales con Turno Extra**:
  - **Puentes (`6` y `12`)**: *«De puente a puente y tiro porque me lleva la corriente»* — salta entre `6` y `12` y otorga turno extra.
  - **Dados (`26` y `53`)**: *«De dado a dado y tiro porque me ha tocado»* — salta entre `26` y `53` y otorga turno extra.
- **Casillas de Penalización y Retroceso**:
  - **Posada (`19`)**: pierde `1` turno (`wait_turns = 1`).
  - **Pozo (`31`)**: pierde `2` turnos (`wait_turns = 2`) o queda liberado si otro jugador cae en el Pozo.
  - **Laberinto (`42`)**: retrocede inmediatamente a la casilla `30` (`LABYRINTH_TARGET = 30`).
  - **Cárcel (`52`)**: pierde `3` turnos (`wait_turns = 3`).
  - **Calavera / Muerte (`58`)**: retrocede al inicio en la casilla `1` (`SKULL_TARGET = 1`).
- **Llegada Exacta y Rebote en el Jardín de la Oca (`63`)**:
  - Para ganar es obligatorio entrar en la casilla `63` con cuenta exacta. Si la suma supera `63`, la ficha rebota hacia atrás (`63 - exceso`), aplicándose el efecto de la casilla donde termine tras el rebote.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `RollDiceCommand` | Lanza el dado de 6 caras (`1..=6`) al inicio del turno o tirada extra. | `{"command_type": "goose_game::RollDiceCommand", "player": 1}` |
| `MoveTokenCommand` | Avanza la ficha del jugador según el valor pendiente del dado y resuelve encadenamientos y penalizaciones. | `{"command_type": "goose_game::MoveTokenCommand", "player": 1}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria al oponente activo. | `{"command_type": "goose_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `DiceRolledEvent` | `player: PlayerId`, `value: u8` | `{"event_type": "goose_game::DiceRolledEvent", "player": 1, "value": 5}` |
| `GooseMovedEvent` | `player: PlayerId`, `from_square: u8`, `raw_square: u8`, `to_square: u8`, `bonus_turn: bool`, `wait_turns: u8`, `effect: String`, `finished: bool` | `{"event_type": "goose_game::GooseMovedEvent", "player": 1, "from_square": 0, "raw_square": 5, "to_square": 9, "bonus_turn": true, "wait_turns": 0, "effect": "¡De oca (5) a oca (9) y tiro porque me toca!", "finished": false}` |
| `TurnSkippedEvent` | `player: PlayerId`, `remaining_wait: u8` | `{"event_type": "goose_game::TurnSkippedEvent", "player": 2, "remaining_wait": 1}` |
| `GameOverEvent` | `winner: PlayerId` | `{"event_type": "goose_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_goose_session(SessionId(1), seed, vec![PlayerId(1), PlayerId(2)])` coloca todas las fichas en la salida (`square = 0`).
2. **Tirada y Avance**: El jugador en turno envía `RollDiceCommand` (recibiendo `DiceRolledEvent`) y a continuación `MoveTokenCommand` (emitiendo `GooseMovedEvent`).
3. **Resolución de Casillas Especiales**: Si `bonus_turn == true` (Oca, Puente o Dados), el jugador conserva el turno; si `wait_turns > 0`, sus siguientes turnos emiten `TurnSkippedEvent` al pasar por la cola de turnos.
4. **Fin**: Al aterrizar exactamente en `to_square == 63` (`finished == true`), se emite `GameOverEvent`.
