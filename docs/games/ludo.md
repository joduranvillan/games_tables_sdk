# Ludo (`ludo_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Circuito oficial de 52 casillas (`TRACK_LEN = 52`)** más **pasillo final de 5 casillas** hacia la meta central (`FINISH_STEPS = 57`), con soporte de **2 a 4 jugadores** y **4 fichas por jugador** (`TOKENS_PER_PLAYER = 4`).
- **Salida de Base y Turno Extra con 6**:
  - Una ficha en la base inicial (`steps == 0`) requiere obtener un `6` en el dado para salir a su casilla de partida (`steps = 1`).
  - Obtener un `6` otorga una tirada adicional, sujeta a la regla de penalización por **tres seises consecutivos** (`three_sixes_penalty: true`), que anula el tercer movimiento y cede el turno al siguiente jugador.
- **Casillas Seguras, Estrellas y Capturas**:
  - Las casillas de salida de cada color (`0, 13, 26, 39`) y las **4 casillas de estrella** (`+8` desde cada salida: `8, 21, 34, 47`) son zonas seguras donde las fichas no pueden ser capturadas.
  - Aterrizar sobre una ficha rival en una casilla normal la captura y la devuelve a su base inicial (`steps = 0`).
- **Tirada Extra por Captura o Meta (`bonus_roll_on_capture_and_goal`)**:
  - Capturar una ficha enemiga o introducir una ficha propia con tirada exacta en la meta (`steps == 57`) concede una tirada extra inmediata.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `RollDiceCommand` | Lanza el dado de 6 caras al inicio del turno o tirada extra. | `{"command_type": "ludo_game::RollDiceCommand", "player": 1}` |
| `MoveTokenCommand` | Avanza la ficha `token_index` (`0..3`) el número de pasos obtenidos en el dado. | `{"command_type": "ludo_game::MoveTokenCommand", "player": 1, "token_index": 0}` |
| `SetLudoRulesCommand` | Configura las variantes reglamentarias (casillas estrella seguras, bono por captura/meta y penalización por tres 6). | `{"command_type": "ludo_game::SetLudoRulesCommand", "star_safe_squares": true, "bonus_roll_on_capture_and_goal": true, "three_sixes_penalty": true}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria al oponente. | `{"command_type": "ludo_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `DiceRolledEvent` | `player: PlayerId`, `value: u32` | `{"event_type": "ludo_game::DiceRolledEvent", "player": 1, "value": 6}` |
| `TokenMovedEvent` | `player: PlayerId`, `token_index: usize`, `from_steps: u32`, `to_steps: u32`, `captured: Option<(PlayerId, usize)>`, `finished: bool` | `{"event_type": "ludo_game::TokenMovedEvent", "player": 1, "token_index": 0, "from_steps": 0, "to_steps": 1, "captured": null, "finished": false}` |
| `NoValidMovesEvent` | `player: PlayerId`, `value: u32` | `{"event_type": "ludo_game::NoValidMovesEvent", "player": 1, "value": 4}` |
| `GameOverEvent` | `winner: PlayerId` | `{"event_type": "ludo_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_ludo_session(SessionId(1), seed, vec![PlayerId(1), PlayerId(2)])` ubica las 4 fichas de cada jugador en su base (`steps = 0`).
2. **Salida**: Jugador 1 envía `RollDiceCommand`, obtiene `6` y ejecuta `MoveTokenCommand { player: PlayerId(1), token_index: 0 }` para colocar su ficha en la casilla de salida y conservar el turno.
3. **Captura y Meta**: Al capturar una ficha rival fuera de casilla segura o entrar con cuenta exacta a `to_steps: 57` (`finished: true`), el jugador recibe tirada extra.
4. **Fin**: Cuando las 4 fichas de un jugador alcanzan `steps == 57`, se emite `GameOverEvent`.
