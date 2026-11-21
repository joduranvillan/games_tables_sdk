import React, { useMemo, useState } from "react";
import { AiMoveTelemetry, WasmGameBridge } from "../../wasm_pkg";

export type MoveQualityClassification =
  | "optima"
  | "buena"
  | "imprecision"
  | "error_critico";

export interface LoggedCommandItem {
  player: number;
  command: string;
}

export interface BoardZoneHeatCell {
  zoneId: string;
  label: string;
  shortCoord: string;
  row: number;
  col: number;
  candidateCount: number;
  topKShareEstimate: number;
  intensityPct: number;
  hasPlayedMove: boolean;
  hasOptimalMove: boolean;
}

export interface DecisionIntensityHeatMap {
  gameId: string;
  topologyLabel: string;
  rows: number;
  cols: number;
  totalCandidates: number;
  peakZoneLabel: string;
  peakIntensityPct: number;
  entropyScore: number;
  cells: BoardZoneHeatCell[];
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
  aiTelemetry: AiMoveTelemetry | null;
  legalCandidatesCount: number;
  zoneHeatMap: DecisionIntensityHeatMap;
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
  cumulativeHeatMap: DecisionIntensityHeatMap;
}

interface ZoneSpec {
  zoneId: string;
  label: string;
  shortCoord: string;
  row: number;
  col: number;
}

interface GameZoneTopology {
  topologyLabel: string;
  rows: number;
  cols: number;
  zones: ZoneSpec[];
}

