import React, { useState } from "react";
import { Play, FastForward, RotateCcw, Trophy } from "lucide-react";

export type TournamentFormat = "round_robin" | "single_elimination";

export interface TournamentParticipant {
  id: string;
  name: string;
  kind: "human" | "ai";
  aiDifficulty: number; // 0..3
  seedRating: number;
}

export interface TournamentMatchItem {
  id: string;
  round: number;
  player1Id: string;
  player2Id: string;
  winnerId: string | null; // "draw" if draw in round_robin, or participant id
  status: "pending" | "completed";
}

export interface TournamentState {
  id: string;
  title: string;
  gameId: string;
  format: TournamentFormat;
  participants: TournamentParticipant[];
  matches: TournamentMatchItem[];
  championId: string | null;
}

export interface StandingsRow {
  participant: TournamentParticipant;
  played: number;
  wins: number;
  draws: number;
  losses: number;
  points: number;
}

export const TOURNAMENT_STORAGE_KEY = "opentable.active_tournament";

export function createDefaultParticipants(): TournamentParticipant[] {
  return [
    {
      id: "p1",
      name: "Jugador Local",
      kind: "human",
      aiDifficulty: 1,
      seedRating: 1200,
    },
    {
      id: "p2",
      name: "Bot Táctico (Media)",
      kind: "ai",
      aiDifficulty: 1,
      seedRating: 1200,
    },
    {
      id: "p3",
      name: "Bot Maestro (Difícil)",
      kind: "ai",
      aiDifficulty: 2,
      seedRating: 1400,
    },
    {
      id: "p4",
      name: "Bot Gran Maestro",
      kind: "ai",
      aiDifficulty: 3,
      seedRating: 1600,
    },
  ];
}

/**
 * Genera el calendario completo de un torneo Round-Robin (Todos contra Todos)
 * mediante el algoritmo cíclico de tablas de Berger, o la primera ronda de Eliminatoria Directa.
 */
export function createTournament(
  gameId: string,
  format: TournamentFormat,
  participants: TournamentParticipant[] = createDefaultParticipants(),
  title: string = "Copa Oficial OpenTable"
): TournamentState {
  const cleanParticipants =
    participants.length >= 2 ? participants : createDefaultParticipants();
  const matches: TournamentMatchItem[] = [];

  if (format === "round_robin") {
    const list = [...cleanParticipants];
    if (list.length % 2 !== 0) {
      list.push({
        id: "bye",
        name: "BYE",
        kind: "ai",
        aiDifficulty: 0,
        seedRating: 1000,
      });
    }
    const n = list.length;
    const rounds = n - 1;
    const half = n / 2;
    let matchCounter = 1;

    const rotating = [...list];
    for (let r = 1; r <= rounds; r++) {
      for (let i = 0; i < half; i++) {
        const p1 = rotating[i];
        const p2 = rotating[n - 1 - i];
        if (p1.id !== "bye" && p2.id !== "bye") {
          matches.push({
            id: `rr_m${matchCounter++}`,
            round: r,
            player1Id: r % 2 === 1 ? p1.id : p2.id,
            player2Id: r % 2 === 1 ? p2.id : p1.id,
            winnerId: null,
            status: "pending",
          });
        }
      }
      // Rotate all except index 0
      const last = rotating.pop()!;
      rotating.splice(1, 0, last);
    }
  } else {
    // Single Elimination (Knockout)
    let matchCounter = 1;
    for (let i = 0; i + 1 < cleanParticipants.length; i += 2) {
      matches.push({
        id: `se_r1_m${matchCounter++}`,
        round: 1,
        player1Id: cleanParticipants[i].id,
        player2Id: cleanParticipants[i + 1].id,
        winnerId: null,
        status: "pending",
      });
    }
  }

  const state: TournamentState = {
    id: `tour_${Date.now()}`,
    title,
    gameId,
    format,
    participants: cleanParticipants,
    matches,
    championId: null,
  };
  saveTournamentState(state);
  return state;
}

