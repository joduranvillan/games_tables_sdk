import React, { useEffect, useRef, useState } from "react";
import { WasmGameBridge } from "./wasm_pkg";
import {
  getSavedRelayUrl,
  MatchmakingQueueTicket,
  RelayChatMessage,
  RelayConnectionState,
  RelayWebSocketClient,
  saveRelayUrl,
} from "./bridge/relayClient";
import { ChessBoard } from "./components/boards/ChessBoard";
import { CheckersBoard } from "./components/boards/CheckersBoard";
import { UnoBoard } from "./components/boards/UnoBoard";
import { GooseBoard } from "./components/boards/GooseBoard";
import { GoBoard } from "./components/boards/GoBoard";
import { ShogiBoard } from "./components/boards/ShogiBoard";
import { XiangqiBoard } from "./components/boards/XiangqiBoard";
import { ChineseCheckersBoard } from "./components/boards/ChineseCheckersBoard";
import { BackgammonBoard } from "./components/boards/BackgammonBoard";
import { LudoBoard } from "./components/boards/LudoBoard";
import { BattleshipBoard } from "./components/boards/BattleshipBoard";
import { MilleBornesBoard } from "./components/boards/MilleBornesBoard";
import { MonopolyBoard } from "./components/boards/MonopolyBoard";
import { CrisisBoard } from "./components/boards/CrisisBoard";
import {
  applyClockMoveComplete,
  ClockPresetId,
  createInitialClockState,
  stepClockTick,
  TournamentClock,
  TournamentClockState,
} from "./components/common/TournamentClock";
import { ReplayViewerBar } from "./components/common/ReplayViewerBar";
import { InteractiveTutorialPanel } from "./components/common/InteractiveTutorialPanel";
import {
  OfflineIndicator,
  PWAInstallButton,
} from "./components/common/PWAInstallButton";
import {
  loadThemeAndAudioConfig,
  playProceduralSound,
  ThemeAndAudioConfig,
  ThemeAndAudioToolbar,
  VISUAL_THEMES,
} from "./components/common/ThemeAndAudioManager";
import {
  ACHIEVEMENTS_CATALOG,
  EloAndAchievementsPanel,
  getAiCalibrationRating,
  loadEloProfile,
  PlayerEloProfile,
  recordMatchInEloProfile,
  recordTournamentVictoryInProfile,
} from "./components/common/EloAndAchievementsPanel";
import {
  loadTournamentState,
  recordTournamentMatchResult,
  TournamentManagerPanel,
  TournamentMatchItem,
  TournamentState,
} from "./components/common/TournamentManagerPanel";
import { RelayChatPanel } from "./components/common/RelayChatPanel";
import { MatchmakingQueuePanel } from "./components/common/MatchmakingQueuePanel";
import { PostMatchAnalyzerPanel } from "./components/common/PostMatchAnalyzerPanel";
import { SystemDiagnosticsPanel } from "./components/common/SystemDiagnosticsPanel";
import { DocumentationCenterModal } from "./components/common/DocumentationCenterModal";
import {
  CategorizedGameListContent,
  CategoryFilterId,
  filterAndGroupCatalogGames,
  GAME_CATEGORY_GROUPS,
  MobileBottomNav,
  MobileGameListDrawer,
} from "./components/common/GameListNavigation";
import {
  Activity,
  BarChart3,
  BookOpen,
  Bot,
  ChevronDown,
  Clock,
  Eye,
  Globe,
  History,
  Layers,
  Menu,
  Palette,
  QrCode,
  RefreshCw,
  RotateCcw,
  Search,
  Settings,
  Trophy,
  Users,
  Wifi,
  X,
} from "lucide-react";
import {
  applyDomSubtreeLocalization,
  getLocalizedCatalogGames,
  getLocalizedCategoryGroups,
  I18nProvider,
  SupportedLocale,
  useI18n,
} from "./i18n";

interface GameCatalogItem {
  id: string;
  title: string;
  crateName: string;
  category: string;
  phase: 1 | 2;
  blockLabel: string;
  summary: string;
}

export const CATALOG_14_GAMES: GameCatalogItem[] = [
  {
    id: "chess",
    title: "Ajedrez",
    crateName: "chess_game",
    category: "Estrategia Clásica",
    phase: 1,
    blockLabel: "Fase 1 · Activo en Web + WASM",
    summary: "Enroque, captura al paso, coronación FIDE, detección de jaque y oferta de tablas.",
  },
  {
    id: "checkers",
    title: "Damas",
    crateName: "checkers_game",
    category: "Estrategia Clásica",
    phase: 1,
    blockLabel: "Fase 1 · Activo en Web + WASM",
    summary: "Captura obligatoria, saltos múltiples encadenados y coronación de Dama.",
  },
  {
    id: "uno",
    title: "UNO",
    crateName: "uno_game",
    category: "Cartas y Reacción",
    phase: 1,
    blockLabel: "Fase 1 · Activo en Web + WASM",
    summary: "Mazo de 108 cartas, comodines multicolor, grito ¡UNO! y penalidades acumulables.",
  },
  {
    id: "goose",
    title: "El Juego de la Oca",
    crateName: "goose_game",
    category: "Dados 3D y Recorrido",
    phase: 1,
    blockLabel: "Fase 1 · Activo en Web + WASM",
    summary: "Espiral de 63 casillas, 13 Ocas, Puentes, Posada, Pozo, Laberinto, Calavera y Dados 3D.",
  },
  {
    id: "go",
    title: "Go (Weiqi / Baduk)",
    crateName: "go_game",
    category: "Estrategia Oriental",
    phase: 1,
    blockLabel: "Fase 2A · Activo en Web + WASM",
    summary: "Tableros 9×9 / 13×13 / 19×19, Ko, Superko posicional, Handicap y Komi 6.5.",
  },
  {
    id: "shogi",
    title: "Shogi",
    crateName: "shogi_game",
    category: "Estrategia Oriental",
    phase: 1,
    blockLabel: "Fase 2A · Activo en Web + WASM",
    summary: "Reingreso de piezas capturadas (Komadai), Nifu, Uchifuzume y promoción FESA.",
  },
  {
    id: "xiangqi",
    title: "Xiangqi",
    crateName: "xiangqi_game",
    category: "Estrategia Oriental",
    phase: 1,
    blockLabel: "Fase 2A · Activo en Web + WASM",
    summary: "Tablero 9×10 con Río, Palacios diagonales, Cañones con pantalla y General Volador.",
  },
  {
    id: "chinese_checkers",
    title: "Damas Chinas",
    crateName: "chinese_checkers_game",
    category: "Estrategia Oriental",
    phase: 1,
    blockLabel: "Fase 2A · Activo en Web + WASM",
    summary: "Estrella hexagonal de 121 casillas para 2 a 6 jugadores con saltos en cadena.",
  },
  {
    id: "backgammon",
    title: "Backgammon",
    crateName: "backgammon_game",
    category: "Dados y Táctica",
    phase: 1,
    blockLabel: "Fase 2B · Activo en Web + WASM",
    summary: "24 picos, barra central, Bear-Off, tiradas dobles y cubo de doblaje (Doubling Cube).",
  },
  {
    id: "ludo",
    title: "Ludo",
    crateName: "ludo_game",
    category: "Dados y Carrera",
    phase: 1,
    blockLabel: "Fase 2B · Activo en Web + WASM",
    summary: "Circuito de 52 casillas + 5 de meta, 8 casillas seguras estrella y tirada extra.",
  },
  {
    id: "battleship",
    title: "Batalla Naval",
    crateName: "battleship_game",
    category: "Combate Táctico",
    phase: 1,
    blockLabel: "Fase 2B · Activo en Web + WASM",
    summary: "Doble cuadrícula 10×10, flota de 5 buques, ráfaga al impactar y revancha.",
  },
  {
    id: "mille_bornes",
    title: "Mil Millas",
    crateName: "mille_bornes_game",
    category: "Cartas y Carrera",
    phase: 1,
    blockLabel: "Fase 2C · Activo en Web + WASM",
    summary: "Ruta de 1000 km, 4 cartas de seguridad (Safeties) y reacción ¡Coup Fourré!.",
  },
  {
    id: "monopoly",
    title: "Monopoly",
    crateName: "monopoly_game",
    category: "Economía y Subastas",
    phase: 1,
    blockLabel: "Fase 2C · Activo en Web + WASM",
    summary: "40 casillas, Suerte/Arca, Subastas, Casas/Hoteles uniformes, Hipotecas y Trueques.",
  },
  {
    id: "crisis",
    title: "Crisis / TEG",
    crateName: "crisis_game",
    category: "Conquista Global",
    phase: 1,
    blockLabel: "Fase 2C · Activo en Web + WASM",
    summary: "30 territorios en 6 continentes, objetivos secretos, tarjetas y dados 3v3.",
  },
];

