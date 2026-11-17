import React, { useMemo, useState } from "react";
import { WasmGameBridge } from "../../wasm_pkg";

export type MoveQualityClassification =
  | "optima"
  | "buena"
  | "imprecision"
  | "error_critico";

export interface LoggedCommandItem {
  player: number;
  command: string;
}

export interface MoveEvaluationEntry {
  ply: number;
  player: 1 | 2;
  playedCommandJson: string;
  bestCommandJson: string;
  matchedEngineBest: boolean;
  evalBeforeP1: number;
  evalAfterP1: number;
  evalDeltaForMover: number;
  classification: MoveQualityClassification;
  summaryText: string;
  bestMoveSummaryText: string;
}

export interface MatchAnalysisReport {
  gameId: string;
  totalPlies: number;
  accuracyP1: number;
  accuracyP2: number;
  countsP1: Record<MoveQualityClassification, number>;
  countsP2: Record<MoveQualityClassification, number>;
  entries: MoveEvaluationEntry[];
  evalTimelineP1: number[];
  criticalTurningPoints: number[];
}

function clampEval(val: number): number {
  if (!Number.isFinite(val)) return 0;
  return Math.max(-100, Math.min(100, Math.round(val * 10) / 10));
}

export function formatCommandBriefFromJson(cmdStr: string): string {
  if (!cmdStr || !cmdStr.trim()) return "Sin jugada alternativa";
  try {
    const cmd = JSON.parse(cmdStr) as Record<string, unknown>;
    const ctype = String(cmd.command_type || cmd.type || "Acción")
      .replace(/^[a-z_]+::/, "")
      .replace(/Command$/, "");
    if (Array.isArray(cmd.from) && Array.isArray(cmd.to)) {
      return `${ctype} (${cmd.from[0]},${cmd.from[1]}) → (${cmd.to[0]},${cmd.to[1]})`;
    }
    if (typeof cmd.from === "number" && typeof cmd.to === "number") {
      return `${ctype} pto ${cmd.from} → ${cmd.to}`;
    }
    if (typeof cmd.fromId === "string" && typeof cmd.toId === "string") {
      return `${ctype} ${cmd.fromId} → ${cmd.toId}`;
    }
    if (typeof cmd.row === "number" && typeof cmd.col === "number") {
      return `${ctype} (${cmd.row},${cmd.col})`;
    }
    if (typeof cmd.card_index === "number") {
      return `${ctype} carta #${cmd.card_index}`;
    }
    if (typeof cmd.token_index === "number") {
      return `${ctype} ficha #${cmd.token_index}`;
    }
    if (typeof cmd.territory === "number") {
      return `${ctype} terr. #${cmd.territory}`;
    }
    return ctype;
  } catch {
    return cmdStr.slice(0, 32);
  }
}

/**
 * Calcula la ventaja posicional normalizada en el rango [-100, +100] desde la perspectiva del Jugador 1
 * a partir del JSON de estado devuelto por `WasmGameBridge.get_state_json()` para los 14 juegos.
 */
