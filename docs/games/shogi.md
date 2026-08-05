# Shogi (`shogi_game`) — Documentación del Juego

## 1. Resumen de Reglas Implementadas
- Tablero 9x9 con piezas tradicionales japonesas.
- Reingreso de piezas capturadas (Drops) a mano del jugador.
- Zona de promoción en las últimas 3 filas.

## 2. Tabla de Comandos
| Comando | Descripción | Ejemplo JSON |
|---|---|---|
| `MovePieceCommand` | Mueve una pieza en el tablero | `{"type": "MovePieceCommand", "player": 1, "from": {"x": 6, "y": 2}, "to": {"x": 6, "y": 3}, "promote": false}` |
| `DropPieceCommand` | Reingresa una pieza capturada | `{"type": "DropPieceCommand", "player": 1, "piece_type": "Pawn", "to": {"x": 4, "y": 4}}` |

## 3. Tabla de Eventos
| Evento | Campos |
|---|---|
| `PieceMovedEvent` | `player`, `from`, `to`, `promoted`, `captured` |
| `PieceDroppedEvent` | `player`, `piece_type`, `to` |
| `GameOverEvent` | `winner` |

## 4. Simplificaciones Respecto al Juego Real
- Pendiente reglas de Nifu (dos peones sin promover en la misma columna) y Uchifuzume (mate por reingreso de peón).

## 5. Ejemplo de Partida Mínima
1. **Inicio**: Tablero Shogi 9x9 con 20 piezas por jugador.
2. **Movimiento 1**: Sente mueve Peón a 7f.
3. **Movimiento 2**: Gote responde moviendo Peón a 3d.
4. **Movimiento 3**: Sente captura pieza y la suma a sus reservas.
5. **Fin**: Captura o jaque mate al Rey emite `GameOverEvent`.