export const GAME_TITLES_MAP: Record<string, string> = Object.fromEntries(
  CATALOG_14_GAMES.map((g) => [g.id, g.title])
);

export type MatchMode = "hotseat" | "ai" | "online_relay" | "spectator";

export function computeIsLocalTurnAllowed(
  mode: MatchMode,
  currentTurn: number,
  localPlayerId: 1 | 2,
  isReplayAtLiveHead: boolean = true
): boolean {
  if (!isReplayAtLiveHead) return false;
  if (mode === "spectator") return false;
  if (mode === "hotseat") return true;
  if (mode === "ai") return currentTurn === 1;
  return currentTurn === localPlayerId;
}

const AppShell: React.FC = () => {
  const { locale, setLocale, t, locales } = useI18n();
  const rootDomRef = useRef<HTMLDivElement | null>(null);
  const bridgeRef = useRef<WasmGameBridge>(new WasmGameBridge());
  const relayRef = useRef<RelayWebSocketClient | null>(null);
  const matchOutcomeRecordedRef = useRef<boolean>(false);

  const [activeTab, setActiveTab] = useState<
    | "play"
    | "catalog"
    | "tournaments"
    | "elo"
    | "analyzer"
    | "network"
    | "diagnostics"
  >("play");
  const [isDocsModalOpen, setIsDocsModalOpen] = useState<boolean>(false);
  const [isGameDrawerOpen, setIsGameDrawerOpen] = useState<boolean>(false);
  const [gameSearchQuery, setGameSearchQuery] = useState<string>("");
  const [gameCategoryFilter, setGameCategoryFilter] =
    useState<CategoryFilterId>("all");
  const [isTopRightMenuOpen, setIsTopRightMenuOpen] = useState<boolean>(false);
  const [selectedGameId, setSelectedGameId] = useState<string>("chess");
  const [matchMode, setMatchMode] = useState<MatchMode>("hotseat");
  const [aiDifficulty, setAiDifficulty] = useState<number>(1);

  const [stateJson, setStateJson] = useState<string>(() =>
    bridgeRef.current.get_state_json()
  );
  const [legalMovesJson, setLegalMovesJson] = useState<string>(() =>
    bridgeRef.current.get_legal_moves_json(1)
  );
  const [currentTurn, setCurrentTurn] = useState<number>(1);
  const [localNetworkPlayerId, setLocalNetworkPlayerId] = useState<1 | 2>(1);

  // Replay timeline state
  const [replayCurrentStep, setReplayCurrentStep] = useState<number>(0);
  const [replayTotalSteps, setReplayTotalSteps] = useState<number>(0);

  // Tournament Clock state
  const [clockState, setClockState] = useState<TournamentClockState>(() =>
    createInitialClockState("none")
  );

  // Phase 4: Theme & Audio state
  const [themeConfig, setThemeConfig] = useState<ThemeAndAudioConfig>(() =>
    loadThemeAndAudioConfig()
  );

  // Phase 4: ELO Profile & Achievements state
  const [eloProfile, setEloProfile] = useState<PlayerEloProfile>(() =>
    loadEloProfile()
  );
  const [recentAchievementBanner, setRecentAchievementBanner] = useState<
    string | null
  >(null);
  const [peerEloInfo, setPeerEloInfo] = useState<{
    playerName: string;
    rating: number;
  } | null>(null);

  // Phase 4: Tournament Organizer state
  const [tournamentState, setTournamentState] = useState<TournamentState>(() =>
    loadTournamentState("chess")
  );
  const [activeTournamentMatchId, setActiveTournamentMatchId] = useState<
    string | null
  >(null);

  // Relay & QR + Chat state
  const [relayUrl, setRelayUrl] = useState<string>(() => getSavedRelayUrl());
  const [relayState, setRelayState] =
    useState<RelayConnectionState>("disconnected");
  const [relayStatusText, setRelayStatusText] = useState<string>(
    "Sin sala activa (Modo Local)"
  );
  const [roomCode, setRoomCode] = useState<string>("");
  const [joinCodeInput, setJoinCodeInput] = useState<string>("");
  const [qrSvg, setQrSvg] = useState<string>("");
  const [chatMessages, setChatMessages] = useState<RelayChatMessage[]>([]);
  const [isQueuingMatchmaking, setIsQueuingMatchmaking] =
    useState<boolean>(false);
  const [activeQueueTicket, setActiveQueueTicket] =
    useState<MatchmakingQueueTicket | null>(null);

  const checkAndRecordWinnerIfAny = (
    nextStateStr: string,
    gameId: string,
    mode: MatchMode,
    diff: number
  ) => {
    try {
      const parsed = JSON.parse(nextStateStr);
      const winner = parsed.winner ?? null;
      if (winner !== null && !matchOutcomeRecordedRef.current) {
        matchOutcomeRecordedRef.current = true;
        playProceduralSound("victory", themeConfig);

        const outcome: "win" | "loss" | "draw" =
          winner === 0
            ? "draw"
            : winner === localNetworkPlayerId
            ? "win"
            : "loss";
        const oppRating =
          mode === "ai"
            ? getAiCalibrationRating(diff)
            : peerEloInfo?.rating || 1200;
        const oppLabel =
          mode === "ai"
            ? `IA Nivel ${diff + 1}`
            : peerEloInfo?.playerName || "Oponente Local/Red";

        setEloProfile((prev) => {
          const { updatedProfile, newlyUnlocked } = recordMatchInEloProfile(
            prev,
            gameId,
            outcome,
            oppRating,
            oppLabel
          );
          if (newlyUnlocked.length > 0) {
            const firstTitle =
              ACHIEVEMENTS_CATALOG.find((a) => a.id === newlyUnlocked[0])
                ?.title || newlyUnlocked[0];
            setRecentAchievementBanner(`¡Logro desbloqueado: ${firstTitle}!`);
          }
          return updatedProfile;
        });

        if (activeTournamentMatchId) {
          setTournamentState((prevTour) => {
            const m = prevTour.matches.find(
              (item) => item.id === activeTournamentMatchId
            );
            if (!m) return prevTour;
            const winParticipantId =
              winner === 1
                ? m.player1Id
                : winner === 2
                ? m.player2Id
                : "draw";
            return recordTournamentMatchResult(
              prevTour,
              m.id,
              winParticipantId
            );
          });
        }
      }
    } catch {
      // Ignore parse error
    }
  };

  const syncFromBridge = () => {
    const turn = bridgeRef.current.current_player();
    const nextStateStr = bridgeRef.current.get_state_json();
    setCurrentTurn(turn);
    setStateJson(nextStateStr);
    setLegalMovesJson(bridgeRef.current.get_legal_moves_json(turn));
    setReplayCurrentStep(bridgeRef.current.get_current_replay_step());
    setReplayTotalSteps(bridgeRef.current.get_replay_step_count());
    checkAndRecordWinnerIfAny(
      nextStateStr,
      bridgeRef.current.get_current_game_type(),
      matchMode,
      aiDifficulty
    );
  };

  useEffect(() => {
    const client = new RelayWebSocketClient(
      {
        onStateChange: (st, info) => {
          setRelayState(st);
          if (info) setRelayStatusText(info);
        },
        onRoomCreated: (code, pid) => {
          setRoomCode(code);
          setLocalNetworkPlayerId(pid);
          setQrSvg(
            bridgeRef.current.generate_join_qr_svg(
              code,
              "WebHost",
              selectedGameId
            )
          );
        },
        onRoomJoined: (code, pid) => {
          setRoomCode(code);
          setLocalNetworkPlayerId(pid);
        },
        onSpectatorJoined: (code) => {
          setRoomCode(code);
          setMatchMode("spectator");
        },
        onPeerJoined: () => {
          const logJson = bridgeRef.current.export_log_json();
          client.sendSyncState(
            bridgeRef.current.get_current_game_type(),
            logJson
          );
        },
        onCommandReceived: (playerId, cmdJson) => {
          bridgeRef.current.send_command_json(playerId, cmdJson);
          syncFromBridge();
        },
        onSyncStateReceived: (gtype, logJson) => {
          if (bridgeRef.current.apply_sync_log_json(gtype, logJson)) {
            setSelectedGameId(bridgeRef.current.get_current_game_type());
            syncFromBridge();
          }
        },
        onChatMessageReceived: (msg) => {
          setChatMessages((prev) => [...prev, msg]);
        },
        onEloSyncReceived: (_pid, rating, playerName) => {
          setPeerEloInfo({ playerName, rating });
        },
        onMatchmakingFound: (code, assignedPid, oppElo, oppName) => {
          setIsQueuingMatchmaking(false);
          setActiveQueueTicket(null);
          setRoomCode(code);
          setLocalNetworkPlayerId(assignedPid);
          setPeerEloInfo({ playerName: oppName, rating: oppElo });
          setMatchMode("online_relay");
          playProceduralSound("victory", themeConfig);
          setActiveTab("play");
        },
      },
      relayUrl
    );
    relayRef.current = client;
    return () => {
      client.disconnect();
    };
  }, []);

  const startGameSession = (
    gameId: string,
    mode: MatchMode,
    diff: number = aiDifficulty
  ) => {
    matchOutcomeRecordedRef.current = false;
    setSelectedGameId(gameId);
    setMatchMode(mode);
    setClockState((prev) => createInitialClockState(prev.preset));
    if (mode === "ai") {
      bridgeRef.current.start_ai_match(gameId, 1, 2, diff);
      setLocalNetworkPlayerId(1);
    } else {
      bridgeRef.current.start_local_match(gameId, 1, 2);
      if (mode === "hotseat") {
        setLocalNetworkPlayerId(1);
      }
    }
    syncFromBridge();
  };

  const handleDispatchCommand = (cmdJson: string) => {
    const turnBefore = bridgeRef.current.current_player() as 1 | 2;
    bridgeRef.current.send_command_json(turnBefore, cmdJson);
    const turnAfter = bridgeRef.current.current_player() as 1 | 2;

    if (cmdJson.toLowerCase().includes("roll")) {
      playProceduralSound("dice_roll", themeConfig);
    } else if (
      selectedGameId === "uno" ||
      selectedGameId === "mille_bornes"
    ) {
      playProceduralSound("card_play", themeConfig);
    } else {
      playProceduralSound("move", themeConfig);
    }

    if (turnAfter !== turnBefore) {
      setClockState((prev) => applyClockMoveComplete(prev, turnBefore));
    }
    syncFromBridge();

    if (matchMode === "online_relay" && relayRef.current) {
      relayRef.current.sendCommand(turnBefore, cmdJson);
      if (localNetworkPlayerId === 1) {
        relayRef.current.sendSyncState(
          selectedGameId,
          bridgeRef.current.export_log_json()
        );
      }
    } else if (matchMode === "ai") {
      setTimeout(() => {
        const aiTurnBefore = bridgeRef.current.current_player() as 1 | 2;
        bridgeRef.current.step_ai_if_needed();
        const aiTurnAfter = bridgeRef.current.current_player() as 1 | 2;
        if (aiTurnAfter !== aiTurnBefore) {
          setClockState((prev) => applyClockMoveComplete(prev, aiTurnBefore));
        }
        syncFromBridge();
      }, 260);
    }
  };

  const handleClockTick = (deltaMs: number) => {
    setClockState((prev) => {
      const next = stepClockTick(
        prev,
        (currentTurn === 2 ? 2 : 1) as 1 | 2,
        deltaMs
      );
      if (next.flaggedWinner !== null && prev.flaggedWinner === null) {
        playProceduralSound("clock_alert", themeConfig);
        bridgeRef.current.force_timeout_win(next.flaggedWinner);
        syncFromBridge();
      }
      return next;
    });
  };

  const handleSeekReplayStep = (step: number) => {
    bridgeRef.current.seek_replay_step(step);
    syncFromBridge();
  };

  const handleImportReplayJson = (jsonStr: string): boolean => {
    const ok = bridgeRef.current.apply_sync_log_json("", jsonStr);
    if (ok) {
      setSelectedGameId(bridgeRef.current.get_current_game_type());
      syncFromBridge();
    }
    return ok;
  };

  const handleSendChatMessage = (text: string) => {
    const sent = relayRef.current?.sendChatMessage(
      eloProfile.playerName,
      text,
      localNetworkPlayerId
    );
    if (sent) {
      setChatMessages((prev) => [...prev, sent]);
    }
  };

  const handleLaunchTournamentMatch = (
    match: TournamentMatchItem,
    gameId: string
  ) => {
    setActiveTournamentMatchId(match.id);
    const p2 = tournamentState.participants.find(
      (p) => p.id === match.player2Id
    );
    const mode: MatchMode = p2?.kind === "ai" ? "ai" : "hotseat";
    const diff = p2?.aiDifficulty ?? 1;
    setAiDifficulty(diff);
    startGameSession(gameId, mode, diff);
    setActiveTab("play");
  };

  const handleCreateRelayRoom = () => {
    if (!relayRef.current) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "online_relay");
    const code = relayRef.current.createRoom(selectedGameId);
    setRoomCode(code);
    setLocalNetworkPlayerId(1);
    setQrSvg(
      bridgeRef.current.generate_join_qr_svg(code, "WebHost", selectedGameId)
    );
    setActiveTab("play");
  };

  const handleJoinRelayRoom = () => {
    if (!relayRef.current || joinCodeInput.trim().length < 4) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "online_relay");
    const ok = relayRef.current.joinRoom(joinCodeInput);
    if (ok) {
      setLocalNetworkPlayerId(2);
      setActiveTab("play");
    }
  };

  const handleJoinAsSpectator = () => {
    if (!relayRef.current || joinCodeInput.trim().length < 4) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "spectator");
    const ok = relayRef.current.joinAsSpectator(joinCodeInput);
    if (ok) {
      setActiveTab("play");
    }
  };

  const handleStartMatchmakingQueue = (maxEloDelta: number) => {
    if (!relayRef.current) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "online_relay");
    const currentGameElo =
      eloProfile.statsByGame[selectedGameId]?.rating ?? eloProfile.globalRating;
    const ticket = relayRef.current.queueMatchmaking(
      selectedGameId,
      currentGameElo,
      maxEloDelta,
      eloProfile.playerName
    );
    setActiveQueueTicket(ticket);
    setIsQueuingMatchmaking(true);
    setRoomCode(ticket.roomCode);
    setQrSvg(
      bridgeRef.current.generate_join_qr_svg(
        ticket.roomCode,
        eloProfile.playerName,
        selectedGameId
      )
    );
  };

  const handleExpandMatchmakingTolerance = (newMaxDelta: number) => {
    relayRef.current?.expandMatchmakingTolerance(newMaxDelta);
    const updated = relayRef.current?.getActiveQueueTicket() ?? null;
    if (updated) {
      setActiveQueueTicket({ ...updated });
    }
  };

  const handleCancelMatchmakingQueue = () => {
    relayRef.current?.cancelMatchmaking();
    setIsQueuingMatchmaking(false);
    setActiveQueueTicket(null);
  };

  const handleSaveSettings = (e: React.FormEvent) => {
    e.preventDefault();
    const cleaned = saveRelayUrl(relayUrl);
    setRelayUrl(cleaned);
    relayRef.current?.setRelayUrl(cleaned);
    setRelayStatusText(`URL de Relay guardada: ${cleaned}`);
  };

  const isReplayAtLiveHead = replayCurrentStep >= replayTotalSteps;
  const isLocalTurnAllowed = computeIsLocalTurnAllowed(
    matchMode,
    currentTurn,
    localNetworkPlayerId,
    isReplayAtLiveHead
  );

  const parsedStateWinner = (() => {
    try {
      return JSON.parse(stateJson).winner ?? null;
    } catch {
      return null;
    }
  })();

  const localizedCatalog = getLocalizedCatalogGames(CATALOG_14_GAMES, locale);
  const localizedCategoryGroups = getLocalizedCategoryGroups(locale);
  const localizedGameTitlesMap: Record<string, string> = Object.fromEntries(
    localizedCatalog.map((g) => [g.id, g.title])
  );

  const activeGameMeta =
    localizedCatalog.find((g) => g.id === selectedGameId) ||
    localizedCatalog[0];

  const currentTheme =
    VISUAL_THEMES[themeConfig.themeId] || VISUAL_THEMES.piedra_oscura;

  useEffect(() => {
    const rootEl = rootDomRef.current;
    if (!rootEl) return;
    applyDomSubtreeLocalization(rootEl, locale);
    if (locale === "es" || typeof MutationObserver === "undefined") return;
    let applying = false;
    const observer = new MutationObserver(() => {
      if (applying) return;
      applying = true;
      applyDomSubtreeLocalization(rootEl, locale);
      applying = false;
    });
    observer.observe(rootEl, {
      childList: true,
      subtree: true,
    });
    return () => observer.disconnect();
  }, [locale, activeTab, selectedGameId, stateJson, isTopRightMenuOpen, isDocsModalOpen]);

  return (
    <div
      ref={rootDomRef}
      data-theme={themeConfig.themeId}
      data-locale={locale}
      data-okabe-ito={themeConfig.okabeIto ? "true" : "false"}
      className={`min-h-screen flex flex-col transition-colors ${currentTheme.rootBgClass}`}
    >
      <OfflineIndicator />

      {/* Strict 3-Zone Top Bar Contract */}
      <header
        className={`sticky top-0 z-30 flex items-center justify-between gap-3 sm:gap-6 px-4 sm:px-6 py-3 sm:py-4 border-b backdrop-blur-md ${currentTheme.headerBgClass}`}
      >
        <a
          href="#top"
          onClick={(e) => {
            e.preventDefault();
            setActiveTab("play");
          }}
          className="text-base sm:text-lg font-bold tracking-tight text-white font-display whitespace-nowrap shrink-0"
        >
          {t("app.brand")}
        </a>

        <nav className="hidden lg:flex items-center gap-5 text-sm font-medium text-slate-300">
          <button
            type="button"
            onClick={() => setActiveTab("play")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "play"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            {t("nav.active_board")}
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("catalog")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "catalog"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            {t("nav.catalog_14")}
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("network")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "network"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            {t("nav.online_rooms")}
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("tournaments")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "tournaments"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            {t("nav.tournaments")}
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("elo")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "elo"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            {t("nav.elo_ranking")}
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("analyzer")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "analyzer"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            {t("nav.analyzer")}
          </button>
        </nav>

        <div className="flex items-center gap-2 sm:gap-2.5 shrink-0">
          {/* Top Bar 9-Language Selector */}
          <div className="inline-flex items-center gap-1.5 px-2.5 py-1.5 min-h-[40px] rounded-lg bg-slate-900 border border-slate-700 text-xs text-slate-200">
            <Globe className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
            <select
              aria-label={t("nav.language_label")}
              value={locale}
              onChange={(e) => setLocale(e.target.value as SupportedLocale)}
              className="bg-transparent text-xs font-semibold text-white focus:outline-none cursor-pointer"
            >
              {locales.map((loc) => (
                <option
                  key={loc.code}
                  value={loc.code}
                  className="bg-slate-950 text-white"
                >
                  {loc.flag} {loc.shortLabel} · {loc.nativeName}
                </option>
              ))}
            </select>
          </div>

          <PWAInstallButton />
          <button
            type="button"
            onClick={() =>
              startGameSession(selectedGameId, matchMode, aiDifficulty)
            }
            className={`hidden sm:inline-flex items-center justify-center min-h-[40px] px-3.5 sm:px-4 py-2 text-xs font-semibold rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer ${currentTheme.accentBtnClass}`}
          >
            {t("nav.restart_match")}
          </button>
          <button
            type="button"
            onClick={() => setIsTopRightMenuOpen((prev) => !prev)}
            aria-label={t("menu.title")}
            aria-expanded={isTopRightMenuOpen}
            className={`min-h-[40px] inline-flex items-center gap-1.5 px-3 sm:px-3.5 py-2 text-xs font-semibold rounded-lg border transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              isTopRightMenuOpen
                ? "bg-amber-500 text-slate-950 border-amber-400"
                : "bg-slate-900 hover:bg-slate-800 text-white border-slate-700"
            }`}
          >
            <Menu className="w-4 h-4" />
            <span>{t("nav.menu")}</span>
          </button>
        </div>
      </header>

      {/* Unified Top-Right Menu Drawer (Language, Themes, Audio, Interactive Tutorial, Replay Viewer, Tournament Clock & Docs) */}
      {isTopRightMenuOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label={t("menu.title")}
          className="fixed inset-0 z-50 flex justify-end"
        >
          <div
            onClick={() => setIsTopRightMenuOpen(false)}
            className="fixed inset-0 bg-slate-950/75 backdrop-blur-sm"
          />
          <aside className="relative z-10 w-full max-w-md sm:max-w-lg bg-slate-950 border-l border-slate-800 h-full overflow-y-auto p-4 sm:p-5 flex flex-col gap-4 shadow-2xl">
            <div className="flex items-center justify-between gap-3 pb-3 border-b border-slate-800">
              <div>
                <div className="text-[11px] font-semibold uppercase tracking-wider text-emerald-400">
                  {t("menu.control_center")} · {activeGameMeta.title}
                </div>
                <h2 className="text-base sm:text-lg font-bold text-white font-display">
                  {t("menu.title")}
                </h2>
              </div>
              <button
                type="button"
                onClick={() => setIsTopRightMenuOpen(false)}
                aria-label={t("menu.close")}
                className="min-h-[38px] inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-700 text-slate-200 text-xs font-semibold cursor-pointer"
              >
                <X className="w-4 h-4" />
                <span>{t("menu.close")}</span>
              </button>
            </div>

            {/* 0. 9-Language Tactile Grid Switcher inside Top-Right Menu Drawer */}
            <div className="flex flex-col gap-2 p-3 rounded-2xl bg-slate-900/90 border border-slate-800">
              <div className="flex items-center gap-1.5 text-xs font-bold text-emerald-300">
                <Globe className="w-3.5 h-3.5 text-emerald-400" />
                <span>{t("menu.language_section")}</span>
              </div>
              <div className="grid grid-cols-3 gap-1.5">
                {locales.map((loc) => {
                  const isCurrentLocale = loc.code === locale;
                  return (
                    <button
                      key={loc.code}
                      type="button"
                      onClick={() => setLocale(loc.code)}
                      aria-pressed={isCurrentLocale}
                      className={`min-h-[38px] px-2.5 py-1.5 rounded-xl border text-xs font-semibold flex items-center justify-center gap-1.5 transition-colors cursor-pointer ${
                        isCurrentLocale
                          ? "bg-emerald-600 text-white border-emerald-400 shadow-sm"
                          : "bg-slate-950 hover:bg-slate-800 text-slate-300 border-slate-800"
                      }`}
                    >
                      <span>{loc.flag}</span>
                      <span>{loc.nativeName}</span>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Quick Global Actions */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              <button
                type="button"
                onClick={() => {
                  setIsTopRightMenuOpen(false);
                  setIsDocsModalOpen(true);
                }}
                className="min-h-[42px] px-3 py-2 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 text-sky-400 text-xs font-semibold inline-flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <BookOpen className="w-4 h-4 shrink-0" />
                <span>{t("menu.guide_docs")}</span>
              </button>

              <button
                type="button"
                onClick={() => {
                  setIsTopRightMenuOpen(false);
                  setActiveTab("diagnostics");
                }}
                className="min-h-[42px] px-3 py-2 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 text-emerald-400 text-xs font-semibold inline-flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <Activity className="w-4 h-4 shrink-0" />
                <span>{t("menu.diagnostics_e2e")}</span>
              </button>

              <button
                type="button"
                onClick={() => {
                  startGameSession(selectedGameId, matchMode, aiDifficulty);
                  setIsTopRightMenuOpen(false);
                }}
                className="min-h-[42px] px-3 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold inline-flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <RotateCcw className="w-4 h-4 shrink-0" />
                <span>{t("nav.restart_match")}</span>
              </button>
            </div>

            {/* 1. Interactive Tutorial & WASM AI Move Suggestion */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center gap-1.5 text-xs font-bold text-amber-300">
                <BookOpen className="w-3.5 h-3.5" />
                <span>
                  {t("menu.tutorial_section")} ({activeGameMeta.title})
                </span>
              </div>
              <InteractiveTutorialPanel
                gameId={selectedGameId}
                currentTurn={(currentTurn === 2 ? 2 : 1) as 1 | 2}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                onDispatchCommand={(cmd) => {
                  handleDispatchCommand(cmd);
                  setIsTopRightMenuOpen(false);
                }}
                hideToggleButton={true}
              />
            </div>

            {/* 2. Visual Themes, Okabe-Ito Colorblind Mode & Procedural Audio */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center gap-1.5 text-xs font-bold text-slate-200">
                <Palette className="w-3.5 h-3.5 text-emerald-400" />
                <span>{t("menu.themes_section")}</span>
              </div>
              <ThemeAndAudioToolbar
                config={themeConfig}
                onChange={setThemeConfig}
              />
            </div>

            {/* 3. Tournament Clock (FIDE Blitz, Rapid, Oriental Byo-yomi) */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center gap-1.5 text-xs font-bold text-slate-200">
                <Clock className="w-3.5 h-3.5 text-emerald-400" />
                <span>{t("menu.clock_section")}</span>
              </div>
              <TournamentClock
                clockState={clockState}
                activeTurn={(currentTurn === 2 ? 2 : 1) as 1 | 2}
                isPaused={parsedStateWinner !== null || !isReplayAtLiveHead}
                onPresetChange={(preset: ClockPresetId) =>
                  setClockState(createInitialClockState(preset))
                }
                onTick={handleClockTick}
              />
            </div>

            {/* 4. Step-by-Step Replay Viewer & JSON Export/Import */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center gap-1.5 text-xs font-bold text-slate-200">
                <History className="w-3.5 h-3.5 text-emerald-400" />
                <span>
                  {t("menu.replay_section")} ({replayCurrentStep}/
                  {replayTotalSteps})
                </span>
              </div>
              <ReplayViewerBar
                currentStep={replayCurrentStep}
                totalSteps={replayTotalSteps}
                gameId={selectedGameId}
                onSeekStep={handleSeekReplayStep}
                onExportJson={() => bridgeRef.current.export_log_json()}
                onImportJson={handleImportReplayJson}
              />
            </div>
          </aside>
        </div>
      )}

      {/* Mobile & Tablet Game List Drawer (< 1024px) */}
      <MobileGameListDrawer
        isOpen={isGameDrawerOpen}
        onClose={() => setIsGameDrawerOpen(false)}
        catalog={localizedCatalog}
        selectedGameId={selectedGameId}
        searchQuery={gameSearchQuery}
        categoryFilter={gameCategoryFilter}
        eloByGame={eloProfile.statsByGame}
        globalElo={eloProfile.globalRating}
        unlockedAchievementsCount={eloProfile.unlockedAchievements.length}
        totalAchievementsCount={ACHIEVEMENTS_CATALOG.length}
        onSearchChange={setGameSearchQuery}
        onCategoryFilterChange={setGameCategoryFilter}
        onSelectGame={(gid) => {
          startGameSession(gid, matchMode, aiDifficulty);
          setActiveTab("play");
        }}
        onOpenCatalogGrid={() => setActiveTab("catalog")}
        onOpenDiagnostics={() => setActiveTab("diagnostics")}
        onOpenDocs={() => setIsDocsModalOpen(true)}
      />

      {/* Responsive 2-Column Workspace Container (Desktop Sidebar + Main Content; Mobile Full-Width + Bottom Nav Padding) */}
      <main className="flex-1 max-w-[1440px] w-full mx-auto px-3 sm:px-6 pt-3 sm:pt-6 pb-20 lg:pb-8 flex flex-col lg:flex-row gap-5 lg:gap-6 items-start">
        {/* Persistent Categorized Game List Sidebar on Desktop (lg: >= 1024px) */}
        <aside
          aria-label={t("sidebar.games_list")}
          className="hidden lg:flex flex-col w-80 shrink-0 sticky top-20 max-h-[calc(100vh-6rem)] rounded-2xl bg-slate-900/90 border border-slate-800 overflow-hidden"
        >
          <CategorizedGameListContent
            catalog={localizedCatalog}
            selectedGameId={selectedGameId}
            searchQuery={gameSearchQuery}
            categoryFilter={gameCategoryFilter}
            eloByGame={eloProfile.statsByGame}
            globalElo={eloProfile.globalRating}
            unlockedAchievementsCount={eloProfile.unlockedAchievements.length}
            totalAchievementsCount={ACHIEVEMENTS_CATALOG.length}
            onSearchChange={setGameSearchQuery}
            onCategoryFilterChange={setGameCategoryFilter}
            onSelectGame={(gid) => {
              startGameSession(gid, matchMode, aiDifficulty);
              setActiveTab("play");
            }}
            onOpenCatalogGrid={() => setActiveTab("catalog")}
            onOpenDiagnostics={() => setActiveTab("diagnostics")}
            onOpenDocs={() => setIsDocsModalOpen(true)}
          />
        </aside>

        {/* Primary Adaptive Content Column */}
        <div className="flex-1 min-w-0 w-full flex flex-col gap-4 sm:gap-5">
          {/* Achievement Toast if newly unlocked */}
          {recentAchievementBanner && (
            <div className="p-3.5 rounded-xl bg-slate-900 border border-amber-500/70 flex items-center justify-between gap-4 text-xs">
              <div className="flex items-center gap-2 text-amber-300 font-semibold">
                <Trophy className="w-4 h-4 shrink-0" />
                <span>{recentAchievementBanner}</span>
              </div>
              <button
                type="button"
                onClick={() => setRecentAchievementBanner(null)}
                className="text-slate-400 hover:text-white font-medium cursor-pointer"
              >
                {t("menu.close")}
              </button>
            </div>
          )}

          {/* Mobile & Tablet Quick Bar: Active Game Switcher + Quick Secondary Views (< 1024px) */}
          <div className="lg:hidden flex flex-col gap-2.5">
            <div className="p-2.5 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-between gap-2">
              <button
                type="button"
                onClick={() => setIsGameDrawerOpen(true)}
                className="min-h-[44px] flex-1 px-3 py-1.5 rounded-xl bg-slate-950 hover:bg-slate-800 border border-slate-800 flex items-center justify-between gap-2 text-left transition-colors cursor-pointer"
              >
                <div className="min-w-0">
                  <div className="text-[11px] text-slate-400 truncate">
                    {activeGameMeta.category} · ELO{" "}
                    <span className="font-mono tabular-nums text-emerald-400 font-semibold">
                      {eloProfile.statsByGame[selectedGameId]?.rating ?? 1200}
                    </span>
                  </div>
                  <div className="text-sm font-bold text-white truncate">
                    {activeGameMeta.title}
                  </div>
                </div>
                <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-emerald-600/20 border border-emerald-500/40 text-emerald-300 text-xs font-semibold whitespace-nowrap shrink-0">
                  <Layers className="w-3.5 h-3.5" />
                  <span>{t("sidebar.list_14_button")}</span>
                  <ChevronDown className="w-3.5 h-3.5" />
                </span>
              </button>

              <button
                type="button"
                onClick={() => setIsDocsModalOpen(true)}
                aria-label={t("menu.guide_docs")}
                className="min-h-[44px] px-3 py-2 rounded-xl bg-slate-950 hover:bg-slate-800 border border-slate-800 text-sky-400 text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer"
              >
                <BookOpen className="w-4 h-4" />
                <span className="hidden sm:inline">
                  {t("sidebar.guide_short")}
                </span>
              </button>

              <button
                type="button"
                onClick={() => setActiveTab("diagnostics")}
                aria-label={t("menu.diagnostics_e2e")}
                className={`min-h-[44px] px-3 py-2 rounded-xl border text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer ${
                  activeTab === "diagnostics"
                    ? "bg-emerald-600 text-white border-emerald-500"
                    : "bg-slate-950 hover:bg-slate-800 border-slate-800 text-emerald-400"
                }`}
              >
                <Activity className="w-4 h-4" />
                <span className="hidden sm:inline">E2E</span>
              </button>
            </div>

            {/* Sub-navigation bar when inside ELO / Analyzer / Diagnostics / Catalog on mobile/tablet */}
            {activeTab !== "play" && (
              <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
                <button
                  type="button"
                  onClick={() => setActiveTab("play")}
                  className="min-h-[38px] px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-semibold whitespace-nowrap shrink-0 cursor-pointer"
                >
                  {t("sidebar.back_to_board")} ({activeGameMeta.title})
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab("catalog")}
                  className={`min-h-[38px] px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                    activeTab === "catalog"
                      ? "bg-white text-slate-950 font-semibold"
                      : "bg-slate-900 text-slate-300 border border-slate-800"
                  }`}
                >
                  {t("nav.catalog_14")}
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab("elo")}
                  className={`min-h-[38px] px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                    activeTab === "elo"
                      ? "bg-white text-slate-950 font-semibold"
                      : "bg-slate-900 text-slate-300 border border-slate-800"
                  }`}
                >
                  {t("nav.elo_ranking")}
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab("analyzer")}
                  className={`min-h-[38px] px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                    activeTab === "analyzer"
                      ? "bg-white text-slate-950 font-semibold"
                      : "bg-slate-900 text-slate-300 border border-slate-800"
                  }`}
                >
                  {t("nav.analyzer")}
                </button>
              </div>
            )}
          </div>

          {/* ACTIVE TAB: PLAY (Board-First Layout with Compact HUD & Collapsible Secondary Tools) */}
          {activeTab === "play" && (
            <section className="flex flex-col gap-3.5 sm:gap-4">
              {/* Compact Match HUD Header */}
              <div className="p-3.5 sm:p-4 rounded-2xl bg-slate-900/90 border border-slate-800 flex flex-col gap-3">
                {/* Row 1: Game Identity + Turn Status + Mode Segmented Switcher */}
                <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h1 className="text-lg sm:text-xl font-bold text-white font-display tracking-tight">
                        {activeGameMeta.title}
                      </h1>
                      <span
                        aria-hidden="true"
                        className="text-slate-600 hidden sm:inline"
                      >
                        ·
                      </span>
                      <span className="text-xs font-mono tabular-nums text-emerald-400 font-semibold">
                        {t("hud.turn_player")} {currentTurn}
                      </span>
                      {matchMode === "spectator" && (
                        <>
                          <span aria-hidden="true" className="text-slate-600">
                            ·
                          </span>
                          <span className="text-xs font-semibold text-amber-400">
                            {t("hud.spectator_mode")}
                          </span>
                        </>
                      )}
                    </div>
                    <p className="text-xs text-slate-400 mt-0.5 line-clamp-1">
                      {activeGameMeta.summary} · {t("hud.engine_label")}:{" "}
                      {activeGameMeta.crateName} (WASM)
                    </p>
                  </div>

                  {/* Match Mode Segmented Control */}
                  <div className="flex flex-wrap items-center gap-2 shrink-0">
                    <div className="grid grid-cols-2 sm:flex items-center gap-1 p-1 bg-slate-950 border border-slate-800 rounded-xl w-full sm:w-auto">
                      <button
                        type="button"
                        onClick={() => startGameSession(selectedGameId, "hotseat")}
                        className={`min-h-[38px] inline-flex items-center justify-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          matchMode === "hotseat"
                            ? "bg-emerald-600 text-white"
                            : "text-slate-300 hover:text-white"
                        }`}
                      >
                        <Users className="w-3.5 h-3.5 shrink-0" />
                        <span>{t("mode.hotseat")}</span>
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          startGameSession(selectedGameId, "ai", aiDifficulty)
                        }
                        className={`min-h-[38px] inline-flex items-center justify-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          matchMode === "ai"
                            ? "bg-emerald-600 text-white"
                            : "text-slate-300 hover:text-white"
                        }`}
                      >
                        <Bot className="w-3.5 h-3.5 shrink-0" />
                        <span>{t("mode.ai_rust")}</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => setActiveTab("network")}
                        className={`min-h-[38px] inline-flex items-center justify-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          matchMode === "online_relay"
                            ? "bg-emerald-600 text-white"
                            : "text-slate-300 hover:text-white"
                        }`}
                      >
                        <Wifi className="w-3.5 h-3.5 shrink-0" />
                        <span>{t("mode.online_relay")}</span>
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          startGameSession(selectedGameId, "spectator")
                        }
                        className={`min-h-[38px] inline-flex items-center justify-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          matchMode === "spectator"
                            ? "bg-amber-600 text-white"
                            : "text-slate-300 hover:text-white"
                        }`}
                      >
                        <Eye className="w-3.5 h-3.5 shrink-0" />
                        <span>{t("mode.spectator")}</span>
                      </button>
                    </div>

                    {matchMode === "ai" && (
                      <select
                        aria-label="AI Difficulty"
                        value={aiDifficulty}
                        onChange={(e) => {
                          const nextDiff = Number(e.target.value);
                          setAiDifficulty(nextDiff);
                          startGameSession(selectedGameId, "ai", nextDiff);
                        }}
                        className="min-h-[38px] px-3 py-1.5 rounded-xl text-xs font-medium bg-slate-950 border border-slate-800 text-slate-200"
                      >
                        <option value={0}>{t("ai.easy")}</option>
                        <option value={1}>{t("ai.medium")}</option>
                        <option value={2}>{t("ai.hard")}</option>
                        <option value={3}>{t("ai.master")}</option>
                      </select>
                    )}
                  </div>
                </div>

                {/* Online Relay Role Switcher when in Online or Spectator Mode */}
                {(matchMode === "online_relay" ||
                  matchMode === "spectator") && (
                  <div className="pt-2.5 border-t border-slate-800/80 flex flex-wrap items-center justify-between gap-2 text-xs">
                    <span className="text-slate-300 font-mono">
                      {t("relay.active_room")}:{" "}
                      <strong className="text-white">
                        {roomCode || "LOCAL"}
                      </strong>
                    </span>
                    <div className="flex flex-wrap items-center gap-1.5">
                      <button
                        type="button"
                        onClick={() => {
                          setMatchMode("online_relay");
                          setLocalNetworkPlayerId(1);
                        }}
                        className={`px-2.5 py-1 rounded font-semibold cursor-pointer ${
                          matchMode === "online_relay" &&
                          localNetworkPlayerId === 1
                            ? "bg-emerald-600 text-white"
                            : "bg-slate-800 text-slate-300"
                        }`}
                      >
                        {t("relay.host_p1")}
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setMatchMode("online_relay");
                          setLocalNetworkPlayerId(2);
                        }}
                        className={`px-2.5 py-1 rounded font-semibold cursor-pointer ${
                          matchMode === "online_relay" &&
                          localNetworkPlayerId === 2
                            ? "bg-sky-600 text-white"
                            : "bg-slate-800 text-slate-300"
                        }`}
                      >
                        {t("relay.client_p2")}
                      </button>
                      <button
                        type="button"
                        onClick={() => setMatchMode("spectator")}
                        className={`px-2.5 py-1 rounded font-semibold cursor-pointer ${
                          matchMode === "spectator"
                            ? "bg-amber-600 text-white"
                            : "bg-slate-800 text-slate-300"
                        }`}
                      >
                        {t("mode.spectator")}
                      </button>
                    </div>
                  </div>
                )}

                {/* Keep Active Clock mounted above board when a preset is active and top-right menu is closed */}
                {clockState.preset !== "none" && !isTopRightMenuOpen && (
                  <div className="pt-2 border-t border-slate-800/80">
                    <TournamentClock
                      clockState={clockState}
                      activeTurn={(currentTurn === 2 ? 2 : 1) as 1 | 2}
                      isPaused={
                        parsedStateWinner !== null || !isReplayAtLiveHead
                      }
                      onPresetChange={(preset: ClockPresetId) =>
                        setClockState(createInitialClockState(preset))
                      }
                      onTick={handleClockTick}
                    />
                  </div>
                )}

                {/* Replay Historical Step Notice when browsing past moves and top-right menu is closed */}
                {!isReplayAtLiveHead && !isTopRightMenuOpen && (
                  <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between gap-2 text-xs">
                    <span className="text-amber-300 font-medium">
                      {t("replay.viewing_history")} ({replayCurrentStep}/
                      {replayTotalSteps})
                    </span>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => handleSeekReplayStep(replayTotalSteps)}
                        className="px-2.5 py-1 rounded-lg bg-emerald-600 text-white font-semibold cursor-pointer"
                      >
                        {t("replay.go_live_turn")}
                      </button>
                      <button
                        type="button"
                        onClick={() => setIsTopRightMenuOpen(true)}
                        className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-200 font-medium cursor-pointer"
                      >
                        {t("replay.open_menu_controls")}
                      </button>
                    </div>
                  </div>
                )}
              </div>

              {/* Active Game Board Viewport (Immediately visible above the fold on mobile, tablet & desktop) */}
              <div className="w-full overflow-x-auto">
                {selectedGameId === "chess" && (
                  <ChessBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "checkers" && (
                  <CheckersBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "uno" && (
                  <UnoBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    isNetworkGame={
                      matchMode === "online_relay" || matchMode === "spectator"
                    }
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "goose" && (
                  <GooseBoard
                    stateJson={stateJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "go" && (
                  <GoBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "shogi" && (
                  <ShogiBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "xiangqi" && (
                  <XiangqiBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "chinese_checkers" && (
                  <ChineseCheckersBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "backgammon" && (
                  <BackgammonBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "ludo" && (
                  <LudoBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "battleship" && (
                  <BattleshipBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "mille_bornes" && (
                  <MilleBornesBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "monopoly" && (
                  <MonopolyBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}

                {selectedGameId === "crisis" && (
                  <CrisisBoard
                    stateJson={stateJson}
                    legalMovesJson={legalMovesJson}
                    isLocalTurnAllowed={isLocalTurnAllowed}
                    localPlayerId={localNetworkPlayerId}
                    onDispatchCommand={handleDispatchCommand}
                  />
                )}
              </div>

              {/* Live Room Chat when in Online Relay or Spectator Mode */}
              {(matchMode === "online_relay" || matchMode === "spectator") && (
                <RelayChatPanel
                  roomCode={roomCode}
                  localPlayerName={eloProfile.playerName}
                  localPlayerId={localNetworkPlayerId}
                  messages={chatMessages}
                  onSendMessage={handleSendChatMessage}
                />
              )}
            </section>
          )}

          {/* ACTIVE TAB: CATALOG (Categorized 14 Games View with Search & Filter) */}
          {activeTab === "catalog" && (
            <section className="flex flex-col gap-5">
              <div className="p-4 sm:p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div>
                    <h2 className="text-xl sm:text-2xl font-bold text-white font-display">
                      {t("catalog.heading")}
                    </h2>
                    <p className="text-xs sm:text-sm text-slate-400 mt-1">
                      {t("catalog.subheading")}
                    </p>
                  </div>
                </div>

                {/* Search & Rapid Filter Bar */}
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
                  <div className="relative flex-1">
                    <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type="text"
                      value={gameSearchQuery}
                      onChange={(e) => setGameSearchQuery(e.target.value)}
                      placeholder={t("catalog.search_placeholder")}
                      className="w-full min-h-[42px] pl-10 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs sm:text-sm text-white placeholder:text-slate-500"
                    />
                  </div>

                  <div className="flex flex-wrap items-center gap-1.5 bg-slate-950 p-1.5 rounded-xl border border-slate-800">
                    <button
                      type="button"
                      onClick={() => setGameCategoryFilter("all")}
                      className={`min-h-[34px] px-3 py-1 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        gameCategoryFilter === "all"
                          ? "bg-emerald-600 text-white"
                          : "text-slate-400 hover:text-white"
                      }`}
                    >
                      {t("catalog.all_14")}
                    </button>
                    {localizedCategoryGroups.map((grp) => (
                      <button
                        key={grp.id}
                        type="button"
                        onClick={() => setGameCategoryFilter(grp.id)}
                        className={`min-h-[34px] px-3 py-1 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          gameCategoryFilter === grp.id
                            ? "bg-emerald-600 text-white"
                            : "text-slate-400 hover:text-white"
                        }`}
                      >
                        {grp.shortLabel}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              {filterAndGroupCatalogGames(
                localizedCatalog,
                gameSearchQuery,
                gameCategoryFilter,
                locale
              ).map((section) => (
                <div key={section.groupId} className="flex flex-col gap-3">
                  <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                    <h3 className="text-base font-bold text-white font-display">
                      {section.groupLabel}
                    </h3>
                    <span className="text-xs text-slate-400 font-mono tabular-nums">
                      {section.games.length}{" "}
                      {section.games.length === 1
                        ? t("catalog.game_singular")
                        : t("catalog.game_plural")}
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3.5">
                    {section.games.map((item) => {
                      const idx =
                        localizedCatalog.findIndex((g) => g.id === item.id) + 1;
                      const isCurrent = item.id === selectedGameId;
                      return (
                        <div
                          key={item.id}
                          className={`p-4 sm:p-5 rounded-2xl border flex flex-col justify-between gap-4 transition-colors ${
                            isCurrent
                              ? "bg-emerald-950/20 border-emerald-500/60"
                              : "bg-slate-900 border-slate-800"
                          }`}
                        >
                          <div>
                            <div className="text-xs text-slate-400">
                              {String(idx).padStart(2, "0")}. {item.category} ·{" "}
                              {item.crateName}
                            </div>
                            <h4 className="text-base font-semibold text-white mt-1">
                              {item.title}
                            </h4>
                            <p className="text-xs text-slate-300 mt-1.5 leading-relaxed">
                              {item.summary}
                            </p>
                          </div>

                          <div className="flex items-center justify-between pt-3 border-t border-slate-800">
                            <span className="text-xs text-slate-300 font-mono tabular-nums">
                              ELO:{" "}
                              <strong className="text-emerald-400">
                                {eloProfile.statsByGame[item.id]?.rating ??
                                  1200}
                              </strong>
                            </span>
                            <button
                              type="button"
                              onClick={() => {
                                startGameSession(
                                  item.id,
                                  matchMode,
                                  aiDifficulty
                                );
                                setActiveTab("play");
                              }}
                              className="min-h-[38px] px-4 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                            >
                              {isCurrent
                                ? t("catalog.on_active_board")
                                : t("catalog.play_now")}
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </section>
          )}

          {activeTab === "tournaments" && (
            <TournamentManagerPanel
              tournament={tournamentState}
              gameTitles={localizedGameTitlesMap}
              activeMatchId={activeTournamentMatchId}
              onUpdateTournament={setTournamentState}
              onLaunchMatchOnBoard={handleLaunchTournamentMatch}
              onTournamentChampionCrowned={() => {
                playProceduralSound("victory", themeConfig);
                setEloProfile((prev) => {
                  const { updatedProfile, newlyUnlocked } =
                    recordTournamentVictoryInProfile(prev);
                  if (newlyUnlocked.length > 0) {
                    setRecentAchievementBanner(t("toast.tournament_champion"));
                  }
                  return updatedProfile;
                });
              }}
            />
          )}

          {activeTab === "elo" && (
            <EloAndAchievementsPanel
              profile={eloProfile}
              gameTitles={localizedGameTitlesMap}
              peerEloInfo={peerEloInfo}
              onUpdateProfile={setEloProfile}
              onSyncEloToRelay={() => {
                relayRef.current?.sendEloSync(
                  localNetworkPlayerId,
                  eloProfile.globalRating,
                  eloProfile.playerName
                );
              }}
            />
          )}

          {activeTab === "analyzer" && (
            <PostMatchAnalyzerPanel
              activeGame={selectedGameId}
              activeGameTitle={activeGameMeta.title}
              activeExportLogJson={bridgeRef.current.export_log_json()}
              colorblindMode={themeConfig.okabeIto}
              onLoadReplayLogToBoard={(logJson) => {
                if (handleImportReplayJson(logJson)) {
                  setActiveTab("play");
                }
              }}
            />
          )}

          {activeTab === "network" && (
            <section className="flex flex-col gap-6">
              {/* Mobile/Desktop Return to Board Banner */}
              <div className="p-3.5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-wrap items-center justify-between gap-3">
                <div className="text-xs text-slate-300">
                  {t("network.selected_game_banner")}{" "}
                  <strong className="text-white">{activeGameMeta.title}</strong>{" "}
                  · ELO{" "}
                  <span className="font-mono tabular-nums text-emerald-400 font-semibold">
                    {eloProfile.statsByGame[selectedGameId]?.rating ?? 1200}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setIsGameDrawerOpen(true)}
                    className="lg:hidden min-h-[38px] px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium cursor-pointer"
                  >
                    {t("network.change_game")}
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveTab("play")}
                    className="min-h-[38px] px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold cursor-pointer"
                  >
                    {t("network.view_active_board")}
                  </button>
                </div>
              </div>

              <MatchmakingQueuePanel
                activeGame={selectedGameId}
                activeGameTitle={activeGameMeta.title}
                playerElo={
                  eloProfile.statsByGame[selectedGameId]?.rating ??
                  eloProfile.globalRating
                }
                playerName={eloProfile.playerName}
                isQueuing={isQueuingMatchmaking}
                activeTicket={activeQueueTicket}
                onStartQueue={handleStartMatchmakingQueue}
                onExpandQueueTolerance={handleExpandMatchmakingTolerance}
                onCancelQueue={handleCancelMatchmakingQueue}
                onQuickCalibratedAiMatch={(diff) => {
                  setAiDifficulty(diff);
                  startGameSession(selectedGameId, "ai", diff);
                  setActiveTab("play");
                }}
              />

              <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                <div className="p-5 sm:p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-5">
                  <div>
                    <h2 className="text-lg sm:text-xl font-bold text-white font-display">
                      {t("network.room_heading")}
                    </h2>
                    <p className="text-xs text-slate-400 mt-1">
                      {t("network.room_subheading")}
                    </p>
                  </div>

                  <form
                    onSubmit={handleSaveSettings}
                    className="flex flex-col gap-2"
                  >
                    <label className="text-xs font-medium text-slate-300">
                      {t("network.relay_url_label")}
                    </label>
                    <div className="flex flex-wrap items-center gap-2">
                      <input
                        type="text"
                        value={relayUrl}
                        onChange={(e) => setRelayUrl(e.target.value)}
                        placeholder="ws://127.0.0.1:8080"
                        className="flex-1 min-w-[180px] min-h-[42px] px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-700 text-sm text-white font-mono"
                      />
                      <button
                        type="submit"
                        className="min-h-[42px] inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium cursor-pointer"
                      >
                        <Settings className="w-3.5 h-3.5" />
                        <span>{t("network.save_url")}</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          const def = saveRelayUrl("ws://127.0.0.1:8080");
                          setRelayUrl(def);
                          relayRef.current?.setRelayUrl(def);
                        }}
                        className="min-h-[42px] inline-flex items-center gap-1 px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs cursor-pointer"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        <span>{t("network.restore_url")}</span>
                      </button>
                    </div>
                  </form>

                  <div className="flex flex-wrap items-center gap-3 pt-1">
                    <button
                      type="button"
                      onClick={handleCreateRelayRoom}
                      className="min-h-[44px] inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors cursor-pointer"
                    >
                      <QrCode className="w-4 h-4" />
                      <span>{t("network.create_room_host")}</span>
                    </button>

                    <button
                      type="button"
                      onClick={() =>
                        relayRef.current?.simulateMicroDisconnectAndReconnect()
                      }
                      disabled={!roomCode}
                      className="min-h-[44px] inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 disabled:opacity-40 text-slate-200 text-xs font-medium border border-slate-700 transition-colors cursor-pointer"
                    >
                      <RefreshCw className="w-4 h-4" />
                      <span>{t("network.test_autoreconnect")}</span>
                    </button>
                  </div>

                  <div className="border-t border-slate-800 pt-4 flex flex-col gap-3">
                    <label className="text-xs font-medium text-slate-300">
                      {t("network.join_code_label")}
                    </label>
                    <div className="flex flex-wrap items-center gap-2">
                      <input
                        type="text"
                        maxLength={8}
                        value={joinCodeInput}
                        onChange={(e) =>
                          setJoinCodeInput(e.target.value.toUpperCase())
                        }
                        placeholder="AB12CD"
                        className="min-h-[44px] px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-700 text-sm text-white font-mono uppercase"
                      />
                      <button
                        type="button"
                        onClick={handleJoinRelayRoom}
                        className="min-h-[44px] px-4 py-2 rounded-xl bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                      >
                        {t("network.join_as_p2")}
                      </button>
                      <button
                        type="button"
                        onClick={handleJoinAsSpectator}
                        className="min-h-[44px] inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-amber-600 hover:bg-amber-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        <span>{t("network.observe_spectator")}</span>
                      </button>
                    </div>
                  </div>
                </div>

                {/* QR Code & Status Card */}
                <div className="p-5 sm:p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col items-center justify-center gap-4 text-center">
                  <div className="text-xs text-slate-400">
                    {t("network.transport_state")}{" "}
                    <strong className="text-white">{relayState}</strong>
                  </div>
                  <div className="text-sm font-medium text-slate-200">
                    {relayStatusText}
                  </div>

                  {qrSvg ? (
                    <div className="flex flex-col items-center gap-3 mt-2">
                      <div
                        className="p-3 rounded-2xl bg-white shadow-lg"
                        dangerouslySetInnerHTML={{ __html: qrSvg }}
                      />
                      <div className="text-xs text-slate-300 font-mono">
                        {t("network.room_code_label")}{" "}
                        <strong className="text-emerald-400 text-sm">
                          {roomCode}
                        </strong>
                      </div>
                    </div>
                  ) : (
                    <div className="p-6 sm:p-8 rounded-xl border border-dashed border-slate-800 text-xs text-slate-400">
                      {t("network.qr_empty_hint")}
                    </div>
                  )}
                </div>
              </div>

              {/* Room Chat Panel */}
              <RelayChatPanel
                roomCode={roomCode}
                localPlayerName={eloProfile.playerName}
                localPlayerId={localNetworkPlayerId}
                messages={chatMessages}
                onSendMessage={handleSendChatMessage}
              />
            </section>
          )}

          {activeTab === "diagnostics" && (
            <SystemDiagnosticsPanel
              activeGameId={selectedGameId}
              relayState={relayState}
              onSelectGameAndPlay={(gid) => {
                startGameSession(gid, matchMode, aiDifficulty);
                setActiveTab("play");
              }}
              onOpenDocsModal={() => setIsDocsModalOpen(true)}
            />
          )}
        </div>
      </main>

      {/* Mobile & Tablet Fixed Bottom Touch Bar (< 1024px) */}
      <MobileBottomNav
        activeTab={activeTab}
        isGameDrawerOpen={isGameDrawerOpen}
        hasActiveRoomOrQueue={Boolean(roomCode) || isQueuingMatchmaking}
        onSelectTab={(tab) => {
          setIsGameDrawerOpen(false);
          setActiveTab(tab);
        }}
        onToggleGameDrawer={() => setIsGameDrawerOpen((prev) => !prev)}
      />

      <DocumentationCenterModal
        isOpen={isDocsModalOpen}
        onClose={() => setIsDocsModalOpen(false)}
      />
    </div>
  );
};

export const App: React.FC = () => (
  <I18nProvider>
    <AppShell />
  </I18nProvider>
);

export default App;
