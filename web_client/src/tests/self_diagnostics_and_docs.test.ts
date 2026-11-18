/**
 * Suite de Garantía Funcional y Documentación (Self-Diagnostics E2E & Documentation Center):
 * - Ejecuta `runFullSystemDiagnostics()` sobre los 14 motores de juego canónicos.
 * - Verifica inicialización, jugadas legales, despacho de comando humano, paso de IA, evaluación posicional y SyncLog.
 * - Verifica la cobertura e integridad del Centro de Documentación interactivo (`DOCUMENTATION_SECTIONS`).
 */

import {
  runFullSystemDiagnostics,
  runSingleGameSelfTest,
} from "../components/common/SystemDiagnosticsPanel";
import { DOCUMENTATION_SECTIONS } from "../components/common/DocumentationCenterModal";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`[FAIL Self-Diagnostics & Docs] ${message}`);
  }
}

console.log("=== INICIANDO SUITE DE GARANTIA FUNCIONAL E2E (14 JUEGOS & CENTRO DE DOCUMENTACION) ===");

// 1. Auditoría completa en vivo de los 14 motores de juego y subsistemas
{
  const report = runFullSystemDiagnostics("disconnected");
  assert(
    report.allPassed === true,
    "runFullSystemDiagnostics debe reportar allPassed === true"
  );
  assert(
    report.totalGamesVerified === 14,
    `Se esperaban 14 juegos verificados, obtenido: ${report.totalGamesVerified}`
  );
  assert(
    report.gameResults.length === 14,
    "El reporte debe incluir exactamente 14 resultados de juegos"
  );

  for (const res of report.gameResults) {
    assert(
      res.status === "PASS",
      `El autodiagnóstico de ${res.gameId} falló: ${res.detail}`
    );
    assert(
      res.initialTurn === 1,
      `El turno inicial de ${res.gameId} debe ser 1`
    );
    assert(
      res.initialLegalMovesCount > 0,
      `${res.gameId} debe exponer al menos 1 jugada legal inicial`
    );
    assert(
      res.humanMoveDispatched === true,
      `${res.gameId} debe aceptar el despacho de jugada inicial del Jugador 1`
    );
    assert(
      res.syncLogVerified === true,
      `${res.gameId} debe verificar el round-trip determinista export_log_json / apply_sync_log_json`
    );
    assert(
      Number.isFinite(res.positionalEvalScore),
      `${res.gameId} debe retornar un puntaje de evaluación posicional finito`
    );
  }
  console.log("  [PASS] 14/14 motores de juego auditados con éxito en runFullSystemDiagnostics.");
}

// 2. Verificación individual de juegos representativos (Clásico, Oriental, Dados, Cartas, Económico, Global)
{
  for (const gameId of [
    "chess",
    "shogi",
    "backgammon",
    "uno",
    "monopoly",
    "crisis",
    "goose",
  ]) {
    const single = runSingleGameSelfTest(gameId);
    assert(
      single.status === "PASS",
      `runSingleGameSelfTest(${gameId}) debe retornar PASS`
    );
    assert(
      single.syncLogVerified === true,
      `SyncLog en ${gameId} debe ser válido`
    );
  }
  console.log("  [PASS] Pruebas individuales en vivo (runSingleGameSelfTest) verificadas.");
}

// 3. Verificación del Centro de Documentación de Uso y Desarrollo React + WASM
{
  const usageSections = DOCUMENTATION_SECTIONS.filter(
    (s) => s.category === "usage"
  );
  const gamesSections = DOCUMENTATION_SECTIONS.filter(
    (s) => s.category === "games"
  );
  const devSections = DOCUMENTATION_SECTIONS.filter(
    (s) => s.category === "developer"
  );

  assert(
    usageSections.length >= 5,
    "El manual de uso debe contener al menos 5 secciones"
  );
  assert(
    gamesSections.length >= 2,
    "La guía de reglas de los 14 juegos debe cubrir todas las categorías"
  );
  assert(
    devSections.length >= 4,
    "La guía de desarrollo React + WASM debe cubrir los 4 pilares técnicos"
  );

  for (const sec of devSections) {
    assert(
      Boolean(sec.codeSnippet && sec.codeSnippet.code.length > 20),
      `La sección técnica ${sec.id} debe incluir un ejemplo de código o comandos ejecutable`
    );
  }
  console.log("  [PASS] Cobertura del Centro de Documentación (Uso, 14 Juegos, Desarrollo React/WASM) verificada.");
}

console.log("=== SUITE DE GARANTIA FUNCIONAL E2E COMPLETADA AL 100% ===");
