import React, { useState } from "react";
import { UnoCard } from "../../wasm_pkg";
import { Layers, Sparkles } from "lucide-react";

interface UnoBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  isNetworkGame: boolean;
  onDispatchCommand: (cmdJson: string) => void;
}

const COLOR_STYLES: Record<UnoCard["color"], string> = {
  Red: "bg-rose-600 border-rose-300 text-white",
  Yellow: "bg-amber-400 border-amber-200 text-slate-950",
  Green: "bg-emerald-600 border-emerald-300 text-white",
  Blue: "bg-sky-600 border-sky-300 text-white",
  Wild: "bg-gradient-to-br from-rose-600 via-amber-500 to-sky-600 border-white text-white",
};

export const UnoBoard: React.FC<UnoBoardProps> = ({
  stateJson,
  legalMovesJson,
  isLocalTurnAllowed,
  localPlayerId,
  isNetworkGame,
  onDispatchCommand,
}) => {
  const [pendingWildIndex, setPendingWildIndex] = useState<number | null>(null);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    hands: Record<1 | 2, UnoCard[]>;
    top_card: UnoCard | null;
    active_color: "Red" | "Yellow" | "Green" | "Blue";
    deck_count: number;
    draw_penalty: number;
    uno_called: Record<1 | 2, boolean>;
    last_event: string;
  };

  const playableEntries = JSON.parse(legalMovesJson) as {
    card: UnoCard;
    index: number;
  }[];
  const playableIndices = new Set(playableEntries.map((e) => e.index));

  const viewingPlayer: 1 | 2 = isNetworkGame ? localPlayerId : state.turn;
  const opponentPlayer: 1 | 2 = viewingPlayer === 1 ? 2 : 1;
  const myHand = state.hands[viewingPlayer] || [];
  const oppHand = state.hands[opponentPlayer] || [];

  const handleCardClick = (idx: number, card: UnoCard) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    if (!playableIndices.has(idx)) return;
    if (card.color === "Wild") {
      setPendingWildIndex(idx);
      return;
    }
    onDispatchCommand(
      JSON.stringify({
        command_type: "PlayCardCommand",
        player: state.turn,
        card_index: idx,
      })
    );
  };

  const confirmWildColor = (color: "Red" | "Yellow" | "Green" | "Blue") => {
    if (pendingWildIndex === null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "PlayCardCommand",
        player: state.turn,
        card_index: pendingWildIndex,
        chosen_color: color,
      })
    );
    setPendingWildIndex(null);
  };

  return (
    <div className="w-full max-w-4xl flex flex-col gap-6 p-6 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl">
      {/* Opponent Hand Top Zone */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-4">
        <div className="text-xs text-slate-400">
          Mano del Jugador {opponentPlayer} ·{" "}
          <strong className="text-slate-100 font-mono tabular-nums">
            {oppHand.length} cartas
          </strong>
        </div>
        <div className="flex items-center gap-1.5">
          {oppHand.map((c) => (
            <div
              key={c.id}
              className="w-8 h-12 rounded-md bg-slate-800 border border-slate-600 flex items-center justify-center text-[10px] font-bold text-slate-400"
            >
              UNO
            </div>
          ))}
        </div>
      </div>

      {/* Center Table Zone: Draw Pile + Discard Pile + Active Color */}
      <div className="flex flex-col sm:flex-row items-center justify-around gap-6 py-4">
        <button
          type="button"
          disabled={!isLocalTurnAllowed || state.winner !== null}
          onClick={() =>
            onDispatchCommand(
              JSON.stringify({
                command_type: "DrawCardCommand",
                player: state.turn,
              })
            )
          }
          className="group flex flex-col items-center gap-2 p-4 rounded-xl bg-slate-800/90 hover:bg-slate-800 border border-slate-700 disabled:opacity-50 transition-colors cursor-pointer"
        >
          <div className="w-20 h-28 rounded-xl bg-slate-950 border-2 border-slate-600 flex flex-col items-center justify-center gap-1 shadow-md">
            <Layers className="w-6 h-6 text-emerald-400" />
            <span className="text-xs font-bold text-white">ROBAR</span>
            <span className="text-[11px] text-slate-400 font-mono tabular-nums">
              ({state.deck_count})
            </span>
          </div>
          <span className="text-xs text-slate-300">
            {state.draw_penalty > 0
              ? `Robar penalidad (+${state.draw_penalty})`
              : "Robar 1 carta"}
          </span>
        </button>

        {/* Top Discard Card */}
        <div className="flex flex-col items-center gap-2">
          {state.top_card && (
            <div
              className={`w-24 h-34 rounded-2xl border-2 flex flex-col items-center justify-between p-3 shadow-lg ${
                COLOR_STYLES[state.top_card.color]
              }`}
            >
              <span className="self-start text-xs font-bold">
                {state.top_card.value}
              </span>
              <span className="text-2xl font-extrabold">
                {state.top_card.value}
              </span>
              <span className="self-end text-xs font-bold">
                {state.top_card.color}
              </span>
            </div>
          )}
          <div className="text-xs text-slate-300">
            Color Activo:{" "}
            <strong className="text-white">{state.active_color}</strong>
          </div>
        </div>

        {/* Canonical UNO Controls */}
        <div className="flex flex-col gap-2.5 min-w-52">
          <div className="text-xs text-slate-400">{state.last_event}</div>
          <button
            type="button"
            disabled={!isLocalTurnAllowed || state.winner !== null}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "CallUnoCommand",
                  player: viewingPlayer,
                })
              )
            }
            className="flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-400 disabled:opacity-50 text-slate-950 font-bold text-xs transition-colors cursor-pointer"
          >
            <Sparkles className="w-4 h-4" />
            <span>¡Gritar UNO!</span>
          </button>
        </div>
      </div>

      {/* Wild Color Modal */}
      {pendingWildIndex !== null && (
        <div className="p-4 rounded-xl bg-slate-950 border border-slate-700 flex flex-wrap items-center justify-between gap-3">
          <span className="text-xs font-semibold text-white">
            Elige el color para el comodín:
          </span>
          <div className="flex items-center gap-2">
            {(["Red", "Yellow", "Green", "Blue"] as const).map((col) => (
              <button
                key={col}
                type="button"
                onClick={() => confirmWildColor(col)}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold border cursor-pointer ${COLOR_STYLES[col]}`}
              >
                {col}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Player Hand Bottom Zone */}
      <div className="border-t border-slate-800 pt-4">
        <div className="flex items-center justify-between mb-3">
          <span className="text-xs font-semibold text-slate-300">
            Mano activa — Jugador {viewingPlayer} ({myHand.length} cartas)
          </span>
          {!isLocalTurnAllowed && state.winner === null && (
            <span className="text-xs text-amber-300">
              Esperando turno del Jugador {state.turn}
            </span>
          )}
        </div>
        <div className="flex flex-wrap gap-2.5">
          {myHand.map((card, idx) => {
            const playable = isLocalTurnAllowed && playableIndices.has(idx);
            return (
              <button
                key={card.id}
                type="button"
                disabled={!playable}
                onClick={() => handleCardClick(idx, card)}
                className={`w-20 h-28 rounded-xl border-2 p-2 flex flex-col items-center justify-between transition-transform ${
                  COLOR_STYLES[card.color]
                } ${
                  playable
                    ? "hover:-translate-y-1.5 ring-2 ring-white cursor-pointer"
                    : "opacity-45 cursor-not-allowed"
                }`}
              >
                <span className="self-start text-[11px] font-bold">
                  {card.value}
                </span>
                <span className="text-lg font-extrabold">{card.value}</span>
                <span className="self-end text-[10px]">{card.color}</span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
};
