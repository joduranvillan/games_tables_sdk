# Reglas de Monopoly (`monopoly_game`)

## Resumen de Reglas Implementadas
- **Tablero**: Circuito de 16 casillas con propiedades, ferrocarriles, servicios públicos, cárcel y salida.
- **Tirada y Movimiento**: Lanzamiento de dados y avance. Si cae en casilla no comprada, suspende el avance de turno permitiendo la compra o inicio de subasta.
- **Rentas y Cárcel**: Cobro de rentas por caída en propiedad ajena, multa para salir de cárcel o tiro de dobles.
- **Subastas y Bancarrota**: Mecánica de pujas para propiedades declinadas; eliminación por saldo negativo.

## Simplificaciones respecto al Juego Estándar
- Tablero de 16 casillas (en lugar de 40).
- Sin casas ni hoteles.
- Sin tarjetas de Suerte o Caja de Comunidad.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `RollAndMoveCommand` | Tira dados y avanza la ficha. |
| Command | `BuyPropertyCommand` | Compra la propiedad donde está detenido. |
| Command | `AuctionBidCommand` | Realiza una puja durante una subasta. |
| Command | `PayJailFeeCommand` | Paga la fianza para salir de la cárcel. |
| Event | `PlayerMovedEvent` | Notifica el desplazamiento del jugador. |
| Event | `PropertyPurchasedEvent` | Notifica la compra de propiedad. |
| Event | `RentPaidEvent` | Notifica el pago de alquiler. |
| Event | `AuctionStartedEvent` | Notifica el inicio de subasta. |
| Event | `AuctionWonEvent` | Notifica el ganador de la subasta. |
| Event | `BankruptcyEvent` | Notifica la bancarrota de un jugador. |
| Event | `GameOverEvent` | Notifica el fin de la partida por único sobreviviente. |
