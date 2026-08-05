# Prompts de Corrección y Mejora — Games Tables SDK (Parte 3)

Continúa desde `PROMPTS2.md` (prompts 1–160). Numerados del 161 al 340.

**Prioridades principales:**
1. Reescritura completa de `crisis_game` como TEG (juego de conquista territorial tipo Risk argentino).
2. Corrección de la infraestructura de tests headless de Godot/Redot (actualmente no funcionan).
3. Mejoras de diseño visual en Godot.
4. Correcciones de reglas y nuevas features.

---

## 0. Crisis Game — Reescritura Completa como TEG

El juego `crisis_game` fue implementado erróneamente como un Monopoly. Debe ser un juego de **conquista territorial tipo TEG** (Táctica y Estrategia de Generales, versión argentina de Risk). Los prompts 161–178 reescriben el crate de cero.

**Descripción de TEG simplificado para el SDK:**
- Mapa de 30 territorios agrupados en 6 continentes.
- Fases de turno: Refuerzo → Ataque → Fortificiación.
- Combate: el atacante tira hasta 3 dados, el defensor hasta 2; se comparan los más altos.
- Tarjetas de territorio (infantería/caballería/cañón + comodín): al conquistar un territorio se roba una carta.
- Canje de 3 tarjetas iguales o una de cada tipo = ejércitos extra.
- Tarjetas de objetivo secreto: condición de victoria personalizada por jugador.
- Eliminación: cuando un jugador pierde todos sus territorios.

---

**161.** Reescribir `crisis_game/src/board.rs` desde cero para representar el **mapa TEG simplificado** de 30 territorios y 6 continentes. Definir la estructura:

```rust
pub struct Territory { pub id: TerritoryId, pub name: &'static str, pub continent: ContinentId }
pub struct Continent { pub id: ContinentId, pub name: &'static str, pub bonus_armies: u8, pub territories: &'static [TerritoryId] }
```

Definir los 30 territorios con sus nombres (orientación latinoamericana/argentina) y las adyacencias como `pub const ADJACENCIES: &[(TerritoryId, TerritoryId)]` (pares ordenados). Definir los 6 continentes con sus bonus: América del Sur (5 terr., +2), América del Norte (4 terr., +3), Europa (5 terr., +5), África (4 terr., +3), Asia (8 terr., +7), Oceanía (4 terr., +2). Total: 30 territorios. Eliminar completamente el tablero lineal de Monopoly anterior. Añadir la función `pub fn are_adjacent(a: TerritoryId, b: TerritoryId) -> bool` que consulta la constante de adyacencias.

---

**162.** Reescribir `crisis_game/src/resources.rs` para representar el **estado del juego TEG**. Eliminar `PlayersResource`, `BoardResource` y `PendingPurchaseResource` anteriores. Definir:

```rust
pub struct TerritoryMapResource { pub armies: HashMap<TerritoryId, u32>, pub owner: HashMap<TerritoryId, PlayerId> }
pub struct PlayerHandResource { pub territory_cards: HashMap<PlayerId, Vec<TerritoryCard>>, pub objective: HashMap<PlayerId, ObjectiveCard> }
pub struct TurnPhaseResource { pub phase: TurnPhase }
pub enum TurnPhase { PlaceArmies { armies_remaining: u32 }, Attack, Fortify }
pub struct PendingAttackResource { pub attacker: Option<PlayerId>, pub from: Option<TerritoryId>, pub to: Option<TerritoryId>, pub attacker_dice: u8 }
pub struct EliminatedPlayersResource { pub eliminated: HashSet<PlayerId> }
```

Todos deben derivar `GameResource`. Añadir constructores `new(players: &[PlayerId])` que distribuyen los 30 territorios aleatoriamente entre los jugadores usando `RandomResource` y asignan 1 ejército por territorio. Calcular y asignar los ejércitos iniciales de refuerzo según la fórmula estándar de Risk (territorios_propios / 3, mínimo 3, más bonus de continentes).

---

**163.** Reescribir `crisis_game/src/commands.rs` con los **comandos TEG**. Eliminar `RollAndMoveCommand` y `BuyCompanyCommand`. Definir:

```rust
pub struct PlaceArmiesCommand { pub player: PlayerId, pub territory: TerritoryId, pub count: u32 }
pub struct DeclareAttackCommand { pub player: PlayerId, pub from: TerritoryId, pub to: TerritoryId, pub dice: u8 }
pub struct RollAttackCommand { pub player: PlayerId }
pub struct FortifyCommand { pub player: PlayerId, pub from: TerritoryId, pub to: TerritoryId, pub armies: u32 }
pub struct EndPhaseCommand { pub player: PlayerId }
pub struct ExchangeCardsCommand { pub player: PlayerId, pub card_indices: [usize; 3] }
```

Todos deben derivar `Debug, Clone, Serialize, Deserialize, GameCommand` con `#[issuer] pub player: PlayerId`. Registrar todos en `crisis_game/src/lib.rs` con `pub use`.

---

**164.** Reescribir `crisis_game/src/events.rs` con los **eventos TEG**. Eliminar todos los eventos anteriores. Definir:

```rust
pub struct TerritoryClaimedEvent { pub player: PlayerId, pub territory: TerritoryId, pub armies: u32 }
pub struct ArmiesPlacedEvent { pub player: PlayerId, pub territory: TerritoryId, pub count: u32, pub armies_remaining: u32 }
pub struct AttackDeclaredEvent { pub attacker: PlayerId, pub from: TerritoryId, pub to: TerritoryId, pub dice: u8 }
pub struct AttackResolvedEvent { pub attacker: PlayerId, pub defender: PlayerId, pub attacker_rolls: Vec<u32>, pub defender_rolls: Vec<u32>, pub attacker_losses: u32, pub defender_losses: u32, pub territory_conquered: bool }
pub struct TerritoryConqueredEvent { pub player: PlayerId, pub territory: TerritoryId, pub card_drawn: Option<TerritoryCard> }
pub struct PlayerEliminatedEvent { pub player: PlayerId, pub by: PlayerId }
pub struct FortifiedEvent { pub player: PlayerId, pub from: TerritoryId, pub to: TerritoryId, pub armies: u32 }
pub struct CardsExchangedEvent { pub player: PlayerId, pub armies_gained: u32 }
pub struct PhaseChangedEvent { pub player: PlayerId, pub new_phase: String }
pub struct TegGameOverEvent { pub winner: PlayerId, pub objective: String }
```

Todos deben derivar `Debug, Serialize, Deserialize, GameEvent`.

---

**165.** Implementar el **handler de `PlaceArmiesCommand`** en `crisis_game/src/rules.rs`. Validar: (a) es el turno del jugador, (b) la fase actual es `TurnPhase::PlaceArmies { armies_remaining }`, (c) el territorio objetivo pertenece al jugador (`owner[territory] == player`), (d) `count <= armies_remaining` y `count >= 1`. Al aceptar: decrementar `armies_remaining`, sumar `count` a `armies[territory]`. Si `armies_remaining` llega a 0, cambiar la fase a `TurnPhase::Attack` y emitir `PhaseChangedEvent`. Emitir `ArmiesPlacedEvent`. Añadir el test `test_colocar_ejercitos_reduce_el_disponible_y_cambia_fase_al_agotarse` en `crisis_game/tests/game_rules.rs`.

---

**166.** Implementar el **handler de `DeclareAttackCommand`** en `crisis_game/src/rules.rs`. Validar: (a) fase actual es `TurnPhase::Attack`, (b) `from` pertenece al atacante, (c) `to` es adyacente a `from` (usar `are_adjacent`), (d) `to` no pertenece al atacante, (e) `armies[from] > 1` (debe dejar al menos 1 en el territorio), (f) `dice` está entre 1 y `min(3, armies[from] - 1)`. Almacenar el ataque en `PendingAttackResource`. Emitir `AttackDeclaredEvent`. Añadir el test `test_declarar_ataque_valida_adyacencia_y_ejercitos` que verifica que atacar un territorio no adyacente retorna `EngineError::InvalidCommand`.

---

**167.** Implementar el **handler de `RollAttackCommand`** en `crisis_game/src/rules.rs`. Solo válido si `PendingAttackResource` tiene un ataque pendiente declarado por el jugador. Tirar los dados del atacante (`dice` veces d6) y los del defensor (`min(2, armies[to])` veces d6) usando `RandomResource`. Ordenar ambos conjuntos de mayor a menor. Comparar pares: si el atacante gana cada comparación, el defensor pierde 1 ejército; si el defensor gana o empata, el atacante pierde 1 ejército. Si `armies[to]` llega a 0: mover `min(dice, armies[from]-1)` ejércitos al territorio conquistado, cambiar `owner[to]`, emitir `TerritoryConqueredEvent` y robar una tarjeta aleatoria de territorio. Emitir `AttackResolvedEvent`. Si el defensor queda eliminado (0 territorios), emitir `PlayerEliminatedEvent`. Verificar si el atacante cumplió su objetivo; si sí, emitir `TegGameOverEvent`. Limpiar `PendingAttackResource`.

---

**168.** Implementar el **handler de `EndPhaseCommand`** en `crisis_game/src/rules.rs`. Según la fase actual: si es `PlaceArmies` y `armies_remaining > 0`, rechazar con error (debe colocar todos los ejércitos). Si es `Attack`, cambiar a `Fortify`. Si es `Fortify`, avanzar el turno al siguiente jugador no eliminado en `EliminatedPlayersResource`, calcular sus ejércitos de refuerzo (territorios/3 + bonus continentes, mínimo 3), y cambiar a `PlaceArmies { armies_remaining: refuerzos }`. Emitir `PhaseChangedEvent`. Añadir el test `test_end_phase_cicla_correctamente_de_ataque_a_fortify_a_nuevo_turno`.

---

**169.** Implementar el **handler de `FortifyCommand`** en `crisis_game/src/rules.rs`. Validar: (a) fase actual es `TurnPhase::Fortify`, (b) `from` y `to` pertenecen al jugador, (c) `from` y `to` están conectados por territorios propios (flood-fill o BFS: solo se puede fortifificar a través de territorios propios), (d) `armies <= armies[from] - 1` (dejar al menos 1 en origen). Mover los ejércitos. Emitir `FortifiedEvent`. Solo se puede fortificar **una vez** por turno (añadir `fortified: bool` a `TurnPhaseResource`). Añadir el test `test_fortify_requiere_conexion_de_territorios_propios`.

---

