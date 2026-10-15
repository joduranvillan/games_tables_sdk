# Prompts de Reglas Canónicas Completas y Cableado UI (13 Juegos) — Games Tables SDK (Parte 13)

Continúa desde `PROMPTS12.md` (prompts 469–495). Numerados del **496 al 520**.

**Prerequisito:** `PROMPTS12.md` completado (`v3.0.0`) → todos los smoke tests de Rust y Godot/Redot en verde (`tools/run_godot_tests.sh` y `cargo test --workspace`).

**Objetivo:** Completar el **100% de las reglas canónicas oficiales** que aún faltan en los motores Rust o en el cableado de las escenas de Godot (`*_board.gd`) para los **13 juegos del catálogo**, **sin romper el motor (`open_table_core` / `open_table_engine`), ni el bridge (`open_table_godot`), ni un solo test existente**.

---

## 0. Auditoría de Estado Real de Reglas (Código Fuente vs `README.md` Histórico)

Tras auditar los 13 crates de juego (`*_game/src/`), sus suites de tests (`*_game/tests/game_rules.rs`), el bridge `open_table_godot/src/lib.rs` y los 13 scripts de tablero en `godot_project/*_board.gd`, se comprobó que **la gran mayoría de las reglas marcadas antiguamente con `⚠️` en `README.md` ya fueron implementadas en Rust**, pero **persisten brechas puntuales de reglamento oficial y comandos del motor que aún no están expuestos en la UI de Godot**:

| # | Juego (`crate`) | Ya Implementado en Motor Rust (No Duplicar) | Faltante Real para Reglas 100% Completas (Cubierto en `PROMPTS13.md`) |
|---|---|---|---|
| 1 | **Ajedrez** (`chess_game`) | Enroque corto/largo, captura al paso (`en_passant_target`), coronación a `Queen`/`Rook`/`Bishop`/`Knight`, jaque/mate/ahogado, regla de 50 movimientos (`HalfMoveClockResource`), triple repetición Zobrist (`PositionHistoryResource`), material insuficiente, `OfferDrawCommand`, `AcceptDrawCommand`, `ResignCommand`. | **UI Godot (`chess_board.gd`)**: selector modal de pieza al coronar (hoy envía siempre Dama) y controles en tablero para `OfferDrawCommand` / `AcceptDrawCommand`. |
| 2 | **Damas** (`checkers_game`) | Captura obligatoria (`has_any_capture`), saltos múltiples encadenados en el mismo turno (`MultiCaptureResource.active_piece`), coronación a Dama (`is_king`) con movimiento/captura en las 4 diagonales, `CheckersLegalMoveGenerator`, `ResignCommand`. | **Motor Rust + UI**: victoria inmediata cuando el rival al inicio de su turno tiene fichas pero **0 movimientos legales (bloqueo total)**; regla de tablas por 40 turnos sin captura ni coronación (`DrawClockResource`); resaltado de ficha obligatoria en multicaptura en `checkers_board.gd`. |
| 3 | **Go** (`go_game`) | Tablero `9×9`/`13×13`/`19×19`, captura por libertades, prohibición de suicidio, Ko simple (`ko_point`), Superko posicional (`BoardHistoryResource`), Handicap (`PlaceHandicapCommand`), doble pase (`PassCommand`) y fase de marcado/confirmación de piedras muertas (`MarkDeadCommand`, `ConfirmDeadCommand`). | **Motor Rust + UI (`go_board.gd`)**: contabilizar **prisioneros capturados** y **Komi (`6.5`)** en la puntuación final al confirmar piedras muertas; implementar `GoLegalMoveGenerator`; cablear en `go_board.gd` los botones de `PassCommand`, fase visual de `MarkDeadCommand` / `ConfirmDeadCommand` y selector de Handicap. |
| 4 | **Shogi** (`shogi_game`) | Tablero `9×9`, reserva de capturas (`hands`) con despromoción, `DropPieceCommand`, **Nifu** (dos peones en la misma columna), **Uchifuzume** (prohibido dar mate por drop de peón), prohibición de drop en filas sin jugada futura, promoción de piezas. | **Motor Rust + UI (`shogi_board.gd`)**: regla de **Sennichite** (tablas por cuádruple repetición de posición + manos + turno, o derrota por jaque perpetuo); modo configurable de promoción opcional vs obligatoria por fila (`ShogiRulesConfigResource`); `ShogiLegalMoveGenerator`; diálogo de "¿Promocionar pieza?" en `shogi_board.gd`. |
| 5 | **Xiangqi** (`xiangqi_game`) | Tablero `9×10`, Río, Palacios, **General Volador (`check_flying_general`)**, bloqueo de ojo de Elefante, bloqueo de pata de Caballo, plataforma exacta del Cañón, avance lateral del Soldado tras cruzar el río, detección de jaque y mate. | **Motor Rust**: en reglamento oficial de Xiangqi, **el ahogado (*Kunbi* / 困毙 — quedarse sin jugadas legales sin estar en jaque) es derrota para el jugador bloqueado**; registrar `XiangqiLegalMoveGenerator` en `RuleEngine`; detección de repetición triple. |
| 6 | **Damas Chinas** (`chinese_checkers_game`) | Estrella oficial de 6 puntas con **121 casillas** (`BOARD_RADIUS = 4` + 6 puntas de 10 casillas), soporte para 2, 3, 4 y 6 jugadores, paso adyacente y saltos múltiples encadenados (`MovePegCommand.path`). | **Motor Rust + UI**: regla oficial **Anti-Bloqueo en punta de meta (*Home-Camp Spoiling Rule*)**: victoria si las 10 casillas destino están ocupadas y al menos una es propia; `ResignCommand`; `ChineseCheckersLegalMoveGenerator`; previsualización y envío de cadenas de salto multi-paso (`path`) en `chinese_checkers_board.gd`. |
| 7 | **Backgammon** (`backgammon_game`) | 24 puntos, barra, **dobles = 4 movimientos**, **Doubling Cube** (`OfferDoubleCommand`, `AcceptDoubleCommand`, `RejectDoubleCommand`), regla **Crawford** (`crawford_game`), bear-off con regla exacta de fichas más atrás (`has_checkers_behind_die_exit`), Gammon (`2×`) y Backgammon (`3×`). | **Motor Rust + UI (`backgammon_board.gd`)**: regla oficial de **obligación de usar ambos dados si existe línea legal (o el dado mayor si solo se puede jugar uno)**; `BackgammonLegalMoveGenerator`; cablear en `backgammon_board.gd` los botones de `OfferDoubleCommand`, `AcceptDoubleCommand` y `RejectDoubleCommand`. |
| 8 | **Batalla Naval** (`battleship_game`) | Tablero **10×10**, flota estándar de **5 barcos** (`[5, 4, 3, 3, 2]`), prohibición de barcos adyacentes incluso en diagonal (`are_adjacent`), niebla de guerra estricta, `SunkenShipEvent` y `RematchCommand`. | **Motor Rust + UI (`battleship_board.gd`)**: recurso opcional `BattleshipConfigResource { extra_turn_on_hit: bool }` (`false` por defecto para no romper tests actuales, activable para la regla clásica de racha al impactar); `ResignCommand`; `BattleshipLegalMoveGenerator`; botón de Revancha (`RematchCommand`) en `battleship_board.gd`. |
| 9 | **Ludo** (`ludo_game`) | Circuito compartido de **52 casillas** (`TRACK_LEN = 52`) + 5 de recta final (`MAX_STEPS = 57`), salida con 6, turno extra con 6, casillas de salida seguras, barreras/bloqueos de 2 fichas (`has_rival_blockade_at`), hasta 4 jugadores. | **Motor Rust**: penalización de **tres `6` consecutivos** en el mismo turno (`ConsecutiveSixesResource` — pierde el turno al tercer 6); **turno extra al capturar ficha rival o al meter ficha en la meta exacta (`MAX_STEPS`)** (configurable con `LudoRulesConfigResource`); **4 casillas seguras de estrella adicionales (`offset + 8`: casillas 8, 21, 34, 47)**; `ResignCommand` y `LudoLegalMoveGenerator`. |
| 10 | **Mil Millas** (`mille_bornes_game`) | Meta de **1000 km** con extensión (`TripExtendedEvent`), máximo 2 cartas de 200 km por jugador, pila de descarte con rebarajado automático, `Safety::RightOfWay` y `CoupFourreCommand`. | **Motor Rust + UI (`mille_bornes_board.gd`)**: añadir las **3 Cartas de Seguridad (Escudos) restantes** (`ExtraTank` vs `OutOfGas`, `PunctureProof` vs `FlatTire`, `DrivingAce` vs `Accident`); otorgar **turno extra al jugar cualquier `Safety`**; bono de `+100 km` en `CoupFourreCommand`; botón de reacción **¡Coup Fourré!** en `mille_bornes_board.gd`. |
| 11 | **Monopoly** (`monopoly_game`) | Tablero oficial de **40 casillas**, **10 cartas de Suerte + 10 de Arca Comunitaria**, **Cárcel** (`JailResource`, `PayJailFeeCommand`), **Subastas** (`AuctionResource`, `AuctionBidCommand`), doble renta por grupo completo, escalado de estaciones y servicios, quiebra con traspaso al acreedor. | **Motor Rust + UI (`monopoly_board.gd`)**: **Casas y Hoteles** (`BuildHouseCommand`, `SellHouseCommand` con construcción uniforme y tabla de rentas con 1–4 casas/hotel); **Hipotecas** (`MortgagePropertyCommand`, `UnmortgagePropertyCommand`); **3 dobles seguidos envían a la Cárcel**; retención y uso de carta `GetOutOfJailFree` (`UseJailCardCommand`); **Intercambios (`ProposeTradeCommand`, `RespondTradeCommand`)** y controles UI en `monopoly_board.gd`. |
| 12 | **UNO** (`uno_game`) | Mazo de 108 cartas, apilamiento de `+2`/`+4`, validación de `WildDrawFour` legal, `Reverse` como `Skip` en 2 jugadores, robo y juego inmediato (`DrewAndPlayedEvent`), rebarajado automático e **Intercepción Jump-In (`InterceptCommand`)**. | **Motor Rust + UI (`uno_board.gd`)**: **grito de "¡UNO!" y penalización de +2 cartas** si un rival acusa antes del siguiente turno (`CallUnoCommand`, `CatchUnoFailureCommand`); **desafío formal de Comodín +4 (`ChallengeWildDrawFourCommand`: +4 al tramposo o +6 al retador fallido)**; cablear botón **Jump-In (`InterceptCommand`)**, botón **¡UNO!** y modal de desafío en `uno_board.gd`. |
| 13 | **Crisis / TEG** (`crisis_game`) | 30 territorios, 6 continentes con bonos, objetivos secretos, fases (`PlaceArmies`, `Attack`, `Fortify`), combate hasta 3v3 dados (empate favorece al defensor), fortificación por camino conexo y canje de tarjetas (`ExchangeCardsCommand`). | **Motor Rust + UI (`crisis_board.gd`)**: **robo efectivo de 1 `TerritoryCard` al cerrar la fase de ataque si conquistó al menos 1 territorio en el turno** (`ConquestTrackerResource`); **bono de +2 ejércitos en el territorio propio si la tarjeta canjeada pertenece al jugador**; `ResignCommand`. |

