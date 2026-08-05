# 120 Development Prompts — Games Tables SDK (Part 2)

Continúa desde `PROMPTS.md` (prompts 1–40). Numerados del 41 al 160.
No incluye IA ni sistemas de chat.

---

## 1. Shogi — Completar Reglas

**41.** Implementar la regla **Uchifuzume** en `shogi_game/src/rules.rs`: el Drop de un Peón que cause jaque mate inmediato al Rey rival es ilegal. Al resolver un `DropPieceCommand { piece: PieceKind::Pawn }`, después de aplicar el drop prueba si el Rey contrario ya no tiene jugadas legales (jaque mate); si es así, rechaza el comando con `EngineError::InvalidCommand`. Añadir el test `test_uchifuzume_rechaza_drop_de_peon_con_jaque_mate_inmediato` en `shogi_game/tests/game_rules.rs` con un tablero mínimo donde el Peón droppado crea la posición de jaque mate.

**42.** Implementar restricción de drop para **Lanza y Caballo** en `shogi_game/src/rules.rs`: una Lanza no puede droppear en la última fila (fila 0 para Sente), y un Caballo no puede droppear en las dos últimas filas (filas 0 y 1). Añadir el test `test_lanza_no_puede_droppear_en_ultima_fila` que intenta `DropPieceCommand { piece: PieceKind::Lance, to: (3, 0) }` para Sente y verifica `EngineError::InvalidCommand`, y el test `test_caballo_no_puede_droppear_en_penultima_fila` que intenta drop en la fila 1 con el mismo resultado.

**43.** Implementar el movimiento de las piezas **promovidas** en `shogi_game/src/rules.rs`. La `PromotedRook` (Dragon) se mueve como Torre más un paso diagonal adyacente; el `PromotedBishop` (Horse) se mueve como Alfil más un paso ortogonal adyacente. Añadir el test `test_dragon_puede_moverse_ortogonal_y_diagonalmente` que coloca un Dragon en (4,4) y verifica que puede moverse tanto a (4,5) como a (5,5). Añadir `test_horse_puede_moverse_diagonal_y_ortogonalmente` con el mismo patrón para el `PromotedBishop`.

**44.** Implementar detección de **jaque** (Oute) en `shogi_game/src/rules.rs`: cualquier movimiento que deje al propio Rey en jaque debe rechazarse con `EngineError::InvalidCommand`. Añadir la función auxiliar privada `is_in_check(world: &World, player: PlayerId) -> bool` que recorre todas las piezas del oponente y verifica si alguna amenaza la posición del Rey. Añadir el test `test_mover_pieza_que_descubre_jaque_propio_es_rechazado` que coloca la Torre Gote atacando al Rey Sente con una pieza propia interpuesta, e intenta mover esa pieza — verificando `EngineError::InvalidCommand`.

**45.** Implementar detección de **jaque mate** (Tsumi) en `shogi_game/src/rules.rs`: cuando el Rey de un jugador está en jaque y ninguna jugada legal lo saca (incluyendo drops del hand), emitir `GameOverEvent { winner: Some(oponente) }`. Añadir el test `test_jaque_mate_termina_la_partida` con un tablero mínimo de mate conocido (por ejemplo, Rey Gote en esquina, dos Piezas Sente cubriendo todas las salidas), verificar que el evento `GameOverEvent` aparece en el retorno de `process_command`.

**46.** Implementar la captura de piezas y el **traspaso a la mano** del capturador en `shogi_game/src/rules.rs`. Cuando una pieza promovida es capturada, debe despromover antes de entrar a la mano del capturador (por ejemplo `PromotedSilver` → `Silver`). Añadir el test `test_capturar_pieza_promovida_la_agrega_despromovida_al_hand` que mueve una pieza Sente sobre una `PromotedSilver` Gote y verifica que `board.hands[&SENTE]` contiene `PieceKind::Silver` (no `PromotedSilver`).

---

## 2. Xiangqi — Completar Reglas

**47.** Implementar la restricción del **Elefante no puede cruzar el río** en `xiangqi_game/src/rules.rs`. El río está entre las filas 4 y 5 (fila 5 para Red, fila 4 para Black en un tablero de 10 filas). Un Elefante Red (owner == RED) no puede moverse a las filas 0–4; un Elefante Black no puede moverse a las filas 5–9. Añadir el test `test_elefante_no_puede_cruzar_el_rio` que intenta mover el Elefante Rojo desde fila 5 hacia fila 4 y verifica `EngineError::InvalidCommand`.

**48.** Implementar el **ojo del Elefante bloqueado** en `xiangqi_game/src/rules.rs`. El Elefante se mueve dos pasos en diagonal; si la casilla intermedia (el "ojo") está ocupada, el movimiento es ilegal. Añadir la verificación del ojo en el handler del Elefante. Añadir el test `test_ojo_del_elefante_bloqueado_invalida_movimiento` que coloca una pieza en el ojo del Elefante e intenta el movimiento de dos pasos diagonal, verificando `EngineError::InvalidCommand`.

**49.** Implementar la **pata del Caballo bloqueada** en `xiangqi_game/src/rules.rs`. El Caballo se mueve un paso ortogonal y luego un paso diagonal; si la casilla del primer paso ortogonal está ocupada, el movimiento es ilegal. Añadir el test `test_pata_de_caballo_bloqueada_invalida_movimiento` que coloca una pieza en la casilla ortogonal adyacente al Caballo e intenta el movimiento del Caballo en esa dirección, verificando `EngineError::InvalidCommand`.

**50.** Implementar la restricción del **Cañón sin captura no puede saltar** en `xiangqi_game/src/rules.rs`. El Cañón se mueve como Torre (ortogonal, cualquier distancia) cuando no captura, y en ese caso no puede haber ninguna pieza interpuesta. Añadir el test `test_canon_movimiento_simple_bloqueado_por_pieza_interpuesta` que coloca una pieza entre el Cañón y su destino en una fila, e intenta el movimiento sin captura, verificando `EngineError::InvalidCommand`.

**51.** Implementar la **captura del Cañón con plataforma** en `xiangqi_game/src/rules.rs`. Para capturar, el Cañón debe saltar exactamente sobre una pieza intermedia (la "pantalla/cannon platform") y aterrizar en una pieza enemiga. Si hay cero o dos o más piezas entre el Cañón y la pieza a capturar, la captura es ilegal. Añadir dos tests: `test_canon_captura_valida_con_una_plataforma` (una pieza interpuesta, captura exitosa) y `test_canon_captura_invalida_sin_plataforma` (cero piezas interpuestas, verifica `EngineError::InvalidCommand`).

**52.** Implementar la restricción del **Guardia/Asesor dentro del palacio** en `xiangqi_game/src/rules.rs`. El Guardia solo puede moverse diagonalmente y debe permanecer dentro del palacio de 3×3 (columnas 3–5, filas 0–2 para Black y filas 7–9 para Red). Añadir el test `test_guardia_no_puede_salir_del_palacio` que intenta mover el Guardia Red desde (4,8) a (5,8) (movimiento ortogonal inválido) y verifica `EngineError::InvalidCommand`.

