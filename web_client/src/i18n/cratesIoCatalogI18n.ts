import type { SupportedLocale } from "./index";

export type CrateLayerId =
  | "all"
  | "core-engine"
  | "transports-relay"
  | "runtime-bridges"
  | "canonical-games";

export interface CrateDocEntry {
  name: string;
  version: string;
  license: string;
  edition: string;
  rustVersion: string;
  layer: Exclude<CrateLayerId, "all">;
  readmePath: string;
  cratesIoUrl: string;
  docsRsUrl: string;
  exports: string[];
  cargoToml: string;
  codeExample: string;
  summaryByLocale: Record<SupportedLocale, string>;
  highlightsByLocale: Record<"en" | "es" | "pt" | "fr" | "de" | "zh" | "ja", string[]>;
}

export interface CratesExplorerUiText {
  tabCratesIo: string;
  categoryBadgeCrates: string;
  languageBarLabel: string;
  i18nHubBannerTitle: string;
  i18nHubBannerDesc: string;
  filterAll: string;
  filterCore: string;
  filterTransports: string;
  filterBridges: string;
  filterGames: string;
  exportsLabel: string;
  cargoTomlLabel: string;
  rustExampleLabel: string;
  copyCargoBtn: string;
  copyRustBtn: string;
  copiedLabel: string;
  resetFilterBtn: string;
}

export const NATIVE_DOC_LANGUAGES: Array<{
  locale: SupportedLocale;
  codeLabel: string;
  nativeLabel: string;
  hubPath: string;
}> = [
  { locale: "en", codeLabel: "EN", nativeLabel: "English (crates.io)", hubPath: "docs/i18n/en/README.md" },
  { locale: "es", codeLabel: "ES", nativeLabel: "Español", hubPath: "docs/i18n/es/README.md" },
  { locale: "pt", codeLabel: "PT-BR", nativeLabel: "Português (BR)", hubPath: "docs/i18n/pt-BR/README.md" },
  { locale: "fr", codeLabel: "FR", nativeLabel: "Français", hubPath: "docs/i18n/fr/README.md" },
  { locale: "de", codeLabel: "DE", nativeLabel: "Deutsch", hubPath: "docs/i18n/de/README.md" },
  { locale: "zh", codeLabel: "ZH-CN", nativeLabel: "简体中文", hubPath: "docs/i18n/zh-CN/README.md" },
  { locale: "ja", codeLabel: "JA", nativeLabel: "日本語", hubPath: "docs/i18n/ja/README.md" },
];

export const CRATES_EXPLORER_UI_BY_LOCALE: Record<SupportedLocale, CratesExplorerUiText> = {
  en: {
    tabCratesIo: "Crates.io & Rustdoc (24)",
    categoryBadgeCrates: "Crates.io & Docs.rs Reference",
    languageBarLabel: "Native Documentation Language:",
    i18nHubBannerTitle: "English Crates.io Standard + 7-Language Native Hub",
    i18nHubBannerDesc:
      "All 24 workspace crates include English README.md and //! rustdoc headers for crates.io & docs.rs, paired with native multilingual guides in docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md.",
    filterAll: "All Crates (24)",
    filterCore: "Core & ECS (3)",
    filterTransports: "Transports & Relay (5)",
    filterBridges: "Godot & WASM (2)",
    filterGames: "14 Board Games (14)",
    exportsLabel: "Public Rust API:",
    cargoTomlLabel: "Cargo.toml Dependency",
    rustExampleLabel: "Rust / SDK Usage Example",
    copyCargoBtn: "Copy Cargo.toml",
    copyRustBtn: "Copy Code",
    copiedLabel: "Copied",
    resetFilterBtn: "Reset Crate Filters",
  },
  es: {
    tabCratesIo: "Crates.io y Rustdoc (24)",
    categoryBadgeCrates: "Referencia Oficial Crates.io y Docs.rs",
    languageBarLabel: "Idioma de Documentación Nativa:",
    i18nHubBannerTitle: "Estándar Inglés para Crates.io + Hub Nativo en 7 Idiomas",
    i18nHubBannerDesc:
      "Los 24 crates del workspace incluyen README.md y encabezados //! rustdoc en inglés para crates.io y docs.rs, junto con guías nativas en docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md.",
    filterAll: "Todos los Crates (24)",
    filterCore: "Núcleo y ECS (3)",
    filterTransports: "Red y Relay (5)",
    filterBridges: "Godot y WASM (2)",
    filterGames: "14 Juegos Canónicos (14)",
    exportsLabel: "API Pública Rust:",
    cargoTomlLabel: "Dependencia Cargo.toml",
    rustExampleLabel: "Ejemplo de Uso en Rust / SDK",
    copyCargoBtn: "Copiar Cargo.toml",
    copyRustBtn: "Copiar Código",
    copiedLabel: "Copiado",
    resetFilterBtn: "Restablecer Filtros",
  },
  pt: {
    tabCratesIo: "Crates.io e Rustdoc (24)",
    categoryBadgeCrates: "Referência Oficial Crates.io e Docs.rs",
    languageBarLabel: "Idioma da Documentação Nativa:",
    i18nHubBannerTitle: "Padrão Inglês para Crates.io + Hub Nativo em 7 Idiomas",
    i18nHubBannerDesc:
      "Todos os 24 crates do workspace incluem README.md e cabeçalhos //! rustdoc em inglês para crates.io e docs.rs, além de guias nativos em docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md.",
    filterAll: "Todos os Crates (24)",
    filterCore: "Núcleo e ECS (3)",
    filterTransports: "Rede e Relay (5)",
    filterBridges: "Godot e WASM (2)",
    filterGames: "14 Jogos Canônicos (14)",
    exportsLabel: "API Pública Rust:",
    cargoTomlLabel: "Dependência Cargo.toml",
    rustExampleLabel: "Exemplo de Uso em Rust / SDK",
    copyCargoBtn: "Copiar Cargo.toml",
    copyRustBtn: "Copiar Código",
    copiedLabel: "Copiado",
    resetFilterBtn: "Redefinir Filtros",
  },
  fr: {
    tabCratesIo: "Crates.io & Rustdoc (24)",
    categoryBadgeCrates: "Référence Officielle Crates.io & Docs.rs",
    languageBarLabel: "Langue de Documentation Native :",
    i18nHubBannerTitle: "Standard Anglais Crates.io + Hub Natif en 7 Langues",
    i18nHubBannerDesc:
      "Les 24 crates du workspace incluent un README.md et des en-têtes //! rustdoc en anglais pour crates.io et docs.rs, ainsi que des guides natifs dans docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md.",
    filterAll: "Tous les Crates (24)",
    filterCore: "Noyau & ECS (3)",
    filterTransports: "Réseau & Relais (5)",
    filterBridges: "Godot & WASM (2)",
    filterGames: "14 Jeux Canoniques (14)",
    exportsLabel: "API Publique Rust :",
    cargoTomlLabel: "Dépendance Cargo.toml",
    rustExampleLabel: "Exemple d'Utilisation Rust / SDK",
    copyCargoBtn: "Copier Cargo.toml",
    copyRustBtn: "Copier le Code",
    copiedLabel: "Copié",
    resetFilterBtn: "Réinitialiser les Filtres",
  },
  de: {
    tabCratesIo: "Crates.io & Rustdoc (24)",
    categoryBadgeCrates: "Offizielle Crates.io & Docs.rs Referenz",
    languageBarLabel: "Native Dokumentationssprache:",
    i18nHubBannerTitle: "Englischer Crates.io-Standard + Nativer 7-Sprachen-Hub",
    i18nHubBannerDesc:
      "Alle 24 Workspace-Crates enthalten englische README.md-Dateien und //! rustdoc-Header für crates.io & docs.rs sowie native Handbücher unter docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md.",
    filterAll: "Alle Crates (24)",
    filterCore: "Kern & ECS (3)",
    filterTransports: "Netzwerk & Relay (5)",
    filterBridges: "Godot & WASM (2)",
    filterGames: "14 Brettspiele (14)",
    exportsLabel: "Öffentliche Rust-API:",
    cargoTomlLabel: "Cargo.toml-Abhängigkeit",
    rustExampleLabel: "Rust / SDK-Anwendungsbeispiel",
    copyCargoBtn: "Cargo.toml kopieren",
    copyRustBtn: "Code kopieren",
    copiedLabel: "Kopiert",
    resetFilterBtn: "Filter zurücksetzen",
  },
  zh: {
    tabCratesIo: "Crates.io 与 Rustdoc (24)",
    categoryBadgeCrates: "Crates.io 与 Docs.rs 官方参考",
    languageBarLabel: "原生文档语言：",
    i18nHubBannerTitle: "Crates.io 英文标准规范 + 7 种原生语言文档中心",
    i18nHubBannerDesc:
      "工作区全部 24 个 Crate 均提供面向 crates.io 与 docs.rs 的英文 README.md 和 //! rustdoc 文档头，并在 docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md 下同步提供 7 种语言的原生指南。",
    filterAll: "全部 Crate (24)",
    filterCore: "核心与 ECS (3)",
    filterTransports: "网络与 Relay (5)",
    filterBridges: "Godot 与 WASM (2)",
    filterGames: "14 款标准游戏 (14)",
    exportsLabel: "公开 Rust API：",
    cargoTomlLabel: "Cargo.toml 依赖配置",
    rustExampleLabel: "Rust / SDK 调用示例",
    copyCargoBtn: "复制 Cargo.toml",
    copyRustBtn: "复制代码",
    copiedLabel: "已复制",
    resetFilterBtn: "重置筛选条件",
  },
  ja: {
    tabCratesIo: "Crates.io & Rustdoc (24)",
    categoryBadgeCrates: "Crates.io & Docs.rs 公式リファレンス",
    languageBarLabel: "ネイティブドキュメント言語：",
    i18nHubBannerTitle: "Crates.io 英語標準仕様 + 7言語ネイティブドキュメントハブ",
    i18nHubBannerDesc:
      "全 24 クレートすべてに crates.io および docs.rs 向けの英語 README.md と //! rustdoc ヘッダーを完備し、docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md にて7言語のネイティブガイドを提供しています。",
    filterAll: "全クレート (24)",
    filterCore: "コア & ECS (3)",
    filterTransports: "通信 & リレー (5)",
    filterBridges: "Godot & WASM (2)",
    filterGames: "全14ボードゲーム (14)",
    exportsLabel: "公開 Rust API：",
    cargoTomlLabel: "Cargo.toml 依存関係",
    rustExampleLabel: "Rust / SDK 使用例",
    copyCargoBtn: "Cargo.toml をコピー",
    copyRustBtn: "コードをコピー",
    copiedLabel: "コピー済",
    resetFilterBtn: "フィルターをリセット",
  },
  it: {
    tabCratesIo: "Crates.io & Rustdoc (24)",
    categoryBadgeCrates: "Riferimento Crates.io & Docs.rs",
    languageBarLabel: "Lingua Documentazione Nativa:",
    i18nHubBannerTitle: "Standard Inglese Crates.io + Hub Nativo in 7 Lingue",
    i18nHubBannerDesc:
      "Tutti i 24 crate includono README.md in inglese per crates.io e docs.rs, insieme alle guide multilingue in docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md.",
    filterAll: "Tutti i Crate (24)",
    filterCore: "Core & ECS (3)",
    filterTransports: "Rete & Relay (5)",
    filterBridges: "Godot & WASM (2)",
    filterGames: "14 Giochi da Tavolo (14)",
    exportsLabel: "API Pubblica Rust:",
    cargoTomlLabel: "Dipendenza Cargo.toml",
    rustExampleLabel: "Esempio Rust / SDK",
    copyCargoBtn: "Copia Cargo.toml",
    copyRustBtn: "Copia Codice",
    copiedLabel: "Copiato",
    resetFilterBtn: "Reimposta Filtri",
  },
  ko: {
    tabCratesIo: "Crates.io & Rustdoc (24)",
    categoryBadgeCrates: "Crates.io & Docs.rs 공식 레퍼런스",
    languageBarLabel: "다국어 문서 언어:",
    i18nHubBannerTitle: "Crates.io 영문 표준 + 7개 국어 네이티브 문서 허브",
    i18nHubBannerDesc:
      "24개 모든 크레이트에 crates.io 및 docs.rs용 영문 README.md가 포함되어 있으며 docs/i18n/{en,es,pt-BR,fr,de,zh-CN,ja}/README.md에서 7개 국어 가이드를 제공합니다.",
    filterAll: "전체 크레이트 (24)",
    filterCore: "코어 & ECS (3)",
    filterTransports: "네트워크 & 릴레이 (5)",
    filterBridges: "Godot & WASM (2)",
    filterGames: "14개 보드게임 (14)",
    exportsLabel: "공개 Rust API:",
    cargoTomlLabel: "Cargo.toml 의존성",
    rustExampleLabel: "Rust / SDK 사용 예제",
    copyCargoBtn: "Cargo.toml 복사",
    copyRustBtn: "코드 복사",
    copiedLabel: "복사됨",
    resetFilterBtn: "필터 초기화",
  },
};

