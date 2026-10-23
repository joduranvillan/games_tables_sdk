# Monopoly (`monopoly_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Tablero oficial completo de 40 casillas (`BOARD_SIZE = 40`)** con los 8 grupos de color, 4 Estaciones de Ferrocarril (`Railroad`), 2 Compañías de Servicios Públicos (`Utility`), Impuestos (`Income Tax`, `Luxury Tax`), Salida (`GO` +$200), Cárcel (`Jail`) y `Go To Jail`.
- **Mazos de Suerte (`Chance`, 10 cartas) y Arca Comunal (`Community Chest`, 10 cartas)**:
  - Incluye avances a casillas específicas, cobros, pagos y la carta retenible **Salir de la Cárcel Gratis (`GetOutOfJailFree`)**, utilizable mediante `UseJailCardCommand`.
- **Regla de Dobles y Cárcel**:
  - Sacar dobles en los dados otorga turno extra, pero obtener **3 dobles consecutivos** envía inmediatamente al jugador a la Cárcel (`JailedEvent`).
  - Desde la Cárcel se puede salir sacando dobles, pagando la fianza de `$50` (`PayJailFeeCommand`) o usando una carta `GetOutOfJailFree` (`UseJailCardCommand`).
- **Compra, Subastas (`AuctionBidCommand`) y Alquileres Escalados**:
  - Al caer en una propiedad libre, el jugador puede comprarla (`BuyPropertyCommand { buy: true }`) o rechazarla (`buy: false`) iniciando una subasta entre los jugadores.
  - Poseer todo un grupo de color duplica el alquiler base de los solares sin edificar.
- **Construcción Uniforme de Casas y Hoteles (`BuildHouseCommand`, `SellHouseCommand`)**:
  - Con monopolio completo y sin propiedades hipotecadas en el grupo, se pueden construir hasta 4 casas y 1 hotel (`level = 5`) respetando la regla de construcción y venta uniforme (diferencia máxima de 1 nivel entre solares del mismo color).
- **Hipotecas (`MortgagePropertyCommand`, `UnmortgagePropertyCommand`)**:
  - Hipotecar una propiedad sin edificios entrega el 50% de su valor de compra y suspende el cobro de alquiler; levantar la hipoteca cuesta el valor hipotecario más un **10% de interés** (60% del precio original).
- **Intercambios Comerciales (`ProposeTradeCommand`, `AcceptTradeCommand`, `RejectTradeCommand`)**:
  - Permite proponer intercambios de propiedades sin edificar y dinero en efectivo entre jugadores.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `RollAndMoveCommand` | Lanza los 2 dados, desplaza el peón y ejecuta las reglas de la casilla destino. | `{"command_type": "monopoly_game::RollAndMoveCommand", "player": 1}` |
