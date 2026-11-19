import React, { useState } from "react";
import { ShogiPiece } from "../../wasm_pkg";

interface ShogiBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const SHOGI_LABELS: Record<ShogiPiece["kind"], string> = {
  King: "王",
  Rook: "飛",
  Bishop: "角",
  Gold: "金",
  Silver: "銀",
  Knight: "桂",
  Lance: "香",
  Pawn: "歩",
};

export const ShogiBoard: React.FC<ShogiBoardProps> = ({
  stateJson,
  legalMovesJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selectedSquare, setSelectedSquare] = useState<[number, number] | null>(null);
  const [selectedDropKind, setSelectedDropKind] = useState<ShogiPiece["kind"] | null>(null);
  const [promoteOnMove, setPromoteOnMove] = useState<boolean>(true);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    grid: (ShogiPiece | null)[][];
    hands: Record<1 | 2, ShogiPiece["kind"][]>;
  };

  const legalMoves = JSON.parse(legalMovesJson) as Array<{
    command_type: string;
    from?: [number, number];
    to: [number, number];
    kind?: ShogiPiece["kind"];
    promote?: boolean;
  }>;

  const validTargets = selectedSquare
    ? legalMoves.filter(
        (m) =>
          m.command_type === "shogi_game::MovePieceCommand" &&
          m.from?.[0] === selectedSquare[0] &&
          m.from?.[1] === selectedSquare[1]
      )
    : selectedDropKind
    ? legalMoves.filter(
        (m) =>
          m.command_type === "shogi_game::DropPieceCommand" &&
          m.kind === selectedDropKind
      )
    : [];

  const handleCellClick = (r: number, c: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    const cell = state.grid[r]?.[c];

    if (selectedDropKind) {
      if (!cell) {
        onDispatchCommand(
          JSON.stringify({
            command_type: "shogi_game::DropPieceCommand",
            player: state.turn,
            kind: selectedDropKind,
            to: [r, c],
          })
        );
        setSelectedDropKind(null);
      }
      return;
    }

    if (selectedSquare) {
      if (selectedSquare[0] === r && selectedSquare[1] === c) {
        setSelectedSquare(null);
        return;
      }
      if (cell && cell.owner === state.turn) {
        setSelectedSquare([r, c]);
        return;
      }
      const inPromoZone =
        state.turn === 1
          ? r <= 2 || selectedSquare[0] <= 2
          : r >= 6 || selectedSquare[0] >= 6;
      onDispatchCommand(
        JSON.stringify({
          command_type: "shogi_game::MovePieceCommand",
          player: state.turn,
          from: selectedSquare,
          to: [r, c],
          promote: inPromoZone && promoteOnMove,
        })
      );
      setSelectedSquare(null);
      return;
    }

    if (cell && cell.owner === state.turn) {
      setSelectedSquare([r, c]);
    }
  };

  return (
    <div className="w-full max-w-5xl flex flex-col lg:flex-row gap-8 items-start">
      {/* 9x9 Shogi Board */}
      <div className="p-4 rounded-2xl bg-amber-100/95 border-4 border-amber-900 shadow-2xl">
        <div className="grid grid-cols-9 gap-1">
          {state.grid.map((row, r) =>
            row.map((pc, c) => {
              const isSel =
                selectedSquare?.[0] === r && selectedSquare?.[1] === c;
              const isTarget = validTargets.some(
                (m) => m.to[0] === r && m.to[1] === c
              );
              return (
                <button
                  key={`${r}_${c}`}
                  type="button"
                  onClick={() => handleCellClick(r, c)}
                  disabled={!isLocalTurnAllowed || state.winner !== null}
                  className={`relative w-10 h-11 sm:w-12 sm:h-13 rounded border flex flex-col items-center justify-center transition-colors cursor-pointer ${
                    isSel
                      ? "bg-emerald-300 border-emerald-700"
                      : isTarget
                      ? "bg-emerald-200/90 border-emerald-600"
                      : "bg-amber-200/80 hover:bg-amber-300 border-amber-800/50"
                  }`}
                >
                  {pc && (
                    <div
                      className={`flex flex-col items-center leading-none ${
                        pc.owner === 2 ? "rotate-180" : ""
                      } ${pc.promoted ? "text-rose-700" : "text-slate-950"}`}
                    >
                      <span className="text-sm sm:text-base font-bold">
                        {pc.promoted ? `+${SHOGI_LABELS[pc.kind]}` : SHOGI_LABELS[pc.kind]}
                      </span>
                      <span className="text-[9px] font-mono opacity-75">
                        {pc.kind.slice(0, 3)}
                      </span>
                    </div>
                  )}
                  {isTarget && !pc && (
                    <span className="w-2.5 h-2.5 rounded-full bg-emerald-600/80" />
                  )}
                </button>
              );
            })
          )}
        </div>
      </div>

      {/* Komadai Trays & Controls */}
      <div className="flex-1 w-full p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-5">
        <div>
          <div className="text-xs text-slate-400">
            Shogi · Bandejas Komadai, Regla Nifu y Promoción FESA
          </div>
          <h3 className="text-lg font-bold text-white mt-0.5">
            {state.winner !== null
              ? `¡Victoria del Jugador ${state.winner}!`
              : `Turno de ${state.turn === 1 ? "Sente ☗ (J1)" : "Gote ☖ (J2)"}`}
          </h3>
          {!isLocalTurnAllowed && state.winner === null && (
            <p className="text-xs text-amber-300 mt-1">
              Esperando turno del Jugador {state.turn} (Tú: J{localPlayerId})
            </p>
          )}
        </div>

        {/* Komadai J1 & J2 */}
        {([1, 2] as const).map((pid) => (
          <div
            key={pid}
            className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col gap-2"
          >
            <div className="text-xs text-slate-400">
              Komadai Jugador {pid} ({pid === 1 ? "Sente ☗" : "Gote ☖"}):
            </div>
            <div className="flex flex-wrap gap-1.5">
              {state.hands[pid].length === 0 ? (
                <span className="text-xs text-slate-500">Sin capturas en mano</span>
              ) : (
                state.hands[pid].map((kind, i) => (
                  <button
                    key={`${kind}_${i}`}
                    type="button"
                    disabled={!isLocalTurnAllowed || state.turn !== pid}
                    onClick={() => {
                      setSelectedSquare(null);
                      setSelectedDropKind(selectedDropKind === kind ? null : kind);
                    }}
                    className={`px-2.5 py-1 rounded text-xs font-bold cursor-pointer ${
                      selectedDropKind === kind && state.turn === pid
                        ? "bg-emerald-600 text-white"
                        : "bg-slate-800 text-amber-200 hover:bg-slate-700"
                    }`}
                  >
                    {SHOGI_LABELS[kind]} ({kind})
                  </button>
                ))
              )}
            </div>
          </div>
        ))}

        {/* FESA Promotion Toggle */}
        <label className="flex items-center gap-2 text-xs text-slate-200 cursor-pointer">
          <input
            type="checkbox"
            checked={promoteOnMove}
            onChange={(e) => setPromoteOnMove(e.target.checked)}
            className="rounded accent-emerald-500"
          />
          <span>Promocionar automáticamente al entrar en zona enemiga (FESA)</span>
        </label>

        <div className="pt-2 border-t border-slate-800 flex gap-2">
          <button
            type="button"
            disabled={!isLocalTurnAllowed || state.winner !== null}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "shogi_game::ResignCommand",
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