**53.** Implementar detección de **jaque mate** en `xiangqi_game/src/rules.rs`. Cuando el General de un jugador está bajo ataque y no existe ninguna jugada legal que lo resuelva, emitir `GameOverEvent { winner: Some(otro_jugador) }`. Añadir la función auxiliar `all_legal_moves_for(world, player) -> Vec<MovePieceCommand>` y usarla después de cada movimiento para detectar el mate. Añadir el test `test_jaque_mate_termina_la_partida_en_xiangqi` con un tablero de mate conocido del Xiangqi (General en esquina, ataque sin escapatoria).

**54.** Implementar detección de **jaque perpetuo** como empate en `xiangqi_game/src/rules.rs`. Si la misma posición de tablero se repite tres veces (el jugador que da jaque continuo es el que causó la repetición), el jugador que da el jaque perpetuo pierde (regla estándar). Alternativamente, implementar como empate si el estado se repite tres veces con cualquier jugador. Almacenar hashes de posición en un `PositionHistoryResource`. Añadir el test `test_repeticion_tres_veces_es_empate` que reproduce una secuencia de movimientos que vuelve al mismo estado tres veces y verifica `GameOverEvent { winner: None }`.

---

## 3. Go — Completar Reglas

**55.** Implementar la **prohibición de suicidio** en `go_game/src/rules.rs`. Al colocar una piedra en una intersección, si el grupo resultante (incluyendo la piedra nueva) tiene cero libertades y esa jugada no captura ningún grupo enemigo, rechazar con `EngineError::InvalidCommand`. Añadir el test `test_suicidio_es_rechazado` que rodea una intersección vacía con piedras del oponente y verifica que el intento de colocar en esa intersección falla.

**56.** Verificar la correcta **captura de grupos multi-piedra** en `go_game/src/rules.rs`. La implementación actual captura grupos de una sola piedra. Extender el flood-fill de libertades para que opere sobre grupos conectados de múltiples piedras. Añadir el test `test_captura_de_grupo_de_tres_piedras` que coloca tres piedras B conectadas, las rodea con piedras W dejando una última libertad, cierra esa libertad, y verifica que `StonesCapturedEvent.count == 3` y el tablero queda sin esas tres piedras.

**57.** Implementar **Superko** (prohibición de repetir posición completa del tablero) en `go_game/src/rules.rs`. Almacenar un historial de hashes del tablero en `BoardHistoryResource`. Antes de aceptar un `PlaceStoneCommand`, computar el hash del estado resultante y rechazar con `EngineError::InvalidCommand` si ya fue visto. Añadir el test `test_superko_previene_repeticion_de_posicion` que reproduce una secuencia ko donde el jugador intenta volver a la misma posición de tablero.

**58.** Añadir soporte para **piedras de hándicap** en `go_game`. Crear un nuevo comando `PlaceHandicapCommand { positions: Vec<(u8, u8)> }` en `go_game/src/commands.rs`. Este comando solo es válido antes de que empiece el juego (tick 0), lo procesa solo el jugador Black, y coloca todas las piedras de hándicap de una vez. Añadir el test `test_handicap_de_cuatro_piedras_se_coloca_correctamente` que coloca las 4 piedras de hándicap clásicas en 9×9 (3,2), (5,2), (3,6), (5,6) y verifica que el tablero las contiene y que es el turno de White.

**59.** Implementar **marcado de piedras muertas** y su eliminación tras el doble pass. Añadir un `MarkDeadCommand { player: PlayerId, positions: Vec<(u8, u8)> }` en `go_game/src/commands.rs`. Cuando ambos jugadores pasan (el estado ya detectado en `test_pass_ends_game`), en lugar de terminar inmediatamente, entrar a una fase "marcado de muertas" donde cada jugador puede marcar/desmarcar grupos muertos. Cuando ambos jugadores confirman con `ConfirmDeadCommand`, eliminar las piedras marcadas y calcular el puntaje. Añadir el test `test_marcado_y_confirmacion_de_muertas` que pasa dos veces, marca una piedra muerta, confirma, y verifica que el `GameOverEvent` refleja el territorio correcto.

---

## 4. UNO — Completar Reglas

**60.** Implementar la **Carta Reversa como Skip en partida de 2 jugadores** en `uno_game/src/rules.rs`. Cuando `players.len() == 2` y se juega una `CardValue::Reverse`, el efecto es equivalente a un Skip (el turno vuelve al jugador que jugó la carta). Añadir el test `test_reversa_es_skip_en_dos_jugadores` con sesión de `vec![P1, P2]`, P1 juega una carta Reverse, y se verifica que `current_player() == P1`.

**61.** Implementar el **robo forzado cuando no hay jugada legal** en `uno_game/src/rules.rs`. Cuando un jugador emite `DrawCardCommand` y `draw_penalty == 0`, el jugador roba exactamente una carta del mazo y, si esa carta es jugable (coincide color o valor con el descarte), puede jugarla inmediatamente emitiendo un evento `DrewAndPlayedEvent`; de lo contrario pasa el turno. Añadir el test `test_robar_cuando_no_hay_jugada_avanza_el_turno_o_juega_inmediatamente` que prepara una mano vacía de jugadas legales y verifica el comportamiento.

**62.** Implementar la **remezcla del mazo** cuando se agota en `uno_game/src/rules.rs`. Cuando `deck` está vacío y se necesita robar, tomar todo el `discard_pile` excepto la carta superior, barajarlas con el `RandomService` del engine, y usarlas como nuevo `deck`. Añadir el test `test_mazo_agotado_se_remezcla_desde_descarte` que reduce el mazo a 0 cartas, deja el descarte con 5 cartas, dispara un robo, y verifica que el mazo tiene 4 cartas (5 - 1 top) y el descarte tiene 1.

**63.** Implementar la **detección de victoria** cuando un jugador vacía su mano en `uno_game/src/rules.rs`. Al jugar la última carta del hand, emitir `GameOverEvent { winner: Some(player) }`. Añadir el test `test_jugar_ultima_carta_emite_game_over` que prepara a P1 con una sola carta jugable y verifica que `PlayCardCommand` devuelve eventos que incluyen `GameOverEvent { winner: Some(P1) }`.

---

## 5. Crisis (TEG) — Completar Reglas

**64.** Implementar la mecánica de **combate y resolución de dados de ataque** en `crisis_game/src/rules.rs`. Cuando un jugador ataca con `DeclareAttackCommand` y luego emite `RollAttackCommand`, tirar hasta 3 dados de ataque y hasta 3 de defensa, ordenar en forma descendente, comparar dados par a par (los empates favorecen al defensor), y restar ejércitos de cada territorio emitiendo `AttackResolvedEvent`. Añadir los tests `test_ataque_resolucion_dados_reduce_ejercitos` y `test_conquista_transfiere_territorio_al_atacante`.

**65.** Implementar la **eliminación de jugador y ciclo de turnos** en `crisis_game/src/rules.rs`. Cuando un jugador pierde su último territorio tras una conquista, emitir `PlayerEliminatedEvent { player, by }` y marcar al jugador en `EliminatedPlayersResource`. El `TurnResource` debe omitir automáticamente a los jugadores eliminados. Añadir el test `test_player_eliminado_sale_del_ciclo_de_turnos`.

