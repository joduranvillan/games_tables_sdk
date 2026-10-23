# Crisis / T.E.G. (`crisis_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Mapa geopolítico de 30 territorios agrupados en 6 continentes** con soporte multilingüe (`crisis_game::territory_name(id, lang)` en `"es"`, `"en"`, `"fr"`, `"de"`, `"pt"`):
  - **América del Sur** (`0..4`, bono `+2`), **América del Norte** (`5..8`, bono `+3`), **Europa** (`9..13`, bono `+5`), **África** (`14..17`, bono `+3`), **Asia** (`18..25`, bono `+7`) y **Oceanía** (`26..29`, bono `+2`).
- **Tres Fases Secuenciales por Turno**:
  1. `PlaceArmies`: incorporación de refuerzos según territorios propios (`max(territorios / 2, 3)`) más bonos por continentes controlados al 100%.
  2. `Attack`: declaración (`DeclareAttackCommand`) y resolución de combate con dados (`RollAttackCommand`) desde territorios con ≥2 ejércitos hacia territorios enemigos limítrofes. El atacante tira hasta 3 dados (`ejércitos - 1`) y el defensor hasta 3 dados; se comparan ordenados de mayor a menor y **el defensor gana todos los empates**.
  3. `Fortify`: reagrupamiento táctico de ejércitos entre territorios propios adyacentes (`FortifyCommand`).
- **Tarjetas de Territorio, Bono de +2 por País Propio y Canjes Crecientes**:
  - Conquistar al menos un territorio durante la fase de ataque otorga automáticamente una tarjeta de país (`card_drawn` en `TerritoryConqueredEvent`) al finalizar la fase.
  - Si al recibir o poseer una tarjeta el jugador es dueño de ese territorio específico, recibe un bono automático de **+2 ejércitos** en dicho país.
  - Canjear 3 tarjetas con símbolos iguales (`Infantry`, `Cavalry`, `Cannon`), 3 distintos o con comodín (`Wild`) mediante `ExchangeCardsCommand` otorga refuerzos escalados (`4, 7, 10, 15, 20...`).
- **Objetivos Secretos y Conquista Global**:
  - Cada comandante recibe al inicio un `SecretObjective` (`ConquerContinent`, `ConquerTwoSmallContinents`, `Exterminate(PlayerId)` o `ConquerTerritories(u8)`). Cumplir el objetivo secreto o controlar los 30 territorios emite `TegGameOverEvent`.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `PlaceArmiesCommand` | Coloca `count` ejércitos de refuerzo en el territorio propio `territory` (`0..29`). | `{"command_type": "crisis_game::PlaceArmiesCommand", "player": 1, "territory": 0, "count": 3}` |
