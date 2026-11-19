import React, {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import type {
  CatalogGameEntry,
  CategoryFilterId,
  CategoryGroupMeta,
} from "../components/common/GameListNavigation";

export type SupportedLocale =
  | "es"
  | "en"
  | "pt"
  | "it"
  | "de"
  | "ja"
  | "fr"
  | "ko"
  | "zh";

export const SUPPORTED_LOCALE_CODES: SupportedLocale[] = [
  "es",
  "en",
  "pt",
  "it",
  "de",
  "ja",
  "fr",
  "ko",
  "zh",
];

export interface LocaleMeta {
  code: SupportedLocale;
  shortLabel: string;
  nativeName: string;
  flag: string;
}

export const SUPPORTED_LOCALES: LocaleMeta[] = [
  { code: "es", shortLabel: "ES", nativeName: "Español", flag: "🇪🇸" },
  { code: "en", shortLabel: "EN", nativeName: "English", flag: "🇬🇧" },
  { code: "pt", shortLabel: "PT", nativeName: "Português", flag: "🇧🇷" },
  { code: "it", shortLabel: "IT", nativeName: "Italiano", flag: "🇮🇹" },
  { code: "de", shortLabel: "DE", nativeName: "Deutsch", flag: "🇩🇪" },
  { code: "ja", shortLabel: "JA", nativeName: "日本語", flag: "🇯🇵" },
  { code: "fr", shortLabel: "FR", nativeName: "Français", flag: "🇫🇷" },
  { code: "ko", shortLabel: "KO", nativeName: "한국어", flag: "🇰🇷" },
  { code: "zh", shortLabel: "ZH", nativeName: "中文", flag: "🇨🇳" },
];

export const LOCALE_STORAGE_KEY = "opentable_locale_v1";

export function isSupportedLocale(val: unknown): val is SupportedLocale {
  return (
    typeof val === "string" &&
    (SUPPORTED_LOCALE_CODES as string[]).includes(val)
  );
}

export function normalizeBrowserLocale(
  rawLang?: string | null
): SupportedLocale {
  if (!rawLang || typeof rawLang !== "string") return "es";
  const prefix = rawLang.trim().toLowerCase().slice(0, 2);
  if (isSupportedLocale(prefix)) {
    return prefix;
  }
  return "es";
}

export function detectInitialLocale(): SupportedLocale {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      const saved = window.localStorage.getItem(LOCALE_STORAGE_KEY);
      if (isSupportedLocale(saved)) {
        return saved;
      }
    }
    if (typeof navigator !== "undefined") {
      const candidate =
        (Array.isArray(navigator.languages) && navigator.languages[0]) ||
        navigator.language;
      if (candidate) {
        return normalizeBrowserLocale(candidate);
      }
    }
  } catch {
    // Ignore storage/navigator access errors in headless test environments
  }
  return "es";
}

export function saveLocalePreference(locale: SupportedLocale): SupportedLocale {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      window.localStorage.setItem(LOCALE_STORAGE_KEY, locale);
    }
    if (typeof document !== "undefined" && document.documentElement) {
      document.documentElement.lang = locale;
    }
  } catch {
    // Ignore storage quota errors
  }
  return locale;
}

export type UiTranslationKey =
  | "app.brand"
  | "nav.active_board"
  | "nav.catalog_14"
  | "nav.online_rooms"
  | "nav.tournaments"
  | "nav.elo_ranking"
  | "nav.analyzer"
  | "nav.restart_match"
  | "nav.menu"
  | "nav.language_label"
  | "nav.board_short"
  | "nav.elo_short"
  | "menu.control_center"
  | "menu.title"
  | "menu.close"
  | "menu.language_section"
  | "menu.guide_docs"
  | "menu.diagnostics_e2e"
  | "menu.tutorial_section"
  | "menu.themes_section"
  | "menu.clock_section"
  | "menu.replay_section"
  | "sidebar.games_list"
  | "sidebar.view_grid"
  | "sidebar.search_placeholder"
  | "sidebar.filter_all"
  | "sidebar.no_games_found"
  | "sidebar.global_elo"
  | "sidebar.achievements"
  | "sidebar.select_canonical_game"
  | "sidebar.list_14_button"
  | "sidebar.guide_short"
  | "sidebar.back_to_board"
  | "cat.classic"
  | "cat.classic_short"
  | "cat.oriental"
  | "cat.oriental_short"
  | "cat.dice_tactics"
  | "cat.dice_tactics_short"
  | "cat.cards_strategy"
  | "cat.cards_strategy_short"
  | "hud.turn_player"
  | "hud.spectator_mode"
  | "hud.engine_label"
  | "mode.hotseat"
  | "mode.ai_rust"
  | "mode.online_relay"
  | "mode.spectator"
  | "ai.easy"
  | "ai.medium"
  | "ai.hard"
  | "ai.master"
  | "relay.active_room"
  | "relay.host_p1"
  | "relay.client_p2"
  | "relay.no_active_room"
  | "relay.saved_url"
  | "replay.viewing_history"
  | "replay.go_live_turn"
  | "replay.open_menu_controls"
  | "replay.title"
  | "replay.play"
  | "replay.pause"
  | "replay.move_counter"
  | "replay.history_badge"
  | "replay.save_json"
  | "replay.load_json_file"
  | "replay.paste_view_json"
  | "replay.close_json_editor"
  | "replay.apply_json"
  | "clock.no_limit"
  | "clock.blitz"
  | "clock.rapid"
  | "clock.byoyomi"
  | "theme.label"
  | "theme.dark_stone"
  | "theme.blue_night"
  | "theme.green_jade"
  | "theme.okabe_active"
  | "theme.okabe_enable"
  | "theme.audio_on"
  | "theme.audio_off"
  | "catalog.heading"
  | "catalog.subheading"
  | "catalog.search_placeholder"
  | "catalog.all_14"
  | "catalog.game_singular"
  | "catalog.game_plural"
  | "catalog.on_active_board"
  | "catalog.play_now"
  | "network.selected_game_banner"
  | "network.change_game"
  | "network.view_active_board"
  | "network.room_heading"
  | "network.room_subheading"
  | "network.relay_url_label"
  | "network.save_url"
  | "network.restore_url"
  | "network.create_room_host"
  | "network.test_autoreconnect"
  | "network.join_code_label"
  | "network.join_as_p2"
  | "network.observe_spectator"
  | "network.transport_state"
  | "network.room_code_label"
  | "network.qr_empty_hint"
  | "toast.achievement_unlocked"
  | "toast.tournament_champion";

export const UI_DICTIONARIES: Record<
  SupportedLocale,
  Record<UiTranslationKey, string>