**170.** Implementar el **handler de `ExchangeCardsCommand`** en `crisis_game/src/rules.rs`. Las tarjetas de territorio tienen tipo `CardType::Infantry | Cavalry | Cannon | Wild`. Una combinación válida es: tres del mismo tipo, o una de cada tipo no-Wild, o cualquier combinación con un Wild. El número de ejércitos concedidos sigue la escala creciente de TEG (primer canje: 4, segundo: 6, tercero: 8, luego +5 por canje). Almacenar el contador de canjes en `ExchangeCountResource`. Quitar las 3 tarjetas de la mano del jugador, sumar los ejércitos a `armies_remaining` en la fase actual. Emitir `CardsExchangedEvent`. Obligatorio si el jugador tiene 5 o más tarjetas. Añadir el test `test_canje_de_tres_infanterias_otorga_ejercitos`.

---

**171.** Implementar las **tarjetas de objetivo** en `crisis_game`. Definir `ObjectiveCard` en `crisis_game/src/board.rs` con variantes: `ConquerContinent(ContinentId)` (conquistar un continente completo), `ConquerTwoSmallContinents` (conquistar dos continentes pequeños), `Exterminate(PlayerId)` (eliminar a un jugador específico — si ya fue eliminado por otro, el objetivo cambia a conquistar 24 territorios), `ConquerTerritories(u8)` (controlar X territorios con al menos 2 ejércitos cada uno). Implementar `pub fn check_objective(objective: &ObjectiveCard, map: &TerritoryMapResource, players: &[PlayerId], eliminated: &EliminatedPlayersResource, player: PlayerId) -> bool` en `crisis_game/src/board.rs`. Llamar a esta función en `RollAttackCommand` tras cada conquista. Añadir el test `test_objetivo_conquistar_continente_detecta_victoria`.

---

**172.** Implementar la **distribución aleatoria inicial** de territorios en `new_crisis_session`. Los 30 territorios deben distribuirse en rondas entre los jugadores (estilo TEG: primer jugador elige 1, segundo elige 1, ..., hasta repartir todos). Para la versión SDK simplificada, hacer la distribución aleatoria directa usando `RandomResource`. Cada jugador empieza con 1 ejército en cada territorio. Calcular los ejércitos extra iniciales según el número de jugadores (2j: 40 extra c/u, 3j: 35, 4j: 30, 5j: 25, 6j: 20). Emitir `TerritoryClaimedEvent` por cada territorio asignado. Añadir el test `test_distribucion_inicial_cubre_todos_los_territorios_sin_repetir`.

---

**173.** Reescribir `crisis_game/tests/game_rules.rs` con los **tests TEG básicos**. Eliminar todos los tests Monopoly anteriores. Implementar:

- `test_setup_distribuye_todos_los_territorios`: Verifica que los 30 territorios tienen dueño asignado y `armies >= 1`.
- `test_ataque_resolucion_dados_reduce_ejercitos`: Fuerza `PendingAttackResource`, llama `RollAttackCommand`, verifica que `AttackResolvedEvent` contiene los dados tirados y las pérdidas correctas.
- `test_conquista_transfiere_territorio_al_atacante`: Pone 1 ejército defensor y 3 atacantes, tira dados hasta que el defensor pierde (seed controlada), verifica `TerritoryConqueredEvent`.
- `test_player_eliminado_sale_del_ciclo_de_turnos`: Deja a P2 con 1 solo territorio con 1 ejército, lo conquista, verifica `PlayerEliminatedEvent` y que el siguiente turno va a P3 (no P2).
- `test_game_over_por_objetivo_conquistar_continente`: Asigna el continente completo a P1 (salvo 1 territorio), P1 lo conquista, verifica `TegGameOverEvent { winner: P1 }`.

---

**174.** Actualizar `crisis_game/src/lib.rs` para exportar el **nuevo API TEG**. Reemplazar todas las re-exportaciones Monopoly por las nuevas: `TerritoryId`, `ContinentId`, `TerritoryCard`, `ObjectiveCard`, `TurnPhase`, `PlaceArmiesCommand`, `DeclareAttackCommand`, `RollAttackCommand`, `FortifyCommand`, `EndPhaseCommand`, `ExchangeCardsCommand`, todos los eventos, `TerritoryMapResource`, `PlayerHandResource`, `TurnPhaseResource`, `EliminatedPlayersResource`, `TERRITORIES`, `CONTINENTS`, `ADJACENCIES`. Actualizar `new_crisis_session` para que acepte 2–6 `PlayerId` y configure el nuevo estado TEG completo con recursos inicializados. Verificar que `cargo test -p crisis_game` pasa sin errores de compilación.

---

**175.** Actualizar `open_table_godot/src/lib.rs` para agregar las **señales TEG del bridge**. Reemplazar las señales Monopoly de crisis (`player_moved`, `company_purchased`, `rent_paid`, `tax_paid`, `crisis_occurred`, `opportunity_gained`) por:

```gdscript
signal territory_conquered(player_id: int, territory_id: int, from_armies: int, to_armies: int)
signal attack_resolved(from_id: int, to_id: int, attacker_rolls: Array, defender_rolls: Array, attacker_losses: int, defender_losses: int)
signal armies_placed(player_id: int, territory_id: int, count: int, remaining: int)
signal player_eliminated(player_id: int, by_player_id: int)
signal phase_changed(player_id: int, new_phase: String)
signal cards_exchanged(player_id: int, armies_gained: int)
signal crisis_game_over(winner_id: int, objective: String)
```

Implementar el parsing del `event_json` para despachar cada señal al detectar el tipo de evento correspondiente (`TerritoryConqueredEvent`, `AttackResolvedEvent`, etc.). Añadir `start_local_match_crisis(seed: i64, players: Array[int]) -> bool` al bridge que acepta entre 2 y 6 jugadores.

---

**176.** Reescribir `godot_project/crisis_board.gd` como **UI de TEG**. Eliminar la UI de Monopoly anterior. La nueva escena debe mostrar:
- Un `TextureRect` de fondo con el mapa de 30 territorios (imagen placeholder o dibujada con `Polygon2D`s).
- Un `Label` por cada territorio con el nombre y el número de ejércitos (nodos posicionados mediante `Control.position`).
- Al recibir `territory_conquered`, cambiar el color del territorio al color del jugador conquistador.
- Al recibir `attack_resolved`, mostrar una ventana popup con los dados tirados (usando `Label`s de iconos de dados).
- Al recibir `armies_placed`, actualizar el contador de ejércitos del territorio.
- Un panel lateral con el estado actual de cada jugador: territorios controlados, tarjetas en mano, fase actual.
- Botones contextuales: "Colocar 1 ejército", "Atacar", "Fortificicar", "Fin de fase", "Canjear tarjetas" — solo habilitados cuando la fase y el turno son correctos.

---

**177.** Crear `godot_project/tests/crisis_smoke.gd` — **test headless TEG**. Instanciar `OpenTableBridge`. Llamar `bridge.start_local_match_crisis(42, [1, 2])`. Verificar:
- `bridge.current_player()` es 1.
- Conectar señal `armies_placed` y emitir `PlaceArmiesCommand` por JSON para un territorio de P1.
- Verificar que la señal `armies_placed` se recibe con `player_id == 1`.
- Emitir `EndPhaseCommand` → verificar `phase_changed` con `new_phase == "Attack"`.
- Emitir `EndPhaseCommand` → verificar `phase_changed` con `new_phase == "Fortify"`.
- Emitir `EndPhaseCommand` → verificar que el turno avanza a P2 (no implementado en el bridge aún → marcarlo como `TODO: verificar turno`).
- Reportar PASS/FAIL con el patrón estándar de `bridge_smoke.gd`. Ejecutar con `redot --headless --path godot_project --script res://tests/crisis_smoke.gd`.

---

**178.** Actualizar el **test en PROMPTS2.md prompt 30** que era incompleto para crisis. Reescribir el test `test_subasta_empresa_la_gana_el_mayor_postor` (que ya no tiene sentido en TEG) por los tres tests TEG ya definidos en el prompt 173. Verificar que `cargo test -p crisis_game -- --nocapture` muestra todos los tests pasando. Actualizar `NEXT_STEPS.md` con el estado actual de `crisis_game`: "Reescrito como TEG — fase de reglas completa, sin IA, sin UI final".

---

## 1. Godot / Redot — Corrección de Tests Headless

Los tests en `godot_project/tests/` no son funcionales headless. Los problemas conocidos son: (a) el `.so` compilado no está presente en el path esperado, (b) errores de API en las señales del bridge, (c) el runner `redot --headless` termina con exit code 1 sin mostrar qué falló, (d) scripts que usan señales que el bridge no emite aún.

---

**179.** Crear `tools/run_godot_tests.sh` — **script maestro de tests headless**. El script debe: (1) compilar el bridge con `cargo build -p open_table_godot` y abortar si falla, (2) correr cada script de test en `godot_project/tests/*.gd` con `redot --headless --path godot_project --script res://tests/<script>`, capturando stdout/stderr y el exit code, (3) imprimir un resumen final `PASS/FAIL` por script, (4) retornar exit code 1 si algún test falló. Añadir una variable `REDOT_BIN` configurable por entorno (default: `redot`). Añadir el target `test-godot` al `Makefile` que llama a este script.

---

**180.** Corregir el **problema de librería no encontrada** en los tests headless. El archivo `godot_project/opentable.gdextension` apunta a `res://../target/debug/libopen_table_godot.so`. Si el archivo no existe al correr el test, Redot no lanza error legible. Modificar `tools/run_godot_tests.sh` para verificar que `target/debug/libopen_table_godot.so` existe antes de lanzar los tests y, si no, mostrar el mensaje `"ERROR: Compilar el bridge con: cargo build -p open_table_godot"` y salir con código 2. Añadir `.gdextension` alternativo `opentable_ci.gdextension` con path absoluto para entornos CI donde el repo no está en la raíz. Documentar ambas variantes en `godot_project/README.md`.

---

**181.** Corregir `godot_project/tests/bridge_smoke.gd` — **test de damas (checkers)**. El test usa `bridge.send_move(player, from_row, from_col, to_row, to_col)` que puede no existir en el API actual del bridge. Auditar `open_table_godot/src/lib.rs` para confirmar el nombre exacto del método GDScript (puede ser `send_command_json` o `send_move`). Si el método es `send_command_json`, reescribir las llamadas a `bridge.send_command_json(player_id, JSON.stringify({command_type: "MovePieceCommand", ...}))`. Verificar que el test pasa con `redot --headless --path godot_project --script res://tests/bridge_smoke.gd` y el exit code es 0.

---

**182.** Corregir `godot_project/tests/chess_smoke.gd` — **test de ajedrez**. Auditar el script para verificar que: (a) usa `bridge.start_local_match_chess(seed, player1, player2)` con el número correcto de parámetros, (b) la señal `event_json` es el nombre correcto (no `piece_moved` para ajedrez), (c) el parsing del JSON verifica `event_type == "PieceMovedEvent"`. Si el bridge emite señales con nombres distintos para ajedrez, adaptar el script. Verificar que el movimiento de peón `e2-e4` en coordenadas de fila/col es correcto para la representación interna del tablero de ajedrez del SDK. Confirmar exit code 0 headless.

