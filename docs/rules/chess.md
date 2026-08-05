# Reglas de Ajedrez (`chess_game`)

## Resumen de Reglas Implementadas
- **Tablero**: Grilla estándar de 8x8 con setup inicial de 16 piezas por jugador.
- **Movimiento de Piezas**: Movimientos legales completos para Peón, Torre, Caballo, Alfil, Dama y Rey.
- **Enroque**: Enroque corto (`O-O`) y largo (`O-O-O`) validando casillas amenazadas y estado de movimiento de Torre/Rey.
- **Captura al Paso**: Implementada para peones que avanzan dos casillas en el turno inmediatamente posterior.
- **Simulación de Jaque/Jaque Mate**: Detección rigurosa de jaque simulando la jugada en una copia del tablero; detección de jaque mate y ahogado enumerando movimientos legales.
- **Tablas**: Por acuerdo entre jugadores (oferta/aceptación) o por regla de 50 movimientos / repetición triple.

## Simplificaciones respecto al Juego Estándar
- La coronación de peón es siempre a Dama por defecto en el comando actual.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `MovePieceCommand` | Solicita mover una pieza desde `from` hasta `to`. |
| Command | `OfferDrawCommand` | Ofrece tablas al oponente. |
| Command | `AcceptDrawCommand` | Acepta la oferta de tablas activa. |
| Event | `PieceMovedEvent` | Notifica un movimiento, captura, enroque o coronación. |
| Event | `GameOverEvent` | Notifica el fin del juego (jaque mate, ahogado, tablas). |
