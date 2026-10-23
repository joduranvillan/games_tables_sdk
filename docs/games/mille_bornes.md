# Mille Bornes (`mille_bornes_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Meta oficial de 1000 kilómetros** con opción de **Extensión de Viaje (*Extension*)** a **1200 km** cuando un jugador alcanza exactamente 1000 km y aún quedan cartas en el mazo.
- **Mazo reglamentario completo**:
  - **Cartas de Distancia**: `25`, `50`, `75`, `100` y `200` km (máximo **2 cartas de 200 km** permitidas por jugador en toda la partida).
  - **Cartas de Peligro (`Hazard`)**: `Accident`, `OutOfGas`, `FlatTire`, `Stop` y `SpeedLimit` (restringe a cartas de ≤50 km).
  - **Cartas de Remedio (`Remedy`)**: `Repairs` (cura `Accident`), `Gasoline` (cura `OutOfGas`), `SpareTire` (cura `FlatTire`), `Roll` / Luz Verde (cura `Stop`) y `EndOfLimit` (cura `SpeedLimit`).
  - **Las 4 Cartas de Seguridad (`Safety`)**:
    - `DrivingAce` (As del Volante — inmune a `Accident`).
    - `ExtraTank` (Tanque Extra — inmune a `OutOfGas`).
    - `PunctureProof` (Llantas Inpinchables — inmune a `FlatTire`).
    - `RightOfWay` (Prioridad de Paso — inmune a `Stop` y `SpeedLimit`, actúa como Luz Verde permanente).
- **Turno Extra por Safety y *Coup Fourré***:
  - Jugar cualquier carta `Safety` limpia el peligro asociado si estaba activo, otorga **inmunidad permanente** y concede un **turno extra inmediato**.
  - `CoupFourreCommand` permite responder instantáneamente a un `Hazard` recién jugado por el rival con la `Safety` correspondiente, sumando **+300 puntos de bonificación** y tomando el turno.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `SetupDeckCommand` | Comando inicial de sistema que baraja el mazo y reparte 6 cartas a cada jugador. | `{"command_type": "mille_bornes_game::SetupDeckCommand"}` |
| `DrawCardCommand` | Roba una carta del mazo al comienzo del turno. | `{"command_type": "mille_bornes_game::DrawCardCommand", "player": 1}` |
| `PlayCardCommand` | Juega la carta en la posición `card_index` de la mano del jugador. | `{"command_type": "mille_bornes_game::PlayCardCommand", "player": 1, "card_index": 0}` |
| `PlayDistanceCommand` | Juega una carta de distancia específica (`25`, `50`, `75`, `100` o `200`). | `{"command_type": "mille_bornes_game::PlayDistanceCommand", "player": 1, "distance": 100}` |
| `PlayHazardCommand` | Aplica un peligro (`"Accident"`, `"OutOfGas"`, `"FlatTire"`, `"Stop"`, `"SpeedLimit"`) al rival `target`. | `{"command_type": "mille_bornes_game::PlayHazardCommand", "player": 1, "target": 2, "hazard": "FlatTire"}` |
| `PlaySafetyCommand` | Despliega una carta de seguridad (`"DrivingAce"`, `"ExtraTank"`, `"PunctureProof"`, `"RightOfWay"`). | `{"command_type": "mille_bornes_game::PlaySafetyCommand", "player": 1, "safety": "PunctureProof"}` |
| `DiscardCardCommand` | Descarta la carta en `card_index` al pozo de descarte. | `{"command_type": "mille_bornes_game::DiscardCardCommand", "player": 1, "card_index": 2}` |
| `CoupFourreCommand` | Ejecuta un *Coup Fourré* en respuesta inmediata al peligro recién aplicado por el oponente. | `{"command_type": "mille_bornes_game::CoupFourreCommand", "player": 2}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `CardDrawnEvent` | `player: PlayerId` (`#[owner]`), `card: Card` | `{"event_type": "mille_bornes_game::CardDrawnEvent", "player": 1, "card": {"Distance": 100}}` |
| `DistancePlayedEvent` | `player: PlayerId`, `value: u32`, `new_distance: u32` | `{"event_type": "mille_bornes_game::DistancePlayedEvent", "player": 1, "value": 100, "new_distance": 300}` |
| `HazardPlayedEvent` | `player: PlayerId`, `target: PlayerId`, `hazard: Hazard` | `{"event_type": "mille_bornes_game::HazardPlayedEvent", "player": 1, "target": 2, "hazard": "FlatTire"}` |
| `RemedyPlayedEvent` | `player: PlayerId`, `hazard: Hazard` | `{"event_type": "mille_bornes_game::RemedyPlayedEvent", "player": 2, "hazard": "FlatTire"}` |
| `SafetyPlayedEvent` | `player: PlayerId`, `safety: Safety` | `{"event_type": "mille_bornes_game::SafetyPlayedEvent", "player": 2, "safety": "PunctureProof"}` |
| `TripExtendedEvent` | `new_target: u32` | `{"event_type": "mille_bornes_game::TripExtendedEvent", "new_target": 1200}` |
| `CardDiscardedEvent` | `player: PlayerId`, `card: Card` | `{"event_type": "mille_bornes_game::CardDiscardedEvent", "player": 1, "card": {"Distance": 25}}` |
| `GameOverEvent` | `winner: PlayerId` | `{"event_type": "mille_bornes_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_mille_bornes_session(SessionId(1), seed, PlayerId(1), PlayerId(2))` ejecuta `SetupDeckCommand` y reparte las manos iniciales.
2. **Semáforo Verde y Avance**: Jugador 1 roba carta (`DrawCardCommand`) y juega `Roll` o `RightOfWay`, habilitando el envío de cartas de distancia.
3. **Sabotaje y Coup Fourré**: Jugador 2 ataca con `FlatTire`; si Jugador 1 posee `PunctureProof`, responde con `CoupFourreCommand`, suma +300 puntos de bono y conserva el turno.
4. **Fin**: Al alcanzar exactamente la meta de 1000 km (o 1200 km tras `TripExtendedEvent`), se emite `GameOverEvent`.
