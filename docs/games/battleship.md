# Batalla Naval (`battleship_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero privado de 8x8 con colocación de barcos durante la fase de Setup.
- Información oculta estricta: los barcos enemigos son invisibles hasta recibir disparos.
- Registro de disparos, impactos y hundimientos.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `PlaceShipCommand` | Coloca un barco en la grilla | `{"type": "PlaceShipCommand", "player": 1, "ship_type": "Destroyer", "x": 0, "y": 0, "horizontal": true}` |
| `FireShotCommand` | Efectúa un disparo al tablero rival | `{"type": "FireShotCommand", "player": 1, "target": {"x": 3, "y": 4}}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `ShotFiredEvent` | `attacker`, `target`, `hit`, `sunk_ship` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Grilla de 8x8 (en lugar de 10x10).
- 3 barcos por jugador.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: Ambos jugadores ubican sus 3 barcos en secreto.
2. **Movimiento 1**: Jugador 1 dispara a (3,4) y registra impacto.
3. **Movimiento 2**: Jugador 2 dispara a (0,0) y se registra agua.
4. **Movimiento 3**: Jugador 1 dispara al último segmento restante del último barco rival y lo hunde.
5. **Fin**: Hundimiento de la flota completa emite `GameOverEvent`.