> = {
  es: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "Tablero Activo",
    "nav.catalog_14": "14 Juegos",
    "nav.online_rooms": "Salas Online",
    "nav.tournaments": "Torneos",
    "nav.elo_ranking": "Ranking ELO",
    "nav.analyzer": "Analizador",
    "nav.restart_match": "Reiniciar Partida",
    "nav.menu": "Menú",
    "nav.language_label": "Idioma",
    "nav.board_short": "Tablero",
    "nav.elo_short": "ELO / Análisis",
    "menu.control_center": "Opciones de Partida",
    "menu.title": "Menú de Herramientas",
    "menu.close": "Cerrar",
    "menu.language_section": "Idioma",
    "menu.guide_docs": "Guía",
    "menu.diagnostics_e2e": "Diagnóstico E2E",
    "menu.tutorial_section": "Tutorial y Sugerencia IA",
    "menu.themes_section": "Temas, Accesibilidad y Audio",
    "menu.clock_section": "Reloj de Torneo",
    "menu.replay_section": "Repeticiones y JSON",
    "sidebar.games_list": "Lista de Juegos",
    "sidebar.view_grid": "Ver cuadrícula",
    "sidebar.search_placeholder": "Buscar juego o regla...",
    "sidebar.filter_all": "Todos",
    "sidebar.no_games_found": "No se encontraron juegos para",
    "sidebar.global_elo": "ELO Global",
    "sidebar.achievements": "Logros",
    "sidebar.select_canonical_game": "Seleccionar Juego Canónico",
    "sidebar.list_14_button": "Lista (14)",
    "sidebar.guide_short": "Guía",
    "sidebar.back_to_board": "← Volver al Tablero",
    "cat.classic": "Estrategia Clásica",
    "cat.classic_short": "Clásicos",
    "cat.oriental": "Estrategia Oriental",
    "cat.oriental_short": "Oriental",
    "cat.dice_tactics": "Dados, Carrera y Táctica",
    "cat.dice_tactics_short": "Dados / Táctica",
    "cat.cards_strategy": "Cartas, Economía y Conquista",
    "cat.cards_strategy_short": "Cartas / Mesa",
    "hud.turn_player": "Turno: Jugador",
    "hud.spectator_mode": "Modo Espectador",
    "hud.engine_label": "Motor",
    "mode.hotseat": "Hotseat Local",
    "mode.ai_rust": "vs IA Rust",
    "mode.online_relay": "Online Relay / QR",
    "mode.spectator": "Espectador",
    "ai.easy": "IA Fácil",
    "ai.medium": "IA Media",
    "ai.hard": "IA Difícil",
    "ai.master": "IA Maestra",
    "relay.active_room": "Sala Activa",
    "relay.host_p1": "J1 (Host)",
    "relay.client_p2": "J2 (Cliente)",
    "relay.no_active_room": "Sin sala activa (Modo Local)",
    "relay.saved_url": "URL de Relay guardada",
    "replay.viewing_history": "Viendo jugada histórica",
    "replay.go_live_turn": "Ir a Turno en Vivo",
    "replay.open_menu_controls": "Abrir Controles en Menú ☰",
    "replay.title": "Visor de Repeticiones:",
    "replay.play": "Reproducir",
    "replay.pause": "Pausar",
    "replay.move_counter": "Jugada",
    "replay.history_badge": "Modo Histórico (Avanza al final o mueve para ramificar)",
    "replay.save_json": "Guardar JSON",
    "replay.load_json_file": "Cargar Archivo JSON",
    "replay.paste_view_json": "Pegar / Ver JSON",
    "replay.close_json_editor": "Cerrar Editor JSON",
    "replay.apply_json": "Aplicar JSON a la Mesa",
    "clock.no_limit": "Reloj: Sin Límite",
    "clock.blitz": "FIDE Blitz 3m + 2s",
    "clock.rapid": "FIDE Rápido 10m + 0s",
    "clock.byoyomi": "Byo-yomi 5m + 3×30s",
    "theme.label": "Tema:",
    "theme.dark_stone": "Piedra Oscura",
    "theme.blue_night": "Noche Azul",
    "theme.green_jade": "Jade Verde",
    "theme.okabe_active": "Okabe-Ito: Activo",
    "theme.okabe_enable": "Modo Daltónico Okabe-Ito",
    "theme.audio_on": "Audio FX: ON",
    "theme.audio_off": "Audio FX: OFF",
    "catalog.heading": "Catálogo de los 14 Juegos por Categoría",
    "catalog.subheading":
      "Selecciona cualquier juego para abrir su tablero interactivo WASM con tutorial guiado, reloj FIDE/Byo-yomi y ranking ELO K=32.",
    "catalog.search_placeholder":
      "Buscar por nombre, categoría o regla canónica...",
    "catalog.all_14": "Todos (14)",
    "catalog.game_singular": "juego",
    "catalog.game_plural": "juegos",
    "catalog.on_active_board": "En Tablero Activo",
    "catalog.play_now": "Jugar Ahora",
    "network.selected_game_banner":
      "Juego seleccionado para sala o matchmaking:",
    "network.change_game": "Cambiar Juego",
    "network.view_active_board": "Ver Tablero Activo",
    "network.room_heading":
      "Crear o Unirse a Sala Online Relay (Jugador o Espectador)",
    "network.room_subheading":
      "Compatible con open_table_relay (Cross-Play entre clientes Godot y clientes Web React) con envío automático de SyncState, bloqueo de turno local, sincronización ELO y chat en tiempo real.",
    "network.relay_url_label": "URL del Servidor Relay WebSocket (Persistente)",
    "network.save_url": "Guardar URL",
    "network.restore_url": "Restaurar",
    "network.create_room_host": "Crear Sala Online (Host J1)",
    "network.test_autoreconnect": "Probar Reconexión Automática",
    "network.join_code_label":
      "Unirse con Código de 6 Caracteres (Cliente J2 o Espectador)",
    "network.join_as_p2": "Unirse como J2",
    "network.observe_spectator": "Observar (Espectador)",
    "network.transport_state": "Estado de Transporte:",
    "network.room_code_label": "Código de Sala:",
    "network.qr_empty_hint":
      "Crea una sala online para generar el código QR instantáneo de invitación.",
    "toast.achievement_unlocked": "¡Logro desbloqueado",
    "toast.tournament_champion": "¡Logro desbloqueado: Campeón de Torneo!",
  },
  en: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "Active Board",
    "nav.catalog_14": "14 Games",
    "nav.online_rooms": "Online Rooms",
    "nav.tournaments": "Tournaments",
    "nav.elo_ranking": "ELO Ranking",
    "nav.analyzer": "Analyzer",
    "nav.restart_match": "Restart Match",
    "nav.menu": "Menu",
    "nav.language_label": "Language",
    "nav.board_short": "Board",
    "nav.elo_short": "ELO / Analysis",
    "menu.control_center": "Match Options",
    "menu.title": "Tools Menu",
    "menu.close": "Close",
    "menu.language_section": "Language",
    "menu.guide_docs": "Guide",
    "menu.diagnostics_e2e": "E2E Diagnostics",
    "menu.tutorial_section": "Tutorial & AI Hint",
    "menu.themes_section": "Themes, Accessibility & Audio",
    "menu.clock_section": "Tournament Clock",
    "menu.replay_section": "Replays & JSON",
    "sidebar.games_list": "Games List",
    "sidebar.view_grid": "View grid",
    "sidebar.search_placeholder": "Search game or rule...",
    "sidebar.filter_all": "All",
    "sidebar.no_games_found": "No games found for",
    "sidebar.global_elo": "Global ELO",
    "sidebar.achievements": "Achievements",
    "sidebar.select_canonical_game": "Select Canonical Game",
    "sidebar.list_14_button": "List (14)",
    "sidebar.guide_short": "Guide",
    "sidebar.back_to_board": "← Back to Board",
    "cat.classic": "Classic Strategy",
    "cat.classic_short": "Classics",
    "cat.oriental": "Eastern Strategy",
    "cat.oriental_short": "Eastern",
    "cat.dice_tactics": "Dice, Race & Tactics",
    "cat.dice_tactics_short": "Dice / Tactics",
    "cat.cards_strategy": "Cards, Economy & Conquest",
    "cat.cards_strategy_short": "Cards / Board",
    "hud.turn_player": "Turn: Player",
    "hud.spectator_mode": "Spectator Mode",
    "hud.engine_label": "Engine",
    "mode.hotseat": "Local Hotseat",
    "mode.ai_rust": "vs Rust AI",
    "mode.online_relay": "Online Relay / QR",
    "mode.spectator": "Spectator",
    "ai.easy": "Easy AI",
    "ai.medium": "Medium AI",
    "ai.hard": "Hard AI",
    "ai.master": "Master AI",
    "relay.active_room": "Active Room",
    "relay.host_p1": "P1 (Host)",
    "relay.client_p2": "P2 (Client)",
    "relay.no_active_room": "No active room (Local Mode)",
    "relay.saved_url": "Saved Relay URL",
    "replay.viewing_history": "Viewing historical move",
    "replay.go_live_turn": "Go to Live Turn",
    "replay.open_menu_controls": "Open Controls in Menu ☰",
    "replay.title": "Replay Viewer:",
    "replay.play": "Play",
    "replay.pause": "Pause",
    "replay.move_counter": "Move",
    "replay.history_badge": "History Mode (Seek to end or move to branch)",
    "replay.save_json": "Save JSON",
    "replay.load_json_file": "Load JSON File",
    "replay.paste_view_json": "Paste / View JSON",
    "replay.close_json_editor": "Close JSON Editor",
    "replay.apply_json": "Apply JSON to Board",
    "clock.no_limit": "Clock: Unlimited",
    "clock.blitz": "FIDE Blitz 3m + 2s",
    "clock.rapid": "FIDE Rapid 10m + 0s",
    "clock.byoyomi": "Byo-yomi 5m + 3×30s",
    "theme.label": "Theme:",
    "theme.dark_stone": "Dark Stone",
    "theme.blue_night": "Blue Night",
    "theme.green_jade": "Green Jade",
    "theme.okabe_active": "Okabe-Ito: Active",
    "theme.okabe_enable": "Okabe-Ito Colorblind Mode",
    "theme.audio_on": "Audio FX: ON",
    "theme.audio_off": "Audio FX: OFF",
    "catalog.heading": "14 Games Catalog by Category",
    "catalog.subheading":
      "Select any game to open its interactive WASM board with guided tutorial, FIDE/Byo-yomi clock, and K=32 ELO ranking.",
    "catalog.search_placeholder":
      "Search by name, category, or canonical rule...",
    "catalog.all_14": "All (14)",
    "catalog.game_singular": "game",
    "catalog.game_plural": "games",
    "catalog.on_active_board": "On Active Board",
    "catalog.play_now": "Play Now",
    "network.selected_game_banner": "Selected game for room or matchmaking:",
    "network.change_game": "Change Game",
    "network.view_active_board": "View Active Board",
    "network.room_heading":
      "Create or Join Online Relay Room (Player or Spectator)",
    "network.room_subheading":
      "Compatible with open_table_relay (Cross-Play between Godot and React Web clients) with automatic SyncState, local turn lock, ELO sync, and live chat.",
    "network.relay_url_label": "Relay WebSocket Server URL (Persistent)",
    "network.save_url": "Save URL",
    "network.restore_url": "Restore",
    "network.create_room_host": "Create Online Room (Host P1)",
    "network.test_autoreconnect": "Test Auto-Reconnect",
    "network.join_code_label":
      "Join with 6-Character Code (Client P2 or Spectator)",
    "network.join_as_p2": "Join as P2",
    "network.observe_spectator": "Watch (Spectator)",
    "network.transport_state": "Transport State:",
    "network.room_code_label": "Room Code:",
    "network.qr_empty_hint":
      "Create an online room to generate an instant invitation QR code.",
    "toast.achievement_unlocked": "Achievement unlocked",
    "toast.tournament_champion": "Achievement unlocked: Tournament Champion!",
  },
  pt: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "Tabuleiro Ativo",
    "nav.catalog_14": "14 Jogos",
    "nav.online_rooms": "Salas Online",
    "nav.tournaments": "Torneios",
    "nav.elo_ranking": "Ranking ELO",
    "nav.analyzer": "Analisador",
    "nav.restart_match": "Reiniciar Partida",
    "nav.menu": "Menu",
    "nav.language_label": "Idioma",
    "nav.board_short": "Tabuleiro",
    "nav.elo_short": "ELO / Análise",
    "menu.control_center": "Opções da Partida",
    "menu.title": "Menu de Ferramentas",
    "menu.close": "Fechar",
    "menu.language_section": "Idioma",
    "menu.guide_docs": "Guia",
    "menu.diagnostics_e2e": "Diagnóstico E2E",
    "menu.tutorial_section": "Tutorial e Sugestão IA",
    "menu.themes_section": "Temas, Acessibilidade e Áudio",
    "menu.clock_section": "Relógio de Torneio",
    "menu.replay_section": "Replays e JSON",
    "sidebar.games_list": "Lista de Jogos",
    "sidebar.view_grid": "Ver grade",
    "sidebar.search_placeholder": "Buscar jogo ou regra...",
    "sidebar.filter_all": "Todos",
    "sidebar.no_games_found": "Nenhum jogo encontrado para",
    "sidebar.global_elo": "ELO Global",
    "sidebar.achievements": "Conquistas",
    "sidebar.select_canonical_game": "Selecionar Jogo Canônico",
    "sidebar.list_14_button": "Lista (14)",
    "sidebar.guide_short": "Guia",
    "sidebar.back_to_board": "← Voltar ao Tabuleiro",
    "cat.classic": "Estratégia Clássica",
    "cat.classic_short": "Clássicos",
    "cat.oriental": "Estratégia Oriental",
    "cat.oriental_short": "Oriental",
    "cat.dice_tactics": "Dados, Corrida e Tática",
    "cat.dice_tactics_short": "Dados / Tática",
    "cat.cards_strategy": "Cartas, Economia e Conquista",
    "cat.cards_strategy_short": "Cartas / Mesa",
    "hud.turn_player": "Turno: Jogador",
    "hud.spectator_mode": "Modo Espectador",
    "hud.engine_label": "Motor",
    "mode.hotseat": "Hotseat Local",
    "mode.ai_rust": "vs IA Rust",
    "mode.online_relay": "Online Relay / QR",
    "mode.spectator": "Espectador",
    "ai.easy": "IA Fácil",
    "ai.medium": "IA Média",
    "ai.hard": "IA Difícil",
    "ai.master": "IA Mestre",
    "relay.active_room": "Sala Ativa",
    "relay.host_p1": "J1 (Anfitrião)",
    "relay.client_p2": "J2 (Cliente)",
    "relay.no_active_room": "Sem sala ativa (Modo Local)",
    "relay.saved_url": "URL do Relay salva",
    "replay.viewing_history": "Vendo jogada histórica",
    "replay.go_live_turn": "Ir ao Turno ao Vivo",
    "replay.open_menu_controls": "Abrir Controles no Menu ☰",
    "replay.title": "Visualizador de Replays:",
    "replay.play": "Reproduzir",
    "replay.pause": "Pausar",
    "replay.move_counter": "Jogada",
    "replay.history_badge": "Modo Histórico (Avance até o fim ou mova para ramificar)",
    "replay.save_json": "Salvar JSON",
    "replay.load_json_file": "Carregar Arquivo JSON",
    "replay.paste_view_json": "Colar / Ver JSON",
    "replay.close_json_editor": "Fechar Editor JSON",
    "replay.apply_json": "Aplicar JSON à Mesa",
    "clock.no_limit": "Relógio: Sem Limite",
    "clock.blitz": "FIDE Blitz 3m + 2s",
    "clock.rapid": "FIDE Rápido 10m + 0s",
    "clock.byoyomi": "Byo-yomi 5m + 3×30s",
    "theme.label": "Tema:",
    "theme.dark_stone": "Pedra Escura",
    "theme.blue_night": "Noite Azul",
    "theme.green_jade": "Jade Verde",
    "theme.okabe_active": "Okabe-Ito: Ativo",
    "theme.okabe_enable": "Modo Daltônico Okabe-Ito",
    "theme.audio_on": "Áudio FX: ON",
    "theme.audio_off": "Áudio FX: OFF",
    "catalog.heading": "Catálogo dos 14 Jogos por Categoria",
    "catalog.subheading":
      "Selecione qualquer jogo para abrir seu tabuleiro interativo WASM com tutorial guiado, relógio FIDE/Byo-yomi e ranking ELO K=32.",
    "catalog.search_placeholder":
      "Buscar por nome, categoria ou regra canônica...",
    "catalog.all_14": "Todos (14)",
    "catalog.game_singular": "jogo",
    "catalog.game_plural": "jogos",
    "catalog.on_active_board": "No Tabuleiro Ativo",
    "catalog.play_now": "Jogar Agora",
    "network.selected_game_banner":
      "Jogo selecionado para sala ou matchmaking:",
    "network.change_game": "Mudar Jogo",
    "network.view_active_board": "Ver Tabuleiro Ativo",
    "network.room_heading":
      "Criar ou Entrar em Sala Online Relay (Jogador ou Espectador)",
    "network.room_subheading":
      "Compatível com open_table_relay (Cross-Play entre clientes Godot e clientes Web React) com envio automático de SyncState, bloqueio de turno local, sincronização ELO e chat em tempo real.",
    "network.relay_url_label": "URL do Servidor Relay WebSocket (Persistente)",
    "network.save_url": "Salvar URL",
    "network.restore_url": "Restaurar",
    "network.create_room_host": "Criar Sala Online (Host J1)",
    "network.test_autoreconnect": "Testar Reconexão Automática",
    "network.join_code_label":
      "Entrar com Código de 6 Caracteres (Cliente J2 ou Espectador)",
    "network.join_as_p2": "Entrar como J2",
    "network.observe_spectator": "Assistir (Espectador)",
    "network.transport_state": "Estado do Transporte:",
    "network.room_code_label": "Código da Sala:",
    "network.qr_empty_hint":
      "Crie uma sala online para gerar o código QR instantâneo de convite.",
    "toast.achievement_unlocked": "Conquista desbloqueada",
    "toast.tournament_champion": "Conquista desbloqueada: Campeão de Torneio!",
  },
  it: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "Tavolo Attivo",
    "nav.catalog_14": "14 Giochi",
    "nav.online_rooms": "Stanze Online",
    "nav.tournaments": "Tornei",
    "nav.elo_ranking": "Classifica ELO",
    "nav.analyzer": "Analizzatore",
    "nav.restart_match": "Riavvia Partita",
    "nav.menu": "Menu",
    "nav.language_label": "Lingua",
    "nav.board_short": "Tavolo",
    "nav.elo_short": "ELO / Analisi",
    "menu.control_center": "Opzioni Partita",
    "menu.title": "Menu Strumenti",
    "menu.close": "Chiudi",
    "menu.language_section": "Lingua",
    "menu.guide_docs": "Guida",
    "menu.diagnostics_e2e": "Diagnostica E2E",
    "menu.tutorial_section": "Tutorial e Suggerimento IA",
    "menu.themes_section": "Temi, Accessibilità e Audio",
    "menu.clock_section": "Orologio da Torneo",
    "menu.replay_section": "Replay e JSON",
    "sidebar.games_list": "Elenco Giochi",
    "sidebar.view_grid": "Vista griglia",
    "sidebar.search_placeholder": "Cerca gioco o regola...",
    "sidebar.filter_all": "Tutti",
    "sidebar.no_games_found": "Nessun gioco trovato per",
    "sidebar.global_elo": "ELO Globale",
    "sidebar.achievements": "Obiettivi",
    "sidebar.select_canonical_game": "Seleziona Gioco Canonico",
    "sidebar.list_14_button": "Lista (14)",
    "sidebar.guide_short": "Guida",
    "sidebar.back_to_board": "← Torna al Tavolo",
    "cat.classic": "Strategia Classica",
    "cat.classic_short": "Classici",
    "cat.oriental": "Strategia Orientale",
    "cat.oriental_short": "Orientale",
    "cat.dice_tactics": "Dadi, Percorso e Tattica",
    "cat.dice_tactics_short": "Dadi / Tattica",
    "cat.cards_strategy": "Carte, Economia e Conquista",
    "cat.cards_strategy_short": "Carte / Tavolo",
    "hud.turn_player": "Turno: Giocatore",
    "hud.spectator_mode": "Modalità Spettatore",
    "hud.engine_label": "Motore",
    "mode.hotseat": "Hotseat Locale",
    "mode.ai_rust": "vs IA Rust",
    "mode.online_relay": "Online Relay / QR",
    "mode.spectator": "Spettatore",
    "ai.easy": "IA Facile",
    "ai.medium": "IA Media",
    "ai.hard": "IA Difficile",
    "ai.master": "IA Maestro",
    "relay.active_room": "Stanza Attiva",
    "relay.host_p1": "G1 (Host)",
    "relay.client_p2": "G2 (Client)",
    "relay.no_active_room": "Nessuna stanza attiva (Modalità Locale)",
    "relay.saved_url": "URL Relay salvato",
    "replay.viewing_history": "Visualizzazione mossa storica",
    "replay.go_live_turn": "Vai al Turno Live",
    "replay.open_menu_controls": "Apri Controlli nel Menu ☰",
    "replay.title": "Visore Replay:",
    "replay.play": "Riproduci",
    "replay.pause": "Pausa",
    "replay.move_counter": "Mossa",
    "replay.history_badge": "Modalità Storica (Vai alla fine o muovi per diramare)",
    "replay.save_json": "Salva JSON",
    "replay.load_json_file": "Carica File JSON",
    "replay.paste_view_json": "Incolla / Vedi JSON",
    "replay.close_json_editor": "Chiudi Editor JSON",
    "replay.apply_json": "Applica JSON al Tavolo",
    "clock.no_limit": "Orologio: Senza Limite",
    "clock.blitz": "FIDE Blitz 3m + 2s",
    "clock.rapid": "FIDE Rapido 10m + 0s",
    "clock.byoyomi": "Byo-yomi 5m + 3×30s",
    "theme.label": "Tema:",
    "theme.dark_stone": "Pietra Scura",
    "theme.blue_night": "Notte Blu",
    "theme.green_jade": "Giada Verde",
    "theme.okabe_active": "Okabe-Ito: Attivo",
    "theme.okabe_enable": "Modalità Daltonici Okabe-Ito",
    "theme.audio_on": "Audio FX: ON",
    "theme.audio_off": "Audio FX: OFF",
    "catalog.heading": "Catalogo dei 14 Giochi per Categoria",
    "catalog.subheading":
      "Seleziona un gioco per aprire la scacchiera interattiva WASM con tutorial guidato, orologio FIDE/Byo-yomi e classifica ELO K=32.",
    "catalog.search_placeholder":
      "Cerca per nome, categoria o regola canonica...",
    "catalog.all_14": "Tutti (14)",
    "catalog.game_singular": "gioco",
    "catalog.game_plural": "giochi",
    "catalog.on_active_board": "Sul Tavolo Attivo",
    "catalog.play_now": "Gioca Ora",
    "network.selected_game_banner":
      "Gioco selezionato per stanza o matchmaking:",
    "network.change_game": "Cambia Gioco",
    "network.view_active_board": "Vedi Tavolo Attivo",
    "network.room_heading":
      "Crea o Unisciti a Stanza Online Relay (Giocatore o Spettatore)",
    "network.room_subheading":
      "Compatibile con open_table_relay (Cross-Play tra client Godot e Web React) con invio automatico di SyncState, blocco turno locale, sync ELO e chat live.",
    "network.relay_url_label": "URL Server Relay WebSocket (Persistente)",
    "network.save_url": "Salva URL",
    "network.restore_url": "Ripristina",
    "network.create_room_host": "Crea Stanza Online (Host G1)",
    "network.test_autoreconnect": "Testa Riconnessione Automatica",
    "network.join_code_label":
      "Unisciti con Codice a 6 Caratteri (Client G2 o Spettatore)",
    "network.join_as_p2": "Unisciti come G2",
    "network.observe_spectator": "Osserva (Spettatore)",
    "network.transport_state": "Stato Trasporto:",
    "network.room_code_label": "Codice Stanza:",
    "network.qr_empty_hint":
      "Crea una stanza online per generare il codice QR istantaneo di invito.",
    "toast.achievement_unlocked": "Obiettivo sbloccato",
    "toast.tournament_champion": "Obiettivo sbloccato: Campione del Torneo!",
  },
  de: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "Aktives Spielbrett",
    "nav.catalog_14": "14 Spiele",
    "nav.online_rooms": "Online-Räume",
    "nav.tournaments": "Turniere",
    "nav.elo_ranking": "ELO-Rangliste",
    "nav.analyzer": "Analysator",
    "nav.restart_match": "Partie Neustarten",
    "nav.menu": "Menü",
    "nav.language_label": "Sprache",
    "nav.board_short": "Spielbrett",
    "nav.elo_short": "ELO / Analyse",
    "menu.control_center": "Spieloptionen",
    "menu.title": "Werkzeugmenü",
    "menu.close": "Schließen",
    "menu.language_section": "Sprache",
    "menu.guide_docs": "Handbuch",
    "menu.diagnostics_e2e": "E2E-Diagnose",
    "menu.tutorial_section": "Tutorial & KI-Zugvorschlag",
    "menu.themes_section": "Themen, Barrierefreiheit & Audio",
    "menu.clock_section": "Turnieruhr",
    "menu.replay_section": "Replays & JSON",
    "sidebar.games_list": "Spieleliste",
    "sidebar.view_grid": "Rasteransicht",
    "sidebar.search_placeholder": "Spiel oder Regel suchen...",
    "sidebar.filter_all": "Alle",
    "sidebar.no_games_found": "Keine Spiele gefunden für",
    "sidebar.global_elo": "Globales ELO",
    "sidebar.achievements": "Erfolge",
    "sidebar.select_canonical_game": "Kanonisches Spiel wählen",
    "sidebar.list_14_button": "Liste (14)",
    "sidebar.guide_short": "Hilfe",
    "sidebar.back_to_board": "← Zurück zum Brett",
    "cat.classic": "Klassische Strategie",
    "cat.classic_short": "Klassiker",
    "cat.oriental": "Östliche Strategie",
    "cat.oriental_short": "Östlich",
    "cat.dice_tactics": "Würfel, Rennen & Taktik",
    "cat.dice_tactics_short": "Würfel / Taktik",
    "cat.cards_strategy": "Karten, Wirtschaft & Eroberung",
    "cat.cards_strategy_short": "Karten / Brett",
    "hud.turn_player": "Zug: Spieler",
    "hud.spectator_mode": "Zuschauermodus",
    "hud.engine_label": "Engine",
    "mode.hotseat": "Lokales Hotseat",
    "mode.ai_rust": "vs Rust-KI",
    "mode.online_relay": "Online-Relay / QR",
    "mode.spectator": "Zuschauer",
    "ai.easy": "KI Leicht",
    "ai.medium": "KI Mittel",
    "ai.hard": "KI Schwer",
    "ai.master": "KI Meister",
    "relay.active_room": "Aktiver Raum",
    "relay.host_p1": "S1 (Host)",
    "relay.client_p2": "S2 (Client)",
    "relay.no_active_room": "Kein aktiver Raum (Lokaler Modus)",
    "relay.saved_url": "Gespeicherte Relay-URL",
    "replay.viewing_history": "Historischer Zug wird angezeigt",
    "replay.go_live_turn": "Zum Live-Zug",
    "replay.open_menu_controls": "Steuerung im Menü ☰ öffnen",
    "replay.title": "Replay-Player:",
    "replay.play": "Abspielen",
    "replay.pause": "Pause",
    "replay.move_counter": "Zug",
    "replay.history_badge": "Historischer Modus (Zum Ende springen oder ziehen)",
    "replay.save_json": "JSON Speichern",
    "replay.load_json_file": "JSON-Datei Laden",
    "replay.paste_view_json": "JSON Einfügen / Ansehen",
    "replay.close_json_editor": "JSON-Editor Schließen",
    "replay.apply_json": "JSON auf Spielbrett Anwenden",
    "clock.no_limit": "Uhr: Kein Limit",
    "clock.blitz": "FIDE Blitz 3m + 2s",
    "clock.rapid": "FIDE Schnell 10m + 0s",
    "clock.byoyomi": "Byo-yomi 5m + 3×30s",
    "theme.label": "Thema:",
    "theme.dark_stone": "Dunkler Stein",
    "theme.blue_night": "Blaue Nacht",
    "theme.green_jade": "Grüne Jade",
    "theme.okabe_active": "Okabe-Ito: Aktiv",
    "theme.okabe_enable": "Okabe-Ito Farbenblind-Modus",
    "theme.audio_on": "Audio-FX: AN",
    "theme.audio_off": "Audio-FX: AUS",
    "catalog.heading": "Katalog der 14 Spiele nach Kategorie",
    "catalog.subheading":
      "Wähle ein Spiel, um das interaktive WASM-Spielbrett mit Tutorial, FIDE/Byo-yomi-Uhr und K=32 ELO-Rangliste zu öffnen.",
    "catalog.search_placeholder":
      "Nach Name, Kategorie oder kanonischer Regel suchen...",
    "catalog.all_14": "Alle (14)",
    "catalog.game_singular": "Spiel",
    "catalog.game_plural": "Spiele",
    "catalog.on_active_board": "Auf aktivem Brett",
    "catalog.play_now": "Jetzt Spielen",
    "network.selected_game_banner":
      "Ausgewähltes Spiel für Raum oder Matchmaking:",
    "network.change_game": "Spiel Wechseln",
    "network.view_active_board": "Aktives Brett Anzeigen",
    "network.room_heading":
      "Online-Relay-Raum Erstellen oder Beitreten (Spieler oder Zuschauer)",
    "network.room_subheading":
      "Kompatibel mit open_table_relay (Cross-Play zwischen Godot- und React-Web-Clients) mit automatischem SyncState, Zug-Sperre, ELO-Sync und Live-Chat.",
    "network.relay_url_label": "Relay-WebSocket-Server-URL (Persistent)",
    "network.save_url": "URL Speichern",
    "network.restore_url": "Zurücksetzen",
    "network.create_room_host": "Online-Raum Erstellen (Host S1)",
    "network.test_autoreconnect": "Auto-Reconnect Testen",
    "network.join_code_label":
      "Mit 6-stelligem Code Beitreten (Client S2 oder Zuschauer)",
    "network.join_as_p2": "Als S2 Beitreten",
    "network.observe_spectator": "Zuschauen (Zuschauer)",
    "network.transport_state": "Transportstatus:",
    "network.room_code_label": "Raumcode:",
    "network.qr_empty_hint":
      "Erstelle einen Online-Raum, um sofort einen Einladungs-QR-Code zu erzeugen.",
    "toast.achievement_unlocked": "Erfolg freigeschaltet",
    "toast.tournament_champion": "Erfolg freigeschaltet: Turnier-Champion!",
  },
  ja: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "現在の盤面",
    "nav.catalog_14": "全14ゲーム",
    "nav.online_rooms": "オンライン対局室",
    "nav.tournaments": "トーナメント",
    "nav.elo_ranking": "ELOランキング",
    "nav.analyzer": "棋譜解析",
    "nav.restart_match": "対局をリセット",
    "nav.menu": "メニュー",
    "nav.language_label": "言語",
    "nav.board_short": "盤面",
    "nav.elo_short": "ELO / 解析",
    "menu.control_center": "対局オプション",
    "menu.title": "ツールメニュー",
    "menu.close": "閉じる",
    "menu.language_section": "言語",
    "menu.guide_docs": "ガイド",
    "menu.diagnostics_e2e": "E2E診断",
    "menu.tutorial_section": "チュートリアル＆AI推奨手",
    "menu.themes_section": "テーマ・色覚サポート・効果音",
    "menu.clock_section": "対局時計",
    "menu.replay_section": "リプレイ＆JSON",
    "sidebar.games_list": "ゲーム一覧",
    "sidebar.view_grid": "グリッド表示",
    "sidebar.search_placeholder": "ゲーム名やルールで検索...",
    "sidebar.filter_all": "すべて",
    "sidebar.no_games_found": "該当するゲームがありません：",
    "sidebar.global_elo": "総合ELO",
    "sidebar.achievements": "実績",
    "sidebar.select_canonical_game": "公式ゲームを選択",
    "sidebar.list_14_button": "一覧 (14)",
    "sidebar.guide_short": "ガイド",
    "sidebar.back_to_board": "← 盤面へ戻る",
    "cat.classic": "古典ストラテジー",
    "cat.classic_short": "古典",
    "cat.oriental": "東洋ストラテジー",
    "cat.oriental_short": "東洋",
    "cat.dice_tactics": "ダイス・レース・戦術",
    "cat.dice_tactics_short": "ダイス/戦術",
    "cat.cards_strategy": "カード・経済・世界征服",
    "cat.cards_strategy_short": "カード/盤上",
    "hud.turn_player": "手番：プレイヤー",
    "hud.spectator_mode": "観戦モード",
    "hud.engine_label": "エンジン",
    "mode.hotseat": "ローカル対戦",
    "mode.ai_rust": "vs Rust AI",
    "mode.online_relay": "オンラインRelay / QR",
    "mode.spectator": "観戦",
    "ai.easy": "AI 初級",
    "ai.medium": "AI 中級",
    "ai.hard": "AI 上級",
    "ai.master": "AI マスター",
    "relay.active_room": "現在のルーム",
    "relay.host_p1": "P1 (ホスト)",
    "relay.client_p2": "P2 (ゲスト)",
    "relay.no_active_room": "ルーム未接続（ローカルモード）",
    "relay.saved_url": "保存されたRelay URL",
    "replay.viewing_history": "過去の手順を表示中",
    "replay.go_live_turn": "最新の手番へ戻る",
    "replay.open_menu_controls": "メニュー ☰ で操作を開く",
    "replay.title": "リプレイ：",
    "replay.play": "再生",
    "replay.pause": "一時停止",
    "replay.move_counter": "手数",
    "replay.history_badge": "履歴表示モード（最終手へ進むか着手して分岐）",
    "replay.save_json": "JSONを保存",
    "replay.load_json_file": "JSONファイルを読込",
    "replay.paste_view_json": "JSONを貼付 / 表示",
    "replay.close_json_editor": "JSONエディタを閉じる",
    "replay.apply_json": "JSONを盤面に適用",
    "clock.no_limit": "時計：時間無制限",
    "clock.blitz": "FIDE ブリッツ 3分 + 2秒",
    "clock.rapid": "FIDE ラピッド 10分 + 0秒",
    "clock.byoyomi": "秒読み 5分 + 3×30秒",
    "theme.label": "テーマ：",
    "theme.dark_stone": "ダークストーン",
    "theme.blue_night": "ブルーナイト",
    "theme.green_jade": "グリーンジェイド",
    "theme.okabe_active": "Okabe-Ito：有効",
    "theme.okabe_enable": "Okabe-Ito 色覚サポート",
    "theme.audio_on": "効果音：ON",
    "theme.audio_off": "効果音：OFF",
    "catalog.heading": "カテゴリ別 全14ゲームカタログ",
    "catalog.subheading":
      "任意のゲームを選択すると、ガイド付きチュートリアル、FIDE/秒読み時計、K=32 ELOランキング対応のWASM盤面が開きます。",
    "catalog.search_placeholder": "名前、カテゴリ、公式ルールで検索...",
    "catalog.all_14": "すべて (14)",
    "catalog.game_singular": "ゲーム",
    "catalog.game_plural": "ゲーム",
    "catalog.on_active_board": "現在プレイ中",
    "catalog.play_now": "今すぐプレイ",
    "network.selected_game_banner": "ルーム／マッチメイキング対象ゲーム：",
    "network.change_game": "ゲーム変更",
    "network.view_active_board": "現在の盤面を見る",
    "network.room_heading":
      "オンラインRelayルームの作成・参加（対局者または観戦者）",
    "network.room_subheading":
      "open_table_relay互換（GodotとReact Web間のクロスプレイ）、SyncState自動同期、手番ロック、ELO同期、リアルタイムチャット対応。",
    "network.relay_url_label": "Relay WebSocketサーバーURL（自動保存）",
    "network.save_url": "URLを保存",
    "network.restore_url": "初期値に戻す",
    "network.create_room_host": "オンラインルーム作成 (ホスト P1)",
    "network.test_autoreconnect": "自動再接続テスト",
    "network.join_code_label": "6桁コードで参加（ゲスト P2 または観戦者）",
    "network.join_as_p2": "P2として参加",
    "network.observe_spectator": "観戦する（スペクテイター）",
    "network.transport_state": "通信ステータス：",
    "network.room_code_label": "ルームコード：",
    "network.qr_empty_hint":
      "オンラインルームを作成すると招待用QRコードが即座に生成されます。",
    "toast.achievement_unlocked": "実績解除",
    "toast.tournament_champion": "実績解除：トーナメント優勝！",
  },
  fr: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "Plateau Actif",
    "nav.catalog_14": "14 Jeux",
    "nav.online_rooms": "Salons en Ligne",
    "nav.tournaments": "Tournois",
    "nav.elo_ranking": "Classement ELO",
    "nav.analyzer": "Analyseur",
    "nav.restart_match": "Redémarrer la Partie",
    "nav.menu": "Menu",
    "nav.language_label": "Langue",
    "nav.board_short": "Plateau",
    "nav.elo_short": "ELO / Analyse",
    "menu.control_center": "Options de Partie",
    "menu.title": "Menu des Outils",
    "menu.close": "Fermer",
    "menu.language_section": "Langue",
    "menu.guide_docs": "Guide",
    "menu.diagnostics_e2e": "Diagnostic E2E",
    "menu.tutorial_section": "Tutoriel et Suggestion IA",
    "menu.themes_section": "Thèmes, Accessibilité et Audio",
    "menu.clock_section": "Pendule de Tournoi",
    "menu.replay_section": "Replays et JSON",
    "sidebar.games_list": "Liste des Jeux",
    "sidebar.view_grid": "Vue grille",
    "sidebar.search_placeholder": "Rechercher un jeu ou une règle...",
    "sidebar.filter_all": "Tous",
    "sidebar.no_games_found": "Aucun jeu trouvé pour",
    "sidebar.global_elo": "ELO Global",
    "sidebar.achievements": "Succès",
    "sidebar.select_canonical_game": "Sélectionner un Jeu Canonique",
    "sidebar.list_14_button": "Liste (14)",
    "sidebar.guide_short": "Guide",
    "sidebar.back_to_board": "← Retour au Plateau",
    "cat.classic": "Stratégie Classique",
    "cat.classic_short": "Classiques",
    "cat.oriental": "Stratégie Orientale",
    "cat.oriental_short": "Orientale",
    "cat.dice_tactics": "Dés, Course et Tactique",
    "cat.dice_tactics_short": "Dés / Tactique",
    "cat.cards_strategy": "Cartes, Économie et Conquête",
    "cat.cards_strategy_short": "Cartes / Plateau",
    "hud.turn_player": "Tour : Joueur",
    "hud.spectator_mode": "Mode Spectateur",
    "hud.engine_label": "Moteur",
    "mode.hotseat": "Hotseat Local",
    "mode.ai_rust": "vs IA Rust",
    "mode.online_relay": "Relais en Ligne / QR",
    "mode.spectator": "Spectateur",
    "ai.easy": "IA Facile",
    "ai.medium": "IA Moyenne",
    "ai.hard": "IA Difficile",
    "ai.master": "IA Maître",
    "relay.active_room": "Salon Actif",
    "relay.host_p1": "J1 (Hôte)",
    "relay.client_p2": "J2 (Client)",
    "relay.no_active_room": "Aucun salon actif (Mode Local)",
    "relay.saved_url": "URL Relais enregistrée",
    "replay.viewing_history": "Consultation d'un coup historique",
    "replay.go_live_turn": "Aller au Tour en Direct",
    "replay.open_menu_controls": "Ouvrir Contrôles dans le Menu ☰",
    "replay.title": "Lecteur de Replays :",
    "replay.play": "Lire",
    "replay.pause": "Pause",
    "replay.move_counter": "Coup",
    "replay.history_badge": "Mode Historique (Avancez à la fin ou jouez pour bifurquer)",
    "replay.save_json": "Enregistrer JSON",
    "replay.load_json_file": "Charger Fichier JSON",
    "replay.paste_view_json": "Coller / Voir JSON",
    "replay.close_json_editor": "Fermer Éditeur JSON",
    "replay.apply_json": "Appliquer JSON au Plateau",
    "clock.no_limit": "Pendule : Sans Limite",
    "clock.blitz": "FIDE Blitz 3m + 2s",
    "clock.rapid": "FIDE Rapide 10m + 0s",
    "clock.byoyomi": "Byo-yomi 5m + 3×30s",
    "theme.label": "Thème :",
    "theme.dark_stone": "Pierre Sombre",
    "theme.blue_night": "Nuit Bleue",
    "theme.green_jade": "Jade Vert",
    "theme.okabe_active": "Okabe-Ito : Actif",
    "theme.okabe_enable": "Mode Daltonien Okabe-Ito",
    "theme.audio_on": "Audio FX : ON",
    "theme.audio_off": "Audio FX : OFF",
    "catalog.heading": "Catalogue des 14 Jeux par Catégorie",
    "catalog.subheading":
      "Sélectionnez n'importe quel jeu pour ouvrir son plateau interactif WASM avec tutoriel guidé, pendule FIDE/Byo-yomi et classement ELO K=32.",
    "catalog.search_placeholder":
      "Rechercher par nom, catégorie ou règle canonique...",
    "catalog.all_14": "Tous (14)",
    "catalog.game_singular": "jeu",
    "catalog.game_plural": "jeux",
    "catalog.on_active_board": "Sur le Plateau Actif",
    "catalog.play_now": "Jouer Maintenant",
    "network.selected_game_banner":
      "Jeu sélectionné pour le salon ou le matchmaking :",
    "network.change_game": "Changer de Jeu",
    "network.view_active_board": "Voir le Plateau Actif",
    "network.room_heading":
      "Créer ou Rejoindre un Salon Relais en Ligne (Joueur ou Spectateur)",
    "network.room_subheading":
      "Compatible avec open_table_relay (Cross-Play entre clients Godot et Web React) avec envoi automatique de SyncState, verrouillage de tour, sync ELO et chat en direct.",
    "network.relay_url_label": "URL du Serveur Relais WebSocket (Persistante)",
    "network.save_url": "Enregistrer URL",
    "network.restore_url": "Restaurer",
    "network.create_room_host": "Créer Salon en Ligne (Hôte J1)",
    "network.test_autoreconnect": "Tester la Reconnexion Auto",
    "network.join_code_label":
      "Rejoindre avec un Code à 6 Caractères (Client J2 ou Spectateur)",
    "network.join_as_p2": "Rejoindre comme J2",
    "network.observe_spectator": "Observer (Spectateur)",
    "network.transport_state": "État du Transport :",
    "network.room_code_label": "Code du Salon :",
    "network.qr_empty_hint":
      "Créez un salon en ligne pour générer instantanément le QR code d'invitation.",
    "toast.achievement_unlocked": "Succès débloqué",
    "toast.tournament_champion": "Succès débloqué : Champion de Tournoi !",
  },
  ko: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "활성 보드",
    "nav.catalog_14": "14종 게임",
    "nav.online_rooms": "온라인 방",
    "nav.tournaments": "토너먼트",
    "nav.elo_ranking": "ELO 랭킹",
    "nav.analyzer": "대국 분석기",
    "nav.restart_match": "대국 재시작",
    "nav.menu": "메뉴",
    "nav.language_label": "언어",
    "nav.board_short": "보드",
    "nav.elo_short": "ELO / 분석",
    "menu.control_center": "대국 옵션",
    "menu.title": "도구 메뉴",
    "menu.close": "닫기",
    "menu.language_section": "언어",
    "menu.guide_docs": "가이드",
    "menu.diagnostics_e2e": "E2E 진단",
    "menu.tutorial_section": "튜토리얼 및 AI 추천 수",
    "menu.themes_section": "테마, 색각 보정 및 사운드",
    "menu.clock_section": "토너먼트 시계",
    "menu.replay_section": "리플레이 및 JSON",
    "sidebar.games_list": "게임 목록",
    "sidebar.view_grid": "그리드 보기",
    "sidebar.search_placeholder": "게임 또는 규칙 검색...",
    "sidebar.filter_all": "전체",
    "sidebar.no_games_found": "검색된 게임이 없습니다:",
    "sidebar.global_elo": "글로벌 ELO",
    "sidebar.achievements": "업적",
    "sidebar.select_canonical_game": "공식 보드게임 선택",
    "sidebar.list_14_button": "목록 (14)",
    "sidebar.guide_short": "가이드",
    "sidebar.back_to_board": "← 보드로 돌아가기",
    "cat.classic": "클래식 전략",
    "cat.classic_short": "클래식",
    "cat.oriental": "동양 전략",
    "cat.oriental_short": "동양",
    "cat.dice_tactics": "주사위, 레이스 및 전술",
    "cat.dice_tactics_short": "주사위 / 전술",
    "cat.cards_strategy": "카드, 경제 및 정복",
    "cat.cards_strategy_short": "카드 / 보드",
    "hud.turn_player": "차례: 플레이어",
    "hud.spectator_mode": "관전 모드",
    "hud.engine_label": "엔진",
    "mode.hotseat": "로컬 핫시트",
    "mode.ai_rust": "vs Rust AI",
    "mode.online_relay": "온라인 Relay / QR",
    "mode.spectator": "관전자",
    "ai.easy": "AI 쉬움",
    "ai.medium": "AI 보통",
    "ai.hard": "AI 어려움",
    "ai.master": "AI 마스터",
    "relay.active_room": "활성 방",
    "relay.host_p1": "P1 (호스트)",
    "relay.client_p2": "P2 (클라이언트)",
    "relay.no_active_room": "활성 방 없음 (로컬 모드)",
    "relay.saved_url": "저장된 Relay URL",
    "replay.viewing_history": "이전 수순 탐색 중",
    "replay.go_live_turn": "실시간 차례로 이동",
    "replay.open_menu_controls": "메뉴 ☰ 에서 컨트롤 열기",
    "replay.title": "리플레이 뷰어:",
    "replay.play": "재생",
    "replay.pause": "일시정지",
    "replay.move_counter": "수순",
    "replay.history_badge": "히스토리 모드 (끝으로 이동하거나 착수하여 분기)",
    "replay.save_json": "JSON 저장",
    "replay.load_json_file": "JSON 파일 불러오기",
    "replay.paste_view_json": "JSON 붙여넣기 / 보기",
    "replay.close_json_editor": "JSON 편집기 닫기",
    "replay.apply_json": "보드에 JSON 적용",
    "clock.no_limit": "시계: 무제한",
    "clock.blitz": "FIDE 블리츠 3분 + 2초",
    "clock.rapid": "FIDE 래피드 10분 + 0초",
    "clock.byoyomi": "초읽기 5분 + 3×30초",
    "theme.label": "테마:",
    "theme.dark_stone": "다크 스톤",
    "theme.blue_night": "블루 나이트",
    "theme.green_jade": "그린 제이드",
    "theme.okabe_active": "Okabe-Ito: 켜짐",
    "theme.okabe_enable": "Okabe-Ito 색각 이상 모드",
    "theme.audio_on": "오디오 FX: ON",
    "theme.audio_off": "오디오 FX: OFF",
    "catalog.heading": "카테고리별 14종 게임 카탈로그",
    "catalog.subheading":
      "게임을 선택하면 가이드 튜토리얼, FIDE/초읽기 시계 및 K=32 ELO 랭킹을 지원하는 인터랙티브 WASM 보드가 열립니다.",
    "catalog.search_placeholder": "이름, 카테고리 또는 공식 규칙으로 검색...",
    "catalog.all_14": "전체 (14)",
    "catalog.game_singular": "게임",
    "catalog.game_plural": "게임",
    "catalog.on_active_board": "현재 활성 보드",
    "catalog.play_now": "지금 플레이",
    "network.selected_game_banner": "방 또는 매치메이킹 선택 게임:",
    "network.change_game": "게임 변경",
    "network.view_active_board": "활성 보드 보기",
    "network.room_heading":
      "온라인 Relay 방 만들기 또는 참가 (플레이어 또는 관전자)",
    "network.room_subheading":
      "open_table_relay 호환(Godot 및 React 웹 클라이언트 간 크로스플레이), 자동 SyncState, 로컬 턴 잠금, ELO 동기화 및 실시간 채팅 지원.",
    "network.relay_url_label": "Relay WebSocket 서버 URL (영구 저장)",
    "network.save_url": "URL 저장",
    "network.restore_url": "초기화",
    "network.create_room_host": "온라인 방 만들기 (호스트 P1)",
    "network.test_autoreconnect": "자동 재연결 테스트",
    "network.join_code_label": "6자리 코드로 참가 (클라이언트 P2 또는 관전자)",
    "network.join_as_p2": "P2로 참가",
    "network.observe_spectator": "관전하기 (관전자)",
    "network.transport_state": "연결 상태:",
    "network.room_code_label": "방 코드:",
    "network.qr_empty_hint":
      "온라인 방을 만들면 즉시 초대용 QR 코드가 생성됩니다.",
    "toast.achievement_unlocked": "업적 달성",
    "toast.tournament_champion": "업적 달성: 토너먼트 챔피언!",
  },
  zh: {
    "app.brand": "OpenTable Web",
    "nav.active_board": "当前棋盘",
    "nav.catalog_14": "14款游戏",
    "nav.online_rooms": "在线房间",
    "nav.tournaments": "锦标赛",
    "nav.elo_ranking": "ELO天梯",
    "nav.analyzer": "复盘分析",
    "nav.restart_match": "重新开始",
    "nav.menu": "菜单",
    "nav.language_label": "语言",
    "nav.board_short": "棋盘",
    "nav.elo_short": "ELO / 分析",
    "menu.control_center": "对局选项",
    "menu.title": "工具菜单",
    "menu.close": "关闭",
    "menu.language_section": "语言",
    "menu.guide_docs": "指南",
    "menu.diagnostics_e2e": "E2E 诊断",
    "menu.tutorial_section": "教程与 AI 着法建议",
    "menu.themes_section": "主题、无障碍与音效",
    "menu.clock_section": "锦标赛棋钟",
    "menu.replay_section": "棋谱回放与 JSON",
    "sidebar.games_list": "游戏列表",
    "sidebar.view_grid": "网格视图",
    "sidebar.search_placeholder": "搜索游戏或规则...",
    "sidebar.filter_all": "全部",
    "sidebar.no_games_found": "未找到匹配的游戏：",
    "sidebar.global_elo": "全局 ELO",
    "sidebar.achievements": "成就",
    "sidebar.select_canonical_game": "选择标准桌面游戏",
    "sidebar.list_14_button": "列表 (14)",
    "sidebar.guide_short": "指南",
    "sidebar.back_to_board": "← 返回棋盘",
    "cat.classic": "经典策略",
    "cat.classic_short": "经典",
    "cat.oriental": "东方策略",
    "cat.oriental_short": "东方",
    "cat.dice_tactics": "骰子、竞速与战术",
    "cat.dice_tactics_short": "骰子 / 战术",
    "cat.cards_strategy": "卡牌、经济与征服",
    "cat.cards_strategy_short": "卡牌 / 桌游",
    "hud.turn_player": "回合：玩家",
    "hud.spectator_mode": "观战模式",
    "hud.engine_label": "引擎",
    "mode.hotseat": "本地同屏",
    "mode.ai_rust": "对战 Rust AI",
    "mode.online_relay": "在线中继 / QR",
    "mode.spectator": "观战",
    "ai.easy": "AI 简单",
    "ai.medium": "AI 中等",
    "ai.hard": "AI 困难",
    "ai.master": "AI 大师",
    "relay.active_room": "当前房间",
    "relay.host_p1": "P1 (房主)",
    "relay.client_p2": "P2 (访客)",
    "relay.no_active_room": "无活动房间（本地模式）",
    "relay.saved_url": "已保存 Relay URL",
    "replay.viewing_history": "正在查看历史步数",
    "replay.go_live_turn": "返回实时回合",
    "replay.open_menu_controls": "在菜单 ☰ 中打开控制器",
    "replay.title": "回放控制器：",
    "replay.play": "播放",
    "replay.pause": "暂停",
    "replay.move_counter": "步数",
    "replay.history_badge": "历史模式（跳至末尾或落子以创建分支）",
    "replay.save_json": "保存 JSON",
    "replay.load_json_file": "加载 JSON 文件",
    "replay.paste_view_json": "粘贴 / 查看 JSON",
    "replay.close_json_editor": "关闭 JSON 编辑器",
    "replay.apply_json": "应用 JSON 到棋盘",
    "clock.no_limit": "棋钟：无限制",
    "clock.blitz": "FIDE 超快棋 3分 + 2秒",
    "clock.rapid": "FIDE 快棋 10分 + 0秒",
    "clock.byoyomi": "读秒 5分 + 3×30秒",
    "theme.label": "主题：",
    "theme.dark_stone": "玄武暗石",
    "theme.blue_night": "深海夜蓝",
    "theme.green_jade": "帝王翡翠",
    "theme.okabe_active": "Okabe-Ito：已开启",
    "theme.okabe_enable": "Okabe-Ito 色盲友好模式",
    "theme.audio_on": "音效：开启",
    "theme.audio_off": "音效：关闭",
    "catalog.heading": "14款桌面游戏分类目录",
    "catalog.subheading":
      "选择任意游戏即可打开支持交互式教程、FIDE/读秒棋钟及 K=32 ELO 积分系统的 WASM 棋盘。",
    "catalog.search_placeholder": "按名称、分类或官方规则搜索...",
    "catalog.all_14": "全部 (14)",
    "catalog.game_singular": "款游戏",
    "catalog.game_plural": "款游戏",
    "catalog.on_active_board": "当前棋盘中",
    "catalog.play_now": "立即开始",
    "network.selected_game_banner": "当前房间或匹配所选游戏：",
    "network.change_game": "切换游戏",
    "network.view_active_board": "查看当前棋盘",
    "network.room_heading": "创建或加入在线中继房间（玩家或观战者）",
    "network.room_subheading":
      "兼容 open_table_relay（支持 Godot 与 React Web 跨平台互联），自动发送 SyncState、本地回合锁定、ELO 同步与实时聊天。",
    "network.relay_url_label": "Relay WebSocket 服务器地址（持久化保存）",
    "network.save_url": "保存地址",
    "network.restore_url": "恢复默认",
    "network.create_room_host": "创建在线房间 (房主 P1)",
    "network.test_autoreconnect": "测试自动重连",
    "network.join_code_label": "使用 6 位房间码加入（访客 P2 或观战者）",
    "network.join_as_p2": "作为 P2 加入",
    "network.observe_spectator": "观战（观战者）",
    "network.transport_state": "传输状态：",
    "network.room_code_label": "房间码：",
    "network.qr_empty_hint": "创建在线房间以立即生成邀请二维码。",
    "toast.achievement_unlocked": "成就已解锁",
    "toast.tournament_champion": "成就已解锁：锦标赛冠军！",
  },
};

