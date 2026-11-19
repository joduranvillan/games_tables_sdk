import React from "react";
import { BattleshipShip } from "../../wasm_pkg";

interface BattleshipBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const DEFAULT_FLEETS: Record<1 | 2, BattleshipShip[]> = {
  1: [
    {
      name: "Portaaviones",
      size: 5,
      cells: [
        [1, 1],
        [1, 2],
        [1, 3],
        [1, 4],
        [1, 5],
      ],
    },
    {
      name: "Acorazado",
      size: 4,
      cells: [
        [4, 4],
        [4, 5],
        [4, 6],
        [4, 7],
      ],
    },
    {
      name: "Crucero",
      size: 3,
      cells: [
        [6, 1],
        [7, 1],
        [8, 1],
      ],
    },
    {
      name: "Submarino",
      size: 3,
      cells: [
        [7, 5],
        [7, 6],
        [7, 7],
      ],
    },
    {
      name: "Destructor",
      size: 2,
      cells: [
        [2, 8],
        [3, 8],
      ],
    },
  ],
  2: [
    {
      name: "Portaaviones",
      size: 5,
      cells: [
        [0, 1],
        [0, 2],
        [0, 3],
        [0, 4],
        [0, 5],
      ],
    },
    {
      name: "Acorazado",
      size: 4,
      cells: [
        [2, 3],
        [2, 4],
        [2, 5],
        [2, 6],
      ],
    },
    {
      name: "Crucero",
      size: 3,
      cells: [
        [5, 2],
        [6, 2],
        [7, 2],
      ],
    },
    {
      name: "Submarino",
      size: 3,
      cells: [
        [6, 6],
        [6, 7],
        [6, 8],
      ],
    },
    {
      name: "Destructor",
      size: 2,
      cells: [
        [8, 4],
        [8, 5],
      ],
    },
  ],
};

interface ShipSegmentMeta {
  shipName: string;
  size: number;
  orientation: "horizontal" | "vertical";
  segmentIndex: number;
  isBow: boolean;
  isStern: boolean;
}

