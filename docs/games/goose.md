# El Juego de la Oca (`goose_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Recorrido clásico en espiral de 63 casillas (`GARDEN_SQUARE = 63`)**, con soporte de **2 a 4 jugadores**, **1 dado de 6 caras** renderizado en 3D (`DiceRoller3D` / `DiceWidget`) y llegada con **rebote exacto** en el Jardín de la Oca (`63`).
- **Ocas (`5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59, 63`)**:
  - *"De oca a oca y tiro porque me toca"*: Al caer en una casilla de Oca (salvo la meta `63`), la ficha avanza automáticamente a la siguiente Oca de la lista y el jugador recibe un **turno extra inmediato** (excepto si salta de `59` a `63`, donde gana la partida).
- **Puentes (`6 ↔ 12`) y Dados (`26 ↔ 53`)**:
  - *"De puente a puente y tiro porque me lleva la corriente"*: Caer en `6` salta a `12` y caer en `12` salta a `6`, otorgando turno extra.
  - *"De dado a dado y tiro porque me ha tocado"*: Caer en `26` salta a `53` y caer en `53` salta a `26`, otorgando turno extra.
- **Casillas de Espera y Rescate**:
  - **Posada (`19`)**: Pierde `1` turno (`wait_turns = 1`).
  - **Pozo (`31`)**: Pierde `2` turnos (`wait_turns = 2`) o queda liberado inmediatamente si otro jugador cae en el Pozo (`31`).
  - **Cárcel (`52`)**: Pierde `3` turnos (`wait_turns = 3`).
- **Retrocesos y Rebote en Meta**:
  - **Laberinto (`42`)**: Retrocede a la casilla `30`.
  - **Calavera / Muerte (`58`)**: Retrocede al inicio en la casilla `1`.
  - **Rebote Exacto en `63`**: Si la suma supera `63`, la ficha retrocede desde `63` tantos pasos como puntos sobren (`63 - (dest - 63)`) y se evalúa la casilla donde aterriza tras el rebote.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `RollDiceCommand` | Lanza el dado de 6 caras al inicio del turno o tirada extra. | `{"command_type": "RollDiceCommand", "player": 1}` |
| `MoveTokenCommand` | Avanza la ficha del jugador según el dado pendiente y resuelve efectos especiales. | `{"command_type": "MoveTokenCommand", "player": 1}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria a un oponente activo. | `{"command_type": "ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `DiceRolledEvent` | `player: PlayerId`, `value: u32` | `{"event_type": "DiceRolledEvent", "player": 1, "value": 5}` |
| `TokenMovedEvent` | `player: PlayerId`, `dice_value: u32`, `from_square: u32`, `landed_square: u32`, `to_square: u32`, `effect: String`, `bonus_turn: bool`, `wait_turns: u32`, `bounced: bool`, `finished: bool` | `{"event_type": "TokenMovedEvent", "player": 1, "dice_value": 5, "from_square": 0, "landed_square": 5, "to_square": 9, "effect": "goose_jump", "bonus_turn": true, "wait_turns": 0, "bounced": false, "finished": false}` |
| `TurnSkippedPenaltyEvent` | `player: PlayerId`, `square: u32`, `remaining_wait: u32` | `{"event_type": "TurnSkippedPenaltyEvent", "player": 1, "square": 19, "remaining_wait": 0}` |
| `GameOverEvent` | `winner: PlayerId` | `{"event_type": "GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_goose_session(SessionId(1), seed, vec![PlayerId(1), PlayerId(2)])` ubica todas las fichas en la salida (`square = 0`).
2. **Tirada y Animación 3D**: Jugador 1 envía `RollDiceCommand`, el widget 3D (`DiceWidget` + `DiceRoller3D`) muestra el lanzamiento 3D en el centro del tablero y pausa brevemente sobre la cara resultante antes de que `goose_board.gd` desplace la ficha paso a paso por la espiral.
3. **Resolución de Casilla Especial**: Al ejecutar `MoveTokenCommand`, el motor aplica saltos de Oca/Puente/Dados, penalizaciones de Posada/Pozo/Cárcel o rebotes desde la casilla `63`.
4. **Fin**: El primer jugador en aterrizar exactamente en la casilla `63` (o saltar desde la Oca `59` hasta `63`) emite `GameOverEvent`.
