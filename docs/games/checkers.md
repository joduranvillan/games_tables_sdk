# Damas (`checkers_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero 8x8 con 12 fichas por jugador.
- Movimiento diagonal simple y captura por salto sobre ficha rival.
- Coronación a Dama al alcanzar el extremo opuesto del tablero.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `MovePieceCommand` | Mueve una ficha a la casilla destino | `{"type": "MovePieceCommand", "player": 1, "from": {"x": 0, "y": 2}, "to": {"x": 1, "y": 3}}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `PieceMovedEvent` | `player`, `from`, `to`, `captured` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Captura opcional (no se fuerza captura si existen otras jugadas).
- Saltos múltiples encadenados simplificados en única resolución por turno.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: Tablero con 12 fichas negras y 12 fichas rojas.
2. **Movimiento 1**: Jugador 1 avanza de (0,2) a (1,3).
3. **Movimiento 2**: Jugador 2 responde de (1,5) a (0,4).
4. **Movimiento 3**: Jugador 1 realiza salto de captura sobre (0,4) aterizando en (0,5).
5. **Fin**: Eliminación de todas las fichas rivales concluye con `GameOverEvent`.
