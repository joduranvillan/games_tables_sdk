import React, { useState } from "react";

interface ChineseCheckersBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

export const ChineseCheckersBoard: React.FC<ChineseCheckersBoardProps> = ({
  stateJson,
  legalMovesJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    cells: { id: string; r: number; c: number; owner: 0 | 1 | 2; zone: 0 | 1 | 2 }[];
  };

  const legalMoves = JSON.parse(legalMovesJson) as {
    fromId: string;
    toId: string;
  }[];

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

  return (
    <div className="w-full max-w-5xl flex flex-col lg:flex-row gap-8 items-start">
      {/* Hexagonal Star Grid */}
      <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl">
        <div className="grid grid-cols-9 gap-2">
          {state.cells.map((cell) => {
            const isSel = selectedId === cell.id;
            const isTarget =
              selectedId !== null &&
              legalMoves.some((m) => m.fromId === selectedId && m.toId === cell.id);

            return (
              <button
                key={cell.id}
                type="button"
                onClick={() => handleCellClick(cell.id, cell.owner)}
                disabled={!isLocalTurnAllowed || state.winner !== null}
                className={`w-9 h-9 sm:w-10 sm:h-10 rounded-full border flex items-center justify-center transition-all cursor-pointer ${
                  isSel
                    ? "ring-2 ring-emerald-400 scale-110"
                    : isTarget
                    ? "ring-2 ring-amber-400 bg-amber-500/20"
                    : ""
                } ${
                  cell.owner === 1
                    ? "bg-rose-500 border-white text-white font-bold"
                    : cell.owner === 2
                    ? "bg-sky-500 border-white text-white font-bold"
                    : cell.zone === 1
                    ? "bg-rose-950/50 border-rose-800/60"
                    : cell.zone === 2
                    ? "bg-sky-950/50 border-sky-800/60"
                    : "bg-slate-800 border-slate-700"
                }`}
              >
                <span className="text-[10px] font-mono">
                  {cell.owner === 1 ? "J1" : cell.owner === 2 ? "J2" : ""}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Info & Controls */}
      <div className="flex-1 w-full p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
        <div>
          <div className="text-xs text-slate-400">
            Damas Chinas (Halma Estrella) · Saltos en Cadena
          </div>
          <h3 className="text-lg font-bold text-white mt-0.5">
            {state.winner !== null
              ? `¡Victoria del Jugador ${state.winner}!`
              : `Turno del Jugador ${state.turn} (${
                  state.turn === 1 ? "Canicas Rojas" : "Canicas Azules"
                })`}
          </h3>
          {!isLocalTurnAllowed && state.winner === null && (
            <p className="text-xs text-amber-300 mt-1">
              Esperando turno del Jugador {state.turn} (Tú: J{localPlayerId})
            </p>
          )}
        </div>

        <p className="text-xs text-slate-300 leading-relaxed">
          Selecciona una canica propia y haz clic en cualquier casilla vacía adyacente o
          salto encadenado disponible para avanzar hacia el triángulo opuesto.
        </p>

        <div className="pt-3 border-t border-slate-800">
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
        </div>
      </div>
    </div>
  );
};
