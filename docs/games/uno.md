# Uno (`uno_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Cartas numéricas (0-9) en 4 colores (Rojo, Azul, Verde, Amarillo) y cartas especiales (+2, Reversa, Salto, Comodín, Comodín +4).
- Validación de coincidencia por color o número y acumulación de efectos.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `PlayCardCommand` | Juega una carta de la mano | `{"type": "PlayCardCommand", "player": 1, "card_index": 0, "chosen_color": "Red"}` |
| `DrawCardCommand` | Roba una carta del mazo | `{"type": "DrawCardCommand", "player": 1}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `CardPlayedEvent` | `player`, `card` |
| `CardDrawnEvent` | `player` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Sin grito de "UNO" manual (penalización simplificada).

## 5. Ejemplo de Partida Mínima
1. **Inicio**: 7 cartas repartidas por jugador.
2. **Movimiento 1**: Jugador 1 juega un 5 Rojo sobre un 3 Rojo.
3. **Movimiento 2**: Jugador 2 juega una carta especial Reversa.
4. **Movimiento 3**: Jugador 1 juega Comodín +4 cambiando el color a Azul.
5. **Fin**: Jugador que se queda sin cartas en mano activa `GameOverEvent`.