function buildShipCellLookup(fleet: BattleshipShip[]): Map<string, ShipSegmentMeta> {
  const map = new Map<string, ShipSegmentMeta>();
  for (const ship of fleet) {
    const isHorizontal =
      ship.cells.length > 1 && ship.cells[0][0] === ship.cells[1][0];
    ship.cells.forEach(([r, c], idx) => {
      map.set(`${r}_${c}`, {
        shipName: ship.name,
        size: ship.size,
        orientation: isHorizontal ? "horizontal" : "vertical",
        segmentIndex: idx,
        isBow: idx === 0,
        isStern: idx === ship.cells.length - 1,
      });
    });
  }
  return map;
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
    fleets?: Record<1 | 2, BattleshipShip[]>;
    sunk_ships?: Record<1 | 2, string[]>;
    extra_turn_on_hit: boolean;
    banner: string;
  };

  const activeCommander: 1 | 2 = state.turn;
  const enemyCommander: 1 | 2 = activeCommander === 1 ? 2 : 1;

  const fleets = state.fleets || DEFAULT_FLEETS;
  const sunkShips = state.sunk_ships || { 1: [], 2: [] };

  const ownFleetLookup = buildShipCellLookup(fleets[activeCommander] || DEFAULT_FLEETS[activeCommander]);
  const enemyFleetLookup = buildShipCellLookup(fleets[enemyCommander] || DEFAULT_FLEETS[enemyCommander]);

  const handleFireShot = (r: number, c: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    if (state.shots[activeCommander]?.[`${r}_${c}`]) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "battleship_game::FireShotCommand",
        player: activeCommander,
        row: r,
        col: c,
      })
    );
  };

  const toggleExtraTurnRule = () => {
    onDispatchCommand(
      JSON.stringify({
        command_type: "battleship_game::SetBattleshipRulesCommand",
        player: activeCommander,
        extra_turn_on_hit: !state.extra_turn_on_hit,
      })
    );
  };

  const rows = Array.from({ length: 10 }, (_, i) => i);
  const cols = Array.from({ length: 10 }, (_, i) => i);

  const renderShipHullDecorator = (seg: ShipSegmentMeta) => {
    const isCarrier = seg.shipName === "Portaaviones";
    const rounding =
      seg.orientation === "horizontal"
        ? `${seg.isBow ? "rounded-l-full pl-1" : ""} ${
            seg.isStern ? "rounded-r-xl pr-1" : ""
          }`
        : `${seg.isBow ? "rounded-t-full pt-1" : ""} ${
            seg.isStern ? "rounded-b-xl pb-1" : ""
          }`;

    return (
      <div
        className={`absolute inset-0.5 ${rounding} ${
          isCarrier
            ? "bg-gradient-to-b from-slate-500 via-slate-600 to-slate-800 border border-slate-300/70"
            : "bg-gradient-to-b from-stone-200 via-slate-300 to-slate-500 border border-white/90"
        } shadow-inner flex items-center justify-center pointer-events-none`}
      >
        {isCarrier ? (
          <span className="text-[8px] font-mono text-white/80 tracking-tighter">
            {seg.segmentIndex === 3 ? "✈️" : "- -"}
          </span>
        ) : (
          <span className="w-2.5 h-2.5 rounded-full bg-slate-600/80 border border-slate-400/80" />
        )}
      </div>
    );
  };

  return (
    <div className="w-full max-w-6xl flex flex-col gap-6">
      {/* Naval Command Header */}
      <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col lg:flex-row lg:items-center justify-between gap-4 shadow-lg">
        <div>
          <div className="text-xs text-sky-400 font-semibold">
            ⚓ Batalla Naval · Doble Tablero Marítimo 10×10 (5 Buques = 17 Impactos)
          </div>
          <h3 className="text-base sm:text-lg font-bold text-white mt-0.5">
            {state.banner}
          </h3>
          {!isLocalTurnAllowed && state.winner === null && (
            <p className="text-xs text-amber-300 mt-1">
              Esperando turno de J{state.turn} (Tú: J{localPlayerId})
            </p>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs font-mono">
            <span className="text-slate-400">Impactos J1: </span>
            <strong className="text-rose-400">{state.hits_count[1]}/17</strong>
          </div>
          <div className="px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs font-mono">
            <span className="text-slate-400">Impactos J2: </span>
            <strong className="text-sky-400">{state.hits_count[2]}/17</strong>
          </div>
          <button
            type="button"
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "battleship_game::RematchCommand",
                  player: activeCommander,
                })
              )
            }
            className="px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold cursor-pointer"
          >
            Nueva Partida
          </button>
        </div>
      </div>

      {/* Dual 10x10 Maritime Grids matching reference image */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 items-start">
        {/* 1. LEFT GRID: Enemy Waters Attack Radar */}
        <div className="p-4 sm:p-5 rounded-3xl bg-gradient-to-b from-[#0284c7] via-[#0369a1] to-[#075985] border-4 border-sky-300/80 shadow-2xl">
          <div className="flex items-center justify-between mb-3">
            <div>
              <span className="text-[11px] font-black uppercase tracking-wider text-sky-100 block">
                🎯 Radar de Ataque · Aguas del Jugador {enemyCommander}
              </span>
              <span className="text-xs text-sky-200">
                Haz clic en una coordenada para disparar como Jugador {activeCommander}
              </span>
            </div>
            <span className="px-2.5 py-1 rounded-full bg-rose-600 text-white text-xs font-bold shadow">
              Hundidos: {(sunkShips[activeCommander] || []).length}/5
            </span>
          </div>

          {/* Column Headers 1..10 */}
          <div className="grid grid-cols-11 gap-1 mb-1 text-center text-[10px] font-mono font-bold text-sky-100">
            <span />
            {cols.map((c) => (
              <span key={`atk_h_${c}`}>{c + 1}</span>
            ))}
          </div>

          <div className="flex flex-col gap-1">
            {rows.map((r) => (
              <div key={`atk_r_${r}`} className="grid grid-cols-11 gap-1 items-center">
                <span className="text-[10px] font-mono font-bold text-sky-100 text-center">
                  {String.fromCharCode(65 + r)}
                </span>
                {cols.map((c) => {
                  const key = `${r}_${c}`;
                  const shot = state.shots[activeCommander]?.[key];
                  const enemyShipSeg = enemyFleetLookup.get(key);
                  const isSunkEnemyShip =
                    enemyShipSeg !== undefined &&
                    (sunkShips[activeCommander] || []).includes(enemyShipSeg.shipName);

                  return (
                    <button
                      key={key}
                      type="button"
                      title={`Disparar a ${String.fromCharCode(65 + r)}${c + 1}`}
                      onClick={() => handleFireShot(r, c)}
                      disabled={
                        !isLocalTurnAllowed ||
                        state.winner !== null ||
                        Boolean(shot)
                      }
                      className={`relative aspect-square w-full min-h-[28px] sm:min-h-[34px] rounded border flex items-center justify-center transition-all cursor-pointer overflow-hidden ${
                        shot === "hit"
                          ? "bg-[#0284c7] border-amber-300 shadow-[inset_0_0_8px_rgba(249,115,22,0.9)]"
                          : shot === "miss"
                          ? "bg-[#0369a1]/90 border-sky-300/50"
                          : "bg-[#0284c7]/80 hover:bg-sky-400/50 border-sky-200/45"
                      }`}
                    >
                      {/* Reveal sunk enemy ship hull beneath flames */}
                      {(isSunkEnemyShip || (shot === "hit" && enemyShipSeg)) &&
                        enemyShipSeg &&
                        renderShipHullDecorator(enemyShipSeg)}

                      {/* Glowing Fire Explosion on Hit (matching reference image) */}
                      {shot === "hit" && (
                        <span className="relative z-10 w-5 h-5 sm:w-6 sm:h-6 rounded-md bg-gradient-to-t from-red-600 via-orange-500 to-yellow-200 border border-red-500 shadow-[0_0_10px_#f97316] flex items-center justify-center animate-pulse">
                          <span className="w-2.5 h-2.5 rounded-full bg-white shadow-[0_0_6px_#fff]" />
                        </span>
                      )}

                      {/* Pale Blue Water Splash Circle on Miss (matching reference image) */}
                      {shot === "miss" && (
                        <span className="relative z-10 w-3.5 h-3.5 sm:w-4 sm:h-4 rounded-full bg-sky-200/85 border border-white/80 shadow-inner" />
                      )}
                    </button>
                  );
                })}
              </div>
            ))}
          </div>
        </div>

        {/* 2. RIGHT GRID: Your Deployed Fleet (with 5 Illustrated Ships) */}
        <div className="p-4 sm:p-5 rounded-3xl bg-gradient-to-b from-[#0369a1] via-[#075985] to-[#0c4a6e] border-4 border-sky-400/70 shadow-2xl">
          <div className="flex items-center justify-between mb-3">
            <div>
              <span className="text-[11px] font-black uppercase tracking-wider text-sky-100 block">
                🚢 Tu Flota Desplegada · Jugador {activeCommander}
              </span>
              <span className="text-xs text-sky-200">
                5 buques ilustrados y disparos recibidos del Jugador {enemyCommander}
              </span>
            </div>
            <span className="px-2.5 py-1 rounded-full bg-sky-900 border border-sky-400/50 text-sky-100 text-xs font-bold">
              5 Buques Activos
            </span>
          </div>

          {/* Column Headers 1..10 */}
          <div className="grid grid-cols-11 gap-1 mb-1 text-center text-[10px] font-mono font-bold text-sky-100">
            <span />
            {cols.map((c) => (
              <span key={`def_h_${c}`}>{c + 1}</span>
            ))}
          </div>

          <div className="flex flex-col gap-1">
            {rows.map((r) => (
              <div key={`def_r_${r}`} className="grid grid-cols-11 gap-1 items-center">
                <span className="text-[10px] font-mono font-bold text-sky-100 text-center">
                  {String.fromCharCode(65 + r)}
                </span>
                {cols.map((c) => {
                  const key = `${r}_${c}`;
                  const ownShipSeg = ownFleetLookup.get(key);
                  const enemyShotHere = state.shots[enemyCommander]?.[key];

                  return (
                    <div
                      key={key}
                      title={
                        ownShipSeg
                          ? `${ownShipSeg.shipName} (${ownShipSeg.size} casillas)`
                          : `Mar (${String.fromCharCode(65 + r)}${c + 1})`
                      }
                      className="relative aspect-square w-full min-h-[28px] sm:min-h-[34px] rounded border border-sky-200/40 bg-[#0284c7]/75 flex items-center justify-center overflow-hidden"
                    >
                      {/* Render Illustrated Ship Hull Segment */}
                      {ownShipSeg && renderShipHullDecorator(ownShipSeg)}

                      {/* Enemy Hit Flame on our ship */}
                      {enemyShotHere === "hit" && (
                        <span className="relative z-10 w-5 h-5 sm:w-6 sm:h-6 rounded-md bg-gradient-to-t from-red-600 via-orange-500 to-yellow-200 border border-red-500 shadow-[0_0_10px_#f97316] flex items-center justify-center">
                          <span className="w-2.5 h-2.5 rounded-full bg-white" />
                        </span>
                      )}

                      {/* Enemy Miss Splash in our ocean */}
                      {enemyShotHere === "miss" && (
                        <span className="relative z-10 w-3.5 h-3.5 sm:w-4 sm:h-4 rounded-full bg-sky-200/85 border border-white/80" />
                      )}
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Fleet Status Roster & Extra Turn Toggle */}
      <div className="p-4 sm:p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-2 text-xs">
          <span className="text-slate-400 font-semibold mr-1">
            Estado de la Flota Enemiga (J{enemyCommander}):
          </span>
          {(fleets[enemyCommander] || DEFAULT_FLEETS[enemyCommander]).map((ship) => {
            const isSunk = (sunkShips[activeCommander] || []).includes(ship.name);
            return (
              <span
                key={ship.name}
                className={`px-2.5 py-1 rounded-lg border font-mono text-xs flex items-center gap-1.5 ${
                  isSunk
                    ? "bg-rose-950/80 border-rose-500/70 text-rose-200 line-through"
                    : "bg-slate-950 border-slate-800 text-slate-200"
                }`}
              >
                <span>{isSunk ? "🔥" : "🚢"}</span>
                <span>
                  {ship.name} ({ship.size})
                </span>
              </span>
            );
          })}
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
      </div>
    </div>
  );
};