function getGameZoneTopology(gameId: string): GameZoneTopology {
  const clean = gameId.trim().toLowerCase().replace(/-/g, "_");
  switch (clean) {
    case "chess":
    case "checkers": {
      const rowLabels = ["Filas 8-7 (Norte)", "Filas 6-5 (Centro-N)", "Filas 4-3 (Centro-S)", "Filas 2-1 (Sur)"];
      const colLabels = ["Cols A-B", "Cols C-D", "Cols E-F", "Cols G-H"];
      const shortCols = ["A-B", "C-D", "E-F", "G-H"];
      const shortRows = ["8-7", "6-5", "4-3", "2-1"];
      const zones: ZoneSpec[] = [];
      for (let r = 0; r < 4; r++) {
        for (let c = 0; c < 4; c++) {
          zones.push({
            zoneId: `z_${r}_${c}`,
            label: `${colLabels[c]} · ${rowLabels[r]}`,
            shortCoord: `${shortCols[c]} / ${shortRows[r]}`,
            row: r,
            col: c,
          });
        }
      }
      return {
        topologyLabel:
          clean === "chess"
            ? "Cuadrícula Táctica FIDE 4×4 (16 Subzonas de Tablero 8×8)"
            : "Cuadrícula de Diagonales 4×4 (16 Subzonas de Tablero 8×8)",
        rows: 4,
        cols: 4,
        zones,
      };
    }

    case "go": {
      const specs: [string, string][] = [
        ["Hoshi Sup-Izq (NO)", "A-C / 1-3"],
        ["Borde Superior (N)", "D-F / 1-3"],
        ["Hoshi Sup-Der (NE)", "G-J / 1-3"],
        ["Borde Izquierdo (O)", "A-C / 4-6"],
        ["Tengen Central (Centro)", "D-F / 4-6"],
        ["Borde Derecho (E)", "G-J / 4-6"],
        ["Hoshi Inf-Izq (SO)", "A-C / 7-9"],
        ["Borde Inferior (S)", "D-F / 7-9"],
        ["Hoshi Inf-Der (SE)", "G-J / 7-9"],
      ];
      return {
        topologyLabel: "Sectores del Goban 3×3 (9 Territorios Hoshi/Tengen)",
        rows: 3,
        cols: 3,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 3)}_${idx % 3}`,
          label,
          shortCoord,
          row: Math.floor(idx / 3),
          col: idx % 3,
        })),
      };
    }

    case "shogi": {
      const specs: [string, string][] = [
        ["Promoción Flanco Izq", "Cols 9-7 / Filas 1-3"],
        ["Promoción Palacio Gote", "Cols 6-4 / Filas 1-3"],
        ["Promoción Flanco Der", "Cols 3-1 / Filas 1-3"],
        ["Centro Izquierdo", "Cols 9-7 / Filas 4-6"],
        ["Vanguardia Central + Komadai", "Cols 6-4 / Filas 4-6"],
        ["Centro Derecho", "Cols 3-1 / Filas 4-6"],
        ["Campo Sente Izq", "Cols 9-7 / Filas 7-9"],
        ["Castillo Sente Central", "Cols 6-4 / Filas 7-9"],
        ["Campo Sente Der", "Cols 3-1 / Filas 7-9"],
      ];
      return {
        topologyLabel: "Sectores FESA 3×3 (9 Zonas de Tablero 9×9 y Komadai)",
        rows: 3,
        cols: 3,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 3)}_${idx % 3}`,
          label,
          shortCoord,
          row: Math.floor(idx / 3),
          col: idx % 3,
        })),
      };
    }

    case "xiangqi": {
      const specs: [string, string][] = [
        ["Flanco Norte Izq", "Cols 1-3 / Filas 0-3"],
        ["Palacio Negro (Norte)", "Cols 4-6 / Filas 0-2"],
        ["Flanco Norte Der", "Cols 7-9 / Filas 0-3"],
        ["Ribera Oeste (Río)", "Cols 1-3 / Filas 4-5"],
        ["Cruce Central Chu-He", "Cols 4-6 / Filas 4-5"],
        ["Ribera Este (Río)", "Cols 7-9 / Filas 4-5"],
        ["Flanco Sur Izq", "Cols 1-3 / Filas 6-9"],
        ["Palacio Rojo (Sur)", "Cols 4-6 / Filas 7-9"],
        ["Flanco Sur Der", "Cols 7-9 / Filas 6-9"],
      ];
      return {
        topologyLabel: "Sectores Xiangqi 3×3 (Palacios 3×3, Río y Flancos)",
        rows: 3,
        cols: 3,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 3)}_${idx % 3}`,
          label,
          shortCoord,
          row: Math.floor(idx / 3),
          col: idx % 3,
        })),
      };
    }

    case "battleship": {
      const zones: ZoneSpec[] = [];
      const rowPairs = ["A-B", "C-D", "E-F", "G-H", "I-J"];
      const colPairs = ["1-2", "3-4", "5-6", "7-8", "9-10"];
      for (let r = 0; r < 5; r++) {
        for (let c = 0; c < 5; c++) {
          zones.push({
            zoneId: `z_${r}_${c}`,
            label: `Sector Radar ${rowPairs[r]} · Cols ${colPairs[c]}`,
            shortCoord: `${rowPairs[r]}:${colPairs[c]}`,
            row: r,
            col: c,
          });
        }
      }
      return {
        topologyLabel: "Radar Naval 5×5 (25 Sectores Tácticos de Cuadrícula 10×10)",
        rows: 5,
        cols: 5,
        zones,
      };
    }

    case "chinese_checkers": {
      const specs: [string, string][] = [
        ["Ala Noroeste", "Filas 0-5 / Izq"],
        ["Punta Norte (Meta J1)", "Filas 0-4 / Centro"],
        ["Ala Noreste", "Filas 0-5 / Der"],
        ["Flanco Hexagonal Oeste", "Filas 6-10 / Izq"],
        ["Hexágono Central (Puente)", "Filas 6-10 / Centro"],
        ["Flanco Hexagonal Este", "Filas 6-10 / Der"],
        ["Ala Suroeste", "Filas 11-16 / Izq"],
        ["Punta Sur (Meta J2)", "Filas 12-16 / Centro"],
        ["Ala Sureste", "Filas 11-16 / Der"],
      ];
      return {
        topologyLabel: "Estrella Hexagonal 3×3 (9 Regiones de las 121 Casillas)",
        rows: 3,
        cols: 3,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 3)}_${idx % 3}`,
          label,
          shortCoord,
          row: Math.floor(idx / 3),
          col: idx % 3,
        })),
      };
    }

    case "backgammon": {
      const specs: [string, string][] = [
        ["Casa J2 (Picos 1-6)", "Pts 0..5"],
        ["Exterior J2 (Picos 7-12)", "Pts 6..11"],
        ["Barra Central (Reingreso)", "Bar -1"],
        ["Exterior J1 (Picos 13-18)", "Pts 12..17"],
        ["Casa J1 (Picos 19-24)", "Pts 18..23"],
        ["Bear-Off & Cubo Doblaje", "Meta 24 / Cubo"],
      ];
      return {
        topologyLabel: "Cuadrantes de Backgammon 2×3 (24 Picos + Barra + Bear-Off)",
        rows: 2,
        cols: 3,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 3)}_${idx % 3}`,
          label,
          shortCoord,
          row: Math.floor(idx / 3),
          col: idx % 3,
        })),
      };
    }

    case "ludo":
    case "goose": {
      const isGoose = clean === "goose";
      const specs: [string, string][] = isGoose
        ? [
            ["Salida y Puente (0-8)", "Casillas 0-8"],
            ["Tramo Posada (9-18)", "Casillas 9-18"],
            ["Tramo Dados (19-27)", "Casillas 19-27"],
            ["Tramo Pozo (28-36)", "Casillas 28-36"],
            ["Tramo Laberinto (37-45)", "Casillas 37-45"],
            ["Tramo Cárcel (46-54)", "Casillas 46-54"],
            ["Tramo Calavera (55-59)", "Casillas 55-59"],
            ["Jardín de la Oca (60-63)", "Meta 60-63"],
          ]
        : [
            ["Base y Salida (0-6)", "Casillas 0-6"],
            ["Cuadrante Rojo (7-14)", "Casillas 7-14"],
            ["Cuadrante Verde (15-27)", "Casillas 15-27"],
            ["Cuadrante Amarillo (28-40)", "Casillas 28-40"],
            ["Cuadrante Azul (41-51)", "Casillas 41-51"],
            ["Estrellas Seguras", "8 Estrellas"],
            ["Pasillo de Color (52-56)", "Recta 52-56"],
            ["Triángulo Meta (57)", "Meta Exacta"],
          ];
      return {
        topologyLabel: isGoose
          ? "Espiral de la Oca 2×4 (8 Tramos de las 63 Casillas)"
          : "Circuito Ludo 2×4 (8 Sectores de 52 Casillas + Meta)",
        rows: 2,
        cols: 4,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 4)}_${idx % 4}`,
          label,
          shortCoord,
          row: Math.floor(idx / 4),
          col: idx % 4,
        })),
      };
    }

    case "monopoly": {
      const specs: [string, string][] = [
        ["Lado Sur (Marrón / Celeste)", "Casillas 0-9"],
        ["Cárcel y Lado Oeste (Rosa)", "Casillas 10-14"],
        ["Lado Oeste (Naranja)", "Casillas 15-19"],
        ["Lado Norte (Rojo)", "Casillas 20-24"],
        ["Lado Norte (Amarillo)", "Casillas 25-29"],
        ["Lado Este (Verde)", "Casillas 30-34"],
        ["Lado Este (Azul Oscuro)", "Casillas 35-39"],
        ["Edificación y Liquidez", "Casas / Reserva"],
      ];
      return {
        topologyLabel: "Sectores Económicos Monopoly 2×4 (40 Propiedades y Desarrollo)",
        rows: 2,
        cols: 4,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 4)}_${idx % 4}`,
          label,
          shortCoord,
          row: Math.floor(idx / 4),
          col: idx % 4,
        })),
      };
    }

    case "uno":
    case "mille_bornes": {
      const isUno = clean === "uno";
      const specs: [string, string][] = isUno
        ? [
            ["Zona Color Rojo", "Cartas Rojas"],
            ["Zona Color Amarillo", "Cartas Amarillas"],
            ["Zona Color Verde", "Cartas Verdes"],
            ["Zona Color Azul", "Cartas Azules"],
            ["Acción (+2 / Skip / Rev)", "Tácticas"],
            ["Comodines & Mazo (Wild/+4)", "Wild / Robar"],
          ]
        : [
            ["Velocidad Corta (25-75 km)", "Ritmo Base"],
            ["Velocidad Alta (100-200 km)", "Crucero"],
            ["Escudos Safeties (Coup Fourré)", "4 Escudos"],
            ["Remedios y Luz Verde", "Reparación"],
            ["Ataques (Hazards)", "Pinchazo/Accidente"],
            ["Descarte y Robo Táctico", "Gestión Mano"],
          ];
      return {
        topologyLabel: isUno
          ? "Matriz Táctica UNO 2×3 (Colores, Acciones y Comodines)"
          : "Matriz de Ruta Mil Millas 2×3 (Distancias, Safeties y Hazards)",
        rows: 2,
        cols: 3,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 3)}_${idx % 3}`,
          label,
          shortCoord,
          row: Math.floor(idx / 3),
          col: idx % 3,
        })),
      };
    }

    case "crisis":
    default: {
      const specs: [string, string][] = [
        ["América del Norte", "Territorios 0-5"],
        ["Europa", "Territorios 10-14"],
        ["Asia", "Territorios 19-25"],
        ["América del Sur", "Territorios 6-9"],
        ["África", "Territorios 15-18"],
        ["Oceanía y Reserva", "Territorios 26-29"],
      ];
      return {
        topologyLabel: "Teatros Continentales Crisis/TEG 2×3 (6 Continentes y 30 Territorios)",
        rows: 2,
        cols: 3,
        zones: specs.map(([label, shortCoord], idx) => ({
          zoneId: `z_${Math.floor(idx / 3)}_${idx % 3}`,
          label,
          shortCoord,
          row: Math.floor(idx / 3),
          col: idx % 3,
        })),
      };
    }
  }
}