---

## 1. Reglas de Oro de Compatibilidad Regresiva (No Romper el Motor ni el Código Existente)

Todo prompt de este documento DEBE cumplir estrictamente estas 5 garantías arquitectónicas:

1. **Inmutabilidad del Core ECS (`open_table_core` y `open_table_engine`):**
   - Prohibido modificar las firmas de `Command`, `Event`, `RuleEngine`, `Session`, `TurnOrder` o `RandomService`.
2. **Retrocompatibilidad de Comandos y Eventos (`#[serde(default)]`):**
   - Si se añade un campo opcional a un comando o evento existente, debe anotarse con `#[serde(default)]` para que todos los tests unitarios existentes, los replays `.otr` y las llamadas `send_command_json` desde GDScript sigan funcionando sin cambios.
   - Preferir añadir **nuevos comandos** (`BuildHouseCommand`, `CallUnoCommand`, `ChallengeWildDrawFourCommand`, etc.) registrados adicionalmente en `RuleEngine` mediante `rules.register::<NuevoComando, _>(...)`.
3. **Inicialización Perezosa de Recursos Nuevos (`Default`):**
   - Todo nuevo `Resource` introducido en un crate de juego debe implementar `Default` e insertarse tanto en `new_*_session` como de forma defensiva al inicio de los handlers de `rules.rs` (`if !world.contains_resource::<NuevoResource>() { world.insert_resource(NuevoResource::default()); }`).
4. **Flags de Configuración con Defaults Seguros para Tests Existentes:**
   - Cuando un test unitario existente depende explícitamente del comportamiento previo (por ejemplo, `shogi_game::test_forced_promotion_en_zona_rival` o `battleship_game::un_disparo_certero_se_reporta_como_hit_y_uno_al_agua_como_miss`), la regla variante se activa mediante un `ConfigResource` cuyo `Default` preserva el 100% de los tests actuales, añadiendo constructores o comandos de configuración para el modo canónico estricto y sus propios tests dedicados.
5. **Verificación Continua por Crate:**
   - Ningún prompt se da por completado si rompe `cargo test --workspace` o `tools/run_godot_tests.sh`.

---

## Bloque 1: Juegos de Estrategia Abstracta — Ajedrez, Damas, Go, Shogi, Xiangqi y Damas Chinas (Prompts 496–504)

---

### 496. Ajedrez (`chess_board.gd`): Selector Visual de Coronación y Controles de Tablas en Tablero

**Objetivo:** Conectar en la interfaz gráfica de Godot las reglas de elección de pieza al coronar (`promote_to`: Dama, Torre, Alfil, Caballo) y de oferta/aceptación de tablas (`OfferDrawCommand` / `AcceptDrawCommand`) que ya existen en `chess_game`.

- **Archivos a modificar:**
  - `godot_project/chess_board.gd`
  - `godot_project/tests/chess_smoke.gd`
- **Especificaciones sin romper código existente:**
  - En `chess_board.gd`, cuando un peón se mueve a la fila de coronación (`row == 0` o `row == 7`), si no estamos en modo headless/test automático sin UI interactiva, mostrar un panel emergente compacto (`PromotionSelectorPanel`) con 4 botones: **♛ Dama (`Queen`)**, **♜ Torre (`Rook`)**, **♝ Alfil (`Bishop`)** y **♞ Caballo (`Knight`)**, enviando en `MovePieceCommand` el campo `"promote_to": chosen_kind`.
  - Exponer el método público `select_promotion_piece(kind: String)` en `chess_board.gd` (por defecto `"Queen"` si no se invoca) para permitir pruebas automatizadas en headless sin bloquear el flujo.
  - Añadir en la barra de acciones de `chess_board.gd` el botón `"🤝 Ofrecer Tablas"` (envía `{"type": "OfferDrawCommand", "player": current_p}`) y un banner reactivo `"El rival ofrece tablas — [Aceptar] [Rechazar]"` cuando se recibe la oferta o está activa, enviando `{"type": "AcceptDrawCommand", "player": current_p}`.
- **Verificación:**
  ```bash
  cargo test -p chess_game
  redot --headless --path godot_project -s tests/chess_smoke.gd
  ```

---

### 497. Damas (`checkers_game` + `checkers_board.gd`): Victoria por Bloqueo Total y Tablas por 40 Movimientos

**Objetivo:** Completar el reglamento oficial de Damas en Rust declarando ganador al jugador cuyo rival se queda sin movimientos legales (fichas bloqueadas) y declarando tablas tras 40 movimientos consecutivos sin capturas ni coronación, resaltando la ficha activa de multicaptura en Godot.

