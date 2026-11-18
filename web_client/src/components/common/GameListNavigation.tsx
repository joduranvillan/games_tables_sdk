import React from "react";
import {
  Activity,
  BarChart3,
  BookOpen,
  ChevronRight,
  Gamepad2,
  Grid,
  Layers,
  Search,
  Trophy,
  Wifi,
  X,
} from "lucide-react";

export interface CatalogGameEntry {
  id: string;
  title: string;
  crateName: string;
  category: string;
  phase: 1 | 2;
  blockLabel: string;
  summary: string;
}

export type CategoryFilterId =
  | "all"
  | "classic"
  | "oriental"
  | "dice_tactics"
  | "cards_strategy";

export interface CategoryGroupMeta {
  id: Exclude<CategoryFilterId, "all">;
  label: string;
  shortLabel: string;
  gameIds: string[];
}

export const GAME_CATEGORY_GROUPS: CategoryGroupMeta[] = [
  {
    id: "classic",
    label: "Estrategia Clásica",
    shortLabel: "Clásicos",
    gameIds: ["chess", "checkers"],
  },
  {
    id: "oriental",
    label: "Estrategia Oriental",
    shortLabel: "Oriental",
    gameIds: ["go", "shogi", "xiangqi", "chinese_checkers"],
  },
  {
    id: "dice_tactics",
    label: "Dados, Carrera y Táctica",
    shortLabel: "Dados / Táctica",
    gameIds: ["goose", "backgammon", "ludo", "battleship"],
  },
  {
    id: "cards_strategy",
    label: "Cartas, Economía y Conquista",
    shortLabel: "Cartas / Mesa",
    gameIds: ["uno", "mille_bornes", "monopoly", "crisis"],
  },
];

export interface GroupedGamesSection {
  groupId: Exclude<CategoryFilterId, "all">;
  groupLabel: string;
  games: CatalogGameEntry[];
}

export function filterAndGroupCatalogGames(
  catalog: CatalogGameEntry[],
  searchQuery: string,
  categoryFilter: CategoryFilterId
): GroupedGamesSection[] {
  const normalizedQuery = searchQuery.trim().toLowerCase();

  const matchesSearch = (game: CatalogGameEntry): boolean => {
    if (!normalizedQuery) return true;
    return (
      game.title.toLowerCase().includes(normalizedQuery) ||
      game.summary.toLowerCase().includes(normalizedQuery) ||
      game.category.toLowerCase().includes(normalizedQuery) ||
      game.crateName.toLowerCase().includes(normalizedQuery)
    );
  };

  const sections: GroupedGamesSection[] = [];

  for (const group of GAME_CATEGORY_GROUPS) {
    if (categoryFilter !== "all" && categoryFilter !== group.id) {
      continue;
    }
    const groupGames = catalog.filter(
      (g) => group.gameIds.includes(g.id) && matchesSearch(g)
    );
    if (groupGames.length > 0) {
      sections.push({
        groupId: group.id,
        groupLabel: group.label,
        games: groupGames,
      });
    }
  }

  return sections;
}

interface GameListContentProps {
  catalog: CatalogGameEntry[];
  selectedGameId: string;
  searchQuery: string;
  categoryFilter: CategoryFilterId;
  eloByGame: Record<string, { rating: number }>;
  globalElo: number;
  unlockedAchievementsCount: number;
  totalAchievementsCount: number;
  onSearchChange: (q: string) => void;
  onCategoryFilterChange: (cat: CategoryFilterId) => void;
  onSelectGame: (gameId: string) => void;
  onOpenCatalogGrid?: () => void;
  onOpenDiagnostics?: () => void;
  onOpenDocs?: () => void;
}