**66.** Implementar la **verificación de objetivos secretos y victoria** en `crisis_game/src/rules.rs`. Al inicio de la partida asignar una `ObjectiveCard` a cada jugador. Al finalizar un ataque exitoso o turno, verificar mediante `check_objective` si el jugador activo cumplió su objetivo (por ejemplo, conquistar un continente o eliminar a otro jugador). Si se cumple, emitir `TegGameOverEvent { winner, objective }`. Añadir el test `test_game_over_por_objetivo_conquistar_continente`.

**67.** Verificar la **distribución inicial de 30 territorios y ejércitos** en `crisis_game/src/rules.rs`. Al crear la sesión con `new_crisis_session`, repartir los 30 territorios entre todos los jugadores de manera equitativa asignando 1 ejército a cada uno. Añadir el test `test_setup_distribuye_todos_los_territorios`.

---

## 6. Chess — Completar Reglas

**68.** Implementar detección de **triple repetición** (tablas por repetición) en `chess_game/src/rules.rs`. Almacenar un historial de hashes de posición (incluyendo turno, derechos de enroque y en passant target) en un nuevo `PositionHistoryResource`. Cuando la misma posición ocurre por tercera vez, emitir `GameOverEvent { winner: None }`. Añadir el test `test_triple_repeticion_produce_tablas` que reproduce tres veces la misma posición y verifica `GameOverEvent { winner: None }`.

**69.** Implementar la **regla de 50 movimientos** en `chess_game/src/rules.rs`. Añadir un `HalfMoveClock` resource (contador de medios movimientos desde la última captura o avance de peón). Resetearlo en capturas y avances de peón; incrementarlo en cualquier otro movimiento. Cuando llega a 100 (50 movimientos completos), emitir `GameOverEvent { winner: None }`. Añadir el test `test_regla_50_movimientos_produce_tablas` que fuerza el contador a 99 y hace un movimiento neutral que lo lleva a 100.

**70.** Implementar detección de **ahogado** (stalemate) en `chess_game/src/rules.rs`. Después de cada jugada, si el jugador cuyo turno es no tiene ninguna jugada legal pero tampoco está en jaque, emitir `GameOverEvent { winner: None }`. Añadir el test `test_ahogado_produce_tablas` que configura un tablero clásico de stalemate (Rey Black en esquina, Dama White una casilla diagonal) y mueve la Dama para crear el ahogado, verificando `GameOverEvent { winner: None }`.

**71.** Implementar tablas por **material insuficiente** en `chess_game/src/rules.rs`. Tras cada movimiento, si el tablero solo contiene: (a) Rey vs Rey, (b) Rey + Alfil vs Rey, (c) Rey + Caballo vs Rey, o (d) Rey + Alfil vs Rey + Alfil (ambos alfiles en misma color), emitir `GameOverEvent { winner: None }`. Añadir el test `test_material_insuficiente_rey_vs_rey_produce_tablas` que despeja el tablero dejando solo los dos Reyes y verifica `GameOverEvent { winner: None }` tras el siguiente movimiento.

---

## 7. Checkers — Completar Reglas

**72.** Implementar el **sistema de captura obligatoria** en `checkers_game/src/rules.rs`. Si existen capturas disponibles para el jugador en turno, un `MovePieceCommand` que no sea captura debe rechazarse con `EngineError::InvalidCommand`. Añadir la función privada `has_any_capture(world, player) -> bool` que escanea el tablero. Añadir el test `test_captura_obligatoria_rechaza_movimiento_simple_si_hay_captura_disponible` que coloca una ficha de captura disponible y verifica que mover otra ficha sin capturar falla.

**73.** Implementar el **movimiento y captura hacia atrás de las Damas (Kings)** en `checkers_game/src/rules.rs`. Las fichas coronadas deben poder moverse y capturar en las cuatro diagonales (actualmente quizás solo en las diagonales de avance). Añadir el test `test_dama_puede_capturar_hacia_atras` que coloca una Dama Blanca coronada con una pieza Negra detrás y verifica que la captura diagonal hacia atrás es válida.

---

## 8. Backgammon — Completar Reglas

**74.** Implementar la detección de **Gammon** en `backgammon_game/src/rules.rs`. Cuando un jugador saca la última pieza (condición de victoria), verificar si el oponente no ha sacado ninguna pieza de casa (todo el bearing-off pendiente). Si es así, emitir `GameOverEvent { winner, gammon: true }` o añadir un campo `gammon: bool` al evento existente. Añadir el test `test_gammon_cuando_oponente_no_saco_ninguna_ficha`.

**75.** Implementar la detección de **Backgammon** (máxima derrota) en `backgammon_game/src/rules.rs`. Además de que el oponente no sacó fichas, si aún tiene piezas en el home board del ganador o en la barra, el resultado es Backgammon. Añadir un campo `backgammon: bool` al evento o a una variante del `GameOverEvent`. Añadir el test `test_backgammon_cuando_oponente_tiene_fichas_en_home_del_ganador`.

**76.** Implementar el **dado de doblaje (Doubling Cube)** en `backgammon_game`. Crear `OfferDoubleCommand { player }` y `AcceptDoubleCommand { player }` en `backgammon_game/src/commands.rs`. El oferente debe hacerlo antes de tirar los dados. Al aceptar, el multiplicador de puntos se dobla. Al rechazar, el rechazador pierde al valor actual. Almacenar el estado en `DoublingCubeResource { value: u32, owner: Option<PlayerId> }`. Añadir el test `test_doblar_y_rechazar_termina_la_partida_con_valor_actual`.

**77.** Implementar la **Regla Crawford** en `backgammon_game/src/rules.rs` para partidas a múltiples puntos. Cuando un jugador llega a `match_points - 1`, el siguiente juego se disputa sin dado de doblaje (el juego Crawford). Añadir el campo `crawford_game: bool` a un nuevo `MatchStateResource`. Añadir el test `test_crawford_rule_bloquea_dado_de_doblaje` que simula llegar a `match_points - 1` y verifica que `OfferDoubleCommand` falla con `EngineError::InvalidCommand` durante ese juego.

---

## 9. Monopoly — Completar Reglas

**78.** Implementar los **mecanismos de la Cárcel** en `monopoly_game/src/rules.rs`. Añadir `JailResource { jailed: HashMap<PlayerId, u8> }` (jugador → turnos restantes en la cárcel). Cuando un jugador cae en el espacio de "Ir a la Cárcel", añadirlo a `JailResource`. En `RollAndMoveCommand`, si el jugador está en la cárcel: puede pagar la fianza (`PayJailFeeCommand`), o tirar dados esperando dobles — si saca dobles, sale; si no saca dobles tres veces, paga y sale. Añadir el test `test_jugador_en_carcel_no_se_mueve_hasta_que_sale`.

**79.** Implementar la **subasta de propiedad** en `monopoly_game/src/rules.rs`. Si un jugador cae en una propiedad libre y no desea comprarla (`BuyPropertyCommand { buy: false }`), iniciar subasta entre todos los jugadores con `AuctionBidCommand { player, amount }`. El ganador la compra al precio de puja. Añadir `AuctionStartedEvent`, `AuctionWonEvent`. Añadir el test `test_rechazo_de_compra_inicia_subasta`.

**80.** Implementar el **alquiler de Servicios (Utilities)** en `monopoly_game/src/rules.rs`. Si un jugador cae en un Servicio (electricidad, agua) que tiene dueño, el alquiler es 4× el dado tirado si el dueño tiene uno, 10× si tiene ambos. Añadir `UtilityRentPaidEvent { player, owner, multiplier, dice_total, amount }`. Añadir el test `test_renta_de_servicio_es_4x_con_uno_y_10x_con_dos`.

