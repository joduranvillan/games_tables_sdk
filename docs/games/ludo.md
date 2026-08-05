# Ludo (`ludo_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Carrera de fichas de 2 a 4 jugadores con salida con 6 en el dado.
- Recorrido de casillas con casillas seguras y captura de fichas enemigas.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `RollDiceCommand` | Lanza el dado de 6 caras | `{"type": "RollDiceCommand", "player": 1}` |
| `MoveTokenCommand` | Mueve una ficha activa | `{"type": "MoveTokenCommand", "player": 1, "token_index": 0}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `DiceRolledEvent` | `player`, `value` |
| `TokenMovedEvent` | `player`, `token_index`, `new_position`, `captured_token` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Pista compartida reducida a 24 casillas.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: 4 fichas en casa por jugador.
2. **Movimiento 1**: Jugador 1 saca un 6 y despliega su primera ficha a la pista.
3. **Movimiento 2**: Jugador 1 saca un 4 y avanza 4 casillas.
4. **Movimiento 3**: Jugador 2 aterriza en la misma casilla y envía la ficha de Jugador 1 a la casa.
5. **Fin**: Ingreso de las 4 fichas a la meta otorga la victoria y emite `GameOverEvent`.