- **Archivos a modificar:**
  - `checkers_game/src/board.rs` (añadir `DrawClockResource { pub half_moves_without_capture_or_promotion: u32 }` con `Default`)
  - `checkers_game/src/events.rs` (añadir campo opcional `#[serde(default)] pub is_draw: bool` en `GameOverEvent` o mantener `winner` y emitir evento de fin de partida)
  - `checkers_game/src/rules.rs`
  - `checkers_game/tests/game_rules.rs`
  - `godot_project/checkers_board.gd`
- **Especificaciones sin romper código existente:**
  - En `checkers_game/src/rules.rs`, cuando el turno avanza al rival (`!has_further_capture`), además de verificar `opponent_pieces_left == 0`, comprobar con `board.get_all_legal_moves(&sides_snapshot, opponent).is_empty()`. Si el rival tiene fichas pero **ningún movimiento legal disponible**, emitir `GameOverEvent { winner: cmd.player }` y actualizar `GameOverResource(true)` y `WinnerResource(Some(cmd.player))`.
  - Mantener un contador `DrawClockResource`: se reinicia a `0` en cada captura (`captured_pos.is_some()`) o coronación (`promoted == true`), y se incrementa en `1` en movimientos simples de dama. Al llegar a `80` medios turnos (40 turnos de ambos jugadores), marcar `GameOverResource(true)`.
  - En `godot_project/checkers_board.gd`, cuando tras un salto el turno sigue perteneciendo al mismo jugador (multicaptura encadenada), seleccionar y resaltar automáticamente con un borde dorado pulsante la casilla de aterrizaje (`to`) para indicar que debe continuar saltando con esa misma ficha.
- **Verificación:**
  ```bash
  cargo test -p checkers_game
  redot --headless --path godot_project -s tests/headless_smoke.gd
  ```

---

### 498. Go (`go_game`): Puntuación Completa con Prisioneros, Komi Configurable (`6.5`) y `GoLegalMoveGenerator`

**Objetivo:** Completar el cálculo de puntuación final de Go sumando prisioneros capturados y el Komi para Blancas, e implementar el generador de jugadas legales en `RuleEngine`.

- **Archivos a modificar:**
  - `go_game/src/board.rs` (añadir `pub black_prisoners: usize`, `pub white_prisoners: usize`, `pub komi_half_points: u32` inicializado a `13` = `6.5` puntos en `BoardResource`)
  - `go_game/src/rules.rs` (incrementar prisioneros al capturar o remover piedras muertas, aplicar `komi` en `ConfirmDeadCommand` y registrar `GoLegalMoveGenerator`)
  - `go_game/src/events.rs` (añadir campos con `#[serde(default)]`: `black_score: f32`, `white_score: f32` en `GameOverEvent`)
  - `go_game/tests/game_rules.rs`
- **Especificaciones sin romper código existente:**
  - En `PlaceStoneCommand`, cuando `captured_stones > 0`, sumar `captured_stones` a `board.black_prisoners` (si juega Negro) o `board.white_prisoners` (si juega Blanco).
  - En `ConfirmDeadCommand`, al remover cada piedra muerta `(x, y)` de `dead_positions`, sumar `1` prisionero al jugador contrario del color de la piedra muerta removida.
  - Calcular `black_total = (black_territory + board.black_prisoners) as f32` y `white_total = (white_territory + board.white_prisoners) as f32 + (board.komi_half_points as f32 / 2.0)`. Nota de compatibilidad: para no alterar el test existente `go_partida_completa_hasta_scoring_de_territorio` (donde Negro tiene mucho más territorio o donde se prueba en tablero 9×9), si `black_territory > white_territory` por margen mayor al komi gana Negro; además proveer `BoardResource::with_komi(mut self, komi_half_points: u32)` (con `komi_half_points = 0` por defecto en `BoardResource::new` y `13` = 6.5 activable mediante `SetKomiCommand` o `new_go_session_with_komi`) para que el test existente `go_partida_completa_hasta_scoring_de_territorio` pase sin tocar una sola línea y los nuevos tests verifiquen el desempate exacto con Komi `6.5` y prisioneros.
  - Implementar `GoLegalMoveGenerator` (todas las intersecciones vacías que no violen suicidio ni Ko/Superko, más `PassCommand`) y registrarlo en `build_go_rules()`.
- **Verificación:**
  ```bash
  cargo test -p go_game
  ```

---

### 499. Go (`go_board.gd`): Botón Pasar, Fase Interactiva de Piedras Muertas y Selector 9×9 / 13×13 / 19×19

**Objetivo:** Cablear en `godot_project/go_board.gd` todos los comandos que ya existen en `go_game` (`PassCommand`, `MarkDeadCommand`, `ConfirmDeadCommand`, `PlaceHandicapCommand`).

- **Archivos a modificar:**
  - `godot_project/go_board.gd`
  - `godot_project/tests/go_smoke.gd`