function makeCrateEntry(params: {
  name: string;
  layer: Exclude<CrateLayerId, "all">;
  exports: string[];
  codeExample: string;
  summaries: {
    en: string;
    es: string;
    pt: string;
    fr: string;
    de: string;
    zh: string;
    ja: string;
  };
  highlights: {
    en: string[];
    es: string[];
    pt: string[];
    fr: string[];
    de: string[];
    zh: string[];
    ja: string[];
  };
}): CrateDocEntry {
  const pkgName = params.name.endsWith("_game")
    ? `open_table_${params.name}`
    : params.name;
  const cargoDepLine =
    pkgName !== params.name
      ? `${params.name} = { package = "${pkgName}", version = "1.1.0" }`
      : `${pkgName} = "1.1.0"`;
  return {
    name: params.name,
    version: "1.1.0",
    license: "GPL-3.0-or-later",
    edition: "2021",
    rustVersion: "1.82+",
    layer: params.layer,
    readmePath: `${params.name}/README.md`,
    cratesIoUrl: `https://crates.io/crates/${pkgName}`,
    docsRsUrl: `https://docs.rs/${pkgName}`,
    exports: params.exports,
    cargoToml: `[dependencies]\n${cargoDepLine}`,
    codeExample: params.codeExample,
    summaryByLocale: {
      en: params.summaries.en,
      es: params.summaries.es,
      pt: params.summaries.pt,
      fr: params.summaries.fr,
      de: params.summaries.de,
      zh: params.summaries.zh,
      ja: params.summaries.ja,
      it: params.summaries.en,
      ko: params.summaries.en,
    },
    highlightsByLocale: params.highlights,
  };
}

