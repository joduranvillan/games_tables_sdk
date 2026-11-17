import React from "react";
import { Eye, Palette, Volume2, VolumeX } from "lucide-react";

export type VisualThemeId = "piedra_oscura" | "noche_azul" | "jade_verde";

export interface ThemeAndAudioConfig {
  themeId: VisualThemeId;
  okabeIto: boolean;
  soundEnabled: boolean;
  soundVolume: number; // 0.0 to 1.0
}

export const THEME_CONFIG_STORAGE_KEY = "opentable.theme_config";

export const VISUAL_THEMES: Record<
  VisualThemeId,
  {
    id: VisualThemeId;
    label: string;
    description: string;
    rootBgClass: string;
    headerBgClass: string;
    cardBgClass: string;
    accentBtnClass: string;
    hexPrimary: string;
  }
> = {
  piedra_oscura: {
    id: "piedra_oscura",
    label: "Piedra Oscura",
    description: "Pizarra basáltica profunda con acentos esmeralda de torneo",
    rootBgClass: "bg-slate-950 text-slate-100",
    headerBgClass: "bg-slate-950/95 border-slate-800",
    cardBgClass: "bg-slate-900 border-slate-800",
    accentBtnClass: "bg-emerald-600 hover:bg-emerald-500 text-white",
    hexPrimary: "#0b0f19",
  },
  noche_azul: {
    id: "noche_azul",
    label: "Noche Azul",
    description: "Terciopelo marino nocturno con contraste zafiro",
    rootBgClass: "bg-[#071324] text-slate-100",
    headerBgClass: "bg-[#071324]/95 border-sky-900/60",
    cardBgClass: "bg-[#0c1e38] border-sky-900/60",
    accentBtnClass: "bg-sky-600 hover:bg-sky-500 text-white",
    hexPrimary: "#071324",
  },
  jade_verde: {
    id: "jade_verde",
    label: "Jade Verde",
    description: "Paño imperial de salón clásico con bordes en madera oscura",
    rootBgClass: "bg-[#061f18] text-slate-100",
    headerBgClass: "bg-[#061f18]/95 border-emerald-900/60",
    cardBgClass: "bg-[#0b2e24] border-emerald-900/60",
    accentBtnClass: "bg-amber-600 hover:bg-amber-500 text-white",
    hexPrimary: "#061f18",
  },
};

export interface OkabeItoPalette {
  player1Hex: string;
  player2Hex: string;
  player3Hex: string;
  player4Hex: string;
  highlightHex: string;
  dangerHex: string;
  player1BadgeClass: string;
  player2BadgeClass: string;
}

export function getOkabeItoPalette(enabled: boolean): OkabeItoPalette {
  if (enabled) {
    return {
      player1Hex: "#0072B2", // Okabe-Ito Blue
      player2Hex: "#D55E00", // Okabe-Ito Vermilion
      player3Hex: "#E69F00", // Okabe-Ito Orange/Amber
      player4Hex: "#CC79A7", // Okabe-Ito Reddish Purple
      highlightHex: "#56B4E9", // Okabe-Ito Sky Blue
      dangerHex: "#D55E00",
      player1BadgeClass: "bg-[#0072B2] text-white",
      player2BadgeClass: "bg-[#D55E00] text-white",
    };
  }
  return {
    player1Hex: "#10B981",
    player2Hex: "#0284C7",
    player3Hex: "#F59E0B",
    player4Hex: "#EC4899",
    highlightHex: "#34D399",
    dangerHex: "#EF4444",
    player1BadgeClass: "bg-emerald-600 text-white",
    player2BadgeClass: "bg-sky-600 text-white",
  };
}

export function getDefaultThemeAndAudioConfig(): ThemeAndAudioConfig {
  return {
    themeId: "piedra_oscura",
    okabeIto: false,
    soundEnabled: true,
    soundVolume: 0.65,
  };
}