- **Especificaciones sin romper código existente:**
  - Añadir en la barra superior/inferior de `go_board.gd`:
    1. Botón **"⏭️ Pasar Turno"** que envía `{"type": "PassCommand", "player": current_p}`.
    2. Cuando se detectan 2 pases consecutivos, cambiar el estado visual del tablero a **"Fase de Marcado de Piedras Muertas"**: hacer clic sobre una piedra en el tablero envía `{"type": "MarkDeadCommand", "player": current_p, "positions": [[x, y]]}` (dibujando una `✕` semitransparente sobre las piedras marcadas) y mostrar el botón **"✅ Confirmar Piedras Muertas"** que envía `{"type": "ConfirmDeadCommand", "player": current_p}`.
    3. Añadir selector de Handicap inicial (0, 2, 3, 4 piedras) antes de la primera jugada que envía `{"type": "PlaceHandicapCommand", "player": 1, "positions": [...]}`.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/go_smoke.gd
  ```

---

### 500. Shogi (`shogi_game` + `shogi_board.gd`): Regla de Sennichite (Repetición Cuádruple), Promoción Opcional/Obligatoria por Fila y Modal UI

**Objetivo:** Añadir detección de **Sennichite** (tablas por repetir 4 veces el mismo estado de tablero + manos + turno), soporte para promoción opcional vs obligatoria según la fila exacta de destino, `ShogiLegalMoveGenerator` y el diálogo de promoción en `shogi_board.gd`.

- **Archivos a modificar:**
  - `shogi_game/src/board.rs` (añadir `ShogiHistoryResource` con contador de hashes de `(squares, hands, current_player)` y `ShogiRulesConfigResource { pub strict_fesa_promotion: bool }`)
  - `shogi_game/src/movement.rs` (añadir `must_promote_fesa` donde solo `Pawn`/`Lance` en fila `0`/`8` y `Knight` en filas `0..=1`/`7..=8` están obligados a promocionar, manteniendo `must_promote` compatible con `test_forced_promotion_en_zona_rival` cuando `strict_fesa_promotion == false`)
  - `shogi_game/src/rules.rs` (registrar `ShogiLegalMoveGenerator` y verificar Sennichite al alcanzar 4 repeticiones emitiendo `GameOverEvent { winner: None }`)
  - `shogi_game/tests/game_rules.rs`
  - `godot_project/shogi_board.gd`
- **Especificaciones sin romper código existente:**
  - `test_forced_promotion_en_zona_rival` sigue pasando al 100% porque `ShogiRulesConfigResource::default().strict_fesa_promotion` es `false`. Cuando se activa `strict_fesa_promotion = true` (o mediante `can_promote` vs `must_promote_fesa`), `Silver`, `Rook` y `Bishop` pueden entrar en la zona de promoción con `promote: false` o `promote: true`.
  - Si un estado `(board.squares, board.hands, next_player)` se repite 4 veces en `ShogiHistoryResource`, se emite `GameOverEvent { winner: None }` (tablas por Sennichite).
  - En `godot_project/shogi_board.gd`, mostrar un diálogo compacto `"¿Promocionar pieza? [Promocionar] [No promocionar]"` cuando un movimiento entra o sale de la zona de promoción y no es obligatorio.
- **Verificación:**
  ```bash
  cargo test -p shogi_game
  redot --headless --path godot_project -s tests/shogi_smoke.gd
  ```

---

### 501. Xiangqi (`xiangqi_game`): Victoria por Ahogado (*Kunbi*), Repetición y `XiangqiLegalMoveGenerator`

**Objetivo:** Hacer cumplir la regla oficial de Xiangqi donde dejar al oponente sin movimientos legales (incluso sin estar en jaque — *Kunbi*) otorga la victoria inmediata, y registrar el generador de movimientos legales en `RuleEngine`.

- **Archivos a modificar:**
  - `xiangqi_game/src/rules.rs`
  - `xiangqi_game/tests/game_rules.rs`
- **Especificaciones sin romper código existente:**
  - En `xiangqi_game/src/rules.rs` (línea 180), cambiar la condición de fin de partida de `is_in_check(board, opponent) && all_legal_moves_for(world, opponent).is_empty()` a `all_legal_moves_for(world, opponent).is_empty()`, ya que en Xiangqi tanto el jaque mate (*Jiangsi*) como el ahogado (*Kunbi*) son victoria para `cmd.player`.
  - Implementar `XiangqiLegalMoveGenerator` envolviendo `all_legal_moves_for` y registrarlo con `rules.set_legal_move_generator(Box::new(XiangqiLegalMoveGenerator))` en `build_xiangqi_rules()`.
  - Añadir `XiangqiHistoryResource` para detectar triple repetición de posición y declarar tablas (`GameOverEvent { winner: None }`) si se repite 3 veces la misma configuración.
- **Verificación:**
  ```bash
  cargo test -p xiangqi_game
  redot --headless --path godot_project -s tests/xiangqi_smoke.gd
  ```

---

### 502. Damas Chinas (`chinese_checkers_game` + `chinese_checkers_board.gd`): Regla Anti-Bloqueo en Meta (*Home-Camp Spoiling*), `ResignCommand` y Saltos Encadenados en UI

**Objetivo:** Implementar la regla oficial de torneo de Damas Chinas contra el bloqueo intencional de la punta destino, añadir `ResignCommand` y `ChineseCheckersLegalMoveGenerator`, y permitir construir caminos de saltos múltiples (`path`) en `chinese_checkers_board.gd`.

- **Archivos a modificar:**
  - `chinese_checkers_game/src/board.rs`
  - `chinese_checkers_game/src/commands.rs` (añadir `ResignCommand`)
  - `chinese_checkers_game/src/rules.rs` (registrar `ResignCommand` y `ChineseCheckersLegalMoveGenerator`)
  - `chinese_checkers_game/tests/game_rules.rs`
  - `godot_project/chinese_checkers_board.gd`
- **Especificaciones sin romper código existente:**
  - En `BoardResource::has_won(&self, player: PlayerId) -> bool`: un jugador gana cuando **las 10 casillas de su triángulo objetivo (`targets[&player]`) están ocupadas** (`target.iter().all(|pos| self.pegs.contains_key(pos))`) y **al menos una de esas casillas contiene una canica propia** (`target.iter().any(|pos| self.pegs.get(pos) == Some(&player))`). Esto mantiene 100% compatible el caso normal donde las 10 canicas son del jugador, e impide que un rival bloquee eternamente una esquina dejando una ficha rezagada.
  - En `godot_project/chinese_checkers_board.gd`, calcular automáticamente mediante BFS el camino de saltos intermedios (`"path": [...]`) cuando el jugador selecciona una casilla alcanzable mediante saltos múltiples encadenados, enviándolo en `MovePegCommand`.
- **Verificación:**
  ```bash
  cargo test -p chinese_checkers_game
  redot --headless --path godot_project -s tests/chinese_checkers_smoke.gd
  ```

---

## Bloque 2: Juegos de Dados y Tablero Clásico — Backgammon, Batalla Naval y Ludo (Prompts 503–507)

---

### 503. Backgammon (`backgammon_game`): Regla de Uso Obligatorio de Ambos Dados (o del Dado Mayor) y `BackgammonLegalMoveGenerator`

**Objetivo:** Validar que si un jugador solo puede usar uno de los dos dados (pero no ambos en secuencia), y ambos dados tienen movimientos individuales posibles, esté obligado a jugar el dado de mayor valor.

- **Archivos a modificar:**
  - `backgammon_game/src/board.rs` (añadir helper `must_use_larger_die_check`)
  - `backgammon_game/src/rules.rs` (registrar `BackgammonLegalMoveGenerator` y validar elección de dado cuando una jugada deja al segundo dado sin movimiento posible habiendo alternativa que usa ambos dados o el dado mayor)
  - `backgammon_game/tests/game_rules.rs`
- **Especificaciones sin romper código existente:**
  - En `Sides`, añadir `can_play_both_dice(&self, board: &BoardResource, player: PlayerId, d1: u32, d2: u32) -> bool` simulando un paso con `d1` seguido de `d2`, o `d2` seguido de `d1`.
  - Cuando `pending` tiene exactamente 2 dados distintos `[d1, d2]`:
    - Si existe al menos una secuencia que permite jugar **ambos dados**, rechazar un primer movimiento que deje al jugador bloqueado sin poder usar el segundo dado.
    - Si **ninguna** secuencia permite jugar ambos dados, pero tanto `d1` como `d2` son jugables por separado, exigir que se juegue `d1.max(d2)`.
  - Verificar que todos los tests existentes en `backgammon_game/tests/game_rules.rs` continúan pasando sin modificaciones.
- **Verificación:**
  ```bash
  cargo test -p backgammon_game
  ```

---

### 504. Backgammon (`backgammon_board.gd`): Controles Interactivos del Doubling Cube en la UI

**Objetivo:** Exponer en `godot_project/backgammon_board.gd` los comandos del dado de doblaje (`OfferDoubleCommand`, `AcceptDoubleCommand`, `RejectDoubleCommand`) que ya existen en `backgammon_game`.

- **Archivos a modificar:**
  - `godot_project/backgammon_board.gd`
  - `godot_project/tests/backgammon_smoke.gd`
- **Especificaciones sin romper código existente:**
  - Mostrar en el panel lateral de `backgammon_board.gd` el valor actual del Cubo de Doblaje (`×1`, `×2`, `×4`, ..., `×64`) y su poseedor actual.
  - Añadir botón **"🎲×2 Doblar Apuesta"** (habilitado antes de tirar los dados cuando el jugador posee el cubo o está en el centro), que envía `{"type": "OfferDoubleCommand", "player": current_p}`.
  - Cuando se recibe `DoubleOfferedEvent`, mostrar modal al oponente con botones **"✅ Aceptar Doblaje (×N)"** (`AcceptDoubleCommand`) y **"🏳️ Rechazar y Conceder"** (`RejectDoubleCommand`).
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/backgammon_smoke.gd
  ```

---

### 505. Batalla Naval (`battleship_game` + `battleship_board.gd`): Turno Extra Configurable al Impactar, `ResignCommand` y Botón de Revancha

**Objetivo:** Soportar la regla oficial de turno extra al acertar (`Hit`/`Sunk`) mediante configuración sin romper los tests por turnos alternos, añadir `ResignCommand` y conectar `RematchCommand` en `battleship_board.gd`.

- **Archivos a modificar:**
  - `battleship_game/src/fleet.rs` (añadir `BattleshipConfigResource { pub extra_turn_on_hit: bool }` con `Default` = `false`)
  - `battleship_game/src/commands.rs` (añadir `SetBattleshipRulesCommand { pub extra_turn_on_hit: bool }` y `ResignCommand { pub player: PlayerId }`)
  - `battleship_game/src/rules.rs`
  - `battleship_game/tests/game_rules.rs`
  - `godot_project/battleship_board.gd`