export function evaluateStateJsonAdvantage(stateJson: string): number {
  try {
    const st = JSON.parse(stateJson);
    if (st.winner === 1) return 100;
    if (st.winner === 2) return -100;

    const gtype = String(st.game_type || "chess");
    switch (gtype) {
      case "chess": {
        const weights: Record<string, number> = {
          Pawn: 10,
          Knight: 30,
          Bishop: 32,
          Rook: 50,
          Queen: 90,
          King: 0,
        };
        let score = 0;
        const grid = st.grid as ({ kind: string; owner: 1 | 2 } | null)[][];
        if (Array.isArray(grid)) {
          for (let r = 0; r < grid.length; r++) {
            for (let c = 0; c < (grid[r]?.length || 0); c++) {
              const pc = grid[r][c];
              if (!pc) continue;
              const base = weights[pc.kind] ?? 10;
              const centerBonus = r >= 2 && r <= 5 && c >= 2 && c <= 5 ? 2 : 0;
              score += pc.owner === 1 ? base + centerBonus : -(base + centerBonus);
            }
          }
        }
        return clampEval(score);
      }
      case "checkers": {
        let score = 0;
        const grid = st.grid as ({ owner: 1 | 2; isKing: boolean } | null)[][];
        if (Array.isArray(grid)) {
          for (let r = 0; r < grid.length; r++) {
            for (let c = 0; c < (grid[r]?.length || 0); c++) {
              const pc = grid[r][c];
              if (!pc) continue;
              const val = pc.isKing ? 15 : 8;
              score += pc.owner === 1 ? val : -val;
            }
          }
        }
        return clampEval(score);
      }
      case "uno": {
        const h1 = Array.isArray(st.hands?.[1]) ? st.hands[1].length : 7;
        const h2 = Array.isArray(st.hands?.[2]) ? st.hands[2].length : 7;
        return clampEval((h2 - h1) * 14);
      }
      case "goose": {
        const p1Sq = Number(st.players?.[0]?.square ?? 0);
        const p2Sq = Number(st.players?.[1]?.square ?? 0);
        return clampEval((p1Sq - p2Sq) * 1.6);
      }
      case "go": {
        const cap1 = Number(st.captures?.[1] ?? 0);
        const cap2 = Number(st.captures?.[2] ?? 0);
        let stonesDiff = (cap1 - cap2) * 4;
        const grid = st.grid as number[][];
        if (Array.isArray(grid)) {
          for (const row of grid) {
            for (const cell of row) {
              if (cell === 1) stonesDiff += 3;
              else if (cell === 2) stonesDiff -= 3;
            }
          }
        }
        return clampEval(stonesDiff);
      }
      case "shogi": {
        let score =
          ((st.hands?.[1]?.length ?? 0) - (st.hands?.[2]?.length ?? 0)) * 8;
        const grid = st.grid as ({ owner: 1 | 2; promoted: boolean } | null)[][];
        if (Array.isArray(grid)) {
          for (const row of grid) {
            for (const pc of row) {
              if (!pc) continue;
              const val = pc.promoted ? 14 : 9;
              score += pc.owner === 1 ? val : -val;
            }
          }
        }
        return clampEval(score);
      }
      case "xiangqi": {
        const weights: Record<string, number> = {
          General: 0,
          Chariot: 18,
          Cannon: 10,
          Horse: 9,
          Elephant: 5,
          Advisor: 5,
          Soldier: 4,
        };
        let score = 0;
        const grid = st.grid as ({ kind: string; owner: 1 | 2 } | null)[][];
        if (Array.isArray(grid)) {
          for (const row of grid) {
            for (const pc of row) {
              if (!pc) continue;
              const val = weights[pc.kind] ?? 5;
              score += pc.owner === 1 ? val : -val;
            }
          }
        }
        return clampEval(score);
      }
      case "chinese_checkers": {
        const cells = st.cells as { r: number; owner: number }[];
        if (!Array.isArray(cells)) return 0;
        let adv1 = 0;
        let adv2 = 0;
        for (const cell of cells) {
          if (cell.owner === 1) adv1 += 16 - cell.r;
          else if (cell.owner === 2) adv2 += cell.r;
        }
        return clampEval((adv1 - adv2) * 1.4);
      }
      case "backgammon": {
        const off1 = Number(st.borne_off?.[1] ?? 0);
        const off2 = Number(st.borne_off?.[2] ?? 0);
        const bar1 = Number(st.bar?.[1] ?? 0);
        const bar2 = Number(st.bar?.[2] ?? 0);
        return clampEval((off1 - off2) * 10 + (bar2 - bar1) * 8);
      }
      case "ludo": {
        const t1 = Array.isArray(st.tokens?.[1])
          ? (st.tokens[1] as number[]).reduce((a, b) => a + b, 0)
          : 0;
        const t2 = Array.isArray(st.tokens?.[2])
          ? (st.tokens[2] as number[]).reduce((a, b) => a + b, 0)
          : 0;
        return clampEval((t1 - t2) * 0.8);
      }
      case "battleship": {
        const h1 = Number(st.hits_count?.[1] ?? 0);
        const h2 = Number(st.hits_count?.[2] ?? 0);
        return clampEval((h1 - h2) * 8);
      }
      case "mille_bornes": {
        const d1 = Number(st.distance?.[1] ?? 0);
        const d2 = Number(st.distance?.[2] ?? 0);
        return clampEval((d1 - d2) * 0.1);
      }
      case "monopoly": {
        const c1 = Number(st.cash?.[1] ?? 1500);
        const c2 = Number(st.cash?.[2] ?? 1500);
        let w1 = c1;
        let w2 = c2;
        if (Array.isArray(st.spaces)) {
          for (const sp of st.spaces) {
            const val = Number(sp.price ?? 0) + Number(sp.houses ?? 0) * 50;
            if (sp.owner === 1) w1 += val;
            else if (sp.owner === 2) w2 += val;
          }
        }
        return clampEval((w1 - w2) / 25);
      }
      case "crisis": {
        let t1 = 0;
        let t2 = 0;
        if (Array.isArray(st.territories)) {
          for (const terr of st.territories) {
            if (terr.owner === 1) t1 += 5 + Number(terr.armies ?? 1) * 2;
            else if (terr.owner === 2) t2 += 5 + Number(terr.armies ?? 1) * 2;
          }
        }
        return clampEval((t1 - t2) * 0.6);
      }
      default:
        return 0;
    }
  } catch {
    return 0;
  }
}

