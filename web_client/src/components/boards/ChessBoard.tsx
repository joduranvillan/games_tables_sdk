import React, { useState } from "react";
import { ChessMove, ChessPiece } from "../../wasm_pkg";
import { Flag, Handshake, Shield } from "lucide-react";

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
    castling_rights?:
      | string
      | {
          p1_kingside: boolean;
          p1_queenside: boolean;
          p2_kingside: boolean;
          p2_queenside: boolean;
        };
    en_passant_target?: [number, number] | null;
    status_banner?: string;
  };
  const legalMoves = JSON.parse(legalMovesJson) as ChessMove[];

  const selectedTargets = selected
    ? legalMoves.filter((m) => m.from[0] === selected[0] && m.from[1] === selected[1])
    : [];

  const backRank = state.turn === 1 ? 7 : 0;
  const shortCastleMove = legalMoves.find(
    (m) =>
      m.from[0] === backRank &&
      m.from[1] === 4 &&
      m.to[0] === backRank &&
      m.to[1] === 6 &&
      state.grid[backRank]?.[4]?.kind === "King"
  );
  const longCastleMove = legalMoves.find(
    (m) =>
      m.from[0] === backRank &&
      m.from[1] === 4 &&
      m.to[0] === backRank &&
      m.to[1] === 2 &&
      state.grid[backRank]?.[4]?.kind === "King"
  );

  const handleSquareClick = (r: number, c: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;

    if (selected) {
      // Allow clicking either the target square (g1/c1 or g8/c8) OR the friendly Rook square (h1/a1 or h8/a8) when King is selected
      const isKingSelectedOnHome =
        selected[0] === backRank &&
        selected[1] === 4 &&
        state.grid[backRank]?.[4]?.kind === "King";

      if (isKingSelectedOnHome && r === backRank && c === 7 && shortCastleMove) {
        onDispatchCommand(
          JSON.stringify({
            command_type: "chess_game::MovePieceCommand",
            player: state.turn,
            from: [backRank, 4],
            to: [backRank, 6],
          })
        );
        setSelected(null);
        return;
      }

      if (isKingSelectedOnHome && r === backRank && c === 0 && longCastleMove) {
        onDispatchCommand(
          JSON.stringify({
            command_type: "chess_game::MovePieceCommand",
            player: state.turn,
            from: [backRank, 4],
            to: [backRank, 2],
          })
        );
        setSelected(null);
        return;
      }

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

  const castlingNotation =
    typeof state.castling_rights === "string"
      ? state.castling_rights === "-"
        ? "—"
        : state.castling_rights
      : state.castling_rights
      ? [
          state.castling_rights.p1_kingside ? "K" : "",
          state.castling_rights.p1_queenside ? "Q" : "",
          state.castling_rights.p2_kingside ? "k" : "",
          state.castling_rights.p2_queenside ? "q" : "",
        ].join("") || "—"
      : "KQkq";

  const epNotation = state.en_passant_target
    ? `${FILES[state.en_passant_target[1]]}${8 - state.en_passant_target[0]}`
    : "—";

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
              const isCastleTarget =
                selected?.[0] === backRank &&
                selected?.[1] === 4 &&
                state.grid[backRank]?.[4]?.kind === "King" &&
                r === backRank &&
                ((c === 6 && Boolean(shortCastleMove)) || (c === 2 && Boolean(longCastleMove)));

              return (
                <button
                  key={`${r}-${c}`}
                  type="button"
                  onClick={() => handleSquareClick(r, c)}
                  className={`relative w-11 h-11 sm:w-14 sm:h-14 flex items-center justify-center text-2xl sm:text-4xl select-none transition-colors cursor-pointer ${
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
                        isCastleTarget
                          ? "ring-4 ring-sky-400 bg-sky-400/70"
                          : cell
                          ? "ring-4 ring-emerald-400 bg-transparent"
                          : "bg-emerald-400/80"
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
          <div className="text-xs text-slate-400">Estado del Tablero FIDE (Motor Rust)</div>
          <div className="text-base font-semibold text-white mt-0.5">
            {state.winner !== null
              ? state.winner === 0
                ? "Tablas acordadas / Ahogado"
                : `Victoria del Jugador ${state.winner}`
              : `Turno del Jugador ${state.turn} (${state.turn === 1 ? "Blancas" : "Negras"})`}
          </div>
          {state.status_banner && (
            <div className="mt-1.5 text-xs text-emerald-300 font-medium">
              {state.status_banner}
            </div>
          )}
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

        {/* FIDE Telemetry Badges: Castling Rights & En Passant */}
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="p-2.5 rounded-xl bg-slate-950 border border-slate-800">
            <span className="text-slate-400 block text-[11px]">Derechos Enroque</span>
            <span className="font-mono font-bold text-sky-300">{castlingNotation}</span>
          </div>
          <div className="p-2.5 rounded-xl bg-slate-950 border border-slate-800">
            <span className="text-slate-400 block text-[11px]">Al Paso (e.p.)</span>
            <span className="font-mono font-bold text-amber-300">{epNotation}</span>
          </div>
        </div>

        {/* Direct Castling Buttons when legal */}
        {(shortCastleMove || longCastleMove) && (
          <div className="border-t border-slate-800 pt-3 flex flex-col gap-2">
            <div className="text-xs text-sky-300 font-semibold flex items-center gap-1.5">
              <Shield className="w-3.5 h-3.5" />
              <span>Enroque Disponible</span>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {shortCastleMove && (
                <button
                  type="button"
                  disabled={!isLocalTurnAllowed || state.winner !== null}
                  onClick={() => {
                    onDispatchCommand(
                      JSON.stringify({
                        command_type: "chess_game::MovePieceCommand",
                        player: state.turn,
                        from: shortCastleMove.from,
                        to: shortCastleMove.to,
                      })
                    );
                    setSelected(null);
                  }}
                  className="px-2.5 py-2 rounded-lg bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition-colors cursor-pointer"
                >
                  Corto (O-O)
                </button>
              )}
              {longCastleMove && (
                <button
                  type="button"
                  disabled={!isLocalTurnAllowed || state.winner !== null}
                  onClick={() => {
                    onDispatchCommand(
                      JSON.stringify({
                        command_type: "chess_game::MovePieceCommand",
                        player: state.turn,
                        from: longCastleMove.from,
                        to: longCastleMove.to,
                      })
                    );
                    setSelected(null);
                  }}
                  className="px-2.5 py-2 rounded-lg bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition-colors cursor-pointer"
                >
                  Largo (O-O-O)
                </button>
              )}
            </div>
          </div>
        )}

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