**81.** Implementar el **alquiler escalonado de Estaciones/Ferrocarriles** en `monopoly_game/src/rules.rs`. El alquiler es 25/50/100/200 según cuántas estaciones posea el dueño (1/2/3/4). Añadir `RailroadRentPaidEvent { player, owner, railroads_owned, amount }`. Añadir el test `test_renta_de_ferrocarril_escala_con_cantidad_de_estaciones`.

**82.** Implementar la **quiebra** en `monopoly_game/src/rules.rs`. Cuando el dinero de un jugador cae por debajo de 0 después de pagar una renta o impuesto, emitir `BankruptcyEvent { player }`. Si el acreedor es otro jugador, transferirle todas las propiedades. Si el acreedor es el banco, las propiedades vuelven al banco (disponibles para subasta). Eliminar al jugador del ciclo de turnos. Si queda un solo jugador, emitir `GameOverEvent { winner }`. Añadir el test `test_quiebra_transfiere_propiedades_al_acreedor`.

---

## 10. Ludo — Completar Reglas

**83.** Implementar la **columna de casa** (home stretch) en `ludo_game/src/rules.rs`. Cada jugador tiene las últimas 5 casillas antes de la meta que son exclusivas de su color (nadie puede entrar ni ser capturado allí). Verificar que los tokens del color correcto pueden entrar y que un `MoveTokenCommand` que intente mover un token rival a esa zona falle. Añadir el test `test_token_no_puede_entrar_en_columna_de_casa_rival`.

**84.** Implementar el **dado exacto** para llegar a la meta en `ludo_game/src/rules.rs`. Un token en la home stretch solo puede avanzar si el dado es exactamente el número de casillas que le faltan. Si el dado es mayor, el movimiento es inválido. Añadir el test `test_dado_mayor_que_casillas_restantes_en_meta_es_invalido` que coloca un token a 2 casillas de la meta y verifica que un movimiento de 3 falla.

**85.** Implementar el **bloqueo** en `ludo_game/src/rules.rs`. Cuando dos tokens del mismo jugador ocupan la misma casilla, forman un bloqueo que los tokens rivales no pueden pasar ni aterrizar. Añadir el test `test_bloqueo_impide_que_rival_aterrice_en_casilla` que coloca dos tokens del mismo color en el espacio 10 y verifica que un token rival no puede moverse a esa casilla ni sobrepasarla.

**86.** Implementar la **elección de token** cuando múltiples tokens del jugador tienen movimientos legales en `ludo_game/src/rules.rs`. El `MoveTokenCommand` debe incluir un `token_index: usize` para identificar qué token mover. Si el `token_index` apunta a un token que no tiene movimiento legal con el dado actual, rechazar con `EngineError::InvalidCommand`. Añadir el test `test_seleccion_de_token_invalido_es_rechazada`.

---

## 11. Mille Bornes — Completar Reglas

**87.** Implementar la **tarjeta Límite de Velocidad** en `mille_bornes_game/src/rules.rs`. Cuando un jugador juega `SpeedLimit` sobre un rival, ese rival solo puede avanzar con cartas de 25 km o 50 km hasta que reciba `EndOfSpeedLimit`. Almacenar el estado en `SpeedLimitResource { limited: HashSet<PlayerId> }`. Rechazar `PlayDistanceCommand { distance: d }` con `EngineError::InvalidCommand` si `d > 50` y el jugador está en `limited`. Añadir el test `test_limite_de_velocidad_rechaza_distancia_mayor_a_50`.

**88.** Implementar la **tarjeta de Seguridad "Derecho de Vía"** en `mille_bornes_game/src/rules.rs`. Un jugador con `RightOfWay` en su tableau es inmune a todos los Hazards excepto `OutOfGas` (y puede ignorar también `SpeedLimit`). Actualizar el handler de `PlayHazardCommand` para verificar si el objetivo tiene `RightOfWay` activo y, si es así, rechazar con `EngineError::InvalidCommand`. Añadir el test `test_derecho_de_via_bloquea_todos_los_hazards`.

**89.** Implementar el **límite de dos cartas de 200 km** en `mille_bornes_game/src/rules.rs`. Añadir un campo `cards_200_played: HashMap<PlayerId, u8>` al estado. Al jugar una carta `Distance(200)`, si el jugador ya jugó 2, rechazar con `EngineError::InvalidCommand`. Añadir el test `test_tercera_carta_200_es_rechazada`.

**90.** Implementar la **extensión del viaje** a 1000 km en `mille_bornes_game/src/rules.rs`. El viaje por defecto termina a 700 km, pero si todos los jugadores han jugado sus dos cartas de 200 km antes de que alguien llegue a 700, extender el objetivo a 1000 km automáticamente. Emitir un `TripExtendedEvent`. Añadir el test `test_extension_de_viaje_a_1000_cuando_se_agotan_las_200` que hace que todos los jugadores jueguen sus cartas de 200 km y verifica la emisión de `TripExtendedEvent`.

---

## 12. Chinese Checkers — Completar Reglas

**91.** Implementar el soporte de **6 jugadores** en `chinese_checkers_game/src/rules.rs`. La sesión `new_chinese_checkers_session` debe aceptar 2, 3, 4, o 6 jugadores. Para 6 jugadores, los triángulos de salida son los 6 ángulos del hexágono de 61 puntos. Añadir el test `test_seis_jugadores_ciclan_correctamente` que inicia con `vec![P1, P2, P3, P4, P5, P6]` y verifica que el turno avanza en ese orden después de 6 movimientos.

**92.** Implementar la **condición de victoria** en `chinese_checkers_game/src/rules.rs`. Un jugador gana cuando sus 10 fichas ocupan el triángulo de destino opuesto al de salida. Añadir la verificación después de cada `MoveCommand` y emitir `GameOverEvent { winner: Some(player) }`. Añadir el test `test_victoria_cuando_todas_las_fichas_llegan_al_triangulo_opuesto` que fuerza las 10 fichas de P1 en el triángulo opuesto y verifica el evento de victoria.

**93.** Verificar **cadenas de salto de 3 o más** en `chinese_checkers_game/src/rules.rs`. El `MoveCommand` ya acepta una secuencia de posiciones intermedias. Verificar que tres o más saltos encadenados funcionan correctamente (cada salto es legal, aterriza en punto vacío). Añadir el test `test_cadena_de_tres_saltos_consecutivos` con un tablero preparado con 3 fichas intermedias para saltar y verificar que el movimiento completo es aceptado.

---

## 13. Battleship — Completar Reglas

**94.** Implementar la **validación de adyacencia** durante la colocación de flota en `battleship_game/src/rules.rs`. Los barcos no pueden tocar a otros barcos (ni en diagonal). Al procesar `PlaceShipCommand`, verificar que ninguna celda del barco nuevo es adyacente (8 direcciones) a una celda de un barco ya colocado. Rechazar con `EngineError::InvalidCommand` si hay adyacencia. Añadir el test `test_barco_adyacente_a_otro_es_rechazado`.