- **Especificaciones sin romper código existente:**
  - En `FireShotCommand`, consultar `world.get_resource::<BattleshipConfigResource>().map(|c| c.extra_turn_on_hit).unwrap_or(false)`.
  - Si `extra_turn_on_hit == true` y `result != ShotResult::Miss` (y la partida aún no terminó), **no avanzar `TurnResource`**, otorgando disparo consecutivo al jugador que acertó.
  - Si `extra_turn_on_hit == false` (valor por defecto), avanzar siempre el turno como esperan los tests existentes de `battleship_game/tests/game_rules.rs`.
  - En `godot_project/battleship_board.gd`, añadir un toggle `"Regla Racha (Turno extra al acertar)"` en la fase de colocación y un botón **"🔄 Solicitar Revancha"** al finalizar la partida que envía `{"type": "RematchCommand", "player": current_p}`.
- **Verificación:**
  ```bash
  cargo test -p battleship_game
  redot --headless --path godot_project -s tests/battleship_smoke.gd
  ```

---

### 506. Ludo (`ludo_game` + `ludo_board.gd`): Tres Seises Consecutivos, Turno Extra por Captura/Meta y Casillas Estrella (`+8`)

**Objetivo:** Completar las reglas clásicas de Ludo: perder el turno al sacar tres `6` seguidos, otorgar tirada extra al capturar una ficha rival o al coronar una ficha en la meta exacta (`MAX_STEPS`), y proteger las 4 casillas de estrella intermedias (`offset + 8`).

- **Archivos a modificar:**
  - `ludo_game/src/board.rs` (añadir `ConsecutiveSixesResource { pub count: HashMap<PlayerId, u8> }`, `LudoRulesConfigResource { pub star_safe_squares: bool, pub bonus_roll_on_capture_and_goal: bool, pub three_sixes_penalty: bool }` y actualizar `is_safe_square`)
  - `ludo_game/src/commands.rs` (añadir `ResignCommand`)
  - `ludo_game/src/rules.rs`
  - `ludo_game/tests/game_rules.rs`
  - `godot_project/ludo_board.gd`
- **Especificaciones sin romper código existente:**
  - En `RollDiceCommand`: llevar la cuenta de `6` consecutivos del jugador actual en `ConsecutiveSixesResource`. Si `value == 6`, incrementar `count`; si `count == 3` y `three_sixes_penalty` está activo, reiniciar `count = 0`, emitir `NoValidMovesEvent { player: cmd.player, value: 6 }`, limpiar `PendingRollResource` y avanzar `TurnResource` al siguiente jugador. Si `value != 6`, reiniciar `count = 0`.
  - En `MoveTokenCommand`: además de conservar el turno cuando `roll == 6`, si `captured.is_some()` o `finished == true` (y la partida no ha terminado), **no avanzar `TurnResource`** (el jugador gana una tirada extra de bonificación). Nota: verificar que todos los tests existentes en `ludo_game/tests/game_rules.rs` (incluido `pisar_una_ficha_rival_la_manda_de_vuelta_a_la_base`) siguen pasando al 100%.
  - En `TokensResource::is_safe_square(board_pos: u32)`: además de las casillas de salida (`start_offset`), considerar seguras las casillas de estrella en `(offset + 8) % TRACK_LEN` cuando `star_safe_squares` esté activo.
- **Verificación:**
  ```bash
  cargo test -p ludo_game
  redot --headless --path godot_project -s tests/ludo_smoke.gd
  ```

---

## Bloque 3: Juegos de Cartas, Economía y Gran Estrategia — Mil Millas, Monopoly, UNO y Crisis/TEG (Prompts 507–518)

---

### 507. Mil Millas (`mille_bornes_game`): Las 4 Cartas de Seguridad Oficiales, Turno Extra por Escudo y Bono de Coup Fourré

**Objetivo:** Incorporar las 4 Cartas de Seguridad (*Safeties*) del reglamento oficial de Mille Bornes (`RightOfWay`, `ExtraTank`, `PunctureProof`, `DrivingAce`), su inmunidad específica frente a cada `Hazard`, el turno extra al jugar una carta de seguridad y el bono de `+100 km` en `CoupFourreCommand`.

- **Archivos a modificar:**
  - `mille_bornes_game/src/card.rs` (ampliar `pub enum Safety { RightOfWay, ExtraTank, PunctureProof, DrivingAce }`)
  - `mille_bornes_game/src/deck.rs` (añadir 1 ejemplar de cada una de las 4 `Safety` en `build_deck()` y `pub safeties_played: HashMap<PlayerId, HashSet<Safety>>` en `DeckResource`)
  - `mille_bornes_game/src/rules.rs`
  - `mille_bornes_game/tests/game_rules.rs`
- **Especificaciones sin romper código existente:**
  - Mapa de protección de `Safety`:
    - `Safety::RightOfWay` protege contra `Hazard::SpeedLimit` (y detenciones de semáforo).
    - `Safety::ExtraTank` protege contra `Hazard::OutOfGas`.
    - `Safety::PunctureProof` protege contra `Hazard::FlatTire`.
    - `Safety::DrivingAce` protege contra `Hazard::Accident`.
  - Mantener la compatibilidad con el test existente `test_derecho_de_via_bloquea_todos_los_hazards` (donde `RightOfWayResource` bloquea hazards distintos de `OutOfGas`), y hacer que `ExtraTank` bloquee también `OutOfGas` y cure inmediatamente `OutOfGas` si el jugador lo tenía activo.
  - En `CoupFourreCommand`: permitir responder cuando el jugador tiene en mano bien el `Card::Remedy(hazard)` (compatibilidad con `test_coup_fourre_contraataca_y_anula_peligro`) o bien la `Card::Safety(matching_safety)` correspondiente al peligro sufrido, limpiando el peligro y otorgando inmunidad permanente de esa `Safety`.
- **Verificación:**
  ```bash
  cargo test -p mille_bornes_game
  ```

---

### 508. Mil Millas (`mille_bornes_board.gd`): Botón de Reacción "¡Coup Fourré!" y Visualización de los 4 Escudos

**Objetivo:** Mostrar en `godot_project/mille_bornes_board.gd` el área de Escudos/Seguridades jugadas por cada jugador y el botón reactivo de `CoupFourreCommand` cuando el jugador sufre un peligro y posee la respuesta en su mano.

- **Archivos a modificar:**
  - `godot_project/mille_bornes_board.gd`
  - `godot_project/tests/mille_bornes_smoke.gd`