export function computeTournamentStandings(
  tournament: TournamentState
): StandingsRow[] {
  const map = new Map<string, StandingsRow>();
  for (const p of tournament.participants) {
    map.set(p.id, {
      participant: p,
      played: 0,
      wins: 0,
      draws: 0,
      losses: 0,
      points: 0,
    });
  }

  for (const m of tournament.matches) {
    if (m.status !== "completed" || !m.winnerId) continue;
    const row1 = map.get(m.player1Id);
    const row2 = map.get(m.player2Id);
    if (!row1 || !row2) continue;

    row1.played += 1;
    row2.played += 1;

    if (m.winnerId === "draw") {
      row1.draws += 1;
      row2.draws += 1;
      row1.points += 1;
      row2.points += 1;
    } else if (m.winnerId === m.player1Id) {
      row1.wins += 1;
      row2.losses += 1;
      row1.points += 3;
    } else if (m.winnerId === m.player2Id) {
      row2.wins += 1;
      row1.losses += 1;
      row2.points += 3;
    }
  }

  return Array.from(map.values()).sort((a, b) => {
    if (b.points !== a.points) return b.points - a.points;
    if (b.wins !== a.wins) return b.wins - a.wins;
    return b.participant.seedRating - a.participant.seedRating;
  });
}

/**
 * Registra el resultado de un encuentro del torneo y, en Eliminatoria Directa,
 * genera automáticamente la siguiente ronda cuando todos los cruces de la ronda actual terminan.
 */
export function recordTournamentMatchResult(
  tournament: TournamentState,
  matchId: string,
  winnerId: string
): TournamentState {
  const updatedMatches = tournament.matches.map((m) =>
    m.id === matchId
      ? { ...m, winnerId, status: "completed" as const }
      : m
  );

  let nextMatches = [...updatedMatches];
  let championId = tournament.championId;

  if (tournament.format === "single_elimination") {
    const maxRound = nextMatches.reduce((max, m) => Math.max(max, m.round), 1);
    const currentRoundMatches = nextMatches.filter((m) => m.round === maxRound);
    const allCompleted = currentRoundMatches.every(
      (m) => m.status === "completed" && m.winnerId && m.winnerId !== "draw"
    );

    if (allCompleted) {
      const winners = currentRoundMatches.map((m) => m.winnerId!);
      if (winners.length === 1) {
        championId = winners[0];
      } else if (winners.length >= 2) {
        const nextRound = maxRound + 1;
        let idxCounter = 1;
        for (let i = 0; i + 1 < winners.length; i += 2) {
          nextMatches.push({
            id: `se_r${nextRound}_m${idxCounter++}`,
            round: nextRound,
            player1Id: winners[i],
            player2Id: winners[i + 1],
            winnerId: null,
            status: "pending",
          });
        }
      }
    }
  } else {
    // Round-robin: if all matches are completed, top of standings is champion
    const allDone = nextMatches.every((m) => m.status === "completed");
    if (allDone && nextMatches.length > 0) {
      const tempState: TournamentState = {
        ...tournament,
        matches: nextMatches,
      };
      const standings = computeTournamentStandings(tempState);
      if (standings.length > 0) {
        championId = standings[0].participant.id;
      }
    }
  }

  const nextState: TournamentState = {
    ...tournament,
    matches: nextMatches,
    championId,
  };
  saveTournamentState(nextState);
  return nextState;
}

export function loadTournamentState(defaultGameId: string = "chess"): TournamentState {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      const raw = window.localStorage.getItem(TOURNAMENT_STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed && Array.isArray(parsed.matches)) {
          return parsed;
        }
      }
    }
  } catch {
    // Ignore storage errors
  }
  return createTournament(defaultGameId, "round_robin");
}

export function saveTournamentState(state: TournamentState): TournamentState {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      window.localStorage.setItem(TOURNAMENT_STORAGE_KEY, JSON.stringify(state));
    }
  } catch {
    // Ignore storage errors
  }
  return state;
}

interface TournamentManagerPanelProps {
  tournament: TournamentState;
  gameTitles: Record<string, string>;
  activeMatchId: string | null;
  onUpdateTournament: (next: TournamentState) => void;
  onLaunchMatchOnBoard: (match: TournamentMatchItem, gameId: string) => void;
  onTournamentChampionCrowned?: (champion: TournamentParticipant) => void;
}