export interface LocalizedGameStrings {
  title: string;
  category: string;
  blockLabel: string;
  summary: string;
}

export const GAME_CATALOG_TRANSLATIONS: Record<
  SupportedLocale,
  Record<string, LocalizedGameStrings>
> = {
  es: {
    chess: {
      title: "Ajedrez",
      category: "Estrategia Clásica",
      blockLabel: "Fase 1 · Activo en Web + WASM",
      summary:
        "Enroque, captura al paso, coronación FIDE, detección de jaque y oferta de tablas.",
    },
    checkers: {
      title: "Damas",
      category: "Estrategia Clásica",
      blockLabel: "Fase 1 · Activo en Web + WASM",
      summary:
        "Captura obligatoria, saltos múltiples encadenados y coronación de Dama.",
    },
    uno: {
      title: "UNO",
      category: "Cartas y Reacción",
      blockLabel: "Fase 1 · Activo en Web + WASM",
      summary:
        "Mazo de 108 cartas, comodines multicolor, grito ¡UNO! y penalidades acumulables.",
    },
    goose: {
      title: "El Juego de la Oca",
      category: "Dados 3D y Recorrido",
      blockLabel: "Fase 1 · Activo en Web + WASM",
      summary:
        "Espiral de 63 casillas, 13 Ocas, Puentes, Posada, Pozo, Laberinto, Calavera y Dados 3D.",
    },
    go: {
      title: "Go (Weiqi / Baduk)",
      category: "Estrategia Oriental",
      blockLabel: "Fase 2A · Activo en Web + WASM",
      summary:
        "Tableros 9×9 / 13×13 / 19×19, Ko, Superko posicional, Handicap y Komi 6.5.",
    },
    shogi: {
      title: "Shogi",
      category: "Estrategia Oriental",
      blockLabel: "Fase 2A · Activo en Web + WASM",
      summary:
        "Reingreso de piezas capturadas (Komadai), Nifu, Uchifuzume y promoción FESA.",
    },
    xiangqi: {
      title: "Xiangqi",
      category: "Estrategia Oriental",
      blockLabel: "Fase 2A · Activo en Web + WASM",
      summary:
        "Tablero 9×10 con Río, Palacios diagonales, Cañones con pantalla y General Volador.",
    },
    chinese_checkers: {
      title: "Damas Chinas",
      category: "Estrategia Oriental",
      blockLabel: "Fase 2A · Activo en Web + WASM",
      summary:
        "Estrella hexagonal de 121 casillas para 2 a 6 jugadores con saltos en cadena.",
    },
    backgammon: {
      title: "Backgammon",
      category: "Dados y Táctica",
      blockLabel: "Fase 2B · Activo en Web + WASM",
      summary:
        "24 picos, barra central, Bear-Off, tiradas dobles y cubo de doblaje (Doubling Cube).",
    },
    ludo: {
      title: "Ludo",
      category: "Dados y Carrera",
      blockLabel: "Fase 2B · Activo en Web + WASM",
      summary:
        "Circuito de 52 casillas + 5 de meta, 8 casillas seguras estrella y tirada extra.",
    },
    battleship: {
      title: "Batalla Naval",
      category: "Combate Táctico",
      blockLabel: "Fase 2B · Activo en Web + WASM",
      summary:
        "Doble cuadrícula 10×10, flota de 5 buques, ráfaga al impactar y revancha.",
    },
    mille_bornes: {
      title: "Mil Millas",
      category: "Cartas y Carrera",
      blockLabel: "Fase 2C · Activo en Web + WASM",
      summary:
        "Ruta de 1000 km, 4 cartas de seguridad (Safeties) y reacción ¡Coup Fourré!.",
    },
    monopoly: {
      title: "Monopoly",
      category: "Economía y Subastas",
      blockLabel: "Fase 2C · Activo en Web + WASM",
      summary:
        "40 casillas, Suerte/Arca, Subastas, Casas/Hoteles uniformes, Hipotecas y Trueques.",
    },
    crisis: {
      title: "Crisis / TEG",
      category: "Conquista Global",
      blockLabel: "Fase 2C · Activo en Web + WASM",
      summary:
        "30 territorios en 6 continentes, objetivos secretos, tarjetas y dados 3v3.",
    },
  },
  en: {
    chess: {
      title: "Chess",
      category: "Classic Strategy",
      blockLabel: "Phase 1 · Active on Web + WASM",
      summary:
        "Castling, en passant, FIDE promotion, check/checkmate detection, and draw offer.",
    },
    checkers: {
      title: "Checkers",
      category: "Classic Strategy",
      blockLabel: "Phase 1 · Active on Web + WASM",
      summary:
        "Mandatory capture, chained multi-jumps, and King crowning.",
    },
    uno: {
      title: "UNO",
      category: "Cards & Reaction",
      blockLabel: "Phase 1 · Active on Web + WASM",
      summary:
        "108-card deck, multicolor wilds, UNO! shout, and stackable draw penalties.",
    },
    goose: {
      title: "Game of the Goose",
      category: "3D Dice & Track",
      blockLabel: "Phase 1 · Active on Web + WASM",
      summary:
        "63-square spiral track, 13 Geese, Bridges, Inn, Well, Labyrinth, Skull, and 3D Dice.",
    },
    go: {
      title: "Go (Weiqi / Baduk)",
      category: "Eastern Strategy",
      blockLabel: "Phase 2A · Active on Web + WASM",
      summary:
        "9×9 / 13×13 / 19×19 boards, Ko, positional Superko, Handicap, and 6.5 Komi.",
    },
    shogi: {
      title: "Shogi",
      category: "Eastern Strategy",
      blockLabel: "Phase 2A · Active on Web + WASM",
      summary:
        "Captured piece drops (Komadai), Nifu, Uchifuzume, and FESA promotion.",
    },
    xiangqi: {
      title: "Xiangqi",
      category: "Eastern Strategy",
      blockLabel: "Phase 2A · Active on Web + WASM",
      summary:
        "9×10 board with River, diagonal Palaces, screen Cannons, and Flying General.",
    },
    chinese_checkers: {
      title: "Chinese Checkers",
      category: "Eastern Strategy",
      blockLabel: "Phase 2A · Active on Web + WASM",
      summary:
        "121-hole 6-pointed star board for 2 to 6 players with chained hop moves.",
    },
    backgammon: {
      title: "Backgammon",
      category: "Dice & Tactics",
      blockLabel: "Phase 2B · Active on Web + WASM",
      summary:
        "24 points, center bar, Bear-Off, doubles rolls, and Doubling Cube.",
    },
    ludo: {
      title: "Ludo",
      category: "Dice & Race",
      blockLabel: "Phase 2B · Active on Web + WASM",
      summary:
        "15×15 cross with 52 perimeter squares + home lanes, 8 safe stars, and bonus rolls.",
    },
    battleship: {
      title: "Battleship",
      category: "Tactical Combat",
      blockLabel: "Phase 2B · Active on Web + WASM",
      summary:
        "Dual 10×10 ocean grids, 5-ship fleet, hit streak salvos, and rematch.",
    },
    mille_bornes: {
      title: "Mille Bornes",
      category: "Cards & Race",
      blockLabel: "Phase 2C · Active on Web + WASM",
      summary:
        "1000 km road race, 4 Safety cards, and instant Coup Fourré! counter-play.",
    },
    monopoly: {
      title: "Monopoly",
      category: "Economy & Auctions",
      blockLabel: "Phase 2C · Active on Web + WASM",
      summary:
        "40 squares, Chance/Chest, Auctions, even Houses/Hotels, Mortgages, and Trades.",
    },
    crisis: {
      title: "Crisis / Risk",
      category: "Global Conquest",
      blockLabel: "Phase 2C · Active on Web + WASM",
      summary:
        "30 territories across 6 continents, secret objectives, cards, and 3v3 dice.",
    },
  },
  pt: {
    chess: {
      title: "Xadrez",
      category: "Estratégia Clássica",
      blockLabel: "Fase 1 · Ativo na Web + WASM",
      summary:
        "Roque curto/longo, captura en passant, promoção FIDE, detecção de xeque e empate.",
    },
    checkers: {
      title: "Damas",
      category: "Estratégia Clássica",
      blockLabel: "Fase 1 · Ativo na Web + WASM",
      summary:
        "Captura obrigatória, saltos múltiplos encadeados e coroação de Dama.",
    },
    uno: {
      title: "UNO",
      category: "Cartas e Reação",
      blockLabel: "Fase 1 · Ativo na Web + WASM",
      summary:
        "Baralho de 108 cartas, curingas multicoloridos, grito UNO! e penalidades acumuláveis.",
    },
    goose: {
      title: "Jogo do Ganso (Oca)",
      category: "Dados 3D e Percurso",
      blockLabel: "Fase 1 · Ativo na Web + WASM",
      summary:
        "Espiral de 63 casas, 13 Gansos, Pontes, Pousada, Poço, Labirinto, Caveira e Dados 3D.",
    },
    go: {
      title: "Go (Weiqi / Baduk)",
      category: "Estratégia Oriental",
      blockLabel: "Fase 2A · Ativo na Web + WASM",
      summary:
        "Tabuleiros 9×9 / 13×13 / 19×19, Ko, Superko posicional, Handicap e Komi 6.5.",
    },
    shogi: {
      title: "Shogi",
      category: "Estratégia Oriental",
      blockLabel: "Fase 2A · Ativo na Web + WASM",
      summary:
        "Reentrada de peças capturadas (Komadai), Nifu, Uchifuzume e promoção FESA.",
    },
    xiangqi: {
      title: "Xiangqi",
      category: "Estratégia Oriental",
      blockLabel: "Fase 2A · Ativo na Web + WASM",
      summary:
        "Tabuleiro 9×10 com Rio, Palácios diagonais, Canhões com barreira e General Voador.",
    },
    chinese_checkers: {
      title: "Damas Chinesas",
      category: "Estratégia Oriental",
      blockLabel: "Fase 2A · Ativo na Web + WASM",
      summary:
        "Estrela hexagonal de 121 casas para 2 a 6 jogadores com saltos em cadeia.",
    },
    backgammon: {
      title: "Gamão (Backgammon)",
      category: "Dados e Tática",
      blockLabel: "Fase 2B · Ativo na Web + WASM",
      summary:
        "24 pontas, barra central, Bear-Off, dados duplos e cubo de dobra (Doubling Cube).",
    },
    ludo: {
      title: "Ludo",
      category: "Dados e Corrida",
      blockLabel: "Fase 2B · Ativo na Web + WASM",
      summary:
        "Cruz 15×15 com 52 casas + corredor final, 8 estrelas seguras e jogada extra.",
    },
    battleship: {
      title: "Batalha Naval",
      category: "Combate Tático",
      blockLabel: "Fase 2B · Ativo na Web + WASM",
      summary:
        "Grade dupla 10×10, frota de 5 navios ilustrados, rajada ao acertar e revanche.",
    },
    mille_bornes: {
      title: "Mil Milhas (Mille Bornes)",
      category: "Cartas e Corrida",
      blockLabel: "Fase 2C · Ativo na Web + WASM",
      summary:
        "Rota de 1000 km, 4 cartas de segurança e reação instantânea Coup Fourré!.",
    },
    monopoly: {
      title: "Monopoly",
      category: "Economia e Leilões",
      blockLabel: "Fase 2C · Ativo na Web + WASM",
      summary:
        "40 casas, Sorte/Cofre, Leilões, Casas/Hotéis uniformes, Hipotecas e Trocas.",
    },
    crisis: {
      title: "Crisis / War",
      category: "Conquista Global",
      blockLabel: "Fase 2C · Ativo na Web + WASM",
      summary:
        "30 territórios em 6 continentes, objetivos secretos, cartas e dados 3v3.",
    },
  },
  it: {
    chess: {
      title: "Scacchi",
      category: "Strategia Classica",
      blockLabel: "Fase 1 · Attivo su Web + WASM",
      summary:
        "Arrocco corto/lungo, presa en passant, promozione FIDE, scacco e patta.",
    },
    checkers: {
      title: "Dama",
      category: "Strategia Classica",
      blockLabel: "Fase 1 · Attivo su Web + WASM",
      summary:
        "Presa obbligatoria, salti multipli concatenati e promozione a Dama.",
    },
    uno: {
      title: "UNO",
      category: "Carte e Reazione",
      blockLabel: "Fase 1 · Attivo su Web + WASM",
      summary:
        "Mazzo da 108 carte, jolly multicolore, grido UNO! e penalità cumulabili.",
    },
    goose: {
      title: "Il Gioco dell'Oca",
      category: "Dadi 3D e Percorso",
      blockLabel: "Fase 1 · Attivo su Web + WASM",
      summary:
        "Spirale di 63 caselle, 13 Oche, Ponti, Locanda, Pozzo, Labirinto, Teschio e Dadi 3D.",
    },
    go: {
      title: "Go (Weiqi / Baduk)",
      category: "Strategia Orientale",
      blockLabel: "Fase 2A · Attivo su Web + WASM",
      summary:
        "Tavoli 9×9 / 13×13 / 19×19, Ko, Superko posizionale, Handicap e Komi 6.5.",
    },
    shogi: {
      title: "Shogi",
      category: "Strategia Orientale",
      blockLabel: "Fase 2A · Attivo su Web + WASM",
      summary:
        "Paracadutaggio pezzi catturati (Komadai), Nifu, Uchifuzume e promozione FESA.",
    },
    xiangqi: {
      title: "Xiangqi",
      category: "Strategia Orientale",
      blockLabel: "Fase 2A · Attivo su Web + WASM",
      summary:
        "Tavolo 9×10 con Fiume, Palazzi diagonali, Cannoni con schermo e Generale Volante.",
    },
    chinese_checkers: {
      title: "Dama Cinese",
      category: "Strategia Orientale",
      blockLabel: "Fase 2A · Attivo su Web + WASM",
      summary:
        "Stella esagonale da 121 caselle per 2-6 giocatori con salti a catena.",
    },
    backgammon: {
      title: "Backgammon",
      category: "Dadi e Tattica",
      blockLabel: "Fase 2B · Attivo su Web + WASM",
      summary:
        "24 punte, barra centrale, Bear-Off, tiri doppi e cubo del raddoppio.",
    },
    ludo: {
      title: "Ludo",
      category: "Dadi e Corsa",
      blockLabel: "Fase 2B · Attivo su Web + WASM",
      summary:
        "Croce 15×15 con 52 caselle + corsie finali, 8 stelle sicure e tiro extra.",
    },
    battleship: {
      title: "Battaglia Navale",
      category: "Combattimento Tattico",
      blockLabel: "Fase 2B · Attivo su Web + WASM",
      summary:
        "Doppia griglia 10×10, flotta di 5 navi illustrate, raffica al colpo e rivincita.",
    },
    mille_bornes: {
      title: "Mille Miglia (Mille Bornes)",
      category: "Carte e Corsa",
      blockLabel: "Fase 2C · Attivo su Web + WASM",
      summary:
        "Percorso di 1000 km, 4 carte sicurezza e risposta istantanea Coup Fourré!.",
    },
    monopoly: {
      title: "Monopoly",
      category: "Economia e Aste",
      blockLabel: "Fase 2C · Attivo su Web + WASM",
      summary:
        "40 caselle, Imprevisti/Probabilità, Aste, Case/Hotel uniformi, Ipoteche e Scambi.",
    },
    crisis: {
      title: "Crisis / Risiko",
      category: "Conquista Globale",
      blockLabel: "Fase 2C · Attivo su Web + WASM",
      summary:
        "30 territori in 6 continenti, obiettivi segreti, carte e dadi 3v3.",
    },
  },
  de: {
    chess: {
      title: "Schach",
      category: "Klassische Strategie",
      blockLabel: "Phase 1 · Aktiv im Web + WASM",
      summary:
        "Kurze/lange Rochade, En Passant, FIDE-Umwandlung, Schach/Matt und Remisangebot.",
    },
    checkers: {
      title: "Dame",
      category: "Klassische Strategie",
      blockLabel: "Phase 1 · Aktiv im Web + WASM",
      summary:
        "Schlagzwang, verkettete Mehrfachsprünge und Damenumwandlung.",
    },
    uno: {
      title: "UNO",
      category: "Karten & Reaktion",
      blockLabel: "Phase 1 · Aktiv im Web + WASM",
      summary:
        "108-Karten-Deck, Farbwahlkarten, UNO!-Ruf und stapelbare Strafkarten.",
    },
    goose: {
      title: "Gänsespiel",
      category: "3D-Würfel & Laufspiel",
      blockLabel: "Phase 1 · Aktiv im Web + WASM",
      summary:
        "63-Felder-Spirale, 13 Gänse, Brücken, Herberge, Brunnen, Labyrinth, Totenkopf & 3D-Würfel.",
    },
    go: {
      title: "Go (Weiqi / Baduk)",
      category: "Östliche Strategie",
      blockLabel: "Phase 2A · Aktiv im Web + WASM",
      summary:
        "9×9 / 13×13 / 19×19 Bretter, Ko, positionelles Superko, Vorgabe und 6.5 Komi.",
    },
    shogi: {
      title: "Shogi",
      category: "Östliche Strategie",
      blockLabel: "Phase 2A · Aktiv im Web + WASM",
      summary:
        "Einsetzen geschlagener Figuren (Komadai), Nifu, Uchifuzume und FESA-Beförderung.",
    },
    xiangqi: {
      title: "Xiangqi",
      category: "Östliche Strategie",
      blockLabel: "Phase 2A · Aktiv im Web + WASM",
      summary:
        "9×10 Brett mit Fluss, diagonalen Palästen, Schirm-Kanonen und Fliegendem General.",
    },
    chinese_checkers: {
      title: "Sternhalma (Damas Chinas)",
      category: "Östliche Strategie",
      blockLabel: "Phase 2A · Aktiv im Web + WASM",
      summary:
        "Sechszackiger Stern mit 121 Feldern für 2 bis 6 Spieler mit Kettensprüngen.",
    },
    backgammon: {
      title: "Backgammon",
      category: "Würfel & Taktik",
      blockLabel: "Phase 2B · Aktiv im Web + WASM",
      summary:
        "24 Zungen, Mittelbar, Bear-Off, Pasch-Würfe und Verdopplungswürfel.",
    },
    ludo: {
      title: "Ludo (Mensch ärgere Dich nicht)",
      category: "Würfel & Rennen",
      blockLabel: "Phase 2B · Aktiv im Web + WASM",
      summary:
        "15×15 Kreuz mit 52 Feldern + Zielgerade, 8 sicheren Sternfeldern und Extrawurf.",
    },
    battleship: {
      title: "Schiffe Versenken",
      category: "Taktischer Kampf",
      blockLabel: "Phase 2B · Aktiv im Web + WASM",
      summary:
        "Doppeltes 10×10 Ozean-Raster, 5 illustrierte Schiffe, Trefferserie und Revanche.",
    },
    mille_bornes: {
      title: "1000 Kilometer (Mille Bornes)",
      category: "Karten & Rennen",
      blockLabel: "Phase 2C · Aktiv im Web + WASM",
      summary:
        "1000-km-Strecke, 4 Sicherheitskarten (Safeties) und Coup-Fourré!-Konter.",
    },
    monopoly: {
      title: "Monopoly",
      category: "Wirtschaft & Auktionen",
      blockLabel: "Phase 2C · Aktiv im Web + WASM",
      summary:
        "40 Felder, Ereignis/Gemeinschaft, Auktionen, Häuser/Hotels, Hypotheken & Handel.",
    },
    crisis: {
      title: "Crisis / Risiko",
      category: "Welteroberung",
      blockLabel: "Phase 2C · Aktiv im Web + WASM",
      summary:
        "30 Gebiete auf 6 Kontinenten, geheime Missionen, Karten und 3v3-Würfel.",
    },
  },
  ja: {
    chess: {
      title: "チェス (Chess)",
      category: "古典ストラテジー",
      blockLabel: "フェーズ1 · Web + WASM稼働中",
      summary:
        "キャスリング（短・長）、アンパッサン、FIDE昇格、王手・詰み判定、引き分け提案。",
    },
    checkers: {
      title: "チェッカー (Checkers)",
      category: "古典ストラテジー",
      blockLabel: "フェーズ1 · Web + WASM稼働中",
      summary: "強制捕獲ルール、連続マルチジャンプ、キングへの昇格。",
    },
    uno: {
      title: "UNO（ウノ）",
      category: "カード＆リアクション",
      blockLabel: "フェーズ1 · Web + WASM稼働中",
      summary:
        "108枚デッキ、マルチカラーワイルド、UNO!宣言、累積ドローペナルティ。",
    },
    goose: {
      title: "ガチョウのゲーム (Oca)",
      category: "3Dダイス＆すごろく",
      blockLabel: "フェーズ1 · Web + WASM稼働中",
      summary:
        "63マスの螺旋コース、13羽のガチョウ、橋、宿屋、井戸、迷宮、ドクロ、3Dダイス。",
    },
    go: {
      title: "囲碁 (Go / Weiqi / Baduk)",
      category: "東洋ストラテジー",
      blockLabel: "フェーズ2A · Web + WASM稼働中",
      summary:
        "9路 / 13路 / 19路盤、コウ、スーパーコウ、置き石ハンデ、コミ6.5目。",
    },
    shogi: {
      title: "将棋 (Shogi)",
      category: "東洋ストラテジー",
      blockLabel: "フェーズ2A · Web + WASM稼働中",
      summary: "持ち駒の打ち込み（駒台）、二歩・打ち歩詰め禁止、FESA成りルール。",
    },
    xiangqi: {
      title: "シャンチー（中国象棋）",
      category: "東洋ストラテジー",
      blockLabel: "フェーズ2A · Web + WASM稼働中",
      summary: "9×10盤面・楚河漢界、九宮、砲の架台ジャンプ、王不見王（飛将）。",
    },
    chinese_checkers: {
      title: "チャイニーズチェッカー（ダイヤモンド）",
      category: "東洋ストラテジー",
      blockLabel: "フェーズ2A · Web + WASM稼働中",
      summary: "121マスの六芒星ボード、2〜6人対応、連続ホップ移動。",
    },
    backgammon: {
      title: "バックギャモン (Backgammon)",
      category: "ダイス＆戦術",
      blockLabel: "フェーズ2B · Web + WASM稼働中",
      summary:
        "24ポイント、センターバー、ベアオフ、ゾロ目4回移動、ダブリングキューブ。",
    },
    ludo: {
      title: "ルド (Ludo)",
      category: "ダイス＆レース",
      blockLabel: "フェーズ2B · Web + WASM稼働中",
      summary:
        "15×15十字ボード、外周52マス＋ゴールレーン、安全星マス8箇所、ボーナスロール。",
    },
    battleship: {
      title: "バトルシップ（海戦ゲーム）",
      category: "戦術コンバット",
      blockLabel: "フェーズ2B · Web + WASM稼働中",
      summary:
        "10×10デュアル海域グリッド、艦船5隻イラスト、命中時の連続攻撃、再戦機能。",
    },
    mille_bornes: {
      title: "ミル・ボーヌ (1000マイル)",
      category: "カード＆レース",
      blockLabel: "フェーズ2C · Web + WASM稼働中",
      summary: "1000km走破レース、安全カード4種、クー・フレ（Coup Fourré!）反撃。",
    },
    monopoly: {
      title: "モノポリー (Monopoly)",
      category: "経済＆オークション",
      blockLabel: "フェーズ2C · Web + WASM稼働中",
      summary:
        "全40マス、チャンス/共同基金、競売、均等建設（家・ホテル）、抵当、交渉取引。",
    },
    crisis: {
      title: "クライシス / TEG (世界征服)",
      category: "グローバル征服",
      blockLabel: "フェーズ2C · Web + WASM稼働中",
      summary: "6大陸30地域、秘密目標、領土カード交換、3対3ダイス戦闘。",
    },
  },
  fr: {
    chess: {
      title: "Échecs",
      category: "Stratégie Classique",
      blockLabel: "Phase 1 · Actif sur Web + WASM",
      summary:
        "Petit/grand roque, prise en passant, promotion FIDE, détection d'échec et nulle.",
    },
    checkers: {
      title: "Dames",
      category: "Stratégie Classique",
      blockLabel: "Phase 1 · Actif sur Web + WASM",
      summary:
        "Prise obligatoire, rafles multiples enchaînées et promotion en Dame.",
    },
    uno: {
      title: "UNO",
      category: "Cartes et Réaction",
      blockLabel: "Phase 1 · Actif sur Web + WASM",
      summary:
        "Paquet de 108 cartes, jokers multicolores, cri UNO! et pénalités cumulables.",
    },
    goose: {
      title: "Le Jeu de l'Oie",
      category: "Dés 3D et Parcours",
      blockLabel: "Phase 1 · Actif sur Web + WASM",
      summary:
        "Spirale de 63 cases, 13 Oies, Ponts, Hôtel, Puits, Labyrinthe, Tête de mort et Dés 3D.",
    },
    go: {
      title: "Go (Weiqi / Baduk)",
      category: "Stratégie Orientale",
      blockLabel: "Phase 2A · Actif sur Web + WASM",
      summary:
        "Goban 9×9 / 13×13 / 19×19, Ko, Superko positionnel, Handicap et Komi 6.5.",
    },
    shogi: {
      title: "Shogi",
      category: "Stratégie Orientale",
      blockLabel: "Phase 2A · Actif sur Web + WASM",
      summary:
        "Parachutage des pièces capturées (Komadai), Nifu, Uchifuzume et promotion FESA.",
    },
    xiangqi: {
      title: "Xiangqi",
      category: "Stratégie Orientale",
      blockLabel: "Phase 2A · Actif sur Web + WASM",
      summary:
        "Plateau 9×10 avec Rivière, Palais diagonaux, Canons à écran et Général Volant.",
    },
    chinese_checkers: {
      title: "Dames Chinoises",
      category: "Stratégie Orientale",
      blockLabel: "Phase 2A · Actif sur Web + WASM",
      summary:
        "Étoile hexagonale de 121 cases pour 2 à 6 joueurs avec sauts en chaîne.",
    },
    backgammon: {
      title: "Backgammon",
      category: "Dés et Tactique",
      blockLabel: "Phase 2B · Actif sur Web + WASM",
      summary:
        "24 flèches, barre centrale, Bear-Off, jets doubles et videau (Doubling Cube).",
    },
    ludo: {
      title: "Ludo",
      category: "Dés et Course",
      blockLabel: "Phase 2B · Actif sur Web + WASM",
      summary:
        "Croix 15×15 avec 52 cases + colonnes finales, 8 étoiles sûres et lancer bonus.",
    },
    battleship: {
      title: "Bataille Navale",
      category: "Combat Tactique",
      blockLabel: "Phase 2B · Actif sur Web + WASM",
      summary:
        "Double grille 10×10, flotte de 5 navires illustrés, salve sur impact et revanche.",
    },
    mille_bornes: {
      title: "Mille Bornes",
      category: "Cartes et Course",
      blockLabel: "Phase 2C · Actif sur Web + WASM",
      summary:
        "Course de 1000 km, 4 bottes de sécurité et réplique instantanée Coup Fourré !",
    },
    monopoly: {
      title: "Monopoly",
      category: "Économie et Enchères",
      blockLabel: "Phase 2C · Actif sur Web + WASM",
      summary:
        "40 cases, Chance/Caisse, Enchères, Maisons/Hôtels uniformes, Hypothèques et Échanges.",
    },
    crisis: {
      title: "Crisis / Risk",
      category: "Conquête Globale",
      blockLabel: "Phase 2C · Actif sur Web + WASM",
      summary:
        "30 territoires sur 6 continents, objectifs secrets, cartes et dés 3v3.",
    },
  },
  ko: {
    chess: {
      title: "체스 (Chess)",
      category: "클래식 전략",
      blockLabel: "1단계 · Web + WASM 활성화",
      summary:
        "킹사이드/퀸사이드 캐슬링, 앙파상, FIDE 프로모션, 체크/체크메이트 및 무승부 제안.",
    },
    checkers: {
      title: "체커 (Checkers)",
      category: "클래식 전략",
      blockLabel: "1단계 · Web + WASM 활성화",
      summary: "강제 포획 규칙, 연속 다중 점프 및 킹 승급.",
    },
    uno: {
      title: "UNO (우노)",
      category: "카드 & 반응",
      blockLabel: "1단계 · Web + WASM 활성화",
      summary:
        "108장 카드 덱, 멀티컬러 와일드, UNO! 외치기 및 누적 드로우 페널티.",
    },
    goose: {
      title: "거위 게임 (Oca)",
      category: "3D 주사위 & 레이스",
      blockLabel: "1단계 · Web + WASM 활성화",
      summary:
        "63칸 나선형 트랙, 13마리 거위, 다리, 여관, 우물, 미로, 해골 및 3D 주사위.",
    },
    go: {
      title: "바둑 (Go / Weiqi / Baduk)",
      category: "동양 전략",
      blockLabel: "2A단계 · Web + WASM 활성화",
      summary:
        "9×9 / 13×13 / 19×19 바둑판, 패(Ko), 슈퍼코, 접바둑 핸디캡 및 덤 6.5집.",
    },
    shogi: {
      title: "쇼기 (일본 장기)",
      category: "동양 전략",
      blockLabel: "2A단계 · Web + WASM 활성화",
      summary: "잡은 기물 재투입(고마다이), 니후·우치후즈메 금지 및 FESA 승급 규칙.",
    },
    xiangqi: {
      title: "샹치 (중국 장기)",
      category: "동양 전략",
      blockLabel: "2A단계 · Web + WASM 활성화",
      summary: "9×10 초하한계 보드, 구궁, 포다리 점프 및 장군 대면(비장) 규칙.",
    },
    chinese_checkers: {
      title: "다이아몬드 게임 (중국 체커)",
      category: "동양 전략",
      blockLabel: "2A단계 · Web + WASM 활성화",
      summary: "121칸 육각 별 보드, 2~6인 플레이 및 연속 징검다리 점프.",
    },
    backgammon: {
      title: "백개먼 (Backgammon)",
      category: "주사위 & 전술",
      blockLabel: "2B단계 · Web + WASM 활성화",
      summary: "24개 포인트, 중앙 바, 베어오프, 더블 주사위 및 더블링 큐브.",
    },
    ludo: {
      title: "루도 (Ludo)",
      category: "주사위 & 레이스",
      blockLabel: "2B단계 · Web + WASM 활성화",
      summary:
        "15×15 십자 보드, 외곽 52칸 + 홈 레인, 안전 별 칸 8곳 및 추가 주사위 굴림.",
    },
    battleship: {
      title: "배틀쉽 (해전 게임)",
      category: "전술 전투",
      blockLabel: "2B단계 · Web + WASM 활성화",
      summary:
        "듀얼 10×10 해상 그리드, 일러스트 군함 5척, 명중 시 연속 타격 및 재대결.",
    },
    mille_bornes: {
      title: "밀 보른 (1000km 레이스)",
      category: "카드 & 레이스",
      blockLabel: "2C단계 · Web + WASM 활성화",
      summary: "1000km 도로 레이스, 안전 카드 4종 및 쿠 푸레(Coup Fourré!) 즉시 반격.",
    },
    monopoly: {
      title: "모노폴리 (Monopoly)",
      category: "경제 & 경매",
      blockLabel: "2C단계 · Web + WASM 활성화",
      summary:
        "40칸 보드, 찬스/공동자금, 경매, 균등 주택/호텔 건설, 저당 및 플레이어 거래.",
    },
    crisis: {
      title: "크라이시스 / 리스크 (세계 정복)",
      category: "글로벌 정복",
      blockLabel: "2C단계 · Web + WASM 활성화",
      summary: "6개 대륙 30개 영토, 비밀 임무, 카드 교환 및 3대3 주사위 전투.",
    },
  },
  zh: {
    chess: {
      title: "国际象棋 (Chess)",
      category: "经典策略",
      blockLabel: "第一阶段 · Web + WASM 已启用",
      summary:
        "王翼/后翼易位、吃过路兵、FIDE 升变、将军/将死检测与提和。",
    },
    checkers: {
      title: "国际跳棋 (Checkers)",
      category: "经典策略",
      blockLabel: "第一阶段 · Web + WASM 已启用",
      summary: "强制吃子规则、连续多跳吃子与王棋加冕。",
    },
    uno: {
      title: "UNO 纸牌",
      category: "卡牌与反应",
      blockLabel: "第一阶段 · Web + WASM 已启用",
      summary: "108张标准牌组、多彩万能牌、UNO! 喊话与可叠加罚抽。",
    },
    goose: {
      title: "鹅棋 (Game of the Goose)",
      category: "3D骰子与跑团",
      blockLabel: "第一阶段 · Web + WASM 已启用",
      summary:
        "63格螺旋赛道、13只幸运鹅、桥梁、客栈、水井、迷宫、骷髅与3D骰子。",
    },
    go: {
      title: "围棋 (Go / Weiqi / Baduk)",
      category: "东方策略",
      blockLabel: "第二阶段A · Web + WASM 已启用",
      summary:
        "9×9 / 13×13 / 19×19 棋盘、劫争 (Ko)、全局同形禁着、让子与贴目 6.5。",
    },
    shogi: {
      title: "将棋 (Shogi)",
      category: "东方策略",
      blockLabel: "第二阶段A · Web + WASM 已启用",
      summary: "持驹打入（驹台）、二步与打步诘禁手、FESA 升变规则。",
    },
    xiangqi: {
      title: "中国象棋 (Xiangqi)",
      category: "东方策略",
      blockLabel: "第二阶段A · Web + WASM 已启用",
      summary: "9×10 楚河汉界棋盘、九宫斜线、炮隔山打牛、蹩马腿/塞象眼与飞将。",
    },
    chinese_checkers: {
      title: "中国跳棋 (Chinese Checkers)",
      category: "东方策略",
      blockLabel: "第二阶段A · Web + WASM 已启用",
      summary: "121孔六角星棋盘，支持2至6名玩家与连续搭桥跳子。",
    },
    backgammon: {
      title: "双陆棋 (Backgammon)",
      category: "骰子与战术",
      blockLabel: "第二阶段B · Web + WASM 已启用",
      summary: "24个三角点、中央横梁、收子离盘 (Bear-Off)、双骰四步与加倍方块。",
    },
    ludo: {
      title: "飞行棋 / 卢多 (Ludo)",
      category: "骰子与竞速",
      blockLabel: "第二阶段B · Web + WASM 已启用",
      summary:
        "15×15 十字棋盘、52格环道+终点跑道、8个星形安全格与掷6奖励。",
    },
    battleship: {
      title: "海战棋 (Battleship)",
      category: "战术海战",
      blockLabel: "第二阶段B · Web + WASM 已启用",
      summary: "双10×10海域网格、5艘插画战舰、命中连击奖励与快速重赛。",
    },
    mille_bornes: {
      title: "千里马 (Mille Bornes)",
      category: "卡牌与竞速",
      blockLabel: "第二阶段C · Web + WASM 已启用",
      summary: "1000公里公路赛、4张王牌安全卡与 Coup Fourré! 瞬间反击。",
    },
    monopoly: {
      title: "大富翁 (Monopoly)",
      category: "经济与拍卖",
      blockLabel: "第二阶段C · Web + WASM 已启用",
      summary:
        "40格地产环道、机会/公益金、公开拍卖、均衡建造房屋/旅馆、抵押与交易。",
    },
    crisis: {
      title: "战地危机 / 风险 (Crisis)",
      category: "全球征服",
      blockLabel: "第二阶段C · Web + WASM 已启用",
      summary: "6大洲30个领地、秘密任务目标、卡牌兑换增援与3v3骰子攻防。",
    },
  },
};