function mapCandidateToZoneIndex(
  gameId: string,
  candidateObj: Record<string, unknown>,
  stateObj: Record<string, unknown>
): number {
  const clean = gameId.trim().toLowerCase().replace(/-/g, "_");
  switch (clean) {
    case "chess":
    case "checkers": {
      const to = Array.isArray(candidateObj.to)
        ? candidateObj.to
        : Array.isArray(candidateObj.from)
        ? candidateObj.from
        : [3, 3];
      const zr = Math.max(0, Math.min(3, Math.floor(Number(to[0] ?? 0) / 2)));
      const zc = Math.max(0, Math.min(3, Math.floor(Number(to[1] ?? 0) / 2)));
      return zr * 4 + zc;
    }

    case "go": {
      if (
        String(candidateObj.command_type || "").includes("Pass") &&
        candidateObj.row === undefined
      ) {
        return 4;
      }
      const r = Number(candidateObj.row ?? 4);
      const c = Number(candidateObj.col ?? 4);
      const zr = Math.max(0, Math.min(2, Math.floor(r / 3)));
      const zc = Math.max(0, Math.min(2, Math.floor(c / 3)));
      return zr * 3 + zc;
    }

    case "shogi": {
      const to = Array.isArray(candidateObj.to) ? candidateObj.to : [4, 4];
      const zr = Math.max(0, Math.min(2, Math.floor(Number(to[0] ?? 4) / 3)));
      const zc = Math.max(0, Math.min(2, Math.floor(Number(to[1] ?? 4) / 3)));
      return zr * 3 + zc;
    }

    case "xiangqi": {
      const to = Array.isArray(candidateObj.to) ? candidateObj.to : [4, 4];
      const tr = Number(to[0] ?? 4);
      const tc = Number(to[1] ?? 4);
      const zr = tr <= 3 ? 0 : tr <= 5 ? 1 : 2;
      const zc = Math.max(0, Math.min(2, Math.floor(tc / 3)));
      return zr * 3 + zc;
    }

    case "battleship": {
      const r = Number(candidateObj.row ?? 0);
      const c = Number(candidateObj.col ?? 0);
      const zr = Math.max(0, Math.min(4, Math.floor(r / 2)));
      const zc = Math.max(0, Math.min(4, Math.floor(c / 2)));
      return zr * 5 + zc;
    }

    case "chinese_checkers": {
      const toId = String(candidateObj.toId || candidateObj.to_id || "8_0");
      const [rStr, x2Str] = toId.split("_");
      const r = Number(rStr ?? 8);
      const x2 = Number(x2Str ?? 0);
      const zr = r <= 5 ? 0 : r <= 10 ? 1 : 2;
      const zc = x2 < -2 ? 0 : x2 > 2 ? 2 : 1;
      return zr * 3 + zc;
    }

    case "backgammon": {
      const rawType = String(candidateObj.command_type || "");
      if (rawType.includes("Double")) return 5;
      const from = Number(candidateObj.from ?? 0);
      const to = Number(candidateObj.to ?? 0);
      if (from === -1) return 2;
      if (to === 24 || to === -1) return 5;
      if (to >= 0 && to <= 5) return 0;
      if (to >= 6 && to <= 11) return 1;
      if (to >= 12 && to <= 17) return 3;
      return 4;
    }

    case "goose": {
      const p = Number(candidateObj.player || stateObj.turn || 1) as 1 | 2;
      const players = stateObj.players as Record<string, { square?: number }> | undefined;
      const curSq = Number(players?.[p]?.square ?? 0);
      const d1 = Number(candidateObj.d1 ?? 3);
      const d2 = Number(candidateObj.d2 ?? 4);
      const targetSq = Math.min(63, curSq + d1 + d2);
      if (targetSq <= 8) return 0;
      if (targetSq <= 18) return 1;
      if (targetSq <= 27) return 2;
      if (targetSq <= 36) return 3;
      if (targetSq <= 45) return 4;
      if (targetSq <= 54) return 5;
      if (targetSq <= 59) return 6;
      return 7;
    }

    case "ludo": {
      const p = Number(candidateObj.player || stateObj.turn || 1) as 1 | 2;
      const tokenIdx = Number(candidateObj.token_index ?? 0);
      const tokensMap = stateObj.tokens as Record<string, number[]> | undefined;
      const curPos = Number(tokensMap?.[p]?.[tokenIdx] ?? 0);
      const step = Number(candidateObj.steps ?? candidateObj.d1 ?? 6);
      const nextPos = curPos === 0 ? 1 : Math.min(57, curPos + step);
      const safeStars = new Set([1, 9, 14, 22, 27, 35, 40, 48]);
      if (nextPos === 57) return 7;
      if (nextPos >= 52) return 6;
      if (safeStars.has(nextPos)) return 5;
      if (nextPos <= 6) return 0;
      if (nextPos <= 14) return 1;
      if (nextPos <= 27) return 2;
      if (nextPos <= 40) return 3;
      return 4;
    }

    case "monopoly": {
      const rawType = String(candidateObj.command_type || "");
      if (rawType.includes("BuildHouse") || rawType.includes("PayJailFine")) {
        return 7;
      }
      const p = Number(candidateObj.player || stateObj.turn || 1) as 1 | 2;
      const posMap = stateObj.pos as Record<string, number> | undefined;
      const spaceIdx =
        candidateObj.space !== undefined
          ? Number(candidateObj.space)
          : Number(posMap?.[p] ?? 0);
      if (spaceIdx <= 9) return 0;
      if (spaceIdx <= 14) return 1;
      if (spaceIdx <= 19) return 2;
      if (spaceIdx <= 24) return 3;
      if (spaceIdx <= 29) return 4;
      if (spaceIdx <= 34) return 5;
      return 6;
    }

    case "uno": {
      const rawType = String(candidateObj.command_type || "");
      if (rawType.includes("DrawCard")) return 5;
      const cardObj = candidateObj.card as
        | { color?: string; value?: string }
        | undefined;
      let color = cardObj?.color;
      let val = cardObj?.value;
      if (!color && candidateObj.card_index !== undefined) {
        const p = Number(candidateObj.player || stateObj.turn || 1);
        const hands = stateObj.hands as
          | Record<string, { color?: string; value?: string }[]>
          | undefined;
        const fromHand = hands?.[p]?.[Number(candidateObj.card_index)];
        color = fromHand?.color;
        val = fromHand?.value;
      }
      if (color === "Wild" || val === "Wild" || val === "WildDrawFour") return 5;
      if (val === "Skip" || val === "Reverse" || val === "DrawTwo") return 4;
      if (color === "Red") return 0;
      if (color === "Yellow") return 1;
      if (color === "Green") return 2;
      if (color === "Blue") return 3;
      return 0;
    }

    case "mille_bornes": {
      let cardName = typeof candidateObj.card === "string" ? candidateObj.card : "";
      if (!cardName && candidateObj.card_index !== undefined) {
        const p = Number(candidateObj.player || stateObj.turn || 1);
        const hands = stateObj.hands as Record<string, string[]> | undefined;
        cardName = hands?.[p]?.[Number(candidateObj.card_index)] || "";
      }
      if (
        cardName.includes("25") ||
        cardName.includes("50") ||
        cardName.includes("75")
      ) {
        return 0;
      }
      if (cardName.includes("100") || cardName.includes("200")) {
        return 1;
      }
      if (
        cardName === "As del Volante" ||
        cardName === "Cisterna" ||
        cardName === "Impinchable" ||
        cardName === "Prioridad" ||
        cardName === "Incorruptible"
      ) {
        return 2;
      }
      if (
        cardName === "Reparaciones" ||
        cardName === "Gasolina" ||
        cardName === "Rueda de Auxilio" ||
        cardName === "Luz Verde"
      ) {
        return 3;
      }
      if (
        cardName === "Pinchazo" ||
        cardName === "Sin Gasolina" ||
        cardName === "Accidente"
      ) {
        return 4;
      }
      return 5;
    }

    case "crisis":
    default: {
      const terrId = Number(
        candidateObj.territory ??
          candidateObj.to ??
          candidateObj.from ??
          0
      );
      if (terrId <= 5) return 0; // América del Norte
      if (terrId <= 9) return 3; // América del Sur
      if (terrId <= 14) return 1; // Europa
      if (terrId <= 18) return 4; // África
      if (terrId <= 25) return 2; // Asia
      return 5; // Oceanía
    }
  }
}