function classifyMoveDelta(
  deltaForMover: number,
  matchedEngineBest: boolean
): MoveQualityClassification {
  if (matchedEngineBest || deltaForMover >= -1.5) return "optima";
  if (deltaForMover >= -10) return "buena";
  if (deltaForMover >= -24) return "imprecision";
  return "error_critico";
}

function accuracyWeightForClassification(c: MoveQualityClassification): number {
  switch (c) {
    case "optima":
      return 100;
    case "buena":
      return 84;
    case "imprecision":
      return 52;
    case "error_critico":
      return 15;
  }
}

/**
 * Extrae una lista de comandos desde el JSON exportado por `WasmGameBridge.export_log_json()`.
 */
export function parseCommandsFromExportLog(logJson: string): LoggedCommandItem[] {
  try {
    const parsed = JSON.parse(logJson);
    if (Array.isArray(parsed.commands)) {
      return parsed.commands.map((c: { player?: number; command?: unknown }) => ({
        player: Number(c.player || 1),
        command:
          typeof c.command === "string"
            ? c.command
            : JSON.stringify(c.command ?? {}),
      }));
    }
  } catch {
    // Ignore
  }
  return [];
}

/**
 * Genera una partida demostrativa de `plyCount` jugadas usando el motor WASM/TS real para cualquiera de los 14 juegos.
 */
export function generateSampleAnalyzableMatch(
  gameId: string,
  plyCount: number = 8
): LoggedCommandItem[] {
  const sim = new WasmGameBridge();
  sim.start_local_match(gameId, 1, 2);
  for (let i = 0; i < plyCount; i++) {
    const st = JSON.parse(sim.get_state_json());
    if (st.winner !== null && st.winner !== undefined) break;
    const p = sim.current_player() as 1 | 2;
    // Usamos una instancia auxiliar en modo IA para obtener una jugada legal canónica para `p`
    const helper = new WasmGameBridge();
    helper.apply_sync_log_json(gameId, sim.export_log_json());
    helper.start_ai_match(gameId, p === 1 ? 2 : 1, p, i % 3 === 1 ? 0 : 3);
    helper.apply_sync_log_json(gameId, sim.export_log_json());
    helper.step_ai_if_needed();
    const helperCmds = parseCommandsFromExportLog(helper.export_log_json());
    const nextCmd = helperCmds[helperCmds.length - 1];
    if (!nextCmd) break;
    sim.send_command_json(nextCmd.player, nextCmd.command);
  }
  return parseCommandsFromExportLog(sim.export_log_json());
}

/**
 * Reconstruye y analiza jugada por jugada un historial de comandos en cualquiera de los 14 juegos.
 */