---

**183.** Corregir `godot_project/tests/shogi_smoke.gd` — **test de Shogi**. El test de Shogi usa coordenadas en notación japonesa (7g → fila 6, col 2). Verificar que el comando `MovePieceCommand` del bridge usa coordenadas `from_row`, `from_col`, `to_row`, `to_col` en formato fila/columna 0-indexed, no notación japonesa. Actualizar el script si usa notación incorrecta. Verificar que `start_local_match_shogi(seed, p1, p2)` existe en el bridge con esa firma. Confirmar exit code 0 headless.

---

**184.** Corregir `godot_project/tests/go_smoke.gd` — **test de Go**. El test de Go del prompt 37 verifica captura y doble-pass. Auditar que: (a) `bridge.start_local_match_go(seed, p1, p2)` existe, (b) el comando para colocar piedra es `PlaceStoneCommand` serializable a JSON con campos `player`, `row`, `col`, (c) la señal de captura (`StonesCapturedEvent`) llega como `event_json` con `event_type == "StonesCapturedEvent"` y campo `count`. Corregir cualquier discrepancia. Confirmar exit code 0 headless.

---

**185.** Corregir `godot_project/tests/uno_smoke.gd` — **test de UNO**. Auditar el script UNO para verificar que: (a) `bridge.start_local_match_uno(seed, players_array)` acepta la firma correcta, (b) el comando `PlayCardCommand` se serializa con los campos correctos (`player`, `card_index`), (c) la señal de carta jugada se recibe correctamente. UNO tiene estado de mano que cambia con cada robo. Simplificar el test: solo verificar que `start_local_match_uno` arranca, que `current_player()` es 1, y que un `DrawCardCommand` no produce crash. Confirmar exit code 0 headless.

---

**186.** Corregir `godot_project/tests/backgammon_smoke.gd` — **test de Backgammon**. El test de Backgammon requiere tirar dados antes de mover. Verificar que la secuencia es: (1) `RollDiceCommand`, (2) obtener los dados del evento, (3) `MoveCheckerCommand` con un movimiento válido para esos dados. Dado que los dados son aleatorios, simplificar el test usando `bridge.send_command_json` con `RollDiceCommand` y verificar solo que llega un evento `DiceRolledEvent` sin crash. No intentar mover fichas específicas. Confirmar exit code 0 headless.

---

**187.** Corregir `godot_project/tests/xiangqi_smoke.gd` — **test de Xiangqi**. El Xiangqi tiene una posición inicial estándar. Verificar que las coordenadas en el test para mover un Soldado Rojo desde su posición inicial son correctas para la representación 10x9 del SDK. Auditar que `start_local_match_xiangqi(seed, p1, p2)` existe. Si el test intenta mover el Cañón Rojo (la pieza más fácil de mover en apertura), verificar coordenadas: el Cañón rojo empieza en (2, 1) y (2, 7) en indexación 0-based (fila 2 = tercera fila desde abajo para Red). Confirmar exit code 0 headless.

---

**188.** Corregir `godot_project/tests/ludo_smoke.gd` — **test de Ludo**. Ludo requiere sacar un 6 para sacar la ficha de la base. Simplificar el test: usar seed determinista que garantice un dado de 6 en el primer tiro de P1. Si no es posible controlar la seed desde GDScript (el seed se pasa a `start_local_match_ludo`), iterar seeds hasta encontrar una que dé 6. Verificar que `TokenMovedEvent` llega. Confirmar exit code 0 headless.

---

**189.** Corregir `godot_project/tests/hud_and_settings_smoke.gd` — **test de HUD y settings**. Auditar el script para verificar que no depende de nodos de escena que no existen en modo headless (como `SceneTree.current_scene`). Si el test instancia `turn_indicator.gd` o `network_status_hud.gd` directamente, asegurarse de que lo hace como `GDScript.new()` y no cargando una escena `.tscn`. Cualquier uso de `await` sin tiempo de espera puede colgar el proceso headless — reemplazar por callbacks síncronos. Confirmar exit code 0 headless.

---

**190.** Corregir `godot_project/tests/test_native_p2p_adapter.gd` — **test del adaptador nativo P2P**. Este test usa una clase `MockNativePlugin` que puede no estar definida. Verificar que la clase mock está en el mismo archivo o en un archivo separado accesible. Si usa `class_name`, verificar que Godot la registra antes de la ejecución headless (los `class_name` globales pueden no estar disponibles en `--headless --script`). Mover la clase mock al mismo archivo del test. Confirmar exit code 0 headless.

---

**191.** Corregir `godot_project/tests/test_spectator.gd` — **test de modo espectador**. El modo espectador requiere una sesión TCP en marcha. En modo headless, abrir un host TCP en un puerto libre (ej. 19876), conectar el espectador, verificar la señal `spectator_event_received`. Asegurar que el host TCP se inicia en un thread separado o con `await Engine.get_main_loop()...` para no bloquear el proceso headless. Añadir un timeout de 3 segundos para que el test no cuelgue si la conexión falla. Confirmar exit code 0 headless.

---

**192.** Añadir un **runner de tests GDScript unificado** `godot_project/tests/run_all_tests.gd`. En lugar de correr cada script por separado, crear un script que cargue y ejecute todos los tests en secuencia usando `GDScript.new()`. Cada test debe exponer una función `run_tests() -> bool`. Adaptar los scripts existentes para exponer esa función además del `_initialize()`. El runner imprime el resumen global y retorna exit code 0 solo si todos pasan. Actualizar `tools/run_godot_tests.sh` para usar este runner en un solo invocación de Redot.

---

**193.** Añadir **timeout global a los tests headless** para evitar cuelgues. Modificar `tools/run_godot_tests.sh` para correr cada invocación de Redot con `timeout 30 redot ...`. Si el proceso excede 30 segundos, marcar ese test como `TIMEOUT` (fallo) y continuar con el siguiente. Añadir una señal de progreso en los tests de TCP (prompt 191) para que emitan output periódico cada segundo y así el timeout de 30s sea suficiente. Documentar en `godot_project/README.md` el tiempo esperado de cada test (bridge_smoke: ~2s, spectator: ~5s).

---

**194.** Añadir el **test headless de crisis TEG** `godot_project/tests/crisis_smoke.gd` (ya definido en prompt 177) al runner unificado del prompt 192. Verificar que el bridge emite las señales correctas para un turno completo de TEG (colocar ejércitos → fin de fase → ataque → fin de fase → fortificiación → fin de fase → turno de P2). Confirmar exit code 0 headless.

---

**195.** Añadir un **test de carga de extensión** `godot_project/tests/extension_load_smoke.gd`. Un test mínimo que solo verifica que `OpenTableBridge` existe como clase (no instancia nada más), imprime "PASS extensión cargada" y sale con código 0. Útil en CI para verificar que el `.so` se compiló correctamente y Redot lo carga sin crash antes de correr los tests completos. Debe ser el primer test en el runner unificado.

---

**196.** Crear el **archivo `godot_project/README.md`** con instrucciones de tests. Documentar: (1) cómo compilar el bridge (`cargo build -p open_table_godot`), (2) cómo correr los tests headless (`make test-godot` o `./tools/run_godot_tests.sh`), (3) lista de tests disponibles con descripción de qué verifica cada uno, (4) cómo correr un test específico (`redot --headless --path godot_project --script res://tests/bridge_smoke.gd`), (5) troubleshooting de errores comunes (librería no encontrada, crash por señal no registrada, timeout).

---

**197.** Añadir **logging estructurado en los tests headless**. Modificar el patrón de tests (empezando por `bridge_smoke.gd`) para que cada test imprima en formato: `[TEST] chess_smoke.gd | PASS nombre_del_caso | FAIL nombre_del_caso | SKIP nombre_del_caso`. Añadir al runner `tools/run_godot_tests.sh` un parser de ese formato para generar un reporte `test_results.json` con todos los resultados. Publicar ese JSON como artefacto en el workflow de CI (`ci.yml`) usando `actions/upload-artifact`.

---

**198.** Verificar que los tests headless pasan en **modo release** además de debug. Añadir al `tools/run_godot_tests.sh` una opción `--release` que compila con `cargo build -p open_table_godot --release` y usa `opentable.gdextension` en la variante `linux.release.x86_64`. Verificar que `bridge_smoke.gd` y `chess_smoke.gd` pasan en release. Si hay diferencias de comportamiento entre debug y release (ej. assertions de Rust que solo corren en debug), documentarlas en `godot_project/README.md`.

---

## 2. Diseño Visual — Mejoras de UI en Godot

---

**199.** Implementar un **sistema de colores de jugador consistente** en `godot_project/game_manager.gd`. Definir un array de colores `PLAYER_COLORS: Array[Color] = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE]`. Exponer `static func get_player_color(player_id: int) -> Color`. Actualizar `checkers_board.gd`, `chess_board.gd`, y `ludo_board.gd` para usar `GameManager.get_player_color(player_id)` en lugar de colores hardcodeados. Asegurar que los mismos IDs de jugador siempre mapean al mismo color en todos los tableros.

---

**200.** Implementar **animaciones de piezas con Tween** en `checkers_board.gd`. Al recibir la señal `piece_moved`, crear un `Tween` que mueva el sprite de la pieza desde `(from_row, from_col)` a `(to_row, to_col)` en 0.25 segundos con interpolación `TRANS_QUAD, EASE_IN_OUT`. Si `captured_row != -1`, encadenar una animación de desaparición (scale a 0 en 0.15s) de la pieza capturada. Emitir una señal `animation_finished` del nodo al completarse. Añadir una flag `animating: bool` para ignorar inputs durante la animación.

---

**201.** Implementar **animaciones de piezas** en `chess_board.gd`. Usar el mismo patrón de Tween del prompt 200 para el movimiento de piezas. Para el enroque (cuando el rey y la torre se mueven en el mismo turno), detectar los dos eventos `PieceMovedEvent` consecutivos y animar ambas piezas simultáneamente. Para la coronación de peón, añadir una animación de "brillo" (modulación alpha 0→1→0.5) sobre la pieza promovida. Emitir `animation_finished` al completarse todas las animaciones activas.

---

**202.** Añadir **resaltado de movimientos válidos** en `checkers_board.gd`. Al hacer click en una pieza propia (detectado por `_gui_input` o `DragDropLayer`), mostrar círculos semitransparentes (radio 20px, color blanco con alpha 0.5) en las casillas de destino válidas. Dado que el backend no expone las jugadas legales directamente, implementar una función client-side en GDScript que calcula los movimientos válidos tentativa local (o usar un array de movimientos del último `event_json` si el bridge los incluye). Al hacer click en un destino resaltado, enviar el movimiento. Al hacer click fuera, quitar los resaltados.

---

