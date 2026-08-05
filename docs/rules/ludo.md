# Reglas de Ludo (`ludo_game`)

## Resumen de Reglas Implementadas
- **Jugadores**: 2 a 4 jugadores con 4 fichas cada uno.
- **Salida**: Se requiere sacar un 6 en el dado para ingresar una ficha al circuito.
- **Desplazamiento**: Recorrido de casillas compartidas, casillas seguras de salida, y tramo final de meta.
- **Captura**: Caer en una casilla ocupada por ficha enemiga no protegida la devuelve a la base inicial.
- **Paso Automático**: Notificación cuando el tiro de dado no permite realizar ninguna jugada legal.

## Simplificaciones respecto al Juego Estándar
- Circuito de 24 casillas comunes (en lugar de 52).
- Sacar un 6 no otorga tiro adicional de dados.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `RollDiceCommand` | Lanza el dado. |
| Command | `MoveTokenCommand` | Mueve una ficha según el valor obtenido. |
| Event | `DiceRolledEvent` | Notifica el resultado del tiro de dado. |
| Event | `TokenMovedEvent` | Notifica el movimiento o captura de una ficha. |
| Event | `NoValidMovesEvent` | Notifica que no hay movimientos posibles con el dado. |
| Event | `GameOverEvent` | Notifica que un jugador introdujo sus 4 fichas a la meta. |