export const TournamentManagerPanel: React.FC<TournamentManagerPanelProps> = ({
  tournament,
  gameTitles,
  activeMatchId,
  onUpdateTournament,
  onLaunchMatchOnBoard,
  onTournamentChampionCrowned,
}) => {
  const [selectedGame, setSelectedGame] = useState<string>(tournament.gameId);
  const [selectedFormat, setSelectedFormat] = useState<TournamentFormat>(
    tournament.format
  );

  const standings = computeTournamentStandings(tournament);
  const participantMap = new Map(
    tournament.participants.map((p) => [p.id, p])
  );

  const handleCreateNewTournament = () => {
    const fresh = createTournament(
      selectedGame,
      selectedFormat,
      createDefaultParticipants()
    );
    onUpdateTournament(fresh);
  };

  const handleResolveMatch = (match: TournamentMatchItem, winnerId: string) => {
    const prevChamp = tournament.championId;
    const next = recordTournamentMatchResult(tournament, match.id, winnerId);
    onUpdateTournament(next);
    if (!prevChamp && next.championId) {
      const champ = participantMap.get(next.championId);
      if (champ && onTournamentChampionCrowned) {
        onTournamentChampionCrowned(champ);
      }
    }
  };

  const handleSimulateNextPendingMatch = () => {
    const pending = tournament.matches.find((m) => m.status === "pending");
    if (!pending) return;
    const p1 = participantMap.get(pending.player1Id);
    const p2 = participantMap.get(pending.player2Id);
    const winnerId =
      (p1?.seedRating ?? 1200) >= (p2?.seedRating ?? 1200)
        ? pending.player1Id
        : pending.player2Id;
    handleResolveMatch(pending, winnerId);
  };

  const champion = tournament.championId
    ? participantMap.get(tournament.championId)
    : null;

  return (
    <section className="flex flex-col gap-6">
      {/* Tournament Setup Header */}
      <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 text-xs text-slate-400">
            <span>Organizador de Torneos Oficiales</span>
            <span aria-hidden="true">·</span>
            <span>
              {tournament.format === "round_robin"
                ? "Formato Round-Robin (Tablas de Berger)"
                : "Formato Eliminatoria Directa (Knockout)"}
            </span>
          </div>
          <h2 className="text-2xl font-bold text-white font-display mt-1">
            {tournament.title} — {gameTitles[tournament.gameId] || tournament.gameId}
          </h2>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <select
            aria-label="Juego del torneo"
            value={selectedGame}
            onChange={(e) => setSelectedGame(e.target.value)}
            className="px-3 py-2 rounded-lg bg-slate-950 border border-slate-700 text-xs text-slate-200"
          >
            {Object.entries(gameTitles).map(([id, title]) => (
              <option key={id} value={id}>
                {title}
              </option>
            ))}
          </select>

          <select
            aria-label="Formato del torneo"
            value={selectedFormat}
            onChange={(e) =>
              setSelectedFormat(e.target.value as TournamentFormat)
            }
            className="px-3 py-2 rounded-lg bg-slate-950 border border-slate-700 text-xs text-slate-200"
          >
            <option value="round_robin">Round-Robin (Todos contra Todos)</option>
            <option value="single_elimination">
              Eliminatoria Directa (Knockout)
            </option>
          </select>

          <button
            type="button"
            onClick={handleCreateNewTournament}
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors cursor-pointer"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>Generar Nuevo Torneo</span>
          </button>

          <button
            type="button"
            onClick={handleSimulateNextPendingMatch}
            disabled={!tournament.matches.some((m) => m.status === "pending")}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-40 text-slate-200 text-xs font-medium transition-colors cursor-pointer"
          >
            <FastForward className="w-3.5 h-3.5" />
            <span>Simular Siguiente Cruce IA</span>
          </button>
        </div>
      </div>

      {/* Champion Banner if finished */}
      {champion && (
        <div className="p-5 rounded-2xl bg-slate-900 border border-amber-500/60 flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <Trophy className="w-6 h-6 text-amber-400 shrink-0" />
            <div>
              <div className="text-xs text-amber-300 font-medium">
                Torneo Finalizado · Campeón Oficial
              </div>
              <div className="text-lg font-bold text-white">
                {champion.name} (ELO Semilla: {champion.seedRating})
              </div>
            </div>
          </div>
          <span className="text-xs font-mono text-amber-300">
            Trofeo Adjudicado
          </span>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Matches / Bracket Column (7 cols) */}
        <div className="lg:col-span-7 p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
          <h3 className="text-lg font-bold text-white font-display">
            01. Calendario de Encuentros y Cruces
          </h3>

          <div className="flex flex-col gap-3">
            {tournament.matches.map((m) => {
              const p1 = participantMap.get(m.player1Id);
              const p2 = participantMap.get(m.player2Id);
              const isCurrentBoardMatch = activeMatchId === m.id;
              return (
                <div
                  key={m.id}
                  className={`p-4 rounded-xl border flex flex-col sm:flex-row sm:items-center justify-between gap-3 ${
                    isCurrentBoardMatch
                      ? "bg-slate-950 border-emerald-500"
                      : "bg-slate-950/80 border-slate-800"
                  }`}
                >
                  <div className="flex flex-col gap-1">
                    <div className="text-[11px] text-slate-400 font-mono">
                      Ronda {m.round} · {m.id.toUpperCase()}
                      {m.status === "completed" ? " · Finalizado" : " · Pendiente"}
                    </div>
                    <div className="text-sm font-semibold text-white flex items-center gap-2">
                      <span
                        className={
                          m.winnerId === m.player1Id ? "text-emerald-400" : ""
                        }
                      >
                        {p1?.name || m.player1Id}
                      </span>
                      <span className="text-xs text-slate-500">vs</span>
                      <span
                        className={
                          m.winnerId === m.player2Id ? "text-emerald-400" : ""
                        }
                      >
                        {p2?.name || m.player2Id}
                      </span>
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-2 shrink-0">
                    {m.status === "pending" ? (
                      <>
                        <button
                          type="button"
                          onClick={() =>
                            onLaunchMatchOnBoard(m, tournament.gameId)
                          }
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors cursor-pointer"
                        >
                          <Play className="w-3.5 h-3.5" />
                          <span>Jugar en Tablero</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => handleResolveMatch(m, m.player1Id)}
                          className="px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium cursor-pointer"
                        >
                          Gana J1
                        </button>
                        <button
                          type="button"
                          onClick={() => handleResolveMatch(m, m.player2Id)}
                          className="px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium cursor-pointer"
                        >
                          Gana J2
                        </button>
                      </>
                    ) : (
                      <span className="text-xs font-mono text-emerald-400">
                        Ganador:{" "}
                        {m.winnerId === "draw"
                          ? "Empate"
                          : participantMap.get(m.winnerId || "")?.name ||
                            m.winnerId}
                      </span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Standings Table Column (5 cols) */}
        <div className="lg:col-span-5 p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
          <h3 className="text-lg font-bold text-white font-display">
            02. Tabla de Posiciones en Vivo
          </h3>
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-800 text-slate-400">
                  <th className="py-2 pr-3 font-medium">#</th>
                  <th className="py-2 pr-3 font-medium">Participante</th>
                  <th className="py-2 px-2 font-medium text-right">PJ</th>
                  <th className="py-2 px-2 font-medium text-right">PG</th>
                  <th className="py-2 px-2 font-medium text-right">PE</th>
                  <th className="py-2 px-2 font-medium text-right">PP</th>
                  <th className="py-2 pl-2 font-medium text-right">Pts</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/70 font-mono tabular-nums">
                {standings.map((row, idx) => (
                  <tr key={row.participant.id}>
                    <td className="py-2.5 pr-3 text-slate-400">{idx + 1}</td>
                    <td className="py-2.5 pr-3 font-sans font-medium text-white">
                      {row.participant.name}
                    </td>
                    <td className="py-2.5 px-2 text-right text-slate-300">
                      {row.played}
                    </td>
                    <td className="py-2.5 px-2 text-right text-emerald-400">
                      {row.wins}
                    </td>
                    <td className="py-2.5 px-2 text-right text-slate-400">
                      {row.draws}
                    </td>
                    <td className="py-2.5 px-2 text-right text-slate-400">
                      {row.losses}
                    </td>
                    <td className="py-2.5 pl-2 text-right font-bold text-amber-400">
                      {row.points}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </section>
  );
};