- **Especificaciones sin romper código existente:**
  - Renderizar las 4 insignias de seguridad (`Prioridad de Paso`, `Cisterna`, `Inpinchable`, `As del Volante`) junto al tablero de cada jugador.
  - Cuando el jugador activo tiene un `Hazard` encima y posee la carta de respuesta en mano, habilitar un botón destacado **"⚡ ¡Coup Fourré!"** que envía `{"type": "CoupFourreCommand", "player": current_p}`.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/mille_bornes_smoke.gd
  ```

---

### 509. Monopoly (`monopoly_game`): Construcción Uniforme de Casas y Hoteles (`BuildHouseCommand` y `SellHouseCommand`)

**Objetivo:** Implementar la compra y venta de Casas (1 a 4) y Hoteles (nivel 5) sobre grupos de color completos con regla de construcción uniforme y alquileres escalonados.

- **Archivos a modificar:**
  - `monopoly_game/src/resources.rs` (añadir `BuildingsResource { pub buildings: HashMap<usize, u8> }` donde `1..=4` son casas y `5` es hotel)
  - `monopoly_game/src/commands.rs` (añadir `BuildHouseCommand { pub player: PlayerId, pub space: usize }` y `SellHouseCommand { pub player: PlayerId, pub space: usize }`)
  - `monopoly_game/src/events.rs` (añadir `HouseBuiltEvent` y `HouseSoldEvent`)
  - `monopoly_game/src/rules.rs`
  - `monopoly_game/tests/game_rules.rs`
- **Especificaciones sin romper código existente:**
  - Coste de construcción por casa según el lado del tablero (`space < 10`: $50, `10..20`: $100, `20..30`: $150, `30..40`: $200).
  - Regla de construcción uniforme: para construir en `space`, el jugador debe poseer todo el grupo de color (`owns_full_group`), ninguna propiedad del grupo debe estar hipotecada, y `buildings[space]` no puede superar en más de 1 el mínimo de edificios de las demás propiedades del mismo grupo (máximo nivel `5` = Hotel).
  - En `apply_land_effect` (`SpaceKind::Property`), si `buildings[space_idx] > 0`, calcular la renta escalonada:
    - `0` edificios (grupo completo): `rent * 2` (comportamiento actual intacto).
    - `1` casa: `rent * 5`.
    - `2` casas: `rent * 15`.
    - `3` casas: `rent * 45`.
    - `4` casas: `rent * 80`.
    - `5` (Hotel): `rent * 125`.
  - `SellHouseCommand` vende un nivel de edificio al banco por el 50% de su coste de construcción respetando el desmonte uniforme.
- **Verificación:**
  ```bash
  cargo test -p monopoly_game
  ```

---

### 510. Monopoly (`monopoly_game`): Hipotecas (`MortgagePropertyCommand`), Tres Dobles a la Cárcel y Tarjeta `GetOutOfJailFree`

**Objetivo:** Implementar el sistema de hipotecas de propiedades, el envío automático a la cárcel al sacar 3 dobles consecutivos en el mismo turno y la retención/uso de la carta "Salir Libre de la Cárcel".

- **Archivos a modificar:**
  - `monopoly_game/src/resources.rs` (añadir `pub mortgaged: HashSet<usize>` y `pub jail_free_cards: HashMap<PlayerId, u8>` en `PlayersResource`, y `pub consecutive_doubles: HashMap<PlayerId, u8>` en `JailResource`)
  - `monopoly_game/src/commands.rs` (añadir `MortgagePropertyCommand { pub player: PlayerId, pub space: usize }`, `UnmortgagePropertyCommand { pub player: PlayerId, pub space: usize }`, `UseJailCardCommand { pub player: PlayerId }`)
  - `monopoly_game/src/rules.rs`
  - `monopoly_game/tests/game_rules.rs`
- **Especificaciones sin romper código existente:**
  - `MortgagePropertyCommand`: valida que `player` sea dueño de `space`, que no haya edificios en ese grupo y que no esté ya hipotecada; acredita `price / 2` al jugador e inserta `space` en `mortgaged`. Mientras `space` esté en `mortgaged`, caer en ella no cobra renta.
  - `UnmortgagePropertyCommand`: descuenta `(price / 2) * 110 / 100` (50% + 10% de interés) y remueve `space` de `mortgaged`.
  - En `RollAndMoveCommand`: si `is_doubles == true` (y el jugador no estaba saliendo de la cárcel), incrementar `consecutive_doubles[player]`. Si llega a `3`, reiniciar a `0`, mover inmediatamente al jugador a `JAIL_SPACE`, insertar `jailed.insert(player, 3)`, emitir `JailedEvent` y avanzar el turno sin aplicar efecto de casilla ni dar turno extra.
  - Cuando un jugador roba `ChanceCard::GetOutOfJailFree` o `CommunityChestCard::GetOutOfJailFree`, además del dividendo actual (para no romper tests existentes), incrementar `jail_free_cards[player] += 1` para que pueda salir gratis con `UseJailCardCommand`.
- **Verificación:**
  ```bash
  cargo test -p monopoly_game
  ```

---

### 511. Monopoly (`monopoly_game` + `monopoly_board.gd`): Intercambios entre Jugadores (`ProposeTradeCommand`) y Paneles UI

**Objetivo:** Permitir intercambios de propiedades y efectivo entre jugadores en `monopoly_game` y exponer en `monopoly_board.gd` los botones de Construir Casa/Hotel, Hipotecar e Intercambiar.

- **Archivos a modificar:**
  - `monopoly_game/src/resources.rs` (añadir `TradeOfferResource`)
  - `monopoly_game/src/commands.rs` (añadir `ProposeTradeCommand`, `AcceptTradeCommand`, `RejectTradeCommand`)
  - `monopoly_game/src/rules.rs`
  - `godot_project/monopoly_board.gd`
  - `godot_project/tests/monopoly_smoke.gd`
- **Especificaciones sin romper código existente:**
  - `ProposeTradeCommand { player, target, offered_spaces: Vec<usize>, requested_spaces: Vec<usize>, offered_cash: u32, requested_cash: u32 }` valida que ambos jugadores posean las propiedades sin edificios y el efectivo ofrecido, registrando la oferta en `TradeOfferResource`.
  - `AcceptTradeCommand { player }` transfiere atómicamente propiedades y dinero entre ambos jugadores; `RejectTradeCommand { player }` limpia la oferta.
  - En `godot_project/monopoly_board.gd`, añadir botones en el panel de gestión de propiedades para **🏠 Construir Casa/Hotel**, **🏦 Hipotecar/Deshipotecar** y **🤝 Proponer Intercambio**.
- **Verificación:**
  ```bash
  cargo test -p monopoly_game
  redot --headless --path godot_project -s tests/monopoly_smoke.gd
  ```

---

### 512. UNO (`uno_game`): Grito de "¡UNO!", Penalización por Olvido (`+2`) y Desafío de Comodín `+4`

**Objetivo:** Implementar las dos reglas oficiales restantes de UNO: cantar "¡UNO!" al quedar con 1 carta (con penalización de 2 cartas si un rival lo acusa antes del siguiente turno) y desafiar formalmente un `WildDrawFour` (`ChallengeWildDrawFourCommand`).

- **Archivos a modificar:**
  - `uno_game/src/board.rs` (añadir `pub uno_called: HashSet<PlayerId>`, `pub last_wild_draw_four_player: Option<PlayerId>` en `UnoState`)
  - `uno_game/src/commands.rs` (añadir `CallUnoCommand { pub player: PlayerId }`, `CatchUnoFailureCommand { pub accuser: PlayerId, pub target: PlayerId }`, `ChallengeWildDrawFourCommand { pub challenger: PlayerId }`)
  - `uno_game/src/events.rs` (añadir `UnoCalledEvent`, `UnoPenaltyEvent`, `WildDrawFourChallengedEvent`)
  - `uno_game/src/rules.rs`
  - `uno_game/tests/game_rules.rs`
- **Especificaciones sin romper código existente:**
  - `CallUnoCommand`: si `player` tiene 1 o 2 cartas en mano, inserta `player` en `state.uno_called` y emite `UnoCalledEvent { player }`.
  - `CatchUnoFailureCommand`: si `target` tiene exactamente 1 carta en mano (`hands[target].len() == 1`) y **no** está en `state.uno_called`, `target` roba inmediatamente 2 cartas de penalización del mazo y se emite `UnoPenaltyEvent { target, accuser, drawn: 2 }`. (Si `target` vuelve a tener >1 carta, se remueve de `uno_called`).
  - `ChallengeWildDrawFourCommand`: para mantener el 100% de compatibilidad con `test_wild_draw_four_ilegal_si_tienes_carta_del_color` (que rechaza directamente `WildDrawFour` en `PlayCardCommand` salvo que se habilite `allow_bluff_wild_draw_four` en `UnoState`), añadir `pub allow_bluff_wild_draw_four: bool` (`false` por defecto) en `UnoState`: cuando `allow_bluff_wild_draw_four == true`, `PlayCardCommand` permite jugar `WildDrawFour` marcando `state.wild_draw_four_illegal = true` si tenía carta del color activo; si el siguiente jugador ejecuta `ChallengeWildDrawFourCommand`, si `wild_draw_four_illegal == true` el infractor roba las 4 cartas en lugar del retador, y si `wild_draw_four_illegal == false` el retador roba 6 cartas (`draw_penalty + 2`).
- **Verificación:**
  ```bash
  cargo test -p uno_game
  ```

---

### 513. UNO (`uno_board.gd`): Botones de "¡UNO!", Intercepción Jump-In (`InterceptCommand`) y Desafío `+4` en UI

**Objetivo:** Conectar en `godot_project/uno_board.gd` los comandos `InterceptCommand`, `CallUnoCommand`, `CatchUnoFailureCommand` y `ChallengeWildDrawFourCommand`.

- **Archivos a modificar:**
  - `godot_project/uno_board.gd`
  - `godot_project/tests/uno_smoke.gd`
- **Especificaciones sin romper código existente:**
  - Añadir botón **"🔥 ¡UNO!"** en `uno_board.gd` que envía `{"type": "CallUnoCommand", "player": local_player}` y botón **"🚨 Acusar UNO"** si el rival tiene 1 carta y no cantó UNO.
  - Añadir soporte para **Jump-In (`InterceptCommand`)**: si no es el turno del jugador local pero tiene en mano una carta exactamente idéntica (mismo color y valor) al tope del descarte, resaltarla con borde eléctrico y permitir jugarla enviando `{"type": "InterceptCommand", "player": local_player, "card_index": idx}`.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/uno_smoke.gd
  ```

