# Damas (`checkers_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Tablero estándar 8×8** (`row: 0..7`, `col: 0..7`) con 12 fichas iniciales por jugador colocadas sobre las casillas oscuras de las tres primeras filas de cada bando.
- **Captura obligatoria**: si al inicio del turno existen capturas disponibles para cualquier ficha propia, los movimientos simples sin captura quedan prohibidos.
- **Saltos múltiples encadenados (`PendingJumpResource`)**: si tras ejecutar un salto de captura la misma pieza puede continuar capturando desde su nueva casilla, el turno permanece en el mismo jugador y `PendingJumpResource` exige completar la cadena con esa pieza.
- **Coronación a Dama (`King`)**: al alcanzar la última fila del extremo opuesto, la ficha se corona como Dama y habilita desplazamientos y capturas en las 4 diagonales.
- **Regla de tablas por 40 medios turnos (`NoProgressResource`)**: si transcurren 40 medios turnos consecutivos sin capturas ni avances de peón, la partida concluye automáticamente en empate (`is_draw: true`).

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `MovePieceCommand` | Desplaza una ficha diagonalmente (distancia 1 para paso simple o distancia 2 para salto de captura). | `{"command_type": "checkers_game::MovePieceCommand", "player": 1, "from": {"row": 2, "col": 1}, "to": {"row": 3, "col": 0}}` |
| `ResignCommand` | Se rinde inmediatamente y otorga la victoria al adversario. | `{"command_type": "checkers_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `PieceMovedEvent` | `player: PlayerId`, `from: Position`, `to: Position`, `captured: Option<Position>`, `promoted: bool` | `{"event_type": "checkers_game::PieceMovedEvent", "player": 1, "from": {"row": 2, "col": 1}, "to": {"row": 4, "col": 3}, "captured": {"row": 3, "col": 2}, "promoted": false}` |
| `GameOverEvent` | `winner: PlayerId`, `is_draw: bool` | `{"event_type": "checkers_game::GameOverEvent", "winner": 1, "is_draw": false}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_checkers_session(SessionId(1), seed, PlayerId(1), PlayerId(2))` coloca 12 fichas para cada jugador.
2. **Avance**: Jugador 1 ejecuta `MovePieceCommand` desde `{"row": 2, "col": 1}` hacia `{"row": 3, "col": 0}`.
3. **Cadena de Capturas**: Cuando una ficha salta sobre un rival y cae en una casilla con otra captura disponible, el motor mantiene el turno activo hasta completar la secuencia de saltos.
4. **Fin**: Al dejar al oponente sin piezas o sin jugadas legales (o al cumplirse 40 medios turnos sin progreso), se emite `GameOverEvent`.
