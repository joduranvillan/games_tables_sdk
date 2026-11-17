import React from "react";

interface BattleshipBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

export const BattleshipBoard: React.FC<BattleshipBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    shots: Record<1 | 2, Record<string, "hit" | "miss">>;
    hits_count: Record<1 | 2, number>;
    extra_turn_on_hit: boolean;
    banner: string;
  };

  const handleFireShot = (r: number, c: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    if (state.shots[state.turn]?.[`${r}_${c}`]) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "battleship_game::FireShotCommand",
        player: state.turn,
        row: r,
        col: c,
      })
    );
  };

  const toggleExtraTurnRule = () => {
    onDispatchCommand(
      JSON.stringify({
        command_type: "battleship_game::SetBattleshipRulesCommand",
        player: state.turn,
        extra_turn_on_hit: !state.extra_turn_on_hit,
      })
    );
  };

  const rows = Array.from({ length: 10 }, (_, i) => i);
  const cols = Array.from({ length: 10 }, (_, i) => i);

  return (
    <div className="w-full max-w-5xl flex flex-col lg:flex-row gap-8 items-start">
      {/* 10x10 Tactical Radar Grid */}
      <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl">
        <div className="text-xs font-mono text-emerald-400 mb-3">
          RADAR TÁCTICO 10×10 · DISPARANDO COMO JUGADOR {state.turn}
        </div>
        <div className="grid grid-cols-10 gap-1.5">
          {rows.map((r) =>
            cols.map((c) => {
              const key = `${r}_${c}`;
              const shot = state.shots[state.turn]?.[key];
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => handleFireShot(r, c)}
                  disabled={!isLocalTurnAllowed || state.winner !== null || Boolean(shot)}
                  className={`w-9 h-9 sm:w-10 sm:h-10 rounded-lg border font-mono text-xs font-bold flex items-center justify-center transition-colors cursor-pointer ${
                    shot === "hit"
                      ? "bg-rose-600 border-rose-400 text-white"
                      : shot === "miss"
                      ? "bg-sky-950 border-sky-700 text-sky-300"
                      : "bg-slate-950 hover:bg-emerald-950/60 border-slate-800 text-slate-500"
                  }`}
                >
                  {shot === "hit" ? "💥" : shot === "miss" ? "•" : `${String.fromCharCode(65 + r)}${c + 1}`}
                </button>
              );
            })
          )}
        </div>
      </div>

      {/* Fleet Status & Canonical Controls */}
      <div className="flex-1 w-full p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-5">
        <div>
          <div className="text-xs text-slate-400">
            Batalla Naval · 5 Buques (5, 4, 3, 3, 2 = 17 Impactos)
          </div>
          <h3 className="text-lg font-bold text-white mt-0.5">{state.banner}</h3>
          {!isLocalTurnAllowed && state.winner === null && (
            <p className="text-xs text-amber-300 mt-1">
              Esperando turno de J{state.turn} (Tú: J{localPlayerId})
            </p>
          )}
        </div>

        <div className="grid grid-cols-2 gap-3 text-xs font-mono">
          <div className="p-3 rounded-xl bg-slate-950 border border-slate-800">
            <div className="text-slate-400">Impactos Jugador 1</div>
            <div className="text-base font-bold text-white mt-1">
              {state.hits_count[1]} / 17
            </div>
          </div>
          <div className="p-3 rounded-xl bg-slate-950 border border-slate-800">
            <div className="text-slate-400">Impactos Jugador 2</div>
            <div className="text-base font-bold text-white mt-1">
              {state.hits_count[2]} / 17
            </div>
          </div>
        </div>

        <label className="flex items-center gap-2 text-xs text-slate-200 cursor-pointer">
          <input
            type="checkbox"
            checked={state.extra_turn_on_hit}
            onChange={toggleExtraTurnRule}
            className="rounded accent-emerald-500"
          />
          <span>Regla Ráfaga: conservar turno al impactar un buque enemigo</span>
        </label>

        <div className="pt-3 border-t border-slate-800 flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "battleship_game::RematchCommand",
                  player: state.turn,
                })
              )
            }
            className="px-4 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold cursor-pointer"
          >
            Solicitar Revancha (Rematch)
          </button>
        </div>
      </div>
    </div>
  );
};
