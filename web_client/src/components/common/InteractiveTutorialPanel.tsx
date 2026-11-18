import React, { useState } from "react";
import { BookOpen, Sparkles, X } from "lucide-react";

export interface GameTutorialSpec {
  id: string;
  title: string;
  objective: string;
  steps: string[];
  tournamentRules: string;
  buildRecommendedCommand: (currentTurn: 1 | 2, legalMovesJson: string) => string | null;
}

export const TUTORIALS_14_GAMES: Record<string, GameTutorialSpec> = {
  chess: {
    id: "chess",
    title: "Tutorial de Ajedrez FIDE",
    objective: "Dar jaque mate al Rey rival o acordar tablas reglamentarias.",
    steps: [
      "1. Controla el centro del tablero avanzando tus peones centrales (e2-e4 o d2-d4).",
      "2. Desarrolla caballos y alfiles antes de mover la Dama y pon a salvo a tu Rey.",
      "3. Al llegar a la última fila, elige entre Dama, Torre, Alfil o Caballo en el selector FIDE.",
    ],
    tournamentRules: "Promoción FIDE a 4 piezas, detección de jaque y oferta/aceptación de tablas.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as { from: [number, number]; to: [number, number] }[];
      if (!moves.length) return null;
      return JSON.stringify({
        command_type: "chess_game::MovePieceCommand",
        player: turn,
        from: moves[0].from,
        to: moves[0].to,
      });
    },
  },
  checkers: {
    id: "checkers",
    title: "Tutorial de Damas Clásicas",
    objective: "Capturar todas las fichas del oponente o bloquear sus movimientos.",
    steps: [
      "1. Avanza en diagonal por las casillas oscuras hacia el lado opuesto.",
      "2. Si existe una captura diagonal disponible, la regla de captura obligatoria se activa automáticamente.",
      "3. Al alcanzar la fila de coronación, tu ficha se convierte en Dama (♛) y puede mover hacia adelante y atrás.",
    ],
    tournamentRules: "Captura obligatoria, saltos múltiples encadenados y coronación de Dama.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as { from: [number, number]; to: [number, number] }[];
      if (!moves.length) return null;
      return JSON.stringify({
        command_type: "checkers_game::MovePieceCommand",
        player: turn,
        from: moves[0].from,
        to: moves[0].to,
      });
    },
  },
  uno: {
    id: "uno",
    title: "Tutorial de UNO",
    objective: "Ser el primero en quedarse sin cartas en la mano.",
    steps: [
      "1. Juega una carta que coincida en color o valor con la cima del descarte, o usa un Comodín.",
      "2. Si hay penalidad activa (+2 o +4), apila otra carta de robo o roba la penalidad acumulada.",
      "3. Pulsa el botón ¡UNO! cuando te queden 1 o 2 cartas para protegerte de sanciones.",
    ],
    tournamentRules: "Mazo de 108 cartas, selector de color en comodines y grito ¡UNO!.",
    buildRecommendedCommand: (turn, legalJson) => {
      const playable = JSON.parse(legalJson) as { index: number }[];
      if (playable.length > 0) {
        return JSON.stringify({
          command_type: "PlayCardCommand",
          player: turn,
          card_index: playable[0].index,
          chosen_color: "Red",
        });
      }
      return JSON.stringify({ command_type: "DrawCardCommand", player: turn });
    },
  },
  goose: {
    id: "goose",
    title: "Tutorial de El Juego de la Oca",
    objective: "Llegar con tirada exacta al Jardín de la Oca (casilla 63).",
    steps: [
      "1. Lanza los dos dados 3D para avanzar por la espiral de 63 casillas.",
      "2. Si caes en una Oca (5, 9, 14, 18, 23, 27...) o Puente (6, 12), saltas y vuelves a tirar.",
      "3. Evita el Pozo (31), el Laberinto (42), la Cárcel (52) y la Calavera (58). Si superas 63, rebotas.",
    ],
    tournamentRules: "13 Ocas, Puentes, Posada, Pozo, Laberinto, Cárcel, Calavera y rebote exacto.",
    buildRecommendedCommand: (turn) =>
      JSON.stringify({
        command_type: "goose_game::RollDiceCommand",
        player: turn,
        d1: 3,
        d2: 3,
      }),
  },
  go: {
    id: "go",
    title: "Tutorial de Go (Weiqi / Baduk)",
    objective: "Controlar más intersecciones y capturas que el rival al final de la partida.",
    steps: [
      "1. Coloca piedras en las intersecciones vacías priorizando los puntos estrella (Hoshi).",
      "2. Rodea por completo las libertades ortogonales de las cadenas rivales para capturarlas.",
      "3. Tras 2 pases consecutivos, marca las piedras muertas (✕) y confirma el conteo con Komi 6.5.",
    ],
    tournamentRules: "Handicap en puntos Hoshi, regla de Ko, marcado de piedras muertas y Komi 6.5.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as { row: number; col: number }[];
      if (!moves.length) return null;
      return JSON.stringify({
        command_type: "go_game::PlaceStoneCommand",
        player: turn,
        row: moves[0].row,
        col: moves[0].col,
      });
    },
  },
  shogi: {
    id: "shogi",
    title: "Tutorial de Shogi",
    objective: "Capturar al Rey rival reutilizando las piezas capturadas desde tu Komadai.",
    steps: [
      "1. Avanza tu línea de peones para abrir la diagonal del Alfil (角) y la columna de la Torre (飛).",
      "2. Las piezas capturadas van a tu bandeja Komadai y pueden reingresarse en cualquier casilla vacía.",
      "3. Al entrar en las 3 últimas filas enemigas, promociona tus piezas según el reglamento FESA.",
    ],
    tournamentRules: "Reingreso desde Komadai, prohibición de doble peón (Nifu) y promoción FESA.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as {
        from: [number, number];
        to: [number, number];
        canPromote: boolean;
      }[];
      if (!moves.length) return null;
      return JSON.stringify({
        command_type: "shogi_game::MovePieceCommand",
        player: turn,
        from: moves[0].from,
        to: moves[0].to,
        promote: moves[0].canPromote,
      });
    },
  },
  xiangqi: {
    id: "xiangqi",
    title: "Tutorial de Xiangqi (Ajedrez Chino)",
    objective: "Capturar o dar mate al General enemigo dentro de su Palacio 3×3.",
    steps: [
      "1. Despliega tus Carros (車) y Caballos (馬) cuidando que los Caballos no tengan su paso bloqueado.",
      "2. Usa tus Cañones (炮) saltando sobre una pieza pantalla para capturar a distancia.",
      "3. Recuerda que los dos Generales nunca pueden mirarse directamente en una columna abierta.",
    ],
    tournamentRules: "Río Chu He / Han Jie, Palacios 3×3, Cañón con pantalla y General Volador.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as { from: [number, number]; to: [number, number] }[];
      if (!moves.length) return null;
      return JSON.stringify({
        command_type: "xiangqi_game::MovePieceCommand",
        player: turn,
        from: moves[0].from,
        to: moves[0].to,
      });
    },
  },
  chinese_checkers: {
    id: "chinese_checkers",
    title: "Tutorial de Damas Chinas",
    objective: "Llevar todas tus canicas al triángulo opuesto de la estrella hexagonal.",
    steps: [
      "1. Selecciona una canica de tu color y muévela a una casilla vacía adyacente.",
      "2. Construye escaleras de canicas para encadenar saltos largos de un extremo a otro.",
      "3. Las canicas nunca son capturadas; utiliza tanto tus piezas como las del rival como puente.",
    ],
    tournamentRules: "Estrella hexagonal con saltos múltiples en cadena.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as { fromId: string; toId: string }[];
      if (!moves.length) return null;
      return JSON.stringify({
        command_type: "chinese_checkers_game::MoveMarbleCommand",
        player: turn,
        fromId: moves[0].fromId,
        toId: moves[0].toId,
      });
    },
  },
  backgammon: {
    id: "backgammon",
    title: "Tutorial de Backgammon",
    objective: "Llevar tus 15 fichas a tu cuadrante interior y retirarlas (Bear-Off).",
    steps: [
      "1. Lanza los dados 3D y avanza tus fichas por los 24 picos.",
      "2. Golpea fichas solitarias rivales (Blots) para enviarlas a la Barra Central.",
      "3. Si tienes ventaja posicional, ofrece doblar la apuesta con el Cubo de Doblaje (×2, ×4, ×8).",
    ],
    tournamentRules: "24 picos, Barra Central, Bear-Off y Cubo de Doblaje.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as { from: number; to: number }[];
      if (!moves.length) return null;
      return JSON.stringify({
        command_type: "backgammon_game::MoveCheckerCommand",
        player: turn,
        from: moves[0].from,
        to: moves[0].to,
      });
    },
  },
  ludo: {
    id: "ludo",
    title: "Tutorial de Ludo",
    objective: "Completar el circuito de 57 pasos con tus 4 fichas hasta la meta central.",
    steps: [
      "1. Elige cuál de tus 4 fichas deseas mover y lanza los dados 3D.",
      "2. Las 8 casillas con estrella (★) son refugios seguros donde tus fichas no pueden ser capturadas.",
      "3. Sacar un 6 o coronar una ficha en la meta te otorga una tirada adicional inmediata.",
    ],
    tournamentRules: "52 casillas + 5 de pasillo de meta, 8 estrellas seguras y tirada extra con 6.",
    buildRecommendedCommand: (turn) =>
      JSON.stringify({
        command_type: "ludo_game::MoveTokenCommand",
        player: turn,
        token_index: 0,
        d1: 6,
        d2: 2,
      }),
  },
  battleship: {
    id: "battleship",
    title: "Tutorial de Batalla Naval",
    objective: "Hundir los 5 buques de la flota enemiga (17 impactos en total).",
    steps: [
      "1. Haz clic en cualquier coordenada del radar enemigo 10×10 para disparar un torpedo.",
      "2. Al lograr un impacto (💥), explora las casillas ortogonales adyacentes para hundir el buque.",
      "3. Activa la Regla de Ráfaga si deseas conservar el turno tras cada impacto.",
    ],
    tournamentRules: "Flota de 5 buques (5, 4, 3, 3, 2), regla de ráfaga opcional y revancha.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as { row: number; col: number }[];
      if (!moves.length) return null;
      return JSON.stringify({
        command_type: "battleship_game::FireShotCommand",
        player: turn,
        row: moves[0].row,
        col: moves[0].col,
      });
    },
  },
  mille_bornes: {
    id: "mille_bornes",
    title: "Tutorial de Mil Millas (Mille Bornes)",
    objective: "Alcanzar exactamente 1000 km en tu odómetro antes que tu rival.",
    steps: [
      "1. Juega cartas de Distancia (50, 75, 100, 200 km) mientras tengas Vía Libre.",
      "2. Despliega los 4 Escudos (Prioridad, Cisterna, Impinchable, As del Volante) para inmunizarte.",
      "3. Usa el botón ⚡ ¡Coup Fourré! ante un ataque para sumar +100 km de bonificación y turno extra.",
    ],
    tournamentRules: "Ruta de 1000 km, 4 cartas de seguridad (Safeties) y reacción ¡Coup Fourré!.",
    buildRecommendedCommand: (turn) =>
      JSON.stringify({
        command_type: "mille_bornes_game::PlayCardCommand",
        player: turn,
        card_index: 0,
      }),
  },
  monopoly: {
    id: "monopoly",
    title: "Tutorial de Monopoly",
    objective: "Construir monopolios inmobiliarios y multiplicar tu capital mediante alquileres.",
    steps: [
      "1. Lanza los dados 3D para recorrer las 40 casillas del tablero y cobrar $200 al pasar por GO.",
      "2. Compra las propiedades libres en las que caigas y edifica casas/hoteles de forma uniforme.",
      "3. Si necesitas liquidez inmediata, hipoteca propiedades seleccionándolas en el tablero.",
    ],
    tournamentRules: "40 casillas, compra de propiedades, construcción de casas/hoteles e hipotecas.",
    buildRecommendedCommand: (turn) =>
      JSON.stringify({
        command_type: "monopoly_game::RollDiceCommand",
        player: turn,
        d1: 3,
        d2: 4,
      }),
  },
  crisis: {
    id: "crisis",
    title: "Tutorial de Crisis / TEG",
    objective: "Conquistar territorios a través de los 6 continentes y dominar el mapa global.",
    steps: [
      "1. En la Fase de Refuerzo (PlaceArmies), haz clic en tus territorios para desplegar ejércitos.",
      "2. En la Fase de Ataque, selecciona un territorio propio con 2+ ejércitos y ataca uno enemigo.",
      "3. Al reunir 3 tarjetas de territorio conquistado, canjéalas por +6 ejércitos adicionales.",
    ],
    tournamentRules: "30 territorios en 6 continentes, refuerzos, combate 3v3 y canje de tarjetas.",
    buildRecommendedCommand: (turn, legalJson) => {
      const moves = JSON.parse(legalJson) as Record<string, unknown>[];
      if (moves.length > 0) {
        return JSON.stringify(moves[0]);
      }
      return JSON.stringify({
        command_type: "crisis_game::EndTurnCommand",
        player: turn,
      });
    },
  },
};

