import React, { useState } from "react";
import { Dices } from "lucide-react";

interface DiceRoller3DProps {
  dice: [number, number];
  disabled?: boolean;
  onRoll: (d1: number, d2: number) => void;
  label?: string;
}

const PIP_POSITIONS: Record<number, [number, number][]> = {
  1: [[50, 50]],
  2: [
    [25, 25],
    [75, 75],
  ],
  3: [
    [25, 25],
    [50, 50],
    [75, 75],
  ],
  4: [
    [25, 25],
    [75, 25],
    [25, 75],
    [75, 75],
  ],
  5: [
    [25, 25],
    [75, 25],
    [50, 50],
    [25, 75],
    [75, 75],
  ],
  6: [
    [25, 22],
    [75, 22],
    [25, 50],
    [75, 50],
    [25, 78],
    [75, 78],
  ],
};

function DieFace3D({ value, rolling }: { value: number; rolling: boolean }) {
  const pips = PIP_POSITIONS[value] || PIP_POSITIONS[1];
  return (
    <div
      className={`relative w-14 h-14 rounded-xl bg-gradient-to-br from-white via-slate-100 to-slate-200 border border-slate-300 shadow-lg transition-transform duration-200 ${
        rolling ? "scale-110 rotate-12" : "scale-100 rotate-0"
      }`}
      aria-label={`Dado valor ${value}`}
    >
      {pips.map(([x, y], idx) => (
        <span
          key={idx}
          style={{ left: `${x}%`, top: `${y}%` }}
          className={`absolute -translate-x-1/2 -translate-y-1/2 w-2.5 h-2.5 rounded-full ${
            value === 1 || value === 4 ? "bg-rose-600" : "bg-slate-900"
          }`}
        />
      ))}
    </div>
  );
}

export const DiceRoller3D: React.FC<DiceRoller3DProps> = ({
  dice,
  disabled = false,
  onRoll,
  label = "Lanzar Dados 3D",
}) => {
  const [rolling, setRolling] = useState(false);

  const handleRollClick = () => {
    if (disabled || rolling) return;
    setRolling(true);
    setTimeout(() => {
      const d1 = 1 + Math.floor(Math.random() * 6);
      const d2 = 1 + Math.floor(Math.random() * 6);
      setRolling(false);
      onRoll(d1, d2);
    }, 180);
  };

  return (
    <div className="flex items-center gap-4 p-3 rounded-xl bg-slate-900/90 border border-slate-800">
      <div className="flex items-center gap-2.5">
        <DieFace3D value={dice[0]} rolling={rolling} />
        <DieFace3D value={dice[1]} rolling={rolling} />
      </div>
      <div className="flex flex-col gap-1.5">
        <div className="text-xs text-slate-400 font-mono tabular-nums">
          Suma: <strong className="text-slate-100">{dice[0] + dice[1]}</strong> ({dice[0]} +{" "}
          {dice[1]})
        </div>
        <button
          type="button"
          onClick={handleRollClick}
          disabled={disabled || rolling}
          className="inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-xs font-semibold bg-emerald-600 hover:bg-emerald-500 disabled:bg-slate-800 disabled:text-slate-500 text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer disabled:cursor-not-allowed"
        >
          <Dices className="w-4 h-4" />
          <span>{rolling ? "Rodando..." : label}</span>
        </button>
      </div>
    </div>
  );
};
