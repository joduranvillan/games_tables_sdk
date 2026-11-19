import assert from "node:assert/strict";
import { CATALOG_14_GAMES } from "../App";
import { filterAndGroupCatalogGames } from "../components/common/GameListNavigation";
import {
  GAME_CATALOG_TRANSLATIONS,
  getLocalizedCatalogGames,
  getLocalizedCategoryGroups,
  isSupportedLocale,
  normalizeBrowserLocale,
  SUPPORTED_LOCALE_CODES,
  SUPPORTED_LOCALES,
  SupportedLocale,
  translateDynamicPhrase,
  UI_DICTIONARIES,
  UiTranslationKey,
} from "../i18n";

console.log("=== Running 9-Language i18n Translation Parity Suite ===");

// 1. Verify all 9 official languages exist
const expectedLocales: SupportedLocale[] = [
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

assert.equal(
  SUPPORTED_LOCALE_CODES.length,
  9,
  "Must support exactly 9 official i18n locales"
);
for (const code of expectedLocales) {
  assert.ok(
    SUPPORTED_LOCALE_CODES.includes(code),
    `Locale ${code} must be in SUPPORTED_LOCALE_CODES`
  );
  assert.ok(
    isSupportedLocale(code),
    `isSupportedLocale(${code}) must return true`
  );
  const meta = SUPPORTED_LOCALES.find((l) => l.code === code);
  assert.ok(meta, `SUPPORTED_LOCALES metadata missing for ${code}`);
  assert.ok(meta.nativeName.length > 0, `nativeName empty for ${code}`);
  assert.ok(meta.flag.length > 0, `flag empty for ${code}`);
}
console.log("✔ 1. 9 official locales verified:", SUPPORTED_LOCALE_CODES.join(", "));

// 2. Verify 100% key parity across UI_DICTIONARIES for all 9 languages
const baseEsKeys = Object.keys(UI_DICTIONARIES.es) as UiTranslationKey[];
assert.ok(baseEsKeys.length >= 80, "Base Spanish UI dictionary must contain all UI keys");

for (const loc of expectedLocales) {
  const dict = UI_DICTIONARIES[loc];
  assert.ok(dict, `Missing UI_DICTIONARIES entry for ${loc}`);
  for (const key of baseEsKeys) {
    const val = dict[key];
    assert.ok(
      typeof val === "string" && val.trim().length > 0,
      `Missing or empty UI translation for locale="${loc}", key="${key}"`
    );
  }
}
console.log(
  `✔ 2. 100% UI key parity verified across all 9 languages (${baseEsKeys.length} keys × 9 locales = ${
    baseEsKeys.length * 9
  } strings)`
);

// 3. Verify 100% coverage of the 14 canonical games across all 9 languages
assert.equal(CATALOG_14_GAMES.length, 14, "Catalog must have 14 games");

for (const loc of expectedLocales) {
  const gameDict = GAME_CATALOG_TRANSLATIONS[loc];
  assert.ok(gameDict, `Missing GAME_CATALOG_TRANSLATIONS for ${loc}`);

  for (const game of CATALOG_14_GAMES) {
    const entry = gameDict[game.id];
    assert.ok(
      entry,
      `Missing game translation for game="${game.id}" in locale="${loc}"`
    );
    assert.ok(entry.title.trim().length > 0, `Empty title for ${game.id} in ${loc}`);
    assert.ok(
      entry.category.trim().length > 0,
      `Empty category for ${game.id} in ${loc}`
    );
    assert.ok(
      entry.summary.trim().length > 0,
      `Empty summary for ${game.id} in ${loc}`
    );
  }

  const localizedCatalog = getLocalizedCatalogGames(CATALOG_14_GAMES, loc);
  assert.equal(localizedCatalog.length, 14);
  const grouped = filterAndGroupCatalogGames(localizedCatalog, "", "all", loc);
  assert.equal(grouped.length, 4, `Must return 4 category groups in ${loc}`);
  const totalGamesInGroups = grouped.reduce((acc, g) => acc + g.games.length, 0);
  assert.equal(totalGamesInGroups, 14, `All 14 games must be grouped in ${loc}`);

  const categoryGroups = getLocalizedCategoryGroups(loc);
  assert.equal(categoryGroups.length, 4);
}
console.log(
  "✔ 3. All 14 games localized and grouped across all 9 languages (14 games × 9 locales)"
);

// 4. Verify browser locale normalization and dynamic board/HUD phrase translation
assert.equal(normalizeBrowserLocale("en-US"), "en");
assert.equal(normalizeBrowserLocale("pt-BR"), "pt");
assert.equal(normalizeBrowserLocale("ja-JP"), "ja");
assert.equal(normalizeBrowserLocale("ko-KR"), "ko");
assert.equal(normalizeBrowserLocale("zh-CN"), "zh");
assert.equal(normalizeBrowserLocale("fr-FR"), "fr");
assert.equal(normalizeBrowserLocale("de-DE"), "de");
assert.equal(normalizeBrowserLocale("it-IT"), "it");
assert.equal(normalizeBrowserLocale("unknown-XX"), "es");

for (const loc of expectedLocales) {
  const sampleBanner = "Turno: Jugador 1 · Enroque Corto · Tirar Dados";
  const translated = translateDynamicPhrase(sampleBanner, loc);
  assert.ok(translated.length > 0);
  if (loc !== "es") {
    assert.notEqual(
      translated,
      sampleBanner,
      `Dynamic phrase should be translated for locale=${loc}`
    );
  }
}
console.log("✔ 4. Browser locale detection and dynamic board phrase translation verified");

// 5. Verify SystemDiagnosticsPanel, PWAInstallButton, Panels & Technical Acronym Preservation (PASS, ELO, JSON, WASM)
const diagnosticStringsToVerify = [
  "Auditoría Funcional en Tiempo Real · 14 Motores Canónicos + Subsistemas Web",
  "Centro de Diagnóstico y Garantía Funcional (Self-Test E2E)",
  "Verifica con un clic que los 14 juegos inicializan su sesión, calculan jugadas legales, procesan comandos del jugador, ejecutan la IA, evalúan la ventaja posicional y sincronizan historiales JSON sin errores.",
  "Ejecutar Diagnóstico Completo (14 Juegos)",
  "Probar Juego Actual",
  "Copiar JSON",
  "Exportar Reporte",
  "Estado Global del Sistema",
  "PASS · 100% OPERATIVO",
  "Motores de Juego Verificados",
  "Inicialización + Jugada Legal + IA + SyncLog",
  "Tiempo Total de Auditoría E2E",
  "Documentación de Uso y Desarrollo React",
  "Abrir Manual de Uso y Guía React/WASM",
  "01. Verificación de Subsistemas del Navegador y Ecosistema",
  "Puente WasmGameBridge (14 Motores)",
  "Subsistema ELO K=32 y Torneos Berger/KO",
  "Persistencia LocalStorage (Perfil y Partidas)",
  "Síntesis Web Audio API & Capacidad PWA",
  "Cliente WebSocket Relay & Cola Matchmaking",
  "02. Matriz de Auditoría Funcional de los 14 Juegos (Ejecución en Vivo)",
  "Instalar PWA",
];

for (const loc of expectedLocales) {
  if (loc === "es") continue;
  for (const phrase of diagnosticStringsToVerify) {
    const translated = translateDynamicPhrase(phrase, loc);
    // In Portuguese and Italian, certain technical phrases are exact cognates with Spanish
    if (
      (loc === "pt" &&
        (phrase === "Copiar JSON" || phrase === "Instalar PWA")) ||
      (loc === "it" && phrase === "PASS · 100% OPERATIVO")
    ) {
      assert.equal(translated, phrase);
      continue;
    }
    assert.notEqual(
      translated,
      phrase,
      `Phrase "${phrase}" must be translated in locale="${loc}"`
    );
  }

  // Verify technical acronyms PASS, ELO, JSON, WASM are preserved
  assert.ok(
    translateDynamicPhrase("PASS · 100% OPERATIVO", loc).includes("PASS"),
    `Technical acronym PASS must be preserved in locale="${loc}"`
  );
  assert.ok(
    translateDynamicPhrase("Copiar JSON", loc).includes("JSON"),
    `Technical acronym JSON must be preserved in locale="${loc}"`
  );
  assert.ok(
    translateDynamicPhrase("Subsistema ELO K=32 y Torneos Berger/KO", loc).includes("ELO"),
    `Technical acronym ELO must be preserved in locale="${loc}"`
  );
  assert.ok(
    translateDynamicPhrase("Abrir Manual de Uso y Guía React/WASM", loc).includes("WASM"),
    `Technical acronym WASM must be preserved in locale="${loc}"`
  );
}
console.log(
  "✔ 5. SystemDiagnosticsPanel, PWAInstallButton & technical acronyms (PASS, ELO, JSON, WASM) verified across all 9 languages"
);

// 6. Verify 14-Game Board HUD & Rule Phrases across all 9 languages
const boardHudPhrases = [
  "Estrella Hexagonal Canónica (121 Casillas)",
  "Tablero Cruz 15×15 Canónico",
  "Recorrido en Espiral de 63 Casillas",
  "Tu Flota (5 Buques Ilustrados)",
  "Radar de Ataque (Flota Enemiga)",
  "Mano del Jugador Activo",
  "Finalizar Turno",
];

for (const loc of expectedLocales) {
  if (loc === "es") continue;
  for (const phrase of boardHudPhrases) {
    const translated = translateDynamicPhrase(phrase, loc);
    if (loc === "pt" && phrase === "Finalizar Turno") {
      assert.equal(translated, "Finalizar Turno");
      continue;
    }
    assert.notEqual(
      translated,
      phrase,
      `Board HUD phrase "${phrase}" must be translated in locale="${loc}"`
    );
  }
}
console.log("✔ 6. All 14 game board HUD phrases verified across all 9 languages");
console.log("=== ALL 9-LANGUAGE I18N TESTS PASSED ===");