export function analyzeMatchCommandLog(
  gameId: string,
  commands: LoggedCommandItem[]
): MatchAnalysisReport {
  const sim = new WasmGameBridge();
  sim.start_local_match(gameId, 1, 2);

  const entries: MoveEvaluationEntry[] = [];
  const evalTimelineP1: number[] = [evaluateStateJsonAdvantage(sim.get_state_json())];
  const criticalTurningPoints: number[] = [];

  const countsP1: Record<MoveQualityClassification, number> = {
    optima: 0,
    buena: 0,
    imprecision: 0,
    error_critico: 0,
  };
  const countsP2: Record<MoveQualityClassification, number> = {
    optima: 0,
    buena: 0,
    imprecision: 0,
    error_critico: 0,
  };

  for (let i = 0; i < commands.length; i++) {
    const item = commands[i];
    const mover: 1 | 2 = item.player === 2 ? 2 : 1;
    const evalBeforeP1 = evaluateStateJsonAdvantage(sim.get_state_json());

    // Consultar la línea recomendada por la IA Maestro (difficulty = 3) en este estado
    const oracle = new WasmGameBridge();
    oracle.start_ai_match(gameId, mover === 1 ? 2 : 1, mover, 3);
    oracle.apply_sync_log_json(gameId, sim.export_log_json());
    oracle.step_ai_if_needed();
    const oracleCmds = parseCommandsFromExportLog(oracle.export_log_json());
    const bestCmdItem = oracleCmds[oracleCmds.length - 1];
    const bestCommandJson = bestCmdItem ? bestCmdItem.command : item.command;
    const evalBestP1 = evaluateStateJsonAdvantage(oracle.get_state_json());

    // Aplicar la jugada realmente ejecutada
    sim.send_command_json(mover, item.command);
    const evalAfterP1 = evaluateStateJsonAdvantage(sim.get_state_json());
    evalTimelineP1.push(evalAfterP1);

    const sign = mover === 1 ? 1 : -1;
    const playedScoreForMover = evalAfterP1 * sign;
    const bestScoreForMover = Math.max(evalBeforeP1 * sign, evalBestP1 * sign);
    const evalDeltaForMover =
      Math.round((playedScoreForMover - bestScoreForMover) * 10) / 10;

    const playedBrief = formatCommandBriefFromJson(item.command);
    const bestBrief = formatCommandBriefFromJson(bestCommandJson);
    const matchedEngineBest = playedBrief === bestBrief;

    const classification = classifyMoveDelta(evalDeltaForMover, matchedEngineBest);
    if (mover === 1) {
      countsP1[classification] += 1;
    } else {
      countsP2[classification] += 1;
    }

    if (Math.abs(evalAfterP1 - evalBeforeP1) >= 16) {
      criticalTurningPoints.push(i + 1);
    }

    entries.push({
      ply: i + 1,
      player: mover,
      playedCommandJson: item.command,
      bestCommandJson,
      matchedEngineBest,
      evalBeforeP1,
      evalAfterP1,
      evalDeltaForMover,
      classification,
      summaryText: playedBrief,
      bestMoveSummaryText: bestBrief,
    });
  }

  const p1Moves = entries.filter((e) => e.player === 1);
  const p2Moves = entries.filter((e) => e.player === 2);

  const accuracyP1 =
    p1Moves.length === 0
      ? 100
      : Math.round(
          p1Moves.reduce(
            (acc, e) => acc + accuracyWeightForClassification(e.classification),
            0
          ) / p1Moves.length
        );
  const accuracyP2 =
    p2Moves.length === 0
      ? 100
      : Math.round(
          p2Moves.reduce(
            (acc, e) => acc + accuracyWeightForClassification(e.classification),
            0
          ) / p2Moves.length
        );

  return {
    gameId,
    totalPlies: entries.length,
    accuracyP1,
    accuracyP2,
    countsP1,
    countsP2,
    entries,
    evalTimelineP1,
    criticalTurningPoints,
  };
}

export interface PostMatchAnalyzerPanelProps {
  activeGame: string;
  activeGameTitle: string;
  activeExportLogJson: string;
  colorblindMode: boolean;
  onLoadReplayLogToBoard: (logJson: string) => void;
}

