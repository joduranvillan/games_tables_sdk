import React, { useState } from "react";
import { ChessMove, ChessPiece } from "../../wasm_pkg";
import { Flag, Handshake } from "lucide-react";

interface ChessBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const PIECE_SYMBOLS: Record<ChessPiece["kind"], { 1: string; 2: string }> = {
  King: { 1: "♔", 2: "♚" },
  Queen: { 1: "♕", 2: "♛" },
  Rook: { 1: "♖", 2: "♜" },
  Bishop: { 1: "♗", 2: "♝" },
  Knight: { 1: "♘", 2: "♞" },
  Pawn: { 1: "♙", 2: "♟" },
};

const FILES = ["a", "b", "c", "d", "e", "f", "g", "h"];

export const ChessBoard: React.FC<ChessBoardProps> = ({
  stateJson,
  legalMovesJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selected, setSelected] = useState<[number, number] | null>(null);
  const [pendingPromoMove, setPendingPromoMove] = useState<{
    from: [number, number];
    to: [number, number];
  } | null>(null);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    grid: (ChessPiece | null)[][];
    last_move: { from: [number, number]; to: [number, number] } | null;
    draw_offered_by: 1 | 2 | null;
    in_check: 1 | 2 | null;
  };
  const legalMoves = JSON.parse(legalMovesJson) as ChessMove[];

  const selectedTargets = selected
    ? legalMoves.filter((m) => m.from[0] === selected[0] && m.from[1] === selected[1])
    : [];

  const handleSquareClick = (r: number, c: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;

    if (selected) {
      const matching = selectedTargets.filter((m) => m.to[0] === r && m.to[1] === c);
      if (matching.length > 0) {
        if (matching.some((m) => m.promotion)) {
          setPendingPromoMove({ from: selected, to: [r, c] });
          return;
        }
        onDispatchCommand(
          JSON.stringify({
            command_type: "chess_game::MovePieceCommand",
            player: state.turn,
            from: selected,
            to: [r, c],
          })
        );
        setSelected(null);
        return;
      }
    }

    const cell = state.grid[r]?.[c];
    if (cell && cell.owner === state.turn) {
      setSelected([r, c]);
    } else {
      setSelected(null);
    }
  };

  const confirmPromotion = (piece: "Queen" | "Rook" | "Bishop" | "Knight") => {
    if (!pendingPromoMove) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "chess_game::MovePieceCommand",
        player: state.turn,
        from: pendingPromoMove.from,
        to: pendingPromoMove.to,
        promotion: piece,
      })
    );
    setPendingPromoMove(null);
    setSelected(null);
  };

  return (
    <div className="flex flex-col lg:flex-row items-center lg:items-start gap-8">
      {/* Main 8x8 Chessboard */}
      <div className="relative p-4 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl">
        <div className="grid grid-cols-8 border-2 border-slate-700 rounded-lg overflow-hidden">
          {state.grid.map((row, r) =>
            row.map((cell, c) => {
              const isLight = (r + c) % 2 === 0;
              const isSelected = selected?.[0] === r && selected?.[1] === c;
              const isTarget = selectedTargets.some((m) => m.to[0] === r && m.to[1] === c);
              const isLastMove =
                (state.last_move?.from[0] === r && state.last_move?.from[1] === c) ||
                (state.last_move?.to[0] === r && state.last_move?.to[1] === c);
              const isKingInCheck =
                cell?.kind === "King" && cell.owner === state.in_check;

              return (
                <button
                  key={`${r}-${c}`}
                  type="button"
                  onClick={() => handleSquareClick(r, c)}
                  className={`relative w-12 h-12 sm:w-15 sm:h-15 flex items-center justify-center text-3xl sm:text-4xl select-none transition-colors cursor-pointer ${
                    isKingInCheck
                      ? "bg-rose-600/80"
                      : isSelected
                      ? "bg-emerald-600/75"
                      : isLastMove
                      ? isLight
                        ? "bg-amber-200/90"
                        : "bg-amber-700/80"
                      : isLight
                      ? "bg-stone-200 hover:bg-stone-100"
                      : "bg-slate-700 hover:bg-slate-600"
                  }`}
                >
                  {c === 0 && (
                    <span
                      className={`absolute top-1 left-1.5 text-[10px] font-mono ${
                        isLight ? "text-slate-600" : "text-slate-300"
                      }`}
                    >
                      {8 - r}
                    </span>
                  )}
                  {r === 7 && (
                    <span
                      className={`absolute bottom-0.5 right-1.5 text-[10px] font-mono ${
                        isLight ? "text-slate-600" : "text-slate-300"
                      }`}
                    >
                      {FILES[c]}
                    </span>
                  )}
                  {cell && (
                    <span
                      className={
                        cell.owner === 1
                          ? "text-white drop-shadow-[0_2px_2px_rgba(15,23,42,0.95)]"
                          : "text-slate-950 drop-shadow-[0_1px_1px_rgba(255,255,255,0.6)]"
                      }
                    >
                      {PIECE_SYMBOLS[cell.kind][cell.owner]}
                    </span>
                  )}
                  {isTarget && (
                    <span
                      className={`w-3.5 h-3.5 rounded-full ${
                        cell ? "ring-4 ring-emerald-400 bg-transparent" : "bg-emerald-400/80"
                      }`}
                    />
                  )}
                </button>
              );
            })
          )}
        </div>

        {/* Promotion Selector Modal */}
        {pendingPromoMove && (
          <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-xs flex flex-col items-center justify-center rounded-2xl p-6 z-20">
            <h4 className="text-base font-semibold text-white mb-3">
              Selecciona pieza de coronación
            </h4>
            <div className="grid grid-cols-2 gap-3">
              {(["Queen", "Rook", "Bishop", "Knight"] as const).map((kind) => (
                <button
                  key={kind}
                  type="button"
                  onClick={() => confirmPromotion(kind)}
                  className="flex items-center gap-2 px-4 py-2.5 rounded-lg bg-slate-800 hover:bg-emerald-600 text-white text-sm font-medium border border-slate-700 transition-colors cursor-pointer"
                >
                  <span className="text-2xl">{PIECE_SYMBOLS[kind][state.turn]}</span>
                  <span>{kind}</span>
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Canonical Controls Side Panel */}
      <div className="w-full lg:w-72 flex flex-col gap-4 p-5 rounded-2xl bg-slate-900 border border-slate-800">
        <div>
          <div className="text-xs text-slate-400">Estado del Tablero</div>
          <div className="text-base font-semibold text-white mt-0.5">
            {state.winner !== null
              ? state.winner === 0
                ? "Tablas acordadas"
                : `Victoria del Jugador ${state.winner}`
              : `Turno del Jugador ${state.turn} (${state.turn === 1 ? "Blancas" : "Negras"})`}
          </div>
          {state.in_check && (
            <div className="mt-2 text-xs font-semibold text-rose-400">
              ¡Rey del Jugador {state.in_check} en Jaque!
            </div>
          )}
          {!isLocalTurnAllowed && state.winner === null && (
            <div className="mt-2 text-xs text-amber-300">
              Esperando jugada del oponente remoto (Tu rol: Jugador {localPlayerId})
            </div>
          )}
        </div>

        <div className="border-t border-slate-800 pt-4 flex flex-col gap-2.5">
          <div className="text-xs text-slate-400">Controles Canónicos FIDE</div>
          {state.draw_offered_by && state.draw_offered_by !== state.turn ? (
            <button
              type="button"
              disabled={!isLocalTurnAllowed}
              onClick={() =>
                onDispatchCommand(
                  JSON.stringify({
                    command_type: "AcceptDrawCommand",
                    player: state.turn,
                  })
                )
              }
              className="flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-amber-600 hover:bg-amber-500 text-white text-xs font-semibold transition-colors cursor-pointer"
            >
              <Handshake className="w-4 h-4" />
              <span>Aceptar Tablas de Jugador {state.draw_offered_by}</span>
            </button>
          ) : (
            <button
              type="button"
              disabled={!isLocalTurnAllowed || state.winner !== null}
              onClick={() =>
                onDispatchCommand(
                  JSON.stringify({
                    command_type: "OfferDrawCommand",
                    player: state.turn,
                  })
                )
              }
              className="flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-50 text-slate-200 text-xs font-medium border border-slate-700 transition-colors cursor-pointer"
            >
              <Handshake className="w-4 h-4" />
              <span>Ofrecer Tablas</span>
            </button>
          )}

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
            className="flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-rose-950/70 hover:bg-rose-900/80 disabled:opacity-50 text-rose-200 text-xs font-medium border border-rose-800/60 transition-colors cursor-pointer"
          >
            <Flag className="w-4 h-4" />
            <span>Rendirse</span>
          </button>
        </div>
      </div>
    </div>
  );
};