**95.** Implementar la **detección de disparo duplicado** en `battleship_game/src/rules.rs`. Si un jugador intenta disparar a una celda que ya disparó previamente (ya sea agua o impacto), rechazar con `EngineError::InvalidCommand`. Almacenar los disparos en `ShotsResource { shots: HashMap<PlayerId, HashSet<(u8, u8)>> }`. Añadir el test `test_disparo_a_celda_ya_disparada_es_rechazado`.

**96.** Verificar la emisión de `SunkenShipEvent` cuando todos los segmentos de un barco son impactados en `battleship_game/src/rules.rs`. El evento ya existe; confirmar que se emite exactamente cuando el último segmento del barco es golpeado, con información de tipo de barco y posición. Añadir el test `test_impactar_todos_los_segmentos_hunde_el_barco_y_emite_evento` que golpea un barco de 3 celdas celda a celda y verifica que el `SunkenShipEvent` aparece solo al tercer disparo.

**97.** Verificar la detección de **flota hundida = victoria** en `battleship_game/src/rules.rs`. Cuando todos los barcos de un jugador son hundidos, emitir `GameOverEvent { winner: Some(atacante) }`. Añadir el test `test_hundir_toda_la_flota_termina_la_partida` que configura una flota mínima de un solo barco, lo hunde, y verifica `GameOverEvent`.

**98.** Implementar el comando de **revancha** en `battleship_game`. Crear `RematchCommand { player }` en `battleship_game/src/commands.rs`. Cuando ambos jugadores emiten `RematchCommand`, reiniciar la sesión a la fase de colocación de flota (vaciar `FleetResource`, resetear turno, reiniciar el `RandomService` con nueva seed). Añadir el test `test_revancha_reinicia_la_fase_de_colocacion`.

---

## 14. SDK — Nuevas Funcionalidades

**99.** Añadir `GameVariant` enum a `open_table_core/src/lib.rs`. Crear `pub enum GameVariant { Standard, Custom(String) }` con soporte de serialización. Extender `Session::new` (o añadir `Session::new_with_variant`) para aceptar un `GameVariant` y almacenarlo en un nuevo `GameVariantResource`. Añadir un test en `open_table_engine/tests/dice_game.rs` que recupera el variant de la sesión y verifica que coincide con el pasado al constructor.

**100.** Implementar un **API de suscripción a eventos** en `open_table_engine/src/session.rs`. Añadir `Session::on_event<E: Event + 'static>(handler: impl Fn(&E) + Send + Sync + 'static)` que registra un closure tipado invocado cada vez que se emite un evento de tipo `E`. Almacenar los handlers en `EventHandlersResource`. Añadir el test `test_on_event_handler_se_invoca_en_cada_evento` que registra un counter y verifica que se incrementa con cada `DiceRolledEvent`.

**101.** Implementar **rate limiting** por jugador en `open_table_engine/src/session.rs`. Añadir `Session::set_rate_limit(max_commands_per_second: u32)`. Almacenar timestamps en `RateLimitResource`. Si un jugador supera el límite, rechazar con un nuevo `EngineError::RateLimitExceeded`. Añadir el test `test_rate_limit_rechaza_comandos_excesivos` que emite 5 comandos en rápida sucesión con un límite de 2/s.

**102.** Añadir **metadatos de sesión** en `open_table_engine/src/session.rs`. Crear `SessionMetadata { game_name: String, started_at: u64, max_players: usize }` y almacenarla en un `SessionMetadataResource`. Añadir `Session::metadata() -> &SessionMetadata`. Actualizar los 12 constructores de juego para pasar el nombre del juego. Añadir el test `test_metadata_contiene_nombre_del_juego_correcto`.

**103.** Implementar **replay parcial desde un tick** en `open_table_engine/src/session.rs`. Añadir `Session::replay_from(tick: Tick) -> Result<(), EngineError>` que reproduce solo los comandos desde el tick dado, sin recrear el estado previo. Útil para aplicar diff updates. Añadir el test `test_replay_parcial_desde_tick_3_produce_estado_correcto` que aplica 5 comandos, exporta el log, crea una sesión nueva que replica los primeros 3 manualmente, y llama a `replay_from(3)` para los últimos 2.

**104.** Implementar **timeout de reconexión y autoforfeit** en `open_table_engine/src/session.rs`. Añadir `Session::set_reconnection_timeout(player: PlayerId, duration: Duration)`. Si `check_timeout()` detecta que un jugador lleva más de `duration` desconectado, emitir `ForfeitEvent { player }` y avanzar el turno. Añadir el test `test_timeout_de_reconexion_emite_forfeit`.

**105.** Implementar **Undo local** para sesiones de un solo dispositivo en `open_table_engine/src/session.rs`. Añadir `Session::undo_last_command() -> Result<(), EngineError>` que revierte el último comando del log replaying desde cero. Disponible solo si `SessionMode::Local`. Añadir el test `test_undo_revierte_el_estado_al_tick_anterior` que hace 3 movimientos en una partida de damas, llama a `undo_last_command`, y verifica que `current_tick() == 2`.

**106.** Crear el struct `GameResult` en `open_table_core/src/lib.rs` con campos: `winner: Option<PlayerId>`, `duration_ms: u64`, `total_moves: u32`, `players: Vec<PlayerId>`, `game_name: String`. Añadir `Session::into_result(elapsed_ms: u64) -> GameResult` que extrae estos datos del estado final. Añadir el test `test_into_result_contiene_datos_correctos_de_partida` usando una sesión de dice game terminada.

**107.** Implementar **política de reintentos** en `open_table_transport_tcp`. Añadir `RetryPolicy { max_attempts: u32, base_backoff_ms: u64, max_backoff_ms: u64 }` y `TcpClientTransport::with_retry_policy(policy: RetryPolicy)`. La lógica de reconexión existente en `reconnect_to_host` debe usar esta política (backoff exponencial con jitter). Añadir el test en `open_table_transport_tcp/tests/` que configura 2 intentos y verifica que el tercer fallo no reintenta.

**108.** Implementar **negociación de versión de protocolo** en `open_table_transport_tcp`. Al conectar, el cliente envía `{ "protocol_version": "1.0" }` y el host responde con su versión o un error `UnsupportedProtocolVersion`. Añadir el nuevo variant `EngineError::UnsupportedProtocolVersion { expected: String, got: String }`. Añadir el test en `open_table_transport_tcp/tests/end_to_end.rs` que verifica la negociación exitosa.

**109.** Implementar un **servidor multi-sesión** en `open_table_transport_tcp`. Crear `MultiSessionServer` en un nuevo archivo `open_table_transport_tcp/src/multi_session.rs`. Permite crear múltiples sesiones de juego independientes con distintos `SessionId`, cada una con su propio `TcpHostTransport`, todas escuchando en el mismo puerto base con rutas de sesión `/session/{id}`. Añadir el test que crea dos sesiones simultáneas y verifica que los eventos de una no llegan a la otra.

**110.** Implementar **Pausa/Reanudación** del estado de sesión en `open_table_engine/src/session.rs`. Añadir `Session::pause() -> Result<(), EngineError>` y `Session::resume() -> Result<(), EngineError>`. Cuando la sesión está pausada, `process_command` rechaza todos los comandos con `EngineError::SessionPaused`. Añadir los tests `test_pausa_rechaza_comandos` y `test_reanudar_permite_comandos_nuevamente`.

---

## 15. Godot — UI de los 12 Juegos

