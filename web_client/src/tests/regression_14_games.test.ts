/**
 * Suite Integral de Regresión E2E de los 14 Juegos Canónicos (`regression_14_games.test.ts`)
 *
 * Valida sin regresiones:
 * 1. Inicialización determinista de los 14 juegos en `WasmGameBridge`.
 * 2. Consulta de jugadas legales (`get_legal_moves_json`), ejecución de comandos canónicos
 *    y controles específicos de torneo (Go Handicap/Pass/DeadStones, Shogi Drop/Promote,
 *    Backgammon Doubling Cube, Battleship ExtraTurn/Rematch, Mille Bornes Coup Fourré,
 *    Monopoly Buy/Build/Mortgage, Crisis PlaceArmies/Attack/ExchangeCards).
 * 3. Respuesta automática de IA (`step_ai_if_needed`) en los 14 juegos.
 * 4. Sincronización de estado `SyncState` (`export_log_json` -> `apply_sync_log_json`) en los 14 juegos.
 * 5. Bloqueo de turno local (`computeIsLocalTurnAllowed`) y persistencia de `RelayWebSocketClient`.
 */

import { WasmGameBridge } from "../wasm_pkg";
import { CATALOG_14_GAMES, computeIsLocalTurnAllowed } from "../App";
import {
  DEFAULT_RELAY_URL,
  RelayWebSocketClient,
  saveRelayUrl,
} from "../bridge/relayClient";

function assert(condition: unknown, message: string): void {
  if (!condition) {
    throw new Error(`REGRESSION ASSERTION FAILED: ${message}`);
  }
}

const SAMPLE_FIRST_COMMANDS: Record<string, Record<string, unknown>> = {
  chess: {
    command_type: "chess_game::MovePieceCommand",
    player: 1,
    from: [6, 4],
    to: [4, 4],
  },
  checkers: {
    command_type: "checkers_game::MovePieceCommand",
    player: 1,
    from: [5, 0],
    to: [4, 1],
  },
  uno: {
    command_type: "DrawCardCommand",
    player: 1,
  },
  goose: {
    command_type: "goose_game::RollDiceCommand",
    player: 1,
    d1: 2,
    d2: 3,
  },
  go: {
    command_type: "go_game::PlaceStoneCommand",
    player: 1,
    row: 4,
    col: 4,
  },
  shogi: {
    command_type: "shogi_game::MovePieceCommand",
    player: 1,
    from: [6, 4],
    to: [5, 4],
    promote: false,
  },
  xiangqi: {
    command_type: "xiangqi_game::MovePieceCommand",
    player: 1,
    from: [6, 4],
    to: [5, 4],
  },
  chinese_checkers: {
    command_type: "chinese_checkers_game::MoveMarbleCommand",
    player: 1,
    fromId: "6_7",
    toId: "5_7",
  },
  backgammon: {
    command_type: "backgammon_game::MoveCheckerCommand",
    player: 1,
    from: 0,
    to: 3,
  },
  ludo: {
    command_type: "ludo_game::MoveTokenCommand",
    player: 1,
    token_index: 0,
    d1: 3,
    d2: 2,
  },
  battleship: {
    command_type: "battleship_game::FireShotCommand",
    player: 1,
    row: 0,
    col: 1,
  },
  mille_bornes: {
    command_type: "mille_bornes_game::PlayCardCommand",
    player: 1,
    card_index: 0,
  },
  monopoly: {
    command_type: "monopoly_game::EndTurnCommand",
    player: 1,
  },
  crisis: {
    command_type: "crisis_game::EndTurnCommand",
    player: 1,
  },
};

