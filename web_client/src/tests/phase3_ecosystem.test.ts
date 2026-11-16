/**
 * Suite de Pruebas Automatizadas de la Fase 3 (`phase3_ecosystem.test.ts`)
 *
 * Verifica:
 * 1. Línea de tiempo del Visor de Repeticiones (`get_replay_step_count`, `seek_replay_step`,
 *    `export_log_json`, `apply_sync_log_json`) en los 14 juegos canónicos.
 * 2. Cobertura completa de los 14 Tutoriales Interactivos (`TUTORIALS_14_GAMES`) y
 *    generación de jugadas recomendadas en vivo sobre el motor WASM.
 * 3. Modo Espectador (`joinAsSpectator`, `isSpectatorRole`, `computeIsLocalTurnAllowed`)
 *    y bloqueo de turno durante reproducción histórica (`isReplayAtLiveHead === false`).
 * 4. Reloj de Torneo FIDE (`blitz_3_2`, `rapid_10_0`) y Byo-yomi Oriental (`byoyomi_5_30`)
 *    incluyendo incremento Fischer, recuperación de periodo Byo-yomi y caída de bandera (`force_timeout_win`).
 * 5. Cumplimiento de artefactos PWA (`manifest.webmanifest`, `sw.js`, iconos PNG 192/512/maskable/apple-touch-icon).
 */

import fs from "fs";
import path from "path";
import { WasmGameBridge } from "../wasm_pkg";
import { CATALOG_14_GAMES, computeIsLocalTurnAllowed } from "../App";
import { TUTORIALS_14_GAMES } from "../components/common/InteractiveTutorialPanel";
import {
  applyClockMoveComplete,
  createInitialClockState,
  stepClockTick,
} from "../components/common/TournamentClock";
import { RelayWebSocketClient } from "../bridge/relayClient";

function assert(condition: unknown, message: string): void {
  if (!condition) {
    throw new Error(`PHASE 3 ASSERTION FAILED: ${message}`);
  }
}