export const PostMatchAnalyzerPanel: React.FC<PostMatchAnalyzerPanelProps> = ({
  activeGame,
  activeGameTitle,
  activeExportLogJson,
  colorblindMode,
  onLoadReplayLogToBoard,
}) => {
  const [customCommands, setCustomCommands] = useState<LoggedCommandItem[] | null>(
    null
  );
  const [selectedPly, setSelectedPly] = useState<number>(1);

  const liveCommands = useMemo(
    () => parseCommandsFromExportLog(activeExportLogJson),
    [activeExportLogJson]
  );

  const effectiveCommands = useMemo(() => {
    if (customCommands && customCommands.length > 0) return customCommands;
    if (liveCommands.length > 0) return liveCommands;
    return generateSampleAnalyzableMatch(activeGame, 8);
  }, [customCommands, liveCommands, activeGame]);

  const report = useMemo(
    () => analyzeMatchCommandLog(activeGame, effectiveCommands),
    [activeGame, effectiveCommands]
  );

  const selectedEntry =
    report.entries.find((e) => e.ply === selectedPly) ||
    report.entries[report.entries.length - 1] ||
    null;

  const classificationLabel = (c: MoveQualityClassification) => {
    switch (c) {
      case "optima":
        return "★ Óptima";
      case "buena":
        return "✓ Buena";
      case "imprecision":
        return "? Imprecisión";
      case "error_critico":
        return "?? Error Crítico";
    }
  };

  const classificationColorClass = (c: MoveQualityClassification) => {
    if (colorblindMode) {
      switch (c) {
        case "optima":
          return "text-sky-300";
        case "buena":
          return "text-emerald-300";
        case "imprecision":
          return "text-amber-300";
        case "error_critico":
          return "text-orange-400";
      }
    }
    switch (c) {
      case "optima":
        return "text-emerald-400";
      case "buena":
        return "text-sky-300";
      case "imprecision":
        return "text-amber-400";
      case "error_critico":
        return "text-rose-400";
    }
  };

  const chartWidth = 680;
  const chartHeight = 170;
  const points = report.evalTimelineP1.map((val, idx) => {
    const total = Math.max(1, report.evalTimelineP1.length - 1);
    const x = 32 + (idx / total) * (chartWidth - 52);
    const y = chartHeight / 2 - (val / 100) * (chartHeight / 2 - 18);
    return { x, y, val, ply: idx };
  });

  const polylinePoints = points
    .map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`)
    .join(" ");

  return (
    <div className="space-y-6">
      {/* Cabecera del Analizador */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-white">
            01. Analizador Táctico Post-Partida y Curva de Ventaja
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Juego activo: <strong className="text-slate-200">{activeGameTitle}</strong>{" "}
            · <span className="font-mono tabular-nums">{report.totalPlies} jugadas evaluadas</span>{" "}
            · Motor de referencia: IA Maestra (Nivel 4)
          </p>
        </div>

        <div className="flex items-center gap-2">
          {liveCommands.length > 0 && customCommands !== null && (
            <button
              type="button"
              onClick={() => {
                setCustomCommands(null);
                setSelectedPly(1);
              }}
              className="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              Usar Partida en Curso ({liveCommands.length} jugadas)
            </button>
          )}
          <button
            type="button"
            onClick={() => {
              const sample = generateSampleAnalyzableMatch(activeGame, 8);
              setCustomCommands(sample);
              setSelectedPly(1);
            }}
            className="px-3.5 py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 text-xs font-bold rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            Simular y Analizar Línea Táctica (8 turnos)
          </button>
        </div>
      </div>

      {/* KPIs de Precisión y Clasificación por Jugador */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 flex items-center justify-between">
          <div>
            <div className="text-xs text-slate-400">Jugador 1 (Anfitrión / Blancas)</div>
            <div className="text-2xl font-bold font-mono tabular-nums text-white mt-1">
              {report.accuracyP1}% Precisión
            </div>
            <div className="text-[11px] text-slate-400 mt-2 font-mono tabular-nums">
              ★ {report.countsP1.optima} Óptimas · ✓ {report.countsP1.buena} Buenas · ?{" "}
              {report.countsP1.imprecision} Imprec. · ?? {report.countsP1.error_critico}{" "}
              Errores
            </div>
          </div>
          <div className="text-right font-mono tabular-nums">
            <span className="text-xs text-slate-500 block">Giros críticos</span>
            <span className="text-lg font-bold text-amber-400">
              {report.criticalTurningPoints.length}
            </span>
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 flex items-center justify-between">
          <div>
            <div className="text-xs text-slate-400">Jugador 2 (Visitante / IA)</div>
            <div className="text-2xl font-bold font-mono tabular-nums text-white mt-1">
              {report.accuracyP2}% Precisión
            </div>
            <div className="text-[11px] text-slate-400 mt-2 font-mono tabular-nums">
              ★ {report.countsP2.optima} Óptimas · ✓ {report.countsP2.buena} Buenas · ?{" "}
              {report.countsP2.imprecision} Imprec. · ?? {report.countsP2.error_critico}{" "}
              Errores
            </div>
          </div>
          <div className="text-right font-mono tabular-nums">
            <span className="text-xs text-slate-500 block">Eval. Final J1</span>
            <span
              className={`text-lg font-bold ${
                (report.evalTimelineP1[report.evalTimelineP1.length - 1] ?? 0) >= 0
                  ? "text-emerald-400"
                  : "text-rose-400"
              }`}
            >
              {(report.evalTimelineP1[report.evalTimelineP1.length - 1] ?? 0) >= 0
                ? "+"
                : ""}
              {report.evalTimelineP1[report.evalTimelineP1.length - 1] ?? 0}
            </span>
          </div>
        </div>
      </div>

      {/* Gráfico SVG Interactivo de Ventaja Posicional */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-bold text-slate-200">
            02. Curva de Ventaja Posicional ([-100, +100] · Haz clic en un nodo para inspeccionar)
          </h3>
          <span className="text-xs font-mono tabular-nums text-slate-400">
            Arriba de 0.0 = Ventaja J1 · Debajo de 0.0 = Ventaja J2
          </span>
        </div>

        <div className="w-full overflow-x-auto bg-slate-950 border border-slate-800 rounded-xl p-3">
          <svg
            viewBox={`0 0 ${chartWidth} ${chartHeight}`}
            className="w-full h-44 select-none"
            role="img"
            aria-label="Gráfico de ventaja posicional por turno"
          >
            <line
              x1={32}
              y1={chartHeight / 2}
              x2={chartWidth - 20}
              y2={chartHeight / 2}
              stroke="#334155"
              strokeDasharray="4 4"
              strokeWidth={1}
            />
            <text x={4} y={22} fill="#94a3b8" fontSize="10" fontFamily="monospace">
              +100
            </text>
            <text
              x={10}
              y={chartHeight / 2 + 3}
              fill="#94a3b8"
              fontSize="10"
              fontFamily="monospace"
            >
              0.0
            </text>
            <text
              x={4}
              y={chartHeight - 10}
              fill="#94a3b8"
              fontSize="10"
              fontFamily="monospace"
            >
              -100
            </text>

            {points.length > 1 && (
              <polyline
                fill="none"
                stroke={colorblindMode ? "#38bdf8" : "#f59e0b"}
                strokeWidth={2.5}
                points={polylinePoints}
              />
            )}

            {points.map((pt) => {
              const isSelected = pt.ply === selectedPly;
              const isTurningPoint = report.criticalTurningPoints.includes(pt.ply);
              return (
                <g
                  key={pt.ply}
                  onClick={() => pt.ply >= 1 && setSelectedPly(pt.ply)}
                  className="cursor-pointer"
                >
                  <circle
                    cx={pt.x}
                    cy={pt.y}
                    r={isSelected ? 6 : isTurningPoint ? 5 : 3.5}
                    fill={
                      isSelected
                        ? "#10b981"
                        : isTurningPoint
                        ? "#f43f5e"
                        : "#f8fafc"
                    }
                    stroke="#0f172a"
                    strokeWidth={1.5}
                  />
                </g>
              );
            })}
          </svg>
        </div>
      </div>

      {/* Inspector Detallado del Turno Seleccionado + Tabla Completa de Jugadas */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-stretch">
        <div className="lg:col-span-5 bg-slate-900 border border-slate-800 rounded-2xl p-5 flex flex-col justify-between space-y-4">
          {selectedEntry ? (
            <>
              <div className="space-y-3">
                <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                  <span className="text-xs font-mono tabular-nums text-slate-400">
                    Turno #{selectedEntry.ply} · Jugador {selectedEntry.player}
                  </span>
                  <span
                    className={`text-xs font-bold font-mono ${classificationColorClass(
                      selectedEntry.classification
                    )}`}
                  >
                    {classificationLabel(selectedEntry.classification)}
                  </span>
                </div>

                <div className="space-y-2 text-xs">
                  <div className="bg-slate-950 border border-slate-800 rounded-lg p-3">
                    <div className="text-slate-400 text-[11px]">Jugada Ejecutada:</div>
                    <div className="font-mono text-slate-100 font-semibold mt-0.5">
                      {selectedEntry.summaryText}
                    </div>
                  </div>

                  <div className="bg-slate-950 border border-slate-800 rounded-lg p-3">
                    <div className="text-slate-400 text-[11px]">
                      Línea Óptima Recomendada (IA Nivel 4):
                    </div>
                    <div className="font-mono text-emerald-300 font-semibold mt-0.5">
                      {selectedEntry.bestMoveSummaryText}
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2 pt-1 text-center font-mono tabular-nums">
                  <div className="bg-slate-950 border border-slate-800 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">Eval. Previa</div>
                    <div className="text-xs font-bold text-slate-200">
                      {selectedEntry.evalBeforeP1 >= 0 ? "+" : ""}
                      {selectedEntry.evalBeforeP1}
                    </div>
                  </div>
                  <div className="bg-slate-950 border border-slate-800 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">Eval. Posterior</div>
                    <div className="text-xs font-bold text-slate-200">
                      {selectedEntry.evalAfterP1 >= 0 ? "+" : ""}
                      {selectedEntry.evalAfterP1}
                    </div>
                  </div>
                  <div className="bg-slate-950 border border-slate-800 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">Delta Jugador</div>
                    <div
                      className={`text-xs font-bold ${
                        selectedEntry.evalDeltaForMover >= -1.5
                          ? "text-emerald-400"
                          : "text-amber-400"
                      }`}
                    >
                      {selectedEntry.evalDeltaForMover >= 0 ? "+" : ""}
                      {selectedEntry.evalDeltaForMover}
                    </div>
                  </div>
                </div>
              </div>

              <button
                type="button"
                onClick={() => {
                  const partial = effectiveCommands.slice(0, selectedEntry.ply);
                  const payload = JSON.stringify({
                    game_type: activeGame,
                    commands: partial,
                  });
                  onLoadReplayLogToBoard(payload);
                }}
                className="w-full py-2.5 px-4 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs rounded-xl transition-colors whitespace-nowrap shrink-0 cursor-pointer"
              >
                Cargar Estado del Turno #{selectedEntry.ply} en el Tablero Activo
              </button>
            </>
          ) : (
            <div className="text-xs text-slate-400 py-8 text-center">
              No hay jugadas registradas para analizar.
            </div>
          )}
        </div>

        {/* Tabla Comparativa de Jugadas */}
        <div className="lg:col-span-7 bg-slate-900 border border-slate-800 rounded-2xl p-5 flex flex-col">
          <h3 className="text-sm font-bold text-slate-200 mb-3">
            03. Registro Comparativo de Movimientos y Sugerencias del Motor
          </h3>
          <div className="overflow-y-auto max-h-80 border border-slate-800 rounded-xl">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-slate-950 text-slate-400 border-b border-slate-800">
                  <th className="py-2 px-3 font-medium">#</th>
                  <th className="py-2 px-3 font-medium">Jug.</th>
                  <th className="py-2 px-3 font-medium">Jugada Realizada</th>
                  <th className="py-2 px-3 font-medium">Óptima (IA 4)</th>
                  <th className="py-2 px-3 font-medium text-right">Eval J1</th>
                  <th className="py-2 px-3 font-medium text-right">Calidad</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/70 font-mono tabular-nums">
                {report.entries.map((entry) => (
                  <tr
                    key={entry.ply}
                    onClick={() => setSelectedPly(entry.ply)}
                    className={`cursor-pointer transition-colors ${
                      selectedPly === entry.ply
                        ? "bg-amber-500/15 text-white"
                        : "hover:bg-slate-800/60 text-slate-300"
                    }`}
                  >
                    <td className="py-2 px-3 text-slate-400">{entry.ply}</td>
                    <td className="py-2 px-3">J{entry.player}</td>
                    <td className="py-2 px-3 truncate max-w-[160px]">
                      {entry.summaryText}
                    </td>
                    <td className="py-2 px-3 text-slate-400 truncate max-w-[160px]">
                      {entry.bestMoveSummaryText}
                    </td>
                    <td className="py-2 px-3 text-right">
                      {entry.evalAfterP1 >= 0 ? "+" : ""}
                      {entry.evalAfterP1}
                    </td>
                    <td
                      className={`py-2 px-3 text-right font-semibold ${classificationColorClass(
                        entry.classification
                      )}`}
                    >
                      {classificationLabel(entry.classification)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};
