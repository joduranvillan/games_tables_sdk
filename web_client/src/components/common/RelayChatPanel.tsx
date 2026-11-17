import React, { useState } from "react";
import { MessageSquare, Send } from "lucide-react";
import { RelayChatMessage } from "../../bridge/relayClient";

export const QUICK_TACTICAL_REACTIONS = [
  "¡Buena jugada!",
  "¡Jaque!",
  "¡Bien jugado!",
  "¡Suerte en la partida!",
] as const;

interface RelayChatPanelProps {
  roomCode: string;
  localPlayerName: string;
  localPlayerId: number;
  messages: RelayChatMessage[];
  onSendMessage: (text: string) => void;
}

export const RelayChatPanel: React.FC<RelayChatPanelProps> = ({
  roomCode,
  localPlayerName,
  localPlayerId,
  messages,
  onSendMessage,
}) => {
  const [draft, setDraft] = useState<string>("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!draft.trim()) return;
    onSendMessage(draft);
    setDraft("");
  };

  return (
    <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
      <div className="flex items-center justify-between border-b border-slate-800 pb-3">
        <div className="flex items-center gap-2">
          <MessageSquare className="w-4 h-4 text-emerald-400" />
          <h3 className="text-sm font-bold text-white">
            Chat de Sala en Vivo ({roomCode || "LOCAL"})
          </h3>
        </div>
        <span className="text-xs text-slate-400 font-mono tabular-nums">
          {messages.length} mensajes
        </span>
      </div>

      {/* Quick Tactical Reactions */}
      <div className="flex flex-wrap items-center gap-1.5">
        {QUICK_TACTICAL_REACTIONS.map((reaction) => (
          <button
            key={reaction}
            type="button"
            onClick={() => onSendMessage(reaction)}
            className="px-2.5 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            {reaction}
          </button>
        ))}
      </div>

      {/* Message List */}
      <div className="h-44 overflow-y-auto rounded-xl bg-slate-950 border border-slate-800 p-3 flex flex-col gap-2">
        {messages.length === 0 ? (
          <div className="text-xs text-slate-500 my-auto text-center">
            Aún no hay mensajes en la sala. Usa una reacción rápida o escribe un
            mensaje para comunicarte con los jugadores y espectadores.
          </div>
        ) : (
          messages.map((m) => {
            const isMine =
              m.playerId === localPlayerId && m.senderName === localPlayerName;
            return (
              <div
                key={m.id}
                className={`p-2.5 rounded-lg text-xs flex flex-col gap-0.5 ${
                  isMine
                    ? "bg-emerald-950/60 border border-emerald-800/60 self-end text-right"
                    : "bg-slate-900 border border-slate-800 self-start text-left"
                }`}
              >
                <div className="text-[11px] text-slate-400 font-mono">
                  <strong className="text-slate-200">{m.senderName}</strong> (J
                  {m.playerId}) · {m.timestamp}
                </div>
                <div className="text-slate-100">{m.text}</div>
              </div>
            );
          })
        )}
      </div>

      {/* Input Form */}
      <form onSubmit={handleSubmit} className="flex items-center gap-2">
        <input
          type="text"
          aria-label="Mensaje de chat de sala"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="Escribe un mensaje para la sala..."
          className="flex-1 px-3 py-2 rounded-lg bg-slate-950 border border-slate-700 text-xs text-white"
        />
        <button
          type="submit"
          className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
        >
          <Send className="w-3.5 h-3.5" />
          <span>Enviar</span>
        </button>
      </form>
    </div>
  );
};
