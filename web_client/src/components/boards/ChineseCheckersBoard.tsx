import React, { useMemo, useState } from "react";
import { ChineseCheckersCell } from "../../wasm_pkg";

interface ChineseCheckersBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const ROW_INDICES = Array.from({ length: 17 }, (_, i) => i);

export const ChineseCheckersBoard: React.FC<ChineseCheckersBoardProps> = ({
  stateJson,
  legalMovesJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [showDecorativeArms, setShowDecorativeArms] = useState<boolean>(true);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    cells: ChineseCheckersCell[];
  };

  const legalMoves = JSON.parse(legalMovesJson) as {
    fromId: string;
    toId: string;
  }[];

  const rows = useMemo(() => {
    return ROW_INDICES.map((r) =>
      state.cells
        .filter((cell) => cell.r === r)
        .sort((a, b) => a.c - b.c)
    );
  }, [state.cells]);

  const targetMovesForSelected = useMemo(() => {
    if (!selectedId) return [];
    return legalMoves.filter((m) => m.fromId === selectedId);
  }, [selectedId, legalMoves]);

  const p1InGoalCount = useMemo(
    () => state.cells.filter((c) => c.zone === 2 && c.owner === 1).length,
    [state.cells]
  );
  const p2InGoalCount = useMemo(
    () => state.cells.filter((c) => c.zone === 1 && c.owner === 2).length,
    [state.cells]
  );

  const handleCellClick = (id: string, owner: 0 | 1 | 2) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;

    if (selectedId) {
      if (selectedId === id) {
        setSelectedId(null);
        return;
      }
      if (owner === state.turn) {
        setSelectedId(id);
        return;
      }
      if (owner === 0) {
        const isLegal = targetMovesForSelected.some((m) => m.toId === id);
        if (!isLegal) return;
        onDispatchCommand(
          JSON.stringify({
            command_type: "chinese_checkers_game::MoveMarbleCommand",
            player: state.turn,
            fromId: selectedId,
            toId: id,
          })
        );
        setSelectedId(null);
      }
      return;
    }

    if (owner === state.turn) {
      setSelectedId(id);
    }
  };

  const getHoleAppearance = (cell: ChineseCheckersCell, isSel: boolean, isTarget: boolean) => {
    let baseClasses = "";
    if (cell.owner === 1) {
      // Player 1 Red Marble (starts at Bottom Red point, aims for Top Green point)
      baseClasses =
        "bg-gradient-to-br from-rose-400 via-red-600 to-rose-900 border-2 border-white text-white shadow-[0_3px_8px_rgba(225,29,72,0.75)]";
    } else if (cell.owner === 2) {
      // Player 2 Green Marble (starts at Top Green point, aims for Bottom Red point)
      baseClasses =
        "bg-gradient-to-br from-lime-300 via-emerald-500 to-emerald-800 border-2 border-white text-slate-950 shadow-[0_3px_8px_rgba(16,185,129,0.75)]";
    } else if (showDecorativeArms && cell.zone === 3) {
      // Top-Left Blue triangle arm
      baseClasses =
        "bg-blue-600/85 hover:bg-blue-500 border-2 border-blue-200/70 text-white";
    } else if (showDecorativeArms && cell.zone === 4) {
      // Top-Right Yellow triangle arm
      baseClasses =
        "bg-yellow-400/90 hover:bg-yellow-300 border-2 border-yellow-100/80 text-slate-950";
    } else if (showDecorativeArms && cell.zone === 5) {
      // Bottom-Left Purple/Magenta triangle arm
      baseClasses =
        "bg-fuchsia-600/85 hover:bg-fuchsia-500 border-2 border-fuchsia-200/70 text-white";
    } else if (showDecorativeArms && cell.zone === 6) {
      // Bottom-Right Orange triangle arm
      baseClasses =
        "bg-orange-500/90 hover:bg-orange-400 border-2 border-orange-200/70 text-white";
    } else if (cell.zone === 2) {
      // Empty hole in Top Green triangle
      baseClasses =
        "bg-emerald-100 hover:bg-emerald-200 border-2 border-emerald-600 text-emerald-950";
    } else if (cell.zone === 1) {
      // Empty hole in Bottom Red triangle
      baseClasses =
        "bg-rose-100 hover:bg-rose-200 border-2 border-rose-600 text-rose-950";
    } else {
      // Central Hexagon White hole (matching reference image)
      baseClasses =
        "bg-white hover:bg-slate-100 border-2 border-slate-900 text-slate-900 shadow-inner";
    }

    if (isSel) {
      return `${baseClasses} ring-4 ring-amber-400 scale-115 z-10`;
    }
    if (isTarget) {
      return "bg-amber-300 hover:bg-amber-200 border-2 border-amber-600 ring-4 ring-amber-400/80 scale-110 z-10 animate-pulse";
    }
    return baseClasses;
  };

  return (
    <div className="w-full max-w-6xl flex flex-col xl:flex-row gap-6 items-center xl:items-start">
      {/* Classic 6-Pointed Star Board (121 Holes across 17 Staggered Rows) */}
      <div className="relative p-4 sm:p-6 rounded-3xl bg-slate-950 border-4 border-slate-800 shadow-2xl flex flex-col items-center overflow-x-auto max-w-full">
        {/* Decorative 6-Pointed Black Star SVG Backdrop matching reference image */}
        <svg
          viewBox="0 0 400 440"
          className="absolute inset-0 w-full h-full pointer-events-none opacity-90"
          preserveAspectRatio="xMidYMid meet"
        >
          <polygon
            points="200,12 252,115 375,115 314,220 375,325 252,325 200,428 148,325 25,325 86,220 25,115 148,115"
            fill="#090d16"
            stroke="#334155"
            strokeWidth="4"
            strokeLinejoin="round"
          />
        </svg>

        <div className="relative z-10 flex items-center justify-between w-full mb-2 px-2 text-[11px] font-bold">
          <span className="px-2.5 py-1 rounded-full bg-emerald-500/20 border border-emerald-500/40 text-emerald-300">
            ▲ Punta Superior Verde (Base J2 · Meta J1: {p1InGoalCount}/10)
          </span>
          <span className="px-2.5 py-1 rounded-full bg-slate-900 border border-slate-700 text-slate-300 font-mono">
            121 Casillas · Estrella Sternhalma
          </span>
        </div>

        {/* 17 Staggered Hexagonal Rows */}
        <div className="relative z-10 flex flex-col items-center gap-1 sm:gap-1.5 py-2 px-3">
          {rows.map((rowCells, rIdx) => (
            <div
              key={rIdx}
              className="flex items-center justify-center gap-1.5 sm:gap-2.5"
            >
              {rowCells.map((cell) => {
                const isSel = selectedId === cell.id;
                const isTarget = targetMovesForSelected.some((m) => m.toId === cell.id);
                const isJumpTarget =
                  isTarget &&
                  selectedId !== null &&
                  Math.abs(Number(selectedId.split("_")[0]) - cell.r) >= 2;

                return (
                  <button
                    key={cell.id}
                    type="button"
                    title={`Casilla (${cell.r}, ${cell.c})`}
                    onClick={() => handleCellClick(cell.id, cell.owner)}
                    disabled={!isLocalTurnAllowed || state.winner !== null}
                    className={`relative w-6 h-6 sm:w-8 sm:h-8 rounded-full flex items-center justify-center transition-all cursor-pointer select-none ${getHoleAppearance(
                      cell,
                      isSel,
                      isTarget
                    )}`}
                  >
                    {cell.owner === 1 && (
                      <span className="w-2 h-2 sm:w-2.5 sm:h-2.5 rounded-full bg-white/80 shadow-xs" />
                    )}
                    {cell.owner === 2 && (
                      <span className="w-2 h-2 sm:w-2.5 sm:h-2.5 rounded-full bg-slate-950/75 shadow-xs" />
                    )}
                    {isTarget && (
                      <span
                        className={`text-[9px] font-extrabold ${
                          isJumpTarget ? "text-rose-900" : "text-slate-950"
                        }`}
                      >
                        {isJumpTarget ? "⚡" : "•"}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          ))}
        </div>

        <div className="relative z-10 flex items-center justify-between w-full mt-2 px-2 text-[11px] font-bold">
          <span className="px-2.5 py-1 rounded-full bg-rose-500/20 border border-rose-500/40 text-rose-300">
            ▼ Punta Inferior Roja (Base J1 · Meta J2: {p2InGoalCount}/10)
          </span>
          <label className="flex items-center gap-1.5 text-slate-300 cursor-pointer">
            <input
              type="checkbox"
              checked={showDecorativeArms}
              onChange={(e) => setShowDecorativeArms(e.target.checked)}
              className="rounded accent-emerald-500"
            />
            <span>Colorear las 6 puntas</span>
          </label>
        </div>
      </div>

      {/* Side Control & Rules Panel */}
      <div className="w-full xl:w-80 p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
        <div>
          <div className="text-xs text-slate-400">
            Damas Chinas (Sternhalma) · Estrella de 6 Puntas
          </div>
          <h3 className="text-lg font-bold text-white mt-0.5">
            {state.winner !== null
              ? `🏆 ¡Victoria del Jugador ${state.winner}!`
              : `Turno del Jugador ${state.turn} (${
                  state.turn === 1 ? "Rojas ▼→▲" : "Verdes ▲→▼"
                })`}
          </h3>
          {!isLocalTurnAllowed && state.winner === null && (
            <p className="text-xs text-amber-300 mt-1">
              Esperando turno del Jugador {state.turn} (Tú: J{localPlayerId})
            </p>
          )}
        </div>

        {/* Score / Goal Progress Cards */}
        <div className="grid grid-cols-2 gap-2.5 text-xs">
          <div
            className={`p-3 rounded-xl border ${
              state.turn === 1
                ? "bg-rose-950/60 border-rose-500/70"
                : "bg-slate-950 border-slate-800"
            }`}
          >
            <div className="flex items-center gap-1.5 font-bold text-rose-300">
              <span className="w-3 h-3 rounded-full bg-rose-500 border border-white" />
              <span>Jugador 1 (Rojo)</span>
            </div>
            <div className="mt-1 font-mono text-sm font-bold text-white">
              {p1InGoalCount} / 10 en Meta ▲
            </div>
          </div>

          <div
            className={`p-3 rounded-xl border ${
              state.turn === 2
                ? "bg-emerald-950/60 border-emerald-500/70"
                : "bg-slate-950 border-slate-800"
            }`}
          >
            <div className="flex items-center gap-1.5 font-bold text-emerald-300">
              <span className="w-3 h-3 rounded-full bg-emerald-400 border border-white" />
              <span>Jugador 2 (Verde)</span>
            </div>
            <div className="mt-1 font-mono text-sm font-bold text-white">
              {p2InGoalCount} / 10 en Meta ▼
            </div>
          </div>
        </div>

        {/* Selected Marble Info */}
        <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 space-y-1.5">
          <div className="font-semibold text-white">
            {selectedId
              ? `Canica seleccionada (${targetMovesForSelected.length} destinos válidos)`
              : "Selecciona una de tus 10 canicas para ver sus pasos y saltos en cadena"}
          </div>
          <p className="text-[11px] text-slate-400 leading-relaxed">
            • <strong>Paso simple (•)</strong>: mueve a cualquiera de las 6 casillas hexagonales contiguas vacías.
            <br />• <strong>Salto en cadena BFS (⚡)</strong>: salta sobre una canica adyacente (propia o rival) hacia el hoyo simétrico vacío y encadena múltiples saltos en un solo turno.
          </p>
        </div>

        <div className="pt-2 border-t border-slate-800 flex items-center justify-between">
          <button
            type="button"
            disabled={!isLocalTurnAllowed || state.winner !== null}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "chinese_checkers_game::ResignCommand",
                  player: state.turn,
                })
              )
            }
            className="px-4 py-2 rounded-lg bg-rose-700 hover:bg-rose-600 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Rendirse
          </button>
          {selectedId && (
            <button
              type="button"
              onClick={() => setSelectedId(null)}
              className="px-3 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium cursor-pointer"
            >
              Cancelar selección
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