export function getLocalizedCatalogGames(
  baseCatalog: CatalogGameEntry[],
  locale: SupportedLocale
): CatalogGameEntry[] {
  const dict = GAME_CATALOG_TRANSLATIONS[locale] || GAME_CATALOG_TRANSLATIONS.es;
  return baseCatalog.map((item) => {
    const localized = dict[item.id];
    if (!localized) return item;
    return {
      ...item,
      title: localized.title,
      category: localized.category,
      blockLabel: localized.blockLabel,
      summary: localized.summary,
    };
  });
}

export function getLocalizedCategoryGroups(
  locale: SupportedLocale
): CategoryGroupMeta[] {
  const ui = UI_DICTIONARIES[locale] || UI_DICTIONARIES.es;
  return [
    {
      id: "classic",
      label: ui["cat.classic"],
      shortLabel: ui["cat.classic_short"],
      gameIds: ["chess", "checkers"],
    },
    {
      id: "oriental",
      label: ui["cat.oriental"],
      shortLabel: ui["cat.oriental_short"],
      gameIds: ["go", "shogi", "xiangqi", "chinese_checkers"],
    },
    {
      id: "dice_tactics",
      label: ui["cat.dice_tactics"],
      shortLabel: ui["cat.dice_tactics_short"],
      gameIds: ["goose", "backgammon", "ludo", "battleship"],
    },
    {
      id: "cards_strategy",
      label: ui["cat.cards_strategy"],
      shortLabel: ui["cat.cards_strategy_short"],
      gameIds: ["uno", "mille_bornes", "monopoly", "crisis"],
    },
  ];
}