/**
 * Construye el Mapa de Calor de Intensidad de Decisión (`DecisionIntensityHeatMap`)
 * para un estado de partida dado, mapeando la frecuencia de candidatos legales, la ventana Top-K
 * y las zonas donde aterrizaron la jugada óptima de la IA y la jugada ejecutada.
 */
export function computeDecisionIntensityHeatMapForState(
  gameId: string,
  stateJson: string,
  legalMovesJson: string,
  playedCommandJson?: string,
  bestCommandJson?: string,
  aiTelemetry?: AiMoveTelemetry | null
): DecisionIntensityHeatMap {
  const topology = getGameZoneTopology(gameId);
  let stateObj: Record<string, unknown> = {};
  try {
    stateObj = JSON.parse(stateJson) as Record<string, unknown>;
  } catch {
    stateObj = {};
  }

  let legalCandidates: Record<string, unknown>[] = [];
  try {
    const parsed = JSON.parse(legalMovesJson);
    if (Array.isArray(parsed)) {
      legalCandidates = parsed.filter(
        (item): item is Record<string, unknown> =>
          typeof item === "object" && item !== null
      );
    }
  } catch {
    legalCandidates = [];
  }

  const counts = new Array<number>(topology.zones.length).fill(0);
  for (const cand of legalCandidates) {
    const zIdx = mapCandidateToZoneIndex(gameId, cand, stateObj);
    const safeIdx = Math.max(0, Math.min(counts.length - 1, zIdx));
    counts[safeIdx] += 1;
  }

  let playedZoneIdx = -1;
  if (playedCommandJson) {
    try {
      const parsedPlayed = JSON.parse(playedCommandJson) as Record<string, unknown>;
      playedZoneIdx = Math.max(
        0,
        Math.min(
          counts.length - 1,
          mapCandidateToZoneIndex(gameId, parsedPlayed, stateObj)
        )
      );
    } catch {
      playedZoneIdx = -1;
    }
  }

  let optimalZoneIdx = -1;
  if (bestCommandJson) {
    try {
      const parsedBest = JSON.parse(bestCommandJson) as Record<string, unknown>;
      optimalZoneIdx = Math.max(
        0,
        Math.min(
          counts.length - 1,
          mapCandidateToZoneIndex(gameId, parsedBest, stateObj)
        )
      );
    } catch {
      optimalZoneIdx = -1;
    }
  }

  // Asegurar que al menos las zonas de jugada óptima o jugada realizada tengan representación cuando el juego usa comandos dinámicos
  if (legalCandidates.length === 0) {
    const fallbackIdx = optimalZoneIdx >= 0 ? optimalZoneIdx : playedZoneIdx >= 0 ? playedZoneIdx : 0;
    counts[fallbackIdx] += 1;
  }

  const totalCandidates = Math.max(
    1,
    counts.reduce((a, b) => a + b, 0)
  );
  const maxZoneCount = Math.max(1, ...counts);
  const totalTopK = aiTelemetry ? Math.max(1, aiTelemetry.top_k_candidates) : Math.max(1, Math.ceil(totalCandidates * 0.25));

  let peakZoneIdx = 0;
  for (let i = 1; i < counts.length; i++) {
    if (counts[i] > counts[peakZoneIdx]) {
      peakZoneIdx = i;
    }
  }

  const activeZonesCount = counts.filter((c) => c > 0).length;
  const entropyScore = Math.min(
    100,
    Math.max(5, Math.round((activeZonesCount / topology.zones.length) * 100))
  );

  const cells: BoardZoneHeatCell[] = topology.zones.map((z, idx) => {
    const count = counts[idx];
    const intensityPct =
      count === 0 ? 0 : Math.max(8, Math.round((count / maxZoneCount) * 100));
    const shareOfTotal = count / totalCandidates;
    const topKShareEstimate =
      count === 0
        ? 0
        : Math.max(
            idx === optimalZoneIdx ? 1 : 0,
            Math.round(shareOfTotal * totalTopK)
          );
    return {
      zoneId: z.zoneId,
      label: z.label,
      shortCoord: z.shortCoord,
      row: z.row,
      col: z.col,
      candidateCount: count,
      topKShareEstimate,
      intensityPct,
      hasPlayedMove: idx === playedZoneIdx,
      hasOptimalMove: idx === optimalZoneIdx,
    };
  });

  const peakSharePct = Math.max(
    1,
    Math.round((counts[peakZoneIdx] / totalCandidates) * 100)
  );

  return {
    gameId,
    topologyLabel: topology.topologyLabel,
    rows: topology.rows,
    cols: topology.cols,
    totalCandidates,
    peakZoneLabel: topology.zones[peakZoneIdx]?.label || "Centro",
    peakIntensityPct: peakSharePct,
    entropyScore,
    cells,
  };
}