export const CategorizedGameListContent: React.FC<GameListContentProps> = ({
  catalog,
  selectedGameId,
  searchQuery,
  categoryFilter,
  eloByGame,
  globalElo,
  unlockedAchievementsCount,
  totalAchievementsCount,
  onSearchChange,
  onCategoryFilterChange,
  onSelectGame,
  onOpenCatalogGrid,
  onOpenDiagnostics,
  onOpenDocs,
}) => {
  const groupedSections = filterAndGroupCatalogGames(
    catalog,
    searchQuery,
    categoryFilter
  );

  const totalVisibleGames = groupedSections.reduce(
    (acc, sec) => acc + sec.games.length,
    0
  );

  return (
    <div className="flex flex-col h-full">
      {/* Header & Search */}
      <div className="p-3.5 border-b border-slate-800 flex flex-col gap-3">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Layers className="w-4 h-4 text-emerald-400 shrink-0" />
            <h2 className="text-sm font-bold text-white font-display tracking-tight">
              Lista de Juegos ({totalVisibleGames}/14)
            </h2>
          </div>
          {onOpenCatalogGrid && (
            <button
              type="button"
              onClick={onOpenCatalogGrid}
              className="text-xs text-slate-400 hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              Ver cuadrícula
            </button>
          )}
        </div>

        {/* Instant Search Input */}
        <div className="relative">
          <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Buscar juego o regla..."
            aria-label="Buscar juego o regla"
            className="w-full pl-8 pr-8 py-2 rounded-lg bg-slate-950 border border-slate-800 text-xs text-white placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => onSearchChange("")}
              aria-label="Limpiar búsqueda"
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white cursor-pointer"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>

        {/* Category Filter Buttons */}
        <div className="flex flex-wrap items-center gap-1 bg-slate-950 p-1 rounded-lg border border-slate-800/80">
          <button
            type="button"
            onClick={() => onCategoryFilterChange("all")}
            className={`px-2 py-1 rounded text-[11px] font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              categoryFilter === "all"
                ? "bg-emerald-600 text-white"
                : "text-slate-400 hover:text-white"
            }`}
          >
            Todos
          </button>
          {GAME_CATEGORY_GROUPS.map((grp) => (
            <button
              key={grp.id}
              type="button"
              onClick={() => onCategoryFilterChange(grp.id)}
              className={`px-2 py-1 rounded text-[11px] font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                categoryFilter === grp.id
                  ? "bg-emerald-600 text-white"
                  : "text-slate-400 hover:text-white"
              }`}
            >
              {grp.shortLabel}
            </button>
          ))}
        </div>
      </div>

      {/* Categorized Scrollable List */}
      <div className="flex-1 overflow-y-auto divide-y divide-slate-800/60">
        {groupedSections.length === 0 ? (
          <div className="p-6 text-center text-xs text-slate-400">
            No se encontraron juegos para "{searchQuery}".
          </div>
        ) : (
          groupedSections.map((section) => (
            <div key={section.groupId} className="py-2">
              <div className="px-3.5 py-1.5 flex items-center justify-between text-[11px] font-semibold text-slate-400">
                <span>{section.groupLabel}</span>
                <span className="font-mono tabular-nums text-slate-500">
                  {section.games.length}
                </span>
              </div>
              <div className="flex flex-col gap-0.5 px-2">
                {section.games.map((game) => {
                  const isSelected = game.id === selectedGameId;
                  const rating = eloByGame[game.id]?.rating ?? 1200;
                  const catalogIndex =
                    catalog.findIndex((c) => c.id === game.id) + 1;

                  return (
                    <button
                      key={game.id}
                      type="button"
                      onClick={() => onSelectGame(game.id)}
                      className={`w-full min-h-[52px] px-3 py-2 rounded-xl text-left flex items-center justify-between gap-2.5 transition-colors cursor-pointer ${
                        isSelected
                          ? "bg-emerald-600/20 text-white border border-emerald-500/50"
                          : "hover:bg-slate-800/70 text-slate-200 border border-transparent"
                      }`}
                    >
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-1.5">
                          <span className="text-[11px] font-mono tabular-nums text-slate-500 shrink-0">
                            {String(catalogIndex).padStart(2, "0")}.
                          </span>
                          <span
                            className={`text-xs font-semibold truncate ${
                              isSelected ? "text-emerald-300" : "text-white"
                            }`}
                          >
                            {game.title}
                          </span>
                        </div>
                        <p className="text-[11px] text-slate-400 truncate mt-0.5">
                          {game.summary}
                        </p>
                      </div>

                      <div className="flex items-center gap-1.5 shrink-0">
                        <span
                          className={`text-[11px] font-mono tabular-nums ${
                            isSelected
                              ? "text-emerald-300 font-semibold"
                              : "text-slate-400"
                          }`}
                        >
                          {rating}
                        </span>
                        <ChevronRight
                          className={`w-3.5 h-3.5 ${
                            isSelected ? "text-emerald-400" : "text-slate-600"
                          }`}
                        />
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          ))
        )}
      </div>

      {/* Compact Footer: Global ELO, Achievements & Quick Tools */}
      <div className="p-3 border-t border-slate-800 bg-slate-950/60 flex flex-col gap-2">
        <div className="flex items-center justify-between text-xs text-slate-300 font-mono tabular-nums">
          <span>
            ELO Global: <strong className="text-white">{globalElo}</strong>
          </span>
          <span aria-hidden="true">·</span>
          <span>
            Logros:{" "}
            <strong className="text-amber-400">
              {unlockedAchievementsCount}/{totalAchievementsCount}
            </strong>
          </span>
        </div>

        <div className="grid grid-cols-2 gap-1.5">
          {onOpenDiagnostics && (
            <button
              type="button"
              onClick={onOpenDiagnostics}
              className="min-h-[36px] px-2.5 py-1.5 rounded-lg bg-slate-900 hover:bg-slate-800 text-emerald-400 border border-slate-800 text-[11px] font-semibold inline-flex items-center justify-center gap-1.5 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              <Activity className="w-3.5 h-3.5 shrink-0" />
              <span>Diagnóstico E2E</span>
            </button>
          )}
          {onOpenDocs && (
            <button
              type="button"
              onClick={onOpenDocs}
              className="min-h-[36px] px-2.5 py-1.5 rounded-lg bg-slate-900 hover:bg-slate-800 text-sky-400 border border-slate-800 text-[11px] font-semibold inline-flex items-center justify-center gap-1.5 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              <BookOpen className="w-3.5 h-3.5 shrink-0" />
              <span>Guía y Docs</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

interface MobileGameDrawerProps extends GameListContentProps {
  isOpen: boolean;
  onClose: () => void;
}

export const MobileGameListDrawer: React.FC<MobileGameDrawerProps> = ({
  isOpen,
  onClose,
  ...contentProps
}) => {
  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 lg:hidden flex flex-col justify-end sm:justify-start sm:flex-row bg-black/65 backdrop-blur-xs"
      role="dialog"
      aria-modal="true"
      aria-label="Selector de los 14 juegos"
    >
      {/* Backdrop click target */}
      <div className="fixed inset-0" onClick={onClose} />

      <div className="relative z-10 w-full sm:w-96 max-h-[84vh] sm:max-h-screen sm:h-full bg-slate-900 border-t sm:border-t-0 sm:border-r border-slate-800 rounded-t-3xl sm:rounded-none flex flex-col overflow-hidden shadow-2xl">
        {/* Mobile grab handle & close header */}
        <div className="flex items-center justify-between px-4 pt-3 pb-1 sm:py-3 border-b border-slate-800/80">
          <div className="w-10 h-1.5 bg-slate-700 rounded-full mx-auto sm:hidden" />
          <span className="hidden sm:inline text-xs font-semibold text-slate-300">
            Seleccionar Juego Canónico
          </span>
          <button
            type="button"
            onClick={onClose}
            aria-label="Cerrar lista de juegos"
            className="min-h-[40px] min-w-[40px] -mr-2 inline-flex items-center justify-center text-slate-400 hover:text-white cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto">
          <CategorizedGameListContent
            {...contentProps}
            onSelectGame={(gid) => {
              contentProps.onSelectGame(gid);
              onClose();
            }}
            onOpenCatalogGrid={
              contentProps.onOpenCatalogGrid
                ? () => {
                    contentProps.onOpenCatalogGrid?.();
                    onClose();
                  }
                : undefined
            }
            onOpenDiagnostics={
              contentProps.onOpenDiagnostics
                ? () => {
                    contentProps.onOpenDiagnostics?.();
                    onClose();
                  }
                : undefined
            }
            onOpenDocs={
              contentProps.onOpenDocs
                ? () => {
                    contentProps.onOpenDocs?.();
                    onClose();
                  }
                : undefined
            }
          />
        </div>
      </div>
    </div>
  );
};

export type AppPrimaryTab =
  | "play"
  | "catalog"
  | "tournaments"
  | "elo"
  | "analyzer"
  | "network"
  | "diagnostics";

interface MobileBottomNavProps {
  activeTab: AppPrimaryTab;
  isGameDrawerOpen: boolean;
  hasActiveRoomOrQueue: boolean;
  onSelectTab: (tab: AppPrimaryTab) => void;
  onToggleGameDrawer: () => void;
}

export const MobileBottomNav: React.FC<MobileBottomNavProps> = ({
  activeTab,
  isGameDrawerOpen,
  hasActiveRoomOrQueue,
  onSelectTab,
  onToggleGameDrawer,
}) => {
  return (
    <nav
      aria-label="Navegación principal móvil"
      className="fixed bottom-0 left-0 right-0 z-40 lg:hidden bg-slate-950/95 backdrop-blur-md border-t border-slate-800 grid grid-cols-5 items-center h-14 px-1"
    >
      <button
        type="button"
        onClick={() => onSelectTab("play")}
        className={`min-h-[44px] flex flex-col items-center justify-center rounded-lg transition-colors cursor-pointer ${
          activeTab === "play" && !isGameDrawerOpen
            ? "text-emerald-400 font-semibold"
            : "text-slate-400 hover:text-white"
        }`}
      >
        <Gamepad2 className="w-5 h-5" />
        <span className="text-[10px] tracking-tight mt-0.5 whitespace-nowrap">
          Tablero
        </span>
      </button>

      <button
        type="button"
        onClick={onToggleGameDrawer}
        className={`min-h-[44px] flex flex-col items-center justify-center rounded-lg transition-colors cursor-pointer ${
          isGameDrawerOpen || activeTab === "catalog"
            ? "text-emerald-400 font-semibold"
            : "text-slate-400 hover:text-white"
        }`}
      >
        <Grid className="w-5 h-5" />
        <span className="text-[10px] tracking-tight mt-0.5 whitespace-nowrap">
          14 Juegos
        </span>
      </button>

      <button
        type="button"
        onClick={() => onSelectTab("network")}
        className={`relative min-h-[44px] flex flex-col items-center justify-center rounded-lg transition-colors cursor-pointer ${
          activeTab === "network" && !isGameDrawerOpen
            ? "text-emerald-400 font-semibold"
            : "text-slate-400 hover:text-white"
        }`}
      >
        <Wifi className="w-5 h-5" />
        <span className="text-[10px] tracking-tight mt-0.5 whitespace-nowrap">
          Salas Online
        </span>
        {hasActiveRoomOrQueue && (
          <span className="absolute top-1.5 right-4 w-2 h-2 rounded-full bg-emerald-400" />
        )}
      </button>

      <button
        type="button"
        onClick={() => onSelectTab("tournaments")}
        className={`min-h-[44px] flex flex-col items-center justify-center rounded-lg transition-colors cursor-pointer ${
          activeTab === "tournaments" && !isGameDrawerOpen
            ? "text-emerald-400 font-semibold"
            : "text-slate-400 hover:text-white"
        }`}
      >
        <Trophy className="w-5 h-5" />
        <span className="text-[10px] tracking-tight mt-0.5 whitespace-nowrap">
          Torneos
        </span>
      </button>

      <button
        type="button"
        onClick={() =>
          onSelectTab(activeTab === "elo" ? "analyzer" : "elo")
        }
        className={`min-h-[44px] flex flex-col items-center justify-center rounded-lg transition-colors cursor-pointer ${
          (activeTab === "elo" ||
            activeTab === "analyzer" ||
            activeTab === "diagnostics") &&
          !isGameDrawerOpen
            ? "text-emerald-400 font-semibold"
            : "text-slate-400 hover:text-white"
        }`}
      >
        <BarChart3 className="w-5 h-5" />
        <span className="text-[10px] tracking-tight mt-0.5 whitespace-nowrap">
          {activeTab === "analyzer" ? "Analizador" : "ELO / Análisis"}
        </span>
      </button>
    </nav>
  );
};