/**
 * Multi-language phrase replacement table for board & panel terms across all 14 games.
 * Ensures that board controls, status messages, and panels are translated cleanly
 * into any of the 9 active languages.
 */
const PHRASE_REPLACEMENTS: Record<
  Exclude<SupportedLocale, "es">,
  Array<[string, string]>
> = {
  en: [
    ["Turno: Jugador", "Turn: Player"],
    ["Turno del Jugador", "Player Turn"],
    ["Turno actual:", "Current Turn:"],
    ["Jugador 1", "Player 1"],
    ["Jugador 2", "Player 2"],
    ["Jugador", "Player"],
    ["¡Ganador:", "Winner:"],
    ["Ganador:", "Winner:"],
    ["¡Tablas", "Draw"],
    ["Ofrecer Tablas", "Offer Draw"],
    ["Aceptar Tablas", "Accept Draw"],
    ["Rechazar Tablas", "Decline Draw"],
    ["Rendirse", "Resign"],
    ["Enroque Corto", "Short Castling"],
    ["Enroque Largo", "Long Castling"],
    ["Enroque:", "Castling:"],
    ["Coronación:", "Promotion:"],
    ["¡JAQUE AL REY", "KING IN CHECK"],
    ["¡JAQUE MATE!", "CHECKMATE!"],
    ["Captura obligatoria activa", "Mandatory capture active"],
    ["Salto múltiple en curso", "Multi-jump in progress"],
    ["Tirar Dados", "Roll Dice"],
    ["Lanzar Dado", "Roll Die"],
    ["Lanzar Dados", "Roll Dice"],
    ["Pasar Turno", "Pass Turn"],
    ["Finalizar Turno", "End Turn"],
    ["Gritar ¡UNO!", "Shout UNO!"],
    ["Robar Carta", "Draw Card"],
    ["Mazo:", "Deck:"],
    ["Color activo:", "Active color:"],
    ["Tamaño de Tablero:", "Board Size:"],
    ["Capturas", "Captures"],
    ["Libertades", "Liberties"],
    ["Bolas en Meta", "Marbles in Goal"],
    ["Estrella Hexagonal Canónica (121 Casillas)", "Canonical 6-Pointed Star (121 Holes)"],
    ["Tablero Cruz 15×15 Canónico", "Canonical 15×15 Cross Board"],
    ["Recorrido en Espiral de 63 Casillas", "63-Square Spiral Track"],
    ["Jardín de la Oca", "Garden of the Goose"],
    ["De oca a oca y tiro porque me toca", "From goose to goose and roll again"],
    ["De puente a puente y tiro porque me lleva la corriente", "From bridge to bridge and roll again"],
    ["Radar de Ataque (Flota Enemiga)", "Attack Radar (Enemy Fleet)"],
    ["Tu Flota (5 Buques Ilustrados)", "Your Fleet (5 Illustrated Ships)"],
    ["Impactos:", "Hits:"],
    ["Hundido", "Sunk"],
    ["Intacto", "Intact"],
    ["Fuego / Impacto", "Fire / Hit"],
    ["Agua", "Water / Miss"],
    ["Portaaviones", "Carrier"],
    ["Acorazado", "Battleship"],
    ["Crucero", "Cruiser"],
    ["Submarino", "Submarine"],
    ["Destructor", "Destroyer"],
    ["Comprar Propiedad", "Buy Property"],
    ["Iniciar Subasta", "Start Auction"],
    ["Construir Casa", "Build House"],
    ["Hipotecar", "Mortgage"],
    ["Salir de la Cárcel", "Leave Jail"],
    ["Reforzar", "Reinforce"],
    ["Atacar", "Attack"],
    ["Reagrupar", "Fortify"],
    ["Canjear Tarjetas", "Trade Cards"],
    ["Objetivo Secreto:", "Secret Objective:"],
    ["Cola de Matchmaking ELO", "ELO Matchmaking Queue"],
    ["Buscar Partida Online", "Find Online Match"],
    ["Cancelar Búsqueda", "Cancel Search"],
    ["Partida Rápida vs IA Calibrada", "Quick Match vs Calibrated AI"],
    ["Chat de Sala en Tiempo Real", "Live Room Chat"],
    ["Enviar", "Send"],
    ["Organizador de Torneos", "Tournament Organizer"],
    ["Eliminación Directa", "Single Elimination"],
    ["Suizo", "Swiss System"],
    ["Nuevo Torneo", "New Tournament"],
    ["Perfil Competitivo ELO", "Competitive ELO Profile"],
    ["Analizador Post-Partida", "Post-Match Analyzer"],
    ["Diagnóstico Automático E2E", "Automated E2E Diagnostics"],
    ["Ejecutar Suite E2E", "Run E2E Suite"],
  ],
  pt: [
    ["Turno: Jugador", "Turno: Jogador"],
    ["Turno del Jugador", "Turno do Jogador"],
    ["Turno actual:", "Turno atual:"],
    ["Jugador 1", "Jogador 1"],
    ["Jugador 2", "Jogador 2"],
    ["Jugador", "Jogador"],
    ["¡Ganador:", "Vencedor:"],
    ["Ganador:", "Vencedor:"],
    ["¡Tablas", "Empate"],
    ["Ofrecer Tablas", "Oferecer Empate"],
    ["Aceptar Tablas", "Aceitar Empate"],
    ["Rechazar Tablas", "Recusar Empate"],
    ["Rendirse", "Desistir"],
    ["Enroque Corto", "Roque Curto"],
    ["Enroque Largo", "Roque Longo"],
    ["Enroque:", "Roque:"],
    ["Coronación:", "Promoção:"],
    ["¡JAQUE AL REY", "XEQUE AO REI"],
    ["¡JAQUE MATE!", "XEQUE-MATE!"],
    ["Captura obligatoria activa", "Captura obrigatória ativa"],
    ["Salto múltiple en curso", "Salto múltiplo em andamento"],
    ["Tirar Dados", "Rolar Dados"],
    ["Lanzar Dado", "Lançar Dado"],
    ["Lanzar Dados", "Lançar Dados"],
    ["Pasar Turno", "Passar Turno"],
    ["Finalizar Turno", "Finalizar Turno"],
    ["Gritar ¡UNO!", "Gritar UNO!"],
    ["Robar Carta", "Comprar Carta"],
    ["Mazo:", "Baralho:"],
    ["Color activo:", "Cor ativa:"],
    ["Tamaño de Tablero:", "Tamanho do Tabuleiro:"],
    ["Capturas", "Capturas"],
    ["Libertades", "Liberdades"],
    ["Bolas en Meta", "Peças na Meta"],
    ["Estrella Hexagonal Canónica (121 Casillas)", "Estrela Hexagonal Canônica (121 Casas)"],
    ["Tablero Cruz 15×15 Canónico", "Tabuleiro Cruz 15×15 Canônico"],
    ["Recorrido en Espiral de 63 Casillas", "Percurso em Espiral de 63 Casas"],
    ["Jardín de la Oca", "Jardim do Ganso"],
    ["Radar de Ataque (Flota Enemiga)", "Radar de Ataque (Frota Inimiga)"],
    ["Tu Flota (5 Buques Ilustrados)", "Sua Frota (5 Navios Ilustrados)"],
    ["Impactos:", "Acertos:"],
    ["Hundido", "Afundado"],
    ["Intacto", "Intacto"],
    ["Fuego / Impacto", "Fogo / Impacto"],
    ["Agua", "Água"],
    ["Portaaviones", "Porta-aviões"],
    ["Acorazado", "Encouraçado"],
    ["Crucero", "Cruzador"],
    ["Submarino", "Submarino"],
    ["Destructor", "Contratorpedeiro"],
    ["Comprar Propiedad", "Comprar Propriedade"],
    ["Iniciar Subasta", "Iniciar Leilão"],
    ["Construir Casa", "Construir Casa"],
    ["Hipotecar", "Hipotecar"],
    ["Salir de la Cárcel", "Sair da Prisão"],
    ["Reforzar", "Reforçar"],
    ["Atacar", "Atacar"],
    ["Reagrupar", "Reagrupar"],
    ["Canjear Tarjetas", "Trocar Cartas"],
    ["Objetivo Secreto:", "Objetivo Secreto:"],
    ["Cola de Matchmaking ELO", "Fila de Matchmaking ELO"],
    ["Buscar Partida Online", "Buscar Partida Online"],
    ["Cancelar Búsqueda", "Cancelar Busca"],
    ["Chat de Sala en Tiempo Real", "Chat da Sala em Tempo Real"],
    ["Enviar", "Enviar"],
    ["Organizador de Torneos", "Organizador de Torneios"],
    ["Perfil Competitivo ELO", "Perfil Competitivo ELO"],
    ["Analizador Post-Partida", "Analisador Pós-Partida"],
    ["Diagnóstico Automático E2E", "Diagnóstico Automático E2E"],
  ],
  it: [
    ["Turno: Jugador", "Turno: Giocatore"],
    ["Turno del Jugador", "Turno del Giocatore"],
    ["Turno actual:", "Turno attuale:"],
    ["Jugador 1", "Giocatore 1"],
    ["Jugador 2", "Giocatore 2"],
    ["Jugador", "Giocatore"],
    ["¡Ganador:", "Vincitore:"],
    ["Ganador:", "Vincitore:"],
    ["¡Tablas", "Patta"],
    ["Ofrecer Tablas", "Offri Patta"],
    ["Aceptar Tablas", "Accetta Patta"],
    ["Rechazar Tablas", "Rifiuta Patta"],
    ["Rendirse", "Arrenditi"],
    ["Enroque Corto", "Arrocco Corto"],
    ["Enroque Largo", "Arrocco Lungo"],
    ["Enroque:", "Arrocco:"],
    ["Coronación:", "Promozione:"],
    ["¡JAQUE AL REY", "SCACCO AL RE"],
    ["¡JAQUE MATE!", "SCACCO MATTO!"],
    ["Captura obligatoria activa", "Presa obbligatoria attiva"],
    ["Salto múltiple en curso", "Salto multiplo in corso"],
    ["Tirar Dados", "Lancia Dadi"],
    ["Lanzar Dado", "Lancia Dado"],
    ["Lanzar Dados", "Lancia Dadi"],
    ["Pasar Turno", "Passa Turno"],
    ["Finalizar Turno", "Termina Turno"],
    ["Gritar ¡UNO!", "Grida UNO!"],
    ["Robar Carta", "Pesca Carta"],
    ["Mazo:", "Mazzo:"],
    ["Color activo:", "Colore attivo:"],
    ["Tamaño de Tablero:", "Dimensione Tavolo:"],
    ["Capturas", "Catture"],
    ["Libertades", "Libertà"],
    ["Bolas en Meta", "Pedine in Meta"],
    ["Estrella Hexagonal Canónica (121 Casillas)", "Stella Esagonale Canonica (121 Caselle)"],
    ["Tablero Cruz 15×15 Canónico", "Tavolo Croce 15×15 Canonico"],
    ["Recorrido en Espiral de 63 Casillas", "Percorso a Spirale di 63 Caselle"],
    ["Jardín de la Oca", "Giardino dell'Oca"],
    ["Radar de Ataque (Flota Enemiga)", "Radar d'Attacco (Flotta Nemica)"],
    ["Tu Flota (5 Buques Ilustrados)", "La Tua Flotta (5 Navi Illustrate)"],
    ["Impactos:", "Colpi:"],
    ["Hundido", "Affondato"],
    ["Intacto", "Intatto"],
    ["Fuego / Impacto", "Fuoco / Colpito"],
    ["Agua", "Acqua"],
    ["Portaaviones", "Portaerei"],
    ["Acorazado", "Corazzata"],
    ["Crucero", "Incrociatore"],
    ["Submarino", "Sottomarino"],
    ["Destructor", "Cacciatorpediniere"],
    ["Comprar Propiedad", "Compra Proprietà"],
    ["Iniciar Subasta", "Avvia Asta"],
    ["Construir Casa", "Costruisci Casa"],
    ["Hipotecar", "Ipoteca"],
    ["Salir de la Cárcel", "Esci di Prigione"],
    ["Reforzar", "Rinforza"],
    ["Atacar", "Attacca"],
    ["Reagrupar", "Raggruppa"],
    ["Canjear Tarjetas", "Scambia Carte"],
    ["Objetivo Secreto:", "Obiettivo Segreto:"],
    ["Cola de Matchmaking ELO", "Coda Matchmaking ELO"],
    ["Buscar Partida Online", "Cerca Partita Online"],
    ["Cancelar Búsqueda", "Annulla Ricerca"],
    ["Chat de Sala en Tiempo Real", "Chat Stanza in Tempo Reale"],
    ["Enviar", "Invia"],
    ["Organizador de Torneos", "Organizzatore Tornei"],
    ["Perfil Competitivo ELO", "Profilo Competitivo ELO"],
    ["Analizador Post-Partida", "Analizzatore Post-Partita"],
    ["Diagnóstico Automático E2E", "Diagnostica Automatica E2E"],
  ],
  de: [
    ["Turno: Jugador", "Zug: Spieler"],
    ["Turno del Jugador", "Zug von Spieler"],
    ["Turno actual:", "Aktueller Zug:"],
    ["Jugador 1", "Spieler 1"],
    ["Jugador 2", "Spieler 2"],
    ["Jugador", "Spieler"],
    ["¡Ganador:", "Sieger:"],
    ["Ganador:", "Sieger:"],
    ["¡Tablas", "Remis"],
    ["Ofrecer Tablas", "Remis Anbieten"],
    ["Aceptar Tablas", "Remis Annehmen"],
    ["Rechazar Tablas", "Remis Ablehnen"],
    ["Rendirse", "Aufgeben"],
    ["Enroque Corto", "Kurze Rochade"],
    ["Enroque Largo", "Lange Rochade"],
    ["Enroque:", "Rochade:"],
    ["Coronación:", "Umwandlung:"],
    ["¡JAQUE AL REY", "SCHACH DEM KÖNIG"],
    ["¡JAQUE MATE!", "SCHACHMATT!"],
    ["Captura obligatoria activa", "Schlagzwang aktiv"],
    ["Salto múltiple en curso", "Mehrfachsprung läuft"],
    ["Tirar Dados", "Würfeln"],
    ["Lanzar Dado", "Würfeln"],
    ["Lanzar Dados", "Würfeln"],
    ["Pasar Turno", "Passen"],
    ["Finalizar Turno", "Zug Beenden"],
    ["Gritar ¡UNO!", "UNO! Rufen"],
    ["Robar Carta", "Karte Ziehen"],
    ["Mazo:", "Stapel:"],
    ["Color activo:", "Aktive Farbe:"],
    ["Tamaño de Tablero:", "Brettgröße:"],
    ["Capturas", "Gefangene"],
    ["Libertades", "Freiheiten"],
    ["Bolas en Meta", "Murmeln im Ziel"],
    ["Estrella Hexagonal Canónica (121 Casillas)", "Kanonischer Sechsstern (121 Felder)"],
    ["Tablero Cruz 15×15 Canónico", "Kanonisches 15×15 Kreuzbrett"],
    ["Recorrido en Espiral de 63 Casillas", "63-Felder-Spiralbahn"],
    ["Jardín de la Oca", "Gänsegarten"],
    ["Radar de Ataque (Flota Enemiga)", "Angriffsradar (Feindliche Flotte)"],
    ["Tu Flota (5 Buques Ilustrados)", "Deine Flotte (5 Illustrierte Schiffe)"],
    ["Impactos:", "Treffer:"],
    ["Hundido", "Versenkt"],
    ["Intacto", "Intakt"],
    ["Fuego / Impacto", "Feuer / Treffer"],
    ["Agua", "Wasser"],
    ["Portaaviones", "Flugzeugträger"],
    ["Acorazado", "Schlachtschiff"],
    ["Crucero", "Kreuzer"],
    ["Submarino", "U-Boot"],
    ["Destructor", "Zerstörer"],
    ["Comprar Propiedad", "Grundstück Kaufen"],
    ["Iniciar Subasta", "Auktion Starten"],
    ["Construir Casa", "Haus Bauen"],
    ["Hipotecar", "Hypothek"],
    ["Salir de la Cárcel", "Gefängnis Verlassen"],
    ["Reforzar", "Verstärken"],
    ["Atacar", "Angreifen"],
    ["Reagrupar", "Truppen Bewegen"],
    ["Canjear Tarjetas", "Karten Eintauschen"],
    ["Objetivo Secreto:", "Geheimziel:"],
    ["Cola de Matchmaking ELO", "ELO-Matchmaking-Warteschlange"],
    ["Buscar Partida Online", "Online-Partie Suchen"],
    ["Cancelar Búsqueda", "Suche Abbrechen"],
    ["Chat de Sala en Tiempo Real", "Live-Raumchat"],
    ["Enviar", "Senden"],
    ["Organizador de Torneos", "Turnier-Manager"],
    ["Perfil Competitivo ELO", "ELO-Wettkampfprofil"],
    ["Analizador Post-Partida", "Post-Match-Analysator"],
    ["Diagnóstico Automático E2E", "Automatische E2E-Diagnose"],
  ],
  ja: [
    ["Turno: Jugador", "手番：プレイヤー"],
    ["Turno del Jugador", "プレイヤーの手番"],
    ["Turno actual:", "現在の手番："],
    ["Jugador 1", "プレイヤー1"],
    ["Jugador 2", "プレイヤー2"],
    ["Jugador", "プレイヤー"],
    ["¡Ganador:", "勝者："],
    ["Ganador:", "勝者："],
    ["¡Tablas", "引き分け"],
    ["Ofrecer Tablas", "引き分けを提案"],
    ["Aceptar Tablas", "引き分けを承諾"],
    ["Rechazar Tablas", "引き分けを拒否"],
    ["Rendirse", "投了する"],
    ["Enroque Corto", "ショートキャスリング"],
    ["Enroque Largo", "ロングキャスリング"],
    ["Enroque:", "キャスリング："],
    ["Coronación:", "プロモーション（昇格）："],
    ["¡JAQUE AL REY", "王手（チェック）"],
    ["¡JAQUE MATE!", "チェックメイト！"],
    ["Captura obligatoria activa", "強制捕獲ルール適用中"],
    ["Salto múltiple en curso", "連続ジャンプ中"],
    ["Tirar Dados", "サイコロを振る"],
    ["Lanzar Dado", "サイコロを振る"],
    ["Lanzar Dados", "サイコロを振る"],
    ["Pasar Turno", "パスする"],
    ["Finalizar Turno", "手番を終了"],
    ["Gritar ¡UNO!", "UNO! と宣言"],
    ["Robar Carta", "カードを引く"],
    ["Mazo:", "山札："],
    ["Color activo:", "現在の色："],
    ["Tamaño de Tablero:", "盤面サイズ："],
    ["Capturas", "アゲハマ（捕獲石）"],
    ["Libertades", "ダメ（呼吸点）"],
    ["Bolas en Meta", "ゴール到達数"],
    ["Estrella Hexagonal Canónica (121 Casillas)", "公式六芒星ボード（121マス）"],
    ["Tablero Cruz 15×15 Canónico", "公式 15×15 十字ルド盤"],
    ["Recorrido en Espiral de 63 Casillas", "63マス螺旋コース"],
    ["Jardín de la Oca", "ガチョウの庭園（ゴール）"],
    ["Radar de Ataque (Flota Enemiga)", "攻撃レーダー（敵艦隊）"],
    ["Tu Flota (5 Buques Ilustrados)", "自軍艦隊（5隻の艦船）"],
    ["Impactos:", "命中数："],
    ["Hundido", "撃沈"],
    ["Intacto", "無傷"],
    ["Fuego / Impacto", "命中 / 炎上"],
    ["Agua", "水しぶき（ハズレ）"],
    ["Portaaviones", "空母"],
    ["Acorazado", "戦艦"],
    ["Crucero", "巡洋艦"],
    ["Submarino", "潜水艦"],
    ["Destructor", "駆逐艦"],
    ["Comprar Propiedad", "物件を購入"],
    ["Iniciar Subasta", "競売を開始"],
    ["Construir Casa", "家を建てる"],
    ["Hipotecar", "抵当に入れる"],
    ["Salir de la Cárcel", "刑務所から出る"],
    ["Reforzar", "兵力増援"],
    ["Atacar", "攻撃"],
    ["Reagrupar", "部隊移動"],
    ["Canjear Tarjetas", "カードを交換"],
    ["Objetivo Secreto:", "秘密目標："],
    ["Cola de Matchmaking ELO", "ELOマッチメイキング待機列"],
    ["Buscar Partida Online", "オンライン対局を検索"],
    ["Cancelar Búsqueda", "検索をキャンセル"],
    ["Chat de Sala en Tiempo Real", "リアルタイム対局チャット"],
    ["Enviar", "送信"],
    ["Organizador de Torneos", "トーナメント運営パネル"],
    ["Perfil Competitivo ELO", "ELO競技プロフィール"],
    ["Analizador Post-Partida", "対局後棋譜アナライザー"],
    ["Diagnóstico Automático E2E", "E2E自動システム診断"],
  ],
  fr: [
    ["Turno: Jugador", "Tour : Joueur"],
    ["Turno del Jugador", "Tour du Joueur"],
    ["Turno actual:", "Tour actuel :"],
    ["Jugador 1", "Joueur 1"],
    ["Jugador 2", "Joueur 2"],
    ["Jugador", "Joueur"],
    ["¡Ganador:", "Vainqueur :"],
    ["Ganador:", "Vainqueur :"],
    ["¡Tablas", "Partie Nulle"],
    ["Ofrecer Tablas", "Proposer Nulle"],
    ["Aceptar Tablas", "Accepter Nulle"],
    ["Rechazar Tablas", "Refuser Nulle"],
    ["Rendirse", "Abandonner"],
    ["Enroque Corto", "Petit Roque"],
    ["Enroque Largo", "Grand Roque"],
    ["Enroque:", "Roque :"],
    ["Coronación:", "Promotion :"],
    ["¡JAQUE AL REY", "ÉCHEC AU ROI"],
    ["¡JAQUE MATE!", "ÉCHEC ET MAT !"],
    ["Captura obligatoria activa", "Prise obligatoire active"],
    ["Salto múltiple en curso", "Rafle multiple en cours"],
    ["Tirar Dados", "Lancer les Dés"],
    ["Lanzar Dado", "Lancer le Dé"],
    ["Lanzar Dados", "Lancer les Dés"],
    ["Pasar Turno", "Passer le Tour"],
    ["Finalizar Turno", "Terminer le Tour"],
    ["Gritar ¡UNO!", "Crier UNO !"],
    ["Robar Carta", "Piocher une Carte"],
    ["Mazo:", "Pioche :"],
    ["Color activo:", "Couleur active :"],
    ["Tamaño de Tablero:", "Taille du Plateau :"],
    ["Capturas", "Captures"],
    ["Libertades", "Libertés"],
    ["Bolas en Meta", "Billes à l'Arrivée"],
    ["Estrella Hexagonal Canónica (121 Casillas)", "Étoile Hexagonale Canonique (121 Cases)"],
    ["Tablero Cruz 15×15 Canónico", "Plateau Croix 15×15 Canonique"],
    ["Recorrido en Espiral de 63 Casillas", "Parcours en Spirale de 63 Cases"],
    ["Jardín de la Oca", "Jardin de l'Oie"],
    ["Radar de Ataque (Flota Enemiga)", "Radar d'Attaque (Flotte Ennemie)"],
    ["Tu Flota (5 Buques Ilustrados)", "Votre Flotte (5 Navires Illustrés)"],
    ["Impactos:", "Impacts :"],
    ["Hundido", "Coulé"],
    ["Intacto", "Intact"],
    ["Fuego / Impacto", "Feu / Touché"],
    ["Agua", "À l'eau"],
    ["Portaaviones", "Porte-avions"],
    ["Acorazado", "Cuirassé"],
    ["Crucero", "Croiseur"],
    ["Submarino", "Sous-marin"],
    ["Destructor", "Destroyer"],
    ["Comprar Propiedad", "Acheter Propriété"],
    ["Iniciar Subasta", "Lancer Enchère"],
    ["Construir Casa", "Construire Maison"],
    ["Hipotecar", "Hypothéquer"],
    ["Salir de la Cárcel", "Sortir de Prison"],
    ["Reforzar", "Renforcer"],
    ["Atacar", "Attaquer"],
    ["Reagrupar", "Regrouper"],
    ["Canjear Tarjetas", "Échanger Cartes"],
    ["Objetivo Secreto:", "Objectif Secret :"],
    ["Cola de Matchmaking ELO", "File de Matchmaking ELO"],
    ["Buscar Partida Online", "Chercher Partie en Ligne"],
    ["Cancelar Búsqueda", "Annuler Recherche"],
    ["Chat de Sala en Tiempo Real", "Chat du Salon en Direct"],
    ["Enviar", "Envoyer"],
    ["Organizador de Torneos", "Organisateur de Tournois"],
    ["Perfil Competitivo ELO", "Profil Compétitif ELO"],
    ["Analizador Post-Partida", "Analyseur d'Après-Partie"],
    ["Diagnóstico Automático E2E", "Diagnostic Automatique E2E"],
  ],
  ko: [
    ["Turno: Jugador", "차례: 플레이어"],
    ["Turno del Jugador", "플레이어 차례"],
    ["Turno actual:", "현재 차례:"],
    ["Jugador 1", "플레이어 1"],
    ["Jugador 2", "플레이어 2"],
    ["Jugador", "플레이어"],
    ["¡Ganador:", "승자:"],
    ["Ganador:", "승자:"],
    ["¡Tablas", "무승부"],
    ["Ofrecer Tablas", "무승부 제안"],
    ["Aceptar Tablas", "무승부 수락"],
    ["Rechazar Tablas", "무승부 거절"],
    ["Rendirse", "기권하기"],
    ["Enroque Corto", "킹사이드 캐슬링"],
    ["Enroque Largo", "퀸사이드 캐슬링"],
    ["Enroque:", "캐슬링:"],
    ["Coronación:", "프로모션(승급):"],
    ["¡JAQUE AL REY", "체크 (장군)"],
    ["¡JAQUE MATE!", "체크메이트!"],
    ["Captura obligatoria activa", "강제 포획 규칙 적용 중"],
    ["Salto múltiple en curso", "연속 점프 진행 중"],
    ["Tirar Dados", "주사위 굴리기"],
    ["Lanzar Dado", "주사위 굴리기"],
    ["Lanzar Dados", "주사위 굴리기"],
    ["Pasar Turno", "턴 넘기기"],
    ["Finalizar Turno", "턴 종료"],
    ["Gritar ¡UNO!", "UNO! 외치기"],
    ["Robar Carta", "카드 뽑기"],
    ["Mazo:", "덱:"],
    ["Color activo:", "현재 색상:"],
    ["Tamaño de Tablero:", "보드 크기:"],
    ["Capturas", "사석(포획)"],
    ["Libertades", "활로"],
    ["Bolas en Meta", "목표 도착 기물"],
    ["Estrella Hexagonal Canónica (121 Casillas)", "공식 육각 별 보드 (121칸)"],
    ["Tablero Cruz 15×15 Canónico", "공식 15×15 십자 루도 보드"],
    ["Recorrido en Espiral de 63 Casillas", "63칸 나선형 트랙"],
    ["Jardín de la Oca", "거위의 정원 (골인)"],
    ["Radar de Ataque (Flota Enemiga)", "공격 레이더 (적 함대)"],
    ["Tu Flota (5 Buques Ilustrados)", "아군 함대 (군함 5척)"],
    ["Impactos:", "명중:"],
    ["Hundido", "격침"],
    ["Intacto", "정상"],
    ["Fuego / Impacto", "화염 / 명중"],
    ["Agua", "물보라 (빗나감)"],
    ["Portaaviones", "항공모함"],
    ["Acorazado", "전함"],
    ["Crucero", "순양함"],
    ["Submarino", "잠수함"],
    ["Destructor", "구축함"],
    ["Comprar Propiedad", "부지 구매"],
    ["Iniciar Subasta", "경매 시작"],
    ["Construir Casa", "주택 건설"],
    ["Hipotecar", "저당 설정"],
    ["Salir de la Cárcel", "감옥 탈출"],
    ["Reforzar", "병력 배치"],
    ["Atacar", "공격"],
    ["Reagrupar", "병력 이동"],
    ["Canjear Tarjetas", "카드 교환"],
    ["Objetivo Secreto:", "비밀 목표:"],
    ["Cola de Matchmaking ELO", "ELO 매치메이킹 대기열"],
    ["Buscar Partida Online", "온라인 대국 찾기"],
    ["Cancelar Búsqueda", "검색 취소"],
    ["Chat de Sala en Tiempo Real", "실시간 방 채팅"],
    ["Enviar", "전송"],
    ["Organizador de Torneos", "토너먼트 매니저"],
    ["Perfil Competitivo ELO", "ELO 경쟁 프로필"],
    ["Analizador Post-Partida", "대국 후 복기 분석기"],
    ["Diagnóstico Automático E2E", "자동 E2E 시스템 진단"],
  ],
  zh: [
    ["Turno: Jugador", "回合：玩家"],
    ["Turno del Jugador", "玩家回合"],
    ["Turno actual:", "当前回合："],
    ["Jugador 1", "玩家 1"],
    ["Jugador 2", "玩家 2"],
    ["Jugador", "玩家"],
    ["¡Ganador:", "获胜者："],
    ["Ganador:", "获胜者："],
    ["¡Tablas", "和棋"],
    ["Ofrecer Tablas", "提议和棋"],
    ["Aceptar Tablas", "接受和棋"],
    ["Rechazar Tablas", "拒绝和棋"],
    ["Rendirse", "认输"],
    ["Enroque Corto", "王翼短易位"],
    ["Enroque Largo", "后翼长易位"],
    ["Enroque:", "王车易位："],
    ["Coronación:", "兵升变："],
    ["¡JAQUE AL REY", "将军 (CHECK)"],
    ["¡JAQUE MATE!", "将死 (CHECKMATE)!"],
    ["Captura obligatoria activa", "强制吃子生效中"],
    ["Salto múltiple en curso", "连续跳吃进行中"],
    ["Tirar Dados", "掷骰子"],
    ["Lanzar Dado", "掷骰子"],
    ["Lanzar Dados", "掷骰子"],
    ["Pasar Turno", "跳过回合"],
    ["Finalizar Turno", "结束回合"],
    ["Gritar ¡UNO!", "喊出 UNO!"],
    ["Robar Carta", "抽牌"],
    ["Mazo:", "牌库："],
    ["Color activo:", "当前颜色："],
    ["Tamaño de Tablero:", "棋盘尺寸："],
    ["Capturas", "提子数"],
    ["Libertades", "气数"],
    ["Bolas en Meta", "到达终点棋子"],
    ["Estrella Hexagonal Canónica (121 Casillas)", "标准六角星棋盘（121孔）"],
    ["Tablero Cruz 15×15 Canónico", "标准 15×15 十字飞行棋盘"],
    ["Recorrido en Espiral de 63 Casillas", "63格螺旋赛道"],
    ["Jardín de la Oca", "鹅之花园（终点）"],
    ["Radar de Ataque (Flota Enemiga)", "攻击雷达（敌方舰队）"],
    ["Tu Flota (5 Buques Ilustrados)", "我方舰队（5艘插画战舰）"],
    ["Impactos:", "命中数："],
    ["Hundido", "已击沉"],
    ["Intacto", "完好"],
    ["Fuego / Impacto", "起火 / 命中"],
    ["Agua", "落水（未命中）"],
    ["Portaaviones", "航空母舰"],
    ["Acorazado", "战列舰"],
    ["Crucero", "巡洋舰"],
    ["Submarino", "潜艇"],
    ["Destructor", "驱逐舰"],
    ["Comprar Propiedad", "购买地产"],
    ["Iniciar Subasta", "发起拍卖"],
    ["Construir Casa", "建造房屋"],
    ["Hipotecar", "抵押地产"],
    ["Salir de la Cárcel", "出狱"],
    ["Reforzar", "部署增援"],
    ["Atacar", "发起进攻"],
    ["Reagrupar", "调动部队"],
    ["Canjear Tarjetas", "兑换卡牌"],
    ["Objetivo Secreto:", "秘密任务："],
    ["Cola de Matchmaking ELO", "ELO 匹配队列"],
    ["Buscar Partida Online", "搜索在线对局"],
    ["Cancelar Búsqueda", "取消搜索"],
    ["Chat de Sala en Tiempo Real", "房间实时聊天"],
    ["Enviar", "发送"],
    ["Organizador de Torneos", "锦标赛管理器"],
    ["Perfil Competitivo ELO", "ELO 竞技档案"],
    ["Analizador Post-Partida", "赛后复盘分析器"],
    ["Diagnóstico Automático E2E", "E2E 自动系统诊断"],
  ],
};