**203.** Añadir **resaltado de movimientos válidos** en `chess_board.gd`. Al seleccionar una pieza, enviar un `GetLegalMovesQuery` al bridge (si existe) o implementar un cálculo client-side simplificado. Como alternativa pragmática: al primer click en la pieza, mostrar un destaque simple (borde dorado en la casilla seleccionada), y al segundo click en cualquier otra casilla, intentar el movimiento — si es rechazado, mostrar un breve parpadeo rojo. Añadir una opción en `settings_menu.tscn` para habilitar/deshabilitar el resaltado.

---

**204.** Implementar un **sistema de texturas de piezas** para `chess_board.gd`. Crear la carpeta `godot_project/assets/chess/` con 12 imágenes SVG (o PNG 64×64): rey, dama, torre, alfil, caballo, peón × 2 colores. Cargar las texturas en `chess_board.gd` con `load("res://assets/chess/white_king.png")`. Si las imágenes no existen, usar fallback a `Label` con caracteres Unicode de ajedrez (♔♕♖♗♘♙♚♛♜♝♞♟). Añadir la opción de fallback en las variables de exportación del nodo.

---

**205.** Implementar **efectos de sonido básicos** en `godot_project`. Crear `godot_project/audio_manager.gd` como Autoload con funciones `play_move()`, `play_capture()`, `play_invalid()`, `play_game_over()`. Usar `AudioStreamPlayer` con archivos `.wav` de libre uso (incluir 4 archivos en `godot_project/assets/audio/`). Si no hay archivos de audio, el `AudioManager` debe funcionar en modo silencioso sin error. Conectar `play_move()` a `piece_moved`, `play_capture()` cuando `captured_row != -1` en checkers, `play_invalid()` a `move_rejected`, y `play_game_over()` a `game_over`.

---

**206.** Mejorar el **overlay de game over** (`godot_project/game_over_overlay.gd`). Añadir una animación de entrada: el overlay hace fade-in desde alpha 0 a alpha 1 en 0.5 segundos. El `Label` del ganador debe usar un `AnimationPlayer` con efecto de escalado ("bounce": escala 0.5→1.1→1.0). Añadir un segundo botón "Menú Principal" además de "Jugar de nuevo". El botón "Jugar de nuevo" llama `get_tree().reload_current_scene()`; el de menú principal llama `SceneManager.transition_to("res://main.tscn")`. Aplicar el overlay a `checkers_board.gd` y `chess_board.gd`.

---

**207.** Mejorar el **indicador de turno** (`godot_project/turn_indicator.gd`). Añadir una animación de pulso (scale 1→1.05→1 en 0.5s, en loop) sobre el `ColorRect` del jugador activo. Al cambiar de turno, animar el texto del nombre con un slide desde fuera de la pantalla. Añadir soporte para mostrar el nombre del jugador usando los nombres configurados en `settings_menu.tscn`. Si no hay nombre configurado, mostrar "Jugador 1", "Jugador 2", etc.

---

**208.** Implementar **temas visuales** en `godot_project/board_theme.gd` y `godot_project/theme_manager.gd`. El tema "Madera Clásica" usa colores `#DEB887`/`#8B4513` para las casillas, fuente serif. El tema "Moderno Minimal" usa `#EEEEEE`/`#222222` y fuente monospace. El `ThemeManager` Autoload expone `get_current_theme() -> BoardTheme` y `set_theme(theme_name: String)`. Los tableros de ajedrez, damas y shogi deben leer el tema al inicializar y reconfigurarse al recibir la señal `theme_changed` del `ThemeManager`. Verificar que el cambio de tema es visible sin recargar la escena.

---

**209.** Mejorar el **menú principal** (`godot_project/main_menu.gd`). Añadir una animación de entrada con `AnimationPlayer`: los 12 botones de juego aparecen escalonados (cada botón 50ms después del anterior, fade-in desde transparente). Los botones deben mostrar un ícono 32×32 del juego correspondiente (placeholder coloreado si no hay imagen). Al hacer hover, el botón escala ligeramente (1.0→1.05). Al hacer click, iniciar la transición de escena con `SceneManager.transition_to(...)` en lugar de cambio directo.

---

**210.** Crear el **tablero visual de Go** (`godot_project/go_board.gd`) con cuadrícula dibujada a mano. Usar `_draw()` del nodo `Control` para renderizar las 9×9 líneas del tablero de Go con `draw_line()` (líneas negras sobre fondo beige). Marcar los 5 puntos de estrella (hoshi) con `draw_circle()` relleno. Las piedras son `TextureRect` circulares negros/blancos instanciados como hijos. Al recibir `StonesCapturedEvent`, hacer `fade_out` de las piedras capturadas con Tween en 0.3s. Las intersecciones se detectan por click más cercano (distancia Manhattan).

---

**211.** Mejorar la **UI de UNO** (`godot_project/uno_board.gd`). Las cartas de la mano deben mostrarse con un efecto de abanico (fan layout): rotaciones ligeras de ±15° distribuidas entre las cartas. Al hacer hover sobre una carta, elevarla 20px verticalmente con Tween. Las cartas jugables deben tener un borde dorado parpadeante (`AnimationPlayer` con modulación de color). La pila de descarte debe mostrar la carta superior con animación de "deslizamiento" al recibir una nueva carta. El contador de cartas de cada jugador se muestra en la parte superior.

---

**212.** Mejorar la **UI del tablero de Backgammon** (`godot_project/backgammon_board.gd`). Los 24 puntos triangulares se dibujan con `Polygon2D` en dos colores alternados (rojo/blanco). Las fichas se apilan verticalmente: cuando hay más de 5 fichas en un punto, mostrar un número encima en lugar de todas las fichas. Al recibir `CheckerMovedEvent`, animar la ficha con un arco curvo (Tween con control point intermedio usando `lerp` en Y) de un punto al otro. La barra central muestra las fichas golpeadas con un fondo de color diferente.

---

**213.** Mejorar la **UI del tablero de Shogi** (`godot_project/shogi_board.gd`). Las piezas se representan como pentágonos apuntando en la dirección del jugador. Al seleccionar una pieza, mostrar los destinos válidos con círculos verdes. Las piezas promovidas tienen texto rojo en lugar de negro. El panel de "mano" (piezas capturadas disponibles para drop) se muestra en dos paneles laterales. Al seleccionar una pieza del panel de mano, el cursor cambia a la imagen de la pieza y los drops válidos se resaltan en el tablero.

---

**214.** Mejorar la **UI del tablero de Ludo** (`godot_project/ludo_board.gd`). El tablero de Ludo se dibuja con el camino de 52 casillas en forma de cruz, usando `ColorRect` nodos. Las zonas de color de inicio (esquinas) y las columnas de casa se colorean con el color del jugador correspondiente. Los tokens son `TextureButton` circulares. Al tirar los dados, mostrar una animación de "vibración" de 0.5s en el `Label` del dado antes de mostrar el valor final. Al coronar o eliminar un token, añadir un efecto de partículas con `GPUParticles2D`.

---

**215.** Implementar el **panel de puntuación en tiempo real** en `go_board.gd`. Mostrar en la esquina superior derecha: "Piedras capturadas — Negro: X / Blanco: Y". Actualizar al recibir `StonesCapturedEvent`. Al terminar el juego (doble-pass), mostrar un panel de puntuación de territorio con un grid de color que indica qué área pertenece a cada jugador (calcular territory scoring en client-side usando flood-fill en GDScript).

---

**216.** Crear la **pantalla de lobby LAN** (`godot_project/host_lobby.gd`) funcional. Al llamar `bridge.start_hosting(port)`, mostrar el QR de la IP:puerto (usando `bridge.generate_qr_svg(ip, port)` si existe, o mostrar la IP en texto grande). Mostrar una lista de jugadores conectados que se actualiza al recibir la señal `player_joined(player_id)`. Un botón "Iniciar partida" se habilita solo cuando hay al menos 2 jugadores. Al presionar "Iniciar partida", llamar `bridge.start_game_from_lobby(game_type)` (a implementar en el bridge) y hacer transición a la escena del juego correspondiente.

---

**217.** Mejorar el **menú de configuración** (`godot_project/settings_menu.gd`). Añadir: (a) `OptionButton` para seleccionar idioma (Español/English/Deutsch/Français) que actualiza el locale del proyecto Godot en tiempo real, (b) `HSlider` para tamaño de fuente (pequeño/mediano/grande) que aplica a todos los `Label`s via `ThemeManager`, (c) checkboxes para habilitar/deshabilitar animaciones y efectos de sonido. Guardar las preferencias en `user://settings.cfg` con `ConfigFile`. Cargar automáticamente al iniciar en `GameManager._ready()`.

---

**218.** Implementar **localización completa** para los textos de UI. Actualizar los archivos CSV de traducción en `godot_project/translations/` (español e inglés ya existentes) añadiendo claves para: todos los nombres de los 12 juegos, los mensajes de error del bridge, los estados de fase de TEG ("Fase de refuerzo", "Fase de ataque", "Fase de fortificiación"), los mensajes del game over overlay, y los textos del menú principal. Añadir soporte en el CSV para Alemán, Francés, Italiano, Portugués, Chino simplificado, Japonés y Coreano. El `translation_loader.gd` debe cargar todos los CSVs al iniciar.

---

**219.** Añadir **indicador visual de jugadas obligatorias** en `checkers_board.gd`. Si el juego de damas tiene la regla de captura obligatoria (prompt 72 de PROMPTS2.md), detectar cuando el jugador intenta hacer un movimiento no-captura y hay capturas disponibles: mostrar un parpadeo rojo en las piezas que tienen capturas disponibles (usando `AnimationPlayer` con modulación de color). Añadir un `Label` de aviso "¡Captura obligatoria!" en la parte superior del tablero durante 2 segundos.

---

**220.** Implementar el **tablero visual de Battleship** (`godot_project/battleship_board.gd`) completo. Dos grids 8×8 (propio y del oponente) con casillas clickeables. En la fase de colocación, el jugador arrastra barcos (representados como `TextureRect` elongados) y los suelta en el grid propio. En la fase de ataque, al hacer click en el grid del oponente, enviar `ShootCommand`. Al recibir `ShotResultEvent` con `is_hit`, mostrar un ícono de explosión (rojo); con `!is_hit`, mostrar agua (azul). Al hundir un barco completo (`SunkenShipEvent`), resaltar todas las celdas del barco hundido en rojo más oscuro.

---

## 3. Correcciones de Reglas y Bugs

---

**221.** Corregir la **captura múltiple en Damas** en `checkers_game/src/rules.rs`. El prompt 6 de PROMPTS.md pedía cadenas de 3+ saltos, pero la implementación actual puede no detectar correctamente si el siguiente salto es obligatorio al terminar una captura. Añadir el test específico `test_cadena_de_tres_saltos_consecutivos` con un tablero donde hay tres fichas rivales alineadas en diagonal para saltar. Verificar que después del segundo salto el `current_player()` sigue siendo el mismo jugador (captura en cadena) y que solo cambia de turno tras agotar los saltos.

