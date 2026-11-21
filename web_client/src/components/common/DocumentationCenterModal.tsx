import React, { useMemo, useState } from "react";
import {
  BookOpen,
  Code2,
  Copy,
  Gamepad2,
  Globe,
  Package,
  Search,
  Terminal,
  X,
} from "lucide-react";
import { useI18n } from "../../i18n";
import {
  DOC_MODAL_UI_BY_LOCALE,
  getLocalizedDocumentationSections,
} from "../../i18n/tutorialsAndDocsI18n";
import {
  CrateLayerId,
  CRATES_EXPLORER_UI_BY_LOCALE,
  CRATES_IO_CATALOG_24,
  getCrateHighlightsForLocale,
  NATIVE_DOC_LANGUAGES,
  TRUSTED_PUBLISHING_OIDC_CONFIG,
} from "../../i18n/cratesIoCatalogI18n";

export type DocCategory = "usage" | "games" | "developer" | "crates";

export interface DocumentationSection {
  id: string;
  category: Exclude<DocCategory, "crates">;
  title: string;
  subtitle: string;
  tags: string[];
  paragraphs: string[];
  bulletPoints?: string[];
  codeSnippet?: {
    label: string;
    code: string;
  };
}

export const DOCUMENTATION_SECTIONS: DocumentationSection[] = [
  // =========================================================================
  // 1. MANUAL DE USO (JUGADORES Y ORGANIZADORES)
  // =========================================================================
  {
    id: "usage-quickstart",
    category: "usage",
    title: "01. Inicio Rápido y Modos de Partida",
    subtitle: "Hotseat Local, vs IA Rust (4 niveles), Salas Online Relay y Espectador",
    tags: ["inicio", "modos", "hotseat", "ia", "relay", "espectador", "qr"],
    paragraphs: [
      "La aplicación Web de OpenTable permite jugar cualquiera de los 14 juegos de mesa canónicos directamente en el navegador sin configuración adicional.",
      "Desde la barra superior del área de trabajo puedes alternar en cualquier momento entre los 14 juegos y elegir uno de los 4 modos de operación:"
    ],
    bulletPoints: [
      "Hotseat Local (2 Jugadores): Ambos jugadores comparten el dispositivo alternando turnos en el mismo tablero.",
      "vs IA Rust (4 Niveles): Juega como Jugador 1 contra el motor de IA determinista con dificultades Fácil (1000 ELO), Media (1200 ELO), Difícil (1450 ELO) y Maestra (1700 ELO), más factor de aleatoriedad configurable 0-100%.",
      "Online Relay / QR: Crea una sala de 6 caracteres con código QR instantáneo o únete como Jugador 2 desde otro navegador o cliente Godot.",
      "Modo Espectador: Observa partidas en curso en tiempo real con el tablero en modo de solo lectura y acceso al chat de sala."
    ]
  },
  {
    id: "usage-matchmaking-elo",
    category: "usage",
    title: "02. Cola de Matchmaking Automático por Rango ELO",
    subtitle: "Emparejamiento competitivo en open_table_relay con expansión progresiva",
    tags: ["matchmaking", "cola", "elo", "online", "rango", "relay"],
    paragraphs: [
      "En la pestaña 'Salas Online', el panel de Cola de Matchmaking Automático te empareja con otro jugador que busque el mismo juego dentro de una ventana de ELO compatible.",
      "El servidor Relay verifica la condición simétrica |ELO_A - ELO_B| <= min(delta_A, delta_B) para garantizar partidas equilibradas."
    ],
    bulletPoints: [
      "Selecciona la tolerancia inicial: ±100 ELO (Estricto), ±200 ELO (Estándar) o ±400 ELO (Amplio).",
      "Si no hay un rival inmediato, la ventana se expande automáticamente cada 10 segundos (±100 -> ±200 -> ±400).",
      "En cualquier momento puedes pulsar 'Jugar vs IA Calibrada Ahora' para iniciar al instante contra un nivel de IA ajustado a tu ELO actual."
    ]
  },
  {
    id: "usage-tournaments-elo",
    category: "usage",
    title: "03. Organizador de Torneos y Ranking ELO K=32",
    subtitle: "Ligas Round-Robin (Tablas de Berger), Eliminatoria Directa y 7 Logros",
    tags: ["torneos", "berger", "round-robin", "knockout", "elo", "logros", "fide"],
    paragraphs: [
      "La pestaña 'Torneos' permite organizar competiciones de 2 a 8 participantes combinando jugadores humanos y bots de IA en cualquiera de los 14 juegos.",
      "La pestaña 'Ranking ELO' mantiene tu perfil competitivo persistente con la fórmula oficial FIDE K=32, estadísticas por juego y 7 logros desbloqueables."
    ],
    bulletPoints: [
      "Liga Round-Robin (Sistema Berger): Todos contra todos con puntuación 1.0 por victoria, 0.5 por tablas y desempate Sonneborn-Berger.",
      "Eliminatoria Directa (Knockout): Cuadro de cuartos, semifinales y final con avance automático del ganador.",
      "Lanzamiento directo al tablero: Pulsa 'Jugar en Tablero' en cualquier cruce pendiente para disputarlo en vivo; al terminar la partida el resultado se registra automáticamente en el torneo y en tu perfil ELO."
    ]
  },
  {
    id: "usage-analyzer-replay",
    category: "usage",
    title: "04. Analizador Post-Partida, Mapa de Calor IA y Visor de Repeticiones",
    subtitle: "Gráfico SVG de ventaja [-100, +100], Mapa de Calor Top-K y clasificación de jugadas",
    tags: ["analizador", "post-partida", "ventaja", "replay", "json", "errores", "heatmap"],
    paragraphs: [
      "La pestaña 'Analizador' reconstruye paso a paso cualquier partida terminada o en curso para los 14 juegos, calcula la curva de ventaja posicional y renderiza el Mapa de Calor de Intensidad de Decisión IA (conmutable entre Turno Seleccionado y Partida Acumulada).",
      "Además, la barra inferior de Replay en el tablero principal permite usar Undo/Redo transaccional, verificar el checksum determinista FNV-1a de 64 bits y exportar o importar registros JSON."
    ],
    bulletPoints: [
      "★ Óptima (ganancia neta >= +5 puntos) y ✓ Buena (pérdida <= 4 puntos).",
      "? Imprecisión (caída de 4 a 14 puntos) y ?? Error Crítico / Blunder (caída >= 15 puntos).",
      "Haz clic en cualquier punto de la curva SVG o fila de la tabla para inspeccionar el estado exacto y el Mapa de Calor Top-K."
    ]
  },
  {
    id: "usage-accessibility-pwa",
    category: "usage",
    title: "05. Relojes de Torneo, Accesibilidad Okabe-Ito, Audio y PWA",
    subtitle: "Personalización visual, síntesis Web Audio API y juego 100% offline",
    tags: ["reloj", "byo-yomi", "fide", "temas", "okabe-ito", "daltonismo", "audio", "pwa", "offline"],
    paragraphs: [
      "La barra de herramientas incluye controles de tiempo oficiales (Blitz 3+2, Rápido 10+0 y Byo-yomi japonés para Go/Shogi), 3 temas ambientales y soporte completo de accesibilidad."
    ],
    bulletPoints: [
      "Temas Visuales: Piedra Oscura (por defecto), Noche Profunda y Mesa Jade.",
      "Modo Daltónico Okabe-Ito: Sustituye paletas rojo/verde ambiguas por azul (#0072B2) y naranja (#D55E00) de alto contraste.",
      "Audio Procedural: Efectos sintetizados por Web Audio API (movimiento, dados, cartas, victoria y alerta de reloj) sin archivos MP3 externos.",
      "Instalación PWA: Pulsa 'Instalar App' en la cabecera para instalar OpenTable en escritorio o móvil y jugar sin conexión a internet."
    ]
  },

  // =========================================================================
  // 2. GUÍA DE REGLAS Y CONTROLES DE LOS 14 JUEGOS
  // =========================================================================
  {
    id: "games-classic-oriental",
    category: "games",
    title: "Juegos 01–07: Estrategia Clásica y Oriental",
    subtitle: "Ajedrez, Damas, Go, Shogi, Xiangqi y Damas Chinas",
    tags: ["chess", "ajedrez", "checkers", "damas", "go", "shogi", "xiangqi", "chinese_checkers"],
    paragraphs: [
      "Todos los tableros de cuadrícula e intersección resaltan automáticamente las casillas de destino legales al seleccionar una pieza propia o una pieza de la mano (Komadai en Shogi)."
    ],
    bulletPoints: [
      "01. Ajedrez (chess_game): Haz clic en una pieza y luego en la casilla de destino resaltada. Incluye enroque, captura al paso y selector de pieza al coronar en la última fila.",
      "02. Damas (checkers_game): Captura obligatoria y coronación a Dama. Las diagonales válidas se iluminan al seleccionar la ficha.",
      "03. Go (go_game): Haz clic en cualquier intersección libre para colocar piedra (con validación de suicidio y Ko) o usa el botón 'Pasar Turno' (2 pases consecutivos finalizan con conteo Komi 6.5).",
      "04. Shogi (shogi_game): Tablero 9×9 con banco de piezas capturadas (Komadai). Puedes mover en el tablero (con opción de promoción) o seleccionar una pieza capturada para reingresarla (Drop).",
      "05. Xiangqi (xiangqi_game): Tablero 9×10 con Río central, Palacios diagonales, salto de Cañón con pantalla y prohibición de General Volador.",
      "06. Damas Chinas (chinese_checkers_game): Estrella hexagonal de 121 posiciones con pasos adyacentes y saltos múltiples en cadena hasta el triángulo opuesto."
    ]
  },
  {
    id: "games-dice-cards-tactical",
    category: "games",
    title: "Juegos 08–14: Dados, Cartas, Combate y Estrategia Global",
    subtitle: "UNO, Oca, Backgammon, Ludo, Batalla Naval, Mil Millas, Monopoly y Crisis/TEG",
    tags: ["uno", "goose", "oca", "backgammon", "ludo", "battleship", "mille_bornes", "monopoly", "crisis", "teg"],
    paragraphs: [
      "Los juegos con dados, cartas o fases tácticas exponen botones contextuales claros para cada etapa del turno (tirar dados, elegir ficha/carta, construir o atacar)."
    ],
    bulletPoints: [
      "07. UNO (uno_game): Haz clic en una carta compatible por color/símbolo o en un comodín (eligiendo el nuevo color), pulsa '¡UNO!' al quedar con 1 carta o roba del mazo.",
      "08. El Juego de la Oca (goose_game): Pulsa 'Lanzar Dado' para avanzar por la espiral de 63 casillas con saltos automáticos de Oca en Oca, Puentes, Posada, Pozo, Laberinto y Calavera.",
      "09. Backgammon (backgammon_game): Lanza los 2 dados y selecciona entre las jugadas legales de tus picos, reingreso desde la barra o Bear-Off final, más el Cubo de Doblaje.",
      "10. Ludo (ludo_game): Lanza el dado (un 6 saca ficha de base y otorga turno extra) y haz clic en la ficha que deseas avanzar por el circuito de 52 casillas.",
      "11. Batalla Naval (battleship_game): Fase 1 de despliegue de los 5 buques (o despliegue táctico rápido) y Fase 2 de disparo por coordenadas sobre el radar enemigo 10×10.",
      "12. Mil Millas (mille_bornes_game): Juega cartas de distancia (25–200 km), ataques, defensas o las 4 seguridades (Safeties con ¡Coup Fourré!) hasta alcanzar 1000 km.",
      "13. Monopoly (monopoly_game): Lanza los dados, compra propiedades libres o inicia subasta, construye casas/hoteles de forma uniforme y gestiona hipotecas hasta la bancarrota rival.",
      "14. Crisis / TEG (crisis_game): Tres fases por turno sobre 30 territorios en 6 continentes: Refuerzo de ejércitos, Ataque con dados 3v3 y Reagrupación fronteriza."
    ]
  },

  // =========================================================================
  // 3. GUÍA DE DESARROLLO WEB (REACT + TYPESCRIPT + WEBASSEMBLY)
  // =========================================================================
  {
    id: "dev-verify-guarantee",
    category: "developer",
    title: "Pilar 1. Cómo Garantizar y Auditar que la Aplicación Está 100% Funcional",
    subtitle: "Script de verificación CLI, suites Vitest y Panel de Autodiagnóstico en vivo",
    tags: ["verificacion", "tests", "vitest", "diagnostico", "ci", "funcional", "e2e"],
    paragraphs: [
      "Para garantizar en cualquier momento que el cliente Web React + WASM funciona al 100%, dispones de dos mecanismos complementarios: el Panel de Diagnóstico en la propia interfaz (pestaña 'Diagnóstico') y el script automatizado de terminal.",
      "El script de verificación ejecuta el chequeo estático de TypeScript, las suites de pruebas en Vitest (cubriendo los 14 juegos, los 24 crates documentados y la internacionalización), el build de producción de Vite y la auditoría de documentación."
    ],
    bulletPoints: [
      "Verificación en un solo comando desde la raíz del SDK: bash tools/verify_web_client.sh",
      "Ejecución directa de las suites de regresión: npm --prefix web_client test",
      "Verificación programática en código: importa runFullSystemDiagnostics() desde src/components/common/SystemDiagnosticsPanel.tsx."
    ],
    codeSnippet: {
      label: "Comandos de Verificación Funcional Completa (Terminal / CI)",
      code: `# 1. Ejecutar el gate completo de garantía funcional Web (TypeScript + Vitest + Build PWA + Docs)
bash games_tables_sdk/tools/verify_web_client.sh

# 2. Ejecutar únicamente las suites de pruebas en Vitest (14 juegos + Fases 1-5 + Autodiagnóstico)
npm --prefix games_tables_sdk/web_client test

# 3. Compilar el crate Rust open_table_wasm hacia WebAssembly (wasm32-unknown-unknown)
bash games_tables_sdk/tools/build_wasm.sh`
    }
  },
  {
    id: "dev-architecture-wasm",
    category: "developer",
    title: "Pilar 2. Arquitectura React + Puente Rust WASM y Fallback Isomórfico TS",
    subtitle: "Contrato unificado entre open_table_wasm (Rust) y WasmGameBridge (TypeScript)",
    tags: ["arquitectura", "wasm", "rust", "bridge", "fallback", "json", "estado"],
    paragraphs: [
      "El cliente Web desacopla completamente la capa visual React de la lógica de reglas mediante la clase WasmGameBridge (src/wasm_pkg/index.ts), que implementa exactamente la misma interfaz que el crate Rust open_table_wasm/src/lib.rs expuesto con #[wasm_bindgen].",
      "Cuando el binario open_table_wasm_bg.wasm está compilado en public/wasm/, el puente delega en Rust; en entornos de desarrollo rápido o pruebas Node/Vitest sin binario WASM cargado, el motor isomórfico determinista en TypeScript responde con el mismo contrato JSON."
    ],
    bulletPoints: [
      "start_local_match(game_type, p1, p2) / start_ai_match(game_type, human_id, ai_id, difficulty): Inicializa la sesión limpia.",
      "get_state_json() y get_state_checksum_hex(): Devuelve el snapshot JSON canónico y la firma FNV-1a de 64 bits.",
      "get_legal_moves_json(player_id): Devuelve el array JSON de comandos legales para iluminar destinos en la UI.",
      "send_command_json(player_id, cmd_json), undo_step() y redo_step(): Ejecuta comandos con historial transaccional.",
      "set_ai_randomness_pct(pct) y get_last_ai_telemetry_json(): Controla el ruido Top-K (0-100%) e inspecciona los candidatos evaluados por la IA.",
      "export_log_json() / apply_sync_log_json(game_type, log_json): Serializa y reconstruye partidas completas para Replay, Analizador y sincronización Relay."
    ],
    codeSnippet: {
      label: "Contrato de WasmGameBridge en React / TypeScript",
      code: `import { WasmGameBridge } from "./wasm_pkg";

const bridge = new WasmGameBridge();
bridge.start_ai_match("chess", 1, 2, 1); // Humano J1 vs IA Media J2 (25% ruido por defecto)

// 1. Obtener estado, checksum FNV-1a y jugadas legales
const state = JSON.parse(bridge.get_state_json());
const checksum = bridge.get_state_checksum_hex();
const legalMoves = JSON.parse(bridge.get_legal_moves_json(1));

// 2. Despachar una jugada legal del Jugador 1
bridge.send_command_json(1, JSON.stringify(legalMoves[0]));

// 3. Ejecutar respuesta automática de la IA (Jugador 2)
bridge.step_ai_if_needed();`
    }
  },
  {
    id: "dev-svg-boards-extension",
    category: "developer",
    title: "Pilar 3. Guía para Crear o Extender Tableros SVG y Motores de Juego",
    subtitle: "Patrón estándar de componentes en src/components/boards/<Game>Board.tsx",
    tags: ["tableros", "svg", "react", "componentes", "extender", "nuevo-juego"],
    paragraphs: [
      "Cada uno de los 14 juegos cuenta con un componente dedicado en src/components/boards/<Game>Board.tsx que recibe props inmutables desde App.tsx: stateJson, legalMovesJson, isLocalTurnAllowed, localPlayerId y onDispatchCommand.",
      "Los tableros no mutan el estado localmente: calculan los destinos válidos a partir de legalMovesJson y al hacer clic invocan onDispatchCommand(JSON.stringify(command))."
    ],
    bulletPoints: [
      "Paso 1: Define el estado inicial, generador de jugadas legales, reductor de comandos e IA en open_table_wasm y en src/wasm_pkg/index.ts.",
      "Paso 2: Crea src/components/boards/MiJuegoBoard.tsx renderizando un SVG responsivo con atributos data-testid y aria-label accesibles.",
      "Paso 3: Registra el juego en CATALOG_14_GAMES dentro de src/App.tsx y añade su evaluador posicional en evaluateBoardAdvantageForPlayer1 (PostMatchAnalyzerPanel.tsx).",
      "Paso 4: Añade su prueba de regresión en src/__tests__/ para que SystemDiagnosticsPanel y Vitest lo auditen automáticamente."
    ],
    codeSnippet: {
      label: "Plantilla de Componente de Tablero React + SVG",
      code: `export interface GameBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

export const CustomGameBoard: React.FC<GameBoardProps> = ({
  stateJson,
  legalMovesJson,
  isLocalTurnAllowed,
  onDispatchCommand,
}) => {
  const state = JSON.parse(stateJson);
  const legalMoves = JSON.parse(legalMovesJson);

  return (
    <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
      {/* Renderizado SVG determinista + disparo de comandos */}
      <button
        disabled={!isLocalTurnAllowed || legalMoves.length === 0}
        onClick={() => onDispatchCommand(JSON.stringify(legalMoves[0]))}
      >
        Ejecutar Jugada Legal
      </button>
    </div>
  );
};`
    }
  },
  {
    id: "dev-relay-protocol-pwa",
    category: "developer",
    title: "Pilar 4. Protocolo WebSocket Relay, Matchmaking ELO y Despliegue PWA",
    subtitle: "Interoperabilidad con open_table_relay y pipeline CI/CD hacia GitHub Pages",
    tags: ["relay", "websocket", "protocolo", "matchmaking", "pwa", "github-pages", "ci"],
    paragraphs: [
      "El cliente RelayWebSocketClient (src/bridge/relayClient.ts) se comunica con el servidor Rust open_table_relay mediante tramas JSON tipadas y soporta sincronización entre pestañas locales via BroadcastChannel cuando se opera sin servidor externo.",
      "El workflow .github/workflows/docs.yml compila automáticamente open_table_wasm, empaqueta la PWA con Vite y la despliega en la raíz de GitHub Pages junto con mdBook en /docs."
    ],
    bulletPoints: [
      "Crear / Unirse / Observar sala: { action: 'create' }, { action: 'join', code: 'AB12CD' }, { action: 'spectate', code: 'AB12CD' }.",
      "Cola Matchmaking con filtro ELO: { action: 'queue', game_type: 'chess', elo: 1240, max_elo_delta: 200 } -> responde { event: 'queued' } o { event: 'matched', code, player_id }.",
      "Retransmisión de jugadas, estado y chat: { action: 'relay', payload } con sobres tipados command, sync_state, elo_sync y chat."
    ],
    codeSnippet: {
      label: "Mensajes JSON del Protocolo open_table_relay",
      code: `// 1. Solicitud de Matchmaking con rango ELO al servidor Rust open_table_relay
{"action":"queue","game_type":"chess","elo":1320,"max_elo_delta":200}

// 2. Respuesta del servidor cuando encuentra rival compatible
{"event":"matched","code":"R9K4M2","player_id":2}

// 3. Sobre de comando de juego retransmitido a la sala
{"action":"relay","payload":"{\\"kind\\":\\"command\\",\\"playerId\\":1,\\"cmdJson\\":\\"...\\"}"}`
    }
  }
];

