# Xiangqi (`xiangqi_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Tablero tradicional de 9×10 intersecciones** (`col: 0..8`, `row: 0..9`) dividido por el **Río Central** (entre las filas 4 y 5) y con dos **Palacios Imperiales** de 3×3 (`col: 3..5`, filas `0..2` y `7..9`).
- **Geometría y bloqueos auténticos por pieza**:
  - **General (`General`)** y **Consejero (`Advisor`)**: confinados estrictamente dentro del Palacio 3×3.
  - **Elefante (`Elephant`)**: mueve 2 intersecciones en diagonal sin cruzar nunca el Río Central; queda bloqueado si el "ojo del elefante" (intersección diagonal intermedia) está ocupado.
  - **Caballo (`Horse`)**: mueve 1 paso ortogonal seguido de 1 paso diagonal hacia afuera; queda bloqueado si la intersección ortogonal adyacente ("pata del caballo") está ocupada.
  - **Carro (`Chariot`)**: desplazamiento ortogonal libre como la torre.
  - **Cañón (`Cannon`)**: mueve sin captura igual que el Carro, pero para capturar debe saltar exactamente sobre una única pieza intermedia (*pantalla*).
  - **Soldado (`Soldier`)**: avanza 1 paso hacia adelante antes de cruzar el Río y adquiere además movimiento lateral tras cruzarlo.
- **Regla del General Volador (*Flying General*)**: está prohibido realizar cualquier jugada que deje a ambos Generales enfrentados en la misma columna sin ninguna pieza interpuesta.
- **Jaque Mate, Ahogado y Jaque Perpetuo**: en Xiangqi, dejar al rival sin movimientos legales (incluso sin estar en jaque) otorga la victoria al jugador que lo provoca; se penaliza la repetición perpetua de posición.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `MovePieceCommand` | Mueve una pieza desde la intersección `from` `[col, row]` hasta `to` `[col, row]`. | `{"command_type": "xiangqi_game::MovePieceCommand", "player": 1, "from": [1, 2], "to": [4, 2]}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria al adversario. | `{"command_type": "xiangqi_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `PieceMovedEvent` | `player: PlayerId`, `from: (usize, usize)`, `to: (usize, usize)`, `captured: Option<PieceKind>` | `{"event_type": "xiangqi_game::PieceMovedEvent", "player": 1, "from": [1, 2], "to": [4, 2], "captured": "Soldier"}` |
| `GameOverEvent` | `winner: Option<PlayerId>` | `{"event_type": "xiangqi_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_xiangqi_session(SessionId(1), seed, PlayerId(1), PlayerId(2))` coloca las 32 piezas en sus intersecciones reglamentarias.
2. **Apertura**: Rojo (`PlayerId(1)`) posiciona el Cañón central con `MovePieceCommand` de `[1, 2]` a `[4, 2]`.
3. **Captura con Pantalla**: Rojo utiliza una pieza intermedia como pantalla para capturar al Soldado central enemigo, emitiendo `PieceMovedEvent`.
4. **Fin**: Jaque mate o bloqueo total del General enemigo emite `GameOverEvent`.