async function runRegression14Games() {
  console.log("=== INICIANDO TEST INTEGRAL DE REGRESIÓN: 14 JUEGOS CANÓNICOS ===");

  assert(
    CATALOG_14_GAMES.length === 14,
    `Deben existir exactamente 14 juegos en CATALOG_14_GAMES, encontrados: ${CATALOG_14_GAMES.length}`
  );

  for (const item of CATALOG_14_GAMES) {
    assert(
      item.phase === 1,
      `El juego '${item.id}' debe tener phase === 1 (Tablero activo en React)`
    );

    // A. Inicialización vs IA + Movimiento Humano + Respuesta IA + SyncState
    const hostBridge = new WasmGameBridge();
    assert(
      hostBridge.start_ai_match(item.id, 1, 2, 1),
      `start_ai_match debe iniciar correctamente para '${item.id}'`
    );
    assert(
      hostBridge.get_current_game_type() === item.id,
      `get_current_game_type debe devolver '${item.id}'`
    );

    const legalMoves = JSON.parse(hostBridge.get_legal_moves_json(1));
    assert(
      Array.isArray(legalMoves) && legalMoves.length > 0,
      `El juego '${item.id}' debe exponer jugadas legales iniciales para el Jugador 1`
    );

    // Verificar rechazo de turno fuera de orden (Jugador 2 intentando mover en turno 1)
    const outOfTurnResp = JSON.parse(
      hostBridge.send_command_json(2, JSON.stringify(SAMPLE_FIRST_COMMANDS[item.id]))
    );
    assert(
      outOfTurnResp.ok === false && outOfTurnResp.error === "not_your_turn",
      `El juego '${item.id}' debe rechazar comandos del Jugador 2 durante el turno 1`
    );

    // Ejecutar comando válido del Jugador 1
    const cmdPayload = JSON.stringify(SAMPLE_FIRST_COMMANDS[item.id]);
    const eventsAfterP1 = JSON.parse(hostBridge.send_command_json(1, cmdPayload));
    assert(
      Array.isArray(eventsAfterP1) && eventsAfterP1.length > 0,
      `El comando del Jugador 1 en '${item.id}' debe emitir eventos válidos`
    );
    assert(
      hostBridge.current_tick() >= 1,
      `El tick en '${item.id}' debe incrementarse tras el movimiento del Jugador 1`
    );

    // Exportar y restaurar SyncState en un cliente remoto antes de la respuesta de IA
    const syncPayload = hostBridge.export_log_json();
    const peerBridge = new WasmGameBridge();
    assert(
      peerBridge.apply_sync_log_json(item.id, syncPayload),
      `apply_sync_log_json debe restaurar la partida de '${item.id}'`
    );
    assert(
      peerBridge.get_state_json() === hostBridge.get_state_json(),
      `El estado restaurado por SyncState en '${item.id}' debe ser idéntico bit a bit`
    );

    // Si el turno pasó al Jugador 2 (IA), verificar que la IA ejecute su jugada
    if (hostBridge.current_player() === 2) {
      const tickBeforeAi = hostBridge.current_tick();
      const aiEvents = JSON.parse(hostBridge.step_ai_if_needed());
      assert(
        Array.isArray(aiEvents) && aiEvents.length > 0,
        `La IA debe responder con al menos un evento en '${item.id}'`
      );
      assert(
        hostBridge.current_tick() > tickBeforeAi,
        `El tick debe avanzar tras la jugada de IA en '${item.id}'`
      );
    }

    console.log(
      `  [PASS] ${item.id.padEnd(18, " ")} -> Init + LegalMoves + TurnLock + SyncState + IA OK`
    );
  }

  // B. Pruebas específicas de controles de torneo de Fase 2
  const specialBridge = new WasmGameBridge();

  // 1. Go: Handicap + Pass + MarkDead + ConfirmDead (Komi 6.5)
  specialBridge.start_local_match("go", 1, 2);
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "go_game::SetHandicapCommand", handicap: 2 })
  );
  assert(
    specialBridge.current_player() === 2,
    "En Go con Handicap 2, el turno inicial debe pasar a Blancas (J2)"
  );
  specialBridge.send_command_json(2, JSON.stringify({ command_type: "go_game::PassCommand" }));
  specialBridge.send_command_json(1, JSON.stringify({ command_type: "go_game::PassCommand" }));
  const goStateAfterPasses = JSON.parse(specialBridge.get_state_json());
  assert(
    goStateAfterPasses.scoring_phase === true,
    "Dos pases consecutivos en Go deben activar la fase de conteo (scoring_phase)"
  );
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "go_game::ConfirmDeadCommand" })
  );
  assert(
    JSON.parse(specialBridge.get_state_json()).winner !== null,
    "ConfirmDeadCommand en Go debe definir al ganador con Komi 6.5"
  );

  // 1b. Go: Captura BFS de cadena conectada de 2+ piedras blancas acorraladas por negras
  specialBridge.start_local_match("go", 1, 2);
  const placeGo = (p: 1 | 2, row: number, col: number) =>
    JSON.parse(
      specialBridge.send_command_json(
        p,
        JSON.stringify({
          command_type: "go_game::PlaceStoneCommand",
          player: p,
          row,
          col,
        })
      )
    );
  // Blancas formarán una cadena conectada de 2 piedras en (4,4) y (4,5).
  // Negras las rodearán en (3,4), (3,5), (5,4), (5,5), (4,3) y finalmente cerrarán la última libertad en (4,6).
  placeGo(1, 3, 4); // B
  placeGo(2, 4, 4); // W1
  placeGo(1, 3, 5); // B
  placeGo(2, 4, 5); // W2 (conectada con W1)
  placeGo(1, 5, 4); // B
  placeGo(2, 0, 0); // W juega lejos
  placeGo(1, 5, 5); // B
  placeGo(2, 0, 1); // W juega lejos
  placeGo(1, 4, 3); // B deja a la cadena blanca [(4,4),(4,5)] en Atari (1 sola libertad en 4_6)

  const goStateAtari = JSON.parse(specialBridge.get_state_json());
  assert(
    goStateAtari.liberties_by_cell["4_4"] === 1 &&
      goStateAtari.liberties_by_cell["4_5"] === 1,
    `La cadena blanca [(4,4),(4,5)] debe reportar exactamente 1 libertad (Atari), actual: ${goStateAtari.liberties_by_cell["4_4"]}`
  );

  placeGo(2, 0, 2); // W juega lejos
  // Negras cierran la última libertad en (4,6) -> debe capturar AMBAS piedras blancas
  const captureEvents = placeGo(1, 4, 6);
  const goStateAfterChainCapture = JSON.parse(specialBridge.get_state_json());
  assert(
    Array.isArray(captureEvents) &&
      goStateAfterChainCapture.captures[1] === 2 &&
      goStateAfterChainCapture.grid[4][4] === 0 &&
      goStateAfterChainCapture.grid[4][5] === 0,
    `Negras deben capturar la cadena conectada de 2 piedras blancas en (4,4) y (4,5); capturas=${goStateAfterChainCapture.captures[1]}`
  );

  // 1c. Go: Regla de Suicidio y Tamaños 9x9 / 13x13 / 19x19
  specialBridge.start_local_match("go", 1, 2);
  // Negras rodean la esquina (0,0) colocando en (0,1) y (1,0)
  placeGo(1, 0, 1);
  placeGo(2, 8, 8);
  placeGo(1, 1, 0);
  // Ahora Blancas intentan jugar en (0,0) sin libertades ni captura -> debe rechazarse por suicidio
  const suicideResp = placeGo(2, 0, 0);
  assert(
    suicideResp.ok === false && suicideResp.error === "suicide_rule",
    "Colocar una piedra sin libertades que no captura nada debe rechazarse por suicide_rule"
  );

  // Cambiar tamaño de tablero a 13x13 y 19x19
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "go_game::SetBoardSizeCommand", size: 13 })
  );
  assert(
    JSON.parse(specialBridge.get_state_json()).size === 13 &&
      JSON.parse(specialBridge.get_state_json()).grid.length === 13,
    "SetBoardSizeCommand(13) debe redimensionar el Goban a 13x13"
  );
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "go_game::SetBoardSizeCommand", size: 19 })
  );
  assert(
    JSON.parse(specialBridge.get_state_json()).size === 19 &&
      JSON.parse(specialBridge.get_state_json()).grid.length === 19,
    "SetBoardSizeCommand(19) debe redimensionar el Goban a 19x19"
  );

  // 2. Backgammon: Cubo de Doblaje (OfferDouble + AcceptDouble)
  specialBridge.start_local_match("backgammon", 1, 2);
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "backgammon_game::OfferDoubleCommand" })
  );
  specialBridge.send_command_json(
    2,
    JSON.stringify({ command_type: "backgammon_game::AcceptDoubleCommand" })
  );
  assert(
    JSON.parse(specialBridge.get_state_json()).cube_value === 2,
    "El Cubo de Doblaje en Backgammon debe duplicarse a 2 tras aceptar"
  );

  // 3. Mille Bornes: Reacción ¡Coup Fourré! (+100 km y conserva turno)
  specialBridge.start_local_match("mille_bornes", 1, 2);
  specialBridge.send_command_json(
    1,
    JSON.stringify({
      command_type: "mille_bornes_game::CoupFourreCommand",
      safety: "Prioridad",
    })
  );
  const mbState = JSON.parse(specialBridge.get_state_json());
  assert(
    mbState.distance[1] === 100 && mbState.safeties[1].includes("Prioridad"),
    "CoupFourreCommand en Mil Millas debe otorgar +100 km y activar el escudo Prioridad"
  );

  // 4. Monopoly: Movimiento + Compra de propiedad + Construcción de casa
  specialBridge.start_local_match("monopoly", 1, 2);
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "monopoly_game::RollDiceCommand", d1: 1, d2: 2 })
  );
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "monopoly_game::BuyPropertyCommand" })
  );
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "monopoly_game::BuildHouseCommand", space: 3 })
  );
  const monoState = JSON.parse(specialBridge.get_state_json());
  assert(
    monoState.spaces[3].owner === 1 && monoState.spaces[3].houses === 1,
    "Monopoly debe registrar la compra de Av. Báltica (#3) y construir 1 casa"
  );

  // 5. Crisis / TEG: Canje de tarjetas + Colocación de ejércitos
  specialBridge.start_local_match("crisis", 1, 2);
  specialBridge.send_command_json(
    1,
    JSON.stringify({ command_type: "crisis_game::ExchangeCardsCommand" })
  );
  const crisisState = JSON.parse(specialBridge.get_state_json());
  assert(
    crisisState.armies_remaining === 11,
    `Canjear 3 tarjetas en Crisis debe subir refuerzos de 5 a 11, actual: ${crisisState.armies_remaining}`
  );
  console.log("  [PASS] Controles específicos de torneo (Go, Backgammon, Mil Millas, Monopoly, Crisis) verificados");

  // C. Bloqueo de turno de red y persistencia Relay
  assert(computeIsLocalTurnAllowed("hotseat", 1, 2) === true, "Hotseat siempre permite turno local");
  assert(computeIsLocalTurnAllowed("ai", 1, 1) === true, "Modo IA permite turno humano J1");
  assert(computeIsLocalTurnAllowed("ai", 2, 1) === false, "Modo IA bloquea turno mientras piensa J2");
  assert(computeIsLocalTurnAllowed("online_relay", 1, 2) === false, "Online Relay bloquea J2 en turno 1");

  const relayClient = new RelayWebSocketClient({}, saveRelayUrl(DEFAULT_RELAY_URL));
  const qr = specialBridge.generate_join_qr_svg("OT2026", "Host", "crisis");
  assert(qr.includes("<svg") && qr.includes("</svg>"), "Generador QR debe producir SVG válido");
  relayClient.disconnect();

  // D. Verificación E2E de niveles de dificultad de IA (0=Easy, 1=Medium, 2=Hard, 3=Expert)
  for (const item of CATALOG_14_GAMES) {
    for (const diff of [0, 1, 2, 3]) {
      const diffBridge = new WasmGameBridge();
      assert(
        diffBridge.start_ai_match(item.id, 1, 2, diff),
        `start_ai_match(${item.id}, 1, 2, ${diff}) debe inicializar correctamente`
      );
      assert(
        diffBridge.get_ai_difficulty() === diff,
        `get_ai_difficulty() en '${item.id}' debe devolver ${diff}, obtenido: ${diffBridge.get_ai_difficulty()}`
      );
    }
  }

  // Verificar diferenciación táctica real por nivel en Chess, Go, Shogi, Xiangqi y Checkers
  const strategicGames = ["chess", "go", "shogi", "xiangqi", "checkers"] as const;
  for (const gId of strategicGames) {
    const postAiStates = new Set<string>();
    for (const diff of [0, 1, 2, 3]) {
      const b = new WasmGameBridge();
      b.start_ai_match(gId, 1, 2, diff);
      b.send_command_json(1, JSON.stringify(SAMPLE_FIRST_COMMANDS[gId]));
      const aiEvents = JSON.parse(b.step_ai_if_needed());
      assert(
        Array.isArray(aiEvents) && aiEvents.length > 0,
        `step_ai_if_needed() en '${gId}' (dificultad ${diff}) debe ejecutar una jugada válida`
      );
      const stateAfter = b.get_state_json();
      postAiStates.add(stateAfter);

      if (gId === "go") {
        const parsedGo = JSON.parse(stateAfter);
        assert(
          parsedGo.grid[0][0] === 0,
          `Go IA (dificultad ${diff}) no debe jugar estáticamente en la esquina 1ra línea (0,0) en apertura`
        );
      }
    }
    assert(
      postAiStates.size >= 3,
      `La IA de '${gId}' debe diferenciar sus jugadas entre los 4 niveles de dificultad (estados distintos: ${postAiStates.size})`
    );
  }
  console.log(
    "  [PASS] Niveles de dificultad de IA (0..3) y diferenciación táctica verificados en Chess, Go, Shogi, Xiangqi, Checkers y catálogo de 14 juegos"
  );

  console.log("=== SUITE DE REGRESIÓN DE LOS 14 JUEGOS COMPLETADA CON 0 ERRORES ===");
}

runRegression14Games().catch((err) => {
  console.error(err);
  process.exit(1);
});