export const CRATES_IO_CATALOG_24: CrateDocEntry[] = [
  makeCrateEntry({
    name: "open_table_core",
    layer: "core-engine",
    exports: ["SessionId", "PlayerId", "Tick", "Command", "Event", "RandomService", "AiDifficulty", "AiMoveTelemetry", "deterministic_fnv1a_64"],
    codeExample: `use open_table_core::{AiDifficulty, RandomService, deterministic_fnv1a_64, format_fnv1a_hex};

let mut rng = RandomService::from_seed(42);
let roll = rng.roll_die(6);
let chosen = AiDifficulty::select_top_k_with_noise(&[120.0, 115.0, 80.0], 25, 15.0, 42);
let checksum = format_fnv1a_hex(deterministic_fnv1a_64(b"board_v1"));`,
    summaries: {
      en: "Foundational deterministic traits, serializable Commands/Events, seeded ChaCha8 RNG, 0-100% Top-K AI noise selector, and 64-bit FNV-1a checksums.",
      es: "Traits fundacionales deterministas, comandos/eventos serializables, RNG ChaCha8 con semilla, selector Top-K de ruido IA (0-100%) y checksums FNV-1a de 64 bits.",
      pt: "Traits fundamentais determinísticos, comandos/eventos serializáveis, RNG ChaCha8 com semente, seletor Top-K de ruído da IA (0-100%) e checksums FNV-1a de 64 bits.",
      fr: "Traits fondamentaux déterministes, commandes/événements sérialisables, RNG ChaCha8 avec graine, sélecteur de bruit IA Top-K (0-100 %) et sommes FNV-1a 64 bits.",
      de: "Deterministische Basistraits, serialisierbare Commands/Events, ChaCha8-RNG mit Seed, Top-K-KI-Rauschselektor (0-100 %) und 64-Bit-FNV-1a-Prüfsummen.",
      zh: "确定性基础特征、可序列化 Command/Event 契约、带种子的 ChaCha8 随机数服务、0-100% Top-K AI 噪声选择器与 64 位 FNV-1a 校验和。",
      ja: "決定論的基盤トレイト、シリアライズ可能な Command/Event、シード付き ChaCha8 RNG、0〜100% Top-K AI ノイズ選択器、および 64ビット FNV-1a チェックサム。",
    },
    highlights: {
      en: ["Zero engine/network coupling with typetag::serde Command & Event trait objects.", "Top-K noise band selector (AiDifficulty::select_top_k_with_noise) and 64-bit FNV-1a checksums."],
      es: ["Cero acoplamiento con red o ECS mediante trait objects Command y Event serializables.", "Selector de banda de ruido Top-K (select_top_k_with_noise) y checksums FNV-1a de 64 bits."],
      pt: ["Zero acoplamento com rede ou ECS via trait objects Command e Event serializáveis.", "Seletor de banda de ruído Top-K (select_top_k_with_noise) e checksums FNV-1a de 64 bits."],
      fr: ["Zéro couplage réseau/ECS grâce aux objets de trait Command et Event sérialisables.", "Sélecteur de bande de bruit Top-K (select_top_k_with_noise) et sommes de contrôle FNV-1a 64 bits."],
      de: ["Keine Engine-/Netzwerkkopplung durch serialisierbare Command- & Event-Trait-Objekte.", "Top-K-Rauschbandauswahl (select_top_k_with_noise) und 64-Bit-FNV-1a-Prüfsummen."],
      zh: ["通过 typetag::serde 可序列化 Command 与 Event 特征对象实现零网络/ECS 耦合。", "内置 Top-K 噪声分值带选择器 (select_top_k_with_noise) 与 64 位 FNV-1a 状态校验和。"],
      ja: ["typetag::serde による Command / Event トレイトオブジェクトでネットワークや ECS との結合を排除。", "Top-K ノイズ帯選択器 (select_top_k_with_noise) と 64ビット FNV-1a チェックサムを内蔵。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_engine",
    layer: "core-engine",
    exports: ["Session", "RuleEngine", "LegalMoveGenerator", "TurnResource", "EloRating", "update_elo"],
    codeExample: `use open_table_engine::prelude::*;

let session = Session::new(SessionId(1), 42, vec![PlayerId(1), PlayerId(2)], RuleEngine::new());
assert_eq!(session.get_state_checksum_hex().len(), 18);`,
    summaries: {
      en: "ECS-backed deterministic turn-based session runtime (Session), transactional Undo/Redo stacks, FIDE K=32 ELO engine, and state hashing.",
      es: "Runtime determinista de sesiones por turnos sobre Bevy ECS (Session), pilas Undo/Redo transaccionales, motor ELO FIDE K=32 y firma de estado.",
      pt: "Runtime determinístico de sessões por turnos sobre Bevy ECS (Session), pilhas Undo/Redo transacionais, motor ELO FIDE K=32 e hash de estado.",
      fr: "Exécutif déterministe de sessions au tour par tour sur Bevy ECS (Session), piles Undo/Redo transactionnelles, moteur ELO FIDE K=32 et hachage d'état.",
      de: "ECS-gestützte deterministische Sitzungslaufzeit (Session), transaktionale Undo/Redo-Stacks, FIDE K=32 ELO-Rechner und Zustands-Hashing.",
      zh: "基于 Bevy ECS 的确定性回合制会话运行时 (Session)，支持事务级 Undo/Redo 栈、FIDE K=32 ELO 积分计算与状态签名。",
      ja: "Bevy ECS ベースの決定論的ターン制セッションランタイム (Session)。トランザクション Undo/Redo、FIDE K=32 ELO 計算、状態ハッシュを提供。",
    },
    highlights: {
      en: ["Transactional command processing with snapshot undo_step() and redo_step() stacks.", "Official FIDE ELO calculation and 64-bit FNV-1a session state checksums."],
      es: ["Procesamiento transaccional de comandos con pilas undo_step() y redo_step().", "Cálculo oficial ELO FIDE y checksums de sesión FNV-1a de 64 bits."],
      pt: ["Processamento transacional de comandos com pilhas undo_step() e redo_step().", "Cálculo oficial ELO FIDE e checksums de sessão FNV-1a de 64 bits."],
      fr: ["Traitement transactionnel des commandes avec piles undo_step() et redo_step().", "Calcul officiel ELO FIDE et sommes de contrôle de session FNV-1a 64 bits."],
      de: ["Transaktionale Befehlsverarbeitung mit undo_step()- und redo_step()-Stacks.", "Offizielle FIDE-ELO-Berechnung und 64-Bit-FNV-1a-Sitzungsprüfsummen."],
      zh: ["支持快照回滚 undo_step() 与重放 redo_step() 的事务级指令管线。", "内置官方 FIDE ELO 计算公式与 64 位 FNV-1a 会话状态校验和。"],
      ja: ["undo_step() / redo_step() スナップショットスタックを備えたトランザクションコマンド処理。", "公式 FIDE ELO 計算と 64ビット FNV-1a セッションチェックサムを搭載。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_macros",
    layer: "core-engine",
    exports: ["Component", "Resource", "game_command", "game_event"],
    codeExample: `use open_table_macros::{Component, Resource};

#[derive(Debug, Clone, Component)]
pub struct GridPosition { pub row: u8, pub col: u8 }`,
    summaries: {
      en: "Procedural derive and attribute macros (#[derive(Component)], #[derive(Resource)], #[game_command]) reducing boilerplate across game crates.",
      es: "Macros procedurales (#[derive(Component)], #[derive(Resource)], #[game_command]) que eliminan código repetitivo en los crates de juegos.",
      pt: "Macros procedurais (#[derive(Component)], #[derive(Resource)], #[game_command]) que reduzem código repetitivo nos crates de jogos.",
      fr: "Macros procédurales (#[derive(Component)], #[derive(Resource)], #[game_command]) réduisant le code répétitif dans les crates de jeux.",
      de: "Prozedurale Derive- und Attribut-Makros (#[derive(Component)], #[derive(Resource)], #[game_command]) zur Reduzierung von Boilerplate.",
      zh: "过程派生与属性宏（#[derive(Component)]、#[derive(Resource)]、#[game_command]），大幅精简游戏 Crate 的样板代码。",
      ja: "ゲームクレートのボイラープレートを削減する手続き型マクロ（#[derive(Component)], #[derive(Resource)], #[game_command]）。",
    },
    highlights: {
      en: ["Enforces Send + Sync + 'static compile-time bounds for ECS components and resources.", "Streamlines serializable Command and Event trait registration."],
      es: ["Garantiza límites Send + Sync + 'static en tiempo de compilación para componentes y recursos ECS.", "Simplifica el registro de comandos y eventos serializables."],
      pt: ["Garante limites Send + Sync + 'static em tempo de compilação para componentes e recursos ECS.", "Simplifica o registro de comandos e eventos serializáveis."],
      fr: ["Garantit les bornes Send + Sync + 'static à la compilation pour les composants et ressources ECS.", "Simplifie l'enregistrement des commandes et événements sérialisables."],
      de: ["Erzwingt Send + Sync + 'static zur Kompilierzeit für ECS-Komponenten und -Ressourcen.", "Vereinfacht die Registrierung serialisierbarer Commands und Events."],
      zh: ["在编译期强制校验 ECS 组件与资源的 Send + Sync + 'static 约束。", "自动化注册可序列化的 Command 与 Event 类型。"],
      ja: ["ECS コンポーネントとリソースに対してコンパイル時に Send + Sync + 'static 境界を保証。", "シリアライズ可能な Command と Event の登録を簡素化。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_qr",
    layer: "transports-relay",
    exports: ["QrInvitePayload", "encode_invite_qr_svg", "decode_invite_payload"],
    codeExample: `use open_table_qr::QrInvitePayload;

let invite = QrInvitePayload::new_relay("AB12CD", "chess", "wss://relay.example.org");`,
    summaries: {
      en: "Compact session invitation payloads and SVG/terminal QR code generation for LAN, Relay room codes, and mobile P2P pairing.",
      es: "Payloads compactos de invitación y generación de códigos QR en SVG/terminal para LAN, códigos de sala Relay y emparejamiento P2P móvil.",
      pt: "Payloads compactos de convite e geração de códigos QR em SVG/terminal para LAN, salas Relay e pareamento P2P móvel.",
      fr: "Charges utiles d'invitation compactes et génération de QR codes SVG/terminal pour LAN, salles Relais et appairage P2P mobile.",
      de: "Kompakte Sitzungseinladungen und SVG-/Terminal-QR-Code-Generierung für LAN, Relay-Raumcodes und mobiles P2P-Pairing.",
      zh: "紧凑型对局邀请载荷与 SVG/终端二维码生成器，适用于局域网、Relay 房间码与移动端 P2P 配对。",
      ja: "LAN、リレールームコード、モバイル P2P ペアリング向けのコンパクトな招待ペイロードおよび SVG/ターミナル QR コード生成。",
    },
    highlights: {
      en: ["Encodes room code, game type, and endpoint URI into compact QR payloads.", "Zero external image dependency: outputs crisp SVG markup directly."],
      es: ["Codifica código de sala, tipo de juego y URI en payloads QR compactos.", "Cero dependencias de imagen externas: genera SVG vectorial limpio."],
      pt: ["Codifica código da sala, tipo de jogo e URI em payloads QR compactos.", "Zero dependências externas de imagem: gera SVG vetorial limpo."],
      fr: ["Encode le code de salle, le jeu et l'URI dans un QR compact.", "Aucune dépendance d'image externe : génère directement du SVG vectoriel."],
      de: ["Kodiert Raumcode, Spieltyp und Endpunkt-URI in kompakte QR-Payloads.", "Keine externen Bildabhängigkeiten: erzeugt direkt sauberes SVG."],
      zh: ["将房间码、游戏类型与端点 URI 编码为紧凑二维码载荷。", "零外部图像库依赖，直接输出矢量 SVG 标记。"],
      ja: ["ルームコード、ゲーム種別、エンドポイント URI をコンパクトな QR ペイロードにエンコード。", "外部画像ライブラリ不要で鮮明な SVG を直接出力。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_transport_tcp",
    layer: "transports-relay",
    exports: ["TcpHostTransport", "TcpClientTransport"],
    codeExample: `use open_table_transport_tcp::TcpHostTransport;

let host = TcpHostTransport::bind("127.0.0.1:0").expect("bind LAN TCP host");`,
    summaries: {
      en: "Length-prefixed TCP host/client transport implementation of open_table_core::Transport for low-latency LAN multiplayer.",
      es: "Implementación de transporte TCP host/cliente con prefijo de longitud para partidas multijugador en red local (LAN) de baja latencia.",
      pt: "Implementação de transporte TCP host/cliente com prefixo de comprimento para multiplayer LAN de baixa latência.",
      fr: "Implémentation de transport TCP hôte/client avec préfixe de longueur pour le multijoueur LAN à faible latence.",
      de: "Längenpräfix-basierte TCP-Host/Client-Transportimplementierung für latenzarme LAN-Mehrspielerpartien.",
      zh: "带长度前缀的局域网 TCP 主机/客户端传输层实现，提供低延迟 LAN 多人对战。",
      ja: "低遅延 LAN マルチプレイヤー向けの長さプレフィックス付き TCP ホスト／クライアント通信実装。",
    },
    highlights: {
      en: ["32-bit big-endian frame header with non-blocking 60 FPS polling.", "Automatic peer disconnect detection and clean socket teardown."],
      es: ["Cabecera de trama de 32 bits big-endian con sondeo no bloqueante a 60 FPS.", "Detección automática de desconexión y cierre limpio de sockets."],
      pt: ["Cabeçalho de frame de 32 bits big-endian com polling não bloqueante a 60 FPS.", "Detecção automática de desconexão e encerramento limpo de sockets."],
      fr: ["En-tête de trame 32 bits big-endian avec scrutation non bloquante à 60 FPS.", "Détection automatique de déconnexion et fermeture propre des sockets."],
      de: ["32-Bit-Big-Endian-Frame-Header mit nicht-blockierendem 60-FPS-Polling.", "Automatische Verbindungsabbrucherkennung und sauberes Socket-Shutdown."],
      zh: ["32 位大端序帧头与非阻塞 60 FPS 轮询。", "自动检测对端断开并安全释放套接字。"],
      ja: ["32ビットビッグエンディアンフレームヘッダーと非ブロッキング 60 FPS ポーリング。", "ピア切断の自動検知とクリーンなソケット終了処理。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_transport_websocket",
    layer: "transports-relay",
    exports: ["WebSocketTransport", "RelayClientConfig"],
    codeExample: `use open_table_transport_websocket::RelayClientConfig;

let cfg = RelayClientConfig::new("ws://127.0.0.1:8080", "AB12CD");`,
    summaries: {
      en: "WebSocket client transport connecting desktop, mobile, and WebAssembly peers through open_table_relay rooms.",
      es: "Transporte cliente WebSocket que interconecta clientes de escritorio, móvil y WebAssembly mediante salas de open_table_relay.",
      pt: "Transporte cliente WebSocket conectando clientes desktop, mobile e WebAssembly através de salas do open_table_relay.",
      fr: "Transport client WebSocket connectant les pairs bureau, mobile et WebAssembly via les salles open_table_relay.",
      de: "WebSocket-Client-Transport zur Verbindung von Desktop-, Mobil- und WebAssembly-Peers über open_table_relay-Räume.",
      zh: "连接桌面端、移动端与 WebAssembly 客户端的 WebSocket 传输层，完全兼容 open_table_relay 房间协议。",
      ja: "デスクトップ、モバイル、WebAssembly クライアントを open_table_relay ルーム経由で接続する WebSocket トランスポート。",
    },
    highlights: {
      en: ["Supports create, join, spectate, and ELO matchmaking queue frames.", "Thread-safe inbox queue for deterministic game loop integration."],
      es: ["Soporta tramas create, join, spectate y cola de matchmaking por ELO.", "Cola de recepción thread-safe para integración determinista en el bucle de juego."],
      pt: ["Suporta frames create, join, spectate e fila de matchmaking por ELO.", "Fila de recepção thread-safe para integração determinística no loop do jogo."],
      fr: ["Prend en charge les trames create, join, spectate et la file de matchmaking ELO.", "File de réception thread-safe pour une intégration déterministe."],
      de: ["Unterstützt create-, join-, spectate- und ELO-Matchmaking-Frames.", "Thread-sichere Empfangswarteschlange für deterministische Spielschleifen."],
      zh: ["支持创建房间、加入、观战与 ELO 匹配队列协议帧。", "线程安全的接收队列，无缝对接确定性游戏主循环。"],
      ja: ["create、join、spectate、および ELO マッチメイキングフレームをサポート。", "決定論的ゲームループに統合可能なスレッドセーフ受信キュー。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_transport_native_bridge",
    layer: "transports-relay",
    exports: ["NativeBridgeTransport", "RawByteLink"],
    codeExample: `use open_table_transport_native_bridge::NativeBridgeTransport;

let mut bridge = NativeBridgeTransport::new();
bridge.push_incoming_frame(b"{\\"cmd\\":\\"Move\\"}".to_vec());`,
    summaries: {
      en: "Zero-socket RawByteLink bridge adapting Android Nearby Connections, iOS MultipeerConnectivity, and WebRTC DataChannels into Transport.",
      es: "Puente RawByteLink sin sockets que adapta Android Nearby Connections, iOS MultipeerConnectivity y WebRTC DataChannels al trait Transport.",
      pt: "Ponte RawByteLink sem sockets adaptando Android Nearby Connections, iOS MultipeerConnectivity e WebRTC DataChannels ao trait Transport.",
      fr: "Pont RawByteLink sans socket adaptant Android Nearby Connections, iOS MultipeerConnectivity et WebRTC DataChannels au trait Transport.",
      de: "Socketfreie RawByteLink-Brücke zur Anbindung von Android Nearby, iOS MultipeerConnectivity und WebRTC DataChannels an Transport.",
      zh: "无套接字 RawByteLink 桥接层，将 Android Nearby Connections、iOS MultipeerConnectivity 与 WebRTC DataChannel 适配为统一 Transport。",
      ja: "Android Nearby Connections、iOS MultipeerConnectivity、WebRTC DataChannel を Transport に適合させるソケットレス RawByteLink ブリッジ。",
    },
    highlights: {
      en: ["FFI-safe in-memory ring buffers (push_incoming_frame / drain_outgoing_frames).", "Enables offline Bluetooth & Wi-Fi Direct P2P play on mobile devices."],
      es: ["Búferes en memoria seguros para FFI (push_incoming_frame / drain_outgoing_frames).", "Permite juego P2P offline por Bluetooth y Wi-Fi Direct en móviles."],
      pt: ["Buffers em memória seguros para FFI (push_incoming_frame / drain_outgoing_frames).", "Permite jogo P2P offline via Bluetooth e Wi-Fi Direct em dispositivos móveis."],
      fr: ["Tampons mémoire sûrs pour FFI (push_incoming_frame / drain_outgoing_frames).", "Permet le jeu P2P hors ligne via Bluetooth et Wi-Fi Direct sur mobile."],
      de: ["FFI-sichere In-Memory-Puffer (push_incoming_frame / drain_outgoing_frames).", "Ermöglicht Offline-P2P-Spiele über Bluetooth und Wi-Fi Direct auf Mobilgeräten."],
      zh: ["FFI 安全的内存环形缓冲区（push_incoming_frame / drain_outgoing_frames）。", "支持移动设备通过蓝牙与 Wi-Fi Direct 进行离线 P2P 对战。"],
      ja: ["FFI セーフなインメモリバッファ (push_incoming_frame / drain_outgoing_frames)。", "モバイル端末での Bluetooth / Wi-Fi Direct オフライン P2P 対戦を実現。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_relay",
    layer: "transports-relay",
    exports: ["RelayServer", "MatchmakingQueue", "RoomRegistry"],
    codeExample: `// Symmetric ELO matchmaking rule in open_table_relay:
// |ELO_A - ELO_B| <= min(delta_A, delta_B)
assert!((1250_i32 - 1320_i32).abs() <= 150.min(200));`,
    summaries: {
      en: "Asynchronous WebSocket Relay server with 6-character room codes, read-only spectator broadcasting, and symmetric ELO matchmaking queues.",
      es: "Servidor Relay WebSocket asíncrono con códigos de sala de 6 caracteres, modo espectador y colas de matchmaking simétrico por rango ELO.",
      pt: "Servidor Relay WebSocket assíncrono com códigos de sala de 6 caracteres, modo espectador e filas de matchmaking simétrico por faixa ELO.",
      fr: "Serveur Relais WebSocket asynchrone avec codes de salle à 6 caractères, diffusion spectateur et files de matchmaking ELO symétrique.",
      de: "Asynchroner WebSocket-Relay-Server mit 6-stelligen Raumcodes, Zuschauermodus und symmetrischen ELO-Matchmaking-Warteschlangen.",
      zh: "异步 WebSocket Relay 中继服务器，支持 6 位房间码、只读观战广播与基于 ELO 容差窗口的对称自动匹配队列。",
      ja: "6桁ルームコード、観戦ブロードキャスト、対称 ELO マッチメイキングキューを備えた非同期 WebSocket リレーサーバー。",
    },
    highlights: {
      en: ["Allocates 6-character rooms with automatic TTL cleanup and spectator multiplexing.", "Matches players automatically when |ELO_A - ELO_B| <= min(delta_A, delta_B)."],
      es: ["Asigna salas de 6 caracteres con limpieza TTL y multiplexación de espectadores.", "Empareja jugadores automáticamente cuando |ELO_A - ELO_B| <= min(delta_A, delta_B)."],
      pt: ["Aloca salas de 6 caracteres com limpeza TTL e multiplexação de espectadores.", "Pareia jogadores automaticamente quando |ELO_A - ELO_B| <= min(delta_A, delta_B)."],
      fr: ["Alloue des salles à 6 caractères avec nettoyage TTL et multiplexage spectateurs.", "Apparie automatiquement les joueurs lorsque |ELO_A - ELO_B| <= min(delta_A, delta_B)."],
      de: ["Erstellt 6-stellige Räume mit TTL-Bereinigung und Zuschauer-Multiplexing.", "Paart Spieler automatisch bei |ELO_A - ELO_B| <= min(delta_A, delta_B)."],
      zh: ["分配带 TTL 自动回收的 6 位房间码并支持多路观战转发。", "满足对称条件 |ELO_A - ELO_B| <= min(delta_A, delta_B) 时自动撮合对局。"],
      ja: ["TTL 自動クリーンアップと観戦マルチプレクスを備えた6桁ルーム管理。", "|ELO_A - ELO_B| <= min(delta_A, delta_B) の対称条件でプレイヤーを自動マッチング。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_godot",
    layer: "runtime-bridges",
    exports: ["OpenTableBridge"],
    codeExample: `# GDScript (Godot 4 / Redot 4)
var bridge = OpenTableBridge.new()
bridge.start_ai_match("chess", 1, 2, 2)
bridge.set_ai_randomness_pct(15)`,
    summaries: {
      en: "GDExtension C-ABI bridge exposing all 14 canonical board games, 4-level AI with 0-100% randomness, Undo/Redo, FNV-1a checksums, and ELO to Godot 4 / Redot 4.",
      es: "Puente GDExtension C-ABI que expone los 14 juegos canónicos, IA de 4 niveles con ruido 0-100%, Undo/Redo, checksums FNV-1a y ELO a Godot 4 / Redot 4.",
      pt: "Ponte GDExtension C-ABI que expõe os 14 jogos canônicos, IA de 4 níveis com ruído 0-100%, Undo/Redo, checksums FNV-1a e ELO ao Godot 4 / Redot 4.",
      fr: "Pont GDExtension C-ABI exposant les 14 jeux canoniques, l'IA à 4 niveaux (bruit 0-100 %), Undo/Redo, sommes FNV-1a et ELO à Godot 4 / Redot 4.",
      de: "GDExtension-C-ABI-Brücke, die alle 14 Brettspiele, 4-stufige KI (0-100 % Rauschen), Undo/Redo, FNV-1a-Prüfsummen und ELO für Godot 4 / Redot 4 bereitstellt.",
      zh: "面向 Godot 4 / Redot 4 的 GDExtension C-ABI 桥接器，完整暴露 14 款游戏、0-100% 随机度 AI、Undo/Redo、FNV-1a 校验和与 ELO 系统。",
      ja: "Godot 4 / Redot 4 向けに全14ゲーム、0〜100% ランダム性対応4段階 AI、Undo/Redo、FNV-1a チェックサム、ELO を公開する GDExtension ブリッジ。",
    },
    highlights: {
      en: ["Single OpenTableBridge node powers all 14 games in Local, AI, LAN TCP, and Relay modes.", "Exposes set_ai_randomness_pct, undo_step, redo_step, and get_state_checksum_hex to GDScript."],
      es: ["Un único nodo OpenTableBridge impulsa los 14 juegos en modo Local, IA, TCP LAN y Relay.", "Expone set_ai_randomness_pct, undo_step, redo_step y get_state_checksum_hex a GDScript."],
      pt: ["Um único nó OpenTableBridge suporta os 14 jogos nos modos Local, IA, TCP LAN e Relay.", "Expõe set_ai_randomness_pct, undo_step, redo_step e get_state_checksum_hex ao GDScript."],
      fr: ["Un seul nœud OpenTableBridge gère les 14 jeux en modes Local, IA, TCP LAN et Relais.", "Expose set_ai_randomness_pct, undo_step, redo_step et get_state_checksum_hex à GDScript."],
      de: ["Ein einziger OpenTableBridge-Knoten steuert alle 14 Spiele in Lokal-, KI-, TCP- und Relay-Modi.", "Stellt set_ai_randomness_pct, undo_step, redo_step und get_state_checksum_hex in GDScript bereit."],
      zh: ["单一 OpenTableBridge 节点驱动全部 14 款游戏的本地、AI、局域网 TCP 与 Relay 模式。", "向 GDScript 暴露 set_ai_randomness_pct、undo_step、redo_step 与 get_state_checksum_hex。"],
      ja: ["単一の OpenTableBridge ノードで全14ゲームのローカル、AI、LAN TCP、リレー対戦を統合管理。", "set_ai_randomness_pct、undo_step、redo_step、get_state_checksum_hex を GDScript に公開。"],
    },
  }),
  makeCrateEntry({
    name: "open_table_wasm",
    layer: "runtime-bridges",
    exports: ["WasmGameBridge"],
    codeExample: `use open_table_wasm::WasmGameBridge;

let mut bridge = WasmGameBridge::new();
bridge.start_ai_match("chess", 1, 2, 2);
assert_eq!(bridge.get_ai_randomness_pct(), 12);`,
    summaries: {
      en: "WebAssembly (wasm-bindgen) bridge compiling all 14 canonical Rust board game engines, AI noise levels, Undo/Redo, FNV-1a checksums, and telemetry for the React Web client.",
      es: "Puente WebAssembly (wasm-bindgen) que compila los 14 motores de juego en Rust, niveles de ruido IA, Undo/Redo, checksums FNV-1a y telemetría para el cliente Web React.",
      pt: "Ponte WebAssembly (wasm-bindgen) compilando os 14 motores de jogo em Rust, níveis de ruído da IA, Undo/Redo, checksums FNV-1a e telemetria para o cliente Web React.",
      fr: "Pont WebAssembly (wasm-bindgen) compilant les 14 moteurs de jeu Rust, le bruit IA, Undo/Redo, les sommes FNV-1a et la télémétrie pour le client Web React.",
      de: "WebAssembly-Brücke (wasm-bindgen), die alle 14 Rust-Brettspiel-Engines, KI-Rauschstufen, Undo/Redo, FNV-1a-Prüfsummen und Telemetrie für den React-Web-Client kompiliert.",
      zh: "WebAssembly (wasm-bindgen) 桥接层，将全部 14 款 Rust 游戏引擎、AI 噪声控制、Undo/Redo、FNV-1a 校验和与决策遥测编译至 React Web 客户端。",
      ja: "全14種類の Rust ゲームエンジン、AI ノイズ制御、Undo/Redo、FNV-1a チェックサム、テレメトリを React Web クライアント向けにコンパイルする WebAssembly ブリッジ。",
    },
    highlights: {
      en: ["1:1 JSON contract parity with WasmGameBridge in src/wasm_pkg/index.ts.", "Provides get_last_ai_telemetry_json() powering the Post-Match Decision Intensity Heat-Map."],
      es: ["Paridad 1:1 de contrato JSON con WasmGameBridge en src/wasm_pkg/index.ts.", "Proporciona get_last_ai_telemetry_json() para el Mapa de Calor de Intensidad de Decisión."],
      pt: ["Paridade 1:1 de contrato JSON com WasmGameBridge em src/wasm_pkg/index.ts.", "Fornece get_last_ai_telemetry_json() para o Mapa de Calor de Intensidade de Decisão."],
      fr: ["Parité de contrat JSON 1:1 avec WasmGameBridge dans src/wasm_pkg/index.ts.", "Fournit get_last_ai_telemetry_json() alimentant la Carte Thermique d'Intensité de Décision."],
      de: ["1:1-JSON-Vertragsparität mit WasmGameBridge in src/wasm_pkg/index.ts.", "Liefert get_last_ai_telemetry_json() für die Entscheidungsintensitäts-Heatmap."],
      zh: ["与 src/wasm_pkg/index.ts 中的 WasmGameBridge 保持 1:1 JSON 契约一致性。", "提供 get_last_ai_telemetry_json() 驱动赛后分析器的 AI 决策强度热力图。"],
      ja: ["src/wasm_pkg/index.ts の WasmGameBridge と 1:1 の JSON 契約パリティを保証。", "get_last_ai_telemetry_json() により対局後アナライザーの AI 意思決定強度ヒートマップを駆動。"],
    },
  }),
  makeCrateEntry({
    name: "chess_game",
    layer: "canonical-games",
    exports: ["new_chess_session", "MovePieceCommand", "OfferDrawCommand", "AcceptDrawCommand", "ChessLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use chess_game::{new_chess_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_chess_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Hard, 12, 42);`,
    summaries: {
      en: "Canonical FIDE Chess engine with castling, en passant, 4-piece promotion, 50-move/threefold repetition draws, Zobrist hashing, ECO opening book, and alpha-beta AI.",
      es: "Motor canónico de Ajedrez FIDE con enroque, captura al paso, promoción a 4 piezas, tablas por 50 movimientos/triple repetición, Zobrist hashing, libro ECO e IA alfa-beta.",
      pt: "Motor canônico de Xadrez FIDE com roque, en passant, promoção para 4 peças, empates por 50 lances/tripla repetição, hash Zobrist, livro ECO e IA alfa-beta.",
      fr: "Moteur d'Échecs FIDE canonique avec roque, prise en passant, sous-promotion (4 pièces), nulle 50 coups/triple répétition, hachage Zobrist, livre ECO et IA alpha-bêta.",
      de: "Kanonische FIDE-Schach-Engine mit Rochade, En Passant, 4-Figuren-Umwandlung, 50-Züge-/Dreifachwiederholungs-Remis, Zobrist-Hashing, ECO-Eröffnungsbuch und Alpha-Beta-KI.",
      zh: "标准 FIDE 国际象棋引擎，支持王车易位、吃过路兵、四子升变、50 回合/三次重复和棋、Zobrist 哈希、ECO 开局库与 Alpha-Beta 剪枝 AI。",
      ja: "キャスリング、アンパッサン、4駒プロモーション、50手ルール／同形三復引き分け、Zobrist ハッシュ、ECO 定跡ブック、αβ探索 AI を備えた FIDE チェスエンジン。",
    },
    highlights: {
      en: ["Full FIDE legality including king safety pins, underpromotion (Q/R/B/N), and threefold Zobrist repetition.", "ECO opening book with Top-K randomness rotation + alpha-beta quiescence search."],
      es: ["Legalidad FIDE completa incluyendo clavadas al Rey, subpromoción (Q/R/B/N) y triple repetición Zobrist.", "Libro de aperturas ECO con rotación por ruido Top-K + búsqueda alfa-beta con quiescencia."],
      pt: ["Legalidade FIDE completa incluindo cravadas ao Rei, subpromoção (Q/R/B/N) e tripla repetição Zobrist.", "Livro de aberturas ECO com rotação Top-K + busca alfa-beta com quiescência."],
      fr: ["Légalité FIDE complète incluant clouages, sous-promotion (Q/R/B/N) et triple répétition Zobrist.", "Livre d'ouvertures ECO avec rotation Top-K + recherche alpha-bêta avec quiescence."],
      de: ["Vollständige FIDE-Regeln inkl. Fesselungen, Unterverwandlung (D/T/L/S) und Zobrist-Dreifachwiederholung.", "ECO-Eröffnungsbuch mit Top-K-Zufallsrotation + Alpha-Beta-Ruhesuche."],
      zh: ["完整的 FIDE 规则校验：王安全牵制、四子升变 (Q/R/B/N) 与三次 Zobrist 局面重复。", "支持 Top-K 随机轮换的 ECO 开局库与静态搜索 Alpha-Beta AI。"],
      ja: ["ピン検知、アンダープロモーション (Q/R/B/N)、Zobrist 同形三復を含む完全な FIDE ルール検証。", "Top-K ランダムローテーション対応 ECO 定跡ブックと静止探索付き αβ AI。"],
    },
  }),
  makeCrateEntry({
    name: "checkers_game",
    layer: "canonical-games",
    exports: ["new_checkers_session", "MovePieceCommand", "CheckersLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use checkers_game::{new_checkers_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_checkers_session(SessionId(1), 42, PlayerId(1), PlayerId(2));
let mv = best_move_with_randomness(&session, PlayerId(1), AiDifficulty::Medium, 25, 42);`,
    summaries: {
      en: "Canonical 8x8 Draughts / Checkers engine with mandatory capture priority, chained multi-jump continuations, King crowning, 40-move draw clock, and minimax AI.",
      es: "Motor canónico de Damas 8x8 con captura obligatoria prioritaria, saltos múltiples encadenados, coronación a Dama, reloj de tablas de 40 turnos e IA minimax.",
      pt: "Motor canônico de Damas 8x8 com captura obrigatória prioritária, saltos múltiplos encadeados, coroação de Dama, relógio de empate de 40 turnos e IA minimax.",
      fr: "Moteur de Dames 8x8 canonique avec prise obligatoire prioritaire, rafles multiples enchaînées, promotion en Dame, règle des 40 coups et IA minimax.",
      de: "Kanonische 8x8-Dame-Engine mit Schlagzwang, verketteten Mehrfachsprüngen, Damenkrönung, 40-Züge-Remisuhr und Minimax-KI.",
      zh: "标准 8x8 西洋跳棋引擎，支持强制吃子优先级、连续多步跳吃锁定、王棋加冕、40 回合和棋计时与 Minimax AI。",
      ja: "強制捕獲優先ルール、連続ジャンプ継続ロック、キング昇格、40手引き分け判定、Minimax AI を備えた 8x8 チェッカーエンジン。",
    },
    highlights: {
      en: ["Enforces mandatory capture and multi-jump chain continuation before yielding turn.", "4-diagonal King mobility and 2-ply lookahead AI with Top-K noise band."],
      es: ["Aplica captura obligatoria y continuación de saltos encadenados antes de ceder el turno.", "Movilidad de Dama en 4 diagonales e IA con búsqueda a 2 plies y banda de ruido Top-K."],
      pt: ["Aplica captura obrigatória e continuação de saltos encadeados antes de passar o turno.", "Mobilidade de Dama nas 4 diagonais e IA com busca de 2 plies e banda de ruído Top-K."],
      fr: ["Applique la prise obligatoire et l'enchaînement des sauts avant de passer le tour.", "Mobilité de Dame sur 4 diagonales et IA minimax à 2 demi-coups avec bruit Top-K."],
      de: ["Erzwingt Schlagzwang und verkettete Mehrfachsprünge vor dem Zugwechsel.", "4-Diagonalen-Damenmobilität und 2-Ply-Minimax-KI mit Top-K-Rauschband."],
      zh: ["严格执行强制吃子与连跳锁定，直到无可继续跳吃的落点才移交回合。", "支持王棋四向斜线机动与带 Top-K 噪声频带的 2 层前瞻 AI。"],
      ja: ["強制捕獲と連続ジャンプが完了するまで手番を維持する厳密なルール検証。", "4方向斜め移動可能なキングと Top-K ノイズ対応 2手先読み AI。"],
    },
  }),
  makeCrateEntry({
    name: "go_game",
    layer: "canonical-games",
    exports: ["new_go_session", "PlaceStoneCommand", "PassTurnCommand", "ToggleDeadStoneCommand", "GoLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use go_game::{new_go_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_go_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical Go (Weiqi / Baduk) engine supporting 9x9, 13x13, and 19x19 boards, BFS liberty & chain capture, positional Superko, Hoshi handicap, and 6.5 Komi scoring.",
      es: "Motor canónico de Go (Weiqi / Baduk) para tableros 9x9, 13x13 y 19x19, captura BFS por libertades, Superko posicional, hándicap Hoshi y conteo Komi 6.5.",
      pt: "Motor canônico de Go (Weiqi / Baduk) para tabuleiros 9x9, 13x13 e 19x19, captura BFS por liberdades, Superko posicional, handicap Hoshi e pontuação Komi 6.5.",
      fr: "Moteur de Go (Weiqi / Baduk) canonique (9x9, 13x13, 19x19) avec capture BFS de chaînes, Superko positionnel, handicap Hoshi et décompte Komi 6.5.",
      de: "Kanonische Go-Engine (Weiqi / Baduk) für 9x9-, 13x13- und 19x19-Bretter mit BFS-Freiheitenberechnung, Superko, Hoshi-Vorgabe und 6,5-Komi-Wertung.",
      zh: "标准围棋 (Go / Weiqi / Baduk) 引擎，支持 9x9、13x13 与 19x19 棋盘、BFS 气数与棋链提子、位置超级劫 (Superko)、星位让子及贴 6.5 目点目。",
      ja: "9x9・13x13・19x19 盤面、BFS 呼吸点・連の捕獲、位置的スーパーコウ、星（ホシ）置き石ハンデ、コミ 6.5 目計算を備えた囲碁エンジン。",
    },
    highlights: {
      en: ["BFS connected-stone liberty counting, suicide ban, and positional Superko verification.", "Interactive dead-stone marking phase after two consecutive passes with 6.5 Komi scoring."],
      es: ["Conteo BFS de libertades de cadenas, prohibición de suicidio y verificación de Superko posicional.", "Fase interactiva de marcado de piedras muertas tras dos pases consecutivos con Komi 6.5."],
      pt: ["Contagem BFS de liberdades de cadeias, proibição de suicídio e verificação de Superko posicional.", "Fase interativa de marcação de pedras mortas após dois passes consecutivos com Komi 6.5."],
      fr: ["Comptage BFS des libertés, interdiction du suicide et vérification du Superko positionnel.", "Phase de marquage des pierres mortes après deux passes consécutives avec Komi 6.5."],
      de: ["BFS-Freiheitsgradzählung verbundener Ketten, Selbstmordverbot und Superko-Prüfung.", "Tote-Steine-Markierungsphase nach zwei aufeinanderfolgenden Pässen mit 6,5 Komi."],
      zh: ["基于 BFS 广度优先的棋链气数计算、禁自杀校验与位置超级劫检测。", "双方连续虚手后进入死子标记确认阶段，自动结算领地、提子与 6.5 目贴目。"],
      ja: ["BFS による連のダメ（呼吸点）計算、自殺手禁止、および位置的スーパーコウ検証。", "連続パス後の死石指定フェーズとコミ 6.5 目を含む自動地合い計算。"],
    },
  }),
  makeCrateEntry({
    name: "shogi_game",
    layer: "canonical-games",
    exports: ["new_shogi_session", "MoveShogiPieceCommand", "DropPieceCommand", "ShogiLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use shogi_game::{new_shogi_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_shogi_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 9x9 Japanese Shogi engine with Komadai capture trays, piece drops, Nifu (double pawn) and Uchifuzume bans, FESA promotion zones, and Sennichite x4.",
      es: "Motor canónico de Shogi japonés 9x9 con bandejas Komadai, reingreso de piezas (Drops), prohibición Nifu y Uchifuzume, promoción FESA y Sennichite x4.",
      pt: "Motor canônico de Shogi japonês 9x9 com bandejas Komadai, reentrada de peças (Drops), proibição Nifu e Uchifuzume, promoção FESA e Sennichite x4.",
      fr: "Moteur de Shogi japonais 9x9 canonique avec réserves Komadai, parachutages (Drops), interdictions Nifu et Uchifuzume, promotion FESA et Sennichite x4.",
      de: "Kanonische japanische 9x9-Shogi-Engine mit Komadai-Figurenbänken, Figureneinsätzen (Drops), Nifu- und Uchifuzume-Verbot, FESA-Beförderung und Sennichite x4.",
      zh: "标准 9x9 日本将棋引擎，支持驹台持驹打入 (Drop)、二步 (Nifu) 与打步诘 (Uchifuzume) 禁手校验、FESA 升变区及千日手四次重复判定。",
      ja: "駒台（持ち駒）からの駒打ち、二歩・打ち歩詰め禁手検証、敵陣3段目の成・不成（FESA準拠）、千日手（同一局面4回）を備えた 9x9 将棋エンジン。",
    },
    highlights: {
      en: ["Demotes captured pieces into the player's Komadai tray for tactical drop re-entry.", "Validates Nifu, dead-end rank drops, Uchifuzume (pawn-drop mate), and 4-fold Sennichite."],
      es: ["Despromociona piezas capturadas hacia la bandeja Komadai para reingreso táctico (Drop).", "Valida Nifu, filas sin movimiento futuro, Uchifuzume y repetición cuádruple Sennichite."],
      pt: ["Despromove peças capturadas para a bandeja Komadai permitindo reentrada tática (Drop).", "Valida Nifu, fileiras sem movimento futuro, Uchifuzume e repetição quádrupla Sennichite."],
      fr: ["Rétrograde les pièces capturées sur le Komadai pour le parachutage tactique.", "Valide Nifu, les rangées sans coup futur, Uchifuzume et la quadruple répétition Sennichite."],
      de: ["Überführt geschlagene Figuren demotiert auf das Komadai für taktische Drops.", "Prüft Nifu, Sackgassen-Reihen, Uchifuzume und vierfache Sennichite-Wiederholung."],
      zh: ["被吃棋子自动退化并收入己方驹台，支持随时打入空位。", "严格校验二步 (Nifu)、无路可走底线打入、打步诘 (Uchifuzume) 与四次千日手。"],
      ja: ["捕獲した駒を成りを戻して駒台へ格納し、任意の空きマスへの駒打ち（ドロップ）をサポート。", "二歩、行き所のない駒、打ち歩詰め、および千日手（4回反復）を厳密に検証。"],
    },
  }),
  makeCrateEntry({
    name: "xiangqi_game",
    layer: "canonical-games",
    exports: ["new_xiangqi_session", "MoveXiangqiPieceCommand", "XiangqiLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use xiangqi_game::{new_xiangqi_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_xiangqi_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 9x10 Chinese Chess (Xiangqi) engine with 3x3 Palaces, River boundary, Horse/Elephant leg blocking, Cannon screen jumping, and Flying General prohibition.",
      es: "Motor canónico de Ajedrez Chino (Xiangqi) 9x10 con Palacios 3x3, Río central, bloqueo de Caballo/Elefante, salto de Cañón con pantalla y regla del General Volador.",
      pt: "Motor canônico de Xadrez Chinês (Xiangqi) 9x10 com Palácios 3x3, Rio central, bloqueio de Cavalo/Elefante, salto de Canhão com tela e proibição do General Voador.",
      fr: "Moteur d'Échecs Chinois (Xiangqi) 9x10 canonique avec Palais 3x3, Rivière, blocage Cavalier/Éléphant, capture du Canon par écran et règle du Général Volant.",
      de: "Kanonische 9x10-Xiangqi-Engine (Chinesisches Schach) mit 3x3-Palästen, Flussgrenze, Pferd-/Elefantenblockade, Kanonensprung über Schirm und Fliegendem General.",
      zh: "标准 9x10 中国象棋引擎，完整实现 3x3 九宫、楚河汉界、蹩马腿/塞象眼、炮隔山打牛（炮架）以及飞将面对面禁手。",
      ja: "3x3 九宮、楚河漢界（河）、馬・象の進路妨害（蹩馬腿・塞象眼）、砲の砲架ジャンプ捕獲、王将対峙禁止（飛将）を備えた 9x10 シャンチー（中国象棋）エンジン。",
    },
    highlights: {
      en: ["Enforces orthogonal Horse leg-blocking, diagonal Elephant eye-blocking, and Cannon screen captures.", "Prevents any move that leaves both Generals facing each other on an open file."],
      es: ["Valida bloqueo ortogonal del Caballo, ojo diagonal del Elefante y captura del Cañón con pantalla.", "Impide cualquier jugada que deje a ambos Generales enfrentados en la misma columna sin piezas."],
      pt: ["Valida bloqueio ortogonal do Cavalo, olho diagonal do Elefante e captura do Canhão com tela.", "Impede qualquer lance que deixe ambos os Generais frente a frente na mesma coluna aberta."],
      fr: ["Valide le blocage orthogonal du Cavalier, l'œil de l'Éléphant et la prise du Canon par écran.", "Interdit tout coup laissant les deux Généraux face à face sur une colonne ouverte."],
      de: ["Prüft orthogonale Pferdeblockade, diagonales Elefantenauge und Kanonensprung-Schlagen.", "Verhindert Züge, bei denen sich beide Generäle auf einer offenen Linie gegenüberstehen."],
      zh: ["精确校验马腿正交阻挡、象眼斜向阻挡与象不过河、以及炮隔一子吃子规则。", "严格禁止帅将同列照面（飞将规则）及送将。"],
      ja: ["馬の直交ブロック、象の斜めブロックと渡河禁止、砲の1駒飛び越し捕獲を正確に実装。", "両将帥が同じ筋で直接向かい合う「飛将」および自殺手を厳密に禁止。"],
    },
  }),
  makeCrateEntry({
    name: "chinese_checkers_game",
    layer: "canonical-games",
    exports: ["new_chinese_checkers_session", "MoveMarbleCommand", "ChineseCheckersLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use chinese_checkers_game::{new_chinese_checkers_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_chinese_checkers_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 121-node hexagram Chinese Checkers engine supporting 2, 3, 4, and 6 players, BFS chained multi-hop paths, anti-camping rules, and axial heuristics.",
      es: "Motor canónico de Damas Chinas sobre estrella hexagonal de 121 casillas para 2, 3, 4 y 6 jugadores, saltos encadenados BFS, regla anti-bloqueo y heurística axial.",
      pt: "Motor canônico de Damas Chinesas em estrela hexagonal de 121 casas para 2, 3, 4 e 6 jogadores, saltos em cadeia BFS, regra antibloqueio e heurística axial.",
      fr: "Moteur de Dames Chinoises sur étoile à 121 cases (2, 3, 4 ou 6 joueurs) avec sauts en chaîne BFS, règle anti-blocage et heuristique axiale.",
      de: "Kanonische 121-Felder-Sternhalma-Engine für 2, 3, 4 und 6 Spieler mit verketteten BFS-Mehrfachsprüngen, Anti-Blockade-Regel und axialer Heuristik.",
      zh: "标准 121 孔六角星中国跳棋引擎，支持 2、3、4、6 人对战、BFS 连续多步跨子跳路径搜索、反占巢阻塞规则与轴向距离启发式 AI。",
      ja: "2・3・4・6人対戦、BFS 連続ホップ経路探索、居座り防止ルール、軸座標ヒューリスティック AI を備えた 121 マス六芒星チャイニーズチェッカーエンジン。",
    },
    highlights: {
      en: ["121-hole axial coordinate hexagram supporting 2, 3, 4, or 6 players.", "BFS multi-hop pathfinder and directional axial projection AI."],
      es: ["Hexagrama de 121 coordenadas axiales compatible con 2, 3, 4 o 6 jugadores.", "Buscador BFS de saltos múltiples en cadena e IA de proyección axial direccional."],
      pt: ["Hexagrama de 121 coordenadas axiais compatível com 2, 3, 4 ou 6 jogadores.", "Buscador BFS de saltos múltiplos em cadeia e IA de projeção axial direcional."],
      fr: ["Hexagramme de 121 coordonnées axiales prenant en charge 2, 3, 4 ou 6 joueurs.", "Solveur BFS de sauts multiples en chaîne et IA à projection axiale directionnelle."],
      de: ["121-Loch-Hexagramm in Axialkoordinaten für 2, 3, 4 oder 6 Spieler.", "BFS-Mehrfachsprung-Pfadfinder und direktionale Axialprojektions-KI."],
      zh: ["采用 121 节点轴向坐标六角星拓扑，灵活支持 2、3、4 或 6 名玩家。", "内置 BFS 任意长度连跳路径求解器与轴向推进启发式 AI。"],
      ja: ["2、3、4、6人対戦に対応する 121 ノード軸座標ヘキサグラム盤面。", "BFS 連続ジャンプ経路ソルバーと目標三角形への軸方向射影 AI を搭載。"],
    },
  }),
  makeCrateEntry({
    name: "backgammon_game",
    layer: "canonical-games",
    exports: ["new_backgammon_session", "RollDiceCommand", "MoveCheckerCommand", "OfferDoubleCommand", "BackgammonLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use backgammon_game::{new_backgammon_session, RollDiceCommand};
use open_table_core::{PlayerId, SessionId};

let mut session = new_backgammon_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 24-point Backgammon engine with doubles (4 moves), mandatory bar re-entry, exact/highest bear-off, Doubling Cube (2..64), and Crawford rule.",
      es: "Motor canónico de Backgammon de 24 picos con dobles (4 movimientos), reingreso obligatorio desde la barra, Bear-Off, Cubo de Doblaje (2..64) y regla Crawford.",
      pt: "Motor canônico de Gamão (Backgammon) de 24 pontas com duplos (4 movimentos), reentrada obrigatória da barra, Bear-Off, Cubo de Dobras (2..64) e regra Crawford.",
      fr: "Moteur de Backgammon à 24 flèches canonique avec doubles (4 coups), réentrée obligatoire depuis la barre, sortie (Bear-Off), Videau (2..64) et règle Crawford.",
      de: "Kanonische 24-Punkte-Backgammon-Engine mit Pasch (4 Züge), Pflicht-Wiedereintritt von der Bar, Bear-Off, Verdopplungswürfel (2..64) und Crawford-Regel.",
      zh: "标准 24 点双陆棋 (Backgammon) 引擎，支持对子四步移动、中央栏强制重入、Bear-Off 离盘、加倍方块 (2..64) 与克劳福德规则。",
      ja: "ゾロ目4回移動、バーからの強制再進入、ベアオフ、ダブリングキューブ (2..64)、クロフォードルールを備えた 24 ポイント・バックギャモンエンジン。",
    },
    highlights: {
      en: ["Enforces mandatory bar re-entry, obligation to use both dice (or higher die), and Bear-Off rules.", "Includes Doubling Cube (2..64), Gammon/Backgammon scoring, and 2-ply expectiminimax AI."],
      es: ["Aplica reingreso obligatorio desde la barra, obligación de usar ambos dados (o el mayor) y Bear-Off.", "Incluye Cubo de Doblaje (2..64), puntuación Gammon/Backgammon e IA expectiminimax a 2 plies."],
      pt: ["Aplica reentrada obrigatória da barra, obrigação de usar ambos os dados (ou o maior) e Bear-Off.", "Inclui Cubo de Dobras (2..64), pontuação Gammon/Backgammon e IA expectiminimax de 2 plies."],
      fr: ["Applique la réentrée depuis la barre, l'obligation de jouer les deux dés (ou le plus fort) et le Bear-Off.", "Inclut le Videau (2..64), les scores Gammon/Backgammon et une IA expectiminimax à 2 demi-coups."],
      de: ["Erzwingt Bar-Wiedereintritt, Pflicht zur Nutzung beider Würfel (bzw. des höheren) und Bear-Off.", "Inklusive Verdopplungswürfel (2..64), Gammon/Backgammon-Wertung und 2-Ply-Expectiminimax-KI."],
      zh: ["严格校验中央栏优先重入、必须尽可能使用双骰（或较大点数骰子）以及 Bear-Off 离盘规则。", "完整支持加倍方块 (2..64)、Gammon/Backgammon 倍率与 2 层期望极小化极大 (Expectiminimax) AI。"],
      ja: ["バーからの最優先復帰、両サイコロ（または大きい目）の使用義務、ベアオフルールを厳密に適用。", "ダブリングキューブ (2..64)、ギャモン／バックギャモン倍率、2手先読み Expectiminimax AI を搭載。"],
    },
  }),
  makeCrateEntry({
    name: "battleship_game",
    layer: "canonical-games",
    exports: ["new_battleship_session", "PlaceShipCommand", "FireShotCommand", "RematchCommand", "BattleshipLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use battleship_game::new_battleship_session;
use open_table_core::{PlayerId, SessionId};

let session = new_battleship_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 10x10 Naval Combat (Battleship) engine with 5-ship fleet deployment ([5,4,3,3,2]), optional extra_turn_on_hit salvo rule, rematch command, and Hunt/Target AI.",
      es: "Motor canónico de Batalla Naval 10x10 con despliegue de flota de 5 buques ([5,4,3,3,2]), variante extra_turn_on_hit, revancha e IA de paridad Hunt/Target.",
      pt: "Motor canônico de Batalha Naval 10x10 com posicionamento de frota de 5 navios ([5,4,3,3,2]), variante extra_turn_on_hit, revanche e IA de paridade Hunt/Target.",
      fr: "Moteur de Bataille Navale 10x10 canonique avec déploiement de 5 navires ([5,4,3,3,2]), option extra_turn_on_hit, revanche et IA de parité Chasse/Cible.",
      de: "Kanonische 10x10-Schiffe-Versenken-Engine mit 5-Schiffe-Flotte ([5,4,3,3,2]), optionaler extra_turn_on_hit-Regel, Revanche und Jagd/Ziel-Paritäts-KI.",
      zh: "标准 10x10 海战棋引擎，包含 5 舰编队部署 ([5,4,3,3,2])、可选命中连射规则 (extra_turn_on_hit)、重赛指令及猎杀/锁定奇偶校验概率密度 AI。",
      ja: "5隻の艦隊配置 ([5,4,3,3,2])、命中時連続攻撃オプション (extra_turn_on_hit)、再戦コマンド、Hunt/Target 確率密度 AI を備えた 10x10 バトルシップ（海戦ゲーム）エンジン。",
    },
    highlights: {
      en: ["Two-phase state machine: Fleet deployment ([5,4,3,3,2]) and radar torpedo combat.", "Hunt/Target checkerboard parity & probability density heatmap AI."],
      es: ["Máquina de estados en dos fases: despliegue de 5 buques ([5,4,3,3,2]) y combate por coordenadas.", "IA Hunt/Target con paridad de tablero y mapa de densidad de probabilidad."],
      pt: ["Máquina de estados de duas fases: posicionamento de 5 navios ([5,4,3,3,2]) e combate por coordenadas.", "IA Hunt/Target com paridade de tabuleiro e mapa de densidade de probabilidade."],
      fr: ["Machine à états à deux phases : déploiement des 5 navires ([5,4,3,3,2]) et tir par coordonnées.", "IA Chasse/Cible avec parité en damier et carte de densité de probabilité."],
      de: ["Zwei-Phasen-Zustandsautomat: Flottenaufstellung ([5,4,3,3,2]) und Koordinatenbeschuss.", "Jagd/Ziel-KI mit Schachbrett-Parität und Wahrscheinlichkeitsdichte-Heatmap."],
      zh: ["双阶段状态机：5 艘战舰部署校验与 10x10 坐标攻击结算。", "结合棋盘奇偶校验搜索与命中后轴向推导的概率密度 AI。"],
      ja: ["艦隊配置フェーズ ([5,4,3,3,2]) と 10x10 レーダー砲撃フェーズの2段階ステートマシン。", "市松模様パリティ探索と命中軸追跡を組み合わせた確率密度 AI。"],
    },
  }),
  makeCrateEntry({
    name: "ludo_game",
    layer: "canonical-games",
    exports: ["new_ludo_session", "RollDiceCommand", "MoveTokenCommand", "LudoLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use ludo_game::{new_ludo_session, RollDiceCommand};
use open_table_core::{PlayerId, SessionId};

let mut session = new_ludo_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 52-track + 5-goal Ludo (Parcheesi) engine with 8 safe star squares, triple-six penalty, capture/goal bonus rolls, and threat-aware tactical AI.",
      es: "Motor canónico de Ludo (Parchís) de 52 casillas + 5 de meta con 8 estrellas seguras, penalización por tres 6 seguidos, tirada extra por captura/meta e IA táctica.",
      pt: "Motor canônico de Ludo de 52 casas + 5 de chegada com 8 estrelas seguras, penalidade por três 6 seguidos, bônus de captura/meta e IA tática.",
      fr: "Moteur de Ludo canonique (parcours de 52 cases + 5 d'arrivée) avec 8 étoiles sûres, pénalité triple-six, lancer bonus de capture/arrivée et IA tactique.",
      de: "Kanonische Ludo-Engine (52er-Ring + 5 Zielfelder) mit 8 sicheren Sternfeldern, Dreifach-Sechs-Strafe, Schlag-/Ziel-Bonuswürfen und taktischer KI.",
      zh: "标准飞行棋 (Ludo) 引擎（52 格公共环形赛道 + 5 格终点走廊），支持 8 个安全星格、连续三次 6 点罚停、吃子/到岸奖励掷骰与威胁感知战术 AI。",
      ja: "52マスの周回トラック＋5マスのゴールレーン、8つの安全星マス、3連続6のペナルティ、捕獲・ゴール時のボーナスロール、脅威評価 AI を備えたルドーエンジン。",
    },
    highlights: {
      en: ["4 tokens per player across 57 steps with 8 safe star squares and exact goal entry.", "Evaluates rear 1..6 rival capture threats, safe square shelter, and capture bonuses."],
      es: ["4 fichas por jugador a lo largo de 57 pasos con 8 casillas estrella seguras y llegada exacta.", "Evalúa amenazas traseras a 1..6 casillas, refugio en estrellas y bonos de captura."],
      pt: ["4 peões por jogador ao longo de 57 passos com 8 casas estrela seguras e chegada exata.", "Avalia ameaças traseiras de 1..6 casas, abrigo em estrelas e bônus de captura."],
      fr: ["4 pions par joueur sur 57 pas avec 8 cases étoiles sûres et entrée exacte au but.", "Évalue les menaces arrière à 1..6 cases, les abris sûrs et les bonus de capture."],
      de: ["4 Figuren pro Spieler über 57 Schritte mit 8 sicheren Sternfeldern und exaktem Zieleinlauf.", "Bewertet Verfolger-Bedrohungen (1..6 Felder), sichere Felder und Schlagboni."],
      zh: ["每名玩家 4 枚棋子跨越 57 步赛程，包含 8 个安全星格与精确进终点校验。", "AI 综合评估后方 1..6 格被吃风险、安全格庇护与吃子奖励。"],
      ja: ["各プレイヤー4個の駒、8つの安全星マス、57ステップの正確なゴール判定。", "後方1〜6マスの被捕獲リスク、安全マスの活用、捕獲ボーナスを評価する戦術 AI。"],
    },
  }),
  makeCrateEntry({
    name: "mille_bornes_game",
    layer: "canonical-games",
    exports: ["new_mille_bornes_session", "PlayCardCommand", "DiscardCardCommand", "CoupFourreCommand", "MilleBornesLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use mille_bornes_game::{new_mille_bornes_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_mille_bornes_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 1000-km Mille Bornes card racing engine with Hazards, Remedies, Speed Limits, max two 200-km cards, 4 Safety shields, and Coup Fourré instant counter-play.",
      es: "Motor canónico de cartas Mil Millas (1000 km) con Ataques, Defensas, Límites de Velocidad, máximo dos cartas de 200 km, 4 Escudos (Safeties) y respuesta ¡Coup Fourré!.",
      pt: "Motor canônico de cartas Mil Milhas (1000 km) com Ataques, Defesas, Limite de Velocidade, máximo duas cartas de 200 km, 4 Escudos (Safeties) e resposta Coup Fourré!.",
      fr: "Moteur canonique du jeu de cartes Mille Bornes (1000 km) avec Attaques, Parades, Limites de Vitesse, max deux bornes 200 km, 4 Bottes et réplique Coup Fourré !",
      de: "Kanonische 1000-km-Mille-Bornes-Kartenrenn-Engine mit Hindernissen, Abhilfen, Tempolimits, max. zwei 200-km-Karten, 4 Trumpfkarten (Safeties) und Coup Fourré.",
      zh: "标准千里之行 (Mille Bornes) 1000 公里竞速卡牌引擎，包含故障卡、修复卡、限速卡、最多两张 200 公里限制、4 张王牌护盾 (Safety) 与 Coup Fourré 瞬间反击。",
      ja: "1000km 達成を目指すミルボーン (Mille Bornes) カードエンジン。妨害・修復・速度制限、200km カード最大2枚制限、4枚のセーフティ（切り札）、クー・フレ反撃を完全実装。",
    },
    highlights: {
      en: ["Enforces exact 1000 km target, maximum two 200 km cards, and Roll (Green Light) requirements.", "Supports instant CoupFourreCommand interruption with +300 bonus and extra turn."],
      es: ["Exige meta exacta de 1000 km, máximo dos cartas de 200 km y requisito de Siga (Semáforo Verde).", "Soporta interrupción instantánea CoupFourreCommand con bono de +300 puntos y turno extra."],
      pt: ["Exige meta exata de 1000 km, máximo duas cartas de 200 km e requisito de Siga (Sinal Verde).", "Suporta interrupção instantânea CoupFourreCommand com bônus de +300 pontos e turno extra."],
      fr: ["Applique l'objectif exact de 1000 km, la limite de deux bornes 200 km et le Feu Vert requis.", "Gère l'interruption instantanée CoupFourreCommand (+300 points et tour supplémentaire)."],
      de: ["Prüft exaktes 1000-km-Ziel, maximal zwei 200-km-Karten und Grünes-Licht-Anforderung.", "Unterstützt sofortige CoupFourreCommand-Reaktion (+300 Bonuspunkte und Extrazug)."],
      zh: ["严格执行 1000 公里精确终点、最多使用两张 200 公里里程卡及绿灯起步条件。", "支持在遭受对应故障攻击时触发 CoupFourreCommand 瞬间反击（+300 分并获额外回合）。"],
      ja: ["1000km ジャスト到達ルール、200km カード2枚制限、青信号（Roll）状態を厳密にチェック。", "妨害カードに対する CoupFourreCommand 即時カウンター（+300点＆追加ターン）をサポート。"],
    },
  }),
  makeCrateEntry({
    name: "monopoly_game",
    layer: "canonical-games",
    exports: ["new_monopoly_session", "RollDiceCommand", "BuyPropertyCommand", "BuildHouseCommand", "PlaceBidCommand", "MonopolyLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use monopoly_game::{new_monopoly_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_monopoly_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 40-square Monopoly economic engine with property auctions, Chance/Community Chest decks, even house/hotel building, mortgages, jail, P2P trades, and ROI AI.",
      es: "Motor económico canónico de Monopoly de 40 casillas con subastas, mazos de Suerte/Arca Comunal, construcción uniforme de casas/hoteles, hipotecas, cárcel, trueques e IA por ROI.",
      pt: "Motor econômico canônico de Monopoly de 40 casas com leilões, cartas Sorte/Cofre, construção uniforme de casas/hotéis, hipotecas, prisão, trocas P2P e IA por ROI.",
      fr: "Moteur économique Monopoly à 40 cases canonique avec enchères, cartes Chance/Caisse de Communauté, construction uniforme maisons/hôtels, hypothèques, prison et IA ROI.",
      de: "Kanonische 40-Felder-Monopoly-Wirtschafts-Engine mit Auktionen, Ereignis-/Gemeinschaftskarten, gleichmäßigem Haus-/Hotelbau, Hypotheken, Gefängnis, Handel und ROI-KI.",
      zh: "标准 40 格大富翁 (Monopoly) 经济引擎，支持地产拍卖、机会/公益金卡组、同色地产均匀建房/旅馆、抵押赎回、监狱规则、玩家交易及投资回报率 (ROI) AI。",
      ja: "40マスのモノポリー経済エンジン。競売（オークション）、チャンス／共同基金カード、均等な家・ホテル建設、抵当・解除、刑務所、プレイヤー間取引、ROI 評価 AI を搭載。",
    },
    highlights: {
      en: ["40 spaces across 8 color groups, 4 railroads, and 2 utilities with live auctions on decline.", "Enforces even house/hotel building across monopolies and 10% mortgage interest."],
      es: ["40 casillas en 8 grupos de color, 4 estaciones y 2 servicios con subasta al rechazar compra.", "Valida construcción uniforme de casas/hoteles en monopolios e interés hipotecario del 10%."],
      pt: ["40 casas em 8 grupos de cor, 4 estações e 2 serviços com leilão ao recusar compra.", "Valida construção uniforme de casas/hotéis em monopólios e juros de hipoteca de 10%."],
      fr: ["40 cases réparties en 8 groupes de couleur, 4 gares et 2 compagnies avec enchères.", "Applique la construction uniforme de maisons/hôtels et l'intérêt hypothécaire de 10 %."],
      de: ["40 Felder in 8 Farbgruppen, 4 Bahnhöfe und 2 Werke mit Live-Auktion bei Kaufverzicht.", "Erzwingt gleichmäßigen Haus-/Hotelbau innerhalb einer Farbgruppe und 10 % Hypothekenzins."],
      zh: ["涵盖 8 大色组、4 座车站与 2 处公用事业的 40 格棋盘，放弃购买即触发竞价拍卖。", "严格执行垄断色组均匀加盖房屋/旅馆规则与 10% 赎回利息计算。"],
      ja: ["8色グループ・4鉄道・2公共会社からなる40マス盤面と、購入見送り時のリアルタイム競売。", "同一カラーグループ内の均等な家／ホテル建設ルールと 10% の抵当解除利子を検証。"],
    },
  }),
  makeCrateEntry({
    name: "uno_game",
    layer: "canonical-games",
    exports: ["new_uno_session", "PlayCardCommand", "DrawCardCommand", "CallUnoCommand", "ChallengeWildDrawFourCommand", "UnoLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use uno_game::{new_uno_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_uno_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 108-card UNO engine with Skip, Reverse, Draw Two, Wild, Wild Draw Four challenge verification, mandatory UNO! call/penalty, and Jump-In interception.",
      es: "Motor canónico de UNO de 108 cartas con Salto, Reversa, +2, Comodín, desafío legal de Wild +4, grito/penalización ¡UNO! e intercepción Jump-In.",
      pt: "Motor canônico de UNO de 108 cartas com Pular, Inverter, +2, Curinga, desafio legal de Wild +4, grito/penalidade UNO! e interceptação Jump-In.",
      fr: "Moteur UNO à 108 cartes canonique avec Passe, Inversion, +2, Joker, contestation légale du +4, annonce/pénalité UNO ! et interception Jump-In.",
      de: "Kanonische 108-Karten-UNO-Engine mit Aussetzen, Retour, +2, Farbwahl, +4-Herausforderungsprüfung, UNO!-Ruf/Strafe und Jump-In-Regel.",
      zh: "标准 108 张牌 UNO 引擎，支持跳过、反转、+2、变色、+4 合法性质疑挑战、强制 ¡UNO! 喊牌与漏喊罚牌，以及相同牌抢出 (Jump-In)。",
      ja: "スキップ、リバース、ドロー2、ワイルド、ワイルドドロー4の合法性チャレンジ判定、UNO! 宣言・ペナルティ、ジャンプイン割り込みを備えた 108枚 UNO エンジン。",
    },
    highlights: {
      en: ["Inspects player hand during ChallengeWildDrawFourCommand (+4 to offender or +6 to challenger).", "Supports CallUnoCommand, CatchUnoFailureCommand (+2 cards), and identical-card JumpInCommand."],
      es: ["Inspecciona la mano durante ChallengeWildDrawFourCommand (+4 al infractor o +6 al retador).", "Soporta CallUnoCommand, CatchUnoFailureCommand (+2 cartas) y JumpInCommand con carta idéntica."],
      pt: ["Inspeciona a mão durante ChallengeWildDrawFourCommand (+4 ao infrator ou +6 ao desafiante).", "Suporta CallUnoCommand, CatchUnoFailureCommand (+2 cartas) e JumpInCommand com carta idêntica."],
      fr: ["Inspecte la main lors de ChallengeWildDrawFourCommand (+4 au fautif ou +6 au contestataire).", "Gère CallUnoCommand, CatchUnoFailureCommand (+2 cartes) et JumpInCommand sur carte identique."],
      de: ["Prüft die Hand bei ChallengeWildDrawFourCommand (+4 für Täter oder +6 für Herausforderer).", "Unterstützt CallUnoCommand, CatchUnoFailureCommand (+2 Karten) und JumpInCommand."],
      zh: ["在 ChallengeWildDrawFourCommand 质疑时自动核查出牌者手牌（违规罚 4 张，合规质疑者罚 6 张）。", "支持 CallUnoCommand 喊牌、CatchUnoFailureCommand 抓漏喊（+2 张）与相同牌 JumpInCommand。"],
      ja: ["ChallengeWildDrawFourCommand 時に手札の色一致を検証（違反時は出した側が+4枚、合法時は挑戦者が+6枚）。", "CallUnoCommand、宣言忘れ指摘 CatchUnoFailureCommand (+2枚)、同カード割り込み JumpInCommand に対応。"],
    },
  }),
  makeCrateEntry({
    name: "crisis_game",
    layer: "canonical-games",
    exports: ["new_crisis_session", "PlaceArmiesCommand", "AttackTerritoryCommand", "FortifyTerritoryCommand", "TradeCardsCommand", "CrisisLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use crisis_game::{new_crisis_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_crisis_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 30-territory, 6-continent global strategy engine (TEG / Risk) with secret objectives, continent bonuses, 3v3 sorted dice combat, 3-card trades, and multi-phase AI.",
      es: "Motor de estrategia global canónico de 30 territorios y 6 continentes (Crisis / TEG / Risk) con objetivos secretos, bonos continentales, combate 3v3, canje de tarjetas e IA multifase.",
      pt: "Motor canônico de estratégia global de 30 territórios e 6 continentes (Crisis / War / Risk) com objetivos secretos, bônus continentais, combate 3v3, troca de cartas e IA multifase.",
      fr: "Moteur de stratégie globale à 30 territoires et 6 continents (Crisis / TEG / Risk) avec objectifs secrets, bonus continentaux, combat de dés 3v3, échange de cartes et IA.",
      de: "Kanonische Globalstrategie-Engine mit 30 Territorien und 6 Kontinenten (Crisis / TEG / Risiko), Geheimzielen, Kontinentboni, 3v3-Würfelkampf, Kartentausch und Mehrphasen-KI.",
      zh: "标准 30 领土 6 大洲全球战略引擎 (Crisis / TEG / Risk)，支持秘密任务目标、大洲控制增援加成、3v3 排序骰子会战、三卡兑换及多阶段战术 AI。",
      ja: "6大陸30領土のグローバル戦略エンジン (Crisis / TEG / リスク)。秘密目標、大陸制覇ボーナス、最大 3対3 のソート付きダイス戦闘、カード3枚交換、マルチフェーズ AI を搭載。",
    },
    highlights: {
      en: ["Three-phase turn loop: Reinforce (territories/3 + continent bonuses + card trades), 3v3 Attack, and Fortify.", "Multi-step AI planning card trades, border reinforcements, favorable attacks, and interior fortification."],
      es: ["Ciclo de turno en 3 fases: Refuerzo (territorios/3 + bonos continentales + canjes), Ataque 3v3 y Reagrupación.", "IA multifase que planifica canjes de tarjetas, refuerzo fronterizo, ataques favorables y fortificación."],
      pt: ["Ciclo de turno em 3 fases: Reforço (territórios/3 + bônus continentais + trocas), Ataque 3v3 e Fortificação.", "IA multifase que planeja trocas de cartas, reforço de fronteira, ataques favoráveis e reagrupamento."],
      fr: ["Cycle de tour en 3 phases : Renfort (territoires/3 + bonus continentaux + cartes), Attaque 3v3 et Fortification.", "IA multi-étapes planifiant échanges de cartes, renforts frontaliers, attaques et regroupements."],
      de: ["Drei-Phasen-Zug: Verstärkung (Gebiete/3 + Kontinentboni + Kartentausch), 3v3-Angriff und Verschieben.", "Mehrstufige KI für Kartentausch, Grenzverstärkung, vorteilhafte Angriffe und Truppenverschiebung."],
      zh: ["三阶段回合流水线：增援（领土数/3 + 大洲加成 + 卡牌兑换）、3v3 骰子进攻与边境调兵加固。", "多步战术 AI 自动统筹卡牌兑换、前线增援、高胜率进攻与腹地兵力向前线集结。"],
      ja: ["増援（領土数/3＋大陸ボーナス＋カード交換）、最大3v3の攻撃、隣接領土への兵力再配置の3フェーズ構成。", "カード交換、国境への増援、勝率の高い攻撃、後衛から前線への兵力移動を計画するマルチフェーズ AI。"],
    },
  }),
  makeCrateEntry({
    name: "goose_game",
    layer: "canonical-games",
    exports: ["new_goose_session", "RollDiceCommand", "GooseLegalMoveGenerator", "best_move_with_randomness"],
    codeExample: `use goose_game::{new_goose_session, ai::best_move_with_randomness};
use open_table_core::{AiDifficulty, PlayerId, SessionId};

let session = new_goose_session(SessionId(1), 42, PlayerId(1), PlayerId(2));`,
    summaries: {
      en: "Canonical 63-square spiral Game of the Goose (Juego de la Oca) engine with 13 Geese ('De oca a oca'), Bridges, Inn, Dice, Well, Labyrinth, Prison, Death Skull (58), and exact bounce.",
      es: "Motor canónico de El Juego de la Oca en espiral de 63 casillas con 13 Ocas ('De oca a oca'), Puentes, Posada, Dados, Pozo, Laberinto, Cárcel, Calavera (58) y rebote exacto.",
      pt: "Motor canônico do Jogo da Gansa em espiral de 63 casas com 13 Gansas, Pontes, Pousada, Dados, Poço, Labirinto, Prisão, Caveira (58) e recuo exato.",
      fr: "Moteur canonique du Jeu de l'Oie en spirale de 63 cases avec 13 Oies, Ponts, Hôtel, Dés, Puits, Labyrinthe, Prison, Tête de Mort (58) et rebond exact.",
      de: "Kanonische 63-Felder-Gänsespiel-Engine mit 13 Gänsen, Brücken, Herberge, Würfeln, Brunnen, Labyrinth, Gefängnis, Totenkopf (58) und exaktem Rückprall.",
      zh: "标准 63 格螺旋鹅棋 (Game of the Goose) 引擎，完整包含 13 个鹅格连跳、桥梁、客栈、骰子格、水井、迷宫 (42->30)、监狱、骷髅 (58->1) 与第 63 格超步反弹。",
      ja: "13箇所のガチョウ連続ジャンプ、橋、宿屋、ダイス、井戸、迷宮 (42->30)、牢獄、ドクロ (58->1)、および63マス目の正確な折り返しを備えた63マス螺旋・鵞鳥のゲームエンジン。",
    },
    highlights: {
      en: ["13 Geese chain jumps + extra turn, Bridges (6<->12), and Dice shortcuts (26<->53).", "Authentic hazards: Inn (19), Well (31), Labyrinth (42->30), Prison (52), Skull (58->1), and bounce at 63."],
      es: ["13 Ocas con salto encadenado y tiro extra, Puentes (6<->12) y atajos de Dados (26<->53).", "Peligros clásicos: Posada (19), Pozo (31), Laberinto (42->30), Cárcel (52), Calavera (58->1) y rebote en 63."],
      pt: ["13 Gansas com salto encadeado e jogada extra, Pontes (6<->12) e atalhos de Dados (26<->53).", "Obstáculos clássicos: Pousada (19), Poço (31), Labirinto (42->30), Prisão (52), Caveira (58->1) e recuo no 63."],
      fr: ["13 Oies avec saut à l'oie suivante et lancer bonus, Ponts (6<->12) et Dés (26<->53).", "Pièges authentiques : Hôtel (19), Puits (31), Labyrinthe (42->30), Prison (52), Mort (58->1) et rebond en 63."],
      de: ["13 Gänsefelder mit Sprung zur nächsten Gans & Extrawurf, Brücken (6<->12) und Würfelfelder (26<->53).", "Klassische Hindernisse: Herberge (19), Brunnen (31), Labyrinth (42->30), Gefängnis (52), Totenkopf (58->1) und Rückprall bei 63."],
      zh: ["13 个鹅格自动跳跃至下一鹅格并获额外掷骰，含桥梁 (6<->12) 与骰子捷径 (26<->53)。", "经典陷阱：客栈 (19)、水井 (31)、迷宫 (42->30)、监狱 (52)、骷髅重回起点 (58->1) 及 63 格超步反弹。"],
      ja: ["13個のガチョウマスによる次のガチョウへのジャンプ＆追加ロール、橋 (6<->12)、ダイス (26<->53)。", "宿屋 (19)、井戸 (31)、迷宮 (42->30)、牢獄 (52)、ドクロ (58->1)、63マス目の余剰バウンスを完全再現。"],
    },
  }),
];

export function getCrateHighlightsForLocale(
  crate: CrateDocEntry,
  locale: SupportedLocale
): string[] {
  if (
    locale === "en" ||
    locale === "es" ||
    locale === "pt" ||
    locale === "fr" ||
    locale === "de" ||
    locale === "zh" ||
    locale === "ja"
  ) {
    return crate.highlightsByLocale[locale];
  }
  return crate.highlightsByLocale.en;
}

export interface TrustedPublishingOidcConfig {
  platform: "GitHub";
  repositoryOwner: string;
  repositoryName: string;
  workflowFilename: string;
  environment: string;
  authAction: string;
  tokenTtlMinutes: number;
  scriptPath: string;
  publishableCratesCount: number;
  ffiBridgesCount: number;
  topologicalTiers: Array<{
    tier: number;
    label: string;
    crates: string[];
  }>;
  workflowYamlSnippet: string;
}

export const TRUSTED_PUBLISHING_OIDC_CONFIG: TrustedPublishingOidcConfig = {
  platform: "GitHub",
  repositoryOwner: "joduranvillan",
  repositoryName: "games_tables_sdk",
  workflowFilename: "release.yml",
  environment: "release",
  authAction: "rust-lang/crates-io-auth-action@v1",
  tokenTtlMinutes: 30,
  scriptPath: "tools/publish_crates_io.sh",
  publishableCratesCount: 22,
  ffiBridgesCount: 2,
  topologicalTiers: [
    {
      tier: 1,
      label: "Tier 1 · Foundation Base (2)",
      crates: ["open_table_core", "open_table_macros"],
    },
    {
      tier: 2,
      label: "Tier 2 · ECS Engine, QR & Transports (5)",
      crates: [
        "open_table_engine",
        "open_table_qr",
        "open_table_transport_tcp",
        "open_table_transport_websocket",
        "open_table_transport_native_bridge",
      ],
    },
    {
      tier: 3,
      label: "Tier 3 · 14 Canonical Board Games (14)",
      crates: [
        "open_table_chess_game",
        "open_table_checkers_game",
        "open_table_shogi_game",
        "open_table_xiangqi_game",
        "open_table_go_game",
        "open_table_chinese_checkers_game",
        "open_table_backgammon_game",
        "open_table_ludo_game",
        "open_table_battleship_game",
        "open_table_mille_bornes_game",
        "open_table_monopoly_game",
        "open_table_uno_game",
        "open_table_crisis_game",
        "open_table_goose_game",
      ],
    },
    {
      tier: 4,
      label: "Tier 4 · Standalone Relay Server (1)",
      crates: ["open_table_relay"],
    },
  ],
  workflowYamlSnippet: `  publish-crates-io:
    name: Publish to crates.io (Trusted Publishing OIDC)
    needs: [verify-release-readiness]
    runs-on: ubuntu-latest
    environment: release
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v6
      - uses: dtolnay/rust-toolchain@stable
      - run: ./tools/publish_crates_io.sh --dry-run
      - uses: rust-lang/crates-io-auth-action@v1
        id: auth
      - run: ./tools/publish_crates_io.sh --publish
        env:
          CARGO_REGISTRY_TOKEN: \${{ steps.auth.outputs.token }}`,
};

