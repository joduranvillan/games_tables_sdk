# Damas Chinas (`chinese_checkers_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero oficial en forma de estrella de 6 puntas con **121 casillas** en coordenadas axiales hexagonales `(q, r)` (`BOARD_RADIUS = 4` + 6 puntas de 10 casillas).
- Soporte configurable para **2, 3, 4 o 6 jugadores** con asignación simétrica de puntas de salida y puntas objetivo opuestas.
- Movimiento de 1 paso a casilla adyacente vacía o **saltos múltiples encadenados (`path`)** sobre fichas propias o rivales (sin capturarlas).
- Detección automática de victoria cuando el jugador ocupa las 10 casillas de su triángulo objetivo opuesto.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `MovePegCommand` | Mueve una canica un paso adyacente o mediante una cadena de saltos | `{"type": "MovePegCommand", "player": 1, "from": {"q": -5, "r": 1}, "to": {"q": -3, "r": 1}, "path": [{"q": -3, "r": 1}]}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `PegMovedEvent` | `player`, `from`, `to`, `was_jump` |
| `GameOverEvent` | `winner` |

## 4. Reglas Adicionales en `PROMPTS13.md`
- Regla oficial de **Anti-Bloqueo en punta de meta (Home-Camp Spoiling Rule)**: victoria si las 10 casillas destino están ocupadas y al menos una ficha es del jugador propietario de esa meta.
- Registro de `ChineseCheckersLegalMoveGenerator` en `RuleEngine` y `ResignCommand`.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: Estrella de 121 casillas inicializada con 10 canicas por jugador en puntas opuestas.
2. **Movimiento 1**: Jugador 1 avanza una canica desde `(-5, 1)` a `(-4, 1)`.
3. **Movimiento 2**: Jugador 2 avanza una canica desde `(5, -1)` a `(4, -1)`.
4. **Movimiento 3**: Jugador 1 realiza un salto encadenado sobre dos canicas intermedias especificando `path`.
5. **Fin**: Al completar las 10 casillas del triángulo opuesto se emite `GameOverEvent`.