/**
 * Agrega múltiples mapas de calor por turno en un único Mapa de Calor Acumulado de toda la partida.
 */
export function aggregateMatchDecisionHeatMaps(
  gameId: string,
  heatMaps: DecisionIntensityHeatMap[]
): DecisionIntensityHeatMap {
  if (heatMaps.length === 0) {
    return computeDecisionIntensityHeatMapForState(gameId, "{}", "[]");
  }
  const base = heatMaps[0];
  const sums = new Array<number>(base.cells.length).fill(0);
  const topKSums = new Array<number>(base.cells.length).fill(0);
  const hasPlayed = new Array<boolean>(base.cells.length).fill(false);
  const hasOptimal = new Array<boolean>(base.cells.length).fill(false);

  for (const hm of heatMaps) {
    hm.cells.forEach((cell, idx) => {
      if (idx < sums.length) {
        sums[idx] += cell.candidateCount;
        topKSums[idx] += cell.topKShareEstimate;
        if (cell.hasPlayedMove) hasPlayed[idx] = true;
        if (cell.hasOptimalMove) hasOptimal[idx] = true;
      }
    });
  }

  const totalCandidates = Math.max(
    1,
    sums.reduce((a, b) => a + b, 0)
  );
  const maxZoneCount = Math.max(1, ...sums);

  let peakZoneIdx = 0;
  for (let i = 1; i < sums.length; i++) {
    if (sums[i] > sums[peakZoneIdx]) {
      peakZoneIdx = i;
    }
  }

  const activeZonesCount = sums.filter((c) => c > 0).length;
  const entropyScore = Math.min(
    100,
    Math.max(5, Math.round((activeZonesCount / Math.max(1, base.cells.length)) * 100))
  );

  const cells: BoardZoneHeatCell[] = base.cells.map((c, idx) => {
    const count = sums[idx];
    const intensityPct =
      count === 0 ? 0 : Math.max(8, Math.round((count / maxZoneCount) * 100));
    return {
      ...c,
      candidateCount: count,
      topKShareEstimate: topKSums[idx],
      intensityPct,
      hasPlayedMove: hasPlayed[idx],
      hasOptimalMove: hasOptimal[idx],
    };
  });

  const peakSharePct = Math.max(
    1,
    Math.round((sums[peakZoneIdx] / totalCandidates) * 100)
  );

  return {
    gameId: base.gameId,
    topologyLabel: base.topologyLabel,
    rows: base.rows,
    cols: base.cols,
    totalCandidates,
    peakZoneLabel: base.cells[peakZoneIdx]?.label || "Centro",
    peakIntensityPct: peakSharePct,
    entropyScore,
    cells,
  };
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
 * Reconstruye y analiza jugada por jugada un historial de comandos en cualquiera de los 14 juegos,
 * incluyendo telemetría IA y mapas de calor de intensidad de decisión por zonas.
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
    const stateBeforeStr = sim.get_state_json();
    const legalBeforeStr = sim.get_legal_moves_json(mover);
    const evalBeforeP1 = evaluateStateJsonAdvantage(stateBeforeStr);

    // Consultar la línea recomendada y la telemetría de decisión de la IA Maestra (difficulty = 3)
    const oracle = new WasmGameBridge();
    oracle.start_ai_match(gameId, mover === 1 ? 2 : 1, mover, 3);
    oracle.apply_sync_log_json(gameId, sim.export_log_json());
    oracle.step_ai_if_needed();
    const oracleCmds = parseCommandsFromExportLog(oracle.export_log_json());
    const bestCmdItem = oracleCmds[oracleCmds.length - 1];
    const bestCommandJson = bestCmdItem ? bestCmdItem.command : item.command;
    const evalBestP1 = evaluateStateJsonAdvantage(oracle.get_state_json());

    let aiTelemetry: AiMoveTelemetry | null = null;
    try {
      const rawTel = oracle.get_last_ai_telemetry_json();
      if (rawTel && rawTel !== "null") {
        aiTelemetry = JSON.parse(rawTel) as AiMoveTelemetry;
      }
    } catch {
      aiTelemetry = null;
    }

    const zoneHeatMap = computeDecisionIntensityHeatMapForState(
      gameId,
      stateBeforeStr,
      legalBeforeStr,
      item.command,
      bestCommandJson,
      aiTelemetry
    );

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
      aiTelemetry,
      legalCandidatesCount: zoneHeatMap.totalCandidates,
      zoneHeatMap,
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

  const cumulativeHeatMap = aggregateMatchDecisionHeatMaps(
    gameId,
    entries.map((e) => e.zoneHeatMap)
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
    cumulativeHeatMap,
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
  const [heatMapScope, setHeatMapScope] = useState<"turn" | "match">("turn");
  const [inspectedZoneId, setInspectedZoneId] = useState<string | null>(null);

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

  const activeHeatMap: DecisionIntensityHeatMap =
    heatMapScope === "turn" && selectedEntry
      ? selectedEntry.zoneHeatMap
      : report.cumulativeHeatMap;

  const inspectedCell: BoardZoneHeatCell | null =
    activeHeatMap.cells.find((c) => c.zoneId === inspectedZoneId) ||
    activeHeatMap.cells.find((c) => c.hasOptimalMove) ||
    activeHeatMap.cells[0] ||
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

  const getHeatCellClasses = (cell: BoardZoneHeatCell, isSelectedZone: boolean) => {
    const p = cell.intensityPct;
    const ringClass = isSelectedZone
      ? "ring-2 ring-white"
      : cell.hasOptimalMove
      ? "ring-1 ring-emerald-400"
      : "";
    if (p === 0) {
      return `bg-slate-950/80 border-slate-800/80 text-slate-500 ${ringClass}`;
    }
    if (colorblindMode) {
      if (p >= 75) {
        return `bg-amber-500/30 border-amber-400 text-amber-100 ${ringClass}`;
      }
      if (p >= 45) {
        return `bg-sky-500/25 border-sky-400/80 text-sky-100 ${ringClass}`;
      }
      return `bg-sky-900/30 border-sky-700/70 text-slate-200 ${ringClass}`;
    }
    if (p >= 75) {
      return `bg-rose-500/30 border-rose-400 text-rose-100 ${ringClass}`;
    }
    if (p >= 45) {
      return `bg-amber-500/25 border-amber-400/80 text-amber-100 ${ringClass}`;
    }
    if (p >= 20) {
      return `bg-emerald-500/20 border-emerald-500/70 text-emerald-100 ${ringClass}`;
    }
    return `bg-sky-950/50 border-sky-800/70 text-slate-200 ${ringClass}`;
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

      {/* 03. Telemetría IA y Mapa de Calor de Intensidad de Decisión por Zonas */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-5">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3 border-b border-slate-800 pb-4">
          <div>
            <h3 className="text-sm font-bold text-white">
              03. Telemetría IA y Mapa de Calor de Intensidad de Decisión por Zonas
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Topología: <strong className="text-slate-200">{activeHeatMap.topologyLabel}</strong>{" "}
              · Mapea la frecuencia de candidatos legales y la ventana Top-K en una superposición térmica.
            </p>
          </div>

          {/* Conmutador de Alcance Temporal */}
          <div className="inline-flex items-center gap-1 p-1 bg-slate-950 border border-slate-800 rounded-xl shrink-0">
            <button
              type="button"
              onClick={() => setHeatMapScope("turn")}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                heatMapScope === "turn"
                  ? "bg-emerald-600 text-white"
                  : "text-slate-400 hover:text-white"
              }`}
            >
              Turno Seleccionado (#{selectedEntry?.ply ?? 1})
            </button>
            <button
              type="button"
              onClick={() => setHeatMapScope("match")}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                heatMapScope === "match"
                  ? "bg-emerald-600 text-white"
                  : "text-slate-400 hover:text-white"
              }`}
            >
              Partida Acumulada ({report.totalPlies} turnos)
            </button>
          </div>
        </div>

        {/* KPIs de Telemetría de Decisión IA */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 font-mono tabular-nums">
          <div className="bg-slate-950 border border-slate-800 rounded-xl p-3.5">
            <div className="text-[11px] font-sans text-slate-400">
              Perfil Estratégico IA
            </div>
            <div className="text-xs font-bold text-sky-400 mt-1 truncate">
              {selectedEntry?.aiTelemetry?.strategy_profile ??
                WasmGameBridge.strategyProfileForGame(activeGame, 3)}
            </div>
            <div className="text-[11px] text-slate-500 mt-1">
              Tiempo cómputo:{" "}
              <strong className="text-slate-300">
                {selectedEntry?.aiTelemetry?.elapsed_us ?? 45} µs
              </strong>
            </div>
          </div>

          <div className="bg-slate-950 border border-slate-800 rounded-xl p-3.5">
            <div className="text-[11px] font-sans text-slate-400">
              Densidad de Candidatos (Top-K / Total)
            </div>
            <div className="text-sm font-bold text-white mt-1">
              {heatMapScope === "turn"
                ? `${selectedEntry?.aiTelemetry?.top_k_candidates ?? 1} Top-K / ${activeHeatMap.totalCandidates} legales`
                : `${activeHeatMap.cells.reduce((acc, c) => acc + c.topKShareEstimate, 0)} Top-K / ${activeHeatMap.totalCandidates} acumulados`}
            </div>
            <div className="text-[11px] text-slate-500 mt-1">
              Score IA:{" "}
              <strong className="text-emerald-400">
                {selectedEntry?.aiTelemetry?.chosen_score ?? 100}
              </strong>{" "}
              (Ruido {selectedEntry?.aiTelemetry?.randomness_pct ?? 5}%)
            </div>
          </div>

          <div className="bg-slate-950 border border-slate-800 rounded-xl p-3.5">
            <div className="text-[11px] font-sans text-slate-400">
              Zona Hotspot de Mayor Presión
            </div>
            <div className="text-xs font-bold text-amber-400 mt-1 truncate">
              {activeHeatMap.peakZoneLabel}
            </div>
            <div className="text-[11px] text-slate-500 mt-1">
              Concentración:{" "}
              <strong className="text-slate-200">
                {activeHeatMap.peakIntensityPct}% del total
              </strong>
            </div>
          </div>

          <div className="bg-slate-950 border border-slate-800 rounded-xl p-3.5">
            <div className="text-[11px] font-sans text-slate-400">
              Dispersión Táctica (Entropía de Zonas)
            </div>
            <div className="text-sm font-bold text-emerald-400 mt-1">
              {activeHeatMap.entropyScore}% Zonas Activas
            </div>
            <div className="text-[11px] text-slate-500 mt-1 font-sans">
              ★ Zona Óptima IA · ● Zona Jugada Real
            </div>
          </div>
        </div>

        {/* Cuadrícula Superpuesta de Mapa de Calor (Heat-Map Grid) + Inspector de Zona */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
          <div className="lg:col-span-8 bg-slate-950 border border-slate-800 rounded-xl p-4 space-y-3">
            <div
              className="grid gap-2"
              style={{
                gridTemplateColumns: `repeat(${activeHeatMap.cols}, minmax(0, 1fr))`,
              }}
              role="grid"
              aria-label="Mapa de calor de intensidad de decisión por zonas del tablero"
            >
              {activeHeatMap.cells.map((cell) => {
                const isSelectedZone = inspectedCell?.zoneId === cell.zoneId;
                return (
                  <button
                    key={cell.zoneId}
                    type="button"
                    onClick={() => setInspectedZoneId(cell.zoneId)}
                    className={`p-2.5 rounded-lg border text-left transition-all flex flex-col justify-between gap-1.5 cursor-pointer ${getHeatCellClasses(
                      cell,
                      isSelectedZone
                    )}`}
                  >
                    <div className="flex items-start justify-between gap-1">
                      <span className="text-[11px] font-semibold leading-tight line-clamp-1">
                        {cell.label}
                      </span>
                      <span className="text-[10px] font-mono tabular-nums shrink-0">
                        {cell.hasOptimalMove ? "★" : ""}
                        {cell.hasPlayedMove ? "●" : ""}
                      </span>
                    </div>

                    <div className="flex items-baseline justify-between gap-1 font-mono tabular-nums">
                      <span className="text-xs font-bold">
                        {cell.candidateCount}{" "}
                        <span className="text-[10px] font-normal opacity-80">
                          cand.
                        </span>
                      </span>
                      <span className="text-[10px] opacity-90">
                        {cell.intensityPct}%
                      </span>
                    </div>

                    {/* Barra térmica proporcional */}
                    <div className="w-full h-1.5 bg-slate-900/90 rounded overflow-hidden">
                      <div
                        className={`h-full transition-all ${
                          colorblindMode
                            ? cell.intensityPct >= 75
                              ? "bg-amber-400"
                              : "bg-sky-400"
                            : cell.intensityPct >= 75
                            ? "bg-rose-400"
                            : cell.intensityPct >= 45
                            ? "bg-amber-400"
                            : "bg-emerald-400"
                        }`}
                        style={{ width: `${Math.max(4, cell.intensityPct)}%` }}
                      />
                    </div>
                  </button>
                );
              })}
            </div>

            {/* Leyenda de Escala Térmica */}
            <div className="pt-2 border-t border-slate-800/80 flex flex-wrap items-center justify-between gap-2 text-[11px] text-slate-400 font-mono">
              <span>
                Escala Térmica: 0% (Fría) → 25% (Exploración) → 50% (Disputada) → 100% (Hotspot Crítico)
              </span>
              <span>
                ★ Recomendación IA Nivel 4 · ● Movimiento Ejecutado
              </span>
            </div>
          </div>

          {/* Inspector Detallado de la Zona Seleccionada */}
          <div className="lg:col-span-4 bg-slate-950 border border-slate-800 rounded-xl p-4 space-y-3">
            <div className="border-b border-slate-800 pb-2.5">
              <div className="text-[11px] text-slate-400">
                Inspector de Zona Táctica
              </div>
              <div className="text-sm font-bold text-white mt-0.5">
                {inspectedCell?.label ?? "Selecciona una zona"}
              </div>
              <div className="text-xs font-mono text-slate-400 mt-0.5">
                Coordenadas / Sector: {inspectedCell?.shortCoord ?? "-"}
              </div>
            </div>

            {inspectedCell && (
              <div className="space-y-2.5 text-xs font-mono tabular-nums">
                <div className="flex items-center justify-between">
                  <span className="text-slate-400 font-sans">
                    Candidatos Evaluados:
                  </span>
                  <strong className="text-white">
                    {inspectedCell.candidateCount} de {activeHeatMap.totalCandidates}
                  </strong>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-slate-400 font-sans">
                    Candidatos en Banda Top-K:
                  </span>
                  <strong className="text-sky-400">
                    {inspectedCell.topKShareEstimate}
                  </strong>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-slate-400 font-sans">
                    Intensidad Térmica Relativa:
                  </span>
                  <strong className="text-amber-400">
                    {inspectedCell.intensityPct}%
                  </strong>
                </div>
                <div className="pt-2 border-t border-slate-800 space-y-1 font-sans">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-400">Línea Óptima IA (★):</span>
                    <span
                      className={
                        inspectedCell.hasOptimalMove
                          ? "text-emerald-400 font-semibold"
                          : "text-slate-500"
                      }
                    >
                      {inspectedCell.hasOptimalMove
                        ? "Objetivo prioritario"
                        : "Sin selección óptima"}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-400">Jugada Realizada (●):</span>
                    <span
                      className={
                        inspectedCell.hasPlayedMove
                          ? "text-sky-300 font-semibold"
                          : "text-slate-500"
                      }
                    >
                      {inspectedCell.hasPlayedMove
                        ? "Ejecutada en esta zona"
                        : "Otra zona"}
                    </span>
                  </div>
                </div>
              </div>
            )}
          </div>
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
            04. Registro Comparativo de Movimientos y Sugerencias del Motor
          </h3>
          <div className="overflow-y-auto max-h-80 border border-slate-800 rounded-xl">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-slate-950 text-slate-400 border-b border-slate-800">
                  <th className="py-2 px-3 font-medium">#</th>
                  <th className="py-2 px-3 font-medium">Jug.</th>
                  <th className="py-2 px-3 font-medium">Jugada Realizada</th>
                  <th className="py-2 px-3 font-medium">Óptima (IA 4)</th>
                  <th className="py-2 px-3 font-medium text-right">Cand.</th>
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
                    <td className="py-2 px-3 truncate max-w-[150px]">
                      {entry.summaryText}
                    </td>
                    <td className="py-2 px-3 text-slate-400 truncate max-w-[150px]">
                      {entry.bestMoveSummaryText}
                    </td>
                    <td className="py-2 px-3 text-right text-sky-400">
                      {entry.legalCandidatesCount}
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