export function translateDynamicPhrase(
  rawText: string,
  locale: SupportedLocale
): string {
  if (!rawText || locale === "es") return rawText;
  const table = PHRASE_REPLACEMENTS[locale];
  if (!table) return rawText;
  let result = rawText;
  for (const [esFragment, localizedFragment] of table) {
    if (result.includes(esFragment)) {
      result = result.split(esFragment).join(localizedFragment);
    }
  }
  return result;
}

const originalTextNodeMap = new WeakMap<Node, string>();

/**
 * Automatically localizes any rendered text nodes and common accessibility attributes
 * inside the root container when a non-Spanish locale is selected, and cleanly restores
 * the original text when switching back or changing among the 9 languages.
 */
export function applyDomSubtreeLocalization(
  root: HTMLElement | null,
  locale: SupportedLocale
): void {
  if (!root || typeof document === "undefined") return;

  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let currentNode: Node | null = walker.nextNode();
  while (currentNode) {
    const parentTag = currentNode.parentElement?.tagName;
    if (
      parentTag !== "SCRIPT" &&
      parentTag !== "STYLE" &&
      parentTag !== "CODE"
    ) {
      const currentVal = currentNode.nodeValue || "";
      if (currentVal.trim().length > 0) {
        let baseEs = originalTextNodeMap.get(currentNode);
        if (!baseEs) {
          baseEs = currentVal;
          originalTextNodeMap.set(currentNode, baseEs);
        }
        const nextVal =
          locale === "es" ? baseEs : translateDynamicPhrase(baseEs, locale);
        if (nextVal !== currentVal) {
          currentNode.nodeValue = nextVal;
        }
      }
    }
    currentNode = walker.nextNode();
  }
}

