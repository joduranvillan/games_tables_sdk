import React, { useState } from "react";
import { CheckersMove, CheckersPiece } from "../../wasm_pkg";
import { Crown, Flag } from "lucide-react";

interface CheckersBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

export const CheckersBoard: React.FC<CheckersBoardProps> = ({
  stateJson,
  legalMovesJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selected, setSelected] = useState<[number, number] | null>(null);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    grid: (CheckersPiece | null)[][];
    mandatory_capture: boolean;
    chain_pos: [number, number] | null;
  };
  const legalMoves = JSON.parse(legalMovesJson) as CheckersMove[];

  const activeOrigin = state.chain_pos || selected;
  const targetsForOrigin = activeOrigin
    ? legalMoves.filter(
        (m) => m.from[0] === activeOrigin[0] && m.from[1] === activeOrigin[1]
      )
    : [];

  const handleSquareClick = (r: number, c: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;

    const matchingMove = targetsForOrigin.find((m) => m.to[0] === r && m.to[1] === c);
    if (matchingMove && activeOrigin) {
      onDispatchCommand(
        JSON.stringify({
          command_type: "checkers_game::MovePieceCommand",
          player: state.turn,
          from: activeOrigin,
          to: [r, c],
        })
      );
      setSelected(null);
      return;
    }

    if (state.chain_pos) return;
    const piece = state.grid[r]?.[c];
    if (piece && piece.owner === state.turn) {
      setSelected([r, c]);
    } else {
      setSelected(null);
    }
  };

  return (
    <div className="flex flex-col lg:flex-row items-center lg:items-start gap-8">
      <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl">
        <div className="grid grid-cols-8 border-2 border-slate-700 rounded-lg overflow-hidden">
          {state.grid.map((row, r) =>
            row.map((cell, c) => {
              const isDarkSquare = (r + c) % 2 === 1;
              const isSelected =
                activeOrigin?.[0] === r && activeOrigin?.[1] === c;
              const isTarget = targetsForOrigin.some(
                (m) => m.to[0] === r && m.to[1] === c
              );
              const canMoveThisPiece = legalMoves.some(
                (m) => m.from[0] === r && m.from[1] === c
              );

              return (
                <button
                  key={`${r}-${c}`}
                  type="button"
                  onClick={() => handleSquareClick(r, c)}
                  className={`relative w-12 h-12 sm:w-15 sm:h-15 flex items-center justify-center transition-colors cursor-pointer ${
                    isSelected
                      ? "bg-emerald-700"
                      : isDarkSquare
                      ? "bg-slate-800 hover:bg-slate-700"
                      : "bg-stone-200"
                  }`}
                >
                  {cell && (
                    <div
                      className={`w-9 h-9 sm:w-11 sm:h-11 rounded-full flex items-center justify-center border-2 shadow-md transition-transform ${
                        cell.owner === 1
                          ? "bg-rose-600 border-rose-300 text-white"
                          : "bg-slate-200 border-slate-400 text-slate-900"
                      } ${
                        canMoveThisPiece && isLocalTurnAllowed
                          ? "ring-2 ring-amber-400"
                          : ""
                      }`}
                    >
                      {cell.isKing && <Crown className="w-5 h-5" />}
                    </div>
                  )}
                  {isTarget && (
                    <span className="w-4 h-4 rounded-full bg-emerald-400 shadow-sm" />
                  )}
                </button>
              );
            })
          )}
        </div>
      </div>

      <div className="w-full lg:w-72 flex flex-col gap-4 p-5 rounded-2xl bg-slate-900 border border-slate-800">
        <div>
          <div className="text-xs text-slate-400">Reglas Oficiales de Damas</div>
          <div className="text-base font-semibold text-white mt-0.5">
            {state.winner !== null
              ? `Victoria del Jugador ${state.winner}`
              : `Turno del Jugador ${state.turn} (${state.turn === 1 ? "Rojas" : "Blancas"})`}
          </div>
          {state.mandatory_capture && state.winner === null && (
            <div className="mt-2 text-xs font-semibold text-amber-400">
              ¡Captura obligatoria disponible! Debes saltar sobre la pieza rival.
            </div>
          )}
          {!isLocalTurnAllowed && state.winner === null && (
            <div className="mt-2 text-xs text-amber-300">
              Turno bloqueado: esperando al Jugador {state.turn} (Tú eres Jugador{" "}
              {localPlayerId})
            </div>
          )}
        </div>

        <div className="border-t border-slate-800 pt-4">
          <button
            type="button"
            disabled={!isLocalTurnAllowed || state.winner !== null}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "ResignCommand",
                  player: state.turn,
                })
              )
            }
            className="w-full flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-rose-950/70 hover:bg-rose-900/80 disabled:opacity-50 text-rose-200 text-xs font-medium border border-rose-800/60 transition-colors cursor-pointer"
          >
            <Flag className="w-4 h-4" />
            <span>Rendirse</span>
          </button>
        </div>
      </div>
    </div>
  );
};