---

**222.** Corregir el **movimiento de la Torre en ajedrez** al verificar que no hay piezas entre origen y destino. Si la implementación actual en `chess_game/src/rules.rs` no verifica piezas interpuestas para la Torre (posible bug de implementación incompleta), añadir la verificación explícita en el handler de movimiento ortogonal. Añadir el test `test_torre_no_puede_saltar_sobre_piezas` que coloca una pieza propia entre la Torre y su destino y verifica `EngineError::InvalidCommand`.

---

**223.** Verificar y corregir la **regla de en passant** en `chess_game/src/rules.rs`. En passant debe ser posible solo en el turno inmediatamente siguiente al avance de peón de dos casillas. Si hay un `EnPassantTargetResource` almacenando la casilla objetivo, verificar que se limpia correctamente después de cualquier movimiento (no solo después de capturar en passant). Añadir el test `test_en_passant_no_disponible_un_turno_despues` que hace avanzar el peón rival dos casillas, pasa el turno (movimiento neutral), y verifica que el en passant ya no está disponible.

---

**224.** Corregir el **estado de fin de juego en Backgammon** cuando un jugador saca todas sus fichas. El evento `GameOverEvent` debe emitirse en el mismo `process_command` del último bearing-off. Verificar en `backgammon_game/src/rules.rs` que la verificación de victoria ocurre dentro del handler de `BearOffCommand` y no en un sistema separado que podría no ejecutarse. Añadir el test `test_sacar_ultima_ficha_emite_game_over_inmediatamente`.

---

**225.** Corregir la **validación de `PlaceShipCommand`** en `battleship_game/src/rules.rs`. Verificar que si un barco sale de los límites del tablero (fila+longitud > 8 o col+longitud > 8), se rechaza con `EngineError::InvalidCommand`. La implementación actual puede no validar este caso de borde. Añadir el test `test_barco_fuera_de_los_limites_es_rechazado` que intenta colocar un barco de 3 celdas desde la columna 6 horizontalmente (saldría en columnas 6,7,8 — inválido para tablero 0-7).

---

**226.** Corregir la **detección de fin de partida en UNO** cuando el mazo y el descarte se agotan simultáneamente. Si el mazo está vacío, el descarte tiene 1 carta, y un jugador debe robar, la remezcla es imposible. En este caso, el juego termina en empate (o continúa sin robo). Actualizar el handler de `DrawCardCommand` en `uno_game/src/rules.rs` para manejar este caso edge. Añadir el test `test_mazo_y_descarte_agotados_no_produce_panic`.

---

**227.** Corregir la **renta de grupo completo** en `crisis_game` (versión Monopoly legada, ahora eliminada). Este prompt se redirige: verificar en `monopoly_game/src/rules.rs` que cuando un jugador posee un grupo completo de propiedades del mismo color, la renta es el doble de la base. Si `owns_full_group` en `PlayersResource` existe (ya hay en la versión de crisis), verificar que `monopoly_game` tiene una función equivalente y que la aplica. Añadir el test `test_renta_doble_por_grupo_completo_en_monopoly`.

---

**228.** Corregir el **handler de `PassCommand` en Go** para que solo sea válido en el turno del jugador que emite el pass. Si `world.resource::<TurnResource>().0.is_current(cmd.player)` devuelve false, rechazar con `EngineError::InvalidCommand`. Verificar que esto ya está implementado; si no, añadirlo. Añadir el test `test_pasar_fuera_de_turno_es_rechazado`.

---

**229.** Corregir la **exportación de la librería en `crisis_game/src/lib.rs`** tras la reescritura TEG. Verificar que `cargo build -p crisis_game`, `cargo test -p crisis_game`, y `cargo check --workspace` pasan sin warnings de `dead_code` ni `unused_imports`. Eliminar todos los restos del código Monopoly (referencias a `Space::Company`, `GO_BONUS`, `STARTING_MONEY`, `PendingDecision`, `BuyCompanyCommand`). Añadir `#![deny(unused_imports)]` temporalmente para detectar imports huérfanos.

---

**230.** Corregir la **función `new_crisis_session`** en `open_table_godot/src/lib.rs` para que use el nuevo API TEG. La función actual llama `crisis_game::new_crisis_session(SessionId, seed, P1, P2)` con firma de 2 jugadores. La nueva versión TEG acepta 2–6 jugadores como `&[PlayerId]`. Actualizar la llamada en el bridge y en todos los tests que lo usan. Verificar que `cargo build -p open_table_godot` compila sin errores.

---

**231.** Añadir **validación de 3+ jugadores** en `ludo_game`. La sesión `new_ludo_session` debe funcionar con 2, 3, o 4 jugadores. Verificar que los 4 colores de inicio están correctamente asignados según el número de jugadores (2j: rojo y verde en esquinas opuestas; 3j: rojo, verde, azul en tres esquinas; 4j: todos). Añadir el test `test_ludo_con_tres_jugadores_cicla_correctamente` que inicia con P1, P2, P3 y verifica el orden de turnos.

---

**232.** Corregir el **cálculo de ejércitos al inicio del turno en TEG** (`crisis_game`). La fórmula estándar de TEG es: `max(3, floor(territories_owned / 3))` + bonuses de continente. Verificar que `EndPhaseCommand` en la transición Fortify→PlaceArmies calcula correctamente los bonus de continente llamando a `check_continent_bonus(map, player, &CONTINENTS)`. Añadir el test `test_bonus_de_continente_se_aplica_al_inicio_del_turno` que asigna todos los territorios de América del Sur a P1 (5 territorios) y verifica que P1 recibe +2 ejércitos extra además del cálculo base.

---

**233.** Corregir la **serialización de `TerritoryId` y `ContinentId`** en `crisis_game`. Definir `pub struct TerritoryId(pub u8)` y `pub struct ContinentId(pub u8)` con `#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]`. Verificar que los comandos y eventos que los contienen se serializan/deserializan correctamente con `serde_json`. Añadir el test `test_serializar_y_deserializar_declare_attack_command_roundtrip` que serializa un `DeclareAttackCommand` a JSON y lo deserializa, verificando que todos los campos son iguales.

---

**234.** Añadir **validación de jugador mínimo y máximo** en `new_crisis_session`. Si se llama con menos de 2 o más de 6 jugadores, retornar un `Result<Session, EngineError>` con `EngineError::InvalidCommand { reason: "TEG requiere entre 2 y 6 jugadores" }`. Actualizar la firma de `new_crisis_session` de `Session` a `Result<Session, EngineError>`. Actualizar el bridge y todos los tests para manejar el Result. Añadir el test `test_crisis_session_rechaza_mas_de_seis_jugadores`.

---

## 4. Nuevas Features — SDK y Juegos

---

**235.** Implementar **historial de movimientos en texto** para `open_table_engine`. Añadir `Session::move_history() -> Vec<String>` que retorna un Vec de strings legibles (ej. `"Tick 3 | Player 1 | MovePieceCommand: (2,1) -> (3,2)"`). Estos strings se generan convirtiendo el log de comandos a texto mediante una función `format_command(envelope: &CommandEnvelope) -> String` en un nuevo archivo `open_table_engine/src/history.rs`. Añadir el test `test_move_history_refleja_los_comandos_jugados`.

---

**236.** Añadir un **comando de rendición** (`ResignCommand`) a todos los juegos de 2 jugadores: ajedrez, damas, go, shogi, xiangqi, backgammon. Añadir `ResignCommand { player: PlayerId }` en cada crate de juego. El handler valida que es el turno del jugador (o que es un jugador de la partida) y emite `GameOverEvent { winner: Some(oponente) }`. Registrar el handler en el `build_*_rules()` de cada juego. Añadir un test en ajedrez `test_rendicion_termina_la_partida` y verificar que el patrón es reutilizable.

---

**237.** Implementar **observadores de estado** en `open_table_engine`. Añadir `Session::watch<R: Resource + Clone + 'static>(handler: impl Fn(&R) + Send + Sync + 'static)` que registra un closure invocado cada vez que `process_command` modifica el recurso `R`. Usar los `Change` detectores de `bevy_ecs` si están disponibles, o un hash del recurso antes/después. Añadir el test `test_watch_dispara_cuando_turn_resource_cambia` que registra un counter y verifica que se incrementa en cada cambio de turno.

---

**238.** Añadir la **señal `turn_changed(player_id: int)` al bridge** en `open_table_godot/src/lib.rs`. Después de cada `process_command` exitoso, si `session.current_player()` cambió respecto al valor anterior, emitir la señal `turn_changed` con el nuevo `player_id`. Añadir en todos los tests smoke de GDScript una verificación básica de que `turn_changed` se emite después de cada movimiento válido. Actualizar `turn_indicator.gd` para conectarse a esta señal en lugar de verificar `current_player()` en `_process`.

---

**239.** Implementar **modo de juego en solitario vs IA básica** para `checkers_game`. Añadir `start_local_match_checkers_vs_ai(seed: i64, human_player: int, ai_player: int) -> bool` al bridge. Cuando es el turno de `ai_player`, el bridge internamente llama a `checkers_ai_pick_move` (del prompt 18 de PROMPTS.md) y procesa el comando automáticamente. El human player recibe los eventos de la IA como si fueran de un jugador remoto. No exponer la IA en modo multiplayer.

---

**240.** Añadir **modo torneo básico** en el bridge Godot. Añadir `start_tournament(game_type: String, players: Array[int], rounds: int) -> bool`. El bridge gestiona una lista de partidas round-robin, emitiendo la señal `tournament_match_started(player1: int, player2: int, round: int)` al inicio de cada partida y `tournament_match_ended(winner: int, round: int)` al final. Al terminar todas las rondas, emitir `tournament_over(standings: Dictionary)`. Implementar con el pattern de `BridgeMode::Tournament` en `open_table_godot/src/lib.rs`.

---

**241.** Añadir **exportación de partida a PGN** para ajedrez. Crear `chess_game/src/pgn.rs` con `pub fn export_to_pgn(session: &Session) -> String` que convierte el log de movimientos al formato PGN estándar (encabezados `[Event]`, `[Date]`, movimientos en notación algebraica). Añadir el método `Session::export_chess_pgn() -> Option<String>` en `open_table_engine`. Añadir el test `test_exportar_partida_a_pgn_produce_formato_valido` que crea una partida de 4 movimientos y verifica que el PGN contiene las jugadas `1. e4 e5 2. Nf3 Nc6`.

---

