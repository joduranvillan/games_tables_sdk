# Ajedrez (`chess_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Tablero estándar 8×8** (`row: 0..7`, `col: 0..7`) con las 6 piezas clásicas (`Pawn`, `Knight`, `Bishop`, `Rook`, `Queen`, `King`).
- **Movimientos especiales completos**:
  - **Enroque corto (O-O) y largo (O-O-O)**: verifica que ni el Rey ni la Torre involucrada se hayan movido, que las casillas intermedias estén vacías y que el Rey no esté en jaque ni atraviese casillas atacadas.
  - **Captura al paso (*En Passant*)**: disponible inmediatamente en el turno posterior al avance doble de un peón rival.
  - **Subpromoción configurable**: el comando `MovePieceCommand` acepta `promote_to` (`Queen`, `Rook`, `Bishop`, `Knight`); por defecto promueve a `Queen`.
- **Detección de fin de partida y tablas**:
  - Jaque mate (`winner: Some(PlayerId)`).
  - Ahogado (*Stalemate*), regla de los **50 movimientos** (`halfmove_clock >= 100`), **triple repetición** de posición (`position_history`) e **insuficiencia de material** (K vs K, K+B vs K, K+N vs K) que emiten `GameOverEvent { winner: None }`.
  - Oferta y aceptación de tablas (`OfferDrawCommand`, `AcceptDrawCommand`) y rendición (`ResignCommand`).
- **Notación FEN**: exportación e importación completa mediante `to_fen()` y `from_fen()`.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `MovePieceCommand` | Mueve una pieza desde `from` hasta `to`, con promoción opcional `promote_to` (`"Queen"`, `"Rook"`, `"Bishop"`, `"Knight"` o `null`). | `{"command_type": "chess_game::MovePieceCommand", "player": 1, "from": {"row": 1, "col": 4}, "to": {"row": 3, "col": 4}, "promote_to": null}` |
| `OfferDrawCommand` | Propone tablas al adversario durante el turno propio. | `{"command_type": "chess_game::OfferDrawCommand", "player": 1}` |
| `AcceptDrawCommand` | Acepta una oferta de tablas pendiente del oponente y finaliza la partida en empate. | `{"command_type": "chess_game::AcceptDrawCommand", "player": 2}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria al oponente. | `{"command_type": "chess_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `PieceMovedEvent` | `player: PlayerId`, `from: Position`, `to: Position`, `captured: Option<PieceKind>`, `promoted: bool`, `opponent_in_check: bool`, `castled: bool`, `promoted_to: Option<PieceKind>` | `{"event_type": "chess_game::PieceMovedEvent", "player": 1, "from": {"row": 6, "col": 4}, "to": {"row": 7, "col": 4}, "captured": null, "promoted": true, "opponent_in_check": true, "castled": false, "promoted_to": "Knight"}` |
| `GameOverEvent` | `winner: Option<PlayerId>` (`null` indica tablas) | `{"event_type": "chess_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_chess_session(SessionId(1), seed, PlayerId(1), PlayerId(2))` inicializa el tablero con Blancas (`PlayerId(1)`) en las filas `0..1` y Negras (`PlayerId(2)`) en las filas `6..7`.
2. **Apertura**: Blancas envían `MovePieceCommand` de `(1, 4)` a `(3, 4)` (e2-e4); se emite `PieceMovedEvent`.
3. **Desarrollo y Enroque**: Tras despejar f1 y g1, Blancas mueven el Rey de `(0, 4)` a `(0, 6)`, emitiendo `PieceMovedEvent` con `"castled": true`.
4. **Cierre**: Jaque mate, tablas acordadas (`OfferDrawCommand` + `AcceptDrawCommand`) o rendición (`ResignCommand`) emiten `GameOverEvent`.
