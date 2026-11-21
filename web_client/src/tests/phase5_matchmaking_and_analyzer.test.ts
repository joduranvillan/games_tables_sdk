/**
 * Suite de Regresión Fase 5:
 * - Emparejamiento ELO automático (compatibilidad de rangos, expansión dinámica y cola en RelayWebSocketClient).
 * - Calibración automática de dificultad de IA según rating ELO.
 * - Analizador táctico post-partida (`evaluateStateJsonAdvantage`, `analyzeMatchCommandLog`, `generateSampleAnalyzableMatch`)
 *   validado en los 14 juegos canónicos del SDK.
 */

import {
  areMatchmakingTicketsCompatible,
  RelayWebSocketClient,
} from "../bridge/relayClient";
import { selectCalibratedAiDifficultyForElo } from "../components/common/MatchmakingQueuePanel";
import {
  analyzeMatchCommandLog,
  evaluateStateJsonAdvantage,
  generateSampleAnalyzableMatch,
} from "../components/common/PostMatchAnalyzerPanel";
import { CATALOG_14_GAMES } from "../App";
import { WasmGameBridge } from "../wasm_pkg";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`[FAIL Phase 5] ${message}`);
  }
}

console.log("=== INICIANDO SUITE DE REGRESION FASE 5 (MATCHMAKING ELO & ANALIZADOR 14 JUEGOS) ===");

// 1. Verificación de compatibilidad de tickets de Matchmaking ELO
{
  const ticketA = { gameId: "chess", elo: 1200, maxEloDelta: 150 };
  const ticketB = { gameId: "chess", elo: 1320, maxEloDelta: 150 };
  const ticketOutlier = { gameId: "chess", elo: 1650, maxEloDelta: 150 };
  const ticketOtherGame = { gameId: "go", elo: 1210, maxEloDelta: 150 };

  assert(
    areMatchmakingTicketsCompatible(ticketA, ticketB) === true,
    "Jugadores con diferencia de 120 ELO deben ser compatibles en ventana ±150"
  );
  assert(
    areMatchmakingTicketsCompatible(ticketA, ticketOutlier) === false,
    "Jugadores con diferencia de 450 ELO deben rechazarse en ventana ±150"
  );
  assert(
    areMatchmakingTicketsCompatible(ticketA, ticketOtherGame) === false,
    "Jugadores buscando juegos distintos no deben emparejarse"
  );
  console.log("  [PASS] Reglas de compatibilidad de ventana ELO verificadas.");
}

// 2. Verificación de cola y expansión dinámica en RelayWebSocketClient
{
  const client = new RelayWebSocketClient({}, "ws://127.0.0.1:8080");
  assert(!client.isQueuingMatchmaking(), "Inicialmente no debe estar en cola");

  const ticket = client.queueMatchmaking("shogi", 1340, 150, "TesterFase5");
  assert(client.isQueuingMatchmaking(), "Debe estar en cola tras queueMatchmaking");
  assert(ticket.gameId === "shogi", "El ticket debe registrar shogi");
  assert(ticket.elo === 1340, "El ticket debe registrar ELO 1340");
  assert(ticket.maxEloDelta === 150, "El ticket debe registrar ventana 150");

  client.expandMatchmakingTolerance(350);
  assert(
    client.getActiveQueueTicket()?.maxEloDelta === 350,
    "La ventana activa debe ampliarse a ±350"
  );

  client.cancelMatchmaking();
  assert(!client.isQueuingMatchmaking(), "Debe salir de la cola tras cancelMatchmaking");
  console.log("  [PASS] Ciclo de vida de cola ELO y expansión de tolerancia verificados.");
}

// 3. Verificación de calibración de dificultad IA por rango ELO
{
  assert(selectCalibratedAiDifficultyForElo(980) === 0, "ELO < 1100 -> IA Fácil (0)");
  assert(selectCalibratedAiDifficultyForElo(1200) === 1, "ELO 1200 -> IA Media (1)");
  assert(selectCalibratedAiDifficultyForElo(1420) === 2, "ELO 1420 -> IA Difícil (2)");
  assert(selectCalibratedAiDifficultyForElo(1680) === 3, "ELO >= 1500 -> IA Maestra (3)");
  console.log("  [PASS] Calibración de sparring IA por rango ELO verificada.");
}