interface InteractiveTutorialPanelProps {
  gameId: string;
  currentTurn: 1 | 2;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  onDispatchCommand: (cmdJson: string) => void;
  defaultOpen?: boolean;
  hideToggleButton?: boolean;
  onClose?: () => void;
}

export const InteractiveTutorialPanel: React.FC<InteractiveTutorialPanelProps> = ({
  gameId,
  currentTurn,
  legalMovesJson,
  isLocalTurnAllowed,
  onDispatchCommand,
  defaultOpen = false,
  hideToggleButton = false,
  onClose,
}) => {
  const [isOpen, setIsOpen] = useState<boolean>(defaultOpen);
  const spec = TUTORIALS_14_GAMES[gameId] || TUTORIALS_14_GAMES.chess;

  const handleApplySuggestion = () => {
    if (!isLocalTurnAllowed) return;
    const cmd = spec.buildRecommendedCommand(currentTurn, legalMovesJson);
    if (cmd) {
      onDispatchCommand(cmd);
    }
  };

  const effectiveOpen = hideToggleButton ? true : isOpen;

  return (
    <div className="flex flex-col gap-2">
      {!hideToggleButton && (
        <button
          type="button"
          onClick={() => setIsOpen(!isOpen)}
          className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-slate-900 hover:bg-slate-800 border border-slate-800 text-xs font-semibold text-amber-300 transition-colors cursor-pointer"
        >
          <BookOpen className="w-3.5 h-3.5" />
          <span>{isOpen ? "Ocultar Tutorial Interactivo" : "Tutorial y Jugada Sugerida"}</span>
        </button>
      )}

      {effectiveOpen && (
        <div className="p-5 rounded-2xl bg-slate-900/95 border border-amber-500/40 shadow-xl flex flex-col gap-4">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="text-xs font-mono text-amber-400">
                GUÍA INTERACTIVA (14/14 JUEGOS CANÓNICOS)
              </div>
              <h3 className="text-base font-bold text-white mt-0.5">{spec.title}</h3>
              <p className="text-xs text-slate-300 mt-1">
                <strong>Objetivo:</strong> {spec.objective}
              </p>
            </div>
            <button
              type="button"
              onClick={() => {
                if (onClose) {
                  onClose();
                } else {
                  setIsOpen(false);
                }
              }}
              className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            {spec.steps.map((step, i) => (
              <div
                key={i}
                className="p-3 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 leading-relaxed"
              >
                {step}
              </div>
            ))}
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-3 border-t border-slate-800">
            <span className="text-xs text-slate-400">
              <strong>Reglas de Torneo:</strong> {spec.tournamentRules}
            </span>

            <button
              type="button"
              disabled={!isLocalTurnAllowed}
              onClick={handleApplySuggestion}
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-amber-500 hover:bg-amber-400 disabled:opacity-40 text-slate-950 text-xs font-bold shadow cursor-pointer shrink-0"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>Ejecutar Jugada Sugerida por Tutor WASM</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