**242.** Añadir **importación de FEN** para ajedrez. Crear `chess_game/src/fen.rs` con `pub fn from_fen(fen: &str) -> Result<BoardState, EngineError>`. Añadir `Session::load_chess_position_from_fen(fen: &str) -> Result<(), EngineError>` que inicializa el tablero desde una posición FEN arbitraria. Añadir el test `test_cargar_posicion_desde_fen_inicializa_tablero_correcto` con el FEN de la posición inicial estándar y uno de medio juego conocido. Exponer `bridge.load_chess_fen(fen: String) -> bool` en el bridge Godot.

---

**243.** Implementar **puntuación persistente entre partidas** en Godot. Crear `godot_project/score_tracker.gd` como Autoload que guarda en `user://scores.json` un diccionario `{ "player_name": { "game_type": { "wins": 0, "losses": 0 } } }`. Actualizar al recibir la señal `game_over(winner_id)` del bridge. Mostrar las estadísticas en `settings_menu.tscn` con un `TabContainer` que tiene una pestaña "Estadísticas" con un `Table` de victorias/derrotas por juego.

---

**244.** Implementar **replay viewer en Godot** usando el método `load_replay` y `step_replay` del bridge (ya implementados en el bridge). Crear `godot_project/replay_viewer.gd` con: botones "▶" (play automático a 1 movimiento/segundo), "⏸" (pausa), "⏭" (siguiente), "⏮" (anterior — reimplementar replaying desde 0 hasta tick-1). Mostrar un slider con la posición actual en el replay. Abrir el replay viewer desde `main_menu.gd` con un botón "Ver Replay" que abre un `FileDialog` para seleccionar un archivo `.otlog` (log exportado).

---

**245.** Añadir soporte de **múltiples partidas simultáneas** en el bridge Godot para modo torneo. Modificar `BridgeMode` para añadir la variante `MultiSession { sessions: Vec<(String, Session)>, active: usize }`. El bridge expone `switch_session(game_id: String)` para cambiar la sesión activa. Todas las señales llevan el `game_id` como primer parámetro adicional. Implementar el test en GDScript `tests/multi_session_smoke.gd` que arranca dos sesiones de damas simultáneas y verifica que los eventos de una no mezclan con la otra.

---

## 5. Tests y Calidad

---

**246.** Añadir **tests de integración completos para TEG/crisis**. Crear `crisis_game/tests/full_game.rs` con:
- `test_partida_teg_de_dos_jugadores_hasta_victoria_por_objetivo`: Simula una partida completa forzando con `resource_mut` que P1 controla casi un continente, luego lo completa con un ataque, y verifica `TegGameOverEvent`.
- `test_canje_de_tarjetas_da_ejercitos_extra`: Coloca 3 tarjetas del mismo tipo en la mano de P1 y verifica que `ExchangeCardsCommand` retorna `CardsExchangedEvent` con los ejércitos correctos.
- `test_eliminacion_de_jugador_con_tres_jugadores`: P3 pierde todos sus territorios y verifica que el turno cicla entre P1 y P2.

---

**247.** Añadir **proptest para crisis_game (TEG)**. Crear `crisis_game/tests/property.rs`. Añadir el test `ataque_con_dados_aleatorios_no_paniquea` que genera `(from_territory, to_territory, dice)` arbitrarios, intenta `DeclareAttackCommand` + `RollAttackCommand` en una sesión TEG con territorios adyacentes, y verifica que el resultado es `Ok` o `Err(EngineError::InvalidCommand)` — nunca panic. Añadir `proptest` a `crisis_game/Cargo.toml [dev-dependencies]`.

---

**248.** Añadir **tests de regresión para los tests que fallaban antes**. Crear `open_table_engine/tests/regression.rs` con un test por cada bug conocido que fue corregido: (a) `test_regresion_checkers_captura_multiple_mantiene_turno` (del prompt 6), (b) `test_regresion_backgammon_bearing_off_dado_mayor` (del prompt 14), (c) `test_regresion_uno_wild_draw_four_invalido_con_carta_del_color` (del prompt 12). Estos tests aseguran que los bugs no regresan en futuras refactorizaciones.

---

**249.** Añadir **tests de contrato de serialización** para todos los comandos y eventos. Crear `open_table_engine/tests/serialization_contract.rs`. Para cada uno de los 12 juegos, verificar que: (a) todos los comandos se serializan a JSON sin panic con `serde_json::to_string`, (b) el JSON resultante se deserializa de vuelta al tipo original sin error, (c) el tipo deserializado es igual al original (implementando `PartialEq` donde falte). Usar un helper `assert_roundtrip<T: Serialize + DeserializeOwned + PartialEq + Debug>(value: T)`.

---

**250.** Añadir **tests de estrés del motor TEG**. Crear `crisis_game/tests/stress.rs` con `#[ignore]` (no corre en CI por defecto). El test crea 1000 sesiones TEG con seeds distintas, procesa 50 comandos aleatorios en cada una (mezclando PlaceArmies, DeclareAttack, RollAttack, EndPhase, Fortify), y verifica que nunca se produce un panic. Medir el tiempo total y reportarlo con `println!`. Añadir el target `test-stress` al Makefile que corre los tests de estrés de todos los juegos.

---

**251.** Añadir **test de compatibilidad de versión de log** en `open_table_engine`. Guardar en `open_table_engine/tests/fixtures/` un archivo `checkers_v1.json` con un log de 5 movimientos generado con la versión actual. En `open_table_engine/tests/log_compatibility.rs`, cargar ese fixture y llamar `Session::replay` — el test verifica que el replay produce el mismo `current_tick()` y `current_player()` que se esperan. Si el formato del log cambia, el test falla como alerta de breaking change.

---

**252.** Añadir **test de fuzzing para TEG**. Crear `fuzz/fuzz_targets/fuzz_crisis.rs`. El target deserializa bytes arbitrarios como un `DeclareAttackCommand` (via `serde_json::from_slice`) y lo procesa en una sesión TEG iniciada con `new_crisis_session(...)`. Never panics — solo `Ok` o `Err`. Actualizar `fuzz/Cargo.toml` con la dependencia y documentar cómo correr con `cargo fuzz run fuzz_crisis`.

---

**253.** Añadir **cobertura de rama para TEG** en CI. Tras implementar el juego TEG completo, verificar con `cargo llvm-cov --package crisis_game` que la cobertura de rama es ≥ 60%. Identificar las ramas no cubiertas (típicamente: paths de error por territorios no adyacentes, fase incorrecta, jugador eliminado). Añadir tests mínimos para llevar la cobertura al umbral. Documentar el porcentaje de cobertura en `NEXT_STEPS.md` para el crate `crisis_game`.

---

**254.** Añadir **test de rendimiento del bridge Godot** en modo headless. Crear `godot_project/tests/performance_smoke.gd` que: instancia el bridge, arranca una sesión de damas, y envía 1000 movimientos alternativos válidos/inválidos midiendo el tiempo total con `Time.get_ticks_msec()`. Reportar "X comandos/segundo". El test falla si el throughput es menor a 500 cmd/s (indicando una regresión severa). Ejecutar solo cuando la variable de entorno `RUN_PERF_TESTS=1` está definida.

---

**255.** Crear `open_table_engine/tests/godot_api_surface.rs` — **test de API surface del bridge**. Verificar que los métodos que el bridge GDScript expone existen en el lado Rust y tienen las firmas correctas. Usar `std::any::type_name::<F>()` o reflexión mínima para verificar que `start_local_match`, `send_command_json`, `current_player`, `export_log`, `load_replay`, `step_replay`, `start_hosting`, `connect_to_host` están compilados en `open_table_godot`. Esto es un test de compilación (si compila, pasa).

---

## 6. DevOps, Build y Documentación

---

**256.** Actualizar `.github/workflows/ci.yml` para **incluir el paso de compilación del bridge Godot**. Añadir un step que instala `libclang-dev` (dependencia de `gdext`), compila `cargo build -p open_table_godot`, y verifica que el `.so` se produce. Este step no corre los tests headless (requiere Redot instalado) pero verifica que el código compila. Añadir el step en un job separado `build-godot-bridge` para no bloquear el job principal de tests de Rust.

---

**257.** Añadir **matrix CI** para múltiples versiones de Rust. En `ci.yml`, configurar `strategy.matrix.rust: [stable, beta]` para el job de tests. Añadir el flag `continue-on-error: true` para el canal `beta` (solo informativo). Verificar que el canal `stable` es el que bloquea el merge. Actualizar `rust-toolchain.toml` para especificar la versión mínima soportada (MSRV) y añadir el step `cargo check --manifest-path Cargo.toml --rust-version <MSRV>` al CI.

---

**258.** Crear el **script de release** `tools/release.sh`. El script: (1) verifica que no hay cambios uncommitted (`git status --porcelain`), (2) ejecuta `tools/bump_version.sh --patch`, (3) ejecuta `cargo test --workspace --exclude open_table_godot`, (4) crea un tag Git `v{nueva_version}` con `git tag -a`, (5) imprime las instrucciones para publicar en crates.io (`cargo publish -p open_table_core`). El script nunca hace push ni publica automáticamente. Documentar en `CONTRIBUTING.md`.

---

**259.** Añadir **Dependabot** para actualizaciones automáticas de dependencias. Crear `.github/dependabot.yml` con: (a) updates de cargo (`package-ecosystem: cargo`) semanales los lunes, (b) updates de GitHub Actions (`package-ecosystem: github-actions`) semanales. Configurar `assignees` y `reviewers` con el usuario `joduranvillan`. Añadir una sección en `CONTRIBUTING.md` explicando cómo revisar y aprobar PRs de Dependabot.

---

**260.** Actualizar `NEXT_STEPS.md` con el **estado actual del proyecto**. Secciones: (1) Juegos implementados (checklist con ✅/⚠️/❌ por cada regla), (2) crisis_game reescrito como TEG — estado de implementación, (3) Tests de Godot headless — estado de cada script, (4) Próximas prioridades (en orden: completar reglas Shogi, tests headless, UI móvil), (5) Deuda técnica conocida (lista de TODOs en código marcados con `// TODO:`). Limitar el documento a 200 líneas para que sea útil.

---

**261.** Crear `docs/games/teg.md` — **documentación del juego Crisis (TEG)**. Documentar: (1) Descripción de TEG y diferencias con Risk estándar, (2) Mapa de 30 territorios con la lista completa y sus continentes, (3) Tabla de adyacencias, (4) Fases de turno y comandos disponibles en cada fase, (5) Tipos de objetivos secretos, (6) Sistema de tarjetas y canje, (7) API de comandos y eventos del crate `crisis_game` con ejemplos JSON, (8) Simplificaciones aplicadas respecto a TEG real (sin guerras nucleares, sin cartas especiales de TEG 2). Enlazar desde `README.md`.

---

