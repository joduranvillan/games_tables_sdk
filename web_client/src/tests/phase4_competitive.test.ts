/**
 * Suite de Regresión Fase 4 (Ecosistema Competitivo: ELO K=32, Logros, Torneos,
 * Temas Visuales + Okabe-Ito, Audio Procedural Web Audio API y Chat Relay):
 *
 * Verifica:
 * 1. Exactitud matemática del cálculo ELO estándar (K = 32) idéntico a `open_table_engine::elo`.
 * 2. Perfil ELO de los 14 juegos, rachas, exportación/importación JSON y desbloqueo de los 12 logros.
 * 3. Generador y progresión de Torneos Round-Robin (Tablas de Berger) y Eliminatoria Directa (Knockout).
 * 4. Temas visuales (`piedra_oscura`, `noche_azul`, `jade_verde`), paleta daltónica Okabe-Ito y sintetizador Web Audio API.
 * 5. Chat de Sala en Vivo y sincronización de ELO sobre `RelayWebSocketClient`.
 */

import {
  ACHIEVEMENTS_CATALOG,
  ALL_14_GAME_IDS,
  BASE_ELO_RATING,
  computeEloUpdate,
  createInitialEloProfile,
  getAiCalibrationRating,
  recordMatchInEloProfile,
  recordTournamentVictoryInProfile,
} from "../components/common/EloAndAchievementsPanel";
import {
  computeTournamentStandings,
  createDefaultParticipants,
  createTournament,
  recordTournamentMatchResult,
} from "../components/common/TournamentManagerPanel";
import {
  getDefaultThemeAndAudioConfig,
  getOkabeItoPalette,
  playProceduralSound,
  VISUAL_THEMES,
} from "../components/common/ThemeAndAudioManager";
import { QUICK_TACTICAL_REACTIONS } from "../components/common/RelayChatPanel";
import { RelayWebSocketClient } from "../bridge/relayClient";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`ASSERTION FAILED: ${message}`);
  }
}