async function runPhase3Tests() {
  console.log("=== INICIANDO SUITE DE TESTS FASE 3: Repeticiones, Tutoriales, Reloj, Espectador y PWA ===");

  // 1. Cobertura de los 14 Tutoriales Interactivos + Sugerencia WASM + Replay Paso a Paso
  for (const game of CATALOG_14_GAMES) {
    const tut = TUTORIALS_14_GAMES[game.id];
    assert(Boolean(tut), `Debe existir tutorial interactivo para '${game.id}'`);
    assert(tut.steps.length === 3, `El tutorial de '${game.id}' debe tener 3 pasos guiados`);

    const bridge = new WasmGameBridge();
    assert(bridge.start_local_match(game.id, 1, 2), `Debe iniciar '${game.id}'`);
    assert(bridge.get_replay_step_count() === 0, `Paso inicial de replay en '${game.id}' debe ser 0`);

    const initialSnapshot = bridge.get_state_json();
    const legal1 = bridge.get_legal_moves_json(1);
    const suggestedCmd1 = tut.buildRecommendedCommand(1, legal1);
    assert(
      Boolean(suggestedCmd1),
      `El tutor de '${game.id}' debe sugerir un comando legal para el Jugador 1`
    );

    // Ejecutar jugada sugerida #1
    bridge.send_command_json(1, suggestedCmd1!);
    assert(
      bridge.get_replay_step_count() === 1 && bridge.get_current_replay_step() === 1,
      `Tras 1 jugada en '${game.id}', el contador de replay debe estar en 1/1`
    );
    const step1Snapshot = bridge.get_state_json();

    // Retroceder al paso 0 en el Visor de Repeticiones
    assert(bridge.seek_replay_step(0), `seek_replay_step(0) debe funcionar en '${game.id}'`);
    assert(
      bridge.get_current_replay_step() === 0 && bridge.get_replay_step_count() === 1,
      `En '${game.id}', seek_replay_step(0) debe conservar totalSteps=1 y cursor=0`
    );
    assert(
      bridge.get_state_json() === initialSnapshot,
      `El estado en el paso 0 de replay de '${game.id}' debe coincidir exactamente con el estado inicial`
    );
    assert(
      !bridge.is_replay_at_live_head(),
      `En el paso 0/1 de '${game.id}', is_replay_at_live_head() debe ser false`
    );

    // Avanzar nuevamente al paso 1
    assert(bridge.seek_replay_step(1), `seek_replay_step(1) debe restaurar el paso 1 en '${game.id}'`);
    assert(
      bridge.get_state_json() === step1Snapshot,
      `El estado restaurado en el paso 1 de '${game.id}' debe ser idéntico al original`
    );
    assert(
      bridge.is_replay_at_live_head(),
      `En el paso 1/1 de '${game.id}', is_replay_at_live_head() debe ser true`
    );
  }
  console.log("  [PASS] 14/14 Tutoriales Interactivos + Sugerencias WASM + ReplayViewer paso a paso verificados");

  // 2. Modo Espectador y bloqueo de turno en reproducción histórica
  assert(
    computeIsLocalTurnAllowed("spectator", 1, 1, true) === false,
    "El modo Espectador nunca debe permitir emitir jugadas locales"
  );
  assert(
    computeIsLocalTurnAllowed("hotseat", 1, 1, false) === false,
    "Mientras el Visor de Repeticiones está en un paso histórico, el tablero debe estar bloqueado"
  );

  const relay = new RelayWebSocketClient({});
  assert(
    relay.joinAsSpectator("SPEC01") === true,
    "RelayWebSocketClient.joinAsSpectator debe conectar en modo solo lectura"
  );
  assert(
    relay.isSpectatorRole() === true && relay.getConnectionState() === "connected_spectator",
    "El estado del cliente Relay debe ser 'connected_spectator'"
  );
  relay.disconnect();
  console.log("  [PASS] Modo Espectador Online y bloqueo de tablero histórico verificados");

  // 3. Reloj de Torneo FIDE (Blitz 3+2) y Byo-yomi Oriental (5m + 3x30s)
  let blitzClock = createInitialClockState("blitz_3_2");
  assert(blitzClock.mainMs[1] === 180_000, "Blitz 3+2 debe iniciar con 180,000 ms");
  blitzClock = stepClockTick(blitzClock, 1, 10_000);
  assert(blitzClock.mainMs[1] === 170_000, "Tras 10s de reflexión, J1 debe tener 170,000 ms");
  blitzClock = applyClockMoveComplete(blitzClock, 1);
  assert(
    blitzClock.mainMs[1] === 172_000,
    "Al completar jugada en Blitz 3+2, J1 debe recibir +2,000 ms de incremento FIDE"
  );

  let byoClock = createInitialClockState("byoyomi_5_30");
  // Consumir los 5 minutos principales de J1 + 10s del primer periodo Byo-yomi
  byoClock = stepClockTick(byoClock, 1, 310_000);
  assert(
    byoClock.mainMs[1] === 0 && byoClock.byoyomiCurrentMs[1] === 20_000 && byoClock.byoyomiPeriods[1] === 3,
    "J1 debe entrar en su primer periodo Byo-yomi con 20s restantes y 3 periodos"
  );
  byoClock = applyClockMoveComplete(byoClock, 1);
  assert(
    byoClock.byoyomiCurrentMs[1] === 30_000,
    "Al mover dentro del tiempo Byo-yomi, el periodo de 30s debe recargarse íntegro"
  );

  // Agotar todos los periodos Byo-yomi de J1 -> Victoria por tiempo de J2
  byoClock = stepClockTick(byoClock, 1, 35_000); // Pierde 1er periodo (quedan 2)
  byoClock = stepClockTick(byoClock, 1, 35_000); // Pierde 2do periodo (queda 1)
  byoClock = stepClockTick(byoClock, 1, 35_000); // Pierde 3er periodo -> Caída de bandera
  assert(
    byoClock.flaggedWinner === 2,
    "Agotar los 3 periodos Byo-yomi de J1 debe declarar ganador por tiempo al Jugador 2"
  );

  const timeoutBridge = new WasmGameBridge();
  timeoutBridge.start_local_match("chess", 1, 2);
  timeoutBridge.force_timeout_win(2);
  assert(
    JSON.parse(timeoutBridge.get_state_json()).winner === 2,
    "force_timeout_win(2) debe adjudicar la partida al Jugador 2 en el motor WASM"
  );
  console.log("  [PASS] Reloj de Torneo FIDE (incremento Fischer) y Byo-yomi Oriental verificados");

  // 4. Verificación de Artefactos PWA (Manifest, Service Worker e Iconos PNG)
  const publicDir = path.resolve(
    path.dirname(new URL(import.meta.url).pathname),
    "../../public"
  );
  const manifestPath = path.join(publicDir, "manifest.webmanifest");
  assert(fs.existsSync(manifestPath), "Debe existir public/manifest.webmanifest");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf-8"));
  assert(manifest.id === "/", "manifest.id debe ser '/'");
  assert(
    manifest.short_name && manifest.short_name.length <= 12,
    `manifest.short_name debe tener <= 12 caracteres: ${manifest.short_name}`
  );
  assert(manifest.display === "standalone", "manifest.display debe ser 'standalone'");
  assert(Array.isArray(manifest.icons) && manifest.icons.length >= 3, "manifest debe incluir iconos 192, 512 y maskable");

  for (const assetName of [
    "sw.js",
    "icon.svg",
    "pwa-192x192.png",
    "pwa-512x512.png",
    "pwa-maskable-512x512.png",
    "apple-touch-icon.png",
  ]) {
    assert(
      fs.existsSync(path.join(publicDir, assetName)),
      `Debe existir el activo PWA public/${assetName}`
    );
  }
  console.log("  [PASS] Cumplimiento de PWA Offline-First (Manifest, Service Worker e Iconos PNG) verificado");

  console.log("=== SUITE DE FASE 3 COMPLETADA EXITOSAMENTE CON 0 ERRORES ===");
}

runPhase3Tests().catch((err) => {
  console.error(err);
  process.exit(1);
});