interface DocumentationCenterModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialCategory?: DocCategory;
}

export const DocumentationCenterModal: React.FC<
  DocumentationCenterModalProps
> = ({ isOpen, onClose, initialCategory = "usage" }) => {
  const { locale, setLocale } = useI18n();
  const ui = DOC_MODAL_UI_BY_LOCALE[locale];
  const cratesUi = CRATES_EXPLORER_UI_BY_LOCALE[locale];

  const [activeCategory, setActiveCategory] =
    useState<DocCategory>(initialCategory);
  const [activeCrateLayer, setActiveCrateLayer] =
    useState<CrateLayerId>("all");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const localizedSections = useMemo(
    () => getLocalizedDocumentationSections(locale, DOCUMENTATION_SECTIONS),
    [locale]
  );

  const filteredSections = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return localizedSections.filter((sec) => {
      if (!q && sec.category !== activeCategory) return false;
      if (!q) return true;
      const haystack = [
        sec.title,
        sec.subtitle,
        ...sec.tags,
        ...sec.paragraphs,
        ...(sec.bulletPoints || []),
        sec.codeSnippet?.code || "",
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [activeCategory, searchQuery, localizedSections]);

  const filteredCrates = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return CRATES_IO_CATALOG_24.filter((crate) => {
      if (activeCrateLayer !== "all" && crate.layer !== activeCrateLayer) {
        return false;
      }
      if (!q) return true;
      const localizedSummary =
        crate.summaryByLocale[locale] || crate.summaryByLocale.en;
      const highlights = getCrateHighlightsForLocale(crate, locale);
      const haystack = [
        crate.name,
        crate.layer,
        localizedSummary,
        ...highlights,
        ...crate.exports,
        crate.codeExample,
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [activeCrateLayer, searchQuery, locale]);

  if (!isOpen) return null;

  const handleCopySnippet = (id: string, code: string) => {
    if (typeof navigator !== "undefined" && navigator.clipboard) {
      navigator.clipboard.writeText(code).catch(() => {});
    }
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const activeNativeDocMeta =
    NATIVE_DOC_LANGUAGES.find((l) => l.locale === locale) ||
    NATIVE_DOC_LANGUAGES[0];

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={ui.dialogAriaLabel}
      className="fixed inset-0 z-50 bg-slate-950/85 backdrop-blur-xs flex items-center justify-center p-4 sm:p-6"
    >
      <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-6xl w-full max-h-[92vh] flex flex-col overflow-hidden shadow-2xl">
        {/* Top Modal Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between gap-4">
          <div>
            <div className="text-xs text-slate-400">
              {ui.headerKicker} · {activeNativeDocMeta.hubPath}
            </div>
            <h2 className="text-lg font-bold text-white font-display">
              {ui.headerTitle}
            </h2>
          </div>

          <button
            type="button"
            onClick={onClose}
            aria-label={ui.closeAriaLabel}
            className="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* 7-Language Native Documentation Switcher Bar */}
        <div
          data-testid="doc-modal-language-bar"
          className="px-6 py-2.5 bg-slate-950/90 border-b border-slate-800 flex flex-wrap items-center justify-between gap-3"
        >
          <div className="flex items-center gap-2 text-xs text-slate-400">
            <Globe className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
            <span className="font-medium text-slate-300">
              {cratesUi.languageBarLabel}
            </span>
          </div>

          <div className="flex flex-wrap items-center gap-1 p-1 bg-slate-900 border border-slate-800 rounded-lg">
            {NATIVE_DOC_LANGUAGES.map((lang) => {
              const isSelected = locale === lang.locale;
              return (
                <button
                  key={lang.locale}
                  type="button"
                  data-testid={`doc-lang-btn-${lang.locale}`}
                  onClick={() => setLocale(lang.locale)}
                  className={`px-2.5 py-1 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                    isSelected
                      ? "bg-emerald-600 text-white"
                      : "text-slate-300 hover:text-white hover:bg-slate-800"
                  }`}
                >
                  {lang.codeLabel} · {lang.nativeLabel}
                </button>
              );
            })}
          </div>
        </div>

        {/* Category Tabs + Search Input */}
        <div className="px-6 py-3.5 bg-slate-950/60 border-b border-slate-800 flex flex-col lg:flex-row lg:items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-1.5 p-1 bg-slate-900 border border-slate-800 rounded-lg">
            <button
              type="button"
              data-testid="doc-tab-usage"
              onClick={() => {
                setActiveCategory("usage");
                setSearchQuery("");
              }}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                activeCategory === "usage" && !searchQuery
                  ? "bg-emerald-600 text-white"
                  : "text-slate-300 hover:text-white"
              }`}
            >
              <BookOpen className="w-3.5 h-3.5" />
              <span>{ui.tabUsage}</span>
            </button>

            <button
              type="button"
              data-testid="doc-tab-games"
              onClick={() => {
                setActiveCategory("games");
                setSearchQuery("");
              }}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                activeCategory === "games" && !searchQuery
                  ? "bg-emerald-600 text-white"
                  : "text-slate-300 hover:text-white"
              }`}
            >
              <Gamepad2 className="w-3.5 h-3.5" />
              <span>{ui.tabGames}</span>
            </button>

            <button
              type="button"
              data-testid="doc-tab-developer"
              onClick={() => {
                setActiveCategory("developer");
                setSearchQuery("");
              }}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                activeCategory === "developer" && !searchQuery
                  ? "bg-emerald-600 text-white"
                  : "text-slate-300 hover:text-white"
              }`}
            >
              <Code2 className="w-3.5 h-3.5" />
              <span>{ui.tabDeveloper}</span>
            </button>

            <button
              type="button"
              data-testid="doc-tab-crates"
              onClick={() => {
                setActiveCategory("crates");
                setSearchQuery("");
              }}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                activeCategory === "crates"
                  ? "bg-emerald-600 text-white"
                  : "text-slate-300 hover:text-white"
              }`}
            >
              <Package className="w-3.5 h-3.5" />
              <span>{cratesUi.tabCratesIo}</span>
            </button>
          </div>

          <div className="relative flex-1 max-w-xs">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              data-testid="doc-modal-search-input"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={ui.searchPlaceholder}
              className="w-full pl-8 pr-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-xs text-white placeholder:text-slate-500"
            />
          </div>
        </div>

        {/* Scrollable Content Body */}
        <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-5">
          {activeCategory === "crates" ? (
            <>
              {/* Crates.io & 7-Language Hub Header Banner */}
              <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 flex flex-col gap-3">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div>
                    <div className="text-xs text-slate-400">
                      {cratesUi.categoryBadgeCrates} · 24/24 Crates · v1.1.0
                    </div>
                    <h3 className="text-base font-bold text-white font-display mt-0.5">
                      {cratesUi.i18nHubBannerTitle}
                    </h3>
                  </div>
                  <div className="text-xs font-mono tabular-nums text-slate-400">
                    {filteredCrates.length} / 24 crates
                  </div>
                </div>
                <p className="text-xs text-slate-300 leading-relaxed max-w-4xl">
                  {cratesUi.i18nHubBannerDesc}
                </p>

                {/* Architectural Layer Segmented Filter */}
                <div className="flex flex-wrap items-center gap-1.5 pt-1">
                  {(
                    [
                      { id: "all", label: cratesUi.filterAll },
                      { id: "core-engine", label: cratesUi.filterCore },
                      { id: "transports-relay", label: cratesUi.filterTransports },
                      { id: "runtime-bridges", label: cratesUi.filterBridges },
                      { id: "canonical-games", label: cratesUi.filterGames },
                    ] as Array<{ id: CrateLayerId; label: string }>
                  ).map((layerFilter) => (
                    <button
                      key={layerFilter.id}
                      type="button"
                      data-testid={`crate-layer-filter-${layerFilter.id}`}
                      onClick={() => setActiveCrateLayer(layerFilter.id)}
                      className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        activeCrateLayer === layerFilter.id
                          ? "bg-emerald-600 text-white"
                          : "bg-slate-900 border border-slate-800 text-slate-300 hover:text-white"
                      }`}
                    >
                      {layerFilter.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Crates.io Trusted Publishing (OIDC) & 4-Tier Topological Pipeline Card */}
              <div
                data-testid="trusted-publishing-oidc-card"
                className="p-4 rounded-xl bg-slate-950 border border-slate-800 flex flex-col gap-3"
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div>
                    <div className="text-xs text-slate-400 font-mono">
                      OIDC Trusted Publishing · {TRUSTED_PUBLISHING_OIDC_CONFIG.authAction} · TTL {TRUSTED_PUBLISHING_OIDC_CONFIG.tokenTtlMinutes}m
                    </div>
                    <h4 className="text-sm font-bold text-white font-display mt-0.5">
                      Crates.io Trusted Publishing ({TRUSTED_PUBLISHING_OIDC_CONFIG.publishableCratesCount} Crates · {TRUSTED_PUBLISHING_OIDC_CONFIG.workflowFilename} · Environment: {TRUSTED_PUBLISHING_OIDC_CONFIG.environment})
                    </h4>
                  </div>

                  <button
                    type="button"
                    data-testid="copy-oidc-workflow-btn"
                    onClick={() =>
                      handleCopySnippet(
                        "oidc-workflow-yaml",
                        TRUSTED_PUBLISHING_OIDC_CONFIG.workflowYamlSnippet
                      )
                    }
                    className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-slate-900 border border-slate-800 hover:bg-slate-800 text-xs text-slate-300 hover:text-white transition-colors cursor-pointer self-start sm:self-auto"
                  >
                    <Copy className="w-3 h-3" />
                    <span>
                      {copiedId === "oidc-workflow-yaml"
                        ? cratesUi.copiedLabel
                        : cratesUi.copyRustBtn}
                    </span>
                  </button>
                </div>

                <div className="text-xs text-slate-300 font-mono tabular-nums">
                  <span>Owner: {TRUSTED_PUBLISHING_OIDC_CONFIG.repositoryOwner}</span>
                  <span aria-hidden="true"> · </span>
                  <span>Repo: {TRUSTED_PUBLISHING_OIDC_CONFIG.repositoryName}</span>
                  <span aria-hidden="true"> · </span>
                  <span>Workflow: .github/workflows/{TRUSTED_PUBLISHING_OIDC_CONFIG.workflowFilename}</span>
                  <span aria-hidden="true"> · </span>
                  <span>Environment: {TRUSTED_PUBLISHING_OIDC_CONFIG.environment}</span>
                  <span aria-hidden="true"> · </span>
                  <span>Script: {TRUSTED_PUBLISHING_OIDC_CONFIG.scriptPath}</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2.5">
                  {TRUSTED_PUBLISHING_OIDC_CONFIG.topologicalTiers.map((t) => (
                    <div
                      key={t.tier}
                      className="p-2.5 rounded-lg bg-slate-900/70 border border-slate-800 flex flex-col gap-1"
                    >
                      <div className="text-xs font-semibold text-emerald-400">
                        {t.label}
                      </div>
                      <div className="text-[11px] text-slate-300 font-mono leading-relaxed">
                        {t.crates.join(", ")}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Crates List */}
              {filteredCrates.length === 0 ? (
                <div className="p-8 rounded-xl bg-slate-950 border border-slate-800 text-center flex flex-col items-center gap-3">
                  <p className="text-xs text-slate-400">
                    {ui.emptySearchPrefix} "{searchQuery}".
                  </p>
                  <button
                    type="button"
                    onClick={() => {
                      setActiveCrateLayer("all");
                      setSearchQuery("");
                    }}
                    className="px-3.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-xs text-white font-medium cursor-pointer"
                  >
                    {cratesUi.resetFilterBtn}
                  </button>
                </div>
              ) : (
                <div className="grid grid-cols-1 gap-4">
                  {filteredCrates.map((crate) => {
                    const summary =
                      crate.summaryByLocale[locale] || crate.summaryByLocale.en;
                    const highlights = getCrateHighlightsForLocale(
                      crate,
                      locale
                    );
                    const cargoCopyId = `cargo-${crate.name}`;
                    const rustCopyId = `rust-${crate.name}`;

                    return (
                      <article
                        key={crate.name}
                        data-testid={`crate-doc-card-${crate.name}`}
                        className="p-5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col gap-3"
                      >
                        <div className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-2">
                          <div>
                            {/* Zero-Pill Unboxed Metadata Line */}
                            <div className="text-xs text-slate-400 font-mono tabular-nums">
                              <span>v{crate.version}</span>
                              <span aria-hidden="true"> · </span>
                              <span>{crate.license}</span>
                              <span aria-hidden="true"> · </span>
                              <span>Edition {crate.edition}</span>
                              <span aria-hidden="true"> · </span>
                              <span>rustc {crate.rustVersion}</span>
                              <span aria-hidden="true"> · </span>
                              <span>{crate.readmePath}</span>
                            </div>
                            <h4 className="text-base font-bold text-white font-mono mt-0.5">
                              {crate.name}
                            </h4>
                          </div>

                          <div className="flex items-center gap-3 text-xs text-slate-400 font-mono">
                            <span>crates.io/crates/{crate.name}</span>
                            <span aria-hidden="true">·</span>
                            <span>docs.rs/{crate.name}</span>
                          </div>
                        </div>

                        <p className="text-xs text-slate-300 leading-relaxed max-w-4xl">
                          {summary}
                        </p>

                        <ul className="list-disc list-inside flex flex-col gap-1 text-xs text-slate-300 pl-1">
                          {highlights.map((hl, idx) => (
                            <li key={idx} className="leading-relaxed">
                              {hl}
                            </li>
                          ))}
                        </ul>

                        {/* Unboxed Exported Public Rust API Symbols */}
                        <div className="text-xs text-slate-400">
                          <span className="font-semibold text-slate-300">
                            {cratesUi.exportsLabel}{" "}
                          </span>
                          <span className="font-mono text-emerald-300">
                            {crate.exports.join(" · ")}
                          </span>
                        </div>

                        {/* Cargo.toml + Rust Code Blocks */}
                        <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 pt-1">
                          <div className="rounded-xl overflow-hidden border border-slate-800 bg-slate-900 flex flex-col">
                            <div className="px-3 py-1.5 bg-slate-900 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300">
                              <span className="font-medium">
                                {cratesUi.cargoTomlLabel}
                              </span>
                              <button
                                type="button"
                                onClick={() =>
                                  handleCopySnippet(
                                    cargoCopyId,
                                    crate.cargoToml
                                  )
                                }
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs cursor-pointer"
                              >
                                <Copy className="w-3 h-3" />
                                <span>
                                  {copiedId === cargoCopyId
                                    ? cratesUi.copiedLabel
                                    : cratesUi.copyCargoBtn}
                                </span>
                              </button>
                            </div>
                            <pre className="p-3 text-xs font-mono text-emerald-300 overflow-x-auto leading-relaxed">
                              <code>{crate.cargoToml}</code>
                            </pre>
                          </div>

                          <div className="lg:col-span-2 rounded-xl overflow-hidden border border-slate-800 bg-slate-900 flex flex-col">
                            <div className="px-3 py-1.5 bg-slate-900 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300">
                              <span className="inline-flex items-center gap-1.5 font-medium">
                                <Terminal className="w-3.5 h-3.5 text-emerald-400" />
                                <span>{cratesUi.rustExampleLabel}</span>
                              </span>
                              <button
                                type="button"
                                onClick={() =>
                                  handleCopySnippet(
                                    rustCopyId,
                                    crate.codeExample
                                  )
                                }
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs cursor-pointer"
                              >
                                <Copy className="w-3 h-3" />
                                <span>
                                  {copiedId === rustCopyId
                                    ? cratesUi.copiedLabel
                                    : cratesUi.copyRustBtn}
                                </span>
                              </button>
                            </div>
                            <pre className="p-3 text-xs font-mono text-emerald-300 overflow-x-auto leading-relaxed">
                              <code>{crate.codeExample}</code>
                            </pre>
                          </div>
                        </div>
                      </article>
                    );
                  })}
                </div>
              )}
            </>
          ) : filteredSections.length === 0 ? (
            <div className="p-8 rounded-xl bg-slate-950 border border-slate-800 text-center text-xs text-slate-400">
              {ui.emptySearchPrefix} "{searchQuery}". {ui.emptySearchSuffix}
            </div>
          ) : (
            filteredSections.map((sec) => (
              <article
                key={sec.id}
                className="p-5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col gap-3"
              >
                <div>
                  <div className="text-xs text-slate-400">
                    {sec.category === "usage"
                      ? ui.categoryBadgeUsage
                      : sec.category === "games"
                      ? ui.categoryBadgeGames
                      : ui.categoryBadgeDeveloper}{" "}
                    · {sec.subtitle}
                  </div>
                  <h3 className="text-base font-bold text-white font-display mt-0.5">
                    {sec.title}
                  </h3>
                </div>

                {sec.paragraphs.map((p, i) => (
                  <p
                    key={i}
                    className="text-xs text-slate-300 leading-relaxed max-w-4xl"
                  >
                    {p}
                  </p>
                ))}

                {sec.bulletPoints && sec.bulletPoints.length > 0 && (
                  <ul className="list-disc list-inside flex flex-col gap-1.5 text-xs text-slate-300 pl-1">
                    {sec.bulletPoints.map((bp, i) => (
                      <li key={i} className="leading-relaxed">
                        {bp}
                      </li>
                    ))}
                  </ul>
                )}

                {sec.codeSnippet && (
                  <div className="mt-2 rounded-xl overflow-hidden border border-slate-800 bg-slate-900">
                    <div className="px-3.5 py-2 bg-slate-900 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300">
                      <span className="inline-flex items-center gap-1.5 font-medium">
                        <Terminal className="w-3.5 h-3.5 text-emerald-400" />
                        <span>{sec.codeSnippet.label}</span>
                      </span>
                      <button
                        type="button"
                        onClick={() =>
                          handleCopySnippet(sec.id, sec.codeSnippet!.code)
                        }
                        className="inline-flex items-center gap-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs cursor-pointer"
                      >
                        <Copy className="w-3 h-3" />
                        <span>
                          {copiedId === sec.id ? ui.copiedBtn : ui.copyBtn}
                        </span>
                      </button>
                    </div>
                    <pre className="p-3.5 text-xs font-mono text-emerald-300 overflow-x-auto leading-relaxed">
                      <code>{sec.codeSnippet.code}</code>
                    </pre>
                  </div>
                )}
              </article>
            ))
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-3.5 border-t border-slate-800 bg-slate-950/60 flex items-center justify-between text-xs text-slate-400">
          <span>
            {ui.footerSyncText} · {activeNativeDocMeta.hubPath}
          </span>
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-white font-semibold cursor-pointer"
          >
            {ui.closeBtn}
          </button>
        </div>
      </div>
    </div>
  );
};
