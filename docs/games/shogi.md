# Shogi (`shogi_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Tablero tradicional 9×9** con las 8 clases de piezas japonesas (`Pawn`, `Lance`, `Knight`, `Silver`, `Gold`, `Bishop`, `Rook`, `King`) y sus versiones promocionadas (`PromotedPawn` / Tokin, `PromotedLance`, `PromotedKnight`, `PromotedSilver`, `PromotedBishop` / Horse, `PromotedRook` / Dragon).
- **Reserva de piezas capturadas (*Komadai* / Drops)**: toda pieza capturada pasa sin promocionar a la mano del jugador captor y puede reingresarse en una casilla libre mediante `DropPieceCommand`.
- **Promoción opcional y obligatoria (Reglas FESA)**:
  - Promoción opcional al entrar, moverse o salir de las últimas 3 filas del campo enemigo (`promote: true`).
  - Promoción obligatoria automática cuando un Peón (`Pawn`), Lanza (`Lance`) o Caballo (`Knight`) alcanza una fila desde la cual no tendría movimientos legales futuros.
- **Restricciones reglamentarias de Drop**:
  - **Nifu (Dos Peones)**: prohibido reingresar un peón sin promocionar en una columna que ya contiene otro peón propio sin promocionar.
  - **Casilla sin salida**: prohibido reingresar Peón, Lanza o Caballo en las últimas filas donde no podrían volver a moverse.
  - **Uchifuzume (Mate por caída de peón)**: prohibido dar jaque mate inmediato mediante el reingreso (`DropPieceCommand`) de un peón.
- **Sennichite (Cuádruple repetición)**: si la misma posición completa (tablero, manos en reserva y turno) se repite 4 veces, la partida termina automáticamente.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `MovePieceCommand` | Mueve una pieza desde `from` `[col, row]` hasta `to` `[col, row]`, indicando si promociona (`promote`). | `{"command_type": "shogi_game::MovePieceCommand", "player": 1, "from": [6, 2], "to": [6, 3], "promote": false}` |
| `DropPieceCommand` | Reingresa una pieza de la reserva (*Komadai*) en la casilla vacía `to` `[col, row]`. | `{"command_type": "shogi_game::DropPieceCommand", "player": 1, "piece": "Pawn", "to": [4, 4]}` |
| `SetShogiRulesCommand` | Activa o desactiva la validación estricta de promoción obligatoria FESA. | `{"command_type": "shogi_game::SetShogiRulesCommand", "strict_fesa_promotion": true}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria al oponente. | `{"command_type": "shogi_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `PieceMovedEvent` | `player: PlayerId`, `from: (usize, usize)`, `to: (usize, usize)`, `promoted: bool`, `captured: Option<PieceKind>` | `{"event_type": "shogi_game::PieceMovedEvent", "player": 1, "from": [6, 2], "to": [6, 3], "promoted": false, "captured": null}` |
| `PieceDroppedEvent` | `player: PlayerId`, `piece: PieceKind`, `to: (usize, usize)` | `{"event_type": "shogi_game::PieceDroppedEvent", "player": 1, "piece": "Pawn", "to": [4, 4]}` |
| `GameOverEvent` | `winner: Option<PlayerId>` (`null` en empate por Sennichite) | `{"event_type": "shogi_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_shogi_session(SessionId(1), seed, PlayerId(1), PlayerId(2))` dispone las 40 piezas en el tablero 9×9.
2. **Avance y Captura**: Sente (`PlayerId(1)`) avanza piezas y captura un peón enemigo, que se incorpora a su `hands`.
3. **Reingreso (Drop)**: Sente ejecuta `DropPieceCommand` respetando las reglas de Nifu y Uchifuzume; se emite `PieceDroppedEvent`.
4. **Fin**: Jaque mate al Rey adversario o `ResignCommand` emite `GameOverEvent`.