**111.** Crear la **UI del tablero de Ajedrez** en `godot_project/chess_board.gd`. Un `GridContainer` de 8×8 con texturas de casillas alternadas claras/oscuras. Para cada `PieceMovedEvent` recibido del bridge, mover el sprite de la pieza desde la casilla origen a la destino. Los movimientos legales del jugador local deben resaltarse cuando se selecciona una pieza (círculos semitransparentes en destinos válidos). Conectar la señal `game_over` para mostrar el `game_over_overlay.tscn`.

**112.** Crear la **UI del tablero de Go** en `godot_project/go_board.gd`. Un `GridContainer` de 9×9 donde las casillas son intersecciones (el clic aterriza en el punto más cercano). Mostrar piedras negras/blancas como `TextureRect` en cada intersección. Al recibir `StonesCapturedEvent`, animar la desaparición de las piedras capturadas. Al recibir `GameOverEvent`, mostrar el marcador de territorio calculado.

**113.** Crear la **UI de la mano de UNO** en `godot_project/uno_board.gd`. Un `HBoxContainer` horizontal con las cartas de la mano del jugador local como `TextureButton`s. Resaltar en verde las cartas jugables (color o valor coinciden con el descarte). Al hacer clic en una carta, llamar `bridge.send_command(...)` con el índice. Mostrar la pila de descarte visible y la pila de robo como contador.

**114.** Crear la **UI del tablero de Shogi** en `godot_project/shogi_board.gd`. Un `GridContainer` de 9×9 con piezas representadas por `Label`s con kanji japonés sobre rectángulos. Añadir paneles laterales para mostrar las piezas capturadas en mano (`board.hands`). Al hacer clic en la mano, seleccionar la pieza para hacer drop; al hacer clic en el tablero, ejecutar el drop con `DropPieceCommand`.

**115.** Crear la **UI del tablero de Xiangqi** en `godot_project/xiangqi_board.gd`. Un panel con fondo de tablero Xiangqi (líneas, río central, palacios), con piezas circulares posicionadas con `Control.position` sobre la imagen de fondo. Conectar clics para seleccionar y mover piezas, enviando `MovePieceCommand` con las coordenadas de intersección correctas.

**116.** Crear la **UI del tablero de Ludo** en `godot_project/ludo_board.gd`. Un tablero visual con el camino estándar de 52 casillas, las 4 zonas de color de inicio, y la columna de casa de cada jugador. Los tokens son `TextureButton`s. Al recibir `DiceRolledEvent`, animar el dado; al recibir `TokenMovedEvent`, mover el token correspondiente. Soportar hasta 4 jugadores.

**117.** Crear la **UI del tablero de Monopoly** en `godot_project/monopoly_board.gd`. Un panel rectangular con las 16+ propiedades del juego simplificado. Mostrar los jugadores como fichas de colores. Al recibir `PlayerMovedEvent`, animar la ficha. Al recibir `PendingPurchaseEvent`, mostrar un diálogo `BuyCompanyCommand`. Mostrar el dinero de cada jugador actualizado en tiempo real.

**118.** Crear la **UI del tablero de Damas Chinas** en `godot_project/chinese_checkers_board.gd`. Un hexágono de 61 puntos renderizado con `Polygon2D`s o una imagen de fondo. Las canicas son `TextureButton`s. Al seleccionar una canica propia, resaltar las casillas de destino válidas (un salto o cadena de saltos). Conectar `TokenMovedEvent` para animar el movimiento.

**119.** Crear la **UI de Mille Bornes** en `godot_project/mille_bornes_board.gd`. Una escena con: (a) la mano de cartas del jugador local (HBoxContainer), (b) el tableau (área de juego del jugador con Hazards/Remedies activos), (c) la pila de distancia, y (d) el tablero del oponente en modo reducido. Conectar las señales del bridge para actualizar cada sección.

**120.** Crear la **UI del tablero de Backgammon** en `godot_project/backgammon_board.gd`. Un panel con 24 puntos triangulares alternados en dos colores. Las fichas (checkers) son `TextureButton`s apilados verticalmente. Al recibir `CheckerMovedEvent`, animar la ficha de un punto al siguiente. Mostrar la barra central y la zona de bearing-off.

**121.** Crear la **UI del juego Crisis** en `godot_project/crisis_board.gd`. Un tablero circular o lineal con las empresas del juego simplificado. Los jugadores son tokens de colores. Al recibir `PlayerMovedEvent`, mover el token. Al recibir `CompanyPurchasedEvent`, marcar la empresa con el color del dueño. Mostrar el dinero de cada jugador. Conectar las señales de `TaxPaidEvent`, `CrisisOccurredEvent`, `OpportunityGainedEvent`.

**122.** Añadir **tests headless de GDScript** para 5 juegos adicionales. Crear los archivos `godot_project/tests/chess_smoke.gd`, `godot_project/tests/shogi_smoke.gd`, `godot_project/tests/uno_smoke.gd`, `godot_project/tests/backgammon_smoke.gd`, y `godot_project/tests/xiangqi_smoke.gd` siguiendo el patrón de `bridge_smoke.gd`. Cada test arranca una partida local, ejecuta 2 movimientos, y verifica que los eventos correspondientes son recibidos por las señales del bridge.

---

## 16. Godot — Infraestructura UI

**123.** Implementar una **capa de input drag-and-drop** reutilizable en `godot_project/drag_drop_layer.gd`. Un `Control` que detecta `_gui_input` para mouse/touch, y expone señales `piece_drag_started(from: Vector2i)` y `piece_dropped(to: Vector2i)`. Las escenas de tablero grid-based (ajedrez, shogi, damas, etc.) deben instanciarlo como hijo y conectar estas señales en lugar de manejar input directamente. Reducir la lógica de input repetida en cada `board.gd`.

**124.** Adaptar el **input táctil (touch)** en todos los tableros para dispositivos móviles. Añadir en `drag_drop_layer.gd` soporte para `InputEventScreenTouch` y `InputEventScreenDrag`. El primer toque selecciona la pieza (resalta destinos), el segundo toque en un destino ejecuta el movimiento. Verificar que funciona en `chess_board.gd` y `checkers_board.gd` con Redot/Godot en modo simulación de pantalla táctil.

**125.** Implementar un **sistema de temas de tablero** con 2 variantes. Crear `godot_project/board_theme.gd` con un recurso de Godot (`@export var light_color: Color`, `dark_color`, `piece_font`, `background_texture`). Implementar el tema "Madera Clásica" y el tema "Moderno Minimal". Los tableros `chess_board.gd`, `checkers_board.gd`, y `go_board.gd` deben cargar el tema desde un `Autoload` `ThemeManager`.

**126.** Crear un **widget indicador de turno** en `godot_project/turn_indicator.gd`. Un `HBoxContainer` con: un `ColorRect` del color del jugador en turno, un `Label` con el nombre del jugador, y una barra de progreso `ProgressBar` que muestra el tiempo restante si hay timer activo. Se actualiza al conectarse a las señales `turn_changed(player_id)` del bridge. Instanciar en todos los tableros como nodo hijo.