**262.** Crear `docs/games/` con archivos para los **12 juegos** actualizados. Cada archivo debe contener: resumen de reglas implementadas, tabla de comandos con su JSON de ejemplo, tabla de eventos con sus campos, simplificaciones respecto al juego real, y un ejemplo de partida mínima (inicio + 3 movimientos + fin). Priorizar los juegos más completos (ajedrez, damas, go) para la primera iteración. El archivo `teg.md` (prompt 261) cuenta como el primero.

---

**263.** Añadir **badges de estado en `README.md`**. Añadir los badges de: CI (GitHub Actions), cobertura de código (Codecov), versión en crates.io (`open_table_core`), licencia (MIT/Apache-2.0), y un badge de "juegos implementados" mostrando "12/12". Añadir una tabla de estado de juegos actualizada con columnas: Juego | Reglas básicas | Reglas completas | Tests Rust | Test Godot | UI Godot. Completar con ✅/⚠️/❌ según el estado real.

---

**264.** Crear el **template de issue** en `.github/ISSUE_TEMPLATE/`. Añadir dos templates: `bug_report.md` (campos: juego afectado, comando/evento con problema, comportamiento esperado vs actual, log de error) y `feature_request.md` (campos: descripción de la feature, juego afectado, prompts relacionados). Añadir también `.github/PULL_REQUEST_TEMPLATE.md` con checklist: `[ ] cargo test --workspace`, `[ ] cargo clippy`, `[ ] Tests de Godot headless`, `[ ] Documentación actualizada`.

---

## 7. SDK — Mejoras Avanzadas

---

**265.** Implementar **CommandMiddleware** en `open_table_engine`. Añadir `Session::add_middleware(mw: impl Fn(&CommandEnvelope, &mut World) -> Result<(), EngineError> + Send + Sync + 'static)` que ejecuta el middleware antes de despachar el comando al `RuleEngine`. Útil para logging, validación global (ej. rate limiting del prompt 101), o auditoría. Los middlewares se aplican en orden de registro. Añadir el test `test_middleware_puede_rechazar_comandos_antes_del_despacho`.

---

**266.** Implementar **modo de observación parcial** (información imperfecta). Añadir `Visibility::PrivateToGroup(Vec<PlayerId>)` en `open_table_core/src/visibility.rs`. Los eventos con esta visibilidad llegan solo a los jugadores en el grupo. Útil para UNO (las cartas de mano solo son visibles para el dueño), Battleship (la posición de la flota propia), y TEG (el objetivo secreto). Actualizar `filter_events_for_player` para manejar la nueva variante. Añadir el test `test_private_to_group_llega_solo_a_los_jugadores_del_grupo`.

---

**267.** Añadir **soporte de WebSocket** como transporte alternativo. Crear el crate `open_table_transport_websocket/` con estructura equivalente a `open_table_transport_tcp/` pero usando `tokio-tungstenite`. Implementar `WsHostTransport` y `WsClientTransport` con las mismas interfaces de `send_command` y `poll_events`. Añadir el test `open_table_transport_websocket/tests/end_to_end.rs` equivalente al de TCP. Documentar en `ARCHITECTURE.md` como tercer transporte disponible.

---

**268.** Implementar **compresión de log** en `Session::export_log`. Añadir `Session::export_log_compressed() -> Vec<u8>` que comprime el JSON del log con `flate2` (gzip). Añadir `Session::replay_from_compressed(bytes: &[u8]) -> Result<(), EngineError>` que descomprime antes de hacer replay. El tamaño comprimido debe ser al menos 50% menor para logs de 100+ movimientos. Añadir el test `test_export_log_comprimido_es_menor_que_el_original` y `test_replay_desde_log_comprimido_produce_estado_correcto`.

---

**269.** Añadir **validación de integridad del log** con firma HMAC. Añadir `Session::export_log_signed(secret: &[u8]) -> Vec<u8>` que calcula un HMAC-SHA256 del JSON y lo añade al final. Añadir `Session::verify_log(bytes: &[u8], secret: &[u8]) -> Result<(), EngineError>` que verifica la firma antes de reproducir. Útil para detectar logs manipulados en torneos. Añadir los tests de firma válida e inválida. Usar la crate `hmac` + `sha2` (ya en el ecosistema `ring` o `rustls`).

---

**270.** Implementar **hot-reload de juegos** en el engine. Añadir `Session::swap_rule_engine(new_rules: RuleEngine) -> Result<(), EngineError>` que reemplaza el `RuleEngine` activo sin perder el estado del mundo. Útil para actualizar las reglas en tiempo de ejecución (ej. cuando se lanza una corrección de bug en modo de juego en vivo). El swap solo es válido si la sesión está pausada (`SessionMode::Paused`). Añadir el test `test_hot_reload_de_reglas_preserva_el_estado_del_mundo`.

---

## 8. Mobile — Completar Features

---

**271.** Implementar **persistencia local de partidas** en Godot para Android/iOS. Añadir `bridge.save_game(filename: String) -> bool` y `bridge.load_game(filename: String) -> bool` que usan `Session::save_to_file` / `Session::load_from_file` (prompt 20 de PROMPTS.md). En Godot, usar `OS.get_user_data_dir()` para obtener la ruta de guardado. Añadir en `settings_menu.tscn` botones "Guardar partida" y "Cargar partida". Verificar que los archivos guardados sobreviven al cierre de la app.

---

**272.** Implementar **notificaciones push locales** en Godot para modo multiplayer por turnos. Cuando es el turno del jugador y la app está en background (modo timer-based multiplayer), usar el plugin de notificaciones nativo (Android: `notification_scheduler` GDNative plugin; iOS: `UNUserNotificationCenter` via plugin). Añadir `godot_project/notification_manager.gd` con `schedule_turn_reminder(player_name: String, delay_seconds: int)`. Documentar qué plugin de terceros usar para cada plataforma.

---

**273.** Mejorar el **rendimiento de serialización** del bridge para dispositivos móviles de gama baja. Perfilar `Session::process_command` + serialización JSON en un benchmark de 1000 comandos. Si la serialización supera el 30% del tiempo total, considerar usar `bincode` en lugar de `serde_json` para la comunicación interna bridge↔Godot (convertir a JSON solo para los eventos GDScript). Documentar el trade-off en `docs/performance/profiling.md`.

---

**274.** Implementar **reducción de tamaño del binary** para el build de Android. Añadir en `crisis_game/Cargo.toml` (y los demás juegos) el perfil de release con `opt-level = "z"` y `codegen-units = 1`. Añadir `strip = true` en el perfil release del workspace `Cargo.toml`. Medir el tamaño de `libopen_table_godot.so` antes y después. Documentar el tamaño resultante (target: < 5MB). Añadir el target `build-android` al Makefile con la toolchain de cross-compilación ARM.

---

**275.** Crear la **guía de integración para iOS** en `platform_plugins/ios/README.md`. Documentar paso a paso: (1) compilar el crate como `cdylib` para `aarch64-apple-ios` con `cargo build --target aarch64-apple-ios -p open_table_godot`, (2) copiar el `.dylib` al XCode project generado por Redot, (3) configurar el `gdextension` con la ruta correcta para iOS, (4) verificar que el bridge funciona en el simulador, (5) firmar la app con los entitlements necesarios para MultipeerConnectivity. Incluir el comando exacto de exportación de Redot para iOS.

---

## 9. Adicionales y Pulido Final

---

**276.** Implementar el **tutorial interactivo** de TEG en Godot. Crear `godot_project/crisis_tutorial.gd` con una secuencia guiada paso a paso: (1) "Haz click en un territorio tuyo para ver tus ejércitos", (2) "Coloca 3 ejércitos en Argentina", (3) "Declara un ataque sobre Chile", (4) "Tira los dados", (5) "Fin de fase". Usar `CanvasLayer` con flechas animadas y burbujas de diálogo para guiar al usuario. Al terminar el tutorial, transicionar a una partida completa contra la IA.

---

**277.** Implementar el **modo de demostración (attract mode)** en el menú principal. Si el usuario no hace nada durante 30 segundos, iniciar una demo de una partida de damas entre dos IAs (usando `checkers_ai_pick_move` del prompt 18). La demo corre visible en el fondo de `main.tscn` sin interfaz interactiva. Al hacer click en cualquier parte, volver al menú. Usar `SceneTree.process_mode = PROCESS_MODE_PAUSED` para que la demo no interfiera con el input del menú.

---

**278.** Añadir **animaciones de dados** en los juegos que los usan (Backgammon, Ludo, Crisis TEG). Crear `godot_project/dice_widget.gd` con un panel que muestra 1-3 dados con animación de "rolling" (TextureRect que cicla entre las 6 caras a 30fps durante 0.5s antes de mostrar el resultado final). El `dice_widget` se instancia programáticamente en los tableros que necesitan dados. Exponer `show_roll(values: Array[int])` que dispara la animación y emite la señal `animation_done` al terminar.

---

**279.** Implementar **recordatorio de reglas in-game**. Añadir un botón "?" en cada tablero que abre un `PopupPanel` con un resumen de las reglas del juego actual (cargado desde los archivos `docs/games/*.md` embebidos como strings en el proyecto Godot). Para TEG, mostrar las fases del turno, la fórmula de combate (mayor dado gana), y los tipos de objetivos. El popup es scrollable y tiene búsqueda de texto simple.

---

**280.** Crear el **bot de Discord para anuncios de partidas LAN**. Crear `tools/discord_bot/` con un bot Python mínimo (`discord.py`) que escucha el webhook de eventos de `open_table_qr`. Cuando el host genera un QR de partida, el bot publica en un canal de Discord el link de unión y la IP:puerto. Documentar la configuración del bot token y el webhook URL en `tools/discord_bot/README.md`. Este es un componente opcional de la stack de devtools, no parte del SDK principal.

---

**281.** Añadir **tests de snapshot visual** para las UI de Godot. Crear `godot_project/tests/visual_regression.gd` que, en modo headless con Redot, renderiza cada tablero vacío (sin partida activa) y guarda el screenshot como PNG en `godot_project/tests/snapshots/`. Al correr en CI, comparar los screenshots actuales con los de referencia (guardados en el repo) usando un diff de píxeles con tolerancia del 1%. Si el diff supera la tolerancia, marcar el test como FAIL. Documentar cómo actualizar los snapshots de referencia con `UPDATE_SNAPSHOTS=1 make test-godot`.

---

**282.** Implementar **log de errores en Godot** para facilitar el debugging. Crear `godot_project/error_logger.gd` como Autoload que captura todos los `push_error()` y `push_warning()` de Godot y los escribe en `user://error.log` con timestamp. En modo debug, también mostrar los errores en un `RichTextLabel` overlay semi-transparente en la esquina inferior de la pantalla (toggleable con F12). El bridge Rust debe mapear sus errores de `EngineError` a `push_error()` en Godot para que aparezcan en el log.

---

