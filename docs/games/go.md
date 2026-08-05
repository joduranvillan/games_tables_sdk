# Go (`go_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero de Go (9x9 o 19x19).
- Colocación de piedras en intersecciones y cálculo automático de libertades.
- Captura de grupos sin libertades y opción de Pase (`PassCommand`).

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `PlaceStoneCommand` | Coloca una piedra en las coordenadas indicadas | `{"type": "PlaceStoneCommand", "player": 1, "x": 2, "y": 3}` |
| `PassCommand` | Pasa el turno actual | `{"type": "PassCommand", "player": 1}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `StonePlacedEvent` | `player`, `x`, `y`, `captured_count` |
| `PassEvent` | `player` |
| `GameOverEvent` | `winner`, `score_player1`, `score_player2` |

## 4. Simplificaciones Respecto al Juego Real
- Regla de Ko en desarrollo (sin detección de repetición infinita compleja).
- Handicap asignable al inicio de la sesión.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: Tablero 9x9 vacío.
2. **Movimiento 1**: Jugador 1 coloca piedra negra en (2,2).
3. **Movimiento 2**: Jugador 2 coloca piedra blanca en (2,3).
4. **Movimiento 3**: Jugador 1 encierra la piedra blanca y la captura.
5. **Fin**: Ambos jugadores ejecutan `PassCommand` consecutivamente y se determina el ganador.