export function loadThemeAndAudioConfig(): ThemeAndAudioConfig {
  const def = getDefaultThemeAndAudioConfig();
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      const raw = window.localStorage.getItem(THEME_CONFIG_STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        const themeId: VisualThemeId =
          parsed.themeId in VISUAL_THEMES ? parsed.themeId : def.themeId;
        return {
          themeId,
          okabeIto: Boolean(parsed.okabeIto),
          soundEnabled:
            typeof parsed.soundEnabled === "boolean"
              ? parsed.soundEnabled
              : def.soundEnabled,
          soundVolume:
            typeof parsed.soundVolume === "number"
              ? Math.max(0, Math.min(1, parsed.soundVolume))
              : def.soundVolume,
        };
      }
    }
  } catch {
    // Fallback to default config
  }
  return def;
}

export function saveThemeAndAudioConfig(
  config: ThemeAndAudioConfig
): ThemeAndAudioConfig {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      window.localStorage.setItem(
        THEME_CONFIG_STORAGE_KEY,
        JSON.stringify(config)
      );
    }
  } catch {
    // Ignore storage quota errors
  }
  return config;
}

export type SoundEffectType =
  | "move"
  | "capture"
  | "dice_roll"
  | "card_play"
  | "clock_alert"
  | "victory";

let sharedAudioCtx: AudioContext | null = null;

function getAudioContext(): AudioContext | null {
  try {
    if (typeof window === "undefined") return null;
    const AudioCtx =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext?: typeof AudioContext })
        .webkitAudioContext;
    if (!AudioCtx) return null;
    if (!sharedAudioCtx) {
      sharedAudioCtx = new AudioCtx();
    }
    if (sharedAudioCtx.state === "suspended") {
      sharedAudioCtx.resume().catch(() => {});
    }
    return sharedAudioCtx;
  } catch {
    return null;
  }
}

/**
 * Sintetizador acústico procedural basado en Web Audio API.
 * Devuelve `true` si el sonido fue despachado (o simulado válidamente con sonido activo),
 * o `false` cuando el audio está silenciado.
 */