**283.** Crear `godot_project/tests/mille_bornes_smoke.gd` — **test headless de Mille Bornes**. Instanciar `OpenTableBridge`. Llamar `bridge.start_local_match_mille_bornes(seed, 1, 2)`. Verificar: (a) el juego arranca, (b) `DrawCardCommand` (si existe) o el método de robo inicial funciona, (c) un `PlayDistanceCommand` con una carta de distancia válida pasa sin error. Dado que las cartas iniciales son aleatorias, usar seed hasta encontrar una partida con carta de 25 en mano de P1. Confirmar exit code 0 headless.

---

**284.** Crear `godot_project/tests/chinese_checkers_smoke.gd` — **test headless de Damas Chinas**. Instanciar `OpenTableBridge`. Llamar `bridge.start_local_match_chinese_checkers(seed, [1, 2])` con 2 jugadores. Verificar: (a) `current_player() == 1`, (b) un movimiento simple válido de una ficha en la posición inicial emite el evento de movimiento, (c) un movimiento inválido (a posición ocupada) emite `move_rejected`. Las posiciones iniciales del tablero hexagonal están definidas en `chinese_checkers_game/src/board.rs`. Confirmar exit code 0 headless.

---

**285.** Crear `godot_project/tests/monopoly_smoke.gd` — **test headless de Monopoly**. Instanciar `OpenTableBridge`. Llamar `bridge.start_local_match_monopoly(seed, 1, 2)`. Verificar: (a) `current_player() == 1`, (b) `RollAndMoveCommand` emite `PlayerMovedEvent` con `roll` entre 2 y 12, (c) si el jugador cae en una propiedad libre, llega un evento de decisión de compra. Adaptar el JSON del comando al formato del bridge. Confirmar exit code 0 headless.

---

**286.** Crear `godot_project/tests/battleship_smoke.gd` — **test headless de Battleship**. Instanciar `OpenTableBridge`. Llamar `bridge.start_local_match_battleship(seed, 1, 2)`. La fase inicial es de colocación de flota. Verificar: (a) `PlaceShipCommand` para el portaaviones (largo 5) en posición válida funciona, (b) `PlaceShipCommand` con barco fuera de límites es rechazado. No intentar la fase de disparo en este smoke test (requiere que ambos jugadores coloquen sus flotas). Confirmar exit code 0 headless.

---

**287.** Añadir el **smoke test de Monopoly al runner unificado** y actualizar `tools/run_godot_tests.sh` con todos los nuevos tests (crisis TEG, mille_bornes, chinese_checkers, monopoly, battleship) para un total de 14+ scripts en la suite. Actualizar el tiempo estimado de ejecución en `godot_project/README.md`. Verificar que la suite completa termina en menos de 5 minutos en hardware de desarrollo estándar (i7, 16GB RAM).

---

**288.** Implementar **métricas de calidad del código** automatizadas. Crear `tools/metrics.sh` que: (a) corre `cargo clippy --workspace 2>&1 | grep "warning:" | wc -l` y falla si hay más de 0 warnings, (b) corre `cargo fmt --check --all` para verificar formato, (c) corre `cargo doc --workspace --no-deps 2>&1 | grep "warning:" | wc -l` y falla si hay warnings de documentación, (d) reporta el número de `// TODO:` en el código fuente. Añadir el target `metrics` al Makefile. Añadir el step al CI.

---

**289.** Actualizar el **CHANGELOG.md** con el formato Keep a Changelog. Añadir la sección `[Unreleased]` con subsecciones `Added`, `Changed`, `Fixed`, `Removed`. Documentar los cambios del crisis game (reescritura de Monopoly a TEG), la corrección de tests headless, y las mejoras de UI. Añadir el script `tools/generate_changelog.sh` que extrae los commits desde el último tag y los categoriza por prefijo (`feat:`, `fix:`, `docs:`, etc.) para facilitar la actualización del CHANGELOG en cada release.

---

**290.** Implementar **validación de consistencia del workspace** en CI. Crear `tools/verify_workspace.sh` que: (a) verifica que todos los crates en `Cargo.toml [workspace.members]` tienen su directorio correspondiente, (b) verifica que todos los juegos exportan `new_{game}_session` y están referenciados en `open_table_godot/src/lib.rs`, (c) verifica que cada juego tiene su archivo `tests/game_rules.rs`, (d) verifica que el `NEXT_STEPS.md` menciona todos los juegos. Añadir al CI como último step.

---

**291.** Crear `docs/adr/` — **Architecture Decision Records**. Añadir tres ADRs iniciales: `ADR-001-bevy-ecs-como-motor-de-estado.md` (por qué bevy_ecs para el estado de juego), `ADR-002-gdext-para-godot-bridge.md` (por qué gdext en lugar de GDNative), `ADR-003-teg-en-lugar-de-monopoly-para-crisis.md` (registro de la decisión de reescribir crisis_game). Cada ADR tiene: Contexto, Decisión, Consecuencias positivas, Consecuencias negativas. Enlazar desde `ARCHITECTURE.md`.

---

**292.** Implementar **sistema de logros** en Godot. Crear `godot_project/achievement_manager.gd` Autoload con un diccionario de logros: "Primera victoria en damas", "Gané en Jaque Mate", "Conquisté Europa en TEG", etc. Guardar en `user://achievements.json`. Mostrar un popup de notificación de logro en la esquina superior derecha con animación slide-in/out de 2 segundos. Conectar a las señales `game_over` y a eventos específicos del bridge para detectar las condiciones de cada logro.

---

**293.** Crear `godot_project/tests/achievements_smoke.gd` — **test headless de logros**. Verificar que el sistema de logros (prompt 292) no produce errores al cargar en modo headless. Simular manualmente la condición de un logro simple (primera victoria) llamando `AchievementManager.unlock("primera_victoria")` directamente y verificando que el logro aparece en el JSON de save. Confirmar exit code 0.

---

**294.** Añadir **soporte de múltiples idiomas** para los nombres de territorios TEG. Crear `crisis_game/src/i18n.rs` con un mapa `HashMap<&'static str, HashMap<&'static str, &'static str>>` donde la clave exterior es el `TerritoryId` como string y el valor es un mapa `{ "es": "Argentina", "en": "Argentina", "fr": "Argentine", ... }`. Exponer `pub fn territory_name(id: TerritoryId, lang: &str) -> &'static str`. Usar en `docs/games/teg.md` para mostrar los nombres en múltiples idiomas.

---

**295.** Crear el **mapa visual de TEG en SVG** en `godot_project/assets/crisis/world_map.svg`. El SVG debe tener 30 regiones `<path>` con `id="territory_0"` a `id="territory_29"`, coloreadas con un color por continente. Los path no necesitan ser geográficamente precisos — pueden ser polígonos estilizados con nombres escritos. Usar este SVG como textura base en `crisis_board.gd` (cargado como imagen rasterizada). Añadir los centros de cada territorio en `crisis_game/src/board.rs` como `pub const TERRITORY_CENTERS: &[(f32, f32)]` para posicionar los labels de ejércitos en la UI.

---

**296.** Implementar **undo/redo** en el modo single-player de Godot. Cuando `bridge.undo_last_command()` (prompt 105 de PROMPTS2.md) existe en el bridge, añadir un botón "⟵ Deshacer" en los tableros de juego local. El botón llama `bridge.undo()` y escucha los eventos re-emitidos para actualizar la UI. Añadir también un botón "Rehacer" que guarda los comandos deshecha y los vuelve a aplicar. Mostrar ambos botones deshabilitados en modo multiplayer.

---

**297.** Crear `godot_project/tests/replay_viewer_smoke.gd` — **test del replay viewer**. Arrancar una partida de damas, hacer 3 movimientos, exportar el log, cargarlo en `ReplayViewer`, verificar que `step_replay()` emite exactamente 3 eventos de movimiento. Verificar que `step_replay()` retorna `false` al final del replay. Confirmar exit code 0 headless.

---

**298.** Añadir **soporte de observers en Godot**. Cuando el bridge emite `event_json`, además de despacharlo a las señales tipadas, guardarlo en un buffer `recent_events: Array[Dictionary]` (últimos 100 eventos). Exponer `bridge.get_recent_events() -> Array[Dictionary]`. Útil para que la UI de replay viewer pueda navegar hacia atrás sin pedir un replay completo. Añadir el test `test_get_recent_events_retorna_eventos_en_orden`.

---

**299.** Implementar **modo de práctica de aperturas** para ajedrez en Godot. Crear `godot_project/chess_openings.gd` con un diccionario de aperturas clásicas en notación PGN simplificada: "e4 e5 Nf3 Nc6 Bb5" (Ruy López), "d4 d5 c4" (Gambito de Dama), etc. El modo de práctica arranca una sesión de ajedrez y, en cada turno, resalta el movimiento esperado de la apertura seleccionada. Si el jugador hace el movimiento correcto, avanza al siguiente. Si se desvía, sale del modo de apertura y continúa en partida libre.

---

**300.** Crear el **meta-prompt de mantenimiento** en `tools/maintenance_prompts.md`. Un conjunto de 10 prompts reutilizables para tareas de mantenimiento recurrente: (1) "Correr todos los tests y reportar fallos", (2) "Actualizar dependencias a las últimas versiones compatibles", (3) "Verificar que todos los juegos compilan sin warnings", (4) "Regenerar la documentación rustdoc", (5) "Actualizar el CHANGELOG con los commits recientes", (6) "Verificar que los tests de Godot headless pasan", (7) "Correr el análisis de cobertura de código", (8) "Verificar que no hay advisories de seguridad en cargo-deny", (9) "Actualizar los snapshots visuales de tests de UI", (10) "Verificar que la suite de proptest no encontró nuevos fallos". Incluir el comando exacto para cada tarea.

---

*Fin de PROMPTS3.md — 140 prompts (161–300), más el bloque de crisis TEG (161–178 = 18 prompts en el cuerpo de la Sección 0).*

*Resumen por sección:*
- *0. Crisis Game (TEG rewrite): prompts 161–178 (18 prompts)*
- *1. Godot/Redot tests headless: prompts 179–198 (20 prompts)*
- *2. Diseño Visual: prompts 199–220 (22 prompts)*
- *3. Correcciones de Reglas: prompts 221–234 (14 prompts)*
- *4. Nuevas Features: prompts 235–245 (11 prompts)*
- *5. Tests y Calidad: prompts 246–255 (10 prompts)*
- *6. DevOps y Docs: prompts 256–264 (9 prompts)*
- *7. SDK Avanzado: prompts 265–270 (6 prompts)*
- *8. Mobile: prompts 271–275 (5 prompts)*
- *9. Pulido Final: prompts 276–300 (25 prompts)*

*Total: 140 prompts nuevos (161–300). Con PROMPTS.md (1–40) y PROMPTS2.md (41–160): 300 prompts acumulados en el proyecto.*