| `DeclareAttackCommand` | Declara un ataque desde el territorio propio `from` hacia el limítrofe enemigo `to` con `dice` dados (`1..3`). | `{"command_type": "crisis_game::DeclareAttackCommand", "player": 1, "from": 0, "to": 1, "dice": 3}` |
| `RollAttackCommand` | Lanza los dados y resuelve el ataque previamente declarado. | `{"command_type": "crisis_game::RollAttackCommand", "player": 1}` |
| `FortifyCommand` | Reagrupa `armies` ejércitos desde el territorio propio `from` hacia el adyacente propio `to`. | `{"command_type": "crisis_game::FortifyCommand", "player": 1, "from": 0, "to": 2, "armies": 2}` |
| `ExchangeCardsCommand` | Canjea el trío de tarjetas en las posiciones `card_indices` de la mano por ejércitos adicionales. | `{"command_type": "crisis_game::ExchangeCardsCommand", "player": 1, "card_indices": [0, 1, 2]}` |
| `EndPhaseCommand` | Avanza de `PlaceArmies` → `Attack` → `Fortify` → fin de turno (otorgando tarjeta si hubo conquista). | `{"command_type": "crisis_game::EndPhaseCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `TerritoryClaimedEvent` | `player: PlayerId`, `territory: TerritoryId`, `armies: u32` | `{"event_type": "crisis_game::TerritoryClaimedEvent", "player": 1, "territory": 0, "armies": 1}` |
| `ArmiesPlacedEvent` | `player: PlayerId`, `territory: TerritoryId`, `count: u32`, `armies_remaining: u32` | `{"event_type": "crisis_game::ArmiesPlacedEvent", "player": 1, "territory": 0, "count": 3, "armies_remaining": 0}` |
| `AttackDeclaredEvent` | `attacker: PlayerId`, `from: TerritoryId`, `to: TerritoryId`, `dice: u8` | `{"event_type": "crisis_game::AttackDeclaredEvent", "attacker": 1, "from": 0, "to": 1, "dice": 3}` |
| `AttackResolvedEvent` | `attacker: PlayerId`, `defender: PlayerId`, `from: TerritoryId`, `to: TerritoryId`, `attacker_rolls: Vec<u32>`, `defender_rolls: Vec<u32>`, `attacker_losses: u32`, `defender_losses: u32`, `territory_conquered: bool` | `{"event_type": "crisis_game::AttackResolvedEvent", "attacker": 1, "defender": 2, "from": 0, "to": 1, "attacker_rolls": [6, 4, 2], "defender_rolls": [5, 3], "attacker_losses": 0, "defender_losses": 2, "territory_conquered": true}` |
| `TerritoryConqueredEvent` | `player: PlayerId`, `territory: TerritoryId`, `from: TerritoryId`, `from_armies: u32`, `to_armies: u32`, `card_drawn: Option<TerritoryCard>` | `{"event_type": "crisis_game::TerritoryConqueredEvent", "player": 1, "territory": 1, "from": 0, "from_armies": 2, "to_armies": 3, "card_drawn": {"territory": 1, "card_type": "Cannon"}}` |
| `PlayerEliminatedEvent` | `player: PlayerId`, `by: PlayerId` | `{"event_type": "crisis_game::PlayerEliminatedEvent", "player": 2, "by": 1}` |
| `FortifiedEvent` | `player: PlayerId`, `from: TerritoryId`, `to: TerritoryId`, `armies: u32` | `{"event_type": "crisis_game::FortifiedEvent", "player": 1, "from": 0, "to": 2, "armies": 2}` |
| `CardsExchangedEvent` | `player: PlayerId`, `armies_gained: u32` | `{"event_type": "crisis_game::CardsExchangedEvent", "player": 1, "armies_gained": 4}` |
| `PhaseChangedEvent` | `player: PlayerId`, `new_phase: String` | `{"event_type": "crisis_game::PhaseChangedEvent", "player": 1, "new_phase": "Attack"}` |
| `TegGameOverEvent` | `winner: PlayerId`, `objective: String` | `{"event_type": "crisis_game::TegGameOverEvent", "winner": 1, "objective": "ConquerContinent(SouthAmerica)"}` |

## 4. Tabla de Adyacencias de los 30 Territorios
| Territorio Origen | Territorios Adyacentes |
|---|---|
| **0: Argentina** | Brasil (1), Chile (2), Perú (4) |
| **1: Brasil** | Argentina (0), Chile (2), Colombia (3), Perú (4), Sahara (14) |
| **2: Chile** | Argentina (0), Brasil (1), Perú (4), Australia (26) |
| **3: Colombia** | Brasil (1), Perú (4), México (5) |
| **4: Perú** | Argentina (0), Brasil (1), Chile (2), Colombia (3) |
| **5: México** | Colombia (3), California (6) |
| **6: California** | México (5), Nueva York (7), Canadá (8) |
| **7: Nueva York** | California (6), Canadá (8), España (10) |
| **8: Canadá** | California (6), Nueva York (7), Kamchatka (22) |
| **9: Gran Bretaña** | España (10), Francia (11), Alemania (12) |
| **10: España** | Nueva York (7), Gran Bretaña (9), Francia (11), Sahara (14) |
| **11: Francia** | Gran Bretaña (9), España (10), Alemania (12) |
| **12: Alemania** | Gran Bretaña (9), Francia (11), Rusia (13) |
| **13: Rusia** | Alemania (12), Aral (18), Tartaria (19) |
| **14: Sahara** | Brasil (1), España (10), Egipto (15), Congo (16) |
| **15: Egipto** | Sahara (14), Congo (16), Sudáfrica (17), Aral (18) |
| **16: Congo** | Sahara (14), Egipto (15), Sudáfrica (17) |
| **17: Sudáfrica** | Egipto (15), Congo (16) |
| **18: Aral** | Rusia (13), Egipto (15), Tartaria (19), India (24) |
| **19: Tartaria** | Rusia (13), Aral (18), Taymir (20), Siberia (21), China (23) |
| **20: Taymir** | Tartaria (19), Siberia (21) |
| **21: Siberia** | Tartaria (19), Taymir (20), Kamchatka (22), China (23) |
| **22: Kamchatka** | Canadá (8), Siberia (21), Japón (25) |
| **23: China** | Tartaria (19), Siberia (21), India (24), Japón (25), Sumatra (28) |
| **24: India** | Aral (18), China (23), Sumatra (28) |
| **25: Japón** | Kamchatka (22), China (23) |
| **26: Australia** | Chile (2), Java (27) |
| **27: Java** | Australia (26), Borneo (29) |
| **28: Sumatra** | China (23), India (24), Borneo (29) |
| **29: Borneo** | Java (27), Sumatra (28) |

## 5. Flujo de Partida de Referencia
1. **Inicio**: `new_crisis_session(SessionId(1), seed, &[PlayerId(1), PlayerId(2)])` reparte equitativamente los 30 territorios y asigna objetivos secretos.
2. **Refuerzo (`PlaceArmiesCommand`)**: Jugador 1 despliega sus ejércitos disponibles.
3. **Ataque (`DeclareAttackCommand` + `RollAttackCommand`)**: Jugador 1 conquista un territorio limítrofe y recibe tarjeta de país.
4. **Fin**: Al cumplir su objetivo secreto o conquistar los 30 países, se emite `TegGameOverEvent`.
