# Ajedrez (`chess_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero estándar 8x8 con piezas tradicionales (Peón, Torre, Caballo, Alfil, Dama, Rey).
- Movimientos legales completos para cada tipo de pieza, detección de jaque y jaque mate.
- Promoción automática a Dama al llegar a la última fila.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `MovePieceCommand` | Mueve una pieza de una casilla origen a destino | `{"type": "MovePieceCommand", "player": 1, "from": {"x": 4, "y": 1}, "to": {"x": 4, "y": 3}}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `PieceMovedEvent` | `player`, `from`, `to`, `captured_piece` |
| `GameOverEvent` | `winner`, `reason` |

## 4. Simplificaciones Respecto al Juego Real
- Sin enroque corto/largo.
- Sin captura al paso (en passant).
- Promoción automática a Dama (no se da a elegir otra pieza).
- Sin tabla de tablas por triple repetición o 50 movimientos.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: Tablero estándar 8x8 inicializado. Turno de Blancas (Jugador 1).
2. **Movimiento 1**: Blancas mueven Peón de e2 a e4 (`MovePieceCommand`).
3. **Movimiento 2**: Negras mueven Peón de e7 a e5 (`MovePieceCommand`).
4. **Movimiento 3**: Blancas mueven Caballo de g1 a f3 (`MovePieceCommand`).
5. **Fin**: Jaque mate ejecutado tras secuencia y se emite `GameOverEvent`.
