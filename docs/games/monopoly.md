# Monopoly (`monopoly_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero simplificado de 16 casillas con propiedades, servicios y cobro de alquileres.
- Gestión de efectivo, compra de propiedades no poseídas y quiebra de jugadores.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `RollDiceCommand` | Lanza los dados y avanza el token | `{"type": "RollDiceCommand", "player": 1}` |
| `BuyPropertyCommand` | Compra la propiedad en la casilla actual | `{"type": "BuyPropertyCommand", "player": 1}` |
| `EndTurnCommand` | Finaliza el turno actual | `{"type": "EndTurnCommand", "player": 1}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `DiceRolledEvent` | `player`, `dice`, `new_position` |
| `PropertyBoughtEvent` | `player`, `property_id`, `price` |
| `RentPaidEvent` | `payer`, `owner`, `amount` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Tablero de 16 casillas (en lugar de 40).
- Sin casas ni hoteles.
- Sin tarjetas de Suerte / Caja de Comunidad.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: Jugadores con $1500 de capital inicial.
2. **Movimiento 1**: Jugador 1 avanza a la casilla 3 y compra la propiedad.
3. **Movimiento 2**: Jugador 2 aterriza en la propiedad de Jugador 1 y paga alquiler.
4. **Movimiento 3**: Jugador 2 queda sin saldo tras compras y se declara en bancarrota.
5. **Fin**: Único jugador en pie activa `GameOverEvent`.