export interface I18nContextValue {
  locale: SupportedLocale;
  setLocale: (next: SupportedLocale) => void;
  t: (key: UiTranslationKey) => string;
  tr: (rawText: string) => string;
  locales: LocaleMeta[];
}

const I18nContext = createContext<I18nContextValue>({
  locale: "es",
  setLocale: () => {},
  t: (key) => UI_DICTIONARIES.es[key] || key,
  tr: (rawText) => rawText,
  locales: SUPPORTED_LOCALES,
});

export const I18nProvider: React.FC<{
  initialLocale?: SupportedLocale;
  children: React.ReactNode;
}> = ({ initialLocale, children }) => {
  const [locale, setLocaleState] = useState<SupportedLocale>(() =>
    initialLocale ? initialLocale : detectInitialLocale()
  );

  const setLocale = (next: SupportedLocale) => {
    if (!isSupportedLocale(next)) return;
    saveLocalePreference(next);
    setLocaleState(next);
  };

  useEffect(() => {
    saveLocalePreference(locale);
  }, [locale]);

  const value = useMemo<I18nContextValue>(() => {
    const dict = UI_DICTIONARIES[locale] || UI_DICTIONARIES.es;
    return {
      locale,
      setLocale,
      t: (key: UiTranslationKey) =>
        dict[key] ?? UI_DICTIONARIES.es[key] ?? key,
      tr: (rawText: string) => translateDynamicPhrase(rawText, locale),
      locales: SUPPORTED_LOCALES,
    };
  }, [locale]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
};

export function useI18n(): I18nContextValue {
  return useContext(I18nContext);
}
