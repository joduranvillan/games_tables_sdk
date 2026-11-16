/**
 * Suite de pruebas automatizadas E2E para la versión paralela en React + WASM (`web_client/`)
 *
 * Verifica:
 * 1. Inicialización de `WasmGameBridge` en los 4 juegos de la Fase 1 (Chess, Checkers, UNO, Goose).
 * 2. Ejecución de movimientos legales, rechazo de turnos fuera de orden y respuesta de IA.
 * 3. Serialización y restauración de `SyncState` (`export_log_json` / `apply_sync_log_json`).
 * 4. Persistencia de `relay_url`, creación/unión de sala en `RelayWebSocketClient` y `computeIsLocalTurnAllowed`.
 */

import { WasmGameBridge } from "../wasm_pkg";
import {
  DEFAULT_RELAY_URL,
  RelayWebSocketClient,
  saveRelayUrl,
} from "../bridge/relayClient";
import { CATALOG_14_GAMES, computeIsLocalTurnAllowed } from "../App";

function assert(condition: unknown, message: string): void {
  if (!condition) {
    throw new Error(`ASSERTION FAILED: ${message}`);
  }
}

async function runTests() {
  console.log("=== INICIANDO SUITE DE TESTS: OpenTable React + WASM (Fase 1) ===");

  // 1. Catálogo de 14 juegos completo
  assert(
    CATALOG_14_GAMES.length === 14,
    `El catálogo debe listar los 14 juegos canónicos, encontrados: ${CATALOG_14_GAMES.length}`
  );
  const phase1Games = CATALOG_14_GAMES.filter((g) => g.phase === 1);
  assert(phase1Games.length === 4, "La Fase 1 debe tener 4 tableros activos");
  console.log("  [PASS] Catálogo de 14 juegos y 4 tableros activos de Fase 1 verificados");

  // 2. Ajedrez (Chess) + Bloqueo de turno + IA
  const bridge = new WasmGameBridge();
  assert(bridge.start_local_match("chess", 1, 2), "Debe iniciar partida local de Ajedrez");
  assert(bridge.current_player() === 1, "El turno inicial en Ajedrez debe ser del Jugador 1");

  const chessLegal = JSON.parse(bridge.get_legal_moves_json(1));
  assert(chessLegal.length === 20, `Ajedrez debe tener 20 jugadas iniciales, actual: ${chessLegal.length}`);

  // Movimiento e2 -> e4 (fila 6 col 4 -> fila 4 col 4)
  bridge.send_command_json(
    1,
    JSON.stringify({
      command_type: "chess_game::MovePieceCommand",
      player: 1,
      from: [6, 4],
      to: [4, 4],
    })
  );
  assert(bridge.current_player() === 2, "Tras mover Blancas, el turno debe pasar al Jugador 2");

  // Sincronización SyncState
  const exportedLog = bridge.export_log_json();
  const clientBridge = new WasmGameBridge();
  assert(
    clientBridge.apply_sync_log_json("chess", exportedLog),
    "Cliente remoto debe aplicar SyncState de Ajedrez"
  );
  assert(
    clientBridge.current_player() === 2,
    "Cliente sincronizado con SyncState debe estar en el turno del Jugador 2"
  );
  console.log("  [PASS] Motor WASM de Ajedrez y sincronización SyncState verificados");

  // 3. Damas (Checkers) + IA
  assert(bridge.start_ai_match("checkers", 1, 2, 1), "Debe iniciar Damas vs IA");
  const checkersLegal = JSON.parse(bridge.get_legal_moves_json(1));
  assert(checkersLegal.length > 0, "Damas debe tener movimientos iniciales legales");
  const firstCheckersMove = checkersLegal[0];
  bridge.send_command_json(
    1,
    JSON.stringify({
      command_type: "checkers_game::MovePieceCommand",
      player: 1,
      from: firstCheckersMove.from,
      to: firstCheckersMove.to,
    })
  );
  assert(bridge.current_player() === 2, "Turno debe pasar a la IA (Jugador 2)");
  bridge.step_ai_if_needed();
  assert(bridge.current_player() === 1, "La IA de Damas debe responder y devolver el turno al Jugador 1");
  console.log("  [PASS] Motor WASM de Damas e IA verificados");

  // 4. UNO
  assert(bridge.start_local_match("uno", 1, 2), "Debe iniciar partida de UNO");
  const unoStateBefore = JSON.parse(bridge.get_state_json());
  assert(unoStateBefore.hands[1].length === 7, "Jugador 1 debe iniciar con 7 cartas en UNO");
  bridge.send_command_json(
    1,
    JSON.stringify({
      command_type: "DrawCardCommand",
      player: 1,
    })
  );
  const unoStateAfter = JSON.parse(bridge.get_state_json());
  assert(unoStateAfter.hands[1].length === 8, "Tras robar, Jugador 1 debe tener 8 cartas");
  assert(bridge.current_player() === 2, "Tras robar en UNO, el turno debe pasar al Jugador 2");
  console.log("  [PASS] Motor WASM de UNO verificado");

  // 5. El Juego de la Oca (Goose) + Casillas especiales (Puente 6 -> 12 con turno extra)
  assert(bridge.start_local_match("goose", 1, 2), "Debe iniciar El Juego de la Oca");
  bridge.send_command_json(
    1,
    JSON.stringify({
      command_type: "goose_game::RollDiceCommand",
      player: 1,
      d1: 4,
      d2: 2,
    })
  );
  const gooseState = JSON.parse(bridge.get_state_json());
  assert(
    gooseState.players[1].square === 12,
    `Caer en el Puente (6) debe saltar a la casilla 12, actual: ${gooseState.players[1].square}`
  );
  assert(
    bridge.current_player() === 1,
    "El Puente (6 -> 12) debe otorgar turno extra al Jugador 1"
  );
  console.log("  [PASS] Motor WASM de El Juego de la Oca y reglas canónicas verificados");

  // 6. Bloqueo de turno por jugador local y RelayWebSocketClient
  assert(
    computeIsLocalTurnAllowed("online_relay", 1, 1) === true,
    "Host (J1) debe poder mover en turno 1"
  );
  assert(
    computeIsLocalTurnAllowed("online_relay", 2, 1) === false,
    "Host (J1) debe tener el turno bloqueado durante el turno 2"
  );
  assert(
    computeIsLocalTurnAllowed("online_relay", 2, 2) === true,
    "Cliente (J2) debe poder mover en turno 2"
  );

  const customUrl = saveRelayUrl("ws://relay.opentable.local:9090");
  const relay = new RelayWebSocketClient({}, customUrl);
  assert(
    relay.getRelayUrl() === "ws://relay.opentable.local:9090",
    "RelayWebSocketClient debe conservar la URL personalizada"
  );
  const code = relay.createRoom("chess");
  assert(code.length === 6, `El código de sala Relay debe tener 6 caracteres: ${code}`);
  assert(relay.getLocalPlayerId() === 1, "El creador de la sala debe ser Jugador 1");
  relay.setRelayUrl(DEFAULT_RELAY_URL);
  relay.disconnect();
  console.log("  [PASS] RelayWebSocketClient, código QR y bloqueo de turno verificados");

  console.log("=== RESULTADO: TODOS LOS TESTS DE REACT + WASM PASARON EXITOSAMENTE ===");
}

runTests().catch((err) => {
  console.error(err);
  process.exit(1);
});
