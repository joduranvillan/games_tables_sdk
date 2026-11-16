import React from "react";
import { GoosePlayerState } from "../../wasm_pkg";
import { DiceRoller3D } from "../common/DiceRoller3D";

interface GooseBoardProps {
  stateJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const GOOSE_SET = new Set([5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59]);

function getSquareBadge(sq: number): { label: string; tone: string } | null {
  if (sq === 0) return { label: "SALIDA", tone: "text-slate-300" };
  if (sq === 63) return { label: "JARDÍN", tone: "text-emerald-300" };
  if (GOOSE_SET.has(sq)) return { label: "OCA", tone: "text-amber-300" };
  if (sq === 6 || sq === 12) return { label: "PUENTE", tone: "text-sky-300" };
  if (sq === 19) return { label: "POSADA", tone: "text-purple-300" };
  if (sq === 26 || sq === 53) return { label: "DADOS", tone: "text-emerald-300" };
  if (sq === 31) return { label: "POZO", tone: "text-orange-300" };
  if (sq === 42) return { label: "LABER.", tone: "text-pink-300" };
  if (sq === 52) return { label: "CÁRCEL", tone: "text-rose-300" };
  if (sq === 58) return { label: "CALAV.", tone: "text-rose-400" };
  return null;
}

export const GooseBoard: React.FC<GooseBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    players: Record<1 | 2, GoosePlayerState>;
    last_dice: [number, number];
    last_banner: string;
  };

  const squares = Array.from({ length: 64 }, (_, i) => i);

  const handleRoll = (d1: number, d2: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "goose_game::RollDiceCommand",
        player: state.turn,
        d1,
        d2,
      })
    );
  };

  return (
    <div className="w-full max-w-5xl flex flex-col gap-6">
      {/* Top Banner & DiceRoller3D */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-5 rounded-2xl bg-slate-900 border border-slate-800">
        <div className="flex flex-col gap-1">
          <div className="text-xs text-slate-400">
            El Juego de la Oca · Recorrido Canónico de 63 Casillas
          </div>
          <div className="text-sm font-semibold text-white">
            {state.last_banner}
          </div>
          <div className="flex items-center gap-4 text-xs text-slate-300 mt-1 font-mono tabular-nums">
            <span>
              Jugador 1 (Rojo): Casilla{" "}
              <strong className="text-white">{state.players[1].square}</strong>
            </span>
            <span>·</span>
            <span>
              Jugador 2 (Azul): Casilla{" "}
              <strong className="text-white">{state.players[2].square}</strong>
            </span>
            {!isLocalTurnAllowed && state.winner === null && (
              <>
                <span>·</span>
                <span className="text-amber-300">
                  Esperando turno del Jugador {state.turn} (Tú: J{localPlayerId})
                </span>
              </>
            )}
          </div>
        </div>

        <DiceRoller3D
          dice={state.last_dice}
          disabled={!isLocalTurnAllowed || state.winner !== null}
          onRoll={handleRoll}
        />
      </div>

      {/* 64-Square Grid (0..63) */}
      <div className="grid grid-cols-8 gap-2 p-4 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl">
        {squares.map((sq) => {
          const badge = getSquareBadge(sq);
          const p1Here = state.players[1].square === sq;
          const p2Here = state.players[2].square === sq;

          return (
            <div
              key={sq}
              className={`relative h-16 sm:h-18 rounded-xl p-2 border flex flex-col justify-between ${
                sq === 63
                  ? "bg-emerald-950/70 border-emerald-500/70"
                  : badge
                  ? "bg-slate-800/90 border-slate-600"
                  : "bg-slate-950/80 border-slate-800"
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="text-xs font-mono font-bold text-slate-300 tabular-nums">
                  {sq}
                </span>
                {badge && (
                  <span className={`text-[10px] font-bold ${badge.tone}`}>
                    {badge.label}
                  </span>
                )}
              </div>

              <div className="flex items-center gap-1.5">
                {p1Here && (
                  <span
                    title="Jugador 1"
                    className="w-5 h-5 rounded-full bg-rose-500 border border-white text-[10px] font-bold text-white flex items-center justify-center shadow-sm"
                  >
                    J1
                  </span>
                )}
                {p2Here && (
                  <span
                    title="Jugador 2"
                    className="w-5 h-5 rounded-full bg-sky-500 border border-white text-[10px] font-bold text-white flex items-center justify-center shadow-sm"
                  >
                    J2
                  </span>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
