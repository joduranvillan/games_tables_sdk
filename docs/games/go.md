# Go (`go_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Tamaños de tablero configurables**: soporte para tableros oficiales de **9×9**, **13×13** y **19×19** (`new_go_session_with_size`).
- **Libertades, Cadenas y Captura**: cálculo de grupos conectados ortogonalmente; cualquier cadena rival que queda con 0 libertades tras una jugada es capturada y retirada del tablero.
- **Prohibición de Suicidio y Regla de Superko Posicional**:
  - Se rechaza colocar una piedra que deje al propio grupo sin libertades salvo que capture piedras enemigas en el mismo movimiento.
  - Se verifica el historial de hashes del tablero (**Superko posicional**) impidiendo repetir cualquier estado previo de la partida.
- **Handicap, Komi y Fase de Marcado de Piedras Muertas (`DeadMarkingResource`)**:
  - Configuración de `SetKomiCommand` (por defecto 6.5 puntos = 13 medios puntos) y colocación inicial de piedras de ventaja con `PlaceHandicapCommand`.
  - Tras dos pases consecutivos (`PassCommand`), se activa la fase de marcado de grupos muertos (`MarkDeadCommand` y `ConfirmDeadCommand`) antes del cómputo final de puntuación territorial/área.
- **Exportación SGF**: serialización de la partida en formato estándar Smart Game Format (`sgf`).

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `PlaceStoneCommand` | Coloca una piedra en la intersección `(x, y)`. | `{"command_type": "go_game::PlaceStoneCommand", "player": 1, "x": 3, "y": 3}` |
| `PassCommand` | Pasa el turno; dos pases consecutivos inician la fase de marcado de piedras muertas o cierre. | `{"command_type": "go_game::PassCommand", "player": 1}` |
| `PlaceHandicapCommand` | Coloca piedras de handicap en las coordenadas estrella al inicio de la partida. | `{"command_type": "go_game::PlaceHandicapCommand", "player": 1, "positions": [[2, 2], [6, 6]]}` |
| `MarkDeadCommand` | Marca o desmarca grupos de piedras como muertas durante la fase de acuerdo post-pases. | `{"command_type": "go_game::MarkDeadCommand", "player": 1, "positions": [[4, 4]]}` |
| `ConfirmDeadCommand` | Confirma el acuerdo sobre las piedras muertas marcadas para proceder al conteo final. | `{"command_type": "go_game::ConfirmDeadCommand", "player": 1}` |
| `SetKomiCommand` | Ajusta la compensación de Komi en medios puntos (ej. `13` = `6.5` puntos). | `{"command_type": "go_game::SetKomiCommand", "player": 1, "komi_half_points": 13}` |
| `ResignCommand` | Se rinde inmediatamente otorgando la victoria por abandono (`B+R` o `W+R`). | `{"command_type": "go_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `StonePlacedEvent` | `player: PlayerId`, `x: usize`, `y: usize` | `{"event_type": "go_game::StonePlacedEvent", "player": 1, "x": 3, "y": 3}` |
| `StonesCapturedEvent` | `player: PlayerId`, `count: usize` | `{"event_type": "go_game::StonesCapturedEvent", "player": 1, "count": 2}` |
| `PassedEvent` | `player: PlayerId` | `{"event_type": "go_game::PassedEvent", "player": 1}` |
| `GameOverEvent` | `winner: Option<PlayerId>`, `reason: String`, `black_score: f32`, `white_score: f32` | `{"event_type": "go_game::GameOverEvent", "winner": 1, "reason": "Score", "black_score": 42.0, "white_score": 35.5}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: Tablero 9×9, 13×13 o 19×19 inicializado con Komi de 6.5 puntos para Blancas.
2. **Juego**: Negras y Blancas alternan `PlaceStoneCommand`, emitiendo `StonePlacedEvent` y `StonesCapturedEvent` cuando se reducen a cero las libertades de un grupo enemigo.
3. **Pases y Acuerdo**: Ambos jugadores ejecutan `PassCommand`, marcan piedras muertas si corresponde (`MarkDeadCommand`) y confirman con `ConfirmDeadCommand`.
4. **Cómputo Final**: El motor calcula territorio más capturas más Komi y emite `GameOverEvent`.
