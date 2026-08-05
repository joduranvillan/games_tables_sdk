# Xiangqi (`xiangqi_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero 9x10 cortado por el Río y Palacios en ambos extremos.
- Piezas especiales: General, Guardias, Elefantes, Caballos, Cañones, Carros y Soldados.
- Regla del Cañón (requiere una pieza pantalla para capturar).

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `MovePieceCommand` | Mueve una pieza en el tablero | `{"type": "MovePieceCommand", "player": 1, "from": {"x": 1, "y": 2}, "to": {"x": 4, "y": 2}}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `PieceMovedEvent` | `player`, `from`, `to`, `captured` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Pendiente verificación estricta del "General Volador" en tiempo real.

## 5. Ejemplo de Partida Mínima
1. **Inicio**: Tablero con piezas rojas y negras en sus posiciones iniciales.
2. **Movimiento 1**: Rojo mueve Cañón al centro.
3. **Movimiento 2**: Negro avanza Caballo para defender.
4. **Movimiento 3**: Rojo dispara con Cañón usando pantalla.
5. **Fin**: Captura del General rival resulta en `GameOverEvent`.