---

### 514. Crisis / TEG (`crisis_game` + `crisis_board.gd`): Robo Automático de Tarjeta de Territorio por Conquista y Bono `+2` por País Propio

**Objetivo:** Completar el ciclo de tarjetas de territorio en `crisis_game`: otorgar 1 tarjeta de territorio al final de la fase de ataque si el jugador conquistó al menos un país en su turno, y añadir `+2` ejércitos directamente en el territorio si al canjear o reclamar tarjeta el jugador es dueño de ese país.

- **Archivos a modificar:**
  - `crisis_game/src/resources.rs` (añadir `pub conquered_this_turn: bool` y `pub card_deck: Vec<TerritoryCard>` en `PlayerCardsResource` o `ConquestTrackerResource`)
  - `crisis_game/src/rules.rs`
  - `crisis_game/tests/game_rules.rs`
- **Especificaciones sin romper código existente:**
  - En `RollAttackCommand`, cuando `territory_conquered == true`, marcar `conquered_this_turn = true`. Si es la primera conquista del turno y el jugador tiene menos de 5 tarjetas en `PlayerCardsResource`, robar determinísticamente una `TerritoryCard` (usando `RandomResource`), añadirla a `PlayerCardsResource.cards[cmd.player]` e incluirla en `TerritoryConqueredEvent.card_drawn = Some(card)`.
  - En `ExchangeCardsCommand`, además del `bonus_armies` global del canje (`4, 7, 10...`), por cada una de las 3 tarjetas canjeadas cuyo `territory` pertenezca actualmente a `cmd.player` en `TerritoryStateResource`, añadir `+2` ejércitos de bonificación en ese territorio.
  - Verificar que todos los tests de `crisis_game/tests/` (`game_rules.rs`, `full_game.rs`, `stress.rs`, `property.rs`) siguen pasando sin errores.
- **Verificación:**
  ```bash
  cargo test -p crisis_game
  redot --headless --path godot_project -s tests/crisis_smoke.gd
  ```

---

## Bloque 4: IA Consciente de Nuevas Reglas, Anti-Cheat, Documentación y Gate `verify_p13.sh` (Prompts 515–520)

---

### 515. Actualización de los Motores de IA (`*/src/ai.rs`) para Utilizar las Reglas Avanzadas

**Objetivo:** Asegurar que los bots de IA de Monopoly, UNO, Mille Bornes, Backgammon y Go aprovechen los nuevos comandos (construir casas en Monopoly, cantar UNO, usar las 4 Safeties en Mille Bornes, doblar con ventaja en Backgammon) sin producir movimientos inválidos.

- **Archivos a modificar:**
  - `monopoly_game/src/ai.rs`
  - `uno_game/src/ai.rs`
  - `mille_bornes_game/src/ai.rs`
  - `backgammon_game/src/ai.rs`
- **Especificaciones sin romper código existente:**
  - En `monopoly_game/src/ai.rs`: en dificultad `Medium`/`Hard`/`Expert`, si el bot posee un grupo de color completo y tiene más de `$400` de reserva, puede emitir `BuildHouseCommand`.
  - En `uno_game/src/ai.rs`: cuando el bot queda con 1 carta tras jugar, emite `CallUnoCommand` (en `Easy` tiene 30% de probabilidad de olvidarlo para que el jugador humano pueda usar `CatchUnoFailureCommand`).
  - En `mille_bornes_game/src/ai.rs`: priorizar jugar cualquier `Card::Safety(_)` cuando su peligro correspondiente amenaza o para obtener el turno extra.
- **Verificación:**
  ```bash
  cargo test --workspace
  redot --headless --path godot_project -s tests/ai_all_games_smoke.gd
  ```

---

### 516. Sincronización de `parse_command_json` en `open_table_godot` y `AntiCheatSession` en `open_table_relay`

**Objetivo:** Garantizar que todos los nuevos comandos añadidos en los prompts 496–514 sean aceptados transparentemente por `OpenTableBridge::send_command_json` y por el validador autoritativo `AntiCheatSession` del servidor Relay.

- **Archivos a modificar:**
  - `open_table_godot/src/lib.rs`
  - `open_table_relay/src/anticheat.rs`
