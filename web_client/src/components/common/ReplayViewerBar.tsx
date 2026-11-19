import React, { useEffect, useState } from "react";
import {
  Download,
  FastForward,
  Pause,
  Play,
  Rewind,
  SkipBack,
  SkipForward,
  Upload,
} from "lucide-react";
import { useI18n } from "../../i18n";

interface ReplayViewerBarProps {
  currentStep: number;
  totalSteps: number;
  gameId: string;
  onSeekStep: (step: number) => void;
  onExportJson: () => string;
  onImportJson: (jsonStr: string) => boolean;
}

export const ReplayViewerBar: React.FC<ReplayViewerBarProps> = ({
  currentStep,
  totalSteps,
  gameId,
  onSeekStep,
  onExportJson,
  onImportJson,
}) => {
  const { t } = useI18n();
  const [isPlaying, setIsPlaying] = useState<boolean>(false);
  const [showImportModal, setShowImportModal] = useState<boolean>(false);
  const [importText, setImportText] = useState<string>("");
  const [statusMessage, setStatusMessage] = useState<string>("");

  useEffect(() => {
    if (!isPlaying) return;
    if (currentStep >= totalSteps) {
      setIsPlaying(false);
      return;
    }
    const timer = setTimeout(() => {
      onSeekStep(currentStep + 1);
    }, 650);
    return () => clearTimeout(timer);
  }, [isPlaying, currentStep, totalSteps]);

  const handleDownloadJson = () => {
    const payload = onExportJson();
    try {
      const blob = new Blob([payload], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `opentable_${gameId}_replay.opentable.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      setStatusMessage("(.opentable.json)");
    } catch {
      setStatusMessage("JSON OK");
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const content = String(reader.result || "");
      if (onImportJson(content)) {
        setStatusMessage(`OK (${file.name})`);
      } else {
        setStatusMessage("JSON Error");
      }
    };
    reader.readAsText(file);
  };

  return (
    <div className="w-full p-4 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-3">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        {/* Step-by-Step Timeline Controls */}
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs font-semibold text-slate-300 mr-1">
            {t("replay.title")}
          </span>

          <button
            type="button"
            disabled={currentStep <= 0}
            onClick={() => {
              setIsPlaying(false);
              onSeekStep(0);
            }}
            className="p-2 rounded-lg bg-slate-950 hover:bg-slate-800 disabled:opacity-40 border border-slate-800 text-slate-200 cursor-pointer"
          >
            <SkipBack className="w-3.5 h-3.5" />
          </button>

          <button
            type="button"
            disabled={currentStep <= 0}
            onClick={() => {
              setIsPlaying(false);
              onSeekStep(currentStep - 1);
            }}
            className="p-2 rounded-lg bg-slate-950 hover:bg-slate-800 disabled:opacity-40 border border-slate-800 text-slate-200 cursor-pointer"
          >
            <Rewind className="w-3.5 h-3.5" />
          </button>

          <button
            type="button"
            disabled={totalSteps === 0}
            onClick={() => {
              if (currentStep >= totalSteps) {
                onSeekStep(0);
              }
              setIsPlaying(!isPlaying);
            }}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            {isPlaying ? (
              <>
                <Pause className="w-3.5 h-3.5" />
                <span>{t("replay.pause")}</span>
              </>
            ) : (
              <>
                <Play className="w-3.5 h-3.5" />
                <span>{t("replay.play")}</span>
              </>
            )}
          </button>

          <button
            type="button"
            disabled={currentStep >= totalSteps}
            onClick={() => {
              setIsPlaying(false);
              onSeekStep(currentStep + 1);
            }}
            className="p-2 rounded-lg bg-slate-950 hover:bg-slate-800 disabled:opacity-40 border border-slate-800 text-slate-200 cursor-pointer"
          >
            <FastForward className="w-3.5 h-3.5" />
          </button>

          <button
            type="button"
            disabled={currentStep >= totalSteps}
            onClick={() => {
              setIsPlaying(false);
              onSeekStep(totalSteps);
            }}
            className="p-2 rounded-lg bg-slate-950 hover:bg-slate-800 disabled:opacity-40 border border-slate-800 text-slate-200 cursor-pointer"
          >
            <SkipForward className="w-3.5 h-3.5" />
          </button>

          <span className="px-2.5 py-1 rounded bg-slate-950 border border-slate-800 text-xs font-mono text-slate-300 tabular-nums">
            {t("replay.move_counter")} {currentStep} / {totalSteps}
          </span>

          {currentStep < totalSteps && (
            <span className="px-2 py-0.5 rounded bg-amber-500/20 border border-amber-500/40 text-[11px] font-semibold text-amber-300">
              {t("replay.history_badge")}
            </span>
          )}
        </div>

        {/* Save / Load JSON Controls */}
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={handleDownloadJson}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-medium cursor-pointer"
          >
            <Download className="w-3.5 h-3.5 text-emerald-400" />
            <span>{t("replay.save_json")}</span>
          </button>

          <label className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-medium cursor-pointer">
            <Upload className="w-3.5 h-3.5 text-sky-400" />
            <span>{t("replay.load_json_file")}</span>
            <input
              type="file"
              accept=".json,application/json"
              onChange={handleFileUpload}
              className="hidden"
            />
          </label>

          <button
            type="button"
            onClick={() => {
              setImportText(onExportJson());
              setShowImportModal(!showImportModal);
            }}
            className="px-3 py-1.5 rounded-lg bg-slate-950 hover:bg-slate-800 border border-slate-800 text-slate-300 text-xs font-medium cursor-pointer"
          >
            {showImportModal
              ? t("replay.close_json_editor")
              : t("replay.paste_view_json")}
          </button>
        </div>
      </div>

      {statusMessage && (
        <div className="text-xs text-emerald-400 font-mono">{statusMessage}</div>
      )}

      {showImportModal && (
        <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col gap-2">
          <textarea
            rows={4}
            value={importText}
            onChange={(e) => setImportText(e.target.value)}
            className="w-full p-2.5 rounded-lg bg-slate-900 border border-slate-700 text-xs font-mono text-slate-200"
          />
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => {
                if (onImportJson(importText)) {
                  setStatusMessage("JSON OK");
                  setShowImportModal(false);
                } else {
                  setStatusMessage("JSON Error");
                }
              }}
              className="px-3.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold cursor-pointer"
            >
              {t("replay.apply_json")}
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
