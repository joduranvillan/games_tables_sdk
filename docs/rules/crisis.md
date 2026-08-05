# Reglas de Crisis (`crisis_game`)

## Resumen de Reglas Implementadas
- **Tablero**: Circuito cerrado con casillas de Propiedades, Impuestos, Oportunidades y Crisis Financieras.
- **Mecánica Financiera**: Lanzamiento de dados, avance de casilla, cobro/pago de rentas, compra de empresas e impuestos de crisis.
- **Bancarrota**: Si el capital de un jugador se vuelve negativo tras cobro de impuestos/rentas, cae en bancarrota.

## Simplificaciones respecto al Juego Estándar
- Tablero reducido de circuito directo sin subastas complejas.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `RollAndMoveCommand` | Tira dados y avanza la casilla correspondiente. |
| Command | `BuyCompanyCommand` | Compra la propiedad/compañía en la casilla actual. |
| Event | `PlayerMovedEvent` | Notifica el desplazamiento del jugador en el tablero. |
| Event | `RentPaidEvent` | Notifica el pago de renta a otro jugador. |
| Event | `TaxPaidEvent` | Notifica el pago de impuestos. |
| Event | `CompanyPurchasedEvent` | Notifica la adquisición de una propiedad. |
| Event | `CrisisOccurredEvent` | Notifica un evento macroeconómico de crisis. |
| Event | `GameOverEvent` | Notifica el fin por bancarrota o victoria financiera. |