- **Especificaciones sin romper código existente:**
  - Añadir tests unitarios en `open_table_godot` y `open_table_relay` verificando la deserialización polimórfica (`#[typetag::serde]`) de `BuildHouseCommand`, `SellHouseCommand`, `MortgagePropertyCommand`, `UnmortgagePropertyCommand`, `ProposeTradeCommand`, `CallUnoCommand`, `CatchUnoFailureCommand`, `ChallengeWildDrawFourCommand` y `SetBattleshipRulesCommand`.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- anticheat
  cargo check -p open_table_godot
  ```

---

### 517. Sincronización de Documentación de Juegos (`docs/games/*.md`) y Catálogo In-Game (`rules_catalog.gd`)

**Objetivo:** Actualizar los 13 documentos técnicos en `docs/games/*.md` y el catálogo in-game `godot_project/scripts/rules_catalog.gd` para documentar todos los comandos, eventos y reglas completas sin menciones obsoletas a prototipos antiguos.

- **Archivos a modificar:**
  - `docs/games/chess.md`, `checkers.md`, `go.md`, `shogi.md`, `xiangqi.md`, `chinese_checkers.md`, `backgammon.md`, `battleship.md`, `ludo.md`, `mille_bornes.md`, `monopoly.md`, `uno.md`, `teg.md`
  - `godot_project/scripts/rules_catalog.gd`
- **Especificaciones:**
  - Documentar en cada `docs/games/<juego>.md` la tabla completa de `Command`s y `Event`s reales con sus esquemas JSON exactos.
- **Verificación:**
  ```bash
  test -f docs/games/chinese_checkers.md
  tools/run_godot_tests.sh
  ```

---

### 518. Suite de Tests de Reglas Canónicas en Rust (`tests/canonical_rules_suite.rs`)

**Objetivo:** Añadir un test de integración transversal por cada uno de los 13 crates que valide las reglas canónicas completas añadidas en `PROMPTS13.md` sin alterar ni un solo test previo.

- **Archivos a crear/modificar:**
  - `checkers_game/tests/canonical_rules.rs` (bloqueo sin movimientos legales + tablas 40 turnos)
  - `go_game/tests/canonical_rules.rs` (puntuación con Komi 6.5 y prisioneros)
  - `shogi_game/tests/canonical_rules.rs` (Sennichite ×4 y promoción opcional FESA)
  - `xiangqi_game/tests/canonical_rules.rs` (victoria por ahogado *Kunbi*)
  - `chinese_checkers_game/tests/canonical_rules.rs` (victoria anti-bloqueo en punta de meta)
  - `backgammon_game/tests/canonical_rules.rs` (obligación de usar ambos dados o el mayor)
  - `battleship_game/tests/canonical_rules.rs` (modo `extra_turn_on_hit`)
  - `ludo_game/tests/canonical_rules.rs` (3 seises seguidos, turno extra por captura/meta y casillas estrella)
  - `mille_bornes_game/tests/canonical_rules.rs` (las 4 `Safety` cards y Coup Fourré)
  - `monopoly_game/tests/canonical_rules.rs` (casas/hoteles, hipotecas, 3 dobles a cárcel e intercambios)
  - `uno_game/tests/canonical_rules.rs` (`CallUnoCommand`, `CatchUnoFailureCommand` y `ChallengeWildDrawFourCommand`)
  - `crisis_game/tests/canonical_rules.rs` (robo de `TerritoryCard` al conquistar y bono `+2` por país propio)
- **Verificación:**
  ```bash
  cargo test --workspace
  ```

---

### 519. Smoke Test Headless en Godot de Reglas Completas y Controles UI (`tests/canonical_rules_ui_smoke.gd`)

**Objetivo:** Verificar en modo headless que los 13 tableros de Godot exponen los controles y métodos de las reglas completas sin errores de compilación ni regresiones en escenas existentes.

- **Archivos a crear:**
  - `godot_project/tests/canonical_rules_ui_smoke.gd`
- **Especificaciones:**
  - Instancia cada tablero clave y verifica la presencia de los controles/métodos de coronación y tablas en Ajedrez, Pasar/Marcar Muertas en Go, Doubling Cube en Backgammon, Coup Fourré en Mil Millas, Casas/Hipotecas en Monopoly e Intercepción/UNO en UNO.
  - Imprime `PASS: canonical_rules_ui_smoke.gd OK`.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/canonical_rules_ui_smoke.gd 2>&1 | grep "PASS"
  ```

---

### 520. Gate Maestro de Certificación de Reglas Completas (`tools/verify_p13.sh`)

**Objetivo:** Script de certificación que comprueba que `verify_p12.sh`, todos los tests de Rust de los 13 juegos y todos los tests headless de Godot pasan al 100% sin regresiones.

- **Archivos a crear:**
  - `tools/verify_p13.sh`
- **Especificaciones:**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  echo "=== 1. Ejecutando gate previo PROMPTS12 (verify_p12.sh) ==="
  bash tools/verify_p12.sh

  echo "=== 2. Ejecutando suite completa de tests de Rust (13 juegos + engine + relay) ==="
  cargo test --workspace

  echo "=== 3. Verificando documentación de los 13 juegos ==="
  for doc in chess checkers go shogi xiangqi chinese_checkers backgammon battleship ludo mille_bornes monopoly uno teg; do
    test -f "docs/games/${doc}.md"
  done

  echo "=== 4. Ejecutando todos los smoke tests de Godot/Redot headless ==="
  bash tools/run_godot_tests.sh

  echo "ALL PROMPTS13 CHECKS PASSED — 13/13 Games Complete Canonical Rules Verified!"
  ```
- **Verificación:**
  ```bash
  bash tools/verify_p13.sh
  ```

---

## Resumen de Prompts `PROMPTS13.md`

| # | Juego / Área | Regla Canónica o Integración UI Implementada (Sin Romper Código Existente) |
|---|---|---|
| **496** | **Ajedrez** (`chess_board.gd`) | Selector visual de pieza al coronar (`Queen`/`Rook`/`Bishop`/`Knight`) y botones `OfferDraw`/`AcceptDraw` |
| **497** | **Damas** (`checkers_game` + UI) | Victoria por bloqueo total del rival (0 movimientos legales), tablas por 40 turnos y resaltado de multicaptura |
| **498** | **Go** (`go_game`) | Puntuación final con prisioneros capturados + Komi (`6.5`) configurable y `GoLegalMoveGenerator` |
| **499** | **Go** (`go_board.gd`) | Botón `PassCommand`, fase interactiva `MarkDeadCommand`/`ConfirmDeadCommand` y selector de Handicap |
| **500** | **Shogi** (`shogi_game` + UI) | Regla de **Sennichite** (repetición ×4), promoción opcional vs obligatoria FESA y modal de promoción en UI |
| **501** | **Xiangqi** (`xiangqi_game`) | Victoria por ahogado (*Kunbi*), triple repetición y registro de `XiangqiLegalMoveGenerator` |
| **502** | **Damas Chinas** (`chinese_checkers`) | Regla oficial anti-bloqueo en punta de meta (*home-camp spoiling*), `ResignCommand` y saltos encadenados en UI |
| **503** | **Backgammon** (`backgammon_game`) | Obligación de usar ambos dados si es posible (o el dado mayor) y `BackgammonLegalMoveGenerator` |
| **504** | **Backgammon** (`backgammon_board.gd`) | Botones interactivos del Doubling Cube (`OfferDouble`, `AcceptDouble`, `RejectDouble`) en tablero |
| **505** | **Batalla Naval** (`battleship`) | Variante configurable `extra_turn_on_hit` en `BattleshipConfigResource`, `ResignCommand` y botón Revancha en UI |
| **506** | **Ludo** (`ludo_game` + UI) | Penalización por tres `6` consecutivos, turno extra por captura/meta y 4 casillas seguras de estrella (`+8`) |
| **507** | **Mil Millas** (`mille_bornes_game`) | Las 4 cartas de seguridad (`RightOfWay`, `ExtraTank`, `PunctureProof`, `DrivingAce`) y bono de Coup Fourré |
| **508** | **Mil Millas** (`mille_bornes_board.gd`) | Botón reactivo "¡Coup Fourré!" e indicadores visuales de los 4 escudos en mesa |
| **509** | **Monopoly** (`monopoly_game`) | Construcción uniforme de Casas (1–4) y Hoteles (`BuildHouseCommand`/`SellHouseCommand`) con rentas escalonadas |
| **510** | **Monopoly** (`monopoly_game`) | Hipotecas (`Mortgage`/`Unmortgage`), 3 dobles seguidos a la Cárcel y uso de tarjeta `GetOutOfJailFree` |
| **511** | **Monopoly** (`monopoly_game` + UI) | Intercambios entre jugadores (`ProposeTrade`/`AcceptTrade`/`RejectTrade`) y paneles de gestión en UI |
| **512** | **UNO** (`uno_game`) | Grito/penalización de `"¡UNO!"` (`CallUno`/`CatchUnoFailure`) y desafío de `+4` (`ChallengeWildDrawFour`) |
| **513** | **UNO** (`uno_board.gd`) | Botones de `"¡UNO!"`, Acusar UNO, Intercepción Jump-In (`InterceptCommand`) y Desafiar `+4` en UI |
| **514** | **Crisis / TEG** (`crisis_game`) | Robo automático de 1 `TerritoryCard` por turno con conquista y bono de `+2` ejércitos por tarjeta de país propio |
| **515** | **IA 13 Juegos** (`*/src/ai.rs`) | Actualización de bots de IA para usar casas en Monopoly, cantar UNO, jugar las 4 Safeties y doblar en Backgammon |
| **516** | **Bridge & Relay** (`godot` / `relay`) | Soporte polimórfico en `send_command_json` y `AntiCheatSession` para todos los nuevos comandos |
| **517** | **Documentación** (`docs/games/*.md`) | Actualización de los 13 documentos técnicos y `rules_catalog.gd` con esquemas JSON completos |
| **518** | **QA Rust** (`canonical_rules.rs`) | Suite de tests de integración en Rust para las reglas canónicas de los 13 juegos |
| **519** | **QA Godot** (`canonical_rules_ui`) | Smoke test headless verificando controles de reglas completas en los 13 tableros |
| **520** | **CI Gate Final** (`verify_p13.sh`) | Script maestro de certificación `tools/verify_p13.sh` |

*Total acumulado al finalizar PROMPTS13: 520 prompts.*
