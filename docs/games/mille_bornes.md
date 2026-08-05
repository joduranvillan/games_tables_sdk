# Mille Bornes (`mille_bornes_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Carrera de distancia con objetivo de completar millas.
- Cartas de velocidad/distancia, peligros (Pinchazo, Límite de velocidad, Sin gasolina) y remedios (Rueda de repuesto, Fin de límite, Gasolina).

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `PlayCardCommand` | Juega una carta de la mano | `{"type": "PlayCardCommand", "player": 1, "card_index": 0, "target_player": 2}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `CardPlayedEvent` | `player`, `card`, `target` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Meta de distancia ajustada a 200 millas para sesiones cortas.
- Sin coup fourré ni cartas de seguridad avanzadas.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: 6 cartas en mano por jugador.
2. **Movimiento 1**: Jugador 1 juega carta "Siga" (Luz Verde).
3. **Movimiento 2**: Jugador 1 juega carta de 50 millas.
4. **Movimiento 3**: Jugador 2 aplica tarjeta "Pinchazo" al Jugador 1.
5. **Fin**: Alcanzar las 200 millas emite `GameOverEvent`.