| `BuyPropertyCommand` | Compra (`buy: true`) o declina hacia subasta (`buy: false`) la propiedad donde cayó el jugador. | `{"command_type": "monopoly_game::BuyPropertyCommand", "player": 1, "buy": true}` |
| `AuctionBidCommand` | Realiza una puja por `amount` durante una subasta activa (`0` para retirarse). | `{"command_type": "monopoly_game::AuctionBidCommand", "player": 2, "amount": 120}` |
| `PayJailFeeCommand` | Paga la fianza de `$50` para salir de la Cárcel. | `{"command_type": "monopoly_game::PayJailFeeCommand", "player": 1}` |
| `UseJailCardCommand` | Utiliza una carta retenida de "Salir de la Cárcel Gratis". | `{"command_type": "monopoly_game::UseJailCardCommand", "player": 1}` |
| `BuildHouseCommand` | Construye una casa o hotel (nivel `1..5`) en el solar `space` de un monopolio propio. | `{"command_type": "monopoly_game::BuildHouseCommand", "player": 1, "space": 1}` |
| `SellHouseCommand` | Vende una casa o hotel del solar `space` recibiendo el 50% de su costo de construcción. | `{"command_type": "monopoly_game::SellHouseCommand", "player": 1, "space": 1}` |
| `MortgagePropertyCommand` | Hipoteca la propiedad `space` recibiendo el 50% de su precio de lista. | `{"command_type": "monopoly_game::MortgagePropertyCommand", "player": 1, "space": 6}` |
| `UnmortgagePropertyCommand` | Levanta la hipoteca de `space` abonando el valor hipotecado más 10% de interés. | `{"command_type": "monopoly_game::UnmortgagePropertyCommand", "player": 1, "space": 6}` |
| `ProposeTradeCommand` | Propone un intercambio comercial de propiedades y efectivo al jugador `target`. | `{"command_type": "monopoly_game::ProposeTradeCommand", "player": 1, "target": 2, "offered_spaces": [1], "requested_spaces": [3], "offered_cash": 100, "requested_cash": 0}` |
| `AcceptTradeCommand` | Acepta la oferta de intercambio comercial pendiente. | `{"command_type": "monopoly_game::AcceptTradeCommand", "player": 2}` |
| `RejectTradeCommand` | Rechaza la oferta de intercambio comercial pendiente. | `{"command_type": "monopoly_game::RejectTradeCommand", "player": 2}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `PlayerMovedEvent` | `player: PlayerId`, `roll: u32`, `d1: u32`, `d2: u32`, `is_doubles: bool`, `new_position: usize`, `passed_go: bool` | `{"event_type": "monopoly_game::PlayerMovedEvent", "player": 1, "roll": 7, "d1": 3, "d2": 4, "is_doubles": false, "new_position": 7, "passed_go": false}` |
| `PropertyPurchasedEvent` | `player: PlayerId`, `space: usize`, `price: u32` | `{"event_type": "monopoly_game::PropertyPurchasedEvent", "player": 1, "space": 1, "price": 60}` |
| `RentPaidEvent` | `payer: PlayerId`, `owner: PlayerId`, `space: usize`, `amount: u32` | `{"event_type": "monopoly_game::RentPaidEvent", "payer": 2, "owner": 1, "space": 1, "amount": 10}` |
| `UtilityRentPaidEvent` | `player: PlayerId`, `owner: PlayerId`, `multiplier: u32`, `dice_total: u32`, `amount: u32` | `{"event_type": "monopoly_game::UtilityRentPaidEvent", "player": 2, "owner": 1, "multiplier": 4, "dice_total": 7, "amount": 28}` |
| `RailroadRentPaidEvent` | `player: PlayerId`, `owner: PlayerId`, `railroads_owned: u32`, `amount: u32` | `{"event_type": "monopoly_game::RailroadRentPaidEvent", "player": 2, "owner": 1, "railroads_owned": 2, "amount": 50}` |
| `TaxPaidEvent` | `player: PlayerId`, `space: usize`, `name: String`, `amount: u32` | `{"event_type": "monopoly_game::TaxPaidEvent", "player": 1, "space": 4, "name": "Income Tax", "amount": 200}` |
| `ChanceCardDrawnEvent` | `player: PlayerId`, `card: ChanceCard`, `description: String` | `{"event_type": "monopoly_game::ChanceCardDrawnEvent", "player": 1, "card": "AdvanceToGo", "description": "Advance to Go (Collect $200)"}` |
| `CommunityChestCardDrawnEvent` | `player: PlayerId`, `card: CommunityChestCard`, `description: String` | `{"event_type": "monopoly_game::CommunityChestCardDrawnEvent", "player": 1, "card": "BankErrorInYourFavor", "description": "Bank error in your favor. Collect $200"}` |
| `JailedEvent` | `player: PlayerId` | `{"event_type": "monopoly_game::JailedEvent", "player": 1}` |
| `JailCardUsedEvent` | `player: PlayerId` | `{"event_type": "monopoly_game::JailCardUsedEvent", "player": 1}` |
| `AuctionStartedEvent` | `space: usize` | `{"event_type": "monopoly_game::AuctionStartedEvent", "space": 3}` |
| `AuctionWonEvent` | `player: PlayerId`, `space: usize`, `price: u32` | `{"event_type": "monopoly_game::AuctionWonEvent", "player": 2, "space": 3, "price": 50}` |
| `HouseBuiltEvent` | `player: PlayerId`, `space: usize`, `level: u8`, `cost: u32` | `{"event_type": "monopoly_game::HouseBuiltEvent", "player": 1, "space": 1, "level": 1, "cost": 50}` |
| `HouseSoldEvent` | `player: PlayerId`, `space: usize`, `level: u8`, `refund: u32` | `{"event_type": "monopoly_game::HouseSoldEvent", "player": 1, "space": 1, "level": 0, "refund": 25}` |
| `PropertyMortgagedEvent` | `player: PlayerId`, `space: usize`, `amount: u32` | `{"event_type": "monopoly_game::PropertyMortgagedEvent", "player": 1, "space": 6, "amount": 50}` |
| `PropertyUnmortgagedEvent` | `player: PlayerId`, `space: usize`, `cost: u32` | `{"event_type": "monopoly_game::PropertyUnmortgagedEvent", "player": 1, "space": 6, "cost": 55}` |
| `TradeProposedEvent` | `player: PlayerId`, `target: PlayerId`, `offered_spaces: Vec<usize>`, `requested_spaces: Vec<usize>`, `offered_cash: u32`, `requested_cash: u32` | `{"event_type": "monopoly_game::TradeProposedEvent", "player": 1, "target": 2, "offered_spaces": [1], "requested_spaces": [3], "offered_cash": 100, "requested_cash": 0}` |
| `TradeAcceptedEvent` | `player: PlayerId`, `target: PlayerId`, `offered_spaces: Vec<usize>`, `requested_spaces: Vec<usize>`, `offered_cash: u32`, `requested_cash: u32` | `{"event_type": "monopoly_game::TradeAcceptedEvent", "player": 2, "target": 1, "offered_spaces": [1], "requested_spaces": [3], "offered_cash": 100, "requested_cash": 0}` |
| `TradeRejectedEvent` | `player: PlayerId` | `{"event_type": "monopoly_game::TradeRejectedEvent", "player": 2}` |
| `BankruptcyEvent` | `player: PlayerId` | `{"event_type": "monopoly_game::BankruptcyEvent", "player": 2}` |
| `GameOverEvent` | `winner: PlayerId` | `{"event_type": "monopoly_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_monopoly_session(SessionId(1), seed, PlayerId(1), PlayerId(2))` asigna `$1500` y posición `0` (`GO`) a cada jugador en el circuito de 40 casillas.
2. **Adquisición y Comercio**: Los jugadores avanzan con `RollAndMoveCommand`, compran solares (`BuyPropertyCommand`) o negocian grupos de color (`ProposeTradeCommand` + `AcceptTradeCommand`).
3. **Edificación**: Una vez completado un grupo de color, el propietario construye casas uniformemente mediante `BuildHouseCommand`.
4. **Fin**: La bancarrota del rival (`BankruptcyEvent`) emite `GameOverEvent`.