**127.** Crear un **overlay de estado de red** en `godot_project/network_status_hud.gd`. Un `CanvasLayer` que muestra un banner en la parte superior con tres estados: "Conectado" (verde), "Reconectando..." (amarillo, parpadeante), "Desconectado" (rojo). Se actualiza conectándose a las señales `connection_lost` y `reconnected` del bridge. Instanciar en `checkers_board.gd` y `chess_board.gd` como prueba.

**128.** Crear la **escena de configuración** `godot_project/settings_menu.tscn` con: `HSlider` para volumen de efectos de sonido, `OptionButton` para selección de tema de tablero, y campos `LineEdit` para los nombres de los jugadores (se guardan en `ProjectSettings` o en un archivo de configuración local). Un botón "Guardar" escribe los cambios y cierra el menú.

**129.** Implementar la **pantalla de transición** entre escenas en `godot_project/scene_transition.gd`. Un `AnimationPlayer` que hace fade-in/fade-out negro de 0.2 segundos al cambiar de escena. Exponer `transition_to(scene_path: String)` en el `Autoload` `SceneManager`. Reemplazar todos los `get_tree().change_scene_to_file()` directos por llamadas a `SceneManager.transition_to(...)`.

**130.** Implementar un sistema de **localización básico** en `godot_project`. Crear dos archivos CSV de traducción: `godot_project/translations/es.csv` (español) y `godot_project/translations/en.csv` (inglés). Añadir las claves para todos los textos de la UI (nombres de juegos, botones, mensajes de error). Configurar el proyecto Godot para cargar ambos CSV como `Translation` resources y seleccionar el idioma activo desde `settings_menu.tscn`.

---

## 17. Testing — Expansión

**131.** Añadir el test de integración completo **"Ludo de 4 jugadores hasta victoria"** en `ludo_game/tests/game_rules.rs`. Usar seeds deterministas para simular una partida completa hasta que un jugador llegue al goal con sus 4 tokens. Verificar que `GameOverEvent { winner: Some(P1) }` se emite y que el orden de turnos fue correcto a lo largo de la partida.

**132.** Añadir el test de integración **"Monopoly: primer jugador en quebrar"** en `monopoly_game/tests/game_rules.rs`. Configurar una sesión de 3 jugadores. Forzar usando `resource_mut` que P2 tenga solo 50 de dinero y caiga en una propiedad cara de P1. Verificar `BankruptcyEvent { player: P2 }`, la transferencia de propiedades, y que el ciclo de turnos continúa entre P1 y P3.

**133.** Añadir el test de integración **"Go: partida completa hasta scoring de territorio"**. En `go_game/tests/game_rules.rs`, configurar un tablero 9×9 con posición de territorio clara (cuadrante completo de cada jugador), hacer doble pass, marcar las muertas, confirmar, y verificar que `GameOverEvent.winner` coincide con el jugador de mayor territorio.

**134.** Añadir tests de **proptest para Backgammon** en `backgammon_game/tests/property.rs`. Crear el test `cualquier_movimiento_valido_no_paniquea` que genera `(die1, die2, checker_index)` arbitrarios, los aplica a una sesión Backgammon, y verifica que el resultado es siempre `Ok` o `Err(EngineError::InvalidCommand)`. Añadir `proptest` a `backgammon_game/Cargo.toml [dev-dependencies]`.

**135.** Añadir tests de **proptest para Chinese Checkers** en `chinese_checkers_game/tests/property.rs`. Crear el test `movimiento_aleatorio_nunca_paniquea` con `(from_index, to_index)` aleatorios en el rango del tablero de 61 puntos. Verificar que nunca ocurre un panic. Añadir `proptest` a `chinese_checkers_game/Cargo.toml [dev-dependencies]`.

**136.** Añadir un **test de caos de red** en `open_table_transport_tcp/tests/chaos.rs`. Crear un test que inicia un host+client de damas, juega 5 movimientos en una tarea async, e inyecta desconexiones aleatorias (con `tokio::time::sleep` + drop del stream) mientras se juegan comandos. Verificar que después de reconectarse el resync entrega todos los eventos perdidos sin panic ni estado corrupto.

**137.** Añadir un **test de contrato cross-crate** en `open_table_engine/tests/api_contract.rs`. Verificar que los 12 constructores de sesión (`new_checkers_session`, `new_chess_session`, etc.) satisfacen el mismo contrato: retornan `Session`, tienen al menos 2 jugadores válidos en `TurnResource`, y `current_player()` es uno de los jugadores pasados. Un único loop de test que instancia cada juego y hace las tres aserciones.

**138.** Añadir un **test de round-trip de snapshot** para todos los juegos en `open_table_engine/tests/snapshot_roundtrip.rs`. Para cada uno de los 12 juegos, crear una sesión, aplicar 3 comandos válidos, llamar a `snapshot()`, crear una sesión desde el snapshot con `from_snapshot()`, y verificar que `current_tick()`, `current_player()`, y el hash del estado del mundo coinciden. Requiere que el prompt 2 esté implementado.

**139.** Añadir el **test headless de GDScript para el tablero de Ludo** en `godot_project/tests/ludo_smoke.gd`. Instanciar `OpenTableBridge`, llamar `bridge.start_local_match_ludo(...)`, simular un `RollAndMoveCommand` enviando el comando por la señal del bridge, y verificar que la señal `token_moved` del bridge emite las coordenadas correctas. Ejecutar con `redot --headless --path godot_project --script res://tests/ludo_smoke.gd`.

**140.** Añadir el **test headless de GDScript para el tablero de Backgammon** en `godot_project/tests/backgammon_smoke.gd`. Instanciar `OpenTableBridge`, iniciar una partida local de Backgammon, enviar `RollDiceCommand` seguido de `MoveCheckerCommand`, y verificar la señal `checker_moved`. Verificar también que un movimiento inválido no produce crash sino que emite una señal de error del bridge.

**141.** Añadir **benchmarks de rendimiento** en `open_table_engine/benches/session_throughput.rs` usando `criterion`. Medir el throughput de `process_command` en una sesión de damas (movimientos simples, sin red): cuántos comandos por segundo puede procesar. Añadir `criterion` a `open_table_engine/Cargo.toml [dev-dependencies]` y documentar la línea base en `NEXT_STEPS.md`.

**142.** Añadir el **test de reconexión TCP para todos los juegos**. Extender `open_table_transport_tcp/tests/reconnection.rs` con un parametrizado que corre el mismo flujo (Host inicia sesión, Client se conecta, se juega 1 comando, Client se desconecta, Client se reconecta, verifica resync) para Checkers, Chess, y Go. Verificar que los tipos de eventos de cada juego sobreviven el round-trip JSON sin errores de deserialización.

**143.** Añadir un **test de memoria** para detectar leaks en sesiones de larga duración. Crear `open_table_engine/tests/memory_stability.rs` que instancia una sesión de damas y procesa 10.000 comandos válidos en loop (usando `SessionId` creciente y boards reiniciados cada 100 movimientos). Medir la memoria RSS antes y después con `proc_self_statm` (Linux) y verificar que no crece más de 5 MB. Documentar el test como `#[ignore]` para no correr por defecto en CI.

---

## 18. Mobile — Platform

**144.** Completar el **AndroidManifest.xml** para el plugin Nearby en `platform_plugins/android/src/main/AndroidManifest.xml`. Añadir los permisos `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION` y el `<uses-feature android:name="android.hardware.bluetooth_le">`. Documentar en `platform_plugins/android/README.md` para qué versión de Android (API ≥ 31) se requiere cada permiso.