// 4. Verificación del Analizador Post-Partida y Curva de Ventaja en los 14 juegos
{
  assert(CATALOG_14_GAMES.length === 14, "El catálogo debe contener exactamente 14 juegos");

  for (const game of CATALOG_14_GAMES) {
    const bridge = new WasmGameBridge();
    bridge.start_local_match(game.id, 1, 2);
    const initialAdv = evaluateStateJsonAdvantage(bridge.get_state_json());
    assert(
      Number.isFinite(initialAdv) && initialAdv >= -100 && initialAdv <= 100,
      `Ventaja inicial fuera de rango en ${game.id}: ${initialAdv}`
    );

    // Verificar estados terminales (+100 / -100)
    bridge.force_timeout_win(1);
    assert(
      evaluateStateJsonAdvantage(bridge.get_state_json()) === 100,
      `Victoria J1 debe evaluar +100 en ${game.id}`
    );

    const sampleCommands = generateSampleAnalyzableMatch(game.id, 4);
    assert(
      sampleCommands.length > 0,
      `generateSampleAnalyzableMatch debe producir jugadas válidas para ${game.id}`
    );

    const report = analyzeMatchCommandLog(game.id, sampleCommands);
    assert(
      report.totalPlies === sampleCommands.length,
      `El reporte de ${game.id} debe analizar todas las jugadas (${report.totalPlies} vs ${sampleCommands.length})`
    );
    assert(
      report.evalTimelineP1.length === sampleCommands.length + 1,
      `La curva de ventaja de ${game.id} debe tener N+1 puntos`
    );
    assert(
      report.accuracyP1 >= 0 && report.accuracyP1 <= 100,
      `Precisión J1 inválida en ${game.id}: ${report.accuracyP1}`
    );
    assert(
      report.accuracyP2 >= 0 && report.accuracyP2 <= 100,
      `Precisión J2 inválida en ${game.id}: ${report.accuracyP2}`
    );

    // 5. Verificar Telemetría IA y Mapa de Calor de Intensidad de Decisión por Zonas (Por Turno y Acumulado)
    assert(
      report.cumulativeHeatMap.gameId === game.id &&
        report.cumulativeHeatMap.cells.length >= 6 &&
        report.cumulativeHeatMap.totalCandidates >= sampleCommands.length,
      `Mapa de calor acumulado inválido en ${game.id}`
    );
    assert(
      report.cumulativeHeatMap.peakIntensityPct >= 1 &&
        report.cumulativeHeatMap.peakIntensityPct <= 100,
      `peakIntensityPct fuera de rango en ${game.id}: ${report.cumulativeHeatMap.peakIntensityPct}`
    );
    for (const entry of report.entries) {
      assert(
        entry.zoneHeatMap.cells.length ===
          entry.zoneHeatMap.rows * entry.zoneHeatMap.cols,
        `Dimensiones de cuadrícula de mapa de calor inconsistentes en ${game.id} turno #${entry.ply}`
      );
      const cellSum = entry.zoneHeatMap.cells.reduce(
        (acc, c) => acc + c.candidateCount,
        0
      );
      assert(
        cellSum === entry.zoneHeatMap.totalCandidates &&
          entry.zoneHeatMap.totalCandidates >= 1,
        `Suma de candidatos por zona (${cellSum}) debe coincidir con totalCandidates (${entry.zoneHeatMap.totalCandidates}) en ${game.id}`
      );
      assert(
        entry.zoneHeatMap.cells.some((c) => c.hasOptimalMove),
        `Al menos una zona debe marcar hasOptimalMove (★) en ${game.id} turno #${entry.ply}`
      );
      assert(
        entry.zoneHeatMap.cells.some((c) => c.hasPlayedMove),
        `Al menos una zona debe marcar hasPlayedMove (●) en ${game.id} turno #${entry.ply}`
      );
      assert(
        entry.aiTelemetry !== null &&
          entry.aiTelemetry.evaluated_candidates >= 1 &&
          entry.aiTelemetry.top_k_candidates >= 1,
        `Telemetría IA en PostMatchAnalyzerPanel debe estar presente en ${game.id} turno #${entry.ply}`
      );
    }
  }
  console.log(
    "  [PASS] Analizador Post-Partida, Curva de Ventaja y Mapa de Calor de Intensidad de Decisión IA por Zonas verificados en los 14/14 juegos."
  );
}

console.log("=== RESULTADO FASE 5: TODAS LAS PRUEBAS PASARON EXITOSAMENTE ===");