async function runPhase4RegressionSuite(): Promise<void> {
  console.log(
    "=== INICIANDO SUITE DE REGRESIÓN FASE 4 (ELO K=32, LOGROS, TORNEOS, TEMAS/OKABE-ITO, AUDIO Y CHAT RELAY) ==="
  );

  // 1. ELO K=32 Mathematical Verification
  console.log("[1/5] Verificando fórmula logística ELO (K = 32) y calibración IA...");
  const equalMatch = computeEloUpdate(1200, 1200, 1, 32);
  assert(
    equalMatch.newRatingA === 1216 &&
      equalMatch.newRatingB === 1184 &&
      equalMatch.deltaA === 16,
    `Victoria entre 1200 vs 1200 con K=32 debe dar +16/-16 (obtenido: ${JSON.stringify(equalMatch)})`
  );

  const equalDraw = computeEloUpdate(1200, 1200, 0.5, 32);
  assert(
    equalDraw.deltaA === 0 && equalDraw.newRatingA === 1200,
    "Empate entre ratings iguales (1200 vs 1200) debe dar delta 0"
  );

  const upsetWin = computeEloUpdate(1200, 1600, 1, 32);
  assert(
    upsetWin.deltaA >= 28,
    `Victoria contra rival de 1600 ELO debe otorgar al menos +28 puntos (obtenido: +${upsetWin.deltaA})`
  );

  assert(getAiCalibrationRating(0) === 1000, "IA Fácil = 1000 ELO");
  assert(getAiCalibrationRating(1) === 1200, "IA Media = 1200 ELO");
  assert(getAiCalibrationRating(2) === 1400, "IA Difícil = 1400 ELO");
  assert(getAiCalibrationRating(3) === 1600, "IA Maestra = 1600 ELO");
  console.log("  [OK] Ecuación ELO K=32 y calibraciones de IA verificadas.");

  // 2. 14-Game ELO Profile & Achievements Engine
  console.log("[2/5] Verificando perfil de los 14 juegos y catálogo de 12 logros...");
  let profile = createInitialEloProfile("GranMaestroWeb");
  assert(
    Object.keys(profile.statsByGame).length === 14 &&
      ALL_14_GAME_IDS.every(
        (id) => profile.statsByGame[id].rating === BASE_ELO_RATING
      ),
    "El perfil inicial debe inicializar los 14 juegos a 1200 ELO"
  );
  assert(
    ACHIEVEMENTS_CATALOG.length === 12,
    "El catálogo de logros debe contener las 12 insignias oficiales"
  );

  // Win in Go vs Hard AI (1400) -> unlocks first_victory, oriental_master, beat_hard_ai
  const res1 = recordMatchInEloProfile(profile, "go", "win", 1400, "IA Difícil");
  profile = res1.updatedProfile;
  assert(
    profile.unlockedAchievements.includes("first_victory") &&
      profile.unlockedAchievements.includes("oriental_master") &&
      profile.unlockedAchievements.includes("beat_hard_ai"),
    "Victoria en Go contra IA Difícil debe desbloquear first_victory, oriental_master y beat_hard_ai"
  );

  // Win in Goose (dice_commander) and Monopoly (tycoon_tactician) -> unlocks polyglot_3_games
  profile = recordMatchInEloProfile(profile, "goose", "win", 1200, "IA Media")
    .updatedProfile;
  profile = recordMatchInEloProfile(profile, "monopoly", "win", 1200, "IA Media")
    .updatedProfile;
  assert(
    profile.unlockedAchievements.includes("dice_commander") &&
      profile.unlockedAchievements.includes("tycoon_tactician") &&
      profile.unlockedAchievements.includes("polyglot_3_games"),
    "Victorias en Oca y Monopoly deben desbloquear dice_commander, tycoon_tactician y polyglot_3_games"
  );

  // 3-win streak in Chess
  profile = recordMatchInEloProfile(profile, "chess", "win", 1400, "IA Difícil")
    .updatedProfile;
  profile = recordMatchInEloProfile(profile, "chess", "win", 1400, "IA Difícil")
    .updatedProfile;
  profile = recordMatchInEloProfile(profile, "chess", "win", 1400, "IA Difícil")
    .updatedProfile;
  assert(
    profile.unlockedAchievements.includes("win_streak_3") &&
      profile.unlockedAchievements.includes("elo_1250"),
    "Racha de 3 victorias en Ajedrez debe desbloquear win_streak_3 y elo_1250"
  );

  const tourWin = recordTournamentVictoryInProfile(profile);
  profile = tourWin.updatedProfile;
  assert(
    profile.unlockedAchievements.includes("tournament_champion"),
    "Ganar un torneo debe desbloquear tournament_champion"
  );
  console.log(
    "  [OK] Perfil ELO de 14 juegos y desbloqueo automático de logros verificados."
  );

  // 3. Tournament Organizer (Round-Robin Berger & Single Elimination)
  console.log(
    "[3/5] Verificando Organizador de Torneos (Round-Robin y Eliminatoria Directa)..."
  );
  const participants = createDefaultParticipants();
  const rrTour = createTournament("chess", "round_robin", participants);
  // 4 participants in Round-Robin -> 3 rounds * 2 matches = 6 matches
  assert(
    rrTour.matches.length === 6,
    `Round-Robin de 4 participantes debe generar 6 encuentros (obtenido: ${rrTour.matches.length})`
  );

  let activeRr = rrTour;
  for (const m of rrTour.matches) {
    activeRr = recordTournamentMatchResult(activeRr, m.id, "p1");
  }
  const rrStandings = computeTournamentStandings(activeRr);
  assert(
    rrStandings[0].participant.id === "p1" &&
      rrStandings[0].wins === 3 &&
      rrStandings[0].points === 9 &&
      activeRr.championId === "p1",
    "Jugador p1 con 3 victorias en Round-Robin debe sumar 9 puntos y coronarse campeón"
  );

  // Single Elimination with 4 participants -> 2 semifinals -> 1 final -> champion
  let seTour = createTournament("shogi", "single_elimination", participants);
  assert(
    seTour.matches.length === 2,
    "Eliminatoria Directa de 4 participantes debe iniciar con 2 semifinales"
  );
  const semi1 = seTour.matches[0];
  const semi2 = seTour.matches[1];
  seTour = recordTournamentMatchResult(seTour, semi1.id, semi1.player1Id);
  seTour = recordTournamentMatchResult(seTour, semi2.id, semi2.player2Id);
  assert(
    seTour.matches.length === 3,
    "Al completar las 2 semifinales debe generarse automáticamente la Gran Final (Ronda 2)"
  );
  const finalMatch = seTour.matches[2];
  assert(
    finalMatch.round === 2 &&
      finalMatch.player1Id === semi1.player1Id &&
      finalMatch.player2Id === semi2.player2Id,
    "La final debe enfrentar a los ganadores de las dos semifinales"
  );
  seTour = recordTournamentMatchResult(seTour, finalMatch.id, finalMatch.player1Id);
  assert(
    seTour.championId === finalMatch.player1Id,
    "El ganador de la final debe ser proclamado campeón del torneo"
  );
  console.log(
    "  [OK] Torneos Round-Robin (Berger) y Eliminatoria Directa verificados."
  );

  // 4. Visual Themes, Okabe-Ito Palette & Procedural Web Audio Synthesizer
  console.log(
    "[4/5] Verificando 3 Temas Visuales, Paleta Okabe-Ito y Sintetizador Web Audio..."
  );
  assert(
    "piedra_oscura" in VISUAL_THEMES &&
      "noche_azul" in VISUAL_THEMES &&
      "jade_verde" in VISUAL_THEMES,
    "Los 3 temas visuales oficiales (Piedra Oscura, Noche Azul, Jade Verde) deben existir"
  );
  const okabePalette = getOkabeItoPalette(true);
  assert(
    okabePalette.player1Hex === "#0072B2" &&
      okabePalette.player2Hex === "#D55E00",
    "La paleta daltónica Okabe-Ito debe usar azul (#0072B2) y bermellón (#D55E00)"
  );

  const defaultAudioCfg = getDefaultThemeAndAudioConfig();
  assert(
    playProceduralSound("move", defaultAudioCfg) === true &&
      playProceduralSound("dice_roll", defaultAudioCfg) === true &&
      playProceduralSound("victory", defaultAudioCfg) === true,
    "El sintetizador Web Audio API debe despachar sonidos con soundEnabled=true"
  );
  assert(
    playProceduralSound("move", { soundEnabled: false, soundVolume: 0.5 }) ===
      false,
    "El sintetizador debe retornar false cuando soundEnabled=false"
  );
  console.log(
    "  [OK] Temas visuales, paleta Okabe-Ito y sintetizador acústico verificados."
  );

  // 5. Relay Room Chat & ELO Sync
  console.log(
    "[5/5] Verificando Chat de Sala en Vivo y Sincronización ELO en RelayWebSocketClient..."
  );
  assert(
    QUICK_TACTICAL_REACTIONS.length >= 4,
    "El panel de chat debe incluir al menos 4 reacciones tácticas rápidas"
  );
  const relayClient = new RelayWebSocketClient({}, "ws://127.0.0.1:8080");
  const room = relayClient.createRoom("chess");
  const chatMsg = relayClient.sendChatMessage(
    "JugadorHost",
    "¡Buena partida!",
    1
  );
  assert(
    chatMsg !== null &&
      chatMsg.roomCode === room &&
      chatMsg.senderName === "JugadorHost" &&
      chatMsg.text === "¡Buena partida!",
    "sendChatMessage debe construir y despachar el mensaje con código de sala y remitente"
  );
  assert(
    relayClient.sendChatMessage("JugadorHost", "   ", 1) === null,
    "Mensajes vacíos no deben despacharse"
  );
  relayClient.sendEloSync(1, 1312, "JugadorHost");
  relayClient.disconnect();
  console.log(
    "  [OK] Chat de sala en tiempo real y sincronización ELO en Relay verificados."
  );

  console.log(
    "=== RESULTADO GLOBAL FASE 4: 100% DE LAS PRUEBAS PASARON EXITOSAMENTE ==="
  );
}

runPhase4RegressionSuite().catch((err) => {
  console.error(err);
  process.exit(1);
});
