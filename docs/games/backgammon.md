# Backgammon (`backgammon_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero de 24 puntos/triángulos.
- Tirada de 2 dados, movimiento de fichas y captura a la Barra.
- Proceso de desocupación (Bear-off) cuando todas las fichas están en el cuadrante de casa.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `RollDiceCommand` | Lanza los dados al inicio del turno | `{"type": "RollDiceCommand", "player": 1}` |
| `MoveCheckerCommand` | Mueve una ficha según el valor del dado | `{"type": "MoveCheckerCommand", "player": 1, "from_point": 24, "die_value": 3}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `DiceRolledEvent` | `player`, `dice` |
| `CheckerMovedEvent` | `player`, `from`, `to`, `hit_bar` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Sin Dado de Doblamiento (Doubling Cube).

## 5. Ejemplo de Partida Mínima
1. **Inicio**: 15 fichas distribuidas en el tablero.
2. **Movimiento 1**: Jugador 1 lanza dados (saca 3 y 5).
3. **Movimiento 2**: Jugador 1 mueve ficha de punto 24 a 21 y de 13 a 8.
4. **Movimiento 3**: Jugador 2 golpea ficha expuesta enviándola a la barra.
5. **Fin**: Retiro de las 15 fichas (bear-off) concluye con `GameOverEvent`.