export function playProceduralSound(
  effect: SoundEffectType,
  config: Pick<ThemeAndAudioConfig, "soundEnabled" | "soundVolume">
): boolean {
  if (!config.soundEnabled || config.soundVolume <= 0) {
    return false;
  }
  const ctx = getAudioContext();
  if (!ctx) {
    // Entorno headless / test sin AudioContext nativo: operación no-op segura
    return true;
  }

  try {
    const now = ctx.currentTime;
    const gain = ctx.createGain();
    const vol = Math.max(0.05, Math.min(1, config.soundVolume)) * 0.18;
    gain.connect(ctx.destination);

    if (effect === "move") {
      const osc = ctx.createOscillator();
      osc.type = "triangle";
      osc.frequency.setValueAtTime(420, now);
      osc.frequency.exponentialRampToValueAtTime(560, now + 0.08);
      gain.gain.setValueAtTime(vol, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);
      osc.connect(gain);
      osc.start(now);
      osc.stop(now + 0.09);
    } else if (effect === "capture") {
      const osc = ctx.createOscillator();
      osc.type = "sine";
      osc.frequency.setValueAtTime(310, now);
      osc.frequency.exponentialRampToValueAtTime(640, now + 0.14);
      gain.gain.setValueAtTime(vol * 1.2, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
      osc.connect(gain);
      osc.start(now);
      osc.stop(now + 0.15);
    } else if (effect === "dice_roll") {
      [0, 0.045, 0.09].forEach((offset, idx) => {
        const osc = ctx.createOscillator();
        const subGain = ctx.createGain();
        osc.type = "square";
        osc.frequency.setValueAtTime(300 + idx * 140, now + offset);
        subGain.gain.setValueAtTime(vol * 0.7, now + offset);
        subGain.gain.exponentialRampToValueAtTime(0.001, now + offset + 0.035);
        osc.connect(subGain);
        subGain.connect(ctx.destination);
        osc.start(now + offset);
        osc.stop(now + offset + 0.04);
      });
    } else if (effect === "card_play") {
      const osc = ctx.createOscillator();
      osc.type = "sine";
      osc.frequency.setValueAtTime(520, now);
      osc.frequency.exponentialRampToValueAtTime(780, now + 0.07);
      gain.gain.setValueAtTime(vol * 0.9, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
      osc.connect(gain);
      osc.start(now);
      osc.stop(now + 0.08);
    } else if (effect === "clock_alert") {
      const osc = ctx.createOscillator();
      osc.type = "sine";
      osc.frequency.setValueAtTime(880, now);
      gain.gain.setValueAtTime(vol, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
      osc.connect(gain);
      osc.start(now);
      osc.stop(now + 0.12);
    } else if (effect === "victory") {
      [523.25, 659.25, 783.99].forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const subGain = ctx.createGain();
        const t = now + idx * 0.09;
        osc.type = "triangle";
        osc.frequency.setValueAtTime(freq, t);
        subGain.gain.setValueAtTime(vol * 1.15, t);
        subGain.gain.exponentialRampToValueAtTime(0.001, t + 0.16);
        osc.connect(subGain);
        subGain.connect(ctx.destination);
        osc.start(t);
        osc.stop(t + 0.17);
      });
    }
  } catch {
    // Ignore audio context timing errors
  }
  return true;
}

interface ThemeAndAudioToolbarProps {
  config: ThemeAndAudioConfig;
  onChange: (next: ThemeAndAudioConfig) => void;
}

export const ThemeAndAudioToolbar: React.FC<ThemeAndAudioToolbarProps> = ({
  config,
  onChange,
}) => {
  const update = (patch: Partial<ThemeAndAudioConfig>) => {
    const next = saveThemeAndAudioConfig({ ...config, ...patch });
    onChange(next);
  };

  return (
    <div className="flex flex-wrap items-center gap-2 p-2 rounded-xl bg-slate-900/90 border border-slate-800 text-xs">
      <div className="inline-flex items-center gap-1.5 text-slate-300 pl-1">
        <Palette className="w-3.5 h-3.5 text-emerald-400" />
        <span className="font-medium">Tema:</span>
      </div>

      {(Object.keys(VISUAL_THEMES) as VisualThemeId[]).map((id) => {
        const item = VISUAL_THEMES[id];
        const active = config.themeId === id;
        return (
          <button
            key={id}
            type="button"
            onClick={() => {
              update({ themeId: id });
              playProceduralSound("move", config);
            }}
            className={`px-2.5 py-1 rounded-md font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              active
                ? "bg-white text-slate-950 font-semibold"
                : "bg-slate-800/80 text-slate-300 hover:text-white"
            }`}
          >
            {item.label}
          </button>
        );
      })}

      <span aria-hidden="true" className="text-slate-700">
        ·
      </span>

      <button
        type="button"
        onClick={() => update({ okabeIto: !config.okabeIto })}
        aria-pressed={config.okabeIto}
        className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
          config.okabeIto
            ? "bg-[#0072B2] text-white font-semibold"
            : "bg-slate-800/80 text-slate-300 hover:text-white"
        }`}
      >
        <Eye className="w-3.5 h-3.5" />
        <span>
          {config.okabeIto ? "Okabe-Ito: Activo" : "Modo Daltónico Okabe-Ito"}
        </span>
      </button>

      <span aria-hidden="true" className="text-slate-700">
        ·
      </span>

      <button
        type="button"
        onClick={() => {
          const nextSound = !config.soundEnabled;
          const nextCfg = saveThemeAndAudioConfig({
            ...config,
            soundEnabled: nextSound,
          });
          onChange(nextCfg);
          if (nextSound) {
            playProceduralSound("move", nextCfg);
          }
        }}
        className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
          config.soundEnabled
            ? "bg-emerald-600/90 text-white"
            : "bg-slate-800/80 text-slate-400 hover:text-white"
        }`}
      >
        {config.soundEnabled ? (
          <Volume2 className="w-3.5 h-3.5" />
        ) : (
          <VolumeX className="w-3.5 h-3.5" />
        )}
        <span>{config.soundEnabled ? "Audio FX: ON" : "Audio FX: OFF"}</span>
      </button>
    </div>
  );
};