**145.** Completar el **Info.plist** del plugin iOS en `platform_plugins/ios/`. Añadir las claves `NSBonjourServices` (array con `_opentable._tcp`), `NSLocalNetworkUsageDescription` (descripción de uso), y `NSBluetoothAlwaysUsageDescription`. Añadir el entitlement `com.apple.developer.networking.multipeer-connectivity` en `platform_plugins/ios/OpenTableMultipeer.entitlements`. Documentar el proceso en `platform_plugins/ios/README.md`.

**146.** Implementar un **servicio en background para Android** en `platform_plugins/android/src/OpenTableNearbyService.kt`. Crear un `ForegroundService` que mantiene la conexión Nearby activa cuando la app está minimizada. Registrarlo en el `AndroidManifest.xml`. Desde GDScript, el `NativeP2PAdapter` debe iniciar y detener el servicio a través del plugin. Documentar el ciclo de vida del servicio en el README de Android.

**147.** Implementar el **modo background para iOS** en `platform_plugins/ios/OpenTableMultipeer.swift`. Usar `UIApplication.beginBackgroundTask` para solicitar tiempo de ejecución adicional cuando la app va a background. Conectar la notificación `UIApplicationDidEnterBackgroundNotification` y `UIApplicationWillEnterForegroundNotification` para pausar/reanudar la sesión Multipeer limpiamente. Documentar limitaciones (máximo 30s de background) en el README de iOS.

**148.** Implementar el **escaneo de QR con la cámara del dispositivo** en Godot. Crear `godot_project/qr_scanner.gd` que usa el plugin de cámara nativa (si existe) o instruye al usuario a ingresar el código manualmente en un `LineEdit`. Al decodificar el QR, extraer la IP y puerto y llamar `bridge.connect_as_client(ip, port)`. Añadir un botón "Escanear QR" en `host_lobby.gd` que abre el scanner.

**149.** Implementar **detección de modo offline** en `godot_project/native_p2p_adapter.gd`. Añadir un timer de 5 segundos que verifica periódicamente si hay conectividad (usando `is_native_connected()` del bridge). Si se detecta modo offline sin sesión activa, mostrar un banner "Sin conexión — solo juego local disponible" y deshabilitar los botones de Host/Client TCP. Reactivarlos cuando se restaura la conectividad.

**150.** Añadir un **test de integración del plugin Android con mock** en `platform_plugins/android/src/OpenTableNearbyPluginTest.kt`. Usando JUnit + Mockito, crear un test que verifica que al llamar `sendBytes("tag", byteArrayOf(1, 2, 3))`, se invoca `Nearby.getConnectionsClient(context).sendPayload(endpointId, Payload.fromBytes(...))` con los bytes correctos. Documentar cómo ejecutar los tests de Android con `./gradlew test`.

---

## 19. DevOps y Documentación

**151.** Crear el **script de sincronización de versiones** en `tools/bump_version.sh`. Lee la versión actual de `open_table_core/Cargo.toml`, la incrementa (semver: patch por defecto, con flags `--minor` y `--major`), y actualiza todos los `Cargo.toml` del workspace con la nueva versión. Usar `sed` con la etiqueta `version = "X.Y.Z"`. Al terminar, ejecuta `cargo check --workspace` para confirmar que no hay inconsistencias.

**152.** Configurar un **pre-commit hook** en `.git/hooks/pre-commit` (o vía `cargo-husky` como dev-dependency). El hook ejecuta `cargo fmt --check --all` y `cargo clippy --workspace -- -D warnings`. Si alguno falla, cancela el commit con un mensaje de error descriptivo. Documentar en `CONTRIBUTING.md` cómo instalar el hook en un nuevo clon con `make install-hooks`.

**153.** Generar y configurar **rustdoc para las APIs públicas** del workspace. Añadir el target `docs` en el `Makefile` que ejecuta `cargo doc --no-deps --workspace --document-private-items`. Añadir atributos `#![doc = include_str!("../README.md")]` en `open_table_core/src/lib.rs` y `open_table_engine/src/lib.rs` para que el README del crate aparezca como documentación de nivel de crate. Verificar que `cargo doc` no produce warnings.

**154.** Crear el archivo **`CONTRIBUTING.md`** en la raíz del workspace con las secciones: (1) Requisitos de entorno, (2) Cómo añadir un nuevo juego paso a paso (crear crate, registrar en workspace, implementar el trait mínimo, añadir tests, añadir el constructor a `OpenTableBridge`), (3) Convenciones de nombres (eventos, comandos, resources en español → snake_case inglés), (4) Estándar de cobertura mínima (65% branch), y (5) Cómo ejecutar los tests de Godot headless.

**155.** Crear las **referencias de reglas de juego** en `docs/rules/`. Un archivo markdown por juego (12 archivos: `checkers.md`, `chess.md`, etc.) con: resumen de las reglas implementadas, las simplificaciones aplicadas respecto al juego estándar, y una tabla de comandos/eventos públicos del crate. Enlazar desde `README.md` en la tabla de estado de juegos.

**156.** Actualizar **`ARCHITECTURE.md`** con diagramas Mermaid. Añadir: (1) un diagrama de secuencia del flujo completo Host→Command→Event→Client con reconexión, (2) un diagrama de componentes con los 20 crates y sus dependencias, y (3) un diagrama de estado de `Session` (Idle → Playing → Paused → GameOver). Verificar que GitHub renderiza los diagramas correctamente.

**157.** Crear el **documento de modelo de amenazas** en `docs/security/threat_model.md`. Cubrir: (1) quién controla el host (único punto de verdad), (2) qué evita comandos de jugadores no autorizados (validación de `PlayerId` con token CSPRNG), (3) riesgos de DoS por comandos maliciosos (rate limiting del prompt 101), (4) privacidad de eventos (Visibility filtering), y (5) limitaciones conocidas (sin cifrado TLS en el transporte TCP).

**158.** Añadir la **guía de profiling de rendimiento** en `docs/performance/profiling.md`. Documentar cómo generar un flamegraph de `Session::process_command` usando `cargo flamegraph` (instalar con `cargo install flamegraph`). Incluir el comando exacto: `cargo flamegraph --bin <bench_binary> -o flamegraph.svg`. Documentar la línea base medida (throughput del prompt 141) y los cuellos de botella identificados en `bevy_ecs` despatch.

**159.** Configurar **`cargo publish`** para `open_table_core` en `open_table_core/Cargo.toml`. Añadir los campos `description`, `license = "MIT OR Apache-2.0"`, `repository`, `keywords`, `categories`. Crear `open_table_core/LICENSE-MIT` y `open_table_core/LICENSE-APACHE`. Verificar con `cargo publish --dry-run -p open_table_core` que no hay errores. Documentar el proceso de release en `CONTRIBUTING.md`.

**160.** Añadir la **automatización de cobertura en CI** al workflow de GitHub Actions (`.github/workflows/ci.yml`, ya creado en el prompt 38b). Añadir un step que instala `cargo-llvm-cov`, ejecuta `cargo llvm-cov --workspace --lcov --output-path lcov.info`, y publica el reporte usando la action `codecov/codecov-action@v4`. Añadir un badge de cobertura en `README.md` y configurar el umbral de falla en 65% de cobertura de líneas.
